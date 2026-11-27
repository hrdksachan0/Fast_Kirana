"""Order cache, formatting utilities, WhatsApp alerts, and FCM/PWA notification dispatchers."""
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
import asyncio
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
from utils.idempotency import (
    generate_order_cart_signature,
    compute_request_fingerprint,
    acquire_idempotency_lock_async,
    save_idempotency_response_async,
    record_idempotency_result_db_async,
    publish_idempotency_cache_async,
    release_idempotency_lock_async,
)
from services.order_calculation_service import (
    get_delivery_rules,
    get_product_type,
    get_product_limit,
    evaluate_surge_fee,
    geocode_address,
    calculate_coupon_discount,
    calculate_delivery_fee,
    calculate_surge_fee,
    resolve_verified_addon_price,
    calculate_item_addons,
)

logger = logging.getLogger("orders")

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])

import time

_order_details_cache: Dict[str, Any] = {}
_order_details_cache_time: Dict[str, float] = {}
ORDER_DETAILS_CACHE_TTL: float = 4.0  # 4 seconds TTL for high frequency tracking polling

def clear_order_cache(order_id: Optional[str] = None):
    global _order_details_cache, _order_details_cache_time
    if order_id:
        clean_target = str(order_id).strip().lstrip("#")
        base_target = re.sub(r'-[GR\d]+$', '', clean_target) if ("-G" in clean_target or "-R" in clean_target) else ""
        prefixes = {f"{order_id}:", f"{clean_target}:"}
        if base_target:
            prefixes.add(f"{base_target}:")
        for k in list(_order_details_cache.keys()):
            val = _order_details_cache.get(k)
            val_id = val.get("id") if isinstance(val, dict) else None
            val_rid = val.get("readableId") if isinstance(val, dict) else None
            val_cid = val.get("combinedId") if isinstance(val, dict) else None
            if (
                any(k.startswith(p) for p in prefixes)
                or val_id == order_id
                or val_id == clean_target
                or (val_rid and (val_rid == clean_target or (base_target and val_rid == base_target)))
                or (val_cid and val_cid == clean_target)
            ):
                _order_details_cache.pop(k, None)
                _order_details_cache_time.pop(k, None)
    else:
        _order_details_cache.clear()
        _order_details_cache_time.clear()



def to_iso_utc(dt: Optional[datetime]) -> Optional[str]:
    if not dt:
        return None
    if getattr(dt, "tzinfo", None) is None:
        return dt.isoformat() + "Z"
    return dt.isoformat()


def safe_enum_str(val: Any, fallback: str = "") -> str:
    if val is None:
        return fallback
    if hasattr(val, "value"):
        return str(val.value)
    return str(val)


def safe_float(val: Any, default: float = 0.0) -> float:
    if val is None:
        return default
    try:
        return float(val)
    except (ValueError, TypeError):
        return default



