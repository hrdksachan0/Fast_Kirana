from fastapi import APIRouter, Depends, HTTPException, status, Body, BackgroundTasks, Header, Request, Query
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

from database import get_db, AsyncSessionLocal
from models import (
    Order, OrderItem, Product, User, Address, RiderWallet, 
    OrderStatus, PaymentStatus, PaymentMethod, OrderType, Role,
    StoreSetting, Coupon, FcmToken, ProductBatch, StockLog, Restaurant, Cart, CartItem
)
from routers.auth import require_auth, get_current_user
from routers.websockets import manager
from utils.firebase import send_fcm_notification, send_fcm_topic_notification
from routers.orders_service import generate_id, get_last_10_digits, get_distance_km, validate_order_status_transition

logger = logging.getLogger("orders")

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])


def get_delivery_rules(distance_km: float, max_radius_km: float = 5.0, surge_fee: float = 0.0) -> dict:
    if distance_km > max_radius_km:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": 0.0,
            "freeDeliveryThreshold": 499.0,
            "isServiceable": False,
            "zoneName": f"Outside Delivery Zone (> {max_radius_km:.1f} km)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }
    
    # Zone 1: 0 - 2.0 km (Local Ghatampur)
    if distance_km <= 2.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": 25.0 + surge_fee,
            "freeDeliveryThreshold": 199.0,
            "isServiceable": True,
            "zoneName": "0 - 2 km (Local Ghatampur Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 2: 2.0 - 3.0 km (Suburban Zone)
    if distance_km <= 3.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": 35.0 + surge_fee,
            "freeDeliveryThreshold": 299.0,
            "isServiceable": True,
            "zoneName": "2 - 3 km (Suburban Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 3: 3.0 - 5.0 km (Extended Zone)
    if distance_km <= 5.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": 50.0 + surge_fee,
            "freeDeliveryThreshold": 399.0,
            "isServiceable": True,
            "zoneName": "3 - 5 km (Extended Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    return {
        "distanceKm": distance_km,
        "minOrder": 0.0,
        "deliveryFee": 70.0 + surge_fee,
        "freeDeliveryThreshold": 499.0,
        "isServiceable": False,
        "zoneName": f"Outside Delivery Zone (> {max_radius_km:.1f} km)",
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
async def send_whatsapp_alert(phone: str, message: str):
    logger.info(f"[WHATSAPP MOCK] To {phone}: {message}")


async def upload_to_cloudinary(base64_data: str, cloud_name: str, upload_preset: str) -> str:
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(url, data={"file": base64_data, "upload_preset": upload_preset})
        if resp.status_code != 200:
            raise Exception(f"Cloudinary upload failed: {resp.status_code} - {resp.text}")
        res_json = resp.json()
        return res_json["secure_url"]


async def send_pwa_notification_to_roles(roles: list, title: str, body: str, data: dict, db: AsyncSession = None):
    try:
        # 1. Send to broad staff topic
        await send_fcm_topic_notification("staff_orders", title, body, data)

        # 2. Also send to individual registered tokens
        async with AsyncSessionLocal() as session:
            stmt = select(FcmToken.token).join(User).where(User.role.in_(roles))
            res = await session.execute(stmt)
            tokens = list(res.scalars().all())
            if tokens:
                await send_fcm_notification(tokens=tokens, title=title, body=body, data=data)
    except Exception as e:
        logger.error(f"Failed to dispatch FCM push notification to roles: {str(e)}")


