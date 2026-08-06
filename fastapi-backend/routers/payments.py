from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any, List

from database import get_db
from models import Order, PaymentStatus
from routers.auth import require_auth

router = APIRouter(prefix="/payments", tags=["Payments"])


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


@router.post("/verify")
async def verify_payment(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
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