async def send_whatsapp_alert(phone: str, text: str, dedupe_key: Optional[str] = None) -> bool:
    token = re.sub(r'\s+', '', os.getenv("WHATSAPP_TOKEN", "").strip().strip('"').strip("'"))
    phone_id = re.sub(r'\s+', '', os.getenv("WHATSAPP_PHONE_NUMBER_ID", "").strip().strip('"').strip("'"))
    template_name = os.getenv("WHATSAPP_ORDER_TEMPLATE_NAME", "fastkirana_otp").strip().strip('"').strip("'")
    template_lang = os.getenv("WHATSAPP_TEMPLATE_LANG", "en").strip().strip('"').strip("'")

    if os.getenv("TESTING") == "1" or os.getenv("PYTEST_CURRENT_TEST"):
        logger.info(f"[WHATSAPP TEST MOCK] Suppressed live WhatsApp alert to {phone} during automated test run: {text}")
        return True

    if not token or not phone_id:
        logger.info(f"[WHATSAPP MOCK] To {phone}: {text}")
        return True

    digits = "".join(c for c in str(phone) if c.isdigit())
    clean_phone = digits if len(digits) > 10 else f"91{digits[-10:]}"

    # Deduplication Guard: Atomic distributed lock on Redis (1 hour TTL)
    # Extracts order readableId / key from dedupe_key or regex matching "#<id>" in text
    order_ref = dedupe_key
    if not order_ref and text:
        match = re.search(r"#([A-Za-z0-9_-]+)", text)
        if match:
            order_ref = match.group(1).split("[")[0].strip()
        else:
            order_ref = text[:32].replace(" ", "_")

    if order_ref:
        lock_key = f"lock:wa:alert:{clean_phone}:{order_ref}"
        try:
            from utils.cache import acquire_lock
            acquired = await acquire_lock(lock_key, ttl_seconds=3600)
            if not acquired:
                logger.info(f"[WhatsApp Alert] Skipping duplicate alert to {clean_phone} for key {lock_key}")
                return True
        except Exception as lock_err:
            logger.warning(f"[WhatsApp Alert] Dedupe lock error: {lock_err}")

    url = f"https://graph.facebook.com/v20.0/{phone_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    # Meta WhatsApp Cloud API requires pre-approved template for proactive business-initiated notifications
    templates_to_try = [template_name]
    for alt in ["fastkirana_otp", "fastkirana_order"]:
        if alt not in templates_to_try:
            templates_to_try.append(alt)

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            for t_name in templates_to_try:
                body = {
                    "messaging_product": "whatsapp",
                    "recipient_type": "individual",
                    "to": clean_phone,
                    "type": "template",
                    "template": {
                        "name": t_name,
                        "language": {"code": template_lang},
                        "components": [
                            {
                                "type": "body",
                                "parameters": [
                                    {
                                        "type": "text",
                                        "text": text,
                                    }
                                ],
                            }
                        ],
                    },
                }
                resp = await client.post(url, json=body, headers=headers)
                if resp.status_code in [200, 201]:
                    logger.info(f"[WhatsApp Alert] Sent template {t_name} to {clean_phone} successfully")
                    return True
                logger.warning(f"[WhatsApp Alert] Template {t_name} failed ({resp.status_code}): {resp.text}")

            # Fallback to direct text message
            text_body = {
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": clean_phone,
                "type": "text",
                "text": {
                    "body": text,
                },
            }
            resp = await client.post(url, json=text_body, headers=headers)
            if resp.status_code in [200, 201]:
                logger.info(f"[WhatsApp Alert] Sent text message to {clean_phone} successfully")
                return True
            logger.error(f"[WhatsApp Alert] Failed to send WhatsApp message to {clean_phone}: {resp.status_code} - {resp.text}")
            return False
    except Exception as e:
        logger.error(f"WhatsApp alert API exception: {str(e)}")
        return False


def resolve_admin_alert_phones(settings_map: dict, store_id: Optional[str] = None) -> list[str]:
    """
    Strictly resolves ONLY the phone numbers selected/enabled by admin in Settings.
    Checks store-scoped setting first, falling back to global setting.
    """
    alert_phones: list[str] = []
    store_prefix = f"store:{store_id}:" if store_id else ""

    def get_setting_val(key_name: str) -> Optional[str]:
        if store_prefix:
            store_val = settings_map.get(f"{store_prefix}{key_name}")
            if store_val is not None and str(store_val).strip() != "":
                return str(store_val).strip()
        global_val = settings_map.get(key_name)
        if global_val is not None and str(global_val).strip() != "":
            return str(global_val).strip()
        return None

    # 1. Master Admin 7054470303
    val_70544 = get_setting_val("whatsapp_notify_7054470303")
    if val_70544 and val_70544.lower() in ("true", "1", "yes"):
        if "7054470303" not in alert_phones:
            alert_phones.append("7054470303")

    # 2. Ops Admin 9450358388
    val_94503 = get_setting_val("whatsapp_notify_9450358388")
    if val_94503 and val_94503.lower() in ("true", "1", "yes"):
        if "9450358388" not in alert_phones:
            alert_phones.append("9450358388")

    # 3. Store Contact Phone toggle
    val_store_phone_toggle = get_setting_val("whatsapp_notify_store_phone")
    if val_store_phone_toggle and val_store_phone_toggle.lower() in ("true", "1", "yes"):
        store_phone = get_setting_val("contact_phone") or get_setting_val("store_phone")
        if store_phone:
            clean = re.sub(r'\D', '', str(store_phone))[-10:]
            if len(clean) == 10 and clean not in alert_phones:
                alert_phones.append(clean)

    # 4. Additional Store Alert Phones
    addl = get_setting_val("store_alert_phones") or get_setting_val("order_alert_phone")
    if addl:
        for p in re.findall(r'\b\d{10}\b', str(addl)):
            if p not in alert_phones:
                alert_phones.append(p)

    return alert_phones


