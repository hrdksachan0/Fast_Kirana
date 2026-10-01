from fastapi import APIRouter, HTTPException, status, Depends, Request, Response, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import httpx
import json
import logging
import os
import re
import time
from datetime import datetime

from config import settings
from database import get_db
from models import Order, User, Address, OrderStatus, PaymentStatus, PaymentMethod
from utils.firebase import send_fcm_topic_notification

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Cashfree Payment Gateway"])

CASHFREE_BASE_URL = "https://api.cashfree.com/pg" if settings.CASHFREE_ENV.upper() == "PRODUCTION" else "https://sandbox.cashfree.com/pg"


def _get_cashfree_headers() -> Dict[str, str]:
    if not settings.CASHFREE_APP_ID or not settings.CASHFREE_SECRET_KEY:
        raise HTTPException(
            status_code=500,
            detail="Cashfree credentials not configured on server (CASHFREE_APP_ID / CASHFREE_SECRET_KEY)"
        )
    return {
        "Content-Type": "application/json",
        "x-api-version": settings.CASHFREE_API_VERSION,
        "x-client-id": settings.CASHFREE_APP_ID,
        "x-client-secret": settings.CASHFREE_SECRET_KEY,
    }


class CashfreeCreateOrderRequest(BaseModel):
    orderId: Optional[str] = None
    amount: Optional[float] = None
    customerPhone: Optional[str] = None
    customerEmail: Optional[str] = None
    customerName: Optional[str] = None
    note: Optional[str] = "FastKirana Quick Commerce Order"


class CashfreeVerifyRequest(BaseModel):
    orderId: Optional[str] = None
    cfOrderId: Optional[str] = None