async def send_pwa_notification_to_user(user_id: str, title: str, body: str, data: dict, db: AsyncSession = None, phone: str = None):
    try:
        # 1. Send direct to user topic
        if user_id:
            await send_fcm_topic_notification(f"user_{user_id}", title, body, data)

        # 2. Look up user phone if not provided
        target_phone = phone
        if not target_phone and user_id:
            async with AsyncSessionLocal() as session:
                user_stmt = select(User).where(User.id == user_id)
                user_res = await session.execute(user_stmt)
                user = user_res.scalars().first()
                if user and user.phone:
                    target_phone = user.phone

        # 3. Send to phone topic (e.g. phone_8112849854)
        if target_phone:
            clean_phone = str(target_phone).replace("+91", "").replace(" ", "").replace("-", "").strip()
            if clean_phone:
                await send_fcm_topic_notification(f"phone_{clean_phone}", title, body, data)

        # 4. Also send to registered device tokens if any
        if user_id:
            async with AsyncSessionLocal() as session:
                stmt = select(FcmToken.token).where(FcmToken.userId == user_id)
                res = await session.execute(stmt)
                tokens = list(res.scalars().all())
                if tokens:
                    await send_fcm_notification(tokens=tokens, title=title, body=body, data=data)
    except Exception as e:
        logger.error(f"Failed to dispatch FCM push notification to user: {str(e)}")


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: Dict[str, Any] = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Place a secure checkout order. Evaluates store timings, geocodes, stocks, and promo codes.
    """
    user_id = current_user.get("id") or current_user.get("sub") if current_user else payload.get("userId")
    
    # If no user_id, resolve or create guest user
    if not user_id:
        phone = payload.get("phone") or "7054470303"
        clean_phone = phone.replace("+91", "").strip()
        guest_stmt = select(User).where(User.phone == clean_phone)
        guest_res = await db.execute(guest_stmt)
        guest_user = guest_res.scalars().first()
        if not guest_user:
            guest_id = f"guest_{generate_id()}"
            guest_user = User(
                id=guest_id,
                name=payload.get("userName") or "FastKirana Customer",
                email=f"{clean_phone}@guest.fastkirana.in",
                phone=clean_phone,
                role="USER"
            )
            db.add(guest_user)
            await db.flush()
        user_id = guest_user.id

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
    raw_pm = str(payload.get("paymentMethod") or "COD").upper()
    if raw_pm in ["RAZORPAY", "ONLINE", "UPI", "GPAY", "PHONEPE", "PAYTM"]:
        payment_method = "UPI"
    elif raw_pm in ["CARD", "DEBIT", "CREDIT"]:
        payment_method = "CARD"
    elif raw_pm in ["WALLET"]:
        payment_method = "WALLET"
    else:
        payment_method = "COD"

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

    if not items:
        raise HTTPException(status_code=400, detail="Missing required fields")

    # Normalize items format so both Web {"product": {"id": ...}} and Mobile {"productId": "..."} work 100%
    normalized_items = []
    for raw_item in items:
        if isinstance(raw_item, dict) and "product" in raw_item and isinstance(raw_item["product"], dict):
            prod_dict = raw_item["product"]
            prod_id = prod_dict.get("id") or raw_item.get("productId")
            prod_name = prod_dict.get("name") or raw_item.get("name", "Product")
            prod_slug = prod_dict.get("slug")
            prod_price = float(raw_item.get("price") or prod_dict.get("price", 0.0))
        elif isinstance(raw_item, dict):
            prod_id = raw_item.get("productId") or raw_item.get("id")
            prod_name = raw_item.get("name", "Product")
            prod_slug = raw_item.get("slug")
            prod_price = float(raw_item.get("price", 0.0))
        else:
            continue

        normalized_items.append({
            "product": {
                "id": str(prod_id) if prod_id else "",
                "name": prod_name,
                "slug": prod_slug,
                "price": prod_price,
            },
            "productId": str(prod_id).split("_")[0] if prod_id else None,
            "quantity": int(raw_item.get("quantity", 1)),
            "price": prod_price,
            "selectedVariant": raw_item.get("selectedVariant"),
            "notes": raw_item.get("notes"),
        })
    items = normalized_items

    if not items:
        raise HTTPException(status_code=400, detail="No valid items in order")

    if delivery_method != "PICKUP" and not address_id:
        user_addr_stmt = select(Address).where(Address.userId == user_id)
        user_addr_res = await db.execute(user_addr_stmt)
        existing_addr = user_addr_res.scalars().first()
        if existing_addr:
            address_id = existing_addr.id
            final_address_id = existing_addr.id
        else:
            new_addr_id = f"addr_{uuid.uuid4().hex[:16]}"
            new_address = Address(
                id=new_addr_id,
                userId=user_id,
                label="Home",
                houseNo="Ghatampur Express Zone",
                street="NH34 Main Road",
                area="Ghatampur",
                city="Kanpur Nagar",
                pincode="209206",
                phone=payload.get("phone") or "7054470303",
                lat=26.1534,
                lng=80.1714,
                isDefault=True
            )
            db.add(new_address)
            await db.flush()
            address_id = new_addr_id
            final_address_id = new_addr_id

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

    address_stmt = select(Address).where(Address.id == final_address_id)
    address_res = await db.execute(address_stmt)
    address = address_res.scalars().first()

    if not address:
        raise HTTPException(status_code=400, detail="Selected address is invalid")

    # Distance-based delivery zone validation
    delivery_rules = None
    if delivery_method == "DELIVERY":
        p = (address.pincode or "").strip().replace(" ", "")
        serviceable_pincode = settings_map.get("serviceable_pincode", "209206").strip().replace(" ", "")
        allowed_pincodes = [serviceable_pincode, "209206", "209201", "209214", "209208", "208001", "208002", "208011", "208012", "208020"]
        
        if p and p not in allowed_pincodes and not (len(p) == 6 and p.isdigit()):
            raise HTTPException(
                status_code=400,
                detail=f"Selected address pincode ({p}) is outside our delivery zone."
            )

        c = (address.city or "").strip().lower()
        allowed_cities = ["ghatampur", "kanpur", "nagar", "dehat", "up", "uttar pradesh"]
        if c and not any(k in c for k in allowed_cities):
            raise HTTPException(
                status_code=400,
                detail="Selected address city is outside our delivery zone."
            )

        # Update phone if passed
        raw_phone = payload.get("phone") or payload.get("customerPhone")
        if raw_phone and address:
            clean_p = "".join(filter(str.isdigit, str(raw_phone)))[-10:]
            if len(clean_p) == 10:
                address.phone = f"+91{clean_p}"
                await db.commit()

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
        # Always allow order placement (24x7 Express Delivery)
        if settings_map.get(f"{prefix}_force_closed") == "true":
            return False
        return True

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

    # Packaging and handling charge
    server_misc_fee = float(settings_map.get("misc_fee", 5.0))
    packaging_fee_input = float(payload.get("packagingFee", payload.get("packaging_fee", 0.0)))
    is_premium_packaging = packaging_option == "PREMIUM" or packaging_fee == 15.0 or packaging_fee_input > 0
    resolved_packaging_fee = packaging_fee_input if packaging_fee_input > 0 else (15.0 if is_premium_packaging else (server_misc_fee if restaurant_id else 5.0))

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
            "subtotal": sub
        })

    # 5. Determine Restaurant & Shop Context
    restaurant_id = restaurant_data[0]["rId"] if restaurant_data else None
    restaurant_obj = restaurant_groups.get(restaurant_id) if restaurant_id else None
    final_shop_name = restaurant_obj["name"] if restaurant_obj else "FastKirana Grocery"
    final_shop_phone = restaurant_obj.get("ownerPhone", default_support_phone) if restaurant_obj else default_support_phone

    # Calculate unified order amounts
    subtotal = combined_subtotal
    discount = combined_discount
    delivery_fee_val = float(settings_map.get("delivery_fee", 25.0))
    delivery_fee_charge = 0.0

    if delivery_method == "DELIVERY" and not is_b2b:
        default_threshold = float(settings_map.get("grocery_free_delivery_threshold", 199.0))
        free_delivery_threshold = delivery_rules["freeDeliveryThreshold"] if delivery_rules else default_threshold
        if subtotal < free_delivery_threshold:
            delivery_fee_charge = delivery_rules["deliveryFee"] if delivery_rules else delivery_fee_val

    misc_fee_charge = resolved_packaging_fee if is_premium_packaging else (server_misc_fee if delivery_method != "PICKUP" else 0.0)
    final_total = max(0.0, subtotal - discount + delivery_fee_charge + misc_fee_charge)

    # 6. Create 1 Single Unified Order
    created_orders = []
    try:
        seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
        readable_id = str(seq_res.scalar())

        est_mins = 30 if restaurant_id else 10
        estimated_delivery = datetime.utcnow() + timedelta(minutes=est_mins)

        order_address_id = final_address_id
        if delivery_method == "PICKUP":
            label = "STORE_PICKUP"
            p_address_text = settings_map.get("grocery_pickup_address", "Vikas Medical Store, NH34, Ghatampur, 209206")
            p_phone = default_support_phone

            addr_exist_stmt = select(Address).where(Address.userId == user_id, Address.label == label)
            addr_exist_res = await db.execute(addr_exist_stmt)
            pickup_address = addr_exist_res.scalars().first()

            if not pickup_address:
                parts = [pt.strip() for pt in p_address_text.split(",")]
                pickup_address = Address(
                    id=f"addr_{uuid.uuid4().hex[:16]}",
                    userId=user_id,
                    label=label,
                    houseNo=parts[0] if len(parts) > 0 else "Store Pickup",
                    street=parts[1] if len(parts) > 1 else "NH34",
                    area=parts[2] if len(parts) > 2 else "Ghatampur",
                    city=parts[3] if len(parts) > 3 else "Kanpur",
                    pincode=parts[4] if len(parts) > 4 else "209206",
                    phone=p_phone
                )
                db.add(pickup_address)
                await db.flush()
            order_address_id = pickup_address.id

        new_order = Order(
            id=generate_id("ord_"),
            readableId=readable_id,
            userId=user_id,
            addressId=order_address_id,
            orderType=OrderType.RESTAURANT if restaurant_id else OrderType.GROCERY,
            status=OrderStatus.PENDING,
            subtotal=round(subtotal, 2),
            discount=round(discount, 2),
            deliveryFee=round(delivery_fee_charge, 2),
            taxes=0.0,
            miscFee=round(misc_fee_charge, 2),
            total=round(final_total, 2),
            paymentMethod=PaymentMethod(payment_method),
            paymentStatus=PaymentStatus.PAID if (payload.get("paymentStatus") == "PAID" or payload.get("paymentId")) else PaymentStatus.PENDING,
            estimatedDelivery=estimated_delivery,
            deliveryMethod=delivery_method,
            isB2B=is_b2b,
            storeId=store_id,
            couponCode=coupon_code.strip().upper() if coupon_code else None,
            shopName=final_shop_name,
            shopPhone=final_shop_phone,
            restaurantId=restaurant_id,
            notes="✨ Premium Thermal Packaging Requested (+₹15)" if is_premium_packaging else None
        )

        db.add(new_order)
        await db.commit()
        await db.refresh(new_order)

        # Attach all items & decrement stock for grocery
        for item in items:
            prod = item["dbProduct"]
            is_var = "_" in item["product"]["id"]
            var_name = item["product"]["id"].split("_")[1] if is_var else None

            cost_price = prod.costPrice or 0.0
            item_price = prod.price
            if is_var and prod.variants:
                variant = next((v for v in prod.variants if v.get("name") == var_name), None)
                if variant:
                    item_price = float(variant.get("price", item_price))
                    cost_price = float(variant.get("costPrice", cost_price))

            order_item = OrderItem(
                id=generate_id("oi_"),
                orderId=new_order.id,
                productId=prod.id,
                name=prod.name,
                price=item_price,
                quantity=int(item["quantity"]),
                imageUrl=prod.imageUrl,
                selectedVariant=var_name,
                costPrice=cost_price,
                variants=prod.variants,
                notes=item.get("notes")
            )
            db.add(order_item)

            # Stock deduction for grocery items
            if not prod.restaurantId and prod.stock > 0:
                qty = int(item["quantity"])
                prev_stock = prod.stock
                new_stock = max(0, prev_stock - qty)
                prod.stock = new_stock

                log = StockLog(
                    id=generate_id("sl_"),
                    productId=prod.id,
                    quantity=-qty,
                    type="ONLINE_ORDER",
                    prevStock=prev_stock,
                    newStock=new_stock
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

            # 1. FCM Push Notification directly to Customer
            customer_title = "🎉 Order Placed Successfully!"
            customer_body = f"Your order #{order.readableId} of ₹{order.total:.2f} has been placed with FastKirana Express! ⚡"
            background_tasks.add_task(
                send_pwa_notification_to_user,
                order.userId,
                customer_title,
                customer_body,
                {"orderId": order.id, "status": order.status.value, "type": "ORDER_PLACED"},
                None,
                address.phone if address else None
            )

            # 2. FCM Push notifications to workers
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
            if settings_map.get("order_alert_phone"):
                clean = re.sub(r'\D', '', str(settings_map["order_alert_phone"]))[-10:]
                if clean and clean not in admin_phones:
                    admin_phones.append(clean)
            if settings_map.get("contact_phone"):
                clean = re.sub(r'\D', '', str(settings_map["contact_phone"]))[-10:]
                if clean and clean not in admin_phones:
                    admin_phones.append(clean)

            for phone in admin_phones:
                app_url = "fastkirana.com"
                admin_text = f"New Order #{order.readableId} for [{order.shopName}] of ₹{order.total} from {user_obj.name or 'Customer'} ({address.phone or 'N/A'}). Manage: {app_url}/admin"
                background_tasks.add_task(send_whatsapp_alert, phone, admin_text)

        # Return full order object matching Flutter Order.fromJson expectations
        return {
            "id": main_order.id,
            "readableId": main_order.readableId,
            "userId": main_order.userId,
            "addressId": main_order.addressId,
            "restaurantId": main_order.restaurantId,
            "status": main_order.status.value,
            "subtotal": float(main_order.subtotal or 0),
            "discount": float(main_order.discount or 0),
            "deliveryFee": float(main_order.deliveryFee or 0),
            "taxes": float(main_order.taxes or 0),
            "miscFee": float(main_order.miscFee or 0),
            "packagingFee": float(main_order.miscFee or 0),
            "total": float(main_order.total or 0),
            "paymentMethod": main_order.paymentMethod.value,
            "paymentStatus": main_order.paymentStatus.value,
            "estimatedDelivery": main_order.estimatedDelivery.isoformat() if main_order.estimatedDelivery else None,
            "deliveryMethod": main_order.deliveryMethod,
            "isB2B": main_order.isB2B,
            "shopName": main_order.shopName,
            "shopPhone": main_order.shopPhone,
            "notes": main_order.notes,
            "couponCode": main_order.couponCode,
            "customerName": user_obj.name,
            "customerPhone": user_obj.phone or (address.phone if address else None),
            "customerAddress": f"{address.houseNo or ''}, {address.street or ''}, {address.area or ''}, {address.city or ''}, {address.pincode or ''}" if address else None,
            "createdAt": main_order.createdAt.isoformat() if main_order.createdAt else None,
            "updatedAt": main_order.updatedAt.isoformat() if main_order.updatedAt else None,
            "confirmedAt": main_order.confirmedAt.isoformat() if main_order.confirmedAt else None,
            "packedAt": main_order.packedAt.isoformat() if main_order.packedAt else None,
            "shippedAt": main_order.shippedAt.isoformat() if main_order.shippedAt else None,
            "deliveredAt": main_order.deliveredAt.isoformat() if main_order.deliveredAt else None,
            "items": [{"id": i.id, "name": i.name, "quantity": i.quantity, "price": float(i.price), "imageUrl": i.imageUrl, "selectedVariant": i.selectedVariant} for i in main_order.items],
            "address": {
                "id": address.id,
                "houseNo": address.houseNo,
                "street": address.street,
                "area": address.area,
                "city": address.city,
                "pincode": address.pincode,
                "phone": address.phone,
                "label": address.label,
            } if address else None,
        }

    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to place order: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to place order: {str(e)}")


@router.get("")
async def list_orders(
    all: bool = False,
    userId: Optional[str] = Query(None),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List user orders (normal user gets combined view; staff gets dashboard flat view).
    """
    user_id = current_user.get("id") or current_user.get("sub") if current_user else userId
    role = current_user.get("role") if current_user else None
    is_staff = role in ["ADMIN", "CHEF", "PICKER", "DELIVERY"]

    if not user_id and not is_staff:
        return []

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
                "shopName": o.shopName or ("FastKirana DarkStore" if not o.restaurantId else "Restaurant"),
                "restaurantId": o.restaurantId,
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
                "shopName": main_order.shopName or ("FastKirana DarkStore" if not main_order.restaurantId else "Restaurant"),
                "restaurantId": main_order.restaurantId,
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
    request: Request,
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

    stmt = select(Order).where(or_(
        Order.id == id,
        Order.readableId == id,
        Order.readableId.ilike(f"{id}%"),
        Order.combinedId == id
    ))
    res = await db.execute(stmt)
    orders_matched = res.scalars().all()

    if not orders_matched:
        raise HTTPException(status_code=404, detail="Order not found")

    order = orders_matched[0]

    target_status_str = payload.get("status")
    delivery_photo = payload.get("deliveryPhoto")
    delivery_lat = payload.get("deliveryLat")
    delivery_lng = payload.get("deliveryLng")
    prep_time = payload.get("prepTime")
    is_rider_cash = payload.get("isRiderCash", True)
    payment_collected_by = payload.get("paymentCollectedBy")

    if not target_status_str:
        raise HTTPException(status_code=400, detail="status is required")

    status_alias_map = {
        "PREPARING": OrderStatus.CONFIRMED,
        "PROCESSING": OrderStatus.CONFIRMED,
        "READY": OrderStatus.PACKED,
        "OUT_FOR_DELIVERY": OrderStatus.SHIPPED,
        "COMPLETED": OrderStatus.DELIVERED,
    }

    raw_status_str = str(target_status_str).upper()
    if raw_status_str in status_alias_map:
        target_status = status_alias_map[raw_status_str]
    else:
        try:
            target_status = OrderStatus(raw_status_str)
        except ValueError:
            target_status = OrderStatus.CONFIRMED

    # Authorization Check
    is_admin = role == "ADMIN"
    is_delivery = role == "DELIVERY"
    is_picker = role == "PICKER"
    is_restaurant_staff = role in ["CHEF", "RESTAURANT_OWNER"]
    is_owner = order.userId == user_id
    is_restaurant_order = bool(order.restaurantId or order.orderType == OrderType.RESTAURANT)

    if not is_owner and not is_admin and not is_delivery and not is_picker and not is_restaurant_staff:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Strict Role Assignment for Status Transitions
    if target_status == OrderStatus.CANCELLED:
        if not (is_owner or is_admin or is_picker or is_restaurant_staff or is_delivery):
            raise HTTPException(status_code=403, detail="Unauthorized to cancel this order")
    elif target_status in [OrderStatus.CONFIRMED, OrderStatus.PACKED]:
        if is_restaurant_order:
            if not (is_admin or is_restaurant_staff):
                raise HTTPException(status_code=403, detail="Only restaurant staff can accept or pack restaurant orders")
        else:
            if not (is_admin or is_picker):
                raise HTTPException(status_code=403, detail="Only Dark Store pickers can accept or pack grocery orders")
    elif target_status in [OrderStatus.SHIPPED, OrderStatus.DELIVERED]:
        if not (is_admin or is_delivery):
            raise HTTPException(status_code=403, detail="Only delivery riders can ship or deliver orders")

    if is_restaurant_staff and not is_admin:
        if not assigned_restaurant_id:
            user_stmt = select(User.assignedRestaurantId).where(User.id == user_id)
            user_res = await db.execute(user_stmt)
            assigned_restaurant_id = user_res.scalar_one_or_none()
        if assigned_restaurant_id and order.restaurantId and order.restaurantId != assigned_restaurant_id:
            raise HTTPException(status_code=403, detail="You can only manage orders for your assigned restaurant")

    # Claim locks
    if target_status == OrderStatus.CONFIRMED:
        if is_restaurant_order:
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

        cash_amount_custom = payload.get("cashAmount")
        is_owner_or_online = payment_collected_by in ["OWNER", "ONLINE"] or is_rider_cash is False

        if cash_amount_custom is not None:
            try:
                order_cash_collected = max(0.0, float(cash_amount_custom))
            except (ValueError, TypeError):
                order_cash_collected = float(order.total) if not is_owner_or_online else 0.0
        else:
            order_cash_collected = float(order.total) if not is_owner_or_online else 0.0

        new_payment_method = "UPI" if (is_owner_or_online and order_cash_collected == 0) else (order.paymentMethod.value if order.paymentMethod.value in ["COD", "UPI", "CARD", "WALLET"] else "COD")

        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = PaymentMethod(new_payment_method)
        order.deliveryPhoto = safe_photo
        order.deliveryLat = float(delivery_lat) if delivery_lat is not None else None
        order.deliveryLng = float(delivery_lng) if delivery_lng is not None else None
        order.deliveredAt = datetime.utcnow()

        # Update Rider Wallet for Cash collected
        if order_cash_collected > 0 and order.deliveryUserId:
            wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
            wallet_res = await db.execute(wallet_stmt)
            wallet = wallet_res.scalars().first()

            if wallet:
                wallet.cashInHand += order_cash_collected
                wallet.totalCollected += order_cash_collected
            else:
                wallet = RiderWallet(
                    id=f"rw_{order.deliveryUserId}",
                    userId=order.deliveryUserId,
                    cashInHand=order_cash_collected,
                    cashLimit=2000.0,
                    totalCollected=order_cash_collected,
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
        "readableId": order.readableId,
        "status": order.status.value,
        "total": float(order.total),
        "paymentMethod": order.paymentMethod.value,
        "paymentStatus": order.paymentStatus.value,
        "estimatedDelivery": order.estimatedDelivery.isoformat() if order.estimatedDelivery else None,
        "createdAt": order.createdAt.isoformat() if order.createdAt else None,
        "updatedAt": order.updatedAt.isoformat() if order.updatedAt else None,
        "deliveryPhoto": order.deliveryPhoto,
        "deliveryLat": order.deliveryLat,
        "deliveryLng": order.deliveryLng,
        "deliveryMethod": order.deliveryMethod,
        "deliveryUserId": order.deliveryUserId,
        "assignedPickerId": order.assignedPickerId,
        "assignedChefId": order.assignedChefId,
        "confirmedAt": order.confirmedAt.isoformat() if order.confirmedAt else None,
        "packedAt": order.packedAt.isoformat() if order.packedAt else None,
        "shippedAt": order.shippedAt.isoformat() if order.shippedAt else None,
        "deliveredAt": order.deliveredAt.isoformat() if order.deliveredAt else None,
        "shopName": order.shopName,
        "shopPhone": order.shopPhone,
        "notes": order.notes,
        "couponCode": order.couponCode,
        "deliveryUser": delivery_user,
    }