async def get_active_alert_phones(db: AsyncSession, store_id: Optional[str] = None) -> list[str]:
    """
    Fetches StoreSetting records from DB and returns strictly the numbers selected/enabled by admin.
    """
    try:
        from models import StoreSetting
        res = await db.execute(select(StoreSetting))
        settings_map = {s.key: s.value for s in res.scalars().all()}
        return resolve_admin_alert_phones(settings_map, store_id)
    except Exception as e:
        logger.warning(f"Error fetching active alert phones: {e}")
        return []



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


_recent_customer_notifications: Dict[str, float] = {}
_recent_rider_packed_notifications: Dict[str, float] = {}

async def send_pwa_notification_to_user(user_id: str, title: str, body: str, data: dict, db: AsyncSession = None, phone: str = None):
    try:
        # Deduplicate customer status notifications for combined sub-orders within 30 seconds
        clean_order_id = re.sub(r'-[GR\d]+$', '', str(data.get("readableId") or data.get("orderId") or "").strip().lstrip("#"))
        order_status = str(data.get("status") or "").upper()
        dedup_key = f"{user_id or phone}:{clean_order_id}:{order_status}"
        now_ts = time.time()

        # Clean expired keys older than 60s
        for k in list(_recent_customer_notifications.keys()):
            if now_ts - _recent_customer_notifications[k] > 60:
                _recent_customer_notifications.pop(k, None)

        if dedup_key in _recent_customer_notifications and (now_ts - _recent_customer_notifications[dedup_key]) < 30:
            logger.info(f"Deduplicated duplicate customer notification for {dedup_key}")
            return
        _recent_customer_notifications[dedup_key] = now_ts

        # Check if user has registered device tokens
        tokens = []
        if user_id:
            async with AsyncSessionLocal() as session:
                stmt = select(FcmToken.token).where(FcmToken.userId == user_id)
                res = await session.execute(stmt)
                tokens = list(set(t for t in res.scalars().all() if t and len(t) > 10))

        # Strict Single Dispatch to Customer:
        # If user has registered FCM tokens, send multicast ONLY.
        # Fallback to phone / user topics ONLY if no active tokens are found.
        if tokens:
            await send_fcm_notification(tokens=tokens, title=title, body=body, data=data)
        elif phone:
            clean_phone = str(phone).replace("+91", "").replace(" ", "").replace("-", "").strip()
            if clean_phone and len(clean_phone) == 10:
                await send_fcm_topic_notification(f"phone_{clean_phone}", title, body, data)
        elif user_id:
            await send_fcm_topic_notification(f"user_{user_id}", title, body, data)
    except Exception as e:
        logger.error(f"Failed to dispatch FCM push notification to user: {str(e)}")


async def dispatch_admin_order_buzzer(
    order_id: str,
    base_readable: str,
    store_id: Optional[str],
    total_amount: float,
    status_val: str,
    is_paid: bool,
    outlets_name: str,
    is_combined: bool = False,
):
    """
    Dispatches EXACTLY 1 consolidated buzzer notification to Store Admin for a checkout.
    Strictly isolated by hub:
      - Ghatampur orders -> admin_orders_ghatampur / admin_orders_hub-209206 (7054470303)
      - Barharwa orders -> admin_orders_barharwa / admin_orders_hub-816101 (7633898577)
      - Super Admin HQ (9170942500) monitors all hubs.
    """
    try:
        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        target_store_id = store_id or "hub-209206"
        is_admin_pending = (status_val == "ADMIN_PENDING")

        if is_admin_pending:
            if is_paid:
                admin_title = f"💳 Online Paid Order #{base_readable}!"
                admin_body = f"Order #{base_readable} ({outlets_name}, ₹{total_amount:.2f}) is PAID online. Tap to review & process."
            else:
                admin_title = "🚨 New Order Awaiting Approval!"
                admin_body = f"Order #{base_readable} ({outlets_name}, ₹{total_amount:.2f}) needs admin approval. Tap to review."
        else:
            admin_title = f"🚨 New Live Order #{base_readable}!" if not is_combined else f"🚨 New Combined Order #{base_readable}!"
            admin_body = f"Order #{base_readable} ({outlets_name}, ₹{total_amount:.2f}) received! Tap to review & process."

        admin_data = {
            "orderId": order_id,
            "readableId": str(base_readable),
            "storeId": str(target_store_id),
            "status": status_val,
            "paymentStatus": "PAID" if is_paid else "PENDING",
            "isPaid": "true" if is_paid else "false",
            "screen": "admin-orders",
            "type": "NEW_ORDER",
            "role": "ADMIN",
            "action": "ORDER_BUZZER",
            "isCombined": "true" if is_combined else "false",
            "timestamp": now_ts,
            "sound": "order_chime",
        }

        # 1. Topic Broadcast - STRICTLY HUB-ISOLATED (EXACTLY 1 CANONICAL TOPIC PER HUB)
        # We NEVER broadcast to multiple duplicate topics or global 'admin_orders' to prevent double notifications.
        canonical_admin_topic = None
        if "209206" in str(target_store_id):
            canonical_admin_topic = "admin_orders_ghatampur"
        elif "816101" in str(target_store_id):
            canonical_admin_topic = "admin_orders_barharwa"
        elif "224122" in str(target_store_id):
            canonical_admin_topic = "admin_orders_akbarpur"
        elif target_store_id:
            canonical_admin_topic = f"admin_orders_{target_store_id}"

        if canonical_admin_topic:
            await send_fcm_topic_notification(canonical_admin_topic, admin_title, admin_body, admin_data)

        # 2. Super Admin HQ (9170942500) Direct Alert ONLY (if not on local hub topic)
        try:
            from database import AsyncSessionLocal
            async with AsyncSessionLocal() as s:
                adm_res = await s.execute(
                    select(FcmToken.token).join(User, FcmToken.userId == User.id).where(
                        and_(
                            User.role == Role.ADMIN,
                            User.phone.like("%9170942500%"),  # Super Admin HQ only
                        )
                    )
                )
                hq_toks = list(set(t for t in adm_res.scalars().all() if t and len(t) > 10))
                if hq_toks:
                    await send_fcm_notification(tokens=hq_toks, title=admin_title, body=admin_body, data=admin_data)
        except Exception as direct_err:
            logger.error(f"Failed Super Admin HQ direct FCM push: {direct_err}")
    except Exception as e:
        logger.error(f"Failed dispatch_admin_order_buzzer: {e}")


