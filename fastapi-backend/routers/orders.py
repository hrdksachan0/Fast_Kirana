from fastapi import APIRouter, Depends, HTTPException, status, Body, BackgroundTasks, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, and_, or_, func, text, not_
import os
import re
import json
import uuid
import random
import math
import httpx
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any

from database import get_db
from models import (
    Order, OrderItem, Product, User, Address, RiderWallet, 
    OrderStatus, PaymentStatus, PaymentMethod, OrderType, Role,
    StoreSetting, Coupon, FcmToken, ProductBatch, StockLog, Restaurant
)
from routers.auth import require_auth, get_current_user
from routers.websockets import manager
from utils.firebase import send_fcm_notification

logger = logging.getLogger("orders")

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])


def generate_id(prefix: str = "ord_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_last_10_digits(phone: str) -> str:
    digits = "".join(c for c in str(phone) if c.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


def get_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         (math.sin(d_lng / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


def get_delivery_rules(distance_km: float, max_radius_km: float = 5.0, surge_fee: float = 0.0) -> dict:
    if distance_km > max_radius_km:
        return {
            "distanceKm": distance_km,
            "minOrder": 20.0,
            "deliveryFee": 0.0,
            "freeDeliveryThreshold": 499.0,
            "isServiceable": False,
            "zoneName": f"Outside Delivery Zone (> {max_radius_km:.1f} km)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }
    
    if distance_km <= 2.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 20.0,
            "deliveryFee": 25.0 + surge_fee,
            "freeDeliveryThreshold": 200.0,
            "isServiceable": True,
            "zoneName": "0-2 km (Express Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    if distance_km <= 4.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 20.0,
            "deliveryFee": 35.0 + surge_fee,
            "freeDeliveryThreshold": 249.0,
            "isServiceable": True,
            "zoneName": "2-4 km (Standard Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    if distance_km <= 6.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 50.0,
            "deliveryFee": 50.0 + surge_fee,
            "freeDeliveryThreshold": 349.0,
            "isServiceable": True,
            "zoneName": "4-6 km (Extended Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    return {
        "distanceKm": distance_km,
        "minOrder": 100.0,
        "deliveryFee": 70.0 + surge_fee,
        "freeDeliveryThreshold": 499.0,
        "isServiceable": True,
        "zoneName": "6+ km (Outer Zone)",
        "surgeFee": surge_fee,
        "maxRadiusKm": max_radius_km,
    }


def get_product_type(p: Product) -> str:
    if p.restaurantId:
        return "RESTAURANT"
    category_slug = getattr(p.category, "slug", "") if p.category else ""
    tags_list = p.tags or []
    if category_slug == "cafe" or "cafe" in tags_list:
        return "CAFE"
    return "GROCERY"


def get_product_limit(p: Product) -> int:
    ptype = get_product_type(p)
    if ptype == "RESTAURANT":
        return 20
    if ptype == "CAFE":
        return 10
    return 10


async def geocode_address(address_str: str) -> Optional[dict]:
    api_key = os.getenv("GOOGLE_MAPS_API_KEY") or os.getenv("NEXT_PUBLIC_GOOGLE_MAPS_API_KEY")
    if not api_key:
        return None
    url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {"address": address_str, "key": api_key.strip()}
    try:
        async with httpx.AsyncClient(timeout=2) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("results") and data["results"][0].get("geometry", {}).get("location"):
                    loc = data["results"][0]["geometry"]["location"]
                    return {"lat": float(loc["lat"]), "lng": float(loc["lng"])}
    except Exception as e:
        logger.error(f"Google Maps geocode exception: {str(e)}")
    return None


async def send_whatsapp_alert(phone: str, text: str) -> bool:
    token = os.getenv("WHATSAPP_TOKEN")
    phone_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID")

    if not token or not phone_id:
        return False

    clean_phone = f"91{phone}" if len(phone) == 10 else phone
    url = f"https://graph.facebook.com/v20.0/{phone_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": clean_phone,
        "type": "text",
        "text": {
            "body": text,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(url, json=body, headers=headers)
            return resp.status_code in [200, 201]
    except Exception as e:
        logger.error(f"WhatsApp alert API exception: {str(e)}")
        return False


async def upload_to_cloudinary(base64_image: str, cloud_name: str, upload_preset: str) -> str:
    file_data = base64_image
    if not file_data.startswith("data:"):
        file_data = f"data:image/jpeg;base64,{base64_image}"

    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
    data = {
        "file": file_data,
        "upload_preset": upload_preset
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, data=data)
        if resp.status_code != 200:
            raise Exception(f"Cloudinary upload failed: {resp.status_code} - {resp.text}")
        res_json = resp.json()
        return res_json["secure_url"]


async def send_pwa_notification_to_roles(roles: list, title: str, body: str, data: dict, db: AsyncSession):
    try:
        stmt = select(FcmToken.token).join(User).where(User.role.in_(roles))
        res = await db.execute(stmt)
        tokens = list(res.scalars().all())
        if tokens:
            await send_fcm_notification(tokens=tokens, title=title, body=body, data=data)
    except Exception as e:
        logger.error(f"Failed to dispatch FCM push notification to roles: {str(e)}")


async def send_pwa_notification_to_user(user_id: str, title: str, body: str, data: dict, db: AsyncSession):
    try:
        stmt = select(FcmToken.token).where(FcmToken.userId == user_id)
        res = await db.execute(stmt)
        tokens = list(res.scalars().all())
        if tokens:
            await send_fcm_notification(tokens=tokens, title=title, body=body, data=data)
    except Exception as e:
        logger.error(f"Failed to dispatch FCM push notification to user: {str(e)}")


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Place a secure checkout order. Evaluates store timings, geocodes, stocks, and promo codes.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    
    # Check if account is blocked
    user_stmt = select(User).where(User.id == user_id)
    user_res = await db.execute(user_stmt)
    user_obj = user_res.scalars().first()

    if user_obj and getattr(user_obj, "isBlocked", False):
        reason = getattr(user_obj, "blockReason", None)
        raise HTTPException(
            status_code=403,
            detail=f"Your account has been blocked from placing orders.{f' Reason: {reason}' if reason else ' Please contact support.'}"
        )

    address_id = payload.get("addressId")
    payment_method = payload.get("paymentMethod")
    items = payload.get("items", [])
    coupon_code = payload.get("couponCode")
    delivery_method = payload.get("deliveryMethod", "DELIVERY")
    is_b2b = payload.get("isB2B", False)
    scheduled_slot = payload.get("scheduledSlot", "INSTANT")
    shop_name = payload.get("shopName")
    shop_phone = payload.get("shopPhone")
    store_id = payload.get("storeId")
    packaging_option = payload.get("packagingOption", "NORMAL")
    packaging_fee = float(payload.get("packagingFee", 0.0))

    if not payment_method or not items:
        raise HTTPException(status_code=400, detail="Missing required fields")

    if delivery_method != "PICKUP" and not address_id:
        raise HTTPException(status_code=400, detail="Delivery address is required")

    # Fetch store settings flat map
    settings_stmt = select(StoreSetting)
    settings_res = await db.execute(settings_stmt)
    settings_map = {s.key: s.value for s in settings_res.scalars().all()}

    default_support_phone = settings_map.get("contact_phone", "+917054470303")
    
    # 1. Resolve address
    final_address_id = address_id
    if delivery_method == "PICKUP":
        default_pickup_address = settings_map.get("contact_address", "Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206")
        addr_parts = [p.strip() for p in default_pickup_address.split(",")]
        
        house_no = addr_parts[0] if len(addr_parts) > 0 else "Vikas Medical Store"
        street = addr_parts[1] if len(addr_parts) > 1 else "NH34, Ghatampur"
        area = addr_parts[2] if len(addr_parts) > 2 else "Kanpur Nagar"
        city = addr_parts[3] if len(addr_parts) > 3 else "Kanpur"
        pincode = addr_parts[4] if len(addr_parts) > 4 else "209206"

        pickup_addr_stmt = select(Address).where(Address.userId == user_id, Address.label == "STORE_PICKUP")
        pickup_addr_res = await db.execute(pickup_addr_stmt)
        pickup_address = pickup_addr_res.scalars().first()

        if not pickup_address:
            pickup_address = Address(
                id=f"addr_{uuid.uuid4().hex[:16]}",
                userId=user_id,
                label="STORE_PICKUP",
                houseNo=house_no,
                street=street,
                area=area,
                city=city,
                pincode=pincode,
                phone=default_support_phone
            )
            db.add(pickup_address)
        else:
            pickup_address.houseNo = house_no
            pickup_address.street = street
            pickup_address.area = area
            pickup_address.city = city
            pickup_address.pincode = pincode
            pickup_address.phone = default_support_phone
        
        await db.commit()
        final_address_id = pickup_address.id

    address_stmt = select(Address).where(Address.id == final_address_id, Address.userId == user_id)
    address_res = await db.execute(address_stmt)
    address = address_res.scalars().first()

    if not address:
        raise HTTPException(status_code=400, detail="Selected address is invalid")

    # Distance-based delivery zone validation
    delivery_rules = None
    if delivery_method == "DELIVERY":
        p = (address.pincode or "").strip().replace(" ", "")
        serviceable_pincode = settings_map.get("serviceable_pincode", "209206").strip().replace(" ", "")
        
        if not p or p != serviceable_pincode:
            raise HTTPException(
                status_code=400,
                detail=f"Selected address is outside our delivery zone. FastKirana delivers strictly to Ghatampur (Pincode: {serviceable_pincode})."
            )

        c = (address.city or "").strip().lower()
        if "ghatampur" not in c:
            raise HTTPException(
                status_code=400,
                detail="Selected address city is outside our delivery zone. Delivery is available in Ghatampur only."
            )

        # Geocode if lat/lng is missing
        target_lat = address.lat
        target_lng = address.lng
        if target_lat is None or target_lng is None:
            address_query = f"{address.houseNo or ''} {address.street or ''} {address.area or ''}, {address.city or 'Ghatampur'}, {address.pincode or '209206'}"
            coords = await geocode_address(address_query)
            if coords:
                target_lat = coords["lat"]
                target_lng = coords["lng"]
                address.lat = target_lat
                address.lng = target_lng
                await db.commit()

        if target_lat is not None and target_lng is not None:
            store_lat = float(settings_map.get("store_lat", 26.1534185))
            store_lng = float(settings_map.get("store_lng", 80.1714024))
            max_radius = float(settings_map.get("delivery_radius", settings_map.get("max_delivery_radius", 5.0)))
            surge_charge = float(settings_map.get("surge_charge", 0.0))

            dist_km = get_distance_km(store_lat, store_lng, target_lat, target_lng)
            delivery_rules = get_delivery_rules(dist_km, max_radius, surge_charge)

            if not delivery_rules["isServiceable"] or dist_km > max_radius:
                raise HTTPException(
                    status_code=400,
                    detail=f"Your location is {dist_km:.1f} km away. Delivery is strictly limited to {max_radius:.1f} km from Ghatampur Store."
                )

    # Store timings check
    def is_store_open(prefix: str) -> bool:
        auto_timing = settings_map.get(f"{prefix}_auto_timing") == "true"
        if not auto_timing:
            if prefix == "grocery":
                return settings_map.get("grocery_mart_open") != "false"
            return settings_map.get("restaurant_open") != "false"

        open_time = settings_map.get(f"{prefix}_open_time", "09:00")
        close_time = settings_map.get(f"{prefix}_close_time", "22:00")

        # India timezone offset
        ist = datetime.utcnow() + timedelta(hours=5, minutes=30)
        curr_mins = ist.hour * 60 + ist.minute

        o_h, o_m = map(int, open_time.split(":"))
        c_h, c_m = map(int, close_time.split(":"))

        open_mins = o_h * 60 + o_m
        close_mins = c_h * 60 + c_m

        if close_mins >= open_mins:
            return open_mins <= curr_mins <= close_mins
        else:
            return curr_mins >= open_mins or curr_mins <= close_mins

    # Load products and validate quantities
    product_ids = [i["product"]["id"].split("_")[0] for i in items]
    product_slugs = [i["product"]["slug"] for i in items if i["product"].get("slug")]

    p_stmt = select(Product).options(selectinload(Product.category)).where(
        or_(Product.id.in_(product_ids), Product.slug.in_(product_slugs))
    )
    p_res = await db.execute(p_stmt)
    db_products = p_res.scalars().all()

    grocery_items = []
    restaurant_groups = {}

    for item in items:
        prod_payload = item["product"]
        is_variant = "_" in prod_payload["id"]
        product_id, variant_name = prod_payload["id"].split("_") if is_variant else (prod_payload["id"], None)

        db_prod = next((p for p in db_products if p.id == product_id), None)
        if not db_prod and prod_payload.get("slug"):
            db_prod = next((p for p in db_products if p.slug == prod_payload["slug"]), None)

        if not db_prod or not db_prod.isAvailable:
            raise HTTPException(status_code=400, detail=f"Product \"{prod_payload.get('name')}\" is no longer available")

        # Stock check
        db_stock = db_prod.stock
        if is_variant and db_prod.variants:
            variant = next((v for v in db_prod.variants if v.get("name") == variant_name), None)
            if variant:
                db_stock = variant.get("stock", 0)

        is_restaurant = bool(db_prod.restaurantId)
        if is_restaurant:
            db_stock = 999999

        if db_stock < int(item["quantity"]):
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(status_code=400, detail=f"Insufficient stock for product \"{db_prod.name}{name_suffix}\"")

        # Limits check
        limit = get_product_limit(db_prod)
        if int(item["quantity"]) > limit:
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(status_code=400, detail=f"Maximum order limit of {limit} units exceeded for product \"{db_prod.name}{name_suffix}\"")

        item_with_db = {**item, "dbProduct": db_prod}
        if is_restaurant:
            r_id = db_prod.restaurantId
            if r_id not in restaurant_groups:
                # Load restaurant details from Restaurant table
                rest_stmt = select(Restaurant).where(Restaurant.id == r_id)
                rest_res = await db.execute(rest_stmt)
                restaurant = rest_res.scalars().first()
                
                if not restaurant or not restaurant.isOpen or not restaurant.isActive:
                    r_name = restaurant.name if restaurant else "Restaurant"
                    raise HTTPException(status_code=400, detail=f"{r_name} is temporarily closed.")
                
                # Load restaurant details
                res_stmt = select(User).where(User.assignedRestaurantId == r_id)
                res_res = await db.execute(res_stmt)
                owner = res_res.scalars().first()
                owner_phone = owner.phone if owner else "+91 81128 49854"
                
                restaurant_groups[r_id] = {
                    "name": restaurant.name,
                    "ownerPhone": owner_phone,
                    "items": []
                }
            restaurant_groups[r_id]["items"].append(item_with_db)
        else:
            grocery_items.append(item_with_db)

    # Enforce single restaurant checkout constraint
    if len(restaurant_groups) > 1:
        raise HTTPException(
            status_code=400,
            detail="You can only order from 1 restaurant at a time. Please remove items from other restaurants before checkout."
        )

    # Open timings verification
    if grocery_items and not is_store_open("grocery"):
        raise HTTPException(status_code=400, detail="Grocery Mart is temporarily closed.")
    
    # Check overall subtotal
    combined_subtotal = 0.0
    for item in items:
        prod_payload = item["product"]
        is_variant = "_" in prod_payload["id"]
        product_id, variant_name = prod_payload["id"].split("_") if is_variant else (prod_payload["id"], None)

        db_prod = next((p for p in db_products if p.id == product_id), None)
        if not db_prod and prod_payload.get("slug"):
            db_prod = next((p for p in db_products if p.slug == prod_payload["slug"]), None)

        item_price = db_prod.price if db_prod else 0.0
        if db_prod and is_variant and db_prod.variants:
            variant = next((v for v in db_prod.variants if v.get("name") == variant_name), None)
            if variant:
                item_price = float(variant.get("price", item_price))

        combined_subtotal += item_price * int(item["quantity"])

    if combined_subtotal < 20.0:
        raise HTTPException(status_code=400, detail="Minimum order value of ₹20 is required to place an order.")

    # 3. Resolve Coupon Code
    combined_discount = 0.0
    coupon_id = None
    if coupon_code:
        coupon_stmt = select(Coupon).where(Coupon.code == coupon_code.strip().upper(), Coupon.isActive == True)
        coupon_res = await db.execute(coupon_stmt)
        coupon = coupon_res.scalars().first()

        if coupon:
            has_expired = coupon.expiresAt and coupon.expiresAt < datetime.utcnow()
            limit_reached = coupon.maxUses and coupon.usedCount >= coupon.maxUses

            if not has_expired and not limit_reached:
                can_use = True
                if coupon.oncePerCustomer:
                    used_stmt = select(func.count(Order.id)).where(
                        Order.userId == user_id,
                        Order.couponCode == coupon.code,
                        Order.status != "CANCELLED"
                    )
                    used_res = await db.execute(used_stmt)
                    if used_res.scalar() > 0:
                        can_use = False

                if can_use:
                    eligible_subtotal = combined_subtotal
                    meets_min_order = True

                    if coupon.categoryId:
                        cat_items = [i for i in items if next((p.categoryId for p in db_products if p.id == i["product"]["id"].split("_")[0]), None) == coupon.categoryId]
                        cat_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in cat_items)
                        if cat_subtotal == 0 or cat_subtotal < coupon.minOrder:
                            meets_min_order = False
                        eligible_subtotal = cat_subtotal
                    
                    elif coupon.restaurantId:
                        rest_items = [i for i in items if next((p.restaurantId for p in db_products if p.id == i["product"]["id"].split("_")[0]), None) == coupon.restaurantId]
                        rest_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in rest_items)
                        if rest_subtotal == 0 or rest_subtotal < coupon.minOrder:
                            meets_min_order = False
                        eligible_subtotal = rest_subtotal

                    else:
                        if combined_subtotal < coupon.minOrder:
                            meets_min_order = False

                    if meets_min_order:
                        coupon_id = coupon.id
                        if coupon.discountType == "FLAT":
                            combined_discount = min(coupon.value, eligible_subtotal)
                        elif coupon.discountType == "PERCENT":
                            combined_discount = (eligible_subtotal * coupon.value) / 100.0
                            if coupon.maxDiscount:
                                combined_discount = min(combined_discount, coupon.maxDiscount)

    # Taxes and fees
    server_misc_fee = float(settings_map.get("misc_fee", 0.0))
    is_premium_packaging = packaging_option == "PREMIUM" or packaging_fee == 15.0
    resolved_packaging_fee = 15.0 if is_premium_packaging else 0.0

    def get_order_subtotal(item_list: list) -> float:
        sub = 0.0
        for it in item_list:
            is_var = "_" in it["product"]["id"]
            p_id, var_name = it["product"]["id"].split("_") if is_var else (it["product"]["id"], None)
            item_price = it["dbProduct"].price
            if is_var and it["dbProduct"].variants:
                variant = next((v for v in it["dbProduct"].variants if v.get("name") == var_name), None)
                if variant:
                    item_price = float(variant.get("price", item_price))
            sub += item_price * int(it["quantity"])
        return sub

    grocery_subtotal = get_order_subtotal(grocery_items)
    
    restaurant_data = []
    for r_id, group in restaurant_groups.items():
        sub = get_order_subtotal(group["items"])
        restaurant_data.append({
            "rId": r_id,
            "ownerPhone": group["ownerPhone"],
            "items": group["items"],
            "subtotal": sub,
            "deliveryFee": 0.0
        })

    # Delivery Fee logic
    grocery_delivery_fee = 0.0
    delivery_fee_val = float(settings_map.get("delivery_fee", 30.0))

    if delivery_method == "DELIVERY" and not is_b2b:
        default_threshold = float(settings_map.get("grocery_free_delivery_threshold", 299.0))
        free_delivery_threshold = delivery_rules["freeDeliveryThreshold"] if delivery_rules else default_threshold
        applies_delivery_fee = combined_subtotal < free_delivery_threshold

        if applies_delivery_fee:
            fee_to_charge = delivery_rules["deliveryFee"] if delivery_rules else delivery_fee_val
            if grocery_items:
                grocery_delivery_fee = fee_to_charge
            elif restaurant_data:
                restaurant_data[0]["deliveryFee"] = fee_to_charge

    orders_to_create = []
    has_charged_misc_fee = False

    if grocery_items:
        g_discount = (grocery_subtotal / combined_subtotal) * combined_discount if combined_subtotal > 0 else 0.0
        applied_misc_fee = server_misc_fee if (delivery_method != "PICKUP" and not has_charged_misc_fee and not is_premium_packaging) else 0.0
        if applied_misc_fee > 0:
            has_charged_misc_fee = True
        
        g_total = grocery_subtotal - g_discount + grocery_delivery_fee + applied_misc_fee

        orders_to_create.append({
            "type": "GROCERY",
            "subtotal": grocery_subtotal,
            "discount": g_discount,
            "deliveryFee": grocery_delivery_fee,
            "taxes": 0.0,
            "miscFee": applied_misc_fee,
            "total": g_total,
            "items": grocery_items
        })

    for idx, r_data in enumerate(restaurant_data):
        r_discount = (r_data["subtotal"] / combined_subtotal) * combined_discount if combined_subtotal > 0 else 0.0
        r_packaging_fee = resolved_packaging_fee if idx == 0 else 0.0

        applied_misc_fee = r_packaging_fee if r_packaging_fee > 0 else (server_misc_fee if (delivery_method != "PICKUP" and not has_charged_misc_fee and not is_premium_packaging) else 0.0)
        if applied_misc_fee > 0:
            has_charged_misc_fee = True

        r_total = r_data["subtotal"] - r_discount + r_data["deliveryFee"] + applied_misc_fee

        orders_to_create.append({
            "type": "RESTAURANT",
            "restaurantId": r_data["rId"],
            "ownerPhone": r_data["ownerPhone"],
            "subtotal": r_data["subtotal"],
            "discount": r_discount,
            "deliveryFee": r_data["deliveryFee"],
            "taxes": 0.0,
            "miscFee": applied_misc_fee,
            "total": r_total,
            "items": r_data["items"],
            "notes": "✨ Premium Thermal Packaging Requested (+₹15)" if is_premium_packaging else None
        })

    # 5. Database transaction execution
    created_orders = []
    is_combined = len(orders_to_create) > 1
    combined_id = f"combined_{uuid.uuid4().hex[:9]}_{int(datetime.utcnow().timestamp())}" if is_combined else None

    try:
        # Atomic sequence read
        seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
        base_readable_id = str(seq_res.scalar())

        rest_index = 0
        for order_info in orders_to_create:
            order_readable_id = base_readable_id
            if is_combined:
                if order_info["type"] == "RESTAURANT":
                    rest_index += 1
                    order_readable_id = f"{base_readable_id}-R" if rest_index == 1 else f"{base_readable_id}-R{rest_index}"
                else:
                    order_readable_id = f"{base_readable_id}-G"

            # Calculate delivery time
            est_mins = 30 if order_info["type"] == "RESTAURANT" else 10
            estimated_delivery = datetime.utcnow() + timedelta(minutes=est_mins)

            order_address_id = final_address_id
            if delivery_method == "PICKUP":
                label = f"STORE_PICKUP_{order_info.get('restaurantId')}" if order_info["type"] == "RESTAURANT" else "STORE_PICKUP"
                p_address_text = settings_map.get("grocery_pickup_address", "Vikas Medical Store, Ghatampur") if order_info["type"] == "GROCERY" else settings_map.get("restaurant_pickup_address", "Dark Store Kitchens")
                p_phone = default_support_phone if order_info["type"] == "GROCERY" else order_info.get("ownerPhone", default_support_phone)

                parts = [pt.strip() for pt in p_address_text.split(",")]
                h_no = parts[0] if len(parts) > 0 else "Store Pickup"
                strt = parts[1] if len(parts) > 1 else "Ghatampur"
                ara = parts[2] if len(parts) > 2 else "Kanpur Nagar"
                ct = parts[3] if len(parts) > 3 else "Kanpur"
                pcode = parts[4] if len(parts) > 4 else "209206"

                addr_exist_stmt = select(Address).where(Address.userId == user_id, Address.label == label)
                addr_exist_res = await db.execute(addr_exist_stmt)
                pickup_address = addr_exist_res.scalars().first()

                if not pickup_address:
                    pickup_address = Address(
                        id=f"addr_{uuid.uuid4().hex[:16]}",
                        userId=user_id,
                        label=label,
                        houseNo=h_no,
                        street=strt,
                        area=ara,
                        city=ct,
                        pincode=pcode,
                        phone=p_phone
                    )
                    db.add(pickup_address)
                else:
                    pickup_address.houseNo = h_no
                    pickup_address.street = strt
                    pickup_address.area = ara
                    pickup_address.city = ct
                    pickup_address.pincode = pcode
                    pickup_address.phone = p_phone
                
                await db.commit()
                order_address_id = pickup_address.id

            # Sync address phone number to user profile if currently missing in system
            if address and address.phone:
                if not user_obj.phone or user_obj.phone.strip() == "":
                    user_obj.phone = address.phone.strip()

            new_order = Order(
                id=generate_id("ord_"),
                readableId=order_readable_id,
                userId=user_id,
                addressId=order_address_id,
                combinedId=combined_id,
                orderType=OrderType.RESTAURANT if order_info["type"] == "RESTAURANT" else OrderType.GROCERY,
                status=OrderStatus.PENDING,
                subtotal=round(order_info["subtotal"], 2),
                discount=round(order_info["discount"], 2),
                deliveryFee=round(order_info["deliveryFee"], 2),
                taxes=0.0,
                miscFee=round(order_info["miscFee"], 2),
                total=round(order_info["total"], 2),
                paymentMethod=PaymentMethod(payment_method),
                paymentStatus=PaymentStatus.PENDING,
                estimatedDelivery=estimated_delivery,
                deliveryMethod=delivery_method,
                isB2B=is_b2b,
                storeId=store_id,
                couponCode=coupon_code.strip().upper() if coupon_code else None,
                shopName="Restaurant" if order_info["type"] == "RESTAURANT" else "FastKirana Grocery",
                shopPhone=order_info.get("ownerPhone", default_support_phone) if order_info["type"] == "RESTAURANT" else default_support_phone,
                restaurantId=order_info.get("restaurantId"),
                notes=order_info.get("notes")
            )

            db.add(new_order)
            await db.commit()
            await db.refresh(new_order)

            # Insert Items & deduct stock
            for item in order_info["items"]:
                prod = item["dbProduct"]
                is_var = "_" in item["product"]["id"]
                var_name = item["product"]["id"].split("_")[1] if is_var else None

                cost_price = prod.costPrice or 0.0
                if is_var and prod.variants:
                    variant = next((v for v in prod.variants if v.get("name") == var_name), None)
                    if variant and "costPrice" in variant:
                        cost_price = float(variant["costPrice"])

                order_item = OrderItem(
                    id=generate_id("oi_"),
                    orderId=new_order.id,
                    productId=prod.id,
                    name=prod.name,
                    price=prod.price if not is_var else float(variant["price"]),
                    quantity=int(item["quantity"]),
                    imageUrl=prod.imageUrl,
                    selectedVariant=var_name,
                    costPrice=cost_price,
                    variants=prod.variants,
                    notes=item.get("notes")
                )
                db.add(order_item)

                # Deduct stock (Grocery only)
                if not prod.restaurantId:
                    qty = int(item["quantity"])
                    prev_stock = prod.stock
                    
                    if is_var and prod.variants:
                        updated_variants = []
                        for v in prod.variants:
                            if v.get("name") == var_name:
                                v["stock"] = max(0, v.get("stock", 0) - qty)
                            updated_variants.append(v)
                        new_total_stock = sum(v.get("stock", 0) for v in updated_variants)
                        
                        prod.variants = updated_variants
                        prod.stock = new_total_stock
                        
                        log = StockLog(
                            id=generate_id("sl_"),
                            productId=prod.id,
                            quantity=-qty,
                            type="ONLINE_ORDER",
                            prevStock=prev_stock,
                            newStock=new_total_stock
                        )
                        db.add(log)
                    else:
                        # Batch inward deductions
                        batch_stmt = select(ProductBatch).where(ProductBatch.productId == prod.id, ProductBatch.quantity > 0).order_by(ProductBatch.expiryDate.asc())
                        batch_res = await db.execute(batch_stmt)
                        batches = batch_res.scalars().all()

                        remaining = qty
                        for batch in batches:
                            if remaining <= 0:
                                break
                            deduct = min(batch.quantity, remaining)
                            batch.quantity -= deduct
                            remaining -= deduct

                        active_stmt = select(ProductBatch).where(ProductBatch.productId == prod.id, ProductBatch.quantity > 0).order_by(ProductBatch.expiryDate.asc())
                        active_res = await db.execute(active_stmt)
                        active_batches = active_res.scalars().all()

                        new_total_stock = sum(b.quantity for b in active_batches) if active_batches else max(0, prev_stock - qty)
                        new_expiry = active_batches[0].expiryDate if active_batches else None

                        prod.stock = new_total_stock
                        prod.expiryDate = new_expiry

                        log = StockLog(
                            id=generate_id("sl_"),
                            productId=prod.id,
                            quantity=-qty,
                            type="ONLINE_ORDER",
                            prevStock=prev_stock,
                            newStock=new_total_stock
                        )
                        db.add(log)

            created_orders.append(new_order)

        # Update coupon usage
        if coupon_id:
            c_stmt = select(Coupon).where(Coupon.id == coupon_id)
            c_res = await db.execute(c_stmt)
            c_obj = c_res.scalars().first()
            if c_obj:
                c_obj.usedCount += 1

        # Clear cart
        cart_stmt = select(Cart).where(Cart.userId == user_id)
        cart_res = await db.execute(cart_stmt)
        cart = cart_res.scalars().first()
        if cart:
            await db.execute(text("DELETE FROM cart_items WHERE \"cartId\" = :cart_id"), {"cart_id": cart.id})

        await db.commit()

        # Dispatch real-time WebSocket alerts
        for order in created_orders:
            # Broadcast to general websocket
            await manager.broadcast_to_channel("general", {
                "type": "new-order",
                "orderId": order.id,
                "readableId": order.readableId,
                "shopName": order.shopName,
                "status": order.status.value,
                "total": float(order.total),
                "createdAt": order.createdAt.isoformat(),
                "restaurantId": order.restaurantId,
            })

            # FCM Push notifications to workers
            title = "New Order Placed 🍲" if order.restaurantId else "New Grocery Order 📦"
            body = f"Order #{order.readableId} of ₹{order.total:.2f} has been placed."
            background_tasks.add_task(
                send_pwa_notification_to_roles,
                [Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER],
                title,
                body,
                {"orderId": order.id},
                db
            )

            # WhatsApp alerts to Admins/Staff
            admin_phones = []
            if settings_map.get("whatsapp_notify_7054470303") != "false":
                admin_phones.append("7054470303")
            if settings_map.get("whatsapp_notify_8112849854") != "false":
                admin_phones.append("8112849854")

            for phone in admin_phones:
                app_url = "fastkirana.com"
                admin_text = f"New Order #{order.readableId} for [{order.shopName}] of ₹{order.total} from {user_obj.name or 'Customer'} ({address.phone or 'N/A'}). Manage: {app_url}/admin"
                background_tasks.add_task(send_whatsapp_alert, phone, admin_text)

        # Return main order or first created order
        main_order = next((o for o in created_orders if o.orderType == OrderType.GROCERY), created_orders[0])
        
        # Format response matching Next.js Order response
        return {
            "id": main_order.id,
            "readableId": main_order.readableId,
            "userId": main_order.userId,
            "addressId": main_order.addressId,
            "status": main_order.status.value,
            "total": float(main_order.total),
            "paymentMethod": main_order.paymentMethod.value,
            "createdAt": main_order.createdAt
        }

    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to place order: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to place order: {str(e)}")


@router.get("")
async def list_orders(
    all: bool = False,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    List user orders (normal user gets combined view; staff gets dashboard flat view).
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    is_staff = role in ["ADMIN", "CHEF", "PICKER", "DELIVERY"]

    if is_staff and all:
        # Fetch all orders in the system with user details
        stmt = select(Order, User).join(User, Order.userId == User.id).options(
            selectinload(Order.items),
            selectinload(Order.address)
        ).order_by(Order.createdAt.desc()).limit(1000)
        
        res = await db.execute(stmt)
        rows = res.all()

        orders_list = []
        for order, user in rows:
            orders_list.append({
                "id": order.id,
                "readableId": order.readableId,
                "userId": order.userId,
                "addressId": order.addressId,
                "status": order.status.value,
                "subtotal": float(order.subtotal),
                "discount": float(order.discount),
                "deliveryFee": float(order.deliveryFee),
                "taxes": float(order.taxes),
                "miscFee": float(order.miscFee),
                "total": float(order.total),
                "paymentMethod": order.paymentMethod.value,
                "paymentStatus": order.paymentStatus.value,
                "estimatedDelivery": order.estimatedDelivery.isoformat() if order.estimatedDelivery else None,
                "createdAt": order.createdAt.isoformat() if order.createdAt else None,
                "updatedAt": order.updatedAt.isoformat() if order.updatedAt else None,
                "deliveryMethod": order.deliveryMethod,
                "isB2B": order.isB2B,
                "shopName": order.shopName,
                "shopPhone": order.shopPhone,
                "restaurantId": order.restaurantId,
                "userName": user.name,
                "userEmail": user.email,
                "userPhone": order.shopPhone or (order.address.phone if order.address else user.phone),
                "items": [{"id": i.id, "name": i.name, "quantity": i.quantity, "price": float(i.price), "imageUrl": i.imageUrl} for i in order.items],
                "address": {
                    "id": order.address.id,
                    "label": order.address.label,
                    "houseNo": order.address.houseNo,
                    "street": order.address.street,
                    "area": order.address.area,
                    "city": order.address.city,
                    "pincode": order.address.pincode,
                    "phone": order.address.phone
                } if order.address else None
            })
        return orders_list

    # Normal user fetches their orders
    email = current_user.get("email", "").lower().strip()
    phone = get_last_10_digits(current_user.get("phone", ""))

    # Find matching user IDs
    user_ids = {user_id}
    if email or phone:
        u_filters = []
        if email:
            u_filters.append(func.lower(User.email) == email)
        if phone:
            u_filters.append(User.phone.like(f"%{phone}"))
        
        users_stmt = select(User.id).where(or_(*u_filters))
        users_res = await db.execute(users_stmt)
        user_ids.update(users_res.scalars().all())

    # Query matching orders
    orders_stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address)
    ).where(Order.userId.in_(user_ids)).order_by(Order.createdAt.desc())
    
    orders_res = await db.execute(orders_stmt)
    raw_orders = orders_res.scalars().all()

    # Customer grouping
    def get_combined_status(statuses: List[str]) -> str:
        active = [s for s in statuses if s != "CANCELLED"]
        if not active:
            return "CANCELLED"
        if "PENDING" in active:
            return "PENDING"
        if "CONFIRMED" in active:
            return "CONFIRMED"
        if "PACKED" in active:
            return "PACKED"
        if "SHIPPED" in active:
            return "SHIPPED"
        return "DELIVERED"

    grouped_orders = []
    processed_ids = set()

    for ord in raw_orders:
        if ord.id in processed_ids:
            continue

        related = []
        for o in raw_orders:
            if o.id in processed_ids:
                continue
            if o.id == ord.id:
                related.append(o)
            elif ord.combinedId and o.combinedId == ord.combinedId:
                related.append(o)
            else:
                time_diff = abs((o.createdAt - ord.createdAt).total_seconds()) if o.createdAt and ord.createdAt else 999
                if o.userId == ord.userId and time_diff <= 10:
                    related.append(o)

        for r in related:
            processed_ids.add(r.id)

        if len(related) == 1:
            o = related[0]
            grouped_orders.append({
                "id": o.id,
                "readableId": o.readableId,
                "status": o.status.value,
                "subtotal": float(o.subtotal or 0.0),
                "discount": float(o.discount or 0.0),
                "deliveryFee": float(o.deliveryFee or 0.0),
                "taxes": float(o.taxes or 0.0),
                "miscFee": float(o.miscFee or 0.0),
                "total": float(o.total or 0.0),
                "paymentMethod": o.paymentMethod.value,
                "paymentStatus": o.paymentStatus.value,
                "deliveryMethod": o.deliveryMethod or "DELIVERY",
                "createdAt": o.createdAt.isoformat() if o.createdAt else None,
                "shopName": o.shopName,
                "items": [{"id": i.id, "name": i.name, "quantity": i.quantity, "price": float(i.price), "imageUrl": i.imageUrl} for i in o.items],
                "address": {
                    "id": o.address.id,
                    "label": o.address.label,
                    "houseNo": o.address.houseNo,
                    "street": o.address.street,
                    "area": o.address.area,
                    "city": o.address.city,
                    "pincode": o.address.pincode,
                    "phone": o.address.phone
                } if o.address else None,
                "isCombined": False
            })
        else:
            main_order = next((r for r in related if r.orderType != OrderType.RESTAURANT), related[0])
            statuses = [r.status.value for r in related]
            combined_status = get_combined_status(statuses)

            all_items = []
            seen_item_ids = set()
            for r in related:
                for i in r.items:
                    if i.id not in seen_item_ids:
                        seen_item_ids.add(i.id)
                        all_items.append({"id": i.id, "name": i.name, "quantity": i.quantity, "price": float(i.price), "imageUrl": i.imageUrl})

            base_readable_id = re.sub(r'-[GR\d]+$', '', main_order.readableId or "")

            grouped_orders.append({
                "id": main_order.id,
                "readableId": base_readable_id,
                "status": combined_status,
                "subtotal": sum(float(r.subtotal or 0.0) for r in related),
                "discount": sum(float(r.discount or 0.0) for r in related),
                "deliveryFee": sum(float(r.deliveryFee or 0.0) for r in related),
                "taxes": sum(float(r.taxes or 0.0) for r in related),
                "miscFee": sum(float(r.miscFee or 0.0) for r in related),
                "total": sum(float(r.total or 0.0) for r in related),
                "paymentMethod": main_order.paymentMethod.value,
                "paymentStatus": main_order.paymentStatus.value,
                "deliveryMethod": main_order.deliveryMethod or "DELIVERY",
                "createdAt": main_order.createdAt.isoformat() if main_order.createdAt else None,
                "shopName": main_order.shopName,
                "items": all_items,
                "address": {
                    "id": main_order.address.id,
                    "label": main_order.address.label,
                    "houseNo": main_order.address.houseNo,
                    "street": main_order.address.street,
                    "area": main_order.address.area,
                    "city": main_order.address.city,
                    "pincode": main_order.address.pincode,
                    "phone": main_order.address.phone
                } if main_order.address else None,
                "isCombined": True
            })

    grouped_orders.sort(key=lambda x: x["createdAt"] or "", reverse=True)
    return grouped_orders


@router.get("/{id}")
async def get_order_details(
    id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed order history. Supports combined checkouts and shields worker details.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    is_staff = role in ["ADMIN", "CHEF", "DELIVERY", "PICKER", "RESTAURANT_OWNER"]

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(or_(Order.id == id, Order.readableId == id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Access Authorization Guard
    if not is_staff and order.userId != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized to view this order")

    # Fetch delivery executive details
    delivery_user = None
    if order.deliveryUserId:
        rider_stmt = select(User).where(User.id == order.deliveryUserId)
        rider_res = await db.execute(rider_stmt)
        rider = rider_res.scalars().first()
        if rider:
            name = rider.name or "FastKirana Delivery Executive"
            phone = rider.phone or "+919696503759"
            
            # Mask internal Admin details
            if rider.role == Role.ADMIN or name == "Admin":
                main_rider_stmt = select(User).where(User.role == Role.DELIVERY)
                main_rider_res = await db.execute(main_rider_stmt)
                main_rider = main_rider_res.scalars().first()
                if main_rider:
                    name = main_rider.name or "FastKirana Delivery Executive"
                    phone = main_rider.phone or "+919696503759"
            
            delivery_user = {"name": name, "phone": phone}

    # Sibling orders formatting for combined order types
    if order.combinedId:
        comb_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(comb_stmt)
        combined_orders = comb_res.scalars().all()

        if len(combined_orders) > 1:
            all_items = []
            for co in combined_orders:
                all_items.extend(co.items)

            def get_combined_status(statuses: List[str]) -> str:
                active = [s for s in statuses if s != "CANCELLED"]
                if not active:
                    return "CANCELLED"
                if "PENDING" in active:
                    return "PENDING"
                if "CONFIRMED" in active:
                    return "CONFIRMED"
                if "PACKED" in active:
                    return "PACKED"
                if "SHIPPED" in active:
                    return "SHIPPED"
                return "DELIVERED"

            statuses = [o.status.value for o in combined_orders]
            combined_status = get_combined_status(statuses)

            base_readable_id = re.sub(r'-[GR\d]+$', '', order.readableId or "")

            sub_orders = []
            for co in combined_orders:
                is_rest = co.orderType == OrderType.RESTAURANT or bool(co.restaurantId)
                sub_orders.append({
                    "id": co.id,
                    "readableId": co.readableId,
                    "type": "RESTAURANT" if is_rest else "GROCERY",
                    "shopName": co.shopName or ("Restaurant" if is_rest else "FastKirana Grocery"),
                    "status": co.status.value,
                    "subtotal": float(co.subtotal),
                    "total": float(co.total),
                    "itemsCount": len(co.items),
                    "items": [{"id": i.id, "name": i.name, "quantity": i.quantity, "price": float(i.price), "imageUrl": i.imageUrl} for i in co.items],
                })

            grocery_sub = next((s for s in sub_orders if s["type"] == "GROCERY"), None)
            restaurant_sub = next((s for s in sub_orders if s["type"] == "RESTAURANT"), None)

            return {
                "id": order.id,
                "userId": order.userId,
                "addressId": order.addressId,
                "readableId": base_readable_id,
                "baseReadableId": base_readable_id,
                "status": combined_status,
                "subtotal": sum(float(co.subtotal) for co in combined_orders),
                "discount": sum(float(co.discount) for co in combined_orders),
                "deliveryFee": sum(float(co.deliveryFee) for co in combined_orders),
                "taxes": sum(float(co.taxes) for co in combined_orders),
                "miscFee": sum(float(co.miscFee) for co in combined_orders),
                "total": sum(float(co.total) for co in combined_orders),
                "paymentMethod": order.paymentMethod.value,
                "paymentStatus": order.paymentStatus.value,
                "estimatedDelivery": order.estimatedDelivery.isoformat() if order.estimatedDelivery else None,
                "createdAt": order.createdAt.isoformat() if order.createdAt else None,
                "updatedAt": order.updatedAt.isoformat() if order.updatedAt else None,
                "deliveryMethod": order.deliveryMethod,
                "isB2B": order.isB2B,
                "shopName": order.shopName,
                "shopPhone": order.shopPhone,
                "deliveryLat": order.deliveryLat,
                "deliveryLng": order.deliveryLng,
                "notes": order.notes,
                "couponCode": order.couponCode,
                "items": [{"id": i.id, "productId": i.productId, "name": i.name, "price": float(i.price), "quantity": i.quantity, "imageUrl": i.imageUrl} for i in all_items],
                "address": {
                    "id": order.address.id,
                    "label": order.address.label,
                    "houseNo": order.address.houseNo,
                    "street": order.address.street,
                    "area": order.address.area,
                    "city": order.address.city,
                    "pincode": order.address.pincode,
                    "phone": order.address.phone
                } if order.address else None,
                "deliveryUser": delivery_user,
                "isCombined": True,
                "groceryStatus": grocery_sub["status"] if grocery_sub else None,
                "groceryItems": grocery_sub["items"] if grocery_sub else [],
                "restaurantStatus": restaurant_sub["status"] if restaurant_sub else None,
                "restaurantName": restaurant_sub["shopName"] if restaurant_sub else None,
                "restaurantItems": restaurant_sub["items"] if restaurant_sub else [],
                "subOrders": sub_orders
            }

    # Single order payload fallback
    return {
        "id": order.id,
        "readableId": order.readableId,
        "userId": order.userId,
        "addressId": order.addressId,
        "status": order.status.value,
        "subtotal": float(order.subtotal),
        "discount": float(order.discount),
        "deliveryFee": float(order.deliveryFee),
        "taxes": float(order.taxes),
        "miscFee": float(order.miscFee),
        "total": float(order.total),
        "paymentMethod": order.paymentMethod.value,
        "paymentStatus": order.paymentStatus.value,
        "estimatedDelivery": order.estimatedDelivery.isoformat() if order.estimatedDelivery else None,
        "createdAt": order.createdAt.isoformat() if order.createdAt else None,
        "updatedAt": order.updatedAt.isoformat() if order.updatedAt else None,
        "deliveryMethod": order.deliveryMethod,
        "isB2B": order.isB2B,
        "shopName": order.shopName,
        "shopPhone": order.shopPhone,
        "deliveryLat": order.deliveryLat,
        "deliveryLng": order.deliveryLng,
        "notes": order.notes,
        "couponCode": order.couponCode,
        "items": [{"id": i.id, "productId": i.productId, "name": i.name, "price": float(i.price), "quantity": i.quantity, "imageUrl": i.imageUrl} for i in order.items],
        "address": {
            "id": order.address.id,
            "label": order.address.label,
            "houseNo": order.address.houseNo,
            "street": order.address.street,
            "area": order.address.area,
            "city": order.address.city,
            "pincode": order.address.pincode,
            "phone": order.address.phone
        } if order.address else None,
        "deliveryUser": delivery_user
    }


@router.patch("/{id}")
async def update_order(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Update order workflow status, claim pickers/riders, deduct stock, and notify clients.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")

    stmt = select(Order).where(or_(Order.id == id, Order.readableId == id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    target_status_str = payload.get("status")
    delivery_photo = payload.get("deliveryPhoto")
    delivery_lat = payload.get("deliveryLat")
    delivery_lng = payload.get("deliveryLng")
    prep_time = payload.get("prepTime")
    is_rider_cash = payload.get("isRiderCash", True)
    payment_collected_by = payload.get("paymentCollectedBy")

    if not target_status_str:
        raise HTTPException(status_code=400, detail="status is required")

    try:
        target_status = OrderStatus(target_status_str)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid order status: {target_status_str}")

    # Authorization Check
    is_admin = role == "ADMIN"
    is_delivery = role == "DELIVERY"
    is_picker = role == "PICKER"
    is_restaurant_staff = role in ["CHEF", "RESTAURANT_OWNER"]
    is_owner = order.userId == user_id

    if not is_owner and not is_admin and not is_delivery and not is_picker and not is_restaurant_staff:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if is_restaurant_staff and not is_admin:
        if not assigned_restaurant_id or order.restaurantId != assigned_restaurant_id:
            raise HTTPException(status_code=403, detail="You can only manage orders for your assigned restaurant")

    # Claim locks
    if target_status == OrderStatus.CONFIRMED:
        if role == Role.CHEF or order.orderType == OrderType.RESTAURANT or order.restaurantId:
            if order.assignedChefId and order.assignedChefId != user_id:
                raise HTTPException(status_code=409, detail="Order is already claimed by another chef")
        else:
            if order.assignedPickerId and order.assignedPickerId != user_id:
                raise HTTPException(status_code=409, detail="Order is already claimed by another picker")

    if target_status == OrderStatus.SHIPPED:
        if order.deliveryUserId and order.deliveryUserId != user_id:
            raise HTTPException(status_code=409, detail="Order is already claimed by another delivery rider")

    # Deduct stock on PACKED state transition
    if target_status == OrderStatus.PACKED and order.status != OrderStatus.PACKED:
        items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
        items_res = await db.execute(items_stmt)
        order_items = items_res.scalars().all()
        
        for item in order_items:
            if not item.productId:
                continue
            prod_stmt = select(Product).where(Product.id == item.productId)
            prod_res = await db.execute(prod_stmt)
            product = prod_res.scalars().first()
            if product:
                product.stock = max(0, product.stock - item.quantity)

    # Restore stock on CANCELLED state transition
    if target_status == OrderStatus.CANCELLED and order.status != OrderStatus.CANCELLED:
        items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
        items_res = await db.execute(items_stmt)
        order_items = items_res.scalars().all()

        for item in order_items:
            if not item.productId:
                continue
            
            prod_stmt = select(Product).options(selectinload(Product.category)).where(Product.id == item.productId)
            prod_res = await db.execute(prod_stmt)
            product = prod_res.scalars().first()

            if not product:
                continue

            # Skip stock restoration for Cafe & Restaurant items
            p_type = get_product_type(product)
            if p_type in ["CAFE", "RESTAURANT"]:
                continue

            if item.selectedVariant:
                if product.variants:
                    updated_variants = []
                    for v in product.variants:
                        if v.get("name") == item.selectedVariant:
                            v["stock"] = v.get("stock", 0) + item.quantity
                        updated_variants.append(v)
                    new_total_stock = sum(v.get("stock", 0) for v in updated_variants)
                    product.variants = updated_variants
                    product.stock = new_total_stock
            else:
                batches_stmt = select(ProductBatch).where(ProductBatch.productId == item.productId).order_by(ProductBatch.expiryDate.asc())
                batches_res = await db.execute(batches_stmt)
                batches = batches_res.scalars().all()

                if batches:
                    batches[0].quantity += item.quantity
                    product.stock = sum(b.quantity for b in batches)
                else:
                    product.stock += item.quantity

    # Cloudinary upload on deliver pings
    final_delivery_photo = delivery_photo
    if target_status == OrderStatus.DELIVERED and delivery_photo and isinstance(delivery_photo, str):
        is_base64 = delivery_photo.startswith("data:image/") or (not delivery_photo.startswith("http") and len(delivery_photo) > 100)
        if is_base64:
            try:
                # Fetch settings for Cloudinary config
                settings_stmt = select(StoreSetting).where(StoreSetting.key.in_(["cloudinary_cloud_name", "cloudinary_upload_preset"]))
                settings_res = await db.execute(settings_stmt)
                settings_map = {s.key: s.value for s in settings_res.scalars().all()}
                
                cloud_name = settings_map.get("cloudinary_cloud_name")
                upload_preset = settings_map.get("cloudinary_upload_preset")

                if cloud_name and upload_preset:
                    cloudinary_url = await upload_to_cloudinary(delivery_photo, cloud_name, upload_preset)
                    final_delivery_photo = cloudinary_url
            except Exception as e:
                logger.error(f"Cloudinary upload fallback: {str(e)}")

    # Update database values
    order.status = target_status
    order.updatedAt = datetime.utcnow()

    if target_status == OrderStatus.DELIVERED:
        # Prevent database length overflow for delivery photo
        safe_photo = final_delivery_photo
        if safe_photo and safe_photo.startswith("data:") and len(safe_photo) > 200000:
            safe_photo = None

        is_owner_or_online = payment_collected_by in ["OWNER", "ONLINE"] or not is_rider_cash
        new_payment_method = "UPI" if is_owner_or_online else (order.paymentMethod.value if order.paymentMethod.value in ["COD", "UPI", "CARD", "WALLET"] else "COD")

        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = PaymentMethod(new_payment_method)
        order.deliveryPhoto = safe_photo
        order.deliveryLat = float(delivery_lat) if delivery_lat is not None else None
        order.deliveryLng = float(delivery_lng) if delivery_lng is not None else None
        order.deliveredAt = datetime.utcnow()

        # Update Rider Wallet for COD order
        is_rider_cash_collected = not is_owner_or_online and (is_rider_cash is not False)
        if order.paymentMethod == PaymentMethod.COD and is_rider_cash_collected and order.deliveryUserId:
            wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
            wallet_res = await db.execute(wallet_stmt)
            wallet = wallet_res.scalars().first()

            order_total = float(order.total)
            if wallet:
                wallet.cashInHand += order_total
                wallet.totalCollected += order_total
            else:
                wallet = RiderWallet(
                    id=f"rw_{order.deliveryUserId}",
                    userId=order.deliveryUserId,
                    cashInHand=order_total,
                    cashLimit=2000.0,
                    totalCollected=order_total,
                    totalDeposited=0.0
                )
                db.add(wallet)

    elif target_status == OrderStatus.SHIPPED:
        order.deliveryUserId = user_id
        if delivery_lat is not None and delivery_lng is not None:
            order.deliveryLat = float(delivery_lat)
            order.deliveryLng = float(delivery_lng)
        order.shippedAt = datetime.utcnow()

    elif target_status == OrderStatus.PACKED:
        order.packedAt = datetime.utcnow()

    elif target_status == OrderStatus.CONFIRMED:
        order.confirmedAt = datetime.utcnow()
        if role == Role.CHEF or order.orderType == OrderType.RESTAURANT or order.restaurantId:
            order.assignedChefId = user_id
        else:
            order.assignedPickerId = user_id

        if prep_time and str(prep_time).isdigit():
            order.estimatedDelivery = datetime.utcnow() + timedelta(minutes=int(prep_time))

    # Sibling synchronization
    if order.combinedId:
        sibling_stmt = select(Order).where(Order.combinedId == order.combinedId, Order.id != order.id)
        sibling_res = await db.execute(sibling_stmt)
        companion = sibling_res.scalars().first()

        if companion:
            companion.status = order.status
            companion.updatedAt = datetime.utcnow()
            if order.deliveryUserId:
                companion.deliveryUserId = order.deliveryUserId
            if target_status == OrderStatus.DELIVERED:
                companion.paymentStatus = PaymentStatus.PAID
                companion.deliveredAt = datetime.utcnow()

    await db.commit()
    await db.refresh(order)

    # Dispatch real-time WebSocket alerts
    await manager.broadcast_to_channel("general", {
        "event": "STATUS_UPDATE",
        "orderId": order.id,
        "status": order.status.value,
        "order": {
            "id": order.id,
            "status": order.status.value,
            "total": float(order.total),
            "updatedAt": order.updatedAt.isoformat()
        }
    })
    
    await manager.broadcast_to_channel(f"order_{order.id}", {
        "event": "STATUS_UPDATE",
        "orderId": order.id,
        "status": order.status.value,
        "lat": order.deliveryLat,
        "lng": order.deliveryLng
    })

    # Trigger PWA Push Notification for customer and staff roles
    status_labels = {
        "CONFIRMED": "Confirmed by Store 🏪",
        "PACKED": "Packed & Ready to Go 📦",
        "SHIPPED": "Out for Delivery 🚴",
        "DELIVERED": "Delivered Successfully 🎉",
        "CANCELLED": "Cancelled ❌",
    }
    
    base_order_no = re.sub(r'-[GR\d]+$', '', order.readableId or "")
    status_title = f"Order #{base_order_no}: {status_labels.get(order.status.value, order.status.value)}"
    status_body = f"Your FastKirana order #{base_order_no} is now {status_labels.get(order.status.value, order.status.value)}."

    background_tasks.add_task(
        send_pwa_notification_to_user,
        order.userId,
        status_title,
        status_body,
        {"orderId": order.id, "status": order.status.value},
        db
    )

    background_tasks.add_task(
        send_pwa_notification_to_roles,
        [Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER],
        f"Order #{base_order_no} Updated 🔄",
        f"Order #{base_order_no} status changed to {status_labels.get(order.status.value, order.status.value)}.",
        {"orderId": order.id, "status": order.status.value},
        db
    )

    return {
        "id": order.id,
        "status": order.status.value,
        "total": float(order.total),
        "createdAt": order.createdAt,
        "updatedAt": order.updatedAt,
        "deliveryPhoto": order.deliveryPhoto,
        "deliveryLat": order.deliveryLat,
        "deliveryLng": order.deliveryLng,
        "assignedPickerId": order.assignedPickerId,
        "assignedChefId": order.assignedChefId,
        "deliveryUserId": order.deliveryUserId,
        "confirmedAt": order.confirmedAt,
        "packedAt": order.packedAt,
        "shippedAt": order.shippedAt,
        "deliveredAt": order.deliveredAt
    }


@router.patch("/{order_id}/status")
async def update_order_status_alias(
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Alias route for status updates.
    """
    return await update_order(order_id=order_id, payload=payload, current_user=current_user, db=db, background_tasks=background_tasks)


@router.get("/{order_id}/track")
async def track_order(
    order_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Real-time order tracking details with delivery partner status & ETA.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    is_staff = role in ["ADMIN", "CHEF", "DELIVERY", "PICKER", "RESTAURANT_OWNER"]

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address)
    ).where(or_(Order.id == order_id, Order.readableId == order_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if not is_staff and order.userId != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    rider_info = None
    if order.deliveryUserId:
        rider_stmt = select(User).where(User.id == order.deliveryUserId)
        rider_res = await db.execute(rider_stmt)
        rider = rider_res.scalars().first()
        if rider:
            rider_info = {
                "id": rider.id,
                "name": rider.name or "Delivery Executive",
                "phone": rider.phone,
                "lat": rider.liveLat or 26.1495,
                "lng": rider.liveLng or 80.1672
            }

    status_steps = [
        {"status": "PENDING", "label": "Order Placed", "completed": True, "time": order.createdAt.isoformat() if order.createdAt else None},
        {"status": "CONFIRMED", "label": "Order Confirmed", "completed": order.confirmedAt is not None, "time": order.confirmedAt.isoformat() if order.confirmedAt else None},
        {"status": "PACKED", "label": "Packing / Preparing", "completed": order.packedAt is not None, "time": order.packedAt.isoformat() if order.packedAt else None},
        {"status": "SHIPPED", "label": "Out for Delivery", "completed": order.shippedAt is not None or order.status == OrderStatus.SHIPPED, "time": order.shippedAt.isoformat() if order.shippedAt else None},
        {"status": "DELIVERED", "label": "Delivered", "completed": order.deliveredAt is not None or order.status == OrderStatus.DELIVERED, "time": order.deliveredAt.isoformat() if order.deliveredAt else None}
    ]

    return {
        "orderId": order.id,
        "readableId": order.readableId,
        "status": order.status.value,
        "estimatedDeliveryMinutes": 10 if order.status.value in ["CONFIRMED", "PACKED", "SHIPPED"] else 0,
        "rider": rider_info,
        "shopName": order.shopName,
        "total": float(order.total),
        "steps": status_steps,
        "address": {
            "houseNo": order.address.houseNo,
            "street": order.address.street,
            "city": order.address.city
        } if order.address else None
    }