@router.post("/payment/cashfree/create-order")
@router.post("/payments/cashfree/create-order")
async def create_cashfree_order(
    req: CashfreeCreateOrderRequest,
    db: AsyncSession = Depends(get_db)
):
    total_amount = 0.0
    resolved_order_id = req.orderId or f"cf_{int(time.time() * 1000)}"
    customer_id = "guest_customer"
    resolved_phone = req.customerPhone or "9999999999"
    resolved_email = req.customerEmail
    resolved_name = req.customerName or "FastKirana Customer"

    if req.orderId:
        clean_order_id = req.orderId.strip()
        stmt = select(Order).where(
            (Order.id == clean_order_id) | (Order.readableId == clean_order_id)
        )
        res = await db.execute(stmt)
        order = res.scalars().first()

        if order:
            resolved_order_id = order.id
            customer_id = order.userId or order.id
            if order.combinedId:
                comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
                comb_res = await db.execute(comb_stmt)
                comb_orders = comb_res.scalars().all()
                total_amount = sum(float(o.total or 0) for o in comb_orders)
            else:
                total_amount = float(order.total or 0)

            # Fetch user & address details if available
            if order.userId:
                u_res = await db.execute(select(User).where(User.id == order.userId))
                user = u_res.scalars().first()
                if user:
                    if user.phone:
                        resolved_phone = user.phone
                    if user.email:
                        resolved_email = user.email
                    if user.name:
                        resolved_name = user.name

            if order.addressId and not resolved_phone:
                a_res = await db.execute(select(Address).where(Address.id == order.addressId))
                addr = a_res.scalars().first()
                if addr and addr.phone:
                    resolved_phone = addr.phone
        elif req.amount:
            total_amount = float(req.amount)
        else:
            raise HTTPException(status_code=404, detail="Order not found")
    elif req.amount:
        total_amount = float(req.amount)
    else:
        raise HTTPException(status_code=400, detail="orderId or amount is required")

    if req.amount and float(req.amount) > total_amount:
        total_amount = float(req.amount)

    if total_amount < 1.0:
        raise HTTPException(status_code=400, detail="Minimum order amount for online payment is ₹1.00")

    # Clean phone strictly to 10 digits
    clean_phone = re.sub(r"\D", "", resolved_phone or "")[-10:]
    if len(clean_phone) != 10:
        clean_phone = "9999999999"

    clean_cust_id = re.sub(r"[^a-zA-Z0-9_-]", "_", customer_id)[:45]
    sanitized_order_id = re.sub(r"[^a-zA-Z0-9_-]", "_", resolved_order_id)[:45]

    customer_details = {
        "customer_id": clean_cust_id,
        "customer_phone": clean_phone,
        "customer_name": (resolved_name or "FastKirana Customer")[:50],
    }
    if resolved_email and "@" in resolved_email and "." in resolved_email:
        customer_details["customer_email"] = resolved_email.strip().lower()

    app_url = settings.NEXT_PUBLIC_APP_URL.rstrip("/")
    if not app_url.startswith("https://"):
        app_url = "https://www.fastkirana.in"
    elif "fastkirana.in" in app_url and "www." not in app_url and "api." not in app_url:
        app_url = "https://www.fastkirana.in"

    api_url = getattr(settings, "API_BASE_URL", "https://api.fastkirana.in").rstrip("/")

    payload = {
        "order_id": sanitized_order_id,
        "order_amount": round(total_amount, 2),
        "order_currency": "INR",
        "customer_details": customer_details,
        "order_meta": {
            "return_url": f"{app_url}/order/{resolved_order_id}?payment=cf_success",
            "notify_url": f"{api_url}/api/payment/cashfree/webhook",
        },
        "order_note": req.note or "FastKirana Quick Commerce Order",
    }

    headers = _get_cashfree_headers()

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(f"{CASHFREE_BASE_URL}/orders", headers=headers, json=payload)
        data = response.json()

        if response.status_code == 409 or data.get("code") == "order_already_exists":
            # Order already exists in Cashfree, attempt fetch
            get_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_order_id}", headers=headers)
            if get_res.status_code == 200:
                existing_data = get_res.json()
                if existing_data.get("order_status") == "ACTIVE" and existing_data.get("payment_session_id"):
                    return {
                        "success": True,
                        "paymentSessionId": existing_data.get("payment_session_id"),
                        "orderId": existing_data.get("order_id"),
                        "cfOrderId": existing_data.get("cf_order_id"),
                        "orderAmount": existing_data.get("order_amount"),
                        "orderCurrency": existing_data.get("order_currency", "INR"),
                    }

            # If existing order was expired, retry with a fresh order ID suffix
            retry_suffix = f"_r{int(time.time() % 10000)}"
            retry_id = f"{sanitized_order_id[:40]}{retry_suffix}"
            payload["order_id"] = retry_id
            payload["order_meta"]["return_url"] += f"&cf_order_id={retry_id}"
            retry_res = await client.post(f"{CASHFREE_BASE_URL}/orders", headers=headers, json=payload)
            retry_data = retry_res.json()
            if retry_res.status_code in [200, 201] and retry_data.get("payment_session_id"):
                return {
                    "success": True,
                    "paymentSessionId": retry_data.get("payment_session_id"),
                    "orderId": retry_data.get("order_id"),
                    "cfOrderId": retry_data.get("cf_order_id"),
                    "orderAmount": retry_data.get("order_amount"),
                    "orderCurrency": retry_data.get("order_currency", "INR"),
                }

        if response.status_code not in [200, 201]:
            error_msg = data.get("message") or data.get("error") or str(data)
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Cashfree order creation failed: {error_msg}"
            )

        return {
            "success": True,
            "paymentSessionId": data.get("payment_session_id"),
            "orderId": data.get("order_id"),
            "cfOrderId": data.get("cf_order_id"),
            "orderAmount": data.get("order_amount"),
            "orderCurrency": data.get("order_currency", "INR"),
        }


# Cache to debounce/deduplicate alerts across concurrent polling requests and webhooks (order_key -> timestamp)
_alerted_orders_cache: Dict[str, float] = {}


