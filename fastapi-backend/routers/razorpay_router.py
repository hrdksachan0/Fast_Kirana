from fastapi import APIRouter, HTTPException, status, Depends, Request, Response, BackgroundTasks
import asyncio
from datetime import datetime
import uuid
import hmac
import hashlib
import json
import logging
import math
import os
import re
import time
from typing import Optional, Dict, Any, List

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from config import settings
from database import get_db
from models import Order, User, OrderStatus, PaymentStatus, PaymentMethod

logger = logging.getLogger("razorpay_router")

router = APIRouter(tags=["Razorpay Payment Gateway"])


def _get_razorpay_client():
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Razorpay credentials not configured on server (RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET)"
        )
    try:
        import razorpay
        return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
    except ImportError:
        logger.warning("razorpay package not installed, using direct API / HMAC verification")
        return None


def verify_razorpay_signature(order_id: str, payment_id: str, signature: str) -> bool:
    """Verifies Razorpay payment signature using HMAC SHA256."""
    if not settings.RAZORPAY_KEY_SECRET or not order_id or not payment_id or not signature:
        return False
    try:
        msg = f"{order_id}|{payment_id}".encode("utf-8")
        generated_sig = hmac.new(
            settings.RAZORPAY_KEY_SECRET.encode("utf-8"),
            msg,
            hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(generated_sig, signature)
    except Exception as e:
        logger.error(f"Error verifying Razorpay signature: {e}")
        return False


@router.post("/payment/razorpay/create-order")
@router.post("/payments/razorpay/create-order")
async def create_razorpay_order(
    payload: Dict[str, Any],
    db: AsyncSession = Depends(get_db)
):
    """
    Creates a Razorpay Order to initiate UPI / Card / Netbanking checkout in Flutter.
    """
    amount = float(payload.get("amount") or 0.0)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid order amount. Must be greater than 0.")

    amount_paise = int(round(amount * 100))
    customer_phone = str(payload.get("customerPhone") or "").strip()
    customer_email = str(payload.get("customerEmail") or "").strip()
    customer_name = str(payload.get("customerName") or "Customer").strip()
    user_id = payload.get("userId")
    store_id = payload.get("storeId")
    wallet_amount_used = float(payload.get("walletAmountUsed") or 0.0)

    receipt = f"rcpt_{int(time.time() * 1000)}"[:40]

    client = _get_razorpay_client()
    if client:
        try:
            rzp_order = client.order.create({
                "amount": amount_paise,
                "currency": "INR",
                "receipt": receipt,
                "notes": {
                    "userId": str(user_id or ""),
                    "phone": customer_phone,
                    "storeId": str(store_id or ""),
                    "walletAmountUsed": str(wallet_amount_used),
                }
            })
            rzp_order_id = rzp_order.get("id")
        except Exception as e:
            logger.error(f"Razorpay order creation failed: {e}")
            raise HTTPException(status_code=502, detail=f"Failed to create Razorpay order: {str(e)}")
    else:
        # Fallback to direct httpx call if sdk not available
        import httpx
        auth = (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
        async with httpx.AsyncClient(timeout=10.0) as http_client:
            resp = await http_client.post(
                "https://api.razorpay.com/v1/orders",
                auth=auth,
                json={
                    "amount": amount_paise,
                    "currency": "INR",
                    "receipt": receipt,
                    "notes": {
                        "userId": str(user_id or ""),
                        "phone": customer_phone,
                    }
                }
            )
            if resp.status_code not in (200, 201):
                logger.error(f"Razorpay HTTP API error: {resp.text}")
                raise HTTPException(status_code=502, detail="Failed to create Razorpay order via API.")
            data = resp.json()
            rzp_order_id = data.get("id")

    # Cache pending payment intent
    try:
        from utils.cache import set_cache
        await set_cache(
            f"rzp_pending:{rzp_order_id}",
            {
                "orderId": rzp_order_id,
                "amount": amount,
                "userId": user_id,
                "phone": customer_phone,
                "walletAmountUsed": wallet_amount_used,
            },
            ttl=1800
        )
    except Exception:
        pass

    return {
        "orderId": rzp_order_id,
        "amount": amount,
        "amountPaise": amount_paise,
        "currency": "INR",
        "keyId": settings.RAZORPAY_KEY_ID,
        "customerPhone": customer_phone,
        "customerEmail": customer_email if "@" in customer_email else None,
        "customerName": customer_name,
    }


@router.post("/payment/razorpay/verify")
@router.post("/payments/razorpay/verify")
async def verify_razorpay_payment(
    payload: Dict[str, Any],
    db: AsyncSession = Depends(get_db)
):
    """
    Verifies Razorpay payment signature after customer completes payment.
    """
    rzp_order_id = str(payload.get("razorpay_order_id") or payload.get("orderId") or "").strip()
    rzp_payment_id = str(payload.get("razorpay_payment_id") or payload.get("paymentId") or "").strip()
    rzp_signature = str(payload.get("razorpay_signature") or payload.get("signature") or "").strip()

    if not rzp_order_id or not rzp_payment_id or not rzp_signature:
        raise HTTPException(
            status_code=400,
            detail="Missing required verification fields (razorpay_order_id, razorpay_payment_id, razorpay_signature)"
        )

    # 1. Verify cryptographic signature
    is_valid = verify_razorpay_signature(rzp_order_id, rzp_payment_id, rzp_signature)
    if not is_valid:
        # Fallback: Query Razorpay API directly to confirm funds captured
        client = _get_razorpay_client()
        if client and rzp_payment_id.startswith("pay_"):
            try:
                p_details = client.payment.fetch(rzp_payment_id)
                if p_details.get("status") in ("captured", "authorized"):
                    is_valid = True
                    logger.info(f"Verified payment {rzp_payment_id} via direct Razorpay API fetch")
            except Exception as e:
                logger.warning(f"Could not fetch payment {rzp_payment_id} from Razorpay: {e}")

    if not is_valid:
        logger.error(f"Razorpay signature mismatch for order {rzp_order_id}, payment {rzp_payment_id}")
        raise HTTPException(status_code=400, detail="Invalid Razorpay payment signature.")

    # 2. Cache verified payment state in Redis for immediate order placement
    try:
        from utils.cache import set_cache
        await set_cache(f"rzp_paid:{rzp_order_id}", {"paymentId": rzp_payment_id, "isPaid": True}, ttl=3600)
        await set_cache(f"rzp_paid:{rzp_payment_id}", {"orderId": rzp_order_id, "isPaid": True}, ttl=3600)
    except Exception:
        pass

    logger.info(f"✅ Razorpay payment verified: Order {rzp_order_id}, Payment {rzp_payment_id}")
    return {
        "status": "SUCCESS",
        "isPaid": True,
        "orderId": rzp_order_id,
        "paymentId": rzp_payment_id,
        "message": "Payment verified successfully"
    }


@router.post("/payment/razorpay/webhook")
@router.post("/payments/razorpay/webhook")
async def razorpay_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Webhook listener for Razorpay payment.captured events.
    """
    body = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")

    # Optional webhook secret verification if configured
    webhook_secret = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")
    if webhook_secret and sig:
        expected_sig = hmac.new(webhook_secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected_sig, sig):
            raise HTTPException(status_code=400, detail="Invalid webhook signature")

    try:
        event = json.loads(body.decode("utf-8"))
        event_name = event.get("event")
        if event_name == "payment.captured":
            payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
            p_id = payment_entity.get("id")
            o_id = payment_entity.get("order_id")
            amt = float(payment_entity.get("amount", 0)) / 100.0

            if o_id:
                from utils.cache import set_cache
                await set_cache(f"rzp_paid:{o_id}", {"paymentId": p_id, "amount": amt, "isPaid": True}, ttl=3600)
            logger.info(f"Webhook payment.captured for order {o_id}, payment {p_id}, ₹{amt}")
    except Exception as e:
        logger.warning(f"Error handling Razorpay webhook: {e}")

    return {"status": "ok"}