@router.patch("/{order_id}/status")
async def update_order_status_alias(
    request: Request,
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Alias route for status updates.
    """
    return await update_order(request=request, id=order_id, payload=payload, current_user=current_user, db=db, background_tasks=background_tasks)


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


@router.delete("/cancelled-orders")
async def delete_all_cancelled_orders(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Purge all cancelled orders and their child items from database. (ADMIN ONLY)
    """
    role = current_user.get("role")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only ADMIN can bulk delete cancelled orders")

    res = await db.execute(select(Order.id).where(Order.status == OrderStatus.CANCELLED))
    cancelled_ids = list(res.scalars().all())

    if not cancelled_ids:
        return {"message": "No cancelled orders found", "deletedCount": 0}

    await db.execute(delete(OrderItem).where(OrderItem.orderId.in_(cancelled_ids)))
    await db.execute(delete(Order).where(Order.id.in_(cancelled_ids)))
    await db.commit()

    return {"message": f"Successfully deleted {len(cancelled_ids)} cancelled orders", "deletedCount": len(cancelled_ids)}


@router.patch("/{id}/payment")
async def update_order_payment(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Admin route to edit/override order payment method (COD, UPI, CARD) and adjust Rider Cash In Hand.
    """
    role = current_user.get("role")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only ADMIN can edit order payment details")

    stmt = select(Order).where(Order.id == id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_method = payload.get("paymentMethod")
    new_status = payload.get("paymentStatus")
    cash_collected = payload.get("cashAmount")

    old_method = order.paymentMethod.value
    order_total = float(order.total)

    if new_method:
        try:
            order.paymentMethod = PaymentMethod(new_method.upper())
        except ValueError:
            pass

    if new_status:
        try:
            order.paymentStatus = PaymentStatus(new_status.upper())
        except ValueError:
            pass

    # Adjust Rider Wallet if rider was assigned
    if order.deliveryUserId:
        wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
        wallet_res = await db.execute(wallet_stmt)
        wallet = wallet_res.scalars().first()

        if wallet:
            # If changing from COD to UPI -> reduce cashInHand by order_total
            if old_method == "COD" and new_method in ["UPI", "CARD", "ONLINE"]:
                wallet.cashInHand = max(0.0, float(wallet.cashInHand) - order_total)
            # If changing from UPI to COD -> add order_total to cashInHand
            elif old_method != "COD" and new_method == "COD":
                wallet.cashInHand = float(wallet.cashInHand) + order_total

            # If explicit custom cashAmount provided
            if cash_collected is not None:
                wallet.cashInHand = max(0.0, float(cash_collected))

    await db.commit()
    await db.refresh(order)

    return {
        "message": "Order payment updated successfully",
        "orderId": order.id,
        "paymentMethod": order.paymentMethod.value,
        "paymentStatus": order.paymentStatus.value
    }
