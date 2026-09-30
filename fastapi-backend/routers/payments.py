from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, List
from datetime import datetime
import hmac
import hashlib
import logging
from database import get_db
from config import settings
from models import Order, PaymentStatus, OrderStatus, PaymentMethod

logger = logging.getLogger("fastapi-backend")

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.get("/methods")
async def get_payment_methods():
    """
    Get supported payment methods (Cash on Delivery, UPI, Cashfree Online, Wallet).
    """
    return {
        "methods": [
            {"id": "COD", "name": "Cash on Delivery", "enabled": True, "icon": "cash"},
            {"id": "UPI", "name": "UPI / QR Code", "enabled": True, "icon": "qr_code"},
            {"id": "ONLINE", "name": "Online Payment (Cashfree)", "enabled": True, "icon": "credit_card"},
            {"id": "WALLET", "name": "FastKirana Wallet", "enabled": True, "icon": "wallet"}
        ]
    }


@router.post("/verify")
@router.post("/cashfree/sync-order")
async def sync_cashfree_order_in_payments(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Sync order with Cashfree: query Cashfree API for captured payment.
    Never marks as PAID unless Cashfree explicitly confirms SUCCESS / PAID.
    Atomically syncs companion orders if this is a combined order.
    """
    import httpx
    import re
    from routers.cashfree_router import CASHFREE_BASE_URL, _get_cashfree_headers

    order_id = payload.get("orderId") or payload.get("order_id")
    if not order_id:
        raise HTTPException(status_code=400, detail="orderId is required")

    clean_id = str(order_id).strip()
    stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # If already verified PAID, ensure companion sub-orders are also in sync
    if order.paymentStatus == PaymentStatus.PAID:
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            for co in comb_res.scalars().all():
                if co.paymentStatus != PaymentStatus.PAID:
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
            await db.commit()
        return {
            "success": True,
            "paymentStatus": "PAID",
            "status": order.status.value,
            "updated": False,
        }

    # Fetch companion orders if combined
    companion_orders = []
    if order.combinedId:
        comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(comb_stmt)
        companion_orders = comb_res.scalars().all()
    if not companion_orders:
        companion_orders = [order]

    headers = _get_cashfree_headers()
    candidate_ids = [order.id]
    if order.readableId:
        candidate_ids.append(order.readableId)
        base_rid = order.readableId.split("-")[0]
        if base_rid and base_rid != order.readableId:
            candidate_ids.append(base_rid)
    if order.combinedId:
        candidate_ids.append(order.combinedId)
    for co in companion_orders:
        if co.id not in candidate_ids:
            candidate_ids.append(co.id)
        if co.readableId and co.readableId not in candidate_ids:
            candidate_ids.append(co.readableId)

    cf_order = None
    successful_payment = None
    checked_ids = set()

    async with httpx.AsyncClient(timeout=10.0) as client:
        for cid in candidate_ids:
            if not cid:
                continue
            sanitized = re.sub(r"[^a-zA-Z0-9_-]", "_", str(cid).strip())[:45]
            if sanitized in checked_ids:
                continue
            checked_ids.add(sanitized)

            try:
                res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized}", headers=headers)
                if res.status_code == 200:
                    cf_data = res.json()
                    if cf_data.get("order_status") == "PAID":
                        cf_order = cf_data
                        break
                    elif not cf_order:
                        cf_order = cf_data
            except Exception as e:
                logger.warning(f"Error checking Cashfree order {sanitized}: {e}")

            try:
                p_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized}/payments", headers=headers)
                if p_res.status_code == 200:
                    payments = p_res.json()
                    sp = next((p for p in payments if p.get("payment_status") == "SUCCESS"), None)
                    if sp:
                        successful_payment = sp
                        break
            except Exception as e:
                logger.warning(f"Error checking Cashfree payments for {sanitized}: {e}")

    is_paid = (cf_order and cf_order.get("order_status") == "PAID") or (successful_payment is not None)

    if not is_paid:
        return {
            "success": False,
            "paymentStatus": order.paymentStatus.value,
            "status": order.status.value,
            "updated": False,
            "message": "No captured online payment detected on Cashfree gateway.",
        }

    now = datetime.utcnow()
    cf_payment_id = str(successful_payment.get("cf_payment_id", "")) if successful_payment else str(cf_order.get("cf_order_id", ""))
    cf_note = f"Cashfree PG Paid (Ref: {cf_payment_id})"

    for o in companion_orders:
        o.paymentStatus = PaymentStatus.PAID
        o.paymentMethod = PaymentMethod.UPI
        if not o.notes or "Cashfree PG Paid" not in o.notes:
            o.notes = f"{o.notes} | {cf_note}" if o.notes else cf_note
        if o.status == OrderStatus.PENDING or o.status == OrderStatus.ADMIN_PENDING:
            o.status = OrderStatus.CONFIRMED
        o.confirmedAt = now
        o.updatedAt = now

    await db.commit()
    await db.refresh(order)

    return {
        "success": True,
        "paymentStatus": "PAID",
        "status": order.status.value,
        "updated": True,
        "message": "Order payment verified on Cashfree and confirmed successfully!",
    }