@router.post("/payment/cashfree/verify")
@router.post("/payments/cashfree/verify")
async def verify_cashfree_payment(
    req: CashfreeVerifyRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    if not req.orderId and not req.cfOrderId:
        raise HTTPException(status_code=400, detail="orderId or cfOrderId is required")

    raw_id = (req.orderId or req.cfOrderId or "").strip()
    clean_id = re.sub(r"_r\d+$", "", raw_id)

    # 1. FAST PATH: Check PostgreSQL first before making slow external gateway calls!
    # If already verified & marked PAID, return instantly in ~2ms.
    stmt = select(Order).where(
        (Order.id == clean_id) | (Order.readableId == clean_id) | (Order.id == raw_id) |
        (Order.notes.ilike(f"%{clean_id}%"))
    )
    res = await db.execute(stmt)
    order = res.scalars().first()

    if order and order.paymentStatus == PaymentStatus.PAID:
        # Also ensure companion orders are synced to PAID
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            needs_commit = False
            for co in comb_res.scalars().all():
                if co.paymentStatus != PaymentStatus.PAID:
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
                    needs_commit = True
            if needs_commit:
                await db.commit()

        return {
            "success": True,
            "orderId": order.id,
            "paymentStatus": "PAID",
            "isPaid": True,
            "cfPaymentId": f"CF_{order.id}",
            "orderAmount": float(order.total or 0),
        }

    headers = _get_cashfree_headers()
    candidate_ids = []
    if req.cfOrderId:
        candidate_ids.append(req.cfOrderId)
    if raw_id:
        candidate_ids.append(raw_id)
    if clean_id and clean_id not in candidate_ids:
        candidate_ids.append(clean_id)

    if order:
        if order.id not in candidate_ids:
            candidate_ids.append(order.id)
        if order.readableId:
            if order.readableId not in candidate_ids:
                candidate_ids.append(order.readableId)
            base_rid = order.readableId.split("-")[0]
            if base_rid and base_rid not in candidate_ids:
                candidate_ids.append(base_rid)
        if order.notes:
            cf_matches = re.findall(r"\[CF_ORDER:([^\]]+)\]", order.notes)
            cf_matches += re.findall(r"Cashfree Order:\s*(cf_[a-zA-Z0-9_-]+)", order.notes, re.IGNORECASE)
            cf_matches += re.findall(r"Ref:\s*(?:CF_)?(cf_[a-zA-Z0-9_-]+)", order.notes, re.IGNORECASE)
            for m in cf_matches:
                if m and m not in candidate_ids:
                    candidate_ids.append(m)
        if order.combinedId:
            if order.combinedId not in candidate_ids:
                candidate_ids.append(order.combinedId)
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            for co in comb_res.scalars().all():
                if co.id not in candidate_ids:
                    candidate_ids.append(co.id)
                if co.readableId and co.readableId not in candidate_ids:
                    candidate_ids.append(co.readableId)
                if co.notes:
                    co_cf_matches = re.findall(r"\[CF_ORDER:([^\]]+)\]", co.notes)
                    for cm in co_cf_matches:
                        if cm and cm not in candidate_ids:
                            candidate_ids.append(cm)

    cf_order = None
    successful_payment = None
    checked_ids = set()
    sanitized_check_id = clean_id

    async with httpx.AsyncClient(timeout=10.0) as client:
        for cid in candidate_ids:
            if not cid:
                continue
            sanitized_check_id = re.sub(r"[^a-zA-Z0-9_-]", "_", str(cid).strip())[:45]
            if sanitized_check_id in checked_ids:
                continue
            checked_ids.add(sanitized_check_id)

            try:
                cf_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}", headers=headers)
                if cf_res.status_code == 200:
                    cf_data = cf_res.json()
                    if cf_data.get("order_status") == "PAID":
                        cf_order = cf_data
                        break
                    elif not cf_order:
                        cf_order = cf_data
            except Exception as e:
                logger.warning(f"Failed to fetch Cashfree order {sanitized_check_id}: {e}")

            try:
                pay_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}/payments", headers=headers)
                if pay_res.status_code == 200:
                    payments = pay_res.json()
                    sp = next((p for p in payments if p.get("payment_status") == "SUCCESS"), None)
                    if sp:
                        successful_payment = sp
                        break
            except Exception as e:
                logger.warning(f"Failed to fetch Cashfree order payments {sanitized_check_id}: {e}")

    is_paid = (cf_order and cf_order.get("order_status") == "PAID") or (successful_payment is not None)

    if not order:
        # Preflight checkout check (e.g. Flutter mobile calls verify before order insertion)
        if is_paid:
            return {
                "success": True,
                "orderId": clean_id,
                "paymentStatus": "PAID",
                "isPaid": True,
                "cfPaymentId": str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}",
                "orderAmount": cf_order.get("order_amount") if cf_order else None,
            }
        return {
            "success": False,
            "orderId": clean_id,
            "paymentStatus": cf_order.get("order_status", "PENDING") if cf_order else "PENDING",
            "isPaid": False,
            "message": "Payment has not been completed on Cashfree gateway.",
        }

    if is_paid:
        payment_id_str = str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}"
        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = PaymentMethod.UPI
        cf_note = f"Cashfree PG Paid (Ref: {payment_id_str})"
        if not order.notes or "Cashfree PG Paid" not in order.notes:
            order.notes = f"{order.notes} | {cf_note}" if order.notes else cf_note

        if order.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
            order.status = OrderStatus.CONFIRMED
            if not order.confirmedAt:
                order.confirmedAt = datetime.utcnow()

        # Handle companion combined orders if present
        comb_orders = []
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            comb_orders = comb_res.scalars().all()
            for co in comb_orders:
                co.paymentStatus = PaymentStatus.PAID
                co.paymentMethod = PaymentMethod.UPI
                if not co.notes or "Cashfree PG Paid" not in co.notes:
                    co.notes = f"{co.notes} | {cf_note}" if co.notes else cf_note
                if co.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                    co.status = OrderStatus.CONFIRMED
                    if not co.confirmedAt:
                        co.confirmedAt = datetime.utcnow()

        # Pre-cache payment confirmation in Redis
        try:
            from utils.cache import set_cache
            await set_cache(f"cf_paid:{clean_id}", {"paid": True, "paymentId": payment_id_str}, ttl_seconds=3600)
            if sanitized_check_id != clean_id:
                await set_cache(f"cf_paid:{sanitized_check_id}", {"paid": True, "paymentId": payment_id_str}, ttl_seconds=3600)
        except Exception:
            pass

        # ── DISTRIBUTED ATOMIC DEDUPLICATION GUARD: Ensure WhatsApp alert is sent EXACTLY ONCE ──
        order_key = str(order.combinedId or order.id)
        now_ts = time.time()
        already_notified = False

        if order.notes and "[CF_PAID_ALERT_SENT]" in order.notes:
            already_notified = True
        elif any(co.notes and "[CF_PAID_ALERT_SENT]" in co.notes for co in comb_orders):
            already_notified = True
        elif order_key in _alerted_orders_cache and (now_ts - _alerted_orders_cache[order_key]) < 600:
            already_notified = True
        else:
            try:
                from utils.cache import acquire_lock
                lock_acquired = await acquire_lock(f"lock:cf:paid_notif:{order_key}", ttl_seconds=3600)
                if not lock_acquired:
                    already_notified = True
            except Exception as e:
                logger.warning(f"[Cashfree] Distributed lock check failed: {e}")

        if not already_notified:
            _alerted_orders_cache[order_key] = now_ts
            order.notes = f"{order.notes} [CF_PAID_ALERT_SENT]" if order.notes else "[CF_PAID_ALERT_SENT]"
            for co in comb_orders:
                co.notes = f"{co.notes} [CF_PAID_ALERT_SENT]" if co.notes else "[CF_PAID_ALERT_SENT]"

        await db.commit()

        # Push & WhatsApp Notification (fired ONLY once)
        if not already_notified:
            try:
                from utils.firebase import send_fcm_topic_notification
                from routers.orders import dispatch_isolated_order_fcm_notifications

                target_orders = comb_orders if comb_orders else [order]
                for o in target_orders:
                    if background_tasks:
                        background_tasks.add_task(
                            dispatch_isolated_order_fcm_notifications,
                            o.id,
                            o.readableId,
                            o.restaurantId,
                            o.shopName,
                            float(o.total),
                            "CONFIRMED",
                            o.storeId
                        )
                    else:
                        import asyncio
                        asyncio.create_task(
                            dispatch_isolated_order_fcm_notifications(
                                o.id,
                                o.readableId,
                                o.restaurantId,
                                o.shopName,
                                float(o.total),
                                "CONFIRMED",
                                o.storeId
                            )
                        )
                from routers.orders import send_whatsapp_alert
                if comb_orders:
                    combined_total = sum(float(co.total or 0) for co in comb_orders)
                    base_id = str(order.readableId or "").split("-")[0] or order.id[:6].upper()
                    outlets = " + ".join(dict.fromkeys(co.shopName for co in comb_orders if co.shopName)) or "Combined Order"
                    admin_text = f"💳 *PAID Online Order (Cashfree)* #{base_id} [{outlets}] Total: ₹{combined_total:.0f}. Payment: PAID ✅"
                else:
                    admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total):.0f}. Payment: PAID ✅"

                dedupe_ref = order.readableId or order.id
                for admin_phone in ["7054470303", "8112849854"]:
                    if background_tasks:
                        background_tasks.add_task(send_whatsapp_alert, admin_phone, admin_text, dedupe_ref)
                    else:
                        import asyncio
                        asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text, dedupe_ref))
            except Exception as fcm_err:
                logger.warning(f"Cashfree payment notification error: {fcm_err}")

        return {
            "success": True,
            "orderId": order.id,
            "paymentStatus": "PAID",
            "isPaid": True,
            "cfPaymentId": payment_id_str,
            "orderAmount": float(order.total or 0),
        }

    return {
        "success": False,
        "orderId": order.id,
        "paymentStatus": cf_order.get("order_status", "PENDING") if cf_order else "PENDING",
        "isPaid": False,
        "message": "Payment has not been completed on Cashfree gateway.",
    }