async def dispatch_isolated_order_fcm_notifications(
    order_id: str,
    readable_id: str,
    restaurant_id: Optional[str],
    shop_name: Optional[str],
    total: float,
    status_val: str,
    store_id: Optional[str] = None,
    payment_status: Optional[str] = None
):
    """
    Dispatches order notifications with absolute isolation & strict order lifecycle:
    1. If ADMIN_PENDING: ONLY notify Admin for manual approval via hub-isolated dispatch_admin_order_buzzer.
    2. If APPROVED (PENDING / CONFIRMED):
       - Restaurant Order: Alert Restaurant/Chef (restaurant_{id}). (Do NOT alert rider yet).
       - Grocery Order: Alert Picker/Vendor (picker_orders_{store_id}). (Do NOT alert rider yet).
       (Admin is already alerted ONCE at checkout level; do NOT duplicate).
    """
    try:
        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        is_admin_pending = (status_val == "ADMIN_PENDING")
        safe_shop_name = (shop_name or "").replace("FastKirana", "FastMinute")
        is_paid = (str(payment_status or "").upper() == "PAID")

        # ── CASE 1: MANUAL ADMIN APPROVAL REQUIRED ──
        if is_admin_pending:
            clean_base = str(readable_id).split("-")[0].lstrip("#")
            await dispatch_admin_order_buzzer(
                order_id=order_id,
                base_readable=clean_base,
                store_id=store_id,
                total_amount=total,
                status_val=status_val,
                is_paid=is_paid,
                outlets_name=safe_shop_name or (f"Hub {store_id}" if store_id else "Store"),
                is_combined=False,
            )
            return  # Stop here! Do not notify restaurant/picker/rider until approved

        # ── CASE 2: AUTO-APPROVED / CONFIRMED ──
        # Outlet-level routing for Pickers & Restaurant Chefs (Admin was already alerted at checkout)
        if restaurant_id:
            # Alert Restaurant/Chef to start cooking (Rider is notified when food is packed/prepared)
            rest_title = f"👨‍🍳 New Order for {safe_shop_name or 'Kitchen'}!"
            rest_body = f"Order #{readable_id} received (₹{total:.2f})! Open kitchen console to prepare dishes."
            rest_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "restaurantId": str(restaurant_id),
                "status": status_val,
                "paymentStatus": "PAID" if is_paid else "PENDING",
                "screen": "restaurant-console",
                "type": "NEW_ORDER",
                "timestamp": now_ts,
            }
            await send_fcm_topic_notification(f"restaurant_{restaurant_id}", rest_title, rest_body, rest_data)

        else:
            # Alert Grocery Picker / Vendor to pack items (Rider is notified when items are packed)
            store_label = f" [{store_id.replace('hub-', '').upper()}]" if store_id else ""
            grocery_title = f"📦 New Order #{readable_id} to Pick!{store_label}"
            grocery_body = f"New order #{readable_id} of ₹{total:.2f}. Tap to pack items."
            grocery_data = {
                "orderId": order_id,
                "readableId": str(readable_id),
                "storeId": str(store_id or ""),
                "status": status_val,
                "paymentStatus": "PAID" if is_paid else "PENDING",
                "screen": "picker",
                "type": "NEW_ORDER",
                "role": "PICKER",
                "timestamp": now_ts,
            }
            picker_topic = f"picker_orders_{store_id}" if store_id else "picker_orders"
            await send_fcm_topic_notification(picker_topic, grocery_title, grocery_body, grocery_data)

        # Note: Riders are NOT notified upon initial order creation.
        # Store pickers/kitchen pack the order first; the designated rider is buzzed
        # when the admin assigns the delivery partner to the order.
    except Exception as e:
        logger.error(f"Failed to dispatch isolated FCM push notification: {str(e)}")


