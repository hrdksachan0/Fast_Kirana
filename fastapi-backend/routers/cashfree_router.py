from fastapi import APIRouter, HTTPException, status, Depends, Request, Response, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
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
        app_url = "https://fastkirana.in"

    payload = {
        "order_id": sanitized_order_id,
        "order_amount": round(total_amount, 2),
        "order_currency": "INR",
        "customer_details": customer_details,
        "order_meta": {
            "return_url": f"{app_url}/order/{resolved_order_id}?payment=cf_success",
            "notify_url": f"{app_url}/api/payment/cashfree/webhook",
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

    headers = _get_cashfree_headers()
    check_id = req.cfOrderId or raw_id
    sanitized_check_id = re.sub(r"[^a-zA-Z0-9_-]", "_", check_id)[:45]

    async with httpx.AsyncClient(timeout=10.0) as client:
        # Check payment records from Cashfree PG
        cf_order = None
        payments = []
        try:
            cf_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}", headers=headers)
            if cf_res.status_code == 200:
                cf_order = cf_res.json()
        except Exception as e:
            logger.warning(f"Failed to fetch Cashfree order {sanitized_check_id}: {e}")

        try:
            pay_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}/payments", headers=headers)
            if pay_res.status_code == 200:
                payments = pay_res.json()
        except Exception as e:
            logger.warning(f"Failed to fetch Cashfree order payments {sanitized_check_id}: {e}")

    successful_payment = next((p for p in payments if p.get("payment_status") == "SUCCESS"), None)
    is_paid = (cf_order and cf_order.get("order_status") == "PAID") or (successful_payment is not None)

    # Locate the order in PostgreSQL
    stmt = select(Order).where(
        (Order.id == clean_id) | (Order.readableId == clean_id) | (Order.id == raw_id)
    )
    res = await db.execute(stmt)
    order = res.scalars().first()

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

    # If already marked PAID in DB, return success
    if order.paymentStatus == PaymentStatus.PAID:
        return {
            "success": True,
            "orderId": order.id,
            "paymentStatus": "PAID",
            "isPaid": True,
            "cfPaymentId": f"CF_{order.id}",
            "orderAmount": float(order.total or 0),
        }

    if is_paid:
        payment_id_str = str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}"
        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = PaymentMethod.UPI
        if order.status == OrderStatus.ADMIN_PENDING:
            order.status = OrderStatus.PENDING

        # Handle companion combined orders if present
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            for co in comb_res.scalars().all():
                co.paymentStatus = PaymentStatus.PAID
                co.paymentMethod = PaymentMethod.UPI
                if co.status == OrderStatus.ADMIN_PENDING:
                    co.status = OrderStatus.PENDING

        await db.commit()

        # Push & WhatsApp Notification
        try:
            from utils.firebase import send_fcm_topic_notification
            send_fcm_topic_notification(
                topic="admin_alerts",
                title="💳 Cashfree Payment Confirmed",
                body=f"Order #{order.readableId or order.id[:8]} paid successfully (₹{float(order.total):.2f})",
                data={"orderId": order.id, "type": "payment_confirmed"}
            )
            from routers.orders import send_whatsapp_alert
            admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total):.0f}. Payment: PAID ✅"
            for admin_phone in ["7054470303", "8112849854"]:
                if background_tasks:
                    background_tasks.add_task(send_whatsapp_alert, admin_phone, admin_text)
                else:
                    import asyncio
                    asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text))
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
async def cashfree_webhook_status():
    """
    Cashfree webhook health check/status endpoint.
    """
    return {"status": "active", "message": "Cashfree Webhook Endpoint Active"}


@router.post("/payment/cashfree/webhook")
async def cashfree_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Webhook endpoint to receive Cashfree server-to-server transaction notifications.
    """
    try:
        raw_body = await request.body()
        payload = json.loads(raw_body) if raw_body else {}
    except Exception:
        return Response(status_code=400, content="Invalid JSON")

    # C5 FIX: Verify Cashfree webhook signature
    webhook_secret = os.environ.get("CASHFREE_WEBHOOK_SECRET", "")
    if webhook_secret:
        signature = request.headers.get("x-webhook-signature", "")
        timestamp = request.headers.get("x-webhook-timestamp", "")
        if signature and timestamp:
            import hmac, hashlib
            sign_payload = timestamp + raw_body.decode("utf-8")
            expected = hmac.new(
                webhook_secret.encode("utf-8"),
                sign_payload.encode("utf-8"),
                hashlib.sha256
            ).hexdigest()
            if not hmac.compare_digest(expected, signature):
                return Response(status_code=401, content="Invalid webhook signature")

    data = payload.get("data", {})
    order_data = data.get("order", {})
    payment_data = data.get("payment", {})

    cf_order_id = order_data.get("order_id")
    payment_status = payment_data.get("payment_status")

    if not cf_order_id:
        return Response(status_code=200, content="OK")

    clean_id = re.sub(r"_r\d+$", "", cf_order_id)

    if payment_status == "SUCCESS":
        stmt = select(Order).where(
            (Order.id == clean_id) | (Order.readableId == clean_id) | (Order.id == cf_order_id)
        )
        res = await db.execute(stmt)
        order = res.scalars().first()

        if order and order.paymentStatus != PaymentStatus.PAID:
            order.paymentStatus = PaymentStatus.PAID
            order.paymentMethod = PaymentMethod.UPI
            if order.status == OrderStatus.ADMIN_PENDING:
                order.status = OrderStatus.PENDING

            if order.combinedId:
                comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
                comb_res = await db.execute(comb_stmt)
                for co in comb_res.scalars().all():
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
                    if co.status == OrderStatus.ADMIN_PENDING:
                        co.status = OrderStatus.PENDING

            await db.commit()

            try:
                from routers.orders import send_whatsapp_alert
                admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total):.0f}. Payment: PAID ✅"
                import asyncio
                for admin_phone in ["7054470303", "8112849854"]:
                    asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text))
            except Exception as wa_err:
                logger.warning(f"Cashfree webhook WhatsApp notification error: {wa_err}")

    return Response(status_code=200, content="OK")