@router.get("/payment/cashfree/webhook")
@router.get("/payments/cashfree/webhook")
async def cashfree_webhook_status():
    """
    Cashfree webhook health check/status endpoint.
    """
    return {"status": "active", "message": "Cashfree Webhook Endpoint Active"}


@router.post("/payment/cashfree/webhook")
@router.post("/payments/cashfree/webhook")
async def cashfree_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Webhook endpoint to receive Cashfree server-to-server transaction notifications.
    Handles PAYMENT_SUCCESS, PAYMENT_FAILED, and USER_DROPPED with full deduplication,
    FCM sound alerts to kitchen & store, WhatsApp notifications, and WebSocket broadcasts.
    """
    try:
        raw_body = await request.body()
        payload = json.loads(raw_body) if raw_body else {}
    except Exception:
        return Response(status_code=400, content="Invalid JSON")

    # Verify Cashfree webhook signature if secret configured
    webhook_secret = os.environ.get("CASHFREE_WEBHOOK_SECRET") or settings.CASHFREE_SECRET_KEY or ""
    if webhook_secret:
        signature = request.headers.get("x-webhook-signature", "")
        timestamp = request.headers.get("x-webhook-timestamp", "")
        if signature and timestamp:
            import hmac, hashlib, base64
            sign_payload = timestamp + raw_body.decode("utf-8")
            digest = hmac.new(
                webhook_secret.encode("utf-8"),
                sign_payload.encode("utf-8"),
                hashlib.sha256
            ).digest()
            expected_b64 = base64.b64encode(digest).decode("utf-8")
            expected_hex = digest.hex()
            if not (hmac.compare_digest(expected_b64, signature) or hmac.compare_digest(expected_hex, signature)):
                logger.warning("[Cashfree Webhook] Invalid webhook signature received")
                return Response(status_code=401, content="Invalid webhook signature")

    event_type = payload.get("type", "")
    data = payload.get("data", {})
    order_data = data.get("order", {})
    payment_data = data.get("payment", {})

    cf_order_id = order_data.get("order_id")
    payment_status = payment_data.get("payment_status")

    if not cf_order_id:
        return Response(status_code=200, content="OK")

    clean_id = re.sub(r"_r\d+$", "", str(cf_order_id).strip())

    # ── 1. PAYMENT SUCCESS FLOW ──────────────────────────────────────────
    if event_type == "PAYMENT_SUCCESS_WEBHOOK" or payment_status == "SUCCESS":
        cf_ref = payment_data.get("cf_payment_id") or cf_order_id
        # Pre-cache payment success in Redis in case webhook arrives before order insertion
        try:
            from utils.cache import set_cache
            await set_cache(f"cf_paid:{clean_id}", {"paid": True, "paymentId": cf_ref}, ttl_seconds=3600)
            if str(cf_order_id) != clean_id:
                await set_cache(f"cf_paid:{cf_order_id}", {"paid": True, "paymentId": cf_ref}, ttl_seconds=3600)
        except Exception as e:
            logger.warning(f"[Cashfree Webhook] Redis pre-caching failed: {e}")

        stmt = select(Order).options(
            selectinload(Order.address),
            selectinload(Order.user),
            selectinload(Order.restaurant)
        ).where(
            (Order.id == clean_id) | 
            (Order.readableId == clean_id) | 
            (Order.id == cf_order_id) |
            (Order.notes.ilike(f"%{clean_id}%")) |
            (Order.notes.ilike(f"%{cf_order_id}%"))
        )
        res = await db.execute(stmt)
        order = res.scalars().first()

        if order and order.paymentStatus != PaymentStatus.PAID:
            was_cod = (order.paymentMethod == PaymentMethod.COD)
            order.paymentStatus = PaymentStatus.PAID
            order.paymentMethod = PaymentMethod.UPI
            cf_note = f"Cashfree PG Paid (Ref: {cf_ref})"
            if not order.notes or "Cashfree PG Paid" not in order.notes:
                order.notes = f"{order.notes} | {cf_note}" if order.notes else cf_note

            if order.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                order.status = OrderStatus.CONFIRMED
                if not order.confirmedAt:
                    order.confirmedAt = datetime.utcnow()

            comb_orders = []
            if order.combinedId:
                comb_stmt = select(Order).options(
                    selectinload(Order.address),
                    selectinload(Order.user),
                    selectinload(Order.restaurant)
                ).where(Order.combinedId == order.combinedId)
                comb_res = await db.execute(comb_stmt)
                comb_orders = comb_res.scalars().all()
                for co in comb_orders:
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
                    if not co.notes or "Cashfree PG Paid" not in co.notes:
                        co.notes = f"{co.notes} | {cf_note}" if co.notes else cf_note
                    if co.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                        co.status = OrderStatus.CONFIRMED
                        if not co.confirmedAt:
                            co.confirmedAt = datetime.utcnow()

            # ── DISTRIBUTED ATOMIC DEDUPLICATION GUARD: Ensure alerts are sent EXACTLY ONCE ──
            order_key = str(order.combinedId or order.id)
            now_ts = time.time()
            already_notified = False

            if order.notes and "[CF_PAID_ALERT_SENT]" in order.notes:
                already_notified = True
            elif any(co.notes and "[CF_PAID_ALERT_SENT]" in co.notes for co in comb_orders):
                already_notified = True
            elif order_key in _alerted_orders_cache and (now_ts - _alerted_orders_cache[order_key]) < 600:
                already_notified = True
            else:
                try:
                    from utils.cache import acquire_lock
                    lock_acquired = await acquire_lock(f"lock:cf:paid_notif:{order_key}", ttl_seconds=3600)
                    if not lock_acquired:
                        already_notified = True
                except Exception as e:
                    logger.warning(f"[Cashfree] Webhook distributed lock check failed: {e}")

            if not already_notified:
                _alerted_orders_cache[order_key] = now_ts
                order.notes = f"{order.notes} [CF_PAID_ALERT_SENT]" if order.notes else "[CF_PAID_ALERT_SENT]"
                for co in comb_orders:
                    co.notes = f"{co.notes} [CF_PAID_ALERT_SENT]" if co.notes else "[CF_PAID_ALERT_SENT]"

            await db.commit()

            # ── Realtime Broadcast & Multi-Channel Notifications ──────────────────
            if not already_notified:
                import asyncio
                target_orders = comb_orders if comb_orders else [order]

                # 1. FCM Push to Darkstore & Restaurant Kitchen
                try:
                    from routers.orders import dispatch_isolated_order_fcm_notifications
                    for o in target_orders:
                        asyncio.create_task(
                            dispatch_isolated_order_fcm_notifications(
                                o.id,
                                o.readableId,
                                o.restaurantId,
                                o.shopName,
                                float(o.total or 0),
                                "CONFIRMED",
                                o.storeId
                            )
                        )
                except Exception as fcm_err:
                    logger.warning(f"[Cashfree Webhook] FCM dispatch notice: {fcm_err}")

                # 2. WhatsApp Notification
                try:
                    from routers.orders import send_whatsapp_alert
                    if comb_orders:
                        combined_total = sum(float(co.total or 0) for co in comb_orders)
                        base_id = str(order.readableId or "").split("-")[0] or order.id[:6].upper()
                        outlets = " + ".join(dict.fromkeys(co.shopName for co in comb_orders if co.shopName)) or "Combined Order"
                        admin_text = f"💳 *PAID Online Order (Cashfree)* #{base_id} [{outlets}] Total: ₹{combined_total:.0f}. Payment: PAID ✅"
                    else:
                        admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total or 0):.0f}. Payment: PAID ✅"

                    if was_cod:
                        admin_text = f"⚠️ *LATE PAYMENT RECONCILED* (Cashfree) #{order.readableId or order.id[:6].upper()} of ₹{float(order.total or 0):.0f}. Paid Online ✅. DO NOT COLLECT CASH!"

                    dedupe_ref = order.readableId or order.id
                    for admin_phone in ["7054470303", "8112849854"]:
                        asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text, dedupe_ref))
                except Exception as wa_err:
                    logger.warning(f"[Cashfree Webhook] WhatsApp notification error: {wa_err}")

                # 3. Live WebSocket Event Broadcast to Customer & Dashboard
                try:
                    from routers.websockets import manager
                    for o in target_orders:
                        clean_oid = str(o.readableId or o.id).strip().lstrip("#")
                        asyncio.create_task(manager.broadcast_to_channel(f"order_{clean_oid}", {
                            "event": "PAYMENT_CONFIRMED",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "status": "CONFIRMED",
                            "paymentStatus": "PAID"
                        }))
                except Exception as ws_err:
                    logger.warning(f"[Cashfree Webhook] WebSocket broadcast notice: {ws_err}")

    # ── 2. PAYMENT FAILED / DROPPED FLOW ─────────────────────────────────
    elif (
        event_type in ["PAYMENT_FAILED_WEBHOOK", "PAYMENT_USER_DROPPED_WEBHOOK"] or
        payment_status in ["FAILED", "USER_DROPPED"]
    ):
        stmt = select(Order).where(
            (Order.id == clean_id) | 
            (Order.readableId == clean_id) | 
            (Order.id == cf_order_id) |
            (Order.notes.ilike(f"%{clean_id}%")) |
            (Order.notes.ilike(f"%{cf_order_id}%"))
        )
        res = await db.execute(stmt)
        order = res.scalars().first()
        if order and order.paymentStatus != PaymentStatus.PAID and order.paymentMethod != PaymentMethod.COD:
            order.paymentStatus = PaymentStatus.FAILED
            await db.commit()
            logger.info(f"[Cashfree Webhook] Marked order #{order.readableId or order.id} as PAYMENT_FAILED")

    return Response(status_code=200, content="OK")