async def dispatch_isolated_status_update_notifications(
    order_id: str,
    readable_id: str,
    restaurant_id: Optional[str],
    shop_name: Optional[str],
    status_val: str,
    store_id: Optional[str] = None,
    delivery_user_id: Optional[str] = None
):
    """
    Dispatches order status update notifications with strict outlet isolation:
    - When PACKED: Alert assigned Delivery Rider ONLY to pick up and deliver.
      (Unassigned orders NEVER spam riders; they are dispatched via dispatch_rider_assignment_notification upon assignment)
    - Restaurant orders alert canonical restaurant topic.
    - Grocery orders alert darkstore pickers.
    """
    try:
        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        base_order_no = re.sub(r'-[GR\d]+$', '', readable_id or "")
        safe_shop_name = (shop_name or "").replace("FastKirana", "FastMinute")

        # ── RIDER NOTIFICATION: Triggered ONLY when order is PACKED & an actual designated rider is assigned ──
        # If order is UNASSIGNED (delivery_user_id is None), do NOT spam riders with personal delivery alarms!
        # When an admin assigns a rider, dispatch_rider_assignment_notification buzzes that rider directly.
        if (status_val == "PACKED" or (restaurant_id and status_val in ["COOKED", "PREPARED"])) and delivery_user_id:
            clean_duid = str(delivery_user_id).strip()
            if clean_duid.upper() not in ["", "NONE", "NULL", "UNASSIGNED", "STORE_ADMIN_SELF"]:
                now_s = time.time()
                dedup_key = f"{clean_duid}:{base_order_no}:PACKED"
                if dedup_key not in _recent_rider_packed_notifications or (now_s - _recent_rider_packed_notifications[dedup_key]) > 30:
                    _recent_rider_packed_notifications[dedup_key] = now_s
                    # Clean expired keys older than 60s
                    for k in list(_recent_rider_packed_notifications.keys()):
                        if now_s - _recent_rider_packed_notifications[k] > 60:
                            _recent_rider_packed_notifications.pop(k, None)

                    rider_title = f"🛵 Order #{base_order_no} is Packed & Ready!"
                    rider_body = f"Order #{base_order_no} ({safe_shop_name or 'Store'}) is packed. Tap to pick up & deliver."
                    rider_data = {
                        "orderId": order_id,
                        "readableId": str(readable_id),
                        "storeId": str(store_id or ""),
                        "restaurantId": str(restaurant_id or ""),
                        "status": status_val,
                        "screen": "delivery",
                        "url": "/delivery",
                        "type": "ORDER_PACKED",
                        "role": "DELIVERY",
                        "timestamp": now_ts,
                    }
                    # Send directly to the designated assigned rider
                    await send_fcm_topic_notification(f"user_{clean_duid}", rider_title, rider_body, rider_data)

        if restaurant_id:
            # RESTAURANT / KITCHEN ISOLATED STATUS UPDATE:
            # Only notify restaurant quietly when an order is CANCELLED.
            # Intermediate status transitions (CONFIRMED/PACKED/SHIPPED/DELIVERED) update live UI via Realtime/WS without chime spam.
            if str(status_val or "").upper() == "CANCELLED":
                rest_title = f"❌ Order #{base_order_no} Cancelled"
                rest_body = f"Order #{base_order_no} for {safe_shop_name or 'Kitchen'} has been cancelled."
                rest_data = {
                    "orderId": order_id,
                    "readableId": str(readable_id),
                    "restaurantId": str(restaurant_id),
                    "status": "CANCELLED",
                    "screen": "restaurant-console",
                    "type": "ORDER_STATUS_UPDATE",
                    "timestamp": now_ts,
                }
                await send_fcm_topic_notification(f"restaurant_{restaurant_id}", rest_title, rest_body, rest_data)

        else:
            # GROCERY DARK STORE ISOLATED STATUS UPDATE
            # Only push notifications for statuses pickers care about (CONFIRMED/PENDING for packing, CANCELLED to stop).
            # SHIPPED and DELIVERED are rider/customer delivery states that store pickers do not need chimes for.
            if str(status_val or "").upper() in ["CONFIRMED", "PENDING", "CANCELLED"]:
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
                picker_topic = f"picker_orders_{store_id}" if store_id else "picker_orders"
                await send_fcm_topic_notification(picker_topic, grocery_title, grocery_body, grocery_data)
    except Exception as e:
        logger.error(f"Failed to dispatch isolated status FCM push notification: {str(e)}")


