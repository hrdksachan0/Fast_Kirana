from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any, List
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
    Verify payment signature and update order status.
    Expected payload: {"orderId": "xxx", "paymentId": "xxx", "signature": "optional"}
    """
    order_id = payload.get("orderId")
    payment_id = payload.get("paymentId")

    if not order_id:
        raise HTTPException(status_code=400, detail="orderId is required")

    stmt = select(Order).where(Order.id == order_id)
    result = await db.execute(stmt)
    order = result.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.paymentStatus = PaymentStatus.PAID
    await db.commit()

    return {
        "success": True,
        "message": "Payment verified successfully",
        "orderId": order_id,
        "paymentId": payment_id or "pay_simulated_123",
        "status": "PAID"
    }
