"""Main Orders & Checkout Router (aggregates notifications, read endpoints, and lifecycle mutations)."""
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
import time
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
from routers.orders_notifications import (
    _order_details_cache,
    _order_details_cache_time,
    ORDER_DETAILS_CACHE_TTL,
    clear_order_cache,
    to_iso_utc,
    safe_enum_str,
    safe_float,
    send_whatsapp_alert,
    resolve_admin_alert_phones,
    get_active_alert_phones,
    upload_to_cloudinary,
    send_pwa_notification_to_roles,
    send_pwa_notification_to_user,
    dispatch_admin_order_buzzer,
    dispatch_isolated_order_fcm_notifications,
    dispatch_isolated_status_update_notifications,
    dispatch_rider_assignment_notification,
    dispatch_restaurant_order_verified_notification,
    _build_replayed_order_payload,
)
from routers.orders_read import (
    list_orders,
    get_order_details,
    track_order,
)
from routers.orders_mutations import (
    update_order,
    update_order_status_alias,
    delete_all_cancelled_orders,
    update_order_payment,
    convert_order_to_cod,
    normalize_restaurant_id,
    edit_order,
)

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])

@router.get("/test-whatsapp-alert")
async def test_whatsapp_alert_endpoint(phone: str = "7054470303"):
    """Live diagnostic endpoint to test WhatsApp alert delivery and inspect Meta response."""
    token = re.sub(r'\s+', '', os.getenv("WHATSAPP_TOKEN", "").strip().strip('"').strip("'"))
    phone_id = re.sub(r'\s+', '', os.getenv("WHATSAPP_PHONE_NUMBER_ID", "").strip().strip('"').strip("'"))
    template_name = os.getenv("WHATSAPP_ORDER_TEMPLATE_NAME", "fastkirana_otp").strip().strip('"').strip("'")
    template_lang = os.getenv("WHATSAPP_TEMPLATE_LANG", "en").strip().strip('"').strip("'")

    digits = "".join(c for c in str(phone) if c.isdigit())
    clean_phone = digits if len(digits) > 10 else f"91{digits[-10:]}"
    url = f"https://graph.facebook.com/v20.0/{phone_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    template_body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": clean_phone,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {"code": template_lang},
            "components": [
                {
                    "type": "body",
                    "parameters": [{"type": "text", "text": "Test Order #1993 for FastMinute of Rs.320"}],
                }
            ],
        },
    }

    results = {}
    async with httpx.AsyncClient(timeout=10) as client:
        try:
            r = await client.post(url, json=template_body, headers=headers)
            results["template_attempt"] = {
                "status": r.status_code,
                "body": r.json() if "application/json" in r.headers.get("content-type", "") else r.text,
            }
        except Exception as e:
            results["template_attempt"] = {"error": str(e)}

        try:
            waba_r = await client.get(f"https://graph.facebook.com/v20.0/{phone_id}?fields=whatsapp_business_account", headers=headers)
            waba_id = waba_r.json().get("whatsapp_business_account", {}).get("id")
            if waba_id:
                t_r = await client.get(f"https://graph.facebook.com/v20.0/{waba_id}/message_templates?name={template_name}", headers=headers)
                results["template_schema"] = t_r.json()
        except Exception as e:
            results["template_schema_error"] = str(e)

    return {
        "phone": clean_phone,
        "phone_id": phone_id,
        "token_prefix": token[:10] + "..." if token else None,
        "template_name": template_name,
        "template_lang": template_lang,
        "results": results,
    }


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
    
    from services.tracer_service import TracerService
    trace_id = getattr(request.state, "trace_id", None) or payload.get("traceId") or payload.get("trace_id") or TracerService.generate_trace_id()

    # ── VALIDATE PAYMENT REFERENCE IDENTIFIERS ──
    raw_cf_order = str(payload.get("cfOrderId") or "").strip()
    raw_payment_id = str(payload.get("paymentId") or payload.get("cfPaymentId") or "").strip()
    check_ref = raw_cf_order or (raw_payment_id.replace("CF_", "") if raw_payment_id.startswith("CF_") else (raw_payment_id if raw_payment_id.startswith("cf_") else ""))
    if check_ref and re.search(r"[^a-zA-Z0-9_-]", check_ref):
        raise HTTPException(
            status_code=400,
            detail="Invalid payment reference format: payment ID must contain only alphanumeric characters, underscores, and hyphens."
        )

    # ── RESILIENT USER RESOLUTION (Supports Web, Flutter, Guests) ──
    user_obj = None
    if user_id:
        user_stmt = select(User).where(User.id == user_id)
        user_res = await db.execute(user_stmt)
        user_obj = user_res.scalars().first()

    # If user doesn't exist by ID, resolve by phone or auto-create in PostgreSQL
    if not user_obj:
        raw_p = payload.get("phone") or payload.get("userPhone") or payload.get("buyerPhone") or "7054470303"
        clean_phone = "".join(filter(str.isdigit, str(raw_p)))[-10:]
        if not clean_phone:
            clean_phone = "7054470303"

        phone_stmt = select(User).where(User.phone == clean_phone)
        phone_res = await db.execute(phone_stmt)
        user_obj = phone_res.scalars().first()

        if not user_obj:
            user_id = user_id if (user_id and not user_id.startswith("default_") and not user_id.startswith("guest_")) else f"usr_{uuid.uuid4().hex[:16]}"
            user_name = payload.get("userName") or payload.get("buyerName") or payload.get("customerName") or "FastMinute Customer"
            user_obj = User(
                id=user_id,
                name=user_name,
                email=f"{clean_phone}@fastkirana.in",
                phone=clean_phone,
                role="USER"
            )
            db.add(user_obj)
            await db.flush()
        else:
            user_id = user_obj.id

    # ── EARLY IDEMPOTENCY CHECK FOR ONLINE/CASHFREE ORDERS ──
    # If this Cashfree payment was already processed (auto-recovered on verify or webhook),
    # immediately return the existing order without re-evaluating stock, store hours, or coupons.
    early_cf_order = str(payload.get("cfOrderId") or "").strip()
    early_pm_id = str(payload.get("paymentId") or payload.get("cfPaymentId") or "").strip()
    early_cf_id = early_cf_order or (early_pm_id.replace("CF_", "") if early_pm_id.startswith("CF_") else (early_pm_id if early_pm_id.startswith("cf_") else ""))
    if early_cf_id:
        early_clean_cf = re.sub(r"[^a-zA-Z0-9_-]", "_", early_cf_id)[:45]
        early_base_cf = re.sub(r"_r\d+$", "", early_clean_cf.strip())
        try:
            exist_res = await db.execute(
                select(Order).where(
                    or_(
                        Order.id == early_clean_cf,
                        Order.id == early_base_cf,
                        Order.readableId == early_clean_cf,
                        Order.readableId == early_base_cf,
                        Order.cfOrderId == early_clean_cf,
                        Order.cfOrderId == early_base_cf,
                    )
                ).options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user)).order_by(Order.createdAt.asc())
            )
            existing_matched = exist_res.scalars().all()
            if existing_matched:
                first_match = existing_matched[0]
                first_phone = re.sub(r"\D", "", str(first_match.user.phone if first_match.user else ""))[-10:]
                caller_phone = re.sub(r"\D", "", str(user_obj.phone if user_obj else payload.get("phone") or ""))[-10:]
                is_owner = (first_match.userId == user_id) or (first_phone and caller_phone and first_phone == caller_phone)
                if not is_owner:
                    logger.error(f"[Payment Security] Order #{first_match.readableId} belongs to user '{first_match.userId}', but caller is '{user_id}'. Replay rejected.")
                    raise HTTPException(status_code=403, detail="Payment reference belongs to another user's order.")
                all_matches = list(existing_matched)
                if first_match.combinedId:
                    comb_res = await db.execute(
                        select(Order).where(Order.combinedId == first_match.combinedId)
                        .options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user))
                        .order_by(Order.createdAt.asc())
                    )
                    all_matches = comb_res.scalars().all()
                main_match = next((o for o in all_matches if not o.restaurantId), all_matches[0])
                logger.info(f"🛡️ [EARLY IDEMPOTENCY] FastAPI returning existing order #{main_match.readableId} for CF ID {early_clean_cf}")
                try:
                    from routers.websockets import manager as early_ws_manager
                    for o in all_matches:
                        asyncio.create_task(early_ws_manager.broadcast_to_channel("general", {
                            "event": "NEW_ORDER",
                            "type": "new-order",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "shopName": o.shopName,
                            "status": o.status.value if hasattr(o.status, "value") else str(o.status),
                            "paymentStatus": "PAID" if str(getattr(o.paymentStatus, "value", o.paymentStatus)).upper() == "PAID" else "PENDING",
                            "paymentMethod": "UPI",
                            "total": float(o.total or 0),
                            "createdAt": o.createdAt.isoformat() if hasattr(o, "createdAt") and o.createdAt else datetime.utcnow().isoformat(),
                            "restaurantId": o.restaurantId,
                            "storeId": o.storeId,
                            "isPaid": True,
                        }))
                except Exception as idemp_ws_err:
                    logger.warning(f"[Early Idempotency] WebSocket broadcast notice: {idemp_ws_err}")
                return _build_replayed_order_payload(main_match, all_matches)
        except HTTPException:
            raise
        except Exception as early_idemp_err:
            logger.warning(f"Early idempotency check notice: {early_idemp_err}")
    # H2 FIX: Idempotency lock check with canonical request fingerprint
    raw_req_items = payload.get("items", [])
    raw_req_addr = payload.get("addressId")
    raw_req_pm = payload.get("paymentMethod")
    raw_req_coupon = payload.get("couponCode")
    raw_req_tip = float(payload.get("tipAmount") or payload.get("tip") or 0.0)
    request_fingerprint = compute_request_fingerprint(
        user_id=user_id,
        items=raw_req_items,
        address_id=raw_req_addr,
        payment_method=raw_req_pm,
        coupon_code=raw_req_coupon,
        tip_amount=raw_req_tip,
    )
    idempotency_key = (
        request.headers.get("x-idempotency-key")
        or request.headers.get("idempotency-key")
        or generate_order_cart_signature(user_id, raw_req_items, raw_req_addr, raw_req_pm)
    )
    lock_acquired = False
    is_dup, is_proc, cached_resp = await acquire_idempotency_lock_async(
        idempotency_key, db=db, user_id=user_id, request_hash=request_fingerprint
    )
    if is_dup:
        if cached_resp:
            return {**cached_resp, "idempotencyReplayed": True}
        raise HTTPException(
            status_code=409,
            detail="An order with these items is already being processed. Please wait a moment."
        )
    lock_acquired = True

    # Check if account is blocked (reuse resolved user_obj without redundant DB roundtrip)
    if not user_obj and user_id:
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

        qty = int(raw_item.get("quantity", 1))
        if qty <= 0:
            raise HTTPException(status_code=400, detail="Item quantity must be a positive integer")

        raw_pid_str = str(prod_id) if prod_id else ""
        normalized_items.append({
            "product": {
                "id": raw_pid_str,
                "name": prod_name,
                "slug": prod_slug,
                "price": prod_price,
                "restaurantId": rest_id_payload,
                "selectedAddons": addons_payload,
            },
            "productId": raw_pid_str.split("_")[0] if raw_pid_str else None,
            "quantity": qty,
            "price": prod_price,
            "selectedVariant": raw_item.get("selectedVariant") or (raw_pid_str.split("_")[1] if "_" in raw_pid_str and raw_pid_str.split("_")[1] != "addons" else None),
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
    default_support_phone = settings_map.get("contact_phone") or os.getenv("SUPPORT_PHONE", "+919450358388")
    
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
        
        await db.flush()
        final_address_id = pickup_address.id

    address_stmt = select(Address).where(Address.id == final_address_id)
    address_res = await db.execute(address_stmt)
    address = address_res.scalars().first()

    # Resilient fallback: If addressId is invalid/missing/default (e.g. Flutter addr_default or unsynced ID)
    if not address and user_id:
        user_addr_stmt = select(Address).where(Address.userId == user_id)
        user_addr_res = await db.execute(user_addr_stmt)
        address = user_addr_res.scalars().first()
        if address:
            final_address_id = address.id

    if not address:
        cust_addr = str(payload.get("customerAddress") or payload.get("address") or "").strip()
        addr_parts = [p.strip() for p in cust_addr.split(",") if p.strip()] if cust_addr else []

        h_no = payload.get("houseNo") or (addr_parts[0] if len(addr_parts) > 0 else "Ghatampur Express Zone")
        st = payload.get("street") or (addr_parts[1] if len(addr_parts) > 1 else "Main Road")
        ar = payload.get("area") or (addr_parts[2] if len(addr_parts) > 2 else "Ghatampur")
        ct = payload.get("city") or (addr_parts[3] if len(addr_parts) > 3 else "Ghatampur")
        pin = str(payload.get("pincode") or (addr_parts[4] if len(addr_parts) > 4 else "209206"))
        p_raw = payload.get("phone") or payload.get("customerPhone") or payload.get("userPhone") or "7054470303"
        p_clean = "".join(filter(str.isdigit, str(p_raw)))[-10:]
        p_val = f"+91{p_clean}" if len(p_clean) == 10 else "+917054470303"

        lat_val = payload.get("lat") or payload.get("latitude")
        lng_val = payload.get("lng") or payload.get("longitude")
        try:
            f_lat = float(lat_val) if lat_val is not None else 26.1534185
            f_lng = float(lng_val) if lng_val is not None else 80.1714024
        except (ValueError, TypeError):
            f_lat, f_lng = 26.1534185, 80.1714024

        new_addr_id = f"addr_{uuid.uuid4().hex[:16]}"
        address = Address(
            id=new_addr_id,
            userId=user_id,
            label="Home",
            houseNo=h_no,
            street=st,
            area=ar,
            city=ct,
            pincode=pin,
            phone=p_val,
            lat=f_lat,
            lng=f_lng,
            isDefault=True
        )
        db.add(address)
        await db.flush()
        final_address_id = address.id

    # Update phone if passed
    raw_phone = payload.get("phone") or payload.get("customerPhone")
    if raw_phone and address:
        clean_p = "".join(filter(str.isdigit, str(raw_phone)))[-10:]
        if len(clean_p) == 10:
            address.phone = f"+91{clean_p}"
            await db.flush()

    # Fast Geocode resolution: prevent external geocoding network latency from stalling checkout
    target_lat = address.lat
    target_lng = address.lng
    if (target_lat is None or target_lng is None) and address:
        p_clean = (address.pincode or "").strip()
        c_clean = (address.city or "").lower().strip()
        s_clean = (address.street or "").lower().strip()
        a_clean = (address.area or "").lower().strip()

        # Barharwa / Pakur Central Hub (816101 / 816107)
        if p_clean in ["816101", "816107"] or any(k in c_clean or k in s_clean or k in a_clean for k in ["barharwa", "pakur", "sahibganj"]):
            target_lat, target_lng = 24.857140, 87.778952
        # Akbarpur Central Hub (224122)
        elif p_clean == "224122" or any(k in c_clean or k in s_clean or k in a_clean for k in ["akbarpur", "ambedkar nagar"]):
            target_lat, target_lng = 26.4380, 82.5400
        # Ghatampur Central Hub (209206)
        else:
            target_lat, target_lng = 26.1534185, 80.1714024

        address.lat = target_lat
        address.lng = target_lng
        address_query = f"{address.houseNo or ''} {address.street or ''} {address.area or ''}, {address.city or ''}, {address.pincode or ''}".strip()
        if address_query:
            async def _bg_geocode(addr_id: str, query_str: str):
                try:
                    c = await geocode_address(query_str)
                    if c:
                        async with AsyncSessionLocal() as s:
                            st = select(Address).where(Address.id == addr_id)
                            r = await s.execute(st)
                            a = r.scalars().first()
                            if a:
                                a.lat = c["lat"]
                                a.lng = c["lng"]
                                await s.commit()
                except Exception as g_err:
                    logger.warning(f"Background geocode update notice for address {addr_id}: {g_err}")

            background_tasks.add_task(_bg_geocode, address.id, address_query)

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
            surge_charge = await evaluate_surge_fee(settings_map, hub_lat, hub_lng, float(matched_hub.surgeCharge or 0.0))

            dist_km = get_distance_km(hub_lat, hub_lng, target_lat, target_lng)
            delivery_rules = get_delivery_rules(dist_km, max_radius, surge_charge, settings_map)

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
            surge_charge = await evaluate_surge_fee(settings_map, store_lat, store_lng)

            dist_km = get_distance_km(store_lat, store_lng, target_lat, target_lng)
            delivery_rules = get_delivery_rules(dist_km, max_radius, surge_charge, settings_map)

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
    product_ids = []
    product_names = []
    for i in items:
        prod_payload = i.get("product") or {}
        pid = prod_payload.get("id") or i.get("productId")
        if pid:
            pid_str = str(pid)
            product_ids.append(pid_str)
            if "_" in pid_str:
                product_ids.append(pid_str.split("_")[0])
        pname = prod_payload.get("name") or i.get("name")
        if pname:
            pname_str = str(pname).strip()
            product_names.append(pname_str)
            clean_pname = re.sub(r'\s*\([^)]*\)\s*$', '', pname_str).strip()
            if clean_pname and clean_pname != pname_str:
                product_names.append(clean_pname)
    product_slugs = [i["product"]["slug"] for i in items if i.get("product", {}).get("slug")]

    search_filters = []
    if product_ids:
        search_filters.append(Product.id.in_(product_ids))
    if product_slugs:
        search_filters.append(Product.slug.in_(product_slugs))
    if product_names:
        search_filters.append(func.lower(Product.name).in_([n.lower() for n in product_names]))

    p_stmt = select(Product).options(selectinload(Product.category)).where(
        or_(*search_filters)
    ).with_for_update()
    p_res = await db.execute(p_stmt)
    db_products = list(p_res.scalars().all())
    db_product_ids = {p.id for p in db_products}

    # ── COMBO / BUNDLE EXPANSION ──
    # Automatically unpacks meal combos into constituent restaurant dishes and darkstore drinks
    # Ensures grocery cold drinks route to FastMinute Darkstore (-G) and food routes to Restaurant (-R)
    expanded_items = []
    missing_bundle_pids = []
    has_combos = False

    for item in items:
        prod_payload = item.get("product") or {}
        raw_id = str(prod_payload.get("id") or item.get("productId") or "")
        lookup_id = raw_id.split("_")[0] if "_" in raw_id else raw_id
        db_prod = next((p for p in db_products if p.id == lookup_id or (prod_payload.get("slug") and p.slug == prod_payload["slug"])), None)

        combo_variants = None
        if db_prod and db_prod.variants:
            if isinstance(db_prod.variants, dict):
                combo_variants = db_prod.variants
            elif isinstance(db_prod.variants, str):
                try:
                    import json
                    parsed = json.loads(db_prod.variants)
                    if isinstance(parsed, dict):
                        combo_variants = parsed
                except Exception:
                    pass

        if combo_variants and combo_variants.get("isCombo") and combo_variants.get("bundleItems"):
            has_combos = True
            item_qty = int(item.get("quantity") or 1)
            for b_item in combo_variants["bundleItems"]:
                b_qty = item_qty * int(b_item.get("quantity") or 1)
                b_vname = b_item.get("selectedVariant") or b_item.get("variantName")
                b_comp_id = f"{b_item['productId']}_{b_vname}" if b_vname else b_item["productId"]
                expanded_items.append({
                    "product": {
                        "id": b_comp_id,
                        "name": b_item.get("name") or "FastMinute Item",
                        "price": float(b_item.get("price") or 0),
                        "slug": b_item.get("slug"),
                        "imageUrl": b_item.get("imageUrl"),
                        "restaurantId": b_item.get("restaurantId"),
                    },
                    "quantity": b_qty,
                    "selectedVariant": b_vname,
                    "notes": f"Combo: {prod_payload.get('name') or 'Meal'}",
                })
                if b_item["productId"] not in db_product_ids:
                    missing_bundle_pids.append(b_item["productId"])
        else:
            expanded_items.append(item)

    if has_combos:
        items = expanded_items
        if missing_bundle_pids:
            extra_stmt = select(Product).options(selectinload(Product.category)).where(Product.id.in_(missing_bundle_pids)).with_for_update()
            extra_res = await db.execute(extra_stmt)
            extra_prods = extra_res.scalars().all()
            db_products.extend(extra_prods)
            db_product_ids = {p.id for p in db_products}

    # Query localized store inventory (e.g. Ghatampur hub-209206)
    effective_store_id = store_id or "hub-209206"
    store_inv_map = {}
    if effective_store_id and effective_store_id != "all":
        from models import StoreInventory
        store_inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == effective_store_id,
            StoreInventory.productId.in_(list(db_product_ids))
        ).with_for_update()
        store_inv_res = await db.execute(store_inv_stmt)
        store_inv_map = {inv.productId: inv for inv in store_inv_res.scalars().all()}

    grocery_items = []
    restaurant_groups = {}

    # Aggregate quantities for duplicate lines by (productId, variantName)
    aggregated_quantities = {}
    for item in items:
        prod_payload = item["product"]
        raw_id = str(prod_payload.get("id") or item.get("productId") or "")
        if raw_id in db_product_ids:
            p_id = raw_id
            v_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
        elif "_" in raw_id:
            parts = raw_id.split("_")
            p_id = parts[0]
            v_name = parts[1] if len(parts) > 1 and parts[1] != "addons" else None
        else:
            p_id = raw_id
            v_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
        key = (p_id, v_name)
        aggregated_quantities[key] = aggregated_quantities.get(key, 0) + int(item.get("quantity", 1))

    for item in items:
        prod_payload = item["product"]
        raw_id = str(prod_payload.get("id") or item.get("productId") or "")
        if raw_id in db_product_ids:
            product_id = raw_id
            variant_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
            is_variant = bool(variant_name)
        elif "_" in raw_id:
            parts = raw_id.split("_")
            product_id = parts[0]
            variant_name = parts[1] if len(parts) > 1 and parts[1] != "addons" else None
            is_variant = True
        else:
            product_id = raw_id
            variant_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
            is_variant = bool(variant_name)

        if not variant_name and item.get("selectedVariant"):
            variant_name = item.get("selectedVariant")
            is_variant = True

        db_prod = next((p for p in db_products if p.id == product_id), None)
        if not db_prod and prod_payload.get("slug"):
            db_prod = next((p for p in db_products if p.slug == prod_payload["slug"]), None)
        if not db_prod:
            item_name = prod_payload.get("name") or item.get("name") or ""
            clean_name = re.sub(r'\s*\([^)]*\)\s*$', '', str(item_name)).strip().lower()
            if clean_name:
                db_prod = next((p for p in db_products if p.name.strip().lower() == clean_name), None)
                if not db_prod:
                    db_prod = next((p for p in db_products if clean_name in p.name.strip().lower()), None)
            if db_prod:
                product_id = db_prod.id

        if not variant_name and "(" in str(prod_payload.get("name", "")):
            v_match = re.search(r'\(([^)]+)\)', str(prod_payload.get("name", "")))
            if v_match:
                variant_name = v_match.group(1).strip()
                is_variant = True

        if not db_prod or not db_prod.isAvailable:
            raise HTTPException(status_code=400, detail=f"Product \"{prod_payload.get('name')}\" is no longer available")

        local_inv = store_inv_map.get(db_prod.id)

        # Stock check: Check variant stock if variant item, else check localized store inventory (or fallback db_prod.stock)
        if is_variant and db_prod.variants:
            variant = next((v for v in db_prod.variants if v.get("name") == variant_name), None)
            if variant:
                db_stock = variant.get("stock", 0)
            else:
                db_stock = local_inv.stock if local_inv else db_prod.stock
        else:
            db_stock = local_inv.stock if local_inv else db_prod.stock

        # Authoritative database-only restaurant derivation (client cannot convert grocery into restaurant)
        resolved_rest_id = db_prod.restaurantId
        is_restaurant = bool(resolved_rest_id)
        if is_restaurant:
            if db_prod.stock is not None and db_prod.stock <= 0:
                db_stock = 0
            else:
                db_stock = 999999

        total_requested_qty = aggregated_quantities.get((product_id, variant_name), int(item["quantity"]))
        if not is_restaurant and db_stock < total_requested_qty:
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient stock for product \"{db_prod.name}{name_suffix}\". Available: {db_stock}, requested: {total_requested_qty}"
            )

        # Limits check
        limit = get_product_limit(db_prod)
        if total_requested_qty > limit:
            name_suffix = f" ({variant_name})" if variant_name else ""
            raise HTTPException(
                status_code=400,
                detail=f"Maximum order limit of {limit} units exceeded for product \"{db_prod.name}{name_suffix}\""
            )

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
                owner_phone = owner.phone if owner else (restaurant.ownerPhone or "+91 9450358388")

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
    
    calc_span = TracerService.start_span(
        "fastapi_order_calculation_engine",
        trace_id=trace_id,
        attributes={"user_id": user_id, "item_count": len(items), "delivery_method": delivery_method}
    )

    # Check overall subtotal
    combined_subtotal = 0.0
    for item in items:
        prod_payload = item["product"]
        raw_pid = str(prod_payload.get("id") or item.get("productId") or "")
        if raw_pid in db_product_ids:
            product_id = raw_pid
            variant_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
            is_variant = bool(variant_name)
        elif "_" in raw_pid:
            parts = raw_pid.split("_")
            product_id = parts[0]
            variant_name = parts[1] if len(parts) > 1 and parts[1] != "addons" else None
            is_variant = True
        else:
            product_id = raw_pid
            variant_name = item.get("selectedVariant") or prod_payload.get("selectedVariant")
            is_variant = bool(variant_name)

        db_prod = next((p for p in db_products if p.id == product_id), None)
        if not db_prod and prod_payload.get("slug"):
            db_prod = next((p for p in db_products if p.slug == prod_payload["slug"]), None)

        item_price = db_prod.price if db_prod else 0.0
        if db_prod and is_variant and db_prod.variants:
            variant = next((v for v in db_prod.variants if v.get("name") == variant_name), None)
            if variant:
                item_price = float(variant.get("price", item_price))

        # Include verified food addons in subtotal (looked up strictly from DB)
        selected_addons_sub = item.get("selectedAddons") or item.get("product", {}).get("selectedAddons") or []
        addon_total_sub, _ = calculate_item_addons(db_prod, selected_addons_sub)
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

                    rest_items = []
                    if coupon.restaurantId:
                        rest_items = [
                            i for i in items
                            if next((p.restaurantId for p in db_products if p.id == (i.get("product") or {}).get("id", "").split("_")[0]), None) == coupon.restaurantId
                        ]

                    if coupon.bogoDishId:
                        target_dish = coupon.bogoDishId.strip()
                        pool = rest_items if coupon.restaurantId else items
                        id_items = [i for i in pool if (i.get("product") or {}).get("id", "").split("_")[0].strip() == target_dish]
                        id_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in id_items)
                        if id_subtotal == 0 or id_subtotal < coupon.minOrder:
                            meets_min_order = False
                        eligible_subtotal = id_subtotal

                    elif coupon.menuSection and coupon.menuSection.strip():
                        pool = rest_items if coupon.restaurantId else items
                        sec_filters = [s.strip().lower() for s in coupon.menuSection.split(",") if s.strip()]
                        known_sections = [
                            'burger', 'sandwich', 'pasta', 'maggie', 'maggi', 'calzone',
                            'garlic', 'beverage', 'drink', 'dessert', 'icecream', 'biryani',
                            'pizza', 'shake', 'momos', 'fries', 'chaat', 'rolls', 'bread',
                            'appetizer', 'main course', 'starter', 'combos', 'combo'
                        ]
                        sec_items = []
                        for it in pool:
                            base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                            prod_dict = it.get("product") if isinstance(it.get("product"), dict) else {}
                            m_sec = str(prod_dict.get("menuSection") or getattr(base_p, "menuSection", "") or "").lower()
                            m_sec_id = str(prod_dict.get("menuSectionId") or prod_dict.get("sectionId") or getattr(base_p, "menuSectionId", "") or "").lower()
                            tags = [str(t).lower() for t in (base_p.tags if base_p and base_p.tags else [])]
                            name = str(base_p.name if base_p else prod_dict.get("name") or "").lower()
                            slug = str(getattr(base_p, "slug", "") or "").lower()

                            matches = False
                            for f in sec_filters:
                                clean_f = f.replace("-", "").replace("_", "")
                                if (m_sec_id and (f == m_sec_id or clean_f in m_sec_id.replace("-", "").replace("_", "") or m_sec_id.replace("-", "").replace("_", "") in clean_f)):
                                    matches = True
                                    break
                                if any(f == t or clean_f in t.replace("-", "").replace("_", "") or t.replace("-", "").replace("_", "") in clean_f for t in tags):
                                    matches = True
                                    break
                                if f in m_sec or f in slug:
                                    matches = True
                                    break
                                other_sections = [s for s in known_sections if f not in s and s not in f]
                                has_conflict = any(any(s in t for t in tags) for s in other_sections) or any(s in m_sec for s in other_sections)
                                if not has_conflict and f in name:
                                    matches = True
                                    break
                            if matches:
                                sec_items.append(it)

                        sec_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in sec_items)
                        if sec_subtotal == 0 or sec_subtotal < coupon.minOrder:
                            meets_min_order = False
                        eligible_subtotal = sec_subtotal

                    elif coupon.categoryId:
                        cat_items = [i for i in items if next((p.categoryId for p in db_products if p.id == (i.get("product") or {}).get("id", "").split("_")[0]), None) == coupon.categoryId]
                        cat_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in cat_items)
                        if cat_subtotal == 0 or cat_subtotal < coupon.minOrder:
                            meets_min_order = False
                        eligible_subtotal = cat_subtotal
                    
                    elif coupon.restaurantId:
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
                                target_dish = coupon.bogoDishId.strip()
                                bogo_items = [
                                    it for it in bogo_items
                                    if (it.get("product") or {}).get("id", "").split("_")[0].strip() == target_dish
                                ]
                            elif coupon.menuSection:
                                sec_filters = [s.strip().lower() for s in coupon.menuSection.split(",") if s.strip()]
                                if sec_filters:
                                    known_sections = ['burger', 'sandwich', 'pasta', 'maggie', 'maggi', 'calzone', 'garlic', 'beverage', 'drink', 'dessert', 'icecream', 'biryani', 'pizza', 'shake']
                                    filtered_bogo = []
                                    for it in bogo_items:
                                        base_p = next((p for p in db_products if p.id == it["product"]["id"].split("_")[0]), None)
                                        prod_dict = it.get("product") if isinstance(it.get("product"), dict) else {}
                                        m_sec = str(prod_dict.get("menuSection") or getattr(base_p, "menuSection", "") or "").lower()
                                        m_sec_id = str(prod_dict.get("menuSectionId") or prod_dict.get("sectionId") or getattr(base_p, "menuSectionId", "") or "").lower()
                                        tags = [str(t).lower() for t in (base_p.tags if base_p and base_p.tags else [])]
                                        name = str(base_p.name if base_p else prod_dict.get("name") or "").lower()
                                        slug = str(getattr(base_p, "slug", "") or "").lower()
                                        matches = False
                                        for f in sec_filters:
                                            clean_f = f.replace("-", "").replace("_", "")
                                            if (m_sec_id and (f == m_sec_id or clean_f in m_sec_id.replace("-", "").replace("_", "") or m_sec_id.replace("-", "").replace("_", "") in clean_f)):
                                                matches = True
                                                break
                                            if any(f == t or clean_f in t.replace("-", "").replace("_", "") or t.replace("-", "").replace("_", "") in clean_f for t in tags):
                                                matches = True
                                                break
                                            if f in m_sec or f in slug:
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

                            SIZE_ALIASES = {
                                'large': {'large', 'full', 'big', 'jumbo'},
                                'full': {'large', 'full', 'big', 'jumbo'},
                                'big': {'large', 'full', 'big', 'jumbo'},
                                'jumbo': {'large', 'full', 'big', 'jumbo'},
                                'medium': {'medium', 'regular', 'med', 'mid'},
                                'regular': {'medium', 'regular', 'med', 'mid'},
                                'med': {'medium', 'regular', 'med', 'mid'},
                                'mid': {'medium', 'regular', 'med', 'mid'},
                                'small': {'small', 'half', 'mini'},
                                'half': {'small', 'half', 'mini'},
                                'mini': {'small', 'half', 'mini'},
                            }

                            def get_variant_tokens(var_str):
                                if not var_str:
                                    return set()
                                s = str(var_str).lower().strip()
                                match = re.search(r'\b(medium|large|small|regular|half|full|mini|jumbo)\b', s, re.I)
                                if match:
                                    sz = match.group(1).lower()
                                    aliases = set(SIZE_ALIASES.get(sz, {sz}))
                                    aliases.add(s)
                                    return aliases
                                return {s}

                            def item_matches_variant(text, var_str):
                                if not var_str:
                                    return True
                                tokens = get_variant_tokens(var_str)
                                text_lower = str(text or "").lower()
                                return any(tok in text_lower for tok in tokens)

                            def parse_trigger_variant(raw):
                                raw_str = str(raw or "").strip()
                                size_match = re.search(r'\b(medium|large|small|regular|half|full|mini|jumbo)\b', raw_str, re.I)
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
                                trigger_var = coupon.triggerVariant or "large"
                                reward_var = coupon.rewardVariant or "small"

                                trigger_items = [it for it in bogo_items if item_matches_variant(get_item_vtext(it), trigger_var)]
                                total_trig_qty = sum(int(it.get("quantity", 1)) for it in trigger_items)

                                reward_pool = bogo_items if coupon.bogoDishId else (bogo_items if coupon.menuSection else (rest_items if coupon.restaurantId else items))
                                if coupon.defaultFreeDishId:
                                    reward_items = [
                                        it for it in (rest_items if coupon.restaurantId else items)
                                        if it["product"]["id"].split("_")[0] == coupon.defaultFreeDishId
                                    ]
                                else:
                                    reward_items = [it for it in reward_pool if item_matches_variant(get_item_vtext(it), reward_var)]

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
                                qualifying_items = [it for it in bogo_items if item_matches_variant(get_item_vtext(it), trigger_size)] if trigger_size else bogo_items
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
                                            if reward_tag in name or any(reward_tag in t for t in tags) or reward_tag in m_sec or reward_tag in v_text or item_matches_variant(v_text, coupon.rewardVariant):
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
                                    target_dish = coupon.bogoDishId.strip()
                                    eligible = [
                                        it for it in bogo_items
                                        if (it.get("product") or {}).get("id", "").split("_")[0].strip() == target_dish
                                    ]
                                max_free_cap = getattr(coupon, "maxFreeItems", 3) or 3
                                rem_free_cap = max_free_cap
                                for it in eligible:
                                    qty = int(it.get("quantity", 1))
                                    if qty >= 2:
                                        pairs = min(qty // 2, rem_free_cap)
                                        if pairs > 0:
                                            base_p = next((p for p in db_products if p.id == (it.get("product") or {}).get("id", "").split("_")[0]), None)
                                            price = float(it.get("price", base_p.price if base_p else 0.0))
                                            combined_discount += pairs * price
                                            rem_free_cap -= pairs
                                            if rem_free_cap <= 0:
                                                break
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
            raw_id = str(it["product"]["id"])
            if raw_id in db_product_ids:
                p_id = raw_id
                var_name = it.get("selectedVariant") or it["product"].get("selectedVariant")
                is_var = bool(var_name)
            elif "_" in raw_id:
                parts = raw_id.split("_")
                p_id = parts[0]
                var_name = parts[1] if len(parts) > 1 and parts[1] != "addons" else None
                is_var = True
            else:
                p_id = raw_id
                var_name = it.get("selectedVariant") or it["product"].get("selectedVariant")
                is_var = bool(var_name)
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
    final_shop_name = restaurant_obj["name"] if restaurant_obj else "FastMinute Grocery"
    final_shop_phone = restaurant_obj.get("ownerPhone", default_support_phone) if restaurant_obj else default_support_phone

    has_grocery_items = len(grocery_items) > 0
    has_restaurant_items = len(restaurant_data) > 0
    is_combined = has_grocery_items and has_restaurant_items

    # Packaging and handling charge (customizable by admin)
    server_misc_fee = float(settings_map.get("misc_fee", 5.0))
    server_combined_misc_fee = float(settings_map.get("combined_misc_fee", server_misc_fee))
    packaging_fee_input = float(payload.get("packagingFee", payload.get("packaging_fee", 0.0)))
    is_premium_packaging = packaging_option == "PREMIUM"
    applicable_misc_fee = server_combined_misc_fee if is_combined else server_misc_fee
    resolved_packaging_fee = 15.0 if is_premium_packaging else (packaging_fee_input if packaging_fee_input > 0 else (applicable_misc_fee if (restaurant_id or is_combined) else 5.0))

    # Support driver tip add-on accurately across backend calculations (strictly reject negative or non-finite tip)
    raw_tip = payload.get("tip") if payload.get("tip") is not None else payload.get("tipAmount")
    tip_amount = 0.0
    if raw_tip is not None and str(raw_tip).strip() != "":
        try:
            parsed_tip = float(raw_tip)
            if not math.isfinite(parsed_tip) or parsed_tip < 0:
                raise HTTPException(status_code=400, detail="Invalid tip amount: tip must be a non-negative finite number")
            tip_amount = round(parsed_tip, 2)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Invalid tip amount: tip must be a valid number")

    # Calculate unified order amounts
    subtotal = combined_subtotal
    discount = combined_discount
    delivery_fee_val = float(settings_map.get("delivery_fee", 25.0))
    delivery_fee_charge = 0.0

    if delivery_method == "DELIVERY" and not is_b2b:
        default_threshold = float(settings_map.get("delivery_threshold_tier1", settings_map.get("grocery_free_delivery_threshold", 149.0)))
        free_delivery_threshold = delivery_rules["freeDeliveryThreshold"] if delivery_rules else default_threshold
        if subtotal < free_delivery_threshold:
            delivery_fee_charge = delivery_rules["deliveryFee"] if delivery_rules else delivery_fee_val

    misc_fee_charge = (resolved_packaging_fee if delivery_method != "PICKUP" else 0.0) + tip_amount
    final_total = max(0.0, round(subtotal - discount + delivery_fee_charge + misc_fee_charge, 2))

    # 6. Create Orders (ID-wise splitting for Combined Orders)
    created_orders = []
    try:
        try:
            seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
            readable_id = str(seq_res.scalar())
        except Exception:
            readable_id = f"FK-{int(time.time() * 1000) % 1000000:06d}"

        combined_id = f"combined_{uuid.uuid4().hex[:9]}_{int(datetime.utcnow().timestamp())}" if is_combined else None

        est_mins = 30 if has_restaurant_items else 10
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

        is_online_paid = False
        incoming_payment_status = str(payload.get("paymentStatus") or "").upper()
        incoming_payment_id = str(payload.get("paymentId") or payload.get("cfPaymentId") or "").strip()
        incoming_cf_order_id = str(payload.get("cfOrderId") or "").strip()
        if payment_method == "WALLET":
            incoming_cf_order_id = ""
        elif not incoming_cf_order_id:
            if incoming_payment_id.startswith("CF_"):
                incoming_cf_order_id = incoming_payment_id.replace("CF_", "")
            elif incoming_payment_id.startswith("cf_"):
                incoming_cf_order_id = incoming_payment_id

        canonical_cf_order_id = None
        if incoming_cf_order_id:
            # Reject malformed references containing special characters
            if re.search(r"[^a-zA-Z0-9_-]", incoming_cf_order_id):
                raise HTTPException(
                    status_code=400,
                    detail="Invalid payment reference format: payment ID must contain only alphanumeric characters, underscores, and hyphens."
                )
            canonical_cf_order_id = re.sub(r"[^a-zA-Z0-9_-]", "_", incoming_cf_order_id)[:45]
            incoming_cf_order_id = canonical_cf_order_id

        # 🛡️ [DATABASE IDEMPOTENCY CHECK] Prevent duplicate order creation if Cashfree order was already placed
        base_cf_order_id = re.sub(r"_r\d+$", "", incoming_cf_order_id.strip()) if incoming_cf_order_id else None
        if incoming_cf_order_id:
            try:
                exist_res = await db.execute(
                    select(Order).where(
                        or_(
                            Order.id == incoming_cf_order_id,
                            Order.id == base_cf_order_id,
                            Order.readableId == incoming_cf_order_id,
                            Order.readableId == base_cf_order_id,
                            Order.cfOrderId == incoming_cf_order_id,
                            Order.cfOrderId == base_cf_order_id,
                        )
                    ).options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user)).order_by(Order.createdAt.asc())
                )
                existing_matched = exist_res.scalars().all()
                if existing_matched:
                    first_match = existing_matched[0]
                    if first_match.userId != user_id:
                        logger.error(f"[Payment Security] Order #{first_match.readableId} belongs to user '{first_match.userId}', but caller is '{user_id}'. Replay rejected.")
                        raise HTTPException(status_code=403, detail="Payment reference belongs to another user's order.")
                    all_matches = list(existing_matched)
                    if first_match.combinedId:
                        comb_res = await db.execute(
                            select(Order).where(Order.combinedId == first_match.combinedId)
                            .options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user))
                            .order_by(Order.createdAt.asc())
                        )
                        all_matches = comb_res.scalars().all()
                    main_match = next((o for o in all_matches if not o.restaurantId), all_matches[0])
                    logger.info(f"🛡️ [IDEMPOTENCY] FastAPI returning existing order #{main_match.readableId} for CF ID {incoming_cf_order_id}")
                    replayed_payload = _build_replayed_order_payload(main_match, all_matches)
                    if idempotency_key:
                        await save_idempotency_response_async(idempotency_key, replayed_payload, db=db)
                    return replayed_payload
            except HTTPException:
                raise
            except Exception as idemp_err:
                logger.warning(f"FastAPI idempotency check error: {idemp_err}")

        wallet_used_amount = float(
            payload.get("walletAmountUsed")
            or payload.get("wallet_amount_used")
            or payload.get("walletDeduction")
            or 0.0
        )
        if wallet_used_amount <= 0.0 and incoming_cf_order_id:
            try:
                from utils.cache import get_cache
                p_clean = re.sub(r"_r\d+$", "", incoming_cf_order_id)
                p_intent_obj = await get_cache(f"cf_pending:{incoming_cf_order_id}") or await get_cache(f"cf_pending:{p_clean}")
                if not p_intent_obj:
                    from models import IdempotencyRecord
                    i_res = await db.execute(
                        select(IdempotencyRecord).where(
                            IdempotencyRecord.key.in_([f"cf_intent:{incoming_cf_order_id}", f"cf_intent:{p_clean}"])
                        )
                    )
                    i_rec = i_res.scalars().first()
                    if i_rec and isinstance(i_rec.response, dict):
                        p_intent_obj = i_rec.response
                if p_intent_obj and isinstance(p_intent_obj, dict):
                    wallet_used_amount = float(
                        (p_intent_obj.get("validated_quote") or p_intent_obj.get("validatedQuote") or {}).get("walletAmountUsed")
                        or (p_intent_obj.get("validated_quote") or p_intent_obj.get("validatedQuote") or {}).get("wallet_amount_used")
                        or p_intent_obj.get("walletAmountUsed")
                        or p_intent_obj.get("wallet_amount_used")
                        or 0.0
                    )
            except Exception:
                pass
        min_wallet_mov = float(settings_map.get("referral_wallet_redeem_min_order_value", "99"))
        allow_promo_wallet = subtotal >= min_wallet_mov

        if payment_method == "WALLET" or wallet_used_amount > 0:
            from routers.wallet import get_or_create_wallet
            cust_wallet = await get_or_create_wallet(user_id, db)
            real_cash = float(cust_wallet.balance or 0.0)
            target_wallet_debit = final_total if payment_method == "WALLET" else min(wallet_used_amount, final_total)

            # Real cash deposited via Cashfree or refunds has ZERO minimum order value!
            # Only promo/referral bonus balance requires subtotal >= min_wallet_mov.
            if not allow_promo_wallet and target_wallet_debit > (real_cash + 0.01):
                raise HTTPException(
                    status_code=400,
                    detail=f"Minimum order of ₹{int(min_wallet_mov)} is required to use referral/promotional bonus. Available real cash: ₹{real_cash:.2f}"
                )

        expected_online_total = max(0.0, round(final_total - wallet_used_amount, 2))

        if payment_method not in ["COD", "WALLET"]:
            if incoming_cf_order_id:
                # 0. Check pending session intent binding to verify initiating user
                try:
                    from utils.cache import get_cache
                    p_clean = re.sub(r"_r\d+$", "", incoming_cf_order_id)
                    p_intent = await get_cache(f"cf_pending:{incoming_cf_order_id}") or await get_cache(f"cf_pending:{p_clean}")
                    if p_intent and isinstance(p_intent, dict):
                        intent_uid = str(p_intent.get("userId") or "")
                        if intent_uid and intent_uid != user_id and not intent_uid.startswith("guest_"):
                            logger.error(f"[Payment Security] cfOrderId '{incoming_cf_order_id}' was initiated by user '{intent_uid}', but caller is '{user_id}'. Rejecting.")
                            raise HTTPException(status_code=403, detail="Payment intent was initiated by a different user.")
                except HTTPException:
                    raise
                except Exception as intent_e:
                    logger.warning(f"Pending intent check notice: {intent_e}")

                # 1. Check Redis cache first (in case webhook fired before client checkout completed)
                try:
                    from utils.cache import get_cache
                    cached_val = await get_cache(f"cf_paid:{incoming_cf_order_id}")
                    if not cached_val and "_r" in incoming_cf_order_id:
                        clean_check = re.sub(r"_r\d+$", "", incoming_cf_order_id)
                        # Verify intent binding before authorizing retry suffix from base payment cache
                        intent_cf = (p_intent.get("cfOrderId") or p_intent.get("orderId")) if p_intent and isinstance(p_intent, dict) else None
                        if intent_cf and (intent_cf == incoming_cf_order_id or intent_cf == clean_check or re.sub(r"_r\d+$", "", str(intent_cf)) == clean_check):
                            cached_val = await get_cache(f"cf_paid:{clean_check}")
                    if cached_val:
                        cached_amount = None
                        if isinstance(cached_val, dict):
                            cached_amount = cached_val.get("amount")
                        if cached_amount is not None and (abs(float(cached_amount) - float(expected_online_total)) <= 0.05 or abs(float(cached_amount) - float(final_total)) <= 0.05):
                            is_online_paid = True
                        else:
                            logger.warning(f"[Payment Security] Cached Cashfree amount {cached_amount} invalid or != final_total {final_total} / expected {expected_online_total}")
                except Exception:
                    pass

                # 2. Query Cashfree server if not yet marked paid
                if not is_online_paid:
                    try:
                        from routers.cashfree_router import CASHFREE_BASE_URL, _get_cashfree_headers
                        headers = _get_cashfree_headers()
                        sanitized_check_id = re.sub(r"[^a-zA-Z0-9_-]", "_", incoming_cf_order_id)[:45]
                        async with httpx.AsyncClient(timeout=10.0) as client:
                            cf_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}", headers=headers)
                            if cf_res.status_code == 200:
                                cf_data = cf_res.json()
                                if cf_data.get("order_status") == "PAID":
                                    cf_amt = cf_data.get("order_amount")
                                    if cf_amt is not None:
                                        try:
                                            if abs(float(cf_amt) - float(expected_online_total)) <= 0.05 or abs(float(cf_amt) - float(final_total)) <= 0.05:
                                                is_online_paid = True
                                            else:
                                                logger.warning(f"[Payment Security] Cashfree order amount ₹{cf_amt} != final_total ₹{final_total} or ₹{expected_online_total}")
                                        except (ValueError, TypeError):
                                            pass
                                    else:
                                        logger.warning(f"[Payment Security] Cashfree order missing order_amount")
                    except Exception as cf_e:
                        logger.warning(f"Error checking Cashfree for new order: {cf_e}")

            # 3. Check Razorpay payment verification
            incoming_rzp_order_id = str(payload.get("razorpay_order_id") or payload.get("razorpayOrderId") or "").strip()
            incoming_rzp_payment_id = str(payload.get("razorpay_payment_id") or payload.get("razorpayPaymentId") or (incoming_payment_id if incoming_payment_id.startswith("pay_") else "")).strip()
            incoming_rzp_signature = str(payload.get("razorpay_signature") or payload.get("razorpaySignature") or "").strip()

            if incoming_rzp_payment_id and not is_online_paid:
                try:
                    from utils.cache import get_cache
                    cached_rzp = await get_cache(f"rzp_paid:{incoming_rzp_payment_id}") or (await get_cache(f"rzp_paid:{incoming_rzp_order_id}") if incoming_rzp_order_id else None)
                    if cached_rzp:
                        is_online_paid = True
                    elif incoming_rzp_order_id and incoming_rzp_signature:
                        from routers.razorpay_router import verify_razorpay_signature
                        if verify_razorpay_signature(incoming_rzp_order_id, incoming_rzp_payment_id, incoming_rzp_signature):
                            is_online_paid = True
                    elif incoming_payment_status == "PAID" or incoming_rzp_payment_id.startswith("pay_"):
                        is_online_paid = True
                except Exception as rzp_e:
                    logger.warning(f"Error checking Razorpay for new order: {rzp_e}")

        from decimal import Decimal
        actual_wallet_debit = Decimal("0.00")
        if payment_method == "WALLET":
            from routers.wallet import debit_customer_wallet
            actual_wallet_debit = Decimal(str(round(final_total, 2)))
            await debit_customer_wallet(
                user_id=user_id,
                amount=actual_wallet_debit,
                description=f"Paid for order #{readable_id} via FastMinute Wallet",
                db=db,
                metadata={"finalTotal": final_total, "readableId": readable_id},
                allow_promo=allow_promo_wallet,
            )
            is_online_paid = True
        elif wallet_used_amount > 0:
            from routers.wallet import debit_customer_wallet
            actual_wallet_debit = Decimal(str(round(min(wallet_used_amount, final_total), 2)))
            # Edge case defense: Insufficient balance or inactive wallet must raise HTTPException and abort order creation
            await debit_customer_wallet(
                user_id=user_id,
                amount=actual_wallet_debit,
                description=f"Wallet deduction for Order #{readable_id}",
                db=db,
                metadata={"walletDeduction": float(actual_wallet_debit), "readableId": readable_id},
                allow_promo=allow_promo_wallet,
            )
            logger.info(f"Deducted ₹{actual_wallet_debit} from wallet for user {user_id}")

        auto_approve_setting = settings_map.get("admin_auto_approve_orders", "true")
        is_auto_approve = auto_approve_setting.lower() == "true"
        # Restaurant orders always require Admin verification first before alerting the kitchen!
        if restaurant_groups:
            initial_order_status = OrderStatus.ADMIN_PENDING
        else:
            initial_order_status = OrderStatus.PENDING if (is_online_paid or is_auto_approve) else OrderStatus.ADMIN_PENDING
        is_admin_pending = (initial_order_status == OrderStatus.ADMIN_PENDING)

        # Construct notes — strip any injected fake gateway markers like [CF_ORDER:...] from customer text
        raw_notes = (payload.get("notes") or "").strip()
        incoming_notes = re.sub(r"\[CF_[A-Z0-9_:]+\]", "", raw_notes, flags=re.IGNORECASE).strip()
        is_order_for_someone = bool(payload.get("isOrderForSomeone"))
        receiver_name = (payload.get("receiverName") or "").strip()
        receiver_phone = (payload.get("receiverPhone") or "").strip()

        notes_parts = []
        if is_order_for_someone and receiver_name:
            order_for_str = f"🎁 Order for: {receiver_name}"
            if receiver_phone:
                order_for_str += f" ({receiver_phone})"
            if incoming_notes and "Order for:" in incoming_notes:
                notes_parts.append(incoming_notes)
            else:
                notes_parts.append(order_for_str)
                if incoming_notes:
                    notes_parts.append(incoming_notes)
        elif incoming_notes:
            notes_parts.append(incoming_notes)

        if incoming_cf_order_id and not any(incoming_cf_order_id in p for p in notes_parts):
            notes_parts.append(f"[CF_ORDER:{incoming_cf_order_id}]")

        if is_premium_packaging and not any("Premium Thermal Packaging" in p for p in notes_parts):
            notes_parts.append("✨ Premium Thermal Packaging Requested (+₹15)")

        base_notes_parts = list(notes_parts)

        if not is_combined:
            if actual_wallet_debit > Decimal("0.00") and payment_method != "WALLET":
                notes_parts.append(f"💳 Wallet Used: ₹{float(actual_wallet_debit):.2f}")
                notes_parts.append(f"[WALLET_USED:{float(actual_wallet_debit):.2f}]")
            elif payment_method == "WALLET":
                notes_parts.append(f"💳 Paid via Wallet: ₹{float(actual_wallet_debit):.2f}")
                notes_parts.append(f"[WALLET_USED:{float(actual_wallet_debit):.2f}]")

        if is_online_paid:
            is_rzp = (
                (incoming_payment_id and incoming_payment_id.startswith("pay_")) or
                bool(payload.get("razorpay_payment_id")) or
                bool(payload.get("razorpayPaymentId"))
            )
            if is_rzp:
                rzp_ref = incoming_payment_id if (incoming_payment_id and incoming_payment_id.startswith("pay_")) else (str(payload.get("razorpay_payment_id") or payload.get("razorpayPaymentId") or ""))
                notes_parts.append(f"Razorpay PG Paid (Ref: {rzp_ref})")
            elif not any("Cashfree PG Paid" in p for p in notes_parts):
                cf_note_ref = f"Cashfree PG Paid (Ref: {incoming_payment_id})" if incoming_payment_id else "Cashfree PG Paid"
                notes_parts.append(cf_note_ref)

        if tip_amount > 0 and not any("Delivery Partner Tip" in p for p in notes_parts):
            notes_parts.append(f"💰 Delivery Partner Tip: ₹{tip_amount:.2f}")

        final_order_notes = " | ".join(notes_parts) if notes_parts else None

        # Calculate discount apportionment
        grocery_disc = 0.0
        restaurant_disc = 0.0
        if combined_discount > 0 and combined_subtotal > 0:
            if is_combined:
                ratio = grocery_subtotal / combined_subtotal
                grocery_disc = round(combined_discount * ratio, 2)
                restaurant_disc = round(combined_discount - grocery_disc, 2)
            elif has_grocery_items:
                grocery_disc = combined_discount
            else:
                restaurant_disc = combined_discount

        # Plan sub-order specifications
        order_specs = []
        wallet_debit_val = float(actual_wallet_debit)
        if is_combined:
            # 1. Grocery Companion Order (takes the combined packaging fee configured by admin + tip)
            grocery_misc = misc_fee_charge
            g_gross = max(0.0, round(grocery_subtotal - grocery_disc + delivery_fee_charge + grocery_misc, 2))
            g_wallet_deduct = min(g_gross, wallet_debit_val)
            g_net = max(0.0, round(g_gross - g_wallet_deduct, 2))
            rem_wallet_debit = round(wallet_debit_val - g_wallet_deduct, 2)

            g_notes_parts = list(base_notes_parts)
            if g_wallet_deduct > 0:
                g_notes_parts.append(f"💳 Wallet Used: ₹{g_wallet_deduct:.2f}")
                g_notes_parts.append(f"[WALLET_USED:{g_wallet_deduct:.2f}]")
            g_notes = " | ".join(g_notes_parts) if g_notes_parts else None

            order_specs.append({
                "type": OrderType.GROCERY,
                "readableId": f"{readable_id}-G",
                "restaurantId": None,
                "shopName": "FastMinute Grocery",
                "shopPhone": default_support_phone,
                "subtotal": round(grocery_subtotal, 2),
                "discount": round(grocery_disc, 2),
                "deliveryFee": round(delivery_fee_charge, 2),
                "miscFee": round(grocery_misc, 2),
                "total": g_net,
                "items": grocery_items,
                "notes": g_notes
            })
            # 2. Restaurant Companion Order (miscFee 0.0 so combined packaging charge is strictly charged once)
            r_gross = max(0.0, round(restaurant_data[0]["subtotal"] - restaurant_disc, 2))
            r_net = max(0.0, round(r_gross - rem_wallet_debit, 2))

            r_notes_parts = list(base_notes_parts)
            if rem_wallet_debit > 0:
                r_notes_parts.append(f"💳 Wallet Used: ₹{rem_wallet_debit:.2f}")
                r_notes_parts.append(f"[WALLET_USED:{rem_wallet_debit:.2f}]")
            r_notes = " | ".join(r_notes_parts) if r_notes_parts else None

            order_specs.append({
                "type": OrderType.RESTAURANT,
                "readableId": f"{readable_id}-R",
                "restaurantId": restaurant_id,
                "shopName": final_shop_name,
                "shopPhone": final_shop_phone,
                "subtotal": round(restaurant_data[0]["subtotal"], 2),
                "discount": round(restaurant_disc, 2),
                "deliveryFee": 0.0,
                "miscFee": 0.0,
                "total": r_net,
                "items": restaurant_data[0]["items"],
                "notes": r_notes
            })
        elif has_restaurant_items:
            r_gross = max(0.0, round(combined_subtotal - combined_discount + delivery_fee_charge + misc_fee_charge, 2))
            order_specs.append({
                "type": OrderType.RESTAURANT,
                "readableId": f"{readable_id}-R",
                "restaurantId": restaurant_id,
                "shopName": final_shop_name,
                "shopPhone": final_shop_phone,
                "subtotal": round(combined_subtotal, 2),
                "discount": round(combined_discount, 2),
                "deliveryFee": round(delivery_fee_charge, 2),
                "miscFee": round(misc_fee_charge, 2),
                "total": max(0.0, round(r_gross - wallet_debit_val, 2)),
                "items": restaurant_data[0]["items"],
                "notes": final_order_notes
            })
        else:
            grocery_misc = misc_fee_charge
            g_gross = max(0.0, round(combined_subtotal - combined_discount + delivery_fee_charge + grocery_misc, 2))
            order_specs.append({
                "type": OrderType.GROCERY,
                "readableId": f"{readable_id}-G",
                "restaurantId": None,
                "shopName": "FastMinute Grocery",
                "shopPhone": default_support_phone,
                "subtotal": round(combined_subtotal, 2),
                "discount": round(combined_discount, 2),
                "deliveryFee": round(delivery_fee_charge, 2),
                "miscFee": round(grocery_misc, 2),
                "total": max(0.0, round(g_gross - wallet_debit_val, 2)),
                "items": grocery_items,
                "notes": final_order_notes
            })

        clean_cf_order_id = incoming_cf_order_id.strip() if incoming_cf_order_id else None
        base_cf_order_id = re.sub(r"_r\d+$", "", clean_cf_order_id) if clean_cf_order_id else None
        cons_rec = None
        if clean_cf_order_id:
            from models import IdempotencyRecord
            consumed_key = f"consumed_payment:{base_cf_order_id}"
            try:
                cons_rec = IdempotencyRecord(
                    key=consumed_key,
                    userId=user_id,
                    status="PROCESSING",
                    createdAt=datetime.utcnow(),
                    expiresAt=datetime.utcnow() + timedelta(days=7)
                )
                db.add(cons_rec)
                await db.flush()
            except Exception:
                await db.rollback()
                exist_res = await db.execute(
                    select(Order).where(
                        or_(
                            Order.id == clean_cf_order_id,
                            Order.id == base_cf_order_id,
                            Order.readableId == clean_cf_order_id,
                            Order.readableId == base_cf_order_id,
                            Order.cfOrderId == clean_cf_order_id,
                            Order.cfOrderId == base_cf_order_id,
                        )
                    ).options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user)).order_by(Order.createdAt.asc())
                )
                existing_matched = exist_res.scalars().all()
                if existing_matched:
                    first_match = existing_matched[0]
                    if first_match.userId != user_id:
                        raise HTTPException(status_code=403, detail="Payment reference belongs to another user's order.")
                    all_matches = list(existing_matched)
                    if first_match.combinedId:
                        comb_res = await db.execute(
                            select(Order).where(Order.combinedId == first_match.combinedId)
                            .options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user))
                            .order_by(Order.createdAt.asc())
                        )
                        all_matches = comb_res.scalars().all()
                    main_match = next((o for o in all_matches if not o.restaurantId), all_matches[0])
                    replayed_payload = _build_replayed_order_payload(main_match, all_matches)
                    if idempotency_key:
                        await save_idempotency_response_async(idempotency_key, replayed_payload, db=db)
                    return replayed_payload
                else:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="Payment is currently being processed or already claimed by another request."
                    )

        reserved_redis_items = []
        for spec in order_specs:
            ord_obj = Order(
                id=generate_id("ord_"),
                readableId=spec["readableId"],
                userId=user_id,
                addressId=order_address_id,
                combinedId=combined_id,
                cfOrderId=base_cf_order_id,
                orderType=spec["type"],
                status=initial_order_status,
                subtotal=spec["subtotal"],
                discount=spec["discount"],
                deliveryFee=spec["deliveryFee"],
                taxes=0.0,
                miscFee=spec["miscFee"],
                total=spec["total"],
                paymentMethod=PaymentMethod(payment_method),
                paymentStatus=PaymentStatus.PAID if is_online_paid else PaymentStatus.PENDING,
                estimatedDelivery=estimated_delivery,
                deliveryMethod=delivery_method,
                isB2B=is_b2b,
                storeId=store_id,
                couponCode=coupon_code.strip().upper() if coupon_code else None,
                shopName=spec["shopName"],
                shopPhone=spec["shopPhone"],
                restaurantId=spec["restaurantId"],
                notes=spec.get("notes") or final_order_notes,
                confirmedAt=datetime.utcnow() if initial_order_status == OrderStatus.CONFIRMED else None
            )
            db.add(ord_obj)
            await db.flush()

            for item in spec["items"]:
                prod = item["dbProduct"]
                raw_id = str(item["product"].get("id", ""))
                is_var = "_" in raw_id
                var_name = item.get("selectedVariant") or (raw_id.split("_")[1] if is_var else None)

                cost_price = float(prod.costPrice or 0.0)
                item_price = prod.price
                if prod.variants and isinstance(prod.variants, list):
                    target_var = str(var_name).strip().lower() if var_name else ""
                    variant = None
                    if target_var:
                        variant = next((
                            v for v in prod.variants
                            if isinstance(v, dict) and (
                                str(v.get("name") or v.get("unit") or "").strip().lower() == target_var or
                                str(v.get("name") or v.get("unit") or "").strip().lower().replace(" ", "") == target_var.replace(" ", "")
                            )
                        ), None)
                    if variant:
                        item_price = float(variant.get("price", item_price))
                        cp_val = variant.get("costPrice") or variant.get("cp") or variant.get("cost")
                        if cp_val is not None and float(cp_val) > 0:
                            cost_price = float(cp_val)
                    elif (not cost_price or cost_price <= 0) and len(prod.variants) > 0:
                        for v in prod.variants:
                            if isinstance(v, dict):
                                cp_val = v.get("costPrice") or v.get("cp") or v.get("cost")
                                if cp_val is not None and float(cp_val) > 0:
                                    cost_price = float(cp_val)
                                    break

                # Food Addons Calculation & Storage (verified from DB)
                selected_addons_raw = item.get("selectedAddons") or []
                addon_total, verified_addons = calculate_item_addons(prod, selected_addons_raw)
                final_item_price = item_price + addon_total

                order_item_variants = {
                    "productVariants": prod.variants,
                    "selectedAddons": verified_addons
                } if verified_addons else prod.variants

                order_item = OrderItem(
                    id=generate_id("oi_"),
                    orderId=ord_obj.id,
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
                if not prod.restaurantId and spec["type"] == OrderType.GROCERY:
                    qty = int(item["quantity"])

                    # 1. Fast in-memory pre-deduction via Redis Lua script (Swiggy/Blinkit high-throughput pattern)
                    from utils.cache import atomic_reserve_inventory, release_reserved_inventory, get_redis_connection
                    stock_cache_key = f"stock:{store_id or 'default'}:{prod.id}:{var_name or 'base'}"
                    hub_inv = store_inv_map.get(prod.id) if "store_inv_map" in locals() and store_inv_map else None
                    effective_seed_stock = hub_inv.stock if (hub_inv and hub_inv.stock is not None) else (prod.stock or 0)
                    if var_name and prod.variants and isinstance(prod.variants, list):
                        v_match = next((v for v in prod.variants if isinstance(v, dict) and v.get("name") == var_name), None)
                        if v_match and "stock" in v_match:
                            effective_seed_stock = int(v_match.get("stock") or 0)

                    lua_res = await atomic_reserve_inventory(stock_cache_key, qty, initial_seed_stock=effective_seed_stock)
                    if lua_res == -1:
                        # Auto-heal stale Redis cache if Postgres DB has sufficient verified stock
                        if effective_seed_stock >= qty:
                            try:
                                redis_c = await get_redis_connection()
                                if redis_c:
                                    await redis_c.set(stock_cache_key, effective_seed_stock - qty, ex=86400)
                                lua_res = effective_seed_stock - qty
                            except Exception:
                                lua_res = 0  # Fallback to DB row lock below
                        else:
                            raise HTTPException(
                                status_code=400,
                                detail=f"Insufficient inventory for \"{prod.name}\". Requested {qty} units."
                            )
                    if "reserved_redis_items" in locals() and lua_res >= 0:
                        reserved_redis_items.append((stock_cache_key, qty))

                    try:
                        # 2. Row-lock product in DB to ensure persistent multi-worker synchronization
                        p_lock_stmt = select(Product).where(Product.id == prod.id).with_for_update()
                        p_lock_res = await db.execute(p_lock_stmt)
                        locked_prod = p_lock_res.scalars().first()
                        if not locked_prod:
                            raise HTTPException(status_code=400, detail=f"Product '{prod.name}' not found")

                        prev_stock = locked_prod.stock or 0
                        if store_id and store_inv_map.get(locked_prod.id):
                            hub_inv = store_inv_map.get(locked_prod.id)
                            if hub_inv and (hub_inv.stock or 0) > prev_stock:
                                prev_stock = int(hub_inv.stock or 0)

                        if var_name and locked_prod.variants and isinstance(locked_prod.variants, list):
                            updated_variants = []
                            variant_found = False
                            for v in locked_prod.variants:
                                v_copy = dict(v)
                                if v_copy.get("name") == var_name:
                                    variant_found = True
                                    v_stock = int(v_copy.get("stock", 0))
                                    if v_stock < qty:
                                        raise HTTPException(
                                            status_code=400,
                                            detail=f"Insufficient stock for \"{locked_prod.name} ({var_name})\". Available: {v_stock}, requested: {qty}."
                                        )
                                    v_copy["stock"] = v_stock - qty
                                updated_variants.append(v_copy)
                            if not variant_found and prev_stock < qty:
                                raise HTTPException(
                                    status_code=400,
                                    detail=f"Insufficient stock for \"{locked_prod.name}\". Available: {prev_stock}, requested: {qty}."
                                )
                            locked_prod.variants = updated_variants
                            locked_prod.stock = sum(int(v.get("stock", 0)) for v in updated_variants)
                        else:
                            if prev_stock < qty:
                                raise HTTPException(
                                    status_code=400,
                                    detail=f"Insufficient stock for \"{locked_prod.name}\". Available: {prev_stock}, requested: {qty}."
                                )
                            locked_prod.stock = prev_stock - qty

                        if store_id:
                            try:
                                existing_inv = store_inv_map.get(locked_prod.id)
                                if existing_inv:
                                    if existing_inv.stock < qty:
                                        raise HTTPException(
                                            status_code=400,
                                            detail=f"Insufficient hub stock for \"{locked_prod.name}\". Available: {existing_inv.stock}, requested: {qty}."
                                        )
                                    existing_inv.stock = existing_inv.stock - qty
                            except HTTPException:
                                raise
                            except Exception as inv_err:
                                logger.warning(f"Could not decrement StoreInventory for product {locked_prod.id} at store {store_id}: {inv_err}")

                        log = StockLog(
                            id=generate_id("sl_"),
                            productId=locked_prod.id,
                            quantity=-qty,
                            type="ONLINE_ORDER",
                            prevStock=prev_stock,
                            newStock=locked_prod.stock
                        )
                        db.add(log)
                    except Exception:
                        if lua_res >= 0:
                            await release_reserved_inventory(stock_cache_key, qty)
                            if "reserved_redis_items" in locals() and (stock_cache_key, qty) in reserved_redis_items:
                                reserved_redis_items.remove((stock_cache_key, qty))
                        raise

            if any(not item["dbProduct"].restaurantId and spec["type"] == OrderType.GROCERY for item in spec["items"]):
                ord_obj.notes = f"{ord_obj.notes or ''} [STOCK_DEDUCTED]".strip()

            created_orders.append(ord_obj)

        if "calc_span" in locals():
            calc_span.end(extra_attributes={
                "order_count": len(created_orders),
                "total": float(sum(o.total for o in created_orders)),
                "order_ids": [o.id for o in created_orders]
            })

        # Update coupon usage
        if coupon_id:
            c_stmt = select(Coupon).where(Coupon.id == coupon_id)
            c_res = await db.execute(c_stmt)
            c_obj = c_res.scalars().first()
            if c_obj:
                c_obj.usedCount += 1

        # Cart clearing will be performed post-commit to avoid PostgreSQL deadlocks with concurrent cart syncs

        main_order = next((o for o in created_orders if not o.restaurantId), created_orders[0])

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
            "orderId": main_order.id,
            "readableId": main_order.readableId,
            "traceId": trace_id,
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
            "estimatedDelivery": to_iso_utc(main_order.estimatedDelivery),
            "deliveryMethod": main_order.deliveryMethod,
            "isB2B": main_order.isB2B,
            "shopName": main_order.shopName,
            "shopPhone": main_order.shopPhone,
            "notes": main_order.notes,
            "couponCode": main_order.couponCode,
            "customerName": user_obj.name if user_obj else None,
            "customerPhone": (user_obj.phone if user_obj else None) or (address.phone if address else None),
            "customerAddress": f"{address.houseNo or ''}, {address.street or ''}, {address.area or ''}, {address.city or ''}, {address.pincode or ''}" if address else None,
            "createdAt": to_iso_utc(main_order.createdAt),
            "updatedAt": to_iso_utc(main_order.updatedAt),
            "confirmedAt": to_iso_utc(main_order.confirmedAt),
            "packedAt": to_iso_utc(main_order.packedAt),
            "shippedAt": to_iso_utc(main_order.shippedAt),
            "deliveredAt": to_iso_utc(main_order.deliveredAt),
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

        # Atomically stage idempotency COMPLETED record in the exact same transaction before commit
        if idempotency_key:
            await record_idempotency_result_db_async(
                idempotency_key,
                result_payload,
                db=db,
                user_id=user_id,
                request_hash=request_fingerprint,
                order_id=main_order.id
            )

        if cons_rec:
            cons_rec.status = "COMPLETED"
            cons_rec.orderId = main_order.id

        await db.commit()
        transaction_committed = True
        if "reserved_redis_items" in locals() and reserved_redis_items:
            reserved_redis_items.clear()

        # Clear cart items safely after the order transaction has committed.
        # This guarantees all product row locks are already released by PostgreSQL,
        # completely preventing deadlocks with concurrent background cart syncs.
        try:
            cart_stmt = select(Cart).where(Cart.userId == user_id)
            cart_res = await db.execute(cart_stmt)
            cart_obj = cart_res.scalars().first()
            if cart_obj:
                await db.execute(text("DELETE FROM cart_items WHERE \"cartId\" = :cart_id"), {"cart_id": cart_obj.id})
                await db.commit()
        except Exception as cart_err:
            logger.warning(f"Non-critical post-commit cart clear warning for user {user_id}: {cart_err}")

        # Publish to Redis and memory cache in background after successful business transaction commit
        if idempotency_key:
            background_tasks.add_task(
                publish_idempotency_cache_async,
                idempotency_key,
                result_payload,
                user_id=user_id,
                request_hash=request_fingerprint,
                order_id=main_order.id
            )

        # Dispatch real-time WebSocket alerts and vendor dispatch via background task to return HTTP 201 immediately
        async def _dispatch_post_order_broadcasts(orders_list, items_list, products_list, uid, tid):
            from routers.websockets import manager as ws_manager
            for ord_item in orders_list:
                try:
                    await ws_manager.broadcast_to_channel("general", {
                        "event": "NEW_ORDER",
                        "type": "new-order",
                        "orderId": ord_item.id,
                        "readableId": ord_item.readableId,
                        "shopName": ord_item.shopName,
                        "status": ord_item.status.value,
                        "total": float(ord_item.total),
                        "createdAt": ord_item.createdAt.isoformat(),
                        "restaurantId": ord_item.restaurantId,
                        "traceId": tid,
                    })
                    await ws_manager.broadcast_to_channel("general", {
                        "event": "CART_UPDATE",
                        "type": "cart-updated",
                        "userId": uid,
                        "traceId": tid,
                    })
                    await ws_manager.broadcast_to_channel(f"order_{ord_item.id}", {
                        "event": "NEW_ORDER",
                        "type": "new-order",
                        "orderId": ord_item.id,
                        "readableId": ord_item.readableId,
                        "status": ord_item.status.value,
                        "total": float(ord_item.total),
                        "traceId": tid,
                    })
                except Exception as ws_err:
                    logger.warning(f"Error in background order WebSocket broadcast: {ws_err}")

                # Dedicated Vendor Dispatch
                try:
                    async with AsyncSessionLocal() as v_db:
                        v_all_res = await v_db.execute(select(Vendor).where(Vendor.isActive.is_(True)))
                        active_vendors = v_all_res.scalars().all()
                        vendor_by_id = {v.id: v for v in active_vendors}
                        vendor_by_name = {v.name.lower().strip(): v for v in active_vendors if v.name}

                        vendor_groups = {}
                        for it in items_list:
                            db_p = it.get("dbProduct")
                            if not db_p:
                                raw_id = str((it.get("product") or {}).get("id") or it.get("productId") or "")
                                p_id = raw_id.split("_")[0] if "_" in raw_id else raw_id
                                db_p = next((p for p in products_list if p.id == p_id), None)
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

                        # Alert vendors ONLY if the order is already confirmed/auto-approved (NOT ADMIN_PENDING)
                        if not is_admin_pending:
                            for v_id, v_data in vendor_groups.items():
                                v_obj = v_data["vendor"]
                                v_items = v_data["items"]
                                total_val = sum(i["quantity"] * i["cost"] for i in v_items)

                                await ws_manager.broadcast_to_channel(f"vendor_{v_id}", {
                                    "event": "NEW_VENDOR_ORDER",
                                    "type": "new-vendor-order",
                                    "orderId": ord_item.id,
                                    "readableId": ord_item.readableId,
                                    "items": v_items,
                                    "totalVendorCost": total_val,
                                    "createdAt": ord_item.createdAt.isoformat(),
                                })

                                clean_v_phone = ""
                                if v_obj.phone:
                                    clean_v_phone = re.sub(r'\D', '', str(v_obj.phone))[-10:]
                                    if len(clean_v_phone) == 10:
                                        item_lines = "\n".join([f"• {i['quantity']}x {i['name']} {('[' + i['weight'] + ']') if i['weight'] else ''}" for i in v_items])
                                        v_alert_text = (
                                            f"🔔 *FastMinute New Order Alert #{ord_item.readableId}*\n\n"
                                            f"Customer ordered items from your catalog:\n{item_lines}\n\n"
                                            f"💰 Total Supply Cost: ₹{total_val:.2f}\n"
                                            f"⚡ Please pack and keep ready for FastMinute picker pickup!"
                                        )
                                        await send_whatsapp_alert(clean_v_phone, v_alert_text)

                                vendor_topic = f"vendor_{v_id}"
                                fcm_title = f"📦 New Order #{ord_item.readableId} for Your Store!"
                                fcm_body = f"{len(v_items)} item(s) to pack (₹{total_val:.0f}). Tap to view and mark ready!"
                                fcm_data = {
                                    "type": "VENDOR_NEW_ORDER",
                                    "orderId": ord_item.id,
                                    "readableId": str(ord_item.readableId),
                                    "vendorId": v_id,
                                    "screen": "vendor-console",
                                    "click_action": "FLUTTER_NOTIFICATION_CLICK",
                                }
                                send_fcm_topic_notification(vendor_topic, fcm_title, fcm_body, fcm_data)
                                if clean_v_phone and len(clean_v_phone) == 10:
                                    send_fcm_topic_notification(f"phone_{clean_v_phone}", fcm_title, fcm_body, fcm_data)
                except Exception as vendor_notify_err:
                    logger.warning(f"Could not dispatch vendor notifications for order #{ord_item.readableId}: {vendor_notify_err}")

        background_tasks.add_task(_dispatch_post_order_broadcasts, created_orders, items, db_products, user_id, trace_id)

        # 1. FCM Push Notification directly to Customer (Single consolidated notification for combined orders)
        cust_order_for_notif = created_orders[0]
        base_readable = re.sub(r'-[GR\d]+$', '', str(cust_order_for_notif.readableId or "").strip().lstrip("#"))
        total_combined_amount = sum(safe_float(o.total) for o in created_orders)

        customer_title = "🎉 Order Placed Successfully!"
        customer_body = f"Your order #{base_readable} of ₹{total_combined_amount:.2f} has been placed with FastMinute Express! ⚡"
        background_tasks.add_task(
            send_pwa_notification_to_user,
            cust_order_for_notif.userId,
            customer_title,
            customer_body,
            {
                "orderId": cust_order_for_notif.id,
                "readableId": base_readable,
                "status": cust_order_for_notif.status.value,
                "type": "ORDER_PLACED",
                "role": "CUSTOMER",
                "screen": "order-tracking",
                "isLiveTracking": "true",
            },
            None,
            address.phone if address else None
        )

        # ALWAYS dispatch EXACTLY 1 buzzer to Admin for the checkout (strictly hub-isolated)
        outlets = " + ".join(dict.fromkeys(o.shopName for o in created_orders if o.shopName)) or "FastMinute Store"
        is_combined = len(created_orders) > 1
        background_tasks.add_task(
            dispatch_admin_order_buzzer,
            cust_order_for_notif.id,
            base_readable,
            cust_order_for_notif.storeId or store_id,
            total_combined_amount,
            cust_order_for_notif.status.value,
            is_online_paid,
            outlets,
            is_combined,
        )

        if not is_admin_pending:
            # Auto-approved order: Dispatch isolated outlet alerts to Darkstore pickers and Restaurant chefs (Pickers/Chefs ONLY)
            for order in created_orders:
                background_tasks.add_task(
                    dispatch_isolated_order_fcm_notifications,
                    order.id,
                    order.readableId,
                    order.restaurantId,
                    order.shopName,
                    float(order.total),
                    order.status.value,
                    order.storeId,
                    "PAID" if is_online_paid else "PENDING"
                )

        # Return full order object matching Flutter Order.fromJson expectations
        main_order = next((o for o in created_orders if not o.restaurantId), created_orders[0])

        # Consolidated WhatsApp alert to Hub Admin (Single alert even for multi-outlet combined orders)
        try:
            target_hub_id = main_order.storeId or store_id
            hub_phones = resolve_admin_alert_phones(settings_map, target_hub_id)

            cust_name = user_obj.name or "Customer"
            cust_phone = address.phone if address else (user_obj.phone or "N/A")
            pay_str = "PAID (Online)" if is_online_paid else "COD"

            if len(created_orders) > 1:
                combined_total = sum(safe_float(o.total) for o in created_orders)
                base_id = str(main_order.readableId or "").split("-")[0]
                outlets = " + ".join(dict.fromkeys(o.shopName for o in created_orders if o.shopName)) or "Store & Restaurant"
                admin_text = f"#{base_id} [{outlets}, Rs.{combined_total:.0f} ({pay_str}), {cust_name}: {cust_phone}]"
            else:
                o = created_orders[0]
                outlet = o.shopName or ("Restaurant" if o.restaurantId else "Dark Store")
                admin_text = f"#{o.readableId} [{outlet}, Rs.{safe_float(o.total):.0f} ({pay_str}), {cust_name}: {cust_phone}]"

            dedupe_id = str(main_order.readableId or main_order.id)
            for phone in hub_phones:
                background_tasks.add_task(send_whatsapp_alert, phone, admin_text, dedupe_id)
        except Exception as wa_err:
            logger.warning(f"Error scheduling consolidated WhatsApp admin alert: {wa_err}")

        return result_payload

    except HTTPException as he:
        if not locals().get("transaction_committed"):
            if "reserved_redis_items" in locals() and reserved_redis_items:
                from utils.cache import release_reserved_inventory
                for r_key, r_qty in reserved_redis_items:
                    try:
                        await release_reserved_inventory(r_key, r_qty)
                    except Exception:
                        pass
                reserved_redis_items.clear()
            if locals().get("lock_acquired"):
                await db.rollback()
                if he.status_code != 409:
                    if "idempotency_key" in locals() and idempotency_key:
                        await release_idempotency_lock_async(idempotency_key, db=db, user_id=user_id)
        raise
    except Exception as e:
        if locals().get("transaction_committed"):
            logger.error(f"Post-commit notification/broadcast error in order placement: {str(e)}")
            if "result_payload" in locals() and result_payload:
                return result_payload
        if "reserved_redis_items" in locals() and reserved_redis_items:
            from utils.cache import release_reserved_inventory
            for r_key, r_qty in reserved_redis_items:
                try:
                    await release_reserved_inventory(r_key, r_qty)
                except Exception:
                    pass
            reserved_redis_items.clear()
        await db.rollback()
        logger.error(f"Failed to place order: {str(e)}", exc_info=True)
        if locals().get("lock_acquired"):
            if "idempotency_key" in locals() and idempotency_key:
                await release_idempotency_lock_async(idempotency_key, db=db, user_id=user_id)
        err_str = str(e)
        if any(kw in err_str.lower() for kw in ["deadlock", "asyncpg", "sqlalchemy", "foreignkey", "violates foreign key", "could not serialize"]):
            detail_msg = "Order placement could not be completed due to high server traffic. Please try again."
        else:
            detail_msg = f"Failed to place order: {err_str}"
        raise HTTPException(status_code=500, detail=detail_msg)

# Register read & mutation routes in exact original sequence so route matching is 100% identical
router.add_api_route("", list_orders, methods=["GET"])
router.add_api_route("/{id}", get_order_details, methods=["GET"])
router.add_api_route("/{id}", update_order, methods=["PATCH"])
router.add_api_route("/{order_id}/status", update_order_status_alias, methods=["PATCH"])
router.add_api_route("/{order_id}/track", track_order, methods=["GET"])
router.add_api_route("/cancelled-orders", delete_all_cancelled_orders, methods=["DELETE"])
router.add_api_route("/{id}/payment", update_order_payment, methods=["PATCH"])
router.add_api_route("/{id}/convert-to-cod", convert_order_to_cod, methods=["POST"])
router.add_api_route("/{id}/edit", edit_order, methods=["POST"])
