from fastapi import APIRouter, Depends, HTTPException, status, Body, BackgroundTasks, Header, Request, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, and_, or_, func, text, not_, delete
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
    StoreSetting, Coupon, FcmToken, ProductBatch, StockLog, Restaurant, Cart, CartItem, Vendor, DarkStore
)
from routers.auth import require_auth, get_current_user
from routers.websockets import manager
from utils.firebase import send_fcm_notification, send_fcm_topic_notification
from routers.orders_service import generate_id, get_last_10_digits, get_distance_km, validate_order_status_transition
from utils.idempotency import generate_order_cart_signature, acquire_idempotency_lock, save_idempotency_response, release_idempotency_lock

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
        logger.info(f"[WHATSAPP MOCK] To {phone}: {text}")
        return True

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


async def upload_to_cloudinary(base64_data: str, cloud_name: str, upload_preset: str) -> str:
    file_data = base64_data
    if not file_data.startswith("data:"):
        file_data = f"data:image/jpeg;base64,{base64_data}"
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(url, data={"file": file_data, "upload_preset": upload_preset})
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


async def dispatch_isolated_order_fcm_notifications(
    order_id: str,
    readable_id: str,
    restaurant_id: Optional[str],
    shop_name: Optional[str],
    total: float,
    status_val: str,
    store_id: Optional[str] = None
):
    """
    Dispatches order notifications with absolute isolation:
    - Restaurant orders ONLY alert restaurant-specific topics & assigned staff. Never grocery pickers.
    - Grocery orders ONLY alert darkstore pickers. Never restaurant consoles or chefs.
    """
    try:
        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        if restaurant_id:
            # 1. RESTAURANT / KITCHEN ISOLATED NOTIFICATION
            rest_title = f"👨‍🍳 New Order for {shop_name or 'Kitchen'}!"
            rest_body = f"Order #{readable_id} received (₹{total:.2f})! Open kitchen console to prepare dishes."
            rest_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "restaurantId": str(restaurant_id),
                "status": status_val,
                "screen": "restaurant-console",
                "type": "NEW_ORDER",
                "timestamp": now_ts,
            }

            # Broadcast to restaurant-specific topics ONLY
            await send_fcm_topic_notification(f"restaurant_{restaurant_id}", rest_title, rest_body, rest_data)
            await send_fcm_topic_notification(f"kitchen_{restaurant_id}", rest_title, rest_body, rest_data)
            await send_fcm_topic_notification(f"restaurant_orders_{restaurant_id}", rest_title, rest_body, rest_data)

            # Direct FCM push to chefs & owners assigned ONLY to this specific restaurant
            async with AsyncSessionLocal() as session:
                rest_res = await session.execute(select(Restaurant).where(Restaurant.id == restaurant_id))
                rest_obj = rest_res.scalars().first()
                clean_owner_phone = ""
                if rest_obj and rest_obj.ownerPhone:
                    clean_owner_phone = re.sub(r'\D', '', str(rest_obj.ownerPhone))[-10:]

                user_filter = [User.assignedRestaurantId == restaurant_id]
                if clean_owner_phone:
                    user_filter.append(User.phone.contains(clean_owner_phone))

                stmt = select(FcmToken.token).join(User).where(or_(*user_filter))
                res = await session.execute(stmt)
                tokens = list(set(res.scalars().all()))
                if tokens:
                    await send_fcm_notification(tokens=tokens, title=rest_title, body=rest_body, data=rest_data)

                if clean_owner_phone:
                    await send_fcm_topic_notification(f"phone_{clean_owner_phone}", rest_title, rest_body, rest_data)

            # Notify Delivery Riders & Admins
            admin_rider_title = f"🍽️ Food Order Placed #{readable_id}"
            admin_rider_body = f"Order #{readable_id} for {shop_name or 'Restaurant'} (₹{total:.2f})."
            admin_rider_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "restaurantId": str(restaurant_id),
                "status": status_val,
                "screen": "delivery",
                "type": "NEW_ORDER",
                "role": "DELIVERY",
                "timestamp": now_ts,
            }
            await send_fcm_topic_notification("admin_orders", admin_rider_title, admin_rider_body, admin_rider_data)
            await send_fcm_topic_notification("delivery_orders", admin_rider_title, admin_rider_body, admin_rider_data)

        else:
            # 2. GROCERY DARK STORE ISOLATED NOTIFICATION
            store_label = f" [{store_id.replace('hub-', '').upper()}]" if store_id else ""
            grocery_title = f"📦 New Order #{readable_id} to Pick!{store_label}"
            grocery_body = f"New order #{readable_id} of ₹{total:.2f}. Tap to pack items."
            grocery_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "storeId": str(store_id or ""),
                "status": status_val,
                "screen": "picker",
                "type": "NEW_ORDER",
                "role": "PICKER",
                "timestamp": now_ts,
            }

            admin_rider_title = f"🛵 New Delivery Order #{readable_id}{store_label}"
            admin_rider_body = f"New grocery order #{readable_id} of ₹{total:.2f} placed."
            admin_rider_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "storeId": str(store_id or ""),
                "status": status_val,
                "screen": "delivery",
                "type": "NEW_ORDER",
                "role": "DELIVERY",
                "timestamp": now_ts,
            }

            # STRICT HUB ISOLATION (Ghatampur vs Akbarpur):
            if store_id:
                # 1. Alert ONLY this specific hub's pickers & riders
                await send_fcm_topic_notification(f"picker_orders_{store_id}", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification(f"delivery_orders_{store_id}", admin_rider_title, admin_rider_body, admin_rider_data)
                await send_fcm_topic_notification(f"staff_orders_{store_id}", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification(f"admin_orders_{store_id}", admin_rider_title, admin_rider_body, admin_rider_data)

                # 2. Direct FCM tokens to staff assigned STRICTLY to this hub
                async with AsyncSessionLocal() as session:
                    picker_stmt = select(FcmToken.token).join(User).where(
                        and_(User.role == Role.PICKER, or_(User.assignedStoreId == store_id, User.assignedStoreId.is_(None)))
                    )
                    picker_res = await session.execute(picker_stmt)
                    picker_tokens = list(set(picker_res.scalars().all()))
                    if picker_tokens:
                        await send_fcm_notification(tokens=picker_tokens, title=grocery_title, body=grocery_body, data=grocery_data)

                    rider_stmt = select(FcmToken.token).join(User).where(
                        and_(User.role.in_([Role.DELIVERY, Role.RIDER]), or_(User.assignedStoreId == store_id, User.assignedStoreId.is_(None)))
                    )
                    rider_res = await session.execute(rider_stmt)
                    rider_tokens = list(set(rider_res.scalars().all()))
                    if rider_tokens:
                        await send_fcm_notification(tokens=rider_tokens, title=admin_rider_title, body=admin_rider_body, data=admin_rider_data)
            else:
                # Fallback only if no hub is assigned
                await send_fcm_topic_notification("picker_orders", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification("delivery_orders", admin_rider_title, admin_rider_body, admin_rider_data)
                await send_fcm_topic_notification("staff_orders", grocery_title, grocery_body, grocery_data)

            # Global admin topic (headquarters)
            await send_fcm_topic_notification("admin_orders", admin_rider_title, admin_rider_body, admin_rider_data)
    except Exception as e:
        logger.error(f"Failed to dispatch isolated FCM push notification: {str(e)}")


async def dispatch_isolated_status_update_notifications(
    order_id: str,
    readable_id: str,
    restaurant_id: Optional[str],
    shop_name: Optional[str],
    status_val: str,
    store_id: Optional[str] = None
):
    """
    Dispatches order status update notifications with strict outlet isolation:
    - Restaurant orders ONLY alert restaurant-specific topics & assigned chefs. Never grocery pickers or other restaurants.
    - Grocery orders ONLY alert darkstore pickers. Never restaurant consoles or chefs.
    """
    try:
        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        base_order_no = re.sub(r'-[GR\d]+$', '', readable_id or "")

        if restaurant_id:
            # 1. RESTAURANT / KITCHEN ISOLATED STATUS UPDATE
            rest_title = f"👨‍🍳 Order #{base_order_no} Status: {status_val}"
            rest_body = f"Order #{base_order_no} for {shop_name or 'Kitchen'} updated to {status_val}."
            rest_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "restaurantId": str(restaurant_id),
                "status": status_val,
                "screen": "restaurant-console",
                "type": "ORDER_STATUS_UPDATE",
                "timestamp": now_ts,
            }

            # Broadcast to this restaurant's specific topics ONLY
            await send_fcm_topic_notification(f"restaurant_{restaurant_id}", rest_title, rest_body, rest_data)
            await send_fcm_topic_notification(f"kitchen_{restaurant_id}", rest_title, rest_body, rest_data)
            await send_fcm_topic_notification(f"restaurant_orders_{restaurant_id}", rest_title, rest_body, rest_data)

            # Direct FCM push to chefs & owners assigned ONLY to this specific restaurant
            async with AsyncSessionLocal() as session:
                rest_res = await session.execute(select(Restaurant).where(Restaurant.id == restaurant_id))
                rest_obj = rest_res.scalars().first()
                clean_owner_phone = ""
                if rest_obj and rest_obj.ownerPhone:
                    clean_owner_phone = re.sub(r'\D', '', str(rest_obj.ownerPhone))[-10:]

                user_filter = [User.assignedRestaurantId == restaurant_id]
                if clean_owner_phone:
                    user_filter.append(User.phone.contains(clean_owner_phone))

                stmt = select(FcmToken.token).join(User).where(or_(*user_filter))
                res = await session.execute(stmt)
                tokens = list(set(res.scalars().all()))
                if tokens:
                    await send_fcm_notification(tokens=tokens, title=rest_title, body=rest_body, data=rest_data)

            # Notify Delivery Riders & Admins
            admin_rider_title = f"🍽️ Food Order #{base_order_no} -> {status_val}"
            admin_rider_body = f"Order #{base_order_no} for {shop_name or 'Restaurant'} is now {status_val}."
            admin_rider_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "restaurantId": str(restaurant_id),
                "status": status_val,
                "screen": "delivery",
                "type": "ORDER_STATUS_UPDATE",
                "role": "DELIVERY",
                "timestamp": now_ts,
            }
            await send_fcm_topic_notification("admin_orders", admin_rider_title, admin_rider_body, admin_rider_data)
            await send_fcm_topic_notification("delivery_orders", admin_rider_title, admin_rider_body, admin_rider_data)

        else:
            # 2. GROCERY DARK STORE ISOLATED STATUS UPDATE
            store_label = f" [{store_id.replace('hub-', '').upper()}]" if store_id else ""
            grocery_title = f"📦 Grocery Order #{base_order_no} -> {status_val}{store_label}"
            grocery_body = f"Order #{base_order_no} status changed to {status_val}."
            grocery_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "storeId": str(store_id or ""),
                "status": status_val,
                "screen": "picker",
                "type": "ORDER_STATUS_UPDATE",
                "role": "PICKER",
                "timestamp": now_ts,
            }

            if store_id:
                await send_fcm_topic_notification(f"picker_orders_{store_id}", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification(f"staff_orders_{store_id}", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification(f"delivery_orders_{store_id}", grocery_title, grocery_body, grocery_data)
            else:
                await send_fcm_topic_notification("picker_orders", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification("staff_orders", grocery_title, grocery_body, grocery_data)
                await send_fcm_topic_notification("delivery_orders", grocery_title, grocery_body, grocery_data)

            await send_fcm_topic_notification("admin_orders", grocery_title, grocery_body, grocery_data)
    except Exception as e:
        logger.error(f"Failed to dispatch isolated status FCM push notification: {str(e)}")


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_order(
    request: Request,
    payload: Dict[str, Any] = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Place a secure checkout order. Evaluates store timings, geocodes, stocks, and promo codes.
    Includes H2 idempotency lock to prevent duplicate orders on double-tap or retries.
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

    # H2 FIX: Idempotency lock check
    idempotency_key = (
        request.headers.get("x-idempotency-key")
        or request.headers.get("idempotency-key")
        or generate_order_cart_signature(user_id, payload.get("items", []), payload.get("addressId"), payload.get("paymentMethod"))
    )
    is_dup, is_proc, cached_resp = acquire_idempotency_lock(idempotency_key)
    if is_dup:
        if cached_resp:
            return {**cached_resp, "idempotencyReplayed": True}
        raise HTTPException(
            status_code=409,
            detail="An order with these items is already being processed. Please wait a moment."
        )

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
            rest_id_payload = raw_item.get("restaurantId") or prod_dict.get("restaurantId")
            addons_payload = raw_item.get("selectedAddons") or prod_dict.get("selectedAddons") or []
        elif isinstance(raw_item, dict):
            prod_id = raw_item.get("productId") or raw_item.get("id")
            prod_name = raw_item.get("name", "Product")
            prod_slug = raw_item.get("slug")
            prod_price = float(raw_item.get("price", 0.0))
            rest_id_payload = raw_item.get("restaurantId")
            addons_payload = raw_item.get("selectedAddons") or []
        else:
            continue

        normalized_items.append({
            "product": {
                "id": str(prod_id) if prod_id else "",
                "name": prod_name,
                "slug": prod_slug,
                "price": prod_price,
                "restaurantId": rest_id_payload,
                "selectedAddons": addons_payload,
            },
            "productId": str(prod_id).split("_")[0] if prod_id else None,
            "quantity": int(raw_item.get("quantity", 1)),
            "price": prod_price,
            "selectedVariant": raw_item.get("selectedVariant"),
            "restaurantId": rest_id_payload,
            "selectedAddons": addons_payload,
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
    if (target_lat is None or target_lng is None) and address:
        address_query = f"{address.houseNo or ''} {address.street or ''} {address.area or ''}, {address.city or ''}, {address.pincode or ''}".strip()
        if address_query:
            coords = await geocode_address(address_query)
            if coords:
                target_lat = coords["lat"]
                target_lng = coords["lng"]
                address.lat = target_lat
                address.lng = target_lng
                await db.commit()

    # ── DYNAMIC MULTI-HUB RESOLUTION (100% Database-Driven, No Hardcoding) ──
    # Fetch all active dark stores from PostgreSQL
    dark_stores_res = await db.execute(select(DarkStore).where(DarkStore.isActive == True))
    active_dark_stores = dark_stores_res.scalars().all()

    matched_hub = None
    if store_id:
        matched_hub = next((s for s in active_dark_stores if s.id == store_id), None)

    # If store_id not explicitly provided, find the closest active dark store by GPS distance
    if not matched_hub and target_lat is not None and target_lng is not None and active_dark_stores:
        hub_distances = []
        for s in active_dark_stores:
            dist = get_distance_km(s.latitude, s.longitude, target_lat, target_lng)
            hub_distances.append((dist, s))
        hub_distances.sort(key=lambda x: x[0])
        closest_dist, closest_hub = hub_distances[0]
        max_rad = float(closest_hub.deliveryRadiusKm or 5.0)
        # If within serviceable radius, assign closest hub
        if closest_dist <= max_rad:
            matched_hub = closest_hub
        else:
            matched_hub = closest_hub

    # Fallback match by City / Area / Name from database
    if not matched_hub and address and active_dark_stores:
        c_clean = (address.city or "").lower().strip()
        a_clean = f"{(address.area or '')} {(address.street or '')}".lower().strip()
        p_clean = (address.pincode or "").strip()
        for s in active_dark_stores:
            s_name = (s.name or "").lower()
            s_city = (s.city or "").lower()
            if (s_city and s_city in c_clean) or (s_name and (s_name in a_clean or s_name in c_clean)) or (p_clean and p_clean in s.id):
                matched_hub = s
                break

    if not matched_hub and active_dark_stores:
        matched_hub = active_dark_stores[0]

    # Assign dynamically resolved storeId
    if matched_hub:
        store_id = matched_hub.id

    # ── DYNAMIC DELIVERY ZONE & DISTANCE VALIDATION ──
    delivery_rules = None
    if delivery_method == "DELIVERY":
        if target_lat is not None and target_lng is not None and matched_hub:
            hub_lat = float(matched_hub.latitude)
            hub_lng = float(matched_hub.longitude)
            max_radius = float(matched_hub.deliveryRadiusKm or 5.0)
            surge_charge = float(matched_hub.surgeCharge or 0.0)

            dist_km = get_distance_km(hub_lat, hub_lng, target_lat, target_lng)
            delivery_rules = get_delivery_rules(dist_km, max_radius, surge_charge)

            if not delivery_rules["isServiceable"] or dist_km > max_radius:
                raise HTTPException(
                    status_code=400,
                    detail=f"Your location is {dist_km:.1f} km away. Delivery is strictly limited to {max_radius:.1f} km from {matched_hub.name}."
                )
        elif target_lat is not None and target_lng is not None:
            # Fallback to StoreSettings if no dark_stores table entry
            store_lat = float(settings_map.get("store_lat", 26.1534185))
            store_lng = float(settings_map.get("store_lng", 80.1714024))
            max_radius = float(settings_map.get("delivery_radius", settings_map.get("max_delivery_radius", 5.0)))
            surge_charge = float(settings_map.get("surge_charge", 0.0))

            dist_km = get_distance_km(store_lat, store_lng, target_lat, target_lng)
            delivery_rules = get_delivery_rules(dist_km, max_radius, surge_charge)

            if not delivery_rules["isServiceable"] or dist_km > max_radius:
                raise HTTPException(
                    status_code=400,
                    detail=f"Your location is {dist_km:.1f} km away. Delivery is limited to {max_radius:.1f} km."
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
    ).with_for_update()
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

        resolved_rest_id = (
            db_prod.restaurantId
            or item.get("restaurantId")
            or (item.get("product") or {}).get("restaurantId")
        )
        is_restaurant = bool(resolved_rest_id)
        if is_restaurant:
            if db_prod.stock is not None and db_prod.stock <= 0:
                db_stock = 0
            else:
                db_stock = 999999

        if db_stock < int(item["quantity"]):
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(status_code=400, detail=f"Insufficient stock for product \"{db_prod.name}{name_suffix}\"")

        # Limits check
        limit = get_product_limit(db_prod)
        if int(item["quantity"]) > limit:
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(status_code=400, detail=f"Maximum order limit of {limit} units exceeded for product \"{db_prod.name}{name_suffix}\"")

        item["dbProduct"] = db_prod
        item_with_db = item
        if is_restaurant:
            r_id = str(resolved_rest_id).strip()
            # Normalize common legacy aliases
            if r_id in ["as-restaurant", "as-cafe", "cms2p1lap0000n0id8alldboy"]:
                r_id = "REST-101"
            elif r_id in ["wedson-restaurant", "wedson"]:
                r_id = "REST-102"
            elif r_id in ["bal-udyan-restaurant", "bal-udyan"]:
                r_id = "REST-103"
            elif r_id in ["hot-pizza-lovers", "pizza-lovers"]:
                r_id = "REST-104"

            matched_group_key = next((k for k in restaurant_groups if k == r_id or restaurant_groups[k].get("slug") == r_id), None)
            if not matched_group_key:
                # Load restaurant details from Restaurant table (search by ID or slug)
                rest_stmt = select(Restaurant).where(or_(Restaurant.id == r_id, Restaurant.slug == r_id))
                rest_res = await db.execute(rest_stmt)
                restaurant = rest_res.scalars().first()

                if not restaurant:
                    # Graceful fallback to default REST-101 instead of crashing
                    def_stmt = select(Restaurant).where(Restaurant.id == "REST-101")
                    def_res = await db.execute(def_stmt)
                    restaurant = def_res.scalars().first()

                if not restaurant or not restaurant.isOpen or not restaurant.isActive:
                    r_name = restaurant.name if restaurant else "Restaurant"
                    raise HTTPException(status_code=400, detail=f"{r_name} is temporarily closed.")

                canonical_r_id = restaurant.id
                # Load restaurant owner details
                res_stmt = select(User).where(User.assignedRestaurantId == canonical_r_id)
                res_res = await db.execute(res_stmt)
                owner = res_res.scalars().first()
                owner_phone = owner.phone if owner else (restaurant.ownerPhone or "+91 81128 49854")

                restaurant_groups[canonical_r_id] = {
                    "id": canonical_r_id,
                    "slug": restaurant.slug,
                    "name": restaurant.name,
                    "ownerPhone": owner_phone,
                    "items": []
                }
                matched_group_key = canonical_r_id

            restaurant_groups[matched_group_key]["items"].append(item_with_db)
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

        # Include food addons in subtotal (C2 fix)
        selected_addons_sub = item.get("selectedAddons") or item.get("product", {}).get("selectedAddons") or []
        addon_total_sub = sum(float(a.get("price", 0)) for a in selected_addons_sub if isinstance(a, dict))
        combined_subtotal += (item_price + addon_total_sub) * int(item["quantity"])

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
                        if coupon.discountType == "BOGO":
                            bogo_items = rest_items if coupon.restaurantId else items
                            if coupon.bogoDishId:
                                bogo_items = [
                                    it for it in bogo_items
                                    if it["product"]["id"].split("_")[0] == coupon.bogoDishId
                                ]
                            elif coupon.menuSection:
                                sec_filters = [s.strip().lower() for s in coupon.menuSection.split(",") if s.strip()]
                                if sec_filters:
                                    known_sections = ['burger', 'sandwich', 'pasta', 'maggie', 'maggi', 'calzone', 'garlic', 'beverage', 'drink', 'dessert', 'icecream', 'biryani', 'pizza', 'shake']
                                    filtered_bogo = []
                                    for it in bogo_items:
                                        base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                        m_sec = str((it.get("product") or {}).get("menuSection") or "").lower()
                                        tags = [str(t).lower() for t in (base_p.tags if base_p and base_p.tags else [])]
                                        name = str(base_p.name if base_p else (it.get("product") or {}).get("name") or "").lower()
                                        matches = False
                                        for f in sec_filters:
                                            if f in m_sec or any(f in t for t in tags):
                                                matches = True
                                                break
                                            other_sections = [s for s in known_sections if f not in s and s not in f]
                                            has_conflict = any(any(s in t for t in tags) for s in other_sections) or any(s in m_sec for s in other_sections)
                                            if not has_conflict and f in name:
                                                matches = True
                                                break
                                        if matches:
                                            filtered_bogo.append(it)
                                    bogo_items = filtered_bogo

                            def parse_trigger_variant(raw):
                                raw_str = str(raw or "").strip()
                                size_match = re.search(r'\b(medium|large|small|regular|half|full)\b', raw_str, re.I)
                                trigger_sz = size_match.group(1).lower() if size_match else None
                                num_match = re.search(r'\b\d+\b', raw_str)
                                min_qty = int(num_match.group(0)) if num_match else (int(raw_str) if raw_str and not trigger_sz else 1)
                                return min_qty, trigger_sz

                            def get_item_vtext(it):
                                is_v = "_" in it["product"]["id"]
                                var_name = it["product"]["id"].split("_")[1] if is_v else ""
                                base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                unit_str = base_p.unit if base_p else ""
                                nm = base_p.name if base_p else ""
                                sel = str((it.get("product") or {}).get("selectedVariant") or "")
                                var = str((it.get("product") or {}).get("variant") or "")
                                return f"{var_name} {unit_str} {nm} {sel} {var}".lower()

                            if coupon.bogoType == "BUY_LARGE_GET_SMALL":
                                trigger_var = (coupon.triggerVariant or "large").lower().strip()
                                reward_var = (coupon.rewardVariant or "small").lower().strip()

                                trigger_items = [it for it in bogo_items if trigger_var in get_item_vtext(it)]
                                total_trig_qty = sum(int(it.get("quantity", 1)) for it in trigger_items)

                                reward_pool = bogo_items if coupon.bogoDishId else (bogo_items if coupon.menuSection else (rest_items if coupon.restaurantId else items))
                                if coupon.defaultFreeDishId:
                                    reward_items = [
                                        it for it in (rest_items if coupon.restaurantId else items)
                                        if it["product"]["id"].split("_")[0] == coupon.defaultFreeDishId
                                    ]
                                else:
                                    reward_items = [it for it in reward_pool if reward_var in get_item_vtext(it)]

                                if total_trig_qty > 0 and reward_items:
                                    allowed_free = min(total_trig_qty, coupon.maxFreeItems or 3)
                                    sorted_rewards = sorted(reward_items, key=lambda x: float(x.get("price", 0.0)))
                                    rem_free = allowed_free
                                    for it in sorted_rewards:
                                        base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                        price = float(it.get("price", base_p.price if base_p else 0.0))
                                        free_q = min(int(it.get("quantity", 1)), rem_free)
                                        combined_discount += free_q * price
                                        rem_free -= free_q
                                        if rem_free <= 0:
                                            break
                                    if coupon.maxDiscount:
                                        combined_discount = min(combined_discount, coupon.maxDiscount)

                            elif coupon.bogoType == "FREE_GIFT":
                                min_trig, trigger_size = parse_trigger_variant(coupon.triggerVariant)
                                qualifying_items = [it for it in bogo_items if trigger_size in get_item_vtext(it)] if trigger_size else bogo_items
                                total_trig = sum(int(it.get("quantity", 1)) for it in qualifying_items)

                                if total_trig >= min_trig:
                                    cart_pool = rest_items if coupon.restaurantId else items
                                    reward_tag = re.sub(r'[^a-z0-9]', '', (coupon.rewardVariant or "").lower())
                                    matching_gift = None
                                    for it in cart_pool:
                                        base_id = it["product"]["id"].split("_")[0]
                                        if coupon.defaultFreeDishId and base_id == coupon.defaultFreeDishId:
                                            matching_gift = it
                                            break
                                        if reward_tag:
                                            base_p = next((p for p in db_products if p.id == base_id), None)
                                            name = str(base_p.name if base_p else (it.get("product") or {}).get("name") or "").lower()
                                            m_sec = str((it.get("product") or {}).get("menuSection") or "").lower()
                                            tags = [str(t).lower() for t in (base_p.tags if base_p and base_p.tags else [])]
                                            v_text = get_item_vtext(it)
                                            if reward_tag in name or any(reward_tag in t for t in tags) or reward_tag in m_sec or reward_tag in v_text:
                                                matching_gift = it
                                                break
                                    if matching_gift:
                                        base_p = next((p for p in db_products if p.id == matching_gift["product"]["id"].split("_")[0]), None)
                                        free_price = float(matching_gift.get("price", base_p.price if base_p else 0.0))
                                        combined_discount = free_price
                                        if coupon.maxDiscount:
                                            combined_discount = min(combined_discount, coupon.maxDiscount)
                                    elif coupon.defaultFreeDishId:
                                        free_dish = next((p for p in db_products if p.id == coupon.defaultFreeDishId), None)
                                        if free_dish:
                                            combined_discount = float(free_dish.price)
                                            if coupon.maxDiscount:
                                                combined_discount = min(combined_discount, coupon.maxDiscount)

                            elif coupon.bogoType == "CHEAPEST_FREE":
                                unit_prices = []
                                for it in bogo_items:
                                    base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                    price = float(it.get("price", base_p.price if base_p else 0.0))
                                    qty = int(it.get("quantity", 1))
                                    for _ in range(qty):
                                        unit_prices.append(price)
                                pend_free = coupon.maxFreeItems or 1
                                if len(unit_prices) >= 2:
                                    unit_prices.sort()
                                    combined_discount = sum(unit_prices[:pend_free])
                                    if coupon.maxDiscount:
                                        combined_discount = min(combined_discount, coupon.maxDiscount)
                                else:
                                    combined_discount = 0.0

                            elif coupon.bogoType == "SAME_ITEM" or not coupon.bogoType:
                                eligible = bogo_items
                                if coupon.bogoDishId:
                                    eligible = [it for it in bogo_items if it["product"]["id"].split("_")[0] == coupon.bogoDishId]
                                max_free_cap = getattr(coupon, "maxFreeItems", 3) or 3
                                for it in eligible:
                                    qty = int(it.get("quantity", 1))
                                    if qty >= 2:
                                        pairs = min(qty // 2, max_free_cap)
                                        base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                        price = float(it.get("price", base_p.price if base_p else 0.0))
                                        combined_discount += pairs * price
                                if coupon.maxDiscount and combined_discount > coupon.maxDiscount:
                                    combined_discount = coupon.maxDiscount
                        elif coupon.discountType == "FREE_DELIVERY":
                            # H5 FIX: Flat ₹25 delivery discount
                            combined_discount = 25.0
                        elif coupon.discountType == "FLAT":
                            combined_discount = min(coupon.value, eligible_subtotal)
                        elif coupon.discountType == "PERCENT":
                            combined_discount = (eligible_subtotal * coupon.value) / 100.0
                            if coupon.maxDiscount:
                                combined_discount = min(combined_discount, coupon.maxDiscount)

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

    # Packaging and handling charge
    server_misc_fee = float(settings_map.get("misc_fee", 5.0))
    packaging_fee_input = float(payload.get("packagingFee", payload.get("packaging_fee", 0.0)))
    is_premium_packaging = packaging_option == "PREMIUM" or packaging_fee == 15.0 or packaging_fee_input > 0
    resolved_packaging_fee = packaging_fee_input if packaging_fee_input > 0 else (15.0 if is_premium_packaging else (server_misc_fee if restaurant_id else 5.0))

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

        # C1 FIX: Never trust client-claimed payment status.
        # Payment is only verified server-side via Razorpay/Cashfree verify endpoints.
        # Orders start as unpaid; payment verification happens in verify-signature/webhook.
        is_online_paid = False
        if payment_method != "COD":
            # For online payments, order starts unpaid. Client must call verify-signature after.
            pass
        auto_approve_setting = settings_map.get("admin_auto_approve_orders", "true")
        is_auto_approve = auto_approve_setting.lower() == "true"
        initial_order_status = OrderStatus.PENDING if (is_online_paid or is_auto_approve) else OrderStatus.ADMIN_PENDING

        new_order = Order(
            id=generate_id("ord_"),
            readableId=readable_id,
            userId=user_id,
            addressId=order_address_id,
            orderType=OrderType.RESTAURANT if restaurant_id else OrderType.GROCERY,
            status=initial_order_status,
            subtotal=round(subtotal, 2),
            discount=round(discount, 2),
            deliveryFee=round(delivery_fee_charge, 2),
            taxes=0.0,
            miscFee=round(misc_fee_charge, 2),
            total=round(final_total, 2),
            paymentMethod=PaymentMethod(payment_method),
            paymentStatus=PaymentStatus.PAID if is_online_paid else PaymentStatus.PENDING,
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
        # Order and items will be committed atomically at line 1021

        # Attach all items & decrement stock for grocery
        for item in items:
            prod = item["dbProduct"]
            raw_id = str(item["product"].get("id", ""))
            is_var = "_" in raw_id
            var_name = item.get("selectedVariant") or (raw_id.split("_")[1] if is_var else None)

            cost_price = prod.costPrice or 0.0
            item_price = prod.price
            if var_name and prod.variants and isinstance(prod.variants, list):
                variant = next((v for v in prod.variants if v.get("name") == var_name), None)
                if variant:
                    item_price = float(variant.get("price", item_price))
                    if variant.get("costPrice") is not None:
                        cost_price = float(variant.get("costPrice"))

            # Food Addons Calculation & Storage
            selected_addons = item.get("selectedAddons") or []
            addon_total = sum(float(a.get("price", 0)) for a in selected_addons if isinstance(a, dict))
            final_item_price = item_price + addon_total

            order_item_variants = {
                "productVariants": prod.variants,
                "selectedAddons": selected_addons
            } if selected_addons else prod.variants

            order_item = OrderItem(
                id=generate_id("oi_"),
                orderId=new_order.id,
                productId=prod.id,
                name=prod.name,
                price=final_item_price,
                quantity=int(item["quantity"]),
                imageUrl=prod.imageUrl,
                selectedVariant=var_name,
                costPrice=cost_price,
                variants=order_item_variants,
                notes=item.get("notes")
            )
            db.add(order_item)

            # Stock deduction for grocery items
            if not prod.restaurantId:
                qty = int(item["quantity"])
                prev_stock = prod.stock
                new_stock = max(0, prev_stock - qty)

                # If item has variant, update variant stock in prod.variants JSON
                if var_name and prod.variants and isinstance(prod.variants, list):
                    updated_variants = []
                    for v in prod.variants:
                        v_copy = dict(v)
                        if v_copy.get("name") == var_name:
                            v_copy["stock"] = max(0, int(v_copy.get("stock", 0)) - qty)
                        updated_variants.append(v_copy)
                    prod.variants = updated_variants
                    prod.stock = sum(int(v.get("stock", 0)) for v in updated_variants)
                else:
                    prod.stock = new_stock

                # Localized Store Inventory deduction (if store_id is provided)
                if store_id:
                    try:
                        from models import StoreInventory
                        inv_stmt = select(StoreInventory).where(
                            StoreInventory.productId == prod.id,
                            StoreInventory.storeId == store_id
                        )
                        inv_res = await db.execute(inv_stmt)
                        existing_inv = inv_res.scalars().first()
                        if existing_inv:
                            existing_inv.stock = max(0, existing_inv.stock - qty)
                    except Exception as inv_err:
                        logger.warning(f"Could not decrement StoreInventory for product {prod.id} at store {store_id}: {inv_err}")

                log = StockLog(
                    id=generate_id("sl_"),
                    productId=prod.id,
                    quantity=-qty,
                    type="ONLINE_ORDER",
                    prevStock=prev_stock,
                    newStock=prod.stock
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
                "event": "NEW_ORDER",
                "type": "new-order",
                "orderId": order.id,
                "readableId": order.readableId,
                "shopName": order.shopName,
                "status": order.status.value,
                "total": float(order.total),
                "createdAt": order.createdAt.isoformat(),
                "restaurantId": order.restaurantId,
            })
            await manager.broadcast_to_channel("general", {
                "event": "CART_UPDATE",
                "type": "cart-updated",
                "userId": user_id,
            })
            await manager.broadcast_to_channel(f"order_{order.id}", {
                "event": "NEW_ORDER",
                "type": "new-order",
                "orderId": order.id,
                "readableId": order.readableId,
                "status": order.status.value,
                "total": float(order.total),
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

            # 2. Strict Isolated FCM Push Notifications to Restaurant/Grocery Workers
            background_tasks.add_task(
                dispatch_isolated_order_fcm_notifications,
                order.id,
                order.readableId,
                order.restaurantId,
                order.shopName,
                float(order.total),
                order.status.value,
                order.storeId
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

            # 3. Dedicated Vendor Dispatch: Notify suppliers of their attached products!
            try:
                v_all_res = await db.execute(select(Vendor).where(Vendor.isActive.is_(True)))
                active_vendors = v_all_res.scalars().all()
                vendor_by_id = {v.id: v for v in active_vendors}
                vendor_by_name = {v.name.lower().strip(): v for v in active_vendors if v.name}

                vendor_groups = {} # vendor_id -> { "vendor": Vendor, "items": [] }
                for it in items:
                    db_p = it.get("dbProduct")
                    if not db_p:
                        raw_id = str((it.get("product") or {}).get("id") or it.get("productId") or "")
                        p_id = raw_id.split("_")[0] if "_" in raw_id else raw_id
                        db_p = next((p for p in db_products if p.id == p_id), None)
                    if not db_p:
                        continue

                    matched_v = None
                    if db_p.vendorId and db_p.vendorId in vendor_by_id:
                        matched_v = vendor_by_id[db_p.vendorId]
                    elif db_p.vendor and db_p.vendor.lower().strip() in vendor_by_name:
                        matched_v = vendor_by_name[db_p.vendor.lower().strip()]

                    if matched_v:
                        if matched_v.id not in vendor_groups:
                            vendor_groups[matched_v.id] = {
                                "vendor": matched_v,
                                "items": []
                            }
                        qty = int(it.get("quantity", 1))
                        unit_cost = float(db_p.costPrice or db_p.price or 0.0)
                        weight_variant = str(it.get("selectedVariant") or getattr(db_p, "unit", "") or "")
                        vendor_groups[matched_v.id]["items"].append({
                            "name": db_p.name,
                            "quantity": qty,
                            "cost": unit_cost,
                            "weight": weight_variant,
                        })

                for v_id, v_data in vendor_groups.items():
                    v_obj = v_data["vendor"]
                    v_items = v_data["items"]
                    total_val = sum(i["quantity"] * i["cost"] for i in v_items)

                    # Real-time WebSocket to vendor console
                    await manager.broadcast_to_channel(f"vendor_{v_id}", {
                        "event": "NEW_VENDOR_ORDER",
                        "type": "new-vendor-order",
                        "orderId": order.id,
                        "readableId": order.readableId,
                        "items": v_items,
                        "totalVendorCost": total_val,
                        "createdAt": order.createdAt.isoformat(),
                    })

                    # Instant WhatsApp order alert to vendor phone
                    clean_v_phone = ""
                    if v_obj.phone:
                        clean_v_phone = re.sub(r'\D', '', str(v_obj.phone))[-10:]
                        if len(clean_v_phone) == 10:
                            item_lines = "\n".join([f"• {i['quantity']}x {i['name']} {('[' + i['weight'] + ']') if i['weight'] else ''}" for i in v_items])
                            v_alert_text = (
                                f"🔔 *FastKirana New Order Alert #{order.readableId}*\n\n"
                                f"Customer ordered items from your catalog:\n{item_lines}\n\n"
                                f"💰 Total Supply Cost: ₹{total_val:.2f}\n"
                                f"⚡ Please pack and keep ready for FastKirana picker pickup!"
                            )
                            background_tasks.add_task(send_whatsapp_alert, clean_v_phone, v_alert_text)

                    # Specific High-Priority Push Notification to Vendor's App!
                    vendor_topic = f"vendor_{v_id}"
                    fcm_title = f"📦 New Order #{order.readableId} for Your Store!"
                    fcm_body = f"{len(v_items)} item(s) to pack (₹{total_val:.0f}). Tap to view and mark ready!"
                    fcm_data = {
                        "type": "VENDOR_NEW_ORDER",
                        "orderId": order.id,
                        "readableId": str(order.readableId),
                        "vendorId": v_id,
                        "screen": "vendor-console",
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    }
                    background_tasks.add_task(
                        send_fcm_topic_notification,
                        vendor_topic,
                        fcm_title,
                        fcm_body,
                        fcm_data,
                    )
                    if clean_v_phone and len(clean_v_phone) == 10:
                        background_tasks.add_task(
                            send_fcm_topic_notification,
                            f"phone_{clean_v_phone}",
                            fcm_title,
                            fcm_body,
                            fcm_data,
                        )
            except Exception as vendor_notify_err:
                logger.warning(f"Could not dispatch vendor notifications for order #{order.readableId}: {vendor_notify_err}")

        # Return full order object matching Flutter Order.fromJson expectations
        main_order = next((o for o in created_orders if not o.restaurantId), created_orders[0]) if created_orders else new_order

        # Build in-memory items payload safely without triggering async lazy-loading DetachedInstanceError
        order_items_payload = []
        for it in items:
            p_data = it.get("product") or {}
            raw_id = str(p_data.get("id") or it.get("productId") or "")
            var_name = it.get("selectedVariant") or (raw_id.split("_")[1] if "_" in raw_id else None)
            db_p = it.get("dbProduct")
            order_items_payload.append({
                "id": str(it.get("productId") or raw_id),
                "name": str(p_data.get("name") or getattr(db_p, "name", "Item")),
                "quantity": int(it.get("quantity", 1)),
                "price": float(it.get("price") or getattr(db_p, "price", 0.0)),
                "imageUrl": getattr(db_p, "imageUrl", None) or p_data.get("imageUrl"),
                "selectedVariant": var_name
            })

        result_payload = {
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
            "customerName": user_obj.name if user_obj else None,
            "customerPhone": (user_obj.phone if user_obj else None) or (address.phone if address else None),
            "customerAddress": f"{address.houseNo or ''}, {address.street or ''}, {address.area or ''}, {address.city or ''}, {address.pincode or ''}" if address else None,
            "createdAt": main_order.createdAt.isoformat() if main_order.createdAt else None,
            "updatedAt": main_order.updatedAt.isoformat() if main_order.updatedAt else None,
            "confirmedAt": main_order.confirmedAt.isoformat() if main_order.confirmedAt else None,
            "packedAt": main_order.packedAt.isoformat() if main_order.packedAt else None,
            "shippedAt": main_order.shippedAt.isoformat() if main_order.shippedAt else None,
            "deliveredAt": main_order.deliveredAt.isoformat() if main_order.deliveredAt else None,
            "items": order_items_payload,
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
            # Universal Web & Flutter compatibility wrappers
            "order": {
                "id": main_order.id,
                "readableId": main_order.readableId,
                "status": main_order.status.value,
                "total": float(main_order.total or 0),
                "restaurantId": main_order.restaurantId,
                "shopName": main_order.shopName,
            },
            "orders": [{
                "id": o.id,
                "readableId": o.readableId,
                "status": o.status.value,
                "total": float(o.total or 0),
                "restaurantId": o.restaurantId,
                "shopName": o.shopName,
            } for o in created_orders]
        }

        # Save idempotency cache
        if idempotency_key:
            save_idempotency_response(idempotency_key, result_payload)

        return result_payload

    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to place order: {str(e)}")
        if "idempotency_key" in locals() and idempotency_key:
            release_idempotency_lock(idempotency_key)
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
        if is_owner and not is_admin:
            # C8 FIX: Customers can only cancel PENDING or ADMIN_PENDING orders
            if order.status not in [OrderStatus.PENDING, OrderStatus.ADMIN_PENDING]:
                raise HTTPException(
                    status_code=400,
                    detail="Order cannot be cancelled after it has been confirmed. Please contact support."
                )
        elif not (is_admin or is_picker or is_restaurant_staff or is_delivery):
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
        if not order.restaurantId:
            raise HTTPException(
                status_code=403,
                detail="Restaurant staff cannot manage dark store grocery orders"
            )
        if not assigned_restaurant_id:
            user_stmt = select(User.assignedRestaurantId).where(User.id == user_id)
            user_res = await db.execute(user_stmt)
            assigned_restaurant_id = user_res.scalar_one_or_none()

        if not assigned_restaurant_id:
            raise HTTPException(
                status_code=403,
                detail="No restaurant assigned to your staff account"
            )

        rest_stmt = select(Restaurant.id, Restaurant.slug).where(
            or_(Restaurant.id == assigned_restaurant_id, Restaurant.slug == assigned_restaurant_id)
        )
        rest_res = await db.execute(rest_stmt)
        matched_rest = rest_res.mappings().first()
        outlet_ids = {assigned_restaurant_id}
        if matched_rest:
            outlet_ids.add(matched_rest["id"])
            if matched_rest["slug"]:
                outlet_ids.add(matched_rest["slug"])

        if order.restaurantId not in outlet_ids:
            raise HTTPException(
                status_code=403,
                detail="You can only manage orders for your assigned restaurant outlet"
            )

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

    # C3 FIX: Stock is already deducted at order creation (lines 896-938).
    # Do NOT deduct again on PACKED to avoid double deduction.
    # The PACKED transition only marks the order as physically packed.
    if target_status == OrderStatus.PACKED and order.status != OrderStatus.PACKED:
        pass  # No stock deduction — already done at creation

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

            # If order was associated with a dark store, restore localized stock in StoreInventory
            if order.storeId:
                try:
                    from models import StoreInventory
                    inv_stmt = select(StoreInventory).where(
                        StoreInventory.productId == item.productId,
                        StoreInventory.storeId == order.storeId
                    )
                    inv_res = await db.execute(inv_stmt)
                    existing_inv = inv_res.scalars().first()
                    if existing_inv:
                        existing_inv.stock += item.quantity
                except Exception as inv_restore_err:
                    logger.warning(f"Could not restore StoreInventory for product {item.productId} at store {order.storeId}: {inv_restore_err}")

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
        if role == Role.DELIVERY:
            order.deliveryUserId = user_id
        elif not order.deliveryUserId:
            rider_stmt = select(User.id).where(or_(User.email == "delivery@fastkirana.com", User.role == Role.DELIVERY)).limit(1)
            rider_res = await db.execute(rider_stmt)
            rider_id = rider_res.scalars().first()
            if rider_id:
                order.deliveryUserId = rider_id
        if delivery_lat is not None and delivery_lng is not None:
            order.deliveryLat = float(delivery_lat)
            order.deliveryLng = float(delivery_lng)
        order.shippedAt = datetime.utcnow()

    elif target_status == OrderStatus.PACKED:
        order.packedAt = datetime.utcnow()

    elif target_status == OrderStatus.CONFIRMED:
        order.confirmedAt = datetime.utcnow()
        if role == Role.CHEF:
            order.assignedChefId = user_id
        elif role == Role.PICKER:
            order.assignedPickerId = user_id

        if prep_time and str(prep_time).isdigit():
            order.estimatedDelivery = datetime.utcnow() + timedelta(minutes=int(prep_time))

    # Sibling synchronization (H6 FIX: outlet isolation, never cascade-cancel sibling)
    is_explicit_all = payload.get("scope") == "ALL" or payload.get("updateCombined") is True
    is_customer_cancel = is_owner and target_status == OrderStatus.CANCELLED
    should_sync_status = is_explicit_all or is_customer_cancel or target_status in [OrderStatus.SHIPPED, OrderStatus.DELIVERED]

    if order.combinedId:
        sibling_stmt = select(Order).where(Order.combinedId == order.combinedId, Order.id != order.id)
        sibling_res = await db.execute(sibling_stmt)
        companion = sibling_res.scalars().first()

        if companion:
            if should_sync_status:
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
        "restaurantId": order.restaurantId,
        "status": order.status.value,
        "lat": order.deliveryLat,
        "lng": order.deliveryLng
    })

    # Strict restaurant channel real-time update
    if order.restaurantId:
        rest_ws_payload = {
            "event": "STATUS_UPDATE",
            "orderId": order.id,
            "restaurantId": order.restaurantId,
            "status": order.status.value,
            "order": {
                "id": order.id,
                "readableId": order.readableId,
                "status": order.status.value,
                "restaurantId": order.restaurantId,
                "total": float(order.total),
                "updatedAt": order.updatedAt.isoformat()
            }
        }
        await manager.broadcast_to_channel(f"restaurant_{order.restaurantId}", rest_ws_payload)
        await manager.broadcast_to_channel(f"kitchen_{order.restaurantId}", rest_ws_payload)

    # Trigger Rich PWA & Mobile Push Notification for customer and staff roles
    base_order_no = re.sub(r'-[GR\d]+$', '', order.readableId or "")
    st_val = order.status.value.upper()

    stage_titles = {
        "CONFIRMED": "🏪 Order Confirmed!",
        "PREPARING": "👨‍🍳 Food Being Prepared!",
        "COOKING": "👨‍🍳 Cooking in Progress!",
        "PACKED": "📦 Items Packed & Ready!",
        "SHIPPED": "🚴 Out for Delivery!",
        "ARRIVING_SOON": "🛵 Delivery Partner Arriving in 2 Mins!",
        "DELIVERED": "🎉 Order Delivered Successfully!",
        "CANCELLED": "❌ Order Cancelled",
    }

    stage_bodies = {
        "CONFIRMED": f"Store has accepted order #{base_order_no} and preparation has started.",
        "PREPARING": f"The kitchen is freshly preparing your dishes for order #{base_order_no}.",
        "COOKING": f"Chefs are putting final touches on order #{base_order_no}.",
        "PACKED": f"Order #{base_order_no} is packed and ready for dispatch.",
        "SHIPPED": f"Your delivery partner has picked up order #{base_order_no} and is on the way! ⚡",
        "ARRIVING_SOON": f"Your delivery partner is right around the corner (~500m away). Get ready to collect order #{base_order_no}!",
        "DELIVERED": f"Your order #{base_order_no} has arrived. Enjoy your meal / groceries!",
        "CANCELLED": f"Order #{base_order_no} has been cancelled.",
    }

    status_title = stage_titles.get(st_val, f"Order #{base_order_no} Update 🔔")
    status_body = stage_bodies.get(st_val, f"Your FastKirana order #{base_order_no} is now {st_val}.")

    background_tasks.add_task(
        send_pwa_notification_to_user,
        order.userId,
        status_title,
        status_body,
        {
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "type": "ORDER_STATUS_UPDATE"
        },
        db
    )

    # Strict outlet-isolated notifications (Never leak food order updates to grocery pickers, or vice versa)
    background_tasks.add_task(
        dispatch_isolated_status_update_notifications,
        order.id,
        order.readableId,
        order.restaurantId,
        order.shopName,
        st_val,
        order.storeId
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
        "deliveryUser": {"name": order.deliveryUser.name, "phone": order.deliveryUser.phone} if getattr(order, "deliveryUser", None) else None,
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


@router.post("/{id}/convert-to-cod")
async def convert_order_to_cod(
    id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Customer / Staff fallback: Convert an unpaid online order to Cash on Delivery (COD).
    Updates order status to CONFIRMED so preparation can begin immediately.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")

    clean_id = id.strip()
    stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_owner = bool(user_id and order.userId == user_id)
    is_admin = role == "ADMIN"
    if not is_owner and not is_admin and user_id:
        raise HTTPException(status_code=403, detail="Unauthorized to modify this order")

    if order.paymentStatus == PaymentStatus.PAID:
        raise HTTPException(status_code=400, detail="Order has already been paid online")

    if order.status == OrderStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Order has been cancelled and cannot be converted")

    now = datetime.utcnow()

    # If part of combined order group, convert all companion sub-orders
    if order.combinedId:
        combined_stmt = select(Order).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(combined_stmt)
        related_orders = comb_res.scalars().all()
        for o in related_orders:
            o.paymentMethod = PaymentMethod.COD
            o.paymentStatus = PaymentStatus.PENDING
            o.status = OrderStatus.CONFIRMED
            o.confirmedAt = now
            o.updatedAt = now
    else:
        order.paymentMethod = PaymentMethod.COD
        order.paymentStatus = PaymentStatus.PENDING
        order.status = OrderStatus.CONFIRMED
        order.confirmedAt = now
        order.updatedAt = now

    await db.commit()
    await db.refresh(order)

    # Broadcast real-time WebSocket update
    try:
        await manager.broadcast_to_channel("general", {
            "type": "order-converted-cod",
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "paymentMethod": "COD"
        })
    except Exception as ws_err:
        logger.warning(f"Failed to broadcast convert-to-cod via websocket: {ws_err}")

    return {
        "success": True,
        "message": "Order converted to Cash on Delivery successfully",
        "orderId": order.id,
        "status": order.status.value,
        "paymentMethod": "COD"
    }


def normalize_restaurant_id(rid: Optional[str]) -> Optional[str]:
    if not rid:
        return None
    r = str(rid).strip().lower()
    if "as-restaurant" in r or "as-cafe" in r or "101" in r or "cms2p1lap" in r:
        return "REST-101"
    if "wedson" in r or "102" in r:
        return "REST-102"
    if "bal-udyan" in r or "103" in r or "cmsbhxb6a" in r:
        return "REST-103"
    if "pizza" in r or "104" in r:
        return "REST-104"
    return str(rid).strip()


@router.post("/{id}/edit")
async def edit_order(
    id: str,
    payload: Dict[str, Any] = Body(...),
    request: Request = None,
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Staff / Admin Order Editing Endpoint.
    Supports single-domain editing as well as multi-domain order splitting (-G, -R, -R2)
    with combined delivery fee threshold management.
    """
    effective_user_id = current_user.get("id") if current_user else None
    effective_role = (current_user.get("role") or "").upper() if current_user else ""
    assigned_restaurant_id = current_user.get("assignedRestaurantId") if current_user else None

    # Fallback: check x-user-id header
    if not effective_role or effective_role == "USER":
        header_user_id = request.headers.get("x-user-id") if request else None
        if header_user_id and not header_user_id.startswith("mock-id-"):
            u_stmt = select(User).where(User.id == header_user_id)
            u_res = await db.execute(u_stmt)
            db_user = u_res.scalars().first()
            if db_user and not getattr(db_user, "isBlocked", False):
                effective_user_id = db_user.id
                effective_role = db_user.role.value if hasattr(db_user.role, "value") else str(db_user.role)
                assigned_restaurant_id = db_user.assignedRestaurantId

    allowed_roles = ["ADMIN", "CHEF", "PICKER", "RESTAURANT_OWNER", "SUPER_ADMIN", "MANAGER"]
    if effective_role not in allowed_roles:
        raise HTTPException(status_code=403, detail="Unauthorized: insufficient role to edit orders")

    updated_items = payload.get("updatedItems")
    if not isinstance(updated_items, list):
        raise HTTPException(status_code=400, detail="updatedItems must be an array")

    out_of_stock_product_ids = payload.get("outOfStockProductIds") or []

    # 1. Fetch current order by id or readableId
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.user)
    ).where(or_(Order.id == id, Order.readableId == id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Outlet isolation check for chef / restaurant owner
    if effective_role in ["CHEF", "RESTAURANT_OWNER"]:
        if assigned_restaurant_id and order.restaurantId:
            norm_assigned = normalize_restaurant_id(assigned_restaurant_id)
            norm_order_rest = normalize_restaurant_id(order.restaurantId)
            if norm_assigned and norm_order_rest and norm_assigned != norm_order_rest:
                raise HTTPException(status_code=403, detail="You can only edit orders for your assigned restaurant")

    order_status_val = order.status.value if hasattr(order.status, "value") else str(order.status)
    if effective_role not in ["ADMIN", "SUPER_ADMIN"]:
        if order_status_val in ["PACKED", "SHIPPED", "DELIVERED", "CANCELLED"]:
            raise HTTPException(status_code=400, detail=f"Order is already {order_status_val} and cannot be edited")
    else:
        if order_status_val == "DELIVERED":
            raise HTTPException(status_code=400, detail="Delivered order cannot be edited")

    # 2. Adjust out of stock products if provided
    if out_of_stock_product_ids and isinstance(out_of_stock_product_ids, list):
        for prod_id in out_of_stock_product_ids:
            p_stmt = select(Product).where(Product.id == prod_id)
            p_res = await db.execute(p_stmt)
            p_obj = p_res.scalars().first()
            if p_obj:
                p_obj.isAvailable = False
                p_obj.stock = 0

    # 3. Revert stock of existing order items
    for item in order.items:
        if not item.productId:
            continue
        p_stmt = select(Product).where(Product.id == item.productId)
        p_res = await db.execute(p_stmt)
        p_obj = p_res.scalars().first()
        if not p_obj or p_obj.restaurantId:
            continue

        if item.selectedVariant and p_obj.variants and isinstance(p_obj.variants, list):
            updated_variants = []
            for v in p_obj.variants:
                if isinstance(v, dict) and v.get("name") == item.selectedVariant:
                    v_copy = dict(v)
                    v_copy["stock"] = int(v_copy.get("stock", 0)) + item.quantity
                    updated_variants.append(v_copy)
                else:
                    updated_variants.append(v)
            new_total = sum(int(v.get("stock", 0)) for v in updated_variants if isinstance(v, dict))
            p_obj.variants = updated_variants
            p_obj.stock = new_total
        else:
            p_obj.stock = (p_obj.stock or 0) + item.quantity

    # 4. Classify new updated items into grocery vs restaurant
    grocery_group = []
    restaurant_groups = {}

    for item in updated_items:
        if not item or not isinstance(item, dict):
            continue
        qty = int(item.get("quantity") or 1)
        if qty <= 0:
            continue

        prod_id = item.get("productId")
        product = None
        if prod_id and isinstance(prod_id, str) and not prod_id.startswith("custom_"):
            prod_stmt = select(Product).options(
                selectinload(Product.restaurant),
                selectinload(Product.category)
            ).where(Product.id == prod_id)
            prod_res = await db.execute(prod_stmt)
            product = prod_res.scalars().first()

        item_price = float(product.price) if product else 0.0
        if effective_role in ["ADMIN", "SUPER_ADMIN"]:
            if item.get("price") is not None:
                item_price = max(0.0, float(item["price"]))
        elif not product and item.get("price") is not None:
            item_price = max(0.0, float(item["price"]))

        item_name = item.get("name") or (product.name if product else "Item")
        item_rest_id = str(item.get("restaurantId") or "").strip() or None
        item_shop_name = str(item.get("shopName") or "").strip() or None

        is_restaurant = False
        resolved_rest_id = None
        resolved_shop_name = None
        resolved_shop_phone = None

        if product:
            raw_rest_id = product.restaurantId or (product.restaurant.id if product.restaurant else None)
            if raw_rest_id:
                is_restaurant = True
                resolved_rest_id = normalize_restaurant_id(raw_rest_id) or raw_rest_id
                resolved_shop_name = product.restaurant.name if product.restaurant else item_shop_name or "Restaurant"
                resolved_shop_phone = product.restaurant.ownerPhone if product.restaurant else None
            else:
                is_restaurant = False
                resolved_rest_id = None
                resolved_shop_name = "FastKirana Grocery"
                resolved_shop_phone = None
        else:
            explicit_rest_id = normalize_restaurant_id(item_rest_id) if item_rest_id else None
            if explicit_rest_id:
                is_restaurant = True
                resolved_rest_id = explicit_rest_id
                resolved_shop_name = item_shop_name or "Restaurant"
                resolved_shop_phone = order.shopPhone
            elif str(order.orderType.value if hasattr(order.orderType, "value") else order.orderType) == "RESTAURANT" and order.restaurantId and effective_role in ["CHEF", "RESTAURANT_OWNER"]:
                is_restaurant = True
                resolved_rest_id = normalize_restaurant_id(order.restaurantId) or order.restaurantId
                resolved_shop_name = order.shopName or "Restaurant"
                resolved_shop_phone = order.shopPhone
            else:
                is_restaurant = False
                resolved_rest_id = None
                resolved_shop_name = "FastKirana Grocery"
                resolved_shop_phone = None

        classified = {
            "item": item,
            "product": product,
            "itemPrice": item_price,
            "itemQty": qty,
            "itemName": item_name,
            "isRestaurant": is_restaurant,
            "restaurantId": resolved_rest_id,
            "shopName": resolved_shop_name,
            "shopPhone": resolved_shop_phone
        }

        if is_restaurant:
            key = resolved_rest_id or normalize_restaurant_id(order.restaurantId) or "REST-101"
            if key not in restaurant_groups:
                restaurant_groups[key] = {
                    "items": [],
                    "shopName": resolved_shop_name or order.shopName or "Restaurant",
                    "shopPhone": resolved_shop_phone or order.shopPhone
                }
            restaurant_groups[key]["items"].append(classified)
        else:
            grocery_group.append(classified)

    has_grocery_items = len(grocery_group) > 0
    restaurant_keys = list(restaurant_groups.keys())
    has_restaurant_items = len(restaurant_keys) > 0
    is_mixed = (has_grocery_items and has_restaurant_items) or len(restaurant_keys) > 1

    # Fetch fee settings
    settings_stmt = select(StoreSetting)
    settings_res = await db.execute(settings_stmt)
    settings_rows = settings_res.scalars().all()
    settings_map = {s.key: s.value for s in settings_rows}

    delivery_fee_setting = float(settings_map.get("delivery_fee") or 25.0)
    misc_fee_setting = float(settings_map.get("misc_fee") or 5.0)

    async def insert_items_for_order(target_order_id: str, items_list: list) -> float:
        subtotal = 0.0
        for ci in items_list:
            subtotal += ci["itemPrice"] * ci["itemQty"]
            order_item = OrderItem(
                id=str(uuid.uuid4()),
                orderId=target_order_id,
                productId=ci["product"].id if ci["product"] else None,
                name=ci["itemName"],
                price=ci["itemPrice"],
                quantity=ci["itemQty"],
                selectedVariant=ci["item"].get("selectedVariant"),
                imageUrl=ci["item"].get("imageUrl") or (ci["product"].imageUrl if ci["product"] else None),
                notes=ci["item"].get("notes"),
                costPrice=float(ci["product"].costPrice or 0.0) if ci["product"] else 0.0
            )
            db.add(order_item)

            # Deduct stock for grocery items
            if ci["product"] and not ci["isRestaurant"]:
                p_item = ci["product"]
                if ci["item"].get("selectedVariant") and p_item.variants and isinstance(p_item.variants, list):
                    updated_v = []
                    for v in p_item.variants:
                        if isinstance(v, dict) and v.get("name") == ci["item"]["selectedVariant"]:
                            v_copy = dict(v)
                            v_copy["stock"] = max(0, int(v_copy.get("stock", 0)) - ci["itemQty"])
                            updated_v.append(v_copy)
                        else:
                            updated_v.append(v)
                    p_item.variants = updated_v
                    p_item.stock = sum(int(v.get("stock", 0)) for v in updated_v if isinstance(v, dict))
                else:
                    p_item.stock = max(0, (p_item.stock or 0) - ci["itemQty"])

        return subtotal

    # =====================================================================
    # SINGLE-DOMAIN PATH
    # =====================================================================
    if not is_mixed:
        # Delete old items
        await db.execute(delete(OrderItem).where(OrderItem.orderId == order.id))

        all_items = grocery_group if has_grocery_items else [item for g in restaurant_groups.values() for item in g["items"]]
        subtotal_val = await insert_items_for_order(order.id, all_items)

        dynamic_order_type = order.orderType
        dynamic_restaurant_id = order.restaurantId
        dynamic_shop_name = order.shopName
        dynamic_shop_phone = order.shopPhone

        if has_restaurant_items:
            first_key = normalize_restaurant_id(restaurant_keys[0]) or restaurant_keys[0]
            first_group = restaurant_groups.get(restaurant_keys[0]) or restaurant_groups.get(first_key) or list(restaurant_groups.values())[0]
            dynamic_order_type = OrderType.RESTAURANT
            dynamic_restaurant_id = first_key

            rest_stmt = select(Restaurant).where(Restaurant.id == first_key)
            rest_res = await db.execute(rest_stmt)
            db_rest = rest_res.scalars().first()

            dynamic_shop_name = db_rest.name if db_rest else (first_group.get("shopName") or "Restaurant")
            dynamic_shop_phone = db_rest.ownerPhone if db_rest else first_group.get("shopPhone")
        elif has_grocery_items:
            dynamic_order_type = OrderType.GROCERY
            dynamic_restaurant_id = None
            dynamic_shop_name = "FastKirana Grocery"
            dynamic_shop_phone = None

        # Delivery fee calculation
        threshold = float(settings_map.get("grocery_free_delivery_threshold") or 200.0)
        if str(dynamic_order_type) == "RESTAURANT":
            threshold = float(settings_map.get("cafe_free_delivery_threshold") or 200.0)

        calc_delivery_fee = 0.0
        calc_misc_fee = 0.0
        if str(order.deliveryMethod) == "DELIVERY":
            calc_delivery_fee = 0.0 if subtotal_val >= threshold else delivery_fee_setting
            calc_misc_fee = miscFee_setting = float(settings_map.get("misc_fee") or 5.0)

        taxes_val = 0.0
        total_val = subtotal_val + calc_delivery_fee + taxes_val + calc_misc_fee - float(order.discount or 0.0)

        order.subtotal = subtotal_val
        order.deliveryFee = calc_delivery_fee
        order.miscFee = calc_misc_fee
        order.taxes = taxes_val
        order.total = total_val
        order.orderType = dynamic_order_type
        order.restaurantId = dynamic_restaurant_id
        order.shopName = dynamic_shop_name
        order.shopPhone = dynamic_shop_phone

        if str(dynamic_order_type) == "GROCERY":
            order.assignedChefId = None
        elif str(dynamic_order_type) == "RESTAURANT":
            order.assignedPickerId = None

        await db.commit()
        await db.refresh(order)

        # Broadcast SSE / WebSocket
        try:
            await manager.broadcast_to_channel("general", {
                "type": "order-edited",
                "orderId": order.id,
                "shopName": dynamic_shop_name,
                "restaurantId": dynamic_restaurant_id,
                "orderType": str(dynamic_order_type.value if hasattr(dynamic_order_type, "value") else dynamic_order_type)
            })
        except Exception:
            pass

        return {
            "success": True,
            "total": total_val,
            "orderType": str(dynamic_order_type.value if hasattr(dynamic_order_type, "value") else dynamic_order_type),
            "restaurantId": dynamic_restaurant_id,
            "shopName": dynamic_shop_name
        }

    # =====================================================================
    # MIXED-DOMAIN PATH (Order Splitting)
    # =====================================================================
    base_readable_id = re.sub(r"-(G|R\d*)$", "", order.readableId or "", flags=re.IGNORECASE)
    combined_id = order.combinedId or f"combined_{uuid.uuid4().hex[:9]}_{int(datetime.utcnow().timestamp())}"
    current_is_grocery = (str(order.orderType.value if hasattr(order.orderType, "value") else order.orderType) == "GROCERY") or not order.restaurantId

    # Find existing companions
    existing_companions = []
    if order.combinedId:
        c_stmt = select(Order).options(selectinload(Order.items)).where(
            and_(Order.combinedId == order.combinedId, Order.id != order.id)
        )
        c_res = await db.execute(c_stmt)
        existing_companions = c_res.scalars().all()

    sub_orders = []
    if has_grocery_items:
        existing_grocery = order if current_is_grocery else next((c for c in existing_companions if str(c.orderType.value if hasattr(c.orderType, "value") else c.orderType) == "GROCERY"), None)
        sub_orders.append({
            "orderId": existing_grocery.id if existing_grocery else None,
            "items": grocery_group,
            "type": OrderType.GROCERY,
            "restaurantId": None,
            "shopName": "FastKirana Grocery",
            "shopPhone": None,
            "readableId": f"{base_readable_id}-G",
            "isNew": existing_grocery is None
        })

    rest_idx = 0
    for r_id in restaurant_keys:
        rest_idx += 1
        r_group = restaurant_groups[r_id]
        normalized_r_id = normalize_restaurant_id(r_id)
        existing_rest = order if (not current_is_grocery and normalize_restaurant_id(order.restaurantId) == normalized_r_id) else next(
            (c for c in existing_companions if str(c.orderType.value if hasattr(c.orderType, "value") else c.orderType) == "RESTAURANT" and normalize_restaurant_id(c.restaurantId) == normalized_r_id),
            None
        )
        suffix = "-R" if rest_idx == 1 else f"-R{rest_idx}"
        sub_orders.append({
            "orderId": existing_rest.id if existing_rest else None,
            "items": r_group["items"],
            "type": OrderType.RESTAURANT,
            "restaurantId": normalized_r_id,
            "shopName": r_group["shopName"],
            "shopPhone": r_group["shopPhone"],
            "readableId": f"{base_readable_id}{suffix}",
            "isNew": existing_rest is None
        })

    # Ensure original order is claimed
    if not any(s["orderId"] == order.id for s in sub_orders) and sub_orders:
        cand = next((s for s in sub_orders if s["type"] == order.orderType and s["orderId"] is None), None) or \
               next((s for s in sub_orders if s["orderId"] is None), None) or sub_orders[0]
        cand["orderId"] = order.id
        cand["isNew"] = False

    prepared = []
    all_order_ids = []

    for spec in sub_orders:
        target_id = spec["orderId"]
        if spec["isNew"]:
            new_ord = Order(
                id=str(uuid.uuid4()),
                userId=order.userId,
                readableId=spec["readableId"],
                addressId=order.addressId,
                combinedId=combined_id,
                orderType=spec["type"],
                status=order.status,
                subtotal=0.0,
                discount=0.0,
                deliveryFee=0.0,
                taxes=0.0,
                miscFee=0.0,
                total=0.0,
                paymentMethod=order.paymentMethod,
                paymentStatus=order.paymentStatus,
                deliveryMethod=order.deliveryMethod,
                isB2B=order.isB2B,
                storeId=order.storeId,
                couponCode=order.couponCode,
                shopName=spec["shopName"],
                shopPhone=spec["shopPhone"],
                restaurantId=spec["restaurantId"],
                deliveryLat=order.deliveryLat,
                deliveryLng=order.deliveryLng,
                notes=order.notes,
                assignedPickerId=order.assignedPickerId if spec["type"] == OrderType.GROCERY else None,
                assignedChefId=order.assignedChefId if spec["type"] == OrderType.RESTAURANT else None,
            )
            db.add(new_ord)
            await db.flush()
            target_id = new_ord.id

        await db.execute(delete(OrderItem).where(OrderItem.orderId == target_id))
        all_order_ids.append(target_id)
        subtotal_val = await insert_items_for_order(target_id, spec["items"])
        prepared.append({
            "targetOrderId": target_id,
            "spec": spec,
            "subtotalVal": subtotal_val
        })

    # Global combined delivery fee calculation
    total_combined_subtotal = sum(p["subtotalVal"] for p in prepared)
    combined_threshold = float(settings_map.get("combined_free_delivery_threshold") or 350.0)
    is_combined_free = (str(order.deliveryMethod) != "DELIVERY") or (total_combined_subtotal >= combined_threshold)

    single_delivery_assigned = is_combined_free
    single_misc_assigned = (str(order.deliveryMethod) != "DELIVERY")

    primary_total = 0.0
    primary_order_type = ""
    primary_restaurant_id = None
    primary_shop_name = ""

    for p in prepared:
        calc_del = 0.0
        if not single_delivery_assigned and p["subtotalVal"] > 0:
            calc_del = delivery_fee_setting
            single_delivery_assigned = True

        calc_misc = 0.0
        if not single_misc_assigned and p["subtotalVal"] > 0:
            calc_misc = misc_fee_setting
            single_misc_assigned = True

        disc = 0.0 if p["spec"]["isNew"] else float(order.discount or 0.0)
        tot = p["subtotalVal"] + calc_del + calc_misc - disc

        u_ord_stmt = select(Order).where(Order.id == p["targetOrderId"])
        u_ord_res = await db.execute(u_ord_stmt)
        target_ord = u_ord_res.scalars().first()

        target_ord.combinedId = combined_id
        target_ord.readableId = p["spec"]["readableId"]
        target_ord.subtotal = p["subtotalVal"]
        target_ord.deliveryFee = calc_del
        target_ord.miscFee = calc_misc
        target_ord.total = tot
        target_ord.orderType = p["spec"]["type"]
        target_ord.restaurantId = p["spec"]["restaurantId"]
        target_ord.shopName = p["spec"]["shopName"]

        if p["targetOrderId"] == order.id:
            primary_total = tot
            primary_order_type = str(p["spec"]["type"].value if hasattr(p["spec"]["type"], "value") else p["spec"]["type"])
            primary_restaurant_id = p["spec"]["restaurantId"]
            primary_shop_name = p["spec"]["shopName"]

    order.combinedId = combined_id

    # Clean up orphaned companion orders
    for ec in existing_companions:
        if ec.id not in all_order_ids:
            await db.execute(delete(OrderItem).where(OrderItem.orderId == ec.id))
            await db.execute(delete(Order).where(Order.id == ec.id))

    await db.commit()

    return {
        "success": True,
        "total": primary_total,
        "orderType": primary_order_type,
        "restaurantId": primary_restaurant_id,
        "shopName": primary_shop_name,
        "split": True,
        "subOrders": [
            {
                "orderId": p["targetOrderId"],
                "type": str(p["spec"]["type"].value if hasattr(p["spec"]["type"], "value") else p["spec"]["type"]),
                "readableId": p["spec"]["readableId"],
                "shopName": p["spec"]["shopName"]
            }
            for p in prepared
        ]
    }