async def dispatch_rider_assignment_notification(
    order_id: str,
    readable_id: str,
    rider_identifier: str,
    status_val: str,
    total: float = 0.0,
    store_id: Optional[str] = None
):
    """
    Dispatches high-priority alarm notification & FCM buzzer to assigned rider.
    Supports rider lookup by user ID or phone number.
    Rings fastkirana_order_buzzer_v2 with order_chime sound.
    """
    try:
        clean_rider_id = str(rider_identifier or "").strip()
        if not clean_rider_id or clean_rider_id.upper() in ["UNASSIGNED", "NONE", "NULL", "STORE_ADMIN_SELF"]:
            return

        async with AsyncSessionLocal() as session:
            clean_digits = re.sub(r"\D", "", clean_rider_id)[-10:]
            rider_conditions = [User.id == clean_rider_id]
            if clean_digits and len(clean_digits) == 10:
                rider_conditions.append(User.phone == clean_rider_id)
                rider_conditions.append(User.phone.like(f"%{clean_digits}"))

            rider_stmt = select(User).where(or_(*rider_conditions))
            rider_res = await session.execute(rider_stmt)
            rider_user = rider_res.scalars().first()

            rider_user_ids = {clean_rider_id}
            rider_phone = clean_digits
            if rider_user:
                rider_user_ids.add(rider_user.id)
                if rider_user.phone:
                    clean_p = re.sub(r"\D", "", rider_user.phone)[-10:]
                    if len(clean_p) == 10:
                        rider_phone = clean_p

            tokens_stmt = select(FcmToken.token).where(FcmToken.userId.in_(list(rider_user_ids)))
            tokens_res = await session.execute(tokens_stmt)
            rider_tokens = list(set([t for t in tokens_res.scalars().all() if t and len(t) > 10]))

            clean_readable = str(readable_id or order_id).lstrip("#")
            fcm_data = {
                "orderId": order_id,
                "readableId": clean_readable,
                "screen": "delivery-dashboard",
                "type": "DELIVERY_ASSIGNED",
                "status": status_val or "CONFIRMED",
                "orderStatus": status_val or "CONFIRMED",
                "role": "DELIVERY",
                "total": str(total or 0.0),
            }

            alarm_title = "🚨 New Delivery Assigned! 🛵"
            alarm_body = f"Order #{clean_readable} has been assigned to you. Tap to view and deliver."

            # Strict Single Dispatch: If direct tokens exist, send multicast ONLY.
            # Only fallback to topic broadcast if no registered tokens are found.
            # This completely eliminates 2x-4x duplicate notifications on mobile devices!
            if rider_tokens:
                await send_fcm_notification(
                    tokens=rider_tokens,
                    title=alarm_title,
                    body=alarm_body,
                    data=fcm_data
                )
            elif rider_phone and len(rider_phone) == 10:
                await send_fcm_topic_notification(
                    topic=f"phone_{rider_phone}",
                    title=alarm_title,
                    body=alarm_body,
                    data=fcm_data
                )
            elif rider_user_ids:
                for r_uid in rider_user_ids:
                    await send_fcm_topic_notification(
                        topic=f"user_{r_uid}",
                        title=alarm_title,
                        body=alarm_body,
                        data=fcm_data
                    )

            # 4. Instant Supabase Realtime broadcast to rider & admin channels
            try:
                from utils.supabase_broadcast import broadcast_supabase_realtime
                sb_topics = [
                    "admin-global-orders-websocket",
                    f"order-live-tracking-{order_id}",
                ]
                if clean_readable:
                    sb_topics.append(f"order-live-tracking-{clean_readable}")
                for r_uid in rider_user_ids:
                    sb_topics.append(f"rider-orders-{r_uid}")

                sb_payload = {
                    "id": order_id,
                    "orderId": order_id,
                    "readableId": clean_readable,
                    "status": status_val or "CONFIRMED",
                    "deliveryUserId": rider_user.id if rider_user else clean_rider_id,
                    "storeId": store_id,
                    "updatedAt": datetime.utcnow().isoformat()
                }
                asyncio.create_task(broadcast_supabase_realtime(sb_topics, "status_update", sb_payload))
                asyncio.create_task(broadcast_supabase_realtime(sb_topics, "order_claimed", sb_payload))
            except Exception as sb_err:
                logger.warning(f"Rider assignment Supabase broadcast note: {sb_err}")

    except Exception as e:
        logger.error(f"Failed to dispatch rider assignment alert for order {order_id}: {str(e)}")


