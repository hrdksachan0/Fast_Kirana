import hmac
import hashlib
import logging
from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Body, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
import razorpay

from database import get_db
from config import settings
from models import Order, PaymentStatus, OrderStatus
from routers.auth import require_auth

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
                "customerName": current_user.get("name", "Customer")
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


@router.post("/verify-signature")
async def verify_razorpay_signature(
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

    # Verify HMAC SHA256 signature
    generated_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode("utf-8"),
        f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    if generated_signature != razorpay_signature:
        raise HTTPException(status_code=400, detail="Invalid Razorpay payment signature")

    # Signature valid! Update Order status to PAID & CONFIRMED
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
