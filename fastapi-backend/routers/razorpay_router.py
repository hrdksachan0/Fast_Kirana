import hmac
import hashlib
import json
import logging
from typing import Dict, Any, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Body, Request, Response, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
import razorpay

from database import get_db
from config import settings
from models import Order, PaymentStatus, OrderStatus
from routers.auth import require_auth
from utils.firebase import send_fcm_topic_notification

logger = logging.getLogger("fastapi-backend")

router = APIRouter(prefix="/payment/razorpay", tags=["Razorpay Payment Integration"])


def get_razorpay_client():
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(status_code=500, detail="Razorpay API keys not configured in server environment")
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


@router.post("/create-order")
async def create_razorpay_order(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Create Razorpay Order (amount in paise).
    Supports combinedId sibling aggregation (C6 fix) and receipt truncation.
    """
    order_id = payload.get("orderId")
    amount_override = payload.get("amount")

    if not order_id and amount_override is None:
        raise HTTPException(status_code=400, detail="orderId or amount is required")

    total_amount = 0.0
    resolved_order_id = None
    receipt_str = "receipt"
    readable_id_note = ""

    if order_id:
        clean_id = str(order_id).strip()
        stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
        res = await db.execute(stmt)
        order = res.scalars().first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        resolved_order_id = order.id
        receipt_str = str(order.id)[:40]
        readable_id_note = str(order.readableId or "")

        # C6 FIX: If order has combinedId, sum totals across all companion sub-orders
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            sibling_orders = comb_res.scalars().all()
            total_amount = sum(float(so.total or 0.0) for so in sibling_orders)
        else:
            total_amount = float(order.total or 0.0)

    if amount_override is not None:
        try:
            amt_val = float(amount_override)
            if amt_val > total_amount:
                total_amount = amt_val
        except (ValueError, TypeError):
            pass

    amount_in_paise = int(round(total_amount * 100))

    if amount_in_paise < 100:
        raise HTTPException(status_code=400, detail="Minimum payment amount must be at least ₹1.00 (100 paise)")

    try:
        client = get_razorpay_client()
        data = {
            "amount": amount_in_paise,
            "currency": "INR",
            "receipt": receipt_str,
            "notes": {
                "orderId": resolved_order_id or "",
                "readableId": readable_id_note,
                "customerName": "Customer"
            }
        }
        rzp_order = client.order.create(data=data)

        return {
            "success": True,
            "razorpayOrderId": rzp_order["id"],
            "keyId": settings.RAZORPAY_KEY_ID,
            "amount": rzp_order["amount"],
            "currency": rzp_order["currency"],
            "orderId": resolved_order_id
        }
    except Exception as e:
        logger.error(f"Razorpay order creation error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Razorpay error: {str(e)}")


@router.post("/verify-signature")
async def verify_razorpay_signature(
    payload: Dict[str, Any] = Body(...),
    background_tasks: BackgroundTasks = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify Razorpay payment signature and mark order as PAID.
    C11 FIX: Does NOT auto-confirm without restaurant/admin acceptance; promotes ADMIN_PENDING to PENDING.
    Updates all sibling orders if combinedId exists.
    Dispatches FCM push notifications and WhatsApp admin alerts in background.
    """
    order_id = payload.get("orderId")
    razorpay_order_id = payload.get("razorpay_order_id")
    razorpay_payment_id = payload.get("razorpay_payment_id")
    razorpay_signature = payload.get("razorpay_signature")

    if not all([order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature]):
        raise HTTPException(status_code=400, detail="Missing required signature parameters")

    clean_id = str(order_id).strip()
    stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Verify HMAC SHA256 signature
    generated_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode("utf-8"),
        f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(generated_signature, razorpay_signature):
        raise HTTPException(status_code=400, detail="Invalid Razorpay payment signature")

    # C11 FIX: Update Order status to PAID & ONLINE
    now = datetime.utcnow()
    target_orders = [order]
    if order.combinedId:
        comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(comb_stmt)
        target_orders = comb_res.scalars().all()

    for o in target_orders:
        o.paymentStatus = PaymentStatus.PAID
        o.paymentMethod = "ONLINE"
        # Only promote ADMIN_PENDING to PENDING (do not prematurely force CONFIRMED)
        if o.status == OrderStatus.ADMIN_PENDING:
            o.status = OrderStatus.PENDING
        o.updatedAt = now

    await db.commit()
    await db.refresh(order)

    # Dispatch H13 notifications
    if background_tasks:
        try:
            display_id = str(order.readableId or order.id[:6].upper())
            combined_total = sum(float(o.total or 0) for o in target_orders)
            from routers.orders import send_whatsapp_alert

            # 1. FCM Push to Staff
            background_tasks.add_task(
                send_fcm_topic_notification,
                "admin_alerts",
                "💳 Online Payment Order Confirmed!",
                f"Order #{display_id} of ₹{combined_total:.0f} — PAID via Razorpay ✅",
                {"orderId": order.id, "type": "payment_confirmed"}
            )

            # 2. WhatsApp admin notifications
            admin_text = f"💳 *PAID Online Order* #{display_id} of ₹{combined_total:.0f}. Payment: Razorpay PAID ✅."
            for admin_phone in ["7054470303", "8112849854"]:
                background_tasks.add_task(send_whatsapp_alert, admin_phone, admin_text)
        except Exception as notify_err:
            logger.warning(f"Error scheduling payment verification notifications: {notify_err}")

    return {
        "success": True,
        "message": "Payment verified successfully!",
        "orderId": order.id,
        "status": order.status.value,
        "paymentStatus": order.paymentStatus.value
    }


@router.post("/webhook")
async def razorpay_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    C4 FIX: Razorpay server-to-server webhook endpoint.
    Verifies x-razorpay-signature and marks order as PAID if client dropped connection.
    """
    try:
        raw_body = await request.body()
        payload = json.loads(raw_body) if raw_body else {}
    except Exception:
        return Response(status_code=400, content="Invalid JSON")

    webhook_secret = getattr(settings, "RAZORPAY_WEBHOOK_SECRET", None) or settings.RAZORPAY_KEY_SECRET
    if not webhook_secret:
        return Response(status_code=503, content="Webhook secret not configured")

    signature = request.headers.get("x-razorpay-signature")
    if not signature:
        return Response(status_code=401, content="Missing signature")

    expected_sig = hmac.new(
        webhook_secret.encode("utf-8"),
        raw_body,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected_sig, signature):
        return Response(status_code=401, content="Invalid signature")

    event = payload.get("event")
    if event in ["payment.captured", "order.paid"]:
        payment_entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
        order_entity = payload.get("payload", {}).get("order", {}).get("entity", {})

        notes = payment_entity.get("notes") or {}
        target_order_id = notes.get("orderId") or order_entity.get("receipt") or notes.get("receipt")

        order = None
        if target_order_id:
            clean_id = str(target_order_id).strip()
            stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
            res = await db.execute(stmt)
            order = res.scalars().first()

        # Fallback: check recent pending order by exact amount
        if not order:
            amt_in_rupees = float(payment_entity.get("amount") or order_entity.get("amount") or 0) / 100.0
            if amt_in_rupees > 0:
                stmt = select(Order).where(
                    Order.paymentStatus == PaymentStatus.PENDING,
                    Order.total == amt_in_rupees
                ).order_by(Order.createdAt.desc()).limit(1)
                res = await db.execute(stmt)
                order = res.scalars().first()

        if not order:
            return Response(status_code=200, content="No matching order found")

        if order.paymentStatus == PaymentStatus.PAID:
            return Response(status_code=200, content="Order already paid")

        now = datetime.utcnow()
        target_orders = [order]
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            target_orders = comb_res.scalars().all()

        for o in target_orders:
            o.paymentStatus = PaymentStatus.PAID
            o.paymentMethod = "ONLINE"
            if o.status == OrderStatus.ADMIN_PENDING:
                o.status = OrderStatus.PENDING
            o.updatedAt = now

        await db.commit()

    return Response(status_code=200, content="OK")


@router.post("/sync-order")
async def sync_razorpay_order(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Sync order with Razorpay: query Razorpay API for captured payment and mark order as PAID.
    """
    order_id = payload.get("orderId")
    if not order_id:
        raise HTTPException(status_code=400, detail="orderId is required")

    clean_id = str(order_id).strip()
    stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.paymentStatus == PaymentStatus.PAID:
        return {
            "success": True,
            "paymentStatus": "PAID",
            "status": order.status.value,
            "updated": False,
        }

    matched_payment = None
    try:
        client = get_razorpay_client()
        rzp_payments = client.payment.all({"count": 50})
        items = rzp_payments.get("items", [])
        order_total_paise = int(round(float(order.total) * 100))
        target_readable = str(order.readableId or "")

        for p in items:
            if p.get("status") not in ["captured", "authorized"]:
                continue
            notes = p.get("notes") or {}
            notes_order_id = str(notes.get("orderId", ""))
            notes_readable_id = str(notes.get("readableId", ""))
            desc = str(p.get("description", ""))

            has_match = (
                notes_order_id == order.id
                or (target_readable and notes_readable_id == target_readable)
                or (target_readable and target_readable in desc)
            )

            if has_match and int(p.get("amount", 0)) == order_total_paise:
                matched_payment = p
                break
    except Exception as e:
        logger.warning(f"Razorpay sync check error: {e}")

    if not matched_payment:
        return {
            "success": True,
            "paymentStatus": order.paymentStatus.value,
            "status": order.status.value,
            "updated": False,
            "message": "No captured online payment detected on Razorpay yet.",
        }

    now = datetime.utcnow()
    if order.combinedId:
        comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(comb_stmt)
        for o in comb_res.scalars().all():
            o.paymentStatus = PaymentStatus.PAID
            o.paymentMethod = "ONLINE"
            if o.status == OrderStatus.ADMIN_PENDING:
                o.status = OrderStatus.PENDING
            o.updatedAt = now
    else:
        order.paymentStatus = PaymentStatus.PAID
        if order.status == OrderStatus.ADMIN_PENDING:
            order.status = OrderStatus.PENDING
        order.updatedAt = now

    await db.commit()
    await db.refresh(order)

    return {
        "success": True,
        "paymentStatus": "PAID",
        "status": order.status.value,
        "updated": True,
        "message": "Order payment verified and confirmed successfully!",
    }