async def dispatch_restaurant_order_verified_notification(
    order_id: str,
    readable_id: str,
    restaurant_id: str,
    shop_name: Optional[str] = None,
    total: float = 0.0
):
    """
    Dispatches high-priority kitchen buzzer notification to restaurant owner/chef
    ONLY when Admin verification is completed.
    Strictly outlet-isolated: only sent to this restaurant's topic & registered owner tokens.
    """
    try:
        clean_rest_id = str(restaurant_id or "").strip()
        if not clean_rest_id:
            return

        now_ts = str(int(datetime.utcnow().timestamp() * 1000))
        clean_readable = str(readable_id or order_id).lstrip("#")
        safe_name = str(shop_name or "Kitchen").replace("FastKirana", "FastMinute")

        rest_title = f"👨‍🍳 New Order Verified by Admin! 🛎️"
        rest_body = f"Order #{clean_readable} for {safe_name} (₹{total:.2f}) verified! Open kitchen console to prepare dishes."
        rest_data = {
            "orderId": order_id,
            "readableId": clean_readable,
            "restaurantId": clean_rest_id,
            "status": "CONFIRMED",
            "orderStatus": "CONFIRMED",
            "screen": "restaurant-console",
            "type": "NEW_ORDER",
            "role": "RESTAURANT",
            "timestamp": now_ts,
            "total": str(total or 0.0),
        }

        # Strict Single Dispatch: If direct tokens exist, send multicast ONLY.
        # Fallback to restaurant topic or phone topics ONLY if no active tokens are registered.
        async with AsyncSessionLocal() as session:
            u_stmt = select(User.id, User.phone).where(
                or_(User.assignedRestaurantId == clean_rest_id, User.assignedRestaurantId.ilike(f"%{clean_rest_id}%")),
                User.role.in_([Role.RESTAURANT, Role.CHEF, Role.RESTAURANT_OWNER])
            )
            u_res = await session.execute(u_stmt)
            matched_users = u_res.all()
            matched_uids = [u[0] for u in matched_users if u[0]]
            matched_phones = [re.sub(r"\D", "", u[1])[-10:] for u in matched_users if u[1]]

            owner_tokens = []
            if matched_uids:
                t_stmt = select(FcmToken.token).where(FcmToken.userId.in_(matched_uids))
                t_res = await session.execute(t_stmt)
                owner_tokens = list(set([t for t in t_res.scalars().all() if t and len(t) > 10]))

            if owner_tokens:
                # 1. Direct Multicast ONLY to outlet staff
                await send_fcm_notification(owner_tokens, rest_title, rest_body, rest_data)
            else:
                # Fallback to topic broadcast if no device tokens found
                await send_fcm_topic_notification(f"restaurant_{clean_rest_id}", rest_title, rest_body, rest_data)

        # 3. Supabase Realtime broadcast to this restaurant's live orders channel
        try:
            from utils.supabase_broadcast import broadcast_supabase_realtime
            sb_topics = [
                f"restaurant-orders-{clean_rest_id}",
                f"kitchen_{clean_rest_id}",
                "admin-global-orders-websocket",
                f"order-live-tracking-{order_id}",
            ]
            sb_payload = {
                "id": order_id,
                "orderId": order_id,
                "readableId": clean_readable,
                "restaurantId": clean_rest_id,
                "shopName": safe_name,
                "status": "CONFIRMED",
                "total": float(total or 0.0),
                "updatedAt": datetime.utcnow().isoformat()
            }
            asyncio.create_task(broadcast_supabase_realtime(sb_topics, "new_order", sb_payload))
            asyncio.create_task(broadcast_supabase_realtime(sb_topics, "status_update", sb_payload))
        except Exception as sb_err:
            logger.warning(f"Restaurant order realtime broadcast note: {sb_err}")

    except Exception as e:
        logger.error(f"Failed to dispatch restaurant order verified notification: {str(e)}")


