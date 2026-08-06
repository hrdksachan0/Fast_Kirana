"""
Paytm Payment Gateway Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, Body, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any
import os
import uuid
import hashlib
import urllib.parse

from database import get_db
from models import Order, OrderStatus
from routers.auth import require_auth

router = APIRouter(prefix="/api/payment/paytm", tags=["Paytm Payments"])

PAYTM_MID = os.getenv("PAYTM_MID", "")
PAYTM_MERCHANT_KEY = os.getenv("PAYTM_MERCHANT_KEY", "")
PAYTM_WEBSITE = os.getenv("PAYTM_WEBSITE", "WEBSTAGING")
PAYTM_ENV = os.getenv("PAYTM_ENV", "stage")
PAYTM_CALLBACK_URL = os.getenv("PAYTM_CALLBACK_URL", "http://localhost:3000/api/payment/paytm/callback")

PAYTM_BASE_URL = "https://securegw-stage.paytm.in" if PAYTM_ENV == "stage" else "https://securegw.paytm.in"


def _generate_signature(params: Dict[str, str]) -> str:
    """Generate Paytm signature."""
    sorted_params = sorted(params.items(), key=lambda x: x[0])
    param_string = "&".join(f"{k}={v}" for k, v in sorted_params)
    salt = PAYTM_MERCHANT_KEY
    final_string = f"{param_string}&salt={salt}"
    return hashlib.sha256(final_string.encode()).hexdigest()


@router.post("/initiate")
async def paytm_initiate(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Initiate Paytm transaction."""
    order_id = data.get("orderId")
    amount = data.get("amount")
    if not order_id or not amount:
        raise HTTPException(status_code=400, detail="orderId and amount required")

    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(Order).where(Order.id == order_id, Order.userId == user_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    txn_id = f"TXN{uuid.uuid4().hex[:16].upper()}"
    params = {
        "MID": PAYTM_MID,
        "WEBSITE": PAYTM_WEBSITE,
        "INDUSTRY_TYPE_ID": "Retail",
        "CHANNEL_ID": "WEB",
        "ORDER_ID": order.id,
        "CUST_ID": user_id,
        "TXN_AMOUNT": str(amount),
        "CALLBACK_URL": PAYTM_CALLBACK_URL,
    }
    params["CHECKSUMHASH"] = _generate_signature(params)

    return {
        "txnId": txn_id,
        "params": params,
        "url": f"{PAYTM_BASE_URL}/theia/processTransaction",
    }


@router.post("/callback")
async def paytm_callback(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Handle Paytm payment callback."""
    form_data = await request.form()
    payload = dict(form_data)
    received_checksum = payload.get("CHECKSUMHASH", "")
    payload.pop("CHECKSUMHASH", None)

    expected_checksum = _generate_signature(payload)
    if received_checksum != expected_checksum:
        raise HTTPException(status_code=400, detail="Invalid checksum")

    order_id = payload.get("ORDERID")
    status = payload.get("STATUS", "")

    if order_id:
        result = await db.execute(select(Order).where(Order.id == order_id))
        order = result.scalars().first()
        if order:
            from models import PaymentStatus
            if status == "TXN_SUCCESS":
                order.paymentStatus = PaymentStatus.PAID
                order.status = OrderStatus.CONFIRMED
            elif status == "TXN_FAILURE":
                order.paymentStatus = PaymentStatus.FAILED
            await db.commit()

    return {"status": "ok", "payload": payload}


@router.post("/mock-success")
async def paytm_mock_success(
    data: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """Mock successful payment for testing."""
    order_id = data.get("orderId")
    if not order_id:
        raise HTTPException(status_code=400, detail="orderId required")

    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    from models import PaymentStatus
    order.paymentStatus = PaymentStatus.PAID
    order.status = OrderStatus.CONFIRMED
    await db.commit()
    return {"success": True, "orderId": order.id, "status": "PAID"}