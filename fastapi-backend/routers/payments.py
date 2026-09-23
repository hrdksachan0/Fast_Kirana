from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, List
from datetime import datetime
import hmac
import hashlib
import logging
import razorpay

from database import get_db
from config import settings
from models import Order, PaymentStatus, OrderStatus

logger = logging.getLogger("fastapi-backend")

router = APIRouter(prefix="/payments", tags=["Payments"])


def get_razorpay_client():
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(status_code=500, detail="Razorpay API keys not configured in server environment")
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


@router.get("/methods")
async def get_payment_methods():
    """
    Get supported payment methods.
    """
    return {
        "methods": [
            {"id": "COD", "name": "Cash on Delivery", "enabled": True, "icon": "cash"},
            {"id": "UPI", "name": "UPI / QR Code", "enabled": True, "icon": "qr_code"},
            {"id": "ONLINE", "name": "Online Payment (Razorpay/Stripe)", "enabled": True, "icon": "credit_card"},
            {"id": "WALLET", "name": "FastKirana Wallet", "enabled": True, "icon": "wallet"}
        ]
    }


@router.post("/razorpay/create-order")
async def create_razorpay_order_in_payments(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Create Razorpay Order (amount in paise).
    """
    order_id = payload.get("orderId")
    if not order_id:
        raise HTTPException(status_code=400, detail="orderId is required")

    stmt = select(Order).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    amount_in_paise = int(round(float(order.total) * 100))

    if amount_in_paise < 100:
        raise HTTPException(status_code=400, detail="Minimum payment amount must be at least ₹1.00 (100 paise)")

    try:
        client = get_razorpay_client()
        data = {
            "amount": amount_in_paise,
            "currency": "INR",
            "receipt": order.id,
            "notes": {
                "readableId": str(order.readableId or ""),
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
            "orderId": order.id
        }
    except Exception as e:
        logger.error(f"Razorpay order creation error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Razorpay error: {str(e)}")


@router.post("/razorpay/verify-signature")
async def verify_razorpay_signature_in_payments(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Verify Razorpay payment signature and mark order as PAID / CONFIRMED.
    """
    order_id = payload.get("orderId")
    razorpay_order_id = payload.get("razorpay_order_id")
    razorpay_payment_id = payload.get("razorpay_payment_id")
    razorpay_signature = payload.get("razorpay_signature")

    if not all([order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature]):
        raise HTTPException(status_code=400, detail="Missing required signature parameters")

    stmt = select(Order).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    generated_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode("utf-8"),
        f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    if generated_signature != razorpay_signature:
        raise HTTPException(status_code=400, detail="Invalid Razorpay payment signature")

    order.paymentStatus = PaymentStatus.PAID
    order.status = OrderStatus.CONFIRMED
    await db.commit()
    await db.refresh(order)

    return {
        "success": True,
        "message": "Payment verified successfully!",
        "orderId": order.id,
        "status": order.status.value,
        "paymentStatus": order.paymentStatus.value
    }


@router.post("/verify")
async def verify_payment(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Payment verification endpoint — DISABLED.
    All payment verification must go through /razorpay/verify-signature
    with proper HMAC signature verification.
    """
    raise HTTPException(
        status_code=403,
        detail="Direct payment verification is disabled. Use gateway-specific verification endpoints with proper signature validation."
    )


@router.post("/razorpay/sync-order")
async def sync_razorpay_order_in_payments(
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
            if o.status == OrderStatus.PENDING or o.status == OrderStatus.ADMIN_PENDING:
                o.status = OrderStatus.CONFIRMED
            o.confirmedAt = now
            o.updatedAt = now
    else:
        order.paymentStatus = PaymentStatus.PAID
        if order.status == OrderStatus.PENDING or order.status == OrderStatus.ADMIN_PENDING:
            order.status = OrderStatus.CONFIRMED
        order.confirmedAt = now
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
