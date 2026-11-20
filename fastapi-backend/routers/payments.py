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
            {"id": "WALLET", "name": "FastMinute Wallet", "enabled": True, "icon": "wallet"}
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


# ============================================================
# DYNAMIC SERVER-DRIVEN PAYMENT GATEWAY ROUTER
# ============================================================

unified_router = APIRouter(prefix="/payment", tags=["Payment Unified"])

_active_gw_cache = {"value": "razorpay", "timestamp": 0.0}

async def get_active_payment_gateway(db: AsyncSession) -> str:
    global _active_gw_cache
    import time
    now = time.time()
    if now - _active_gw_cache["timestamp"] < 30.0:
        return _active_gw_cache["value"]

    try:
        from models import StoreSetting
        res = await db.execute(select(StoreSetting).where(StoreSetting.key == "active_payment_gateway"))
        row = res.scalars().first()
        gw = str(row.value).strip().lower() if row and row.value else "razorpay"
        if gw not in ["razorpay", "cashfree", "easebuzz", "phonepe"]:
            gw = "razorpay"
        _active_gw_cache["value"] = gw
        _active_gw_cache["timestamp"] = now
        return gw
    except Exception as e:
        logger.warning(f"Error reading active_payment_gateway from DB: {e}")
        return _active_gw_cache.get("value", "razorpay")


@router.get("/active-gateway")
@unified_router.get("/active-gateway")
async def get_active_gateway_endpoint(db: AsyncSession = Depends(get_db)):
    """Returns currently active payment gateway and available fallback gateways."""
    gateway = await get_active_payment_gateway(db)
    return {
        "activeGateway": gateway,
        "availableGateways": ["razorpay", "cashfree", "easebuzz", "phonepe"],
        "fallbackGateway": "cashfree" if gateway == "razorpay" else "razorpay"
    }


@router.post("/active-gateway")
@unified_router.post("/active-gateway")
async def set_active_gateway_endpoint(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Admin control to dynamically switch active payment gateway across entire platform
    without requiring any mobile app updates or website redeployments.
    """
    gw = str(payload.get("gateway") or "").strip().lower()
    if gw not in ["razorpay", "cashfree", "easebuzz", "phonepe"]:
        raise HTTPException(
            status_code=400,
            detail="Unsupported gateway. Must be 'razorpay', 'cashfree', 'easebuzz', or 'phonepe'."
        )

    from models import StoreSetting
    res = await db.execute(select(StoreSetting).where(StoreSetting.key == "active_payment_gateway"))
    setting = res.scalars().first()
    if setting:
        setting.value = gw
    else:
        import uuid
        setting = StoreSetting(id=f"set_{uuid.uuid4().hex[:16]}", key="active_payment_gateway", value=gw)
        db.add(setting)

    await db.commit()

    global _active_gw_cache
    import time
    _active_gw_cache["value"] = gw
    _active_gw_cache["timestamp"] = time.time()

    logger.info(f"⚡ [Payment Gateway Switch] Active gateway updated to {gw.upper()} across all clients.")
    return {
        "success": True,
        "activeGateway": gw,
        "message": f"Active payment gateway successfully switched to {gw.upper()}!"
    }


@router.post("/create-order")
@router.post("/initiate")
@unified_router.post("/create-order")
@unified_router.post("/initiate")
async def create_unified_payment_order(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Unified, Server-Driven Payment Order Creation.
    Dynamically routes to the active gateway (Razorpay or Cashfree).
    If the active gateway experiences any outage, automatically falls back to secondary gateway.
    """
    active_gw = await get_active_payment_gateway(db)
    preferred_gw = str(payload.get("preferredGateway") or payload.get("gateway") or active_gw).strip().lower()

    last_err = None

    # ── BRANCH 1: RAZORPAY ──────────────────────────────────────────
    if preferred_gw == "razorpay":
        try:
            from routers.razorpay_router import create_razorpay_order
            order_res = await create_razorpay_order(payload=payload, db=db)
            if order_res and isinstance(order_res, dict):
                order_res["gateway"] = "RAZORPAY"
                order_res["success"] = True
                return order_res
        except Exception as e:
            logger.warning(f"[Dynamic Gateway Switch] Razorpay creation failed ({e}), falling back to Cashfree...")
            last_err = e
            try:
                from routers.cashfree_router import create_cashfree_order, CashfreeCreateOrderRequest
                cf_req = CashfreeCreateOrderRequest(**payload)
                cf_res = await create_cashfree_order(req=cf_req, db=db)
                if cf_res and isinstance(cf_res, dict):
                    cf_res["gateway"] = "CASHFREE"
                    cf_res["fallbackUsed"] = True
                    return cf_res
            except Exception as cf_err:
                logger.error(f"[Dynamic Gateway Switch] Both Razorpay and Cashfree failed: {cf_err}")
                raise HTTPException(status_code=502, detail=f"Payment initialization failed: {last_err}")

    # ── BRANCH 2: CASHFREE ──────────────────────────────────────────
    else:
        try:
            from routers.cashfree_router import create_cashfree_order, CashfreeCreateOrderRequest
            cf_req = CashfreeCreateOrderRequest(**payload)
            cf_res = await create_cashfree_order(req=cf_req, db=db)
            if cf_res and isinstance(cf_res, dict):
                cf_res["gateway"] = "CASHFREE"
                cf_res["success"] = True
                return cf_res
        except Exception as e:
            logger.warning(f"[Dynamic Gateway Switch] Cashfree creation failed ({e}), falling back to Razorpay...")
            last_err = e
            try:
                from routers.razorpay_router import create_razorpay_order
                order_res = await create_razorpay_order(payload=payload, db=db)
                if order_res and isinstance(order_res, dict):
                    order_res["gateway"] = "RAZORPAY"
                    order_res["fallbackUsed"] = True
                    return order_res
            except Exception as rzp_err:
                logger.error(f"[Dynamic Gateway Switch] Both Cashfree and Razorpay failed: {rzp_err}")
                raise HTTPException(status_code=502, detail=f"Payment initialization failed: {last_err}")