def _build_replayed_order_payload(main_match: Any, all_matches: List[Any]) -> Dict[str, Any]:
    matched_user = None
    try:
        matched_user = main_match.user
    except Exception:
        pass
    matched_addr = None
    try:
        matched_addr = main_match.address
    except Exception:
        pass
    matched_items = []
    try:
        raw_items = main_match.items or []
        matched_items = [
            {
                "id": item.id,
                "productId": item.productId,
                "name": item.name,
                "price": float(item.price),
                "quantity": item.quantity,
                "imageUrl": item.imageUrl,
                "selectedVariant": item.selectedVariant,
                "costPrice": float(item.costPrice or 0),
                "variants": item.variants,
                "notes": item.notes,
            }
            for item in raw_items
        ]
    except Exception:
        pass

    return {
        "id": main_match.id,
        "readableId": main_match.readableId,
        "userId": main_match.userId,
        "type": main_match.type.value if hasattr(main_match.type, "value") else str(main_match.type),
        "restaurantId": main_match.restaurantId,
        "status": main_match.status.value if hasattr(main_match.status, "value") else str(main_match.status),
        "subtotal": float(main_match.subtotal or 0),
        "discount": float(main_match.discount or 0),
        "deliveryFee": float(main_match.deliveryFee or 0),
        "taxes": float(main_match.taxes or 0),
        "miscFee": float(main_match.miscFee or 0),
        "packagingFee": float(main_match.miscFee or 0),
        "total": float(main_match.total or 0),
        "paymentMethod": main_match.paymentMethod.value if hasattr(main_match.paymentMethod, "value") else str(main_match.paymentMethod),
        "paymentStatus": main_match.paymentStatus.value if hasattr(main_match.paymentStatus, "value") else str(main_match.paymentStatus),
        "estimatedDelivery": to_iso_utc(main_match.estimatedDelivery),
        "deliveryMethod": main_match.deliveryMethod,
        "isB2B": main_match.isB2B,
        "shopName": main_match.shopName,
        "shopPhone": main_match.shopPhone,
        "notes": main_match.notes,
        "couponCode": main_match.couponCode,
        "customerName": matched_user.name if matched_user else None,
        "customerPhone": (matched_user.phone if matched_user else None) or (matched_addr.phone if matched_addr else None),
        "customerAddress": f"{matched_addr.houseNo or ''}, {matched_addr.street or ''}, {matched_addr.area or ''}, {matched_addr.city or ''}, {matched_addr.pincode or ''}" if matched_addr else None,
        "createdAt": to_iso_utc(main_match.createdAt),
        "updatedAt": to_iso_utc(main_match.updatedAt),
        "confirmedAt": to_iso_utc(main_match.confirmedAt),
        "packedAt": to_iso_utc(main_match.packedAt),
        "shippedAt": to_iso_utc(main_match.shippedAt),
        "deliveredAt": to_iso_utc(main_match.deliveredAt),
        "items": matched_items,
        "address": {
            "id": matched_addr.id,
            "houseNo": matched_addr.houseNo,
            "street": matched_addr.street,
            "area": matched_addr.area,
            "city": matched_addr.city,
            "pincode": matched_addr.pincode,
            "phone": matched_addr.phone,
            "label": matched_addr.label,
        } if matched_addr else None,
        "order": {
            "id": main_match.id,
            "readableId": main_match.readableId,
            "status": main_match.status.value if hasattr(main_match.status, "value") else str(main_match.status),
            "total": float(main_match.total or 0),
            "restaurantId": main_match.restaurantId,
            "shopName": main_match.shopName,
        },
        "orders": [{
            "id": o.id,
            "readableId": o.readableId,
            "status": o.status.value if hasattr(o.status, "value") else str(o.status),
            "total": float(o.total or 0),
            "restaurantId": o.restaurantId,
            "shopName": o.shopName,
        } for o in all_matches],
        "idempotencyReplayed": True,
    }
