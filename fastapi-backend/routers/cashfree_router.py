from fastapi import APIRouter, HTTPException, status, Depends, Request, Response, BackgroundTasks
import asyncio
from datetime import datetime, timedelta
import uuid
from sqlalchemy import text, func, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import httpx
import json
import logging
import os
import re
import time

from config import settings
from database import get_db
from models import (
    Order, User, Address, OrderStatus, PaymentStatus, PaymentMethod,
    OrderItem, OrderType, Cart, CartItem, Product, Restaurant
)
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
    userId: Optional[str] = None
    addressId: Optional[str] = None
    items: Optional[List[Dict[str, Any]]] = None
    cartPayload: Optional[Dict[str, Any]] = None
    orderPayload: Optional[Dict[str, Any]] = None
    deliveryMethod: Optional[str] = None
    storeId: Optional[str] = None


class CashfreeVerifyRequest(BaseModel):
    orderId: Optional[str] = None
    cfOrderId: Optional[str] = None


async def _save_pending_checkout_intent(
    db: AsyncSession,
    order_id: str,
    cf_order_id: Optional[str],
    amount: float,
    user_id: Optional[str],
    address_id: Optional[str],
    customer_phone: str,
    customer_name: str,
    customer_email: Optional[str],
    items: Any,
    delivery_method: str = "DELIVERY",
    store_id: Optional[str] = "hub-209206"
):
    """
    Persist pending checkout intent in both Redis cache and durable database (IdempotencyRecord).
    Ensures payment auto-recovery reconstructs exact ordered items, delivery details, and buyer
    even if Redis restarts or cache is evicted.
    Fails closed (HTTP 503) if persistent DB recording fails.
    """
    from utils.cache import set_cache
    from models import IdempotencyRecord
    pending_payload = {
        "orderId": order_id,
        "cfOrderId": cf_order_id,
        "amount": float(amount),
        "userId": user_id,
        "addressId": address_id,
        "customerPhone": customer_phone,
        "customerName": customer_name,
        "customerEmail": customer_email,
        "items": items,
        "deliveryMethod": delivery_method,
        "storeId": store_id or "hub-209206",
        "createdAt": time.time(),
    }
    try:
        await set_cache(f"cf_pending:{order_id}", pending_payload, ttl_seconds=86400)
        if cf_order_id and cf_order_id != order_id:
            await set_cache(f"cf_pending:{cf_order_id}", pending_payload, ttl_seconds=86400)
    except Exception as cache_err:
        logger.warning(f"[Cashfree] Pending session intent cache notice: {cache_err}")

    try:
        intent_expiry = datetime.utcnow() + timedelta(days=2)
        intent_rec = IdempotencyRecord(
            key=f"cf_intent:{order_id}",
            userId=user_id,
            status="PENDING",
            response=pending_payload,
            createdAt=datetime.utcnow(),
            expiresAt=intent_expiry
        )
        await db.merge(intent_rec)
        if cf_order_id and cf_order_id != order_id:
            intent_cf_rec = IdempotencyRecord(
                key=f"cf_intent:{cf_order_id}",
                userId=user_id,
                status="PENDING",
                response=pending_payload,
                createdAt=datetime.utcnow(),
                expiresAt=intent_expiry
            )
            await db.merge(intent_cf_rec)
        await db.commit()
    except Exception as db_err:
        await db.rollback()
        logger.error(f"[Cashfree] Failed to establish durable checkout intent in database: {db_err}")
        raise HTTPException(
            status_code=503,
            detail="Unable to establish recoverable checkout session. Please try again."
        )


@router.post("/payment/cashfree/create-order")
@router.post("/payments/cashfree/create-order")
async def create_cashfree_order(
    req: CashfreeCreateOrderRequest,
    db: AsyncSession = Depends(get_db)
):
    total_amount = 0.0
    resolved_order_id = req.orderId or f"cf_{int(time.time() * 1000)}"
    customer_id = "guest_customer"
    order_payload = req.orderPayload if isinstance(req.orderPayload, dict) else {}
    cart_payload = req.cartPayload if isinstance(req.cartPayload, dict) else {}

    effective_items = (
        req.items
        or order_payload.get("items")
        or cart_payload.get("items")
        or None
    )
    effective_address_id = (
        req.addressId
        or order_payload.get("addressId")
        or cart_payload.get("addressId")
        or None
    )
    effective_delivery_method = (
        req.deliveryMethod
        or order_payload.get("deliveryMethod")
        or cart_payload.get("deliveryMethod")
        or "DELIVERY"
    )
    effective_store_id = (
        req.storeId
        or order_payload.get("storeId")
        or cart_payload.get("storeId")
        or "hub-209206"
    )
    effective_user_id = (
        req.userId
        or order_payload.get("userId")
        or cart_payload.get("userId")
        or None
    )

    resolved_phone = (
        req.customerPhone
        or order_payload.get("phone")
        or order_payload.get("userPhone")
        or "9999999999"
    )
    resolved_email = req.customerEmail or order_payload.get("userEmail") or order_payload.get("customerEmail")
    resolved_name = (
        req.customerName
        or order_payload.get("customerName")
        or order_payload.get("userName")
        or "FastKirana Customer"
    )

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
        app_url = "https://www.fastkirana.in"
    elif "fastkirana.in" in app_url and "www." not in app_url and "api." not in app_url:
        app_url = "https://www.fastkirana.in"

    api_url = getattr(settings, "API_BASE_URL", "https://api.fastkirana.in").rstrip("/")

    payload = {
        "order_id": sanitized_order_id,
        "order_amount": round(total_amount, 2),
        "order_currency": "INR",
        "customer_details": customer_details,
        "order_meta": {
            "return_url": f"{app_url}/order/{resolved_order_id}?payment=cf_success",
            "notify_url": f"{api_url}/api/payment/cashfree/webhook",
        },
        "order_note": req.note or "FastKirana Quick Commerce Order",
    }

    if settings.CASHFREE_ENV.upper() in ["TEST", "MOCK"]:
        mock_cf_order_id = f"cf_{int(time.time() * 1000)}"
        await _save_pending_checkout_intent(
            db=db,
            order_id=sanitized_order_id,
            cf_order_id=mock_cf_order_id,
            amount=float(round(total_amount, 2)),
            user_id=customer_id if customer_id != "guest_customer" else effective_user_id,
            address_id=effective_address_id,
            customer_phone=clean_phone,
            customer_name=resolved_name,
            customer_email=resolved_email,
            items=effective_items,
            delivery_method=effective_delivery_method,
            store_id=effective_store_id
        )
        return {
            "success": True,
            "paymentSessionId": f"session_mock_test_{int(time.time())}",
            "orderId": sanitized_order_id,
            "cfOrderId": mock_cf_order_id,
            "orderAmount": round(total_amount, 2),
            "orderCurrency": "INR",
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
                    await _save_pending_checkout_intent(
                        db=db,
                        order_id=existing_data.get("order_id") or sanitized_order_id,
                        cf_order_id=existing_data.get("cf_order_id"),
                        amount=float(existing_data.get("order_amount") or total_amount),
                        user_id=customer_id if customer_id != "guest_customer" else effective_user_id,
                        address_id=effective_address_id,
                        customer_phone=clean_phone,
                        customer_name=resolved_name,
                        customer_email=resolved_email,
                        items=effective_items,
                        delivery_method=effective_delivery_method,
                        store_id=effective_store_id
                    )
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
                await _save_pending_checkout_intent(
                    db=db,
                    order_id=retry_data.get("order_id") or retry_id,
                    cf_order_id=retry_data.get("cf_order_id"),
                    amount=float(retry_data.get("order_amount") or total_amount),
                    user_id=customer_id if customer_id != "guest_customer" else effective_user_id,
                    address_id=effective_address_id,
                    customer_phone=clean_phone,
                    customer_name=resolved_name,
                    customer_email=resolved_email,
                    items=effective_items,
                    delivery_method=effective_delivery_method,
                    store_id=effective_store_id
                )
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

        # Cache and persist pending order intent so webhook can auto-recover if client drops
        await _save_pending_checkout_intent(
            db=db,
            order_id=data.get("order_id") or sanitized_order_id,
            cf_order_id=data.get("cf_order_id"),
            amount=float(data.get("order_amount") or total_amount),
            user_id=customer_id if customer_id != "guest_customer" else effective_user_id,
            address_id=effective_address_id,
            customer_phone=clean_phone,
            customer_name=resolved_name,
            customer_email=resolved_email,
            items=effective_items,
            delivery_method=effective_delivery_method,
            store_id=effective_store_id
        )

        return {
            "success": True,
            "paymentSessionId": data.get("payment_session_id"),
            "orderId": data.get("order_id"),
            "cfOrderId": data.get("cf_order_id"),
            "orderAmount": data.get("order_amount"),
            "orderCurrency": data.get("order_currency", "INR"),
        }


# Cache to debounce/deduplicate alerts across concurrent polling requests and webhooks (order_key -> timestamp)
_alerted_orders_cache: Dict[str, float] = {}


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

    # 1. FAST PATH: Check indexed primary keys first in ~2ms!
    stmt = select(Order).where(
        (Order.id == clean_id) | (Order.readableId == clean_id) | (Order.id == raw_id)
    )
    res = await db.execute(stmt)
    order = res.scalars().first()

    if order and order.paymentStatus == PaymentStatus.PAID:
        # Also ensure companion orders are synced to PAID
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            needs_commit = False
            for co in comb_res.scalars().all():
                if co.paymentStatus != PaymentStatus.PAID:
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
                    needs_commit = True
            if needs_commit:
                await db.commit()

        return {
            "success": True,
            "orderId": order.id,
            "paymentStatus": "PAID",
            "isPaid": True,
            "cfPaymentId": f"CF_{order.id}",
            "orderAmount": float(order.total or 0),
        }

    if settings.CASHFREE_ENV.upper() in ["TEST", "MOCK"]:
        return {
            "success": True,
            "orderId": clean_id,
            "paymentStatus": "PAID" if order else "ACTIVE",
            "isPaid": bool(order),
            "cfPaymentId": f"CF_TEST_{clean_id}",
            "orderAmount": float(order.total if order else 10.0),
        }

    headers = _get_cashfree_headers()
    candidate_ids = []
    valid_order_candidates = set()

    if order:
        if getattr(order, "cfOrderId", None):
            valid_order_candidates.add(order.cfOrderId)
            valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", order.cfOrderId)[:45])
            if order.cfOrderId not in candidate_ids:
                candidate_ids.append(order.cfOrderId)

        valid_order_candidates.add(order.id)
        valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", order.id)[:45])
        if order.readableId:
            valid_order_candidates.add(order.readableId)
            valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", order.readableId)[:45])
            base_rid = order.readableId.split("-")[0]
            if base_rid:
                valid_order_candidates.add(base_rid)
                valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", base_rid)[:45])
        if order.combinedId:
            valid_order_candidates.add(order.combinedId)
            valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", order.combinedId)[:45])
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            for co in comb_res.scalars().all():
                if getattr(co, "cfOrderId", None):
                    valid_order_candidates.add(co.cfOrderId)
                    valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", co.cfOrderId)[:45])
                valid_order_candidates.add(co.id)
                valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", co.id)[:45])
                if co.readableId:
                    valid_order_candidates.add(co.readableId)
                    valid_order_candidates.add(re.sub(r"[^a-zA-Z0-9_-]", "_", co.readableId)[:45])

        # Also check Redis pending session cache and durable DB intent for caller's cfOrderId to see if it was created for this order
        if req.cfOrderId:
            cf_cand = req.cfOrderId.strip()
            clean_cf_cand = re.sub(r"_r\d+$", "", cf_cand)
            try:
                from utils.cache import get_cache
                cached_intent = await get_cache(f"cf_pending:{cf_cand}") or await get_cache(f"cf_pending:{clean_cf_cand}")
                if not cached_intent:
                    from models import IdempotencyRecord
                    db_intent_stmt = select(IdempotencyRecord).where(
                        IdempotencyRecord.key.in_([f"cf_intent:{cf_cand}", f"cf_intent:{clean_cf_cand}"])
                    )
                    db_intent_res = await db.execute(db_intent_stmt)
                    db_intent_rec = db_intent_res.scalars().first()
                    if db_intent_rec and isinstance(db_intent_rec.response, dict):
                        cached_intent = db_intent_rec.response
                if isinstance(cached_intent, dict):
                    cached_oid = str(cached_intent.get("orderId", "")).strip()
                    if cached_oid in valid_order_candidates or re.sub(r"[^a-zA-Z0-9_-]", "_", cached_oid)[:45] in valid_order_candidates:
                        valid_order_candidates.add(cf_cand)
                        valid_order_candidates.add(clean_cf_cand)
            except Exception:
                pass

        # Build candidate_ids strictly from validated order candidates
        for voc in valid_order_candidates:
            if voc and voc not in candidate_ids:
                candidate_ids.append(voc)
    else:
        # Preflight checkout check without DB order yet
        if req.cfOrderId:
            candidate_ids.append(req.cfOrderId)
        if raw_id and raw_id not in candidate_ids:
            candidate_ids.append(raw_id)
        if clean_id and clean_id not in candidate_ids:
            candidate_ids.append(clean_id)

    cf_order = None
    successful_payment = None
    checked_ids = set()
    sanitized_check_id = clean_id

    async with httpx.AsyncClient(timeout=4.0) as client:
        for cid in candidate_ids:
            if not cid:
                continue
            sanitized_check_id = re.sub(r"[^a-zA-Z0-9_-]", "_", str(cid).strip())[:45]
            if sanitized_check_id in checked_ids:
                continue
            checked_ids.add(sanitized_check_id)

            try:
                cf_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}", headers=headers)
                if cf_res.status_code == 200:
                    cf_data = cf_res.json()
                    if cf_data.get("order_status") == "PAID":
                        cf_order = cf_data
                        break
                    elif not cf_order:
                        cf_order = cf_data
            except Exception as e:
                logger.warning(f"Failed to fetch Cashfree order {sanitized_check_id}: {e}")

            if not cf_order or cf_order.get("order_status") != "PAID":
                try:
                    pay_res = await client.get(f"{CASHFREE_BASE_URL}/orders/{sanitized_check_id}/payments", headers=headers)
                    if pay_res.status_code == 200:
                        payments = pay_res.json()
                        sp = next((p for p in payments if p.get("payment_status") == "SUCCESS"), None)
                        if sp:
                            successful_payment = sp
                            break
                except Exception as e:
                    logger.warning(f"Failed to fetch Cashfree order payments {sanitized_check_id}: {e}")

    is_paid = (cf_order and cf_order.get("order_status") == "PAID") or (successful_payment is not None)

    if not order:
        # Preflight checkout check (e.g. Flutter mobile calls verify before order insertion)
        if is_paid:
            cf_amount = None
            if cf_order and cf_order.get("order_amount") is not None:
                try:
                    cf_amount = float(cf_order.get("order_amount"))
                except (ValueError, TypeError):
                    pass
            elif successful_payment and successful_payment.get("payment_amount") is not None:
                try:
                    cf_amount = float(successful_payment.get("payment_amount"))
                except (ValueError, TypeError):
                    pass

            if cf_amount is None or cf_amount <= 0:
                logger.error(f"[Cashfree Security] Preflight verification rejected: missing/invalid payment amount.")
                raise HTTPException(status_code=400, detail="Gateway payment missing valid amount.")

            from utils.cache import get_cache
            check_cf = req.cfOrderId or clean_id
            clean_check_cf = re.sub(r"_r\d+$", "", check_cf)
            pending_intent = await get_cache(f"cf_pending:{check_cf}") or await get_cache(f"cf_pending:{clean_check_cf}")
            if pending_intent and isinstance(pending_intent, dict):
                expected_p_amt = float(pending_intent.get("amount") or 0)
                if expected_p_amt > 0 and abs(cf_amount - expected_p_amt) > 0.05:
                    logger.error(f"[Cashfree Security] Preflight amount mismatch: Paid ₹{cf_amount:.2f} != Expected ₹{expected_p_amt:.2f}")
                    raise HTTPException(status_code=400, detail="Gateway payment amount does not match checkout session amount.")

            return {
                "success": True,
                "orderId": clean_id,
                "paymentStatus": "PAID",
                "isPaid": True,
                "cfPaymentId": str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}",
                "orderAmount": cf_amount,
            }
        return {
            "success": False,
            "orderId": clean_id,
            "paymentStatus": cf_order.get("order_status", "PENDING") if cf_order else "PENDING",
            "isPaid": False,
            "message": "Payment has not been completed on Cashfree gateway.",
        }

    # Verify gateway order identity strictly binds to this order
    if order and cf_order:
        cf_gateway_id = str(cf_order.get("order_id", "")).strip()
        cf_gateway_clean = re.sub(r"_r\d+$", "", cf_gateway_id)
        if (cf_gateway_id not in valid_order_candidates and 
            cf_gateway_clean not in valid_order_candidates and
            re.sub(r"[^a-zA-Z0-9_-]", "_", cf_gateway_clean)[:45] not in valid_order_candidates):
            logger.error(
                f"[Cashfree Security] Payment binding mismatch: Gateway order_id '{cf_gateway_id}' does not match order '{order.id}'."
            )
            raise HTTPException(
                status_code=400,
                detail="Payment gateway order binding mismatch: the payment does not belong to this order."
            )

    if is_paid:
        # SECURITY & INTEGRITY: Strictly verify that the gateway paid amount matches the local order total!
        # Prevents unrelated or partial payments (e.g. paying ₹1 or paying for a different order).
        cf_amount = None
        if cf_order and cf_order.get("order_amount") is not None:
            try:
                cf_amount = float(cf_order.get("order_amount"))
            except (ValueError, TypeError):
                pass
        elif successful_payment and successful_payment.get("payment_amount") is not None:
            try:
                cf_amount = float(successful_payment.get("payment_amount"))
            except (ValueError, TypeError):
                pass

        expected_total = float(order.total or 0.0)
        # If companion orders exist under a combined checkout, check against sum of combined totals
        if order.combinedId:
            comb_check = await db.execute(select(func.sum(Order.total)).where(Order.combinedId == order.combinedId))
            sum_comb = comb_check.scalar()
            if sum_comb:
                expected_total = float(sum_comb)

        if cf_amount is None or expected_total <= 0:
            logger.error(f"[Cashfree Security] Payment verification rejected: missing amount (cf_amount={cf_amount}, expected={expected_total}).")
            raise HTTPException(
                status_code=400,
                detail="Unable to verify payment: gateway did not report a valid payment amount."
            )

        if abs(cf_amount - expected_total) > 0.05:
            logger.error(
                f"[Cashfree Security] Payment amount mismatch: Gateway paid ₹{cf_amount:.2f} but Order expects ₹{expected_total:.2f}. Rejecting."
            )
            raise HTTPException(
                status_code=400,
                detail=f"Payment amount mismatch: gateway received ₹{cf_amount:.2f}, expected ₹{expected_total:.2f}. Payment rejected."
            )

        payment_id_str = str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}"
        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = PaymentMethod.UPI
        cf_note = f"Cashfree PG Paid (Ref: {payment_id_str})"
        if not order.notes or "Cashfree PG Paid" not in order.notes:
            order.notes = f"{order.notes} | {cf_note}" if order.notes else cf_note

        cf_order_key = str(cf_order.get("order_id") if cf_order else (req.cfOrderId or clean_id)).strip()
        if not getattr(order, "cfOrderId", None) and cf_order_key:
            order.cfOrderId = cf_order_key

        try:
            from models import IdempotencyRecord
            cons_rec = IdempotencyRecord(
                key=f"consumed_payment:{cf_order_key}",
                userId=order.userId,
                status="COMPLETED",
                orderId=order.id,
                createdAt=datetime.utcnow(),
                expiresAt=datetime.utcnow() + timedelta(days=7)
            )
            await db.merge(cons_rec)
        except Exception:
            pass

        if order.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
            order.status = OrderStatus.CONFIRMED
            if not order.confirmedAt:
                order.confirmedAt = datetime.utcnow()

        # Handle companion combined orders if present
        comb_orders = []
        if order.combinedId:
            comb_stmt = select(Order).where(Order.combinedId == order.combinedId)
            comb_res = await db.execute(comb_stmt)
            comb_orders = comb_res.scalars().all()
            for co in comb_orders:
                co.paymentStatus = PaymentStatus.PAID
                co.paymentMethod = PaymentMethod.UPI
                if not co.notes or "Cashfree PG Paid" not in co.notes:
                    co.notes = f"{co.notes} | {cf_note}" if co.notes else cf_note
                if co.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                    co.status = OrderStatus.CONFIRMED
                    if not co.confirmedAt:
                        co.confirmedAt = datetime.utcnow()

        # Pre-cache payment confirmation in Redis
        try:
            from utils.cache import set_cache
            await set_cache(f"cf_paid:{clean_id}", {"paid": True, "paymentId": payment_id_str}, ttl_seconds=3600)
            if sanitized_check_id != clean_id:
                await set_cache(f"cf_paid:{sanitized_check_id}", {"paid": True, "paymentId": payment_id_str}, ttl_seconds=3600)
        except Exception:
            pass

        # ── DISTRIBUTED ATOMIC DEDUPLICATION GUARD: Ensure WhatsApp alert is sent EXACTLY ONCE ──
        order_key = str(order.combinedId or order.id)
        now_ts = time.time()
        already_notified = False

        if order.notes and "[CF_PAID_ALERT_SENT]" in order.notes:
            already_notified = True
        elif any(co.notes and "[CF_PAID_ALERT_SENT]" in co.notes for co in comb_orders):
            already_notified = True
        elif order_key in _alerted_orders_cache and (now_ts - _alerted_orders_cache[order_key]) < 600:
            already_notified = True
        else:
            try:
                from utils.cache import acquire_lock
                lock_acquired = await acquire_lock(f"lock:cf:paid_notif:{order_key}", ttl_seconds=3600)
                if not lock_acquired:
                    already_notified = True
            except Exception as e:
                logger.warning(f"[Cashfree] Distributed lock check failed: {e}")

        if not already_notified:
            _alerted_orders_cache[order_key] = now_ts
            order.notes = f"{order.notes} [CF_PAID_ALERT_SENT]" if order.notes else "[CF_PAID_ALERT_SENT]"
            for co in comb_orders:
                co.notes = f"{co.notes} [CF_PAID_ALERT_SENT]" if co.notes else "[CF_PAID_ALERT_SENT]"

        await db.commit()

        # Push & WhatsApp Notification (fired ONLY once)
        if not already_notified:
            try:
                from utils.firebase import send_fcm_topic_notification
                from routers.orders import dispatch_isolated_order_fcm_notifications

                target_orders = comb_orders if comb_orders else [order]
                for o in target_orders:
                    if background_tasks:
                        background_tasks.add_task(
                            dispatch_isolated_order_fcm_notifications,
                            o.id,
                            o.readableId,
                            o.restaurantId,
                            o.shopName,
                            float(o.total),
                            "CONFIRMED",
                            o.storeId
                        )
                    else:
                        import asyncio
                        asyncio.create_task(
                            dispatch_isolated_order_fcm_notifications(
                                o.id,
                                o.readableId,
                                o.restaurantId,
                                o.shopName,
                                float(o.total),
                                "CONFIRMED",
                                o.storeId
                            )
                        )
                from routers.orders import send_whatsapp_alert
                if comb_orders:
                    combined_total = sum(float(co.total or 0) for co in comb_orders)
                    base_id = str(order.readableId or "").split("-")[0] or order.id[:6].upper()
                    outlets = " + ".join(dict.fromkeys(co.shopName for co in comb_orders if co.shopName)) or "Combined Order"
                    admin_text = f"💳 *PAID Online Order (Cashfree)* #{base_id} [{outlets}] Total: ₹{combined_total:.0f}. Payment: PAID ✅"
                else:
                    admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total):.0f}. Payment: PAID ✅"

                dedupe_ref = order.readableId or order.id
                for admin_phone in ["7054470303", "8112849854"]:
                    if background_tasks:
                        background_tasks.add_task(send_whatsapp_alert, admin_phone, admin_text, dedupe_ref)
                    else:
                        import asyncio
                        asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text, dedupe_ref))
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


async def auto_recover_unplaced_cashfree_order(
    cf_order_id: str,
    clean_id: str,
    cf_ref: str,
    order_data: Dict[str, Any],
    payment_data: Dict[str, Any],
    db: AsyncSession
) -> Optional[Order]:
    """
    Emergency Auto-Recovery for paid Cashfree orders:
    If a customer pays online via UPI/gateway but their client app closed, dropped connection,
    or threw an error before completing POST /api/orders, this function reconstructs the order,
    commits it to PostgreSQL, enqueues the kitchen KOT, and sends alerts so NO ORDER IS EVER MISSED!
    """
    try:
        from utils.cache import get_cache
        from sqlalchemy import text, or_
        import uuid

        # 0. Check if order already recovered or created with this cfOrderId / clean_id
        # Authoritative lookup strictly uses explicit order fields — NEVER free-text notes
        existing_stmt = select(Order).options(
            selectinload(Order.address),
            selectinload(Order.user)
        ).where(
            or_(
                Order.cfOrderId == cf_order_id,
                Order.cfOrderId == clean_id,
                Order.id == clean_id,
                Order.readableId == clean_id
            )
        )
        existing_res = await db.execute(existing_stmt)
        existing_order = existing_res.scalars().first()
        if existing_order:
            # Verify that existing_order belongs to the same buyer if customer info is provided in payment data
            cust_details = order_data.get("customer_details") or {}
            raw_phone = cust_details.get("customer_phone")
            if raw_phone and existing_order.user and existing_order.user.phone:
                clean_pay_phone = re.sub(r"\D", "", str(raw_phone))[-10:]
                clean_user_phone = re.sub(r"\D", "", str(existing_order.user.phone))[-10:]
                if clean_pay_phone and clean_user_phone and clean_pay_phone != clean_user_phone:
                    logger.error(
                        f"[Cashfree Security] Cross-buyer recovery rejected: Payment phone '{clean_pay_phone}' "
                        f"does not match existing order buyer '{clean_user_phone}'"
                    )
                    return None

            logger.info(f"[Cashfree Recovery] Order already recovered or exists for {cf_order_id}: #{existing_order.readableId or existing_order.id}")
            if not getattr(existing_order, "cfOrderId", None):
                existing_order.cfOrderId = cf_order_id
                await db.commit()
            return existing_order

        # 0.5 Atomic payment fulfillment lock to prevent concurrent duplicate recovery across workers
        consumed_key = f"consumed_payment:{cf_order_id}"
        cons_rec = None
        from models import IdempotencyRecord
        try:
            cons_rec = IdempotencyRecord(
                key=consumed_key,
                userId=None,
                status="PROCESSING",
                createdAt=datetime.utcnow(),
                expiresAt=datetime.utcnow() + timedelta(days=7)
            )
            db.add(cons_rec)
            await db.flush()
        except Exception:
            # Another worker already inserted or is recovering this payment
            await db.rollback()
            existing_res = await db.execute(existing_stmt)
            existing_order = existing_res.scalars().first()
            if existing_order:
                return existing_order
            rec_stmt = select(IdempotencyRecord).where(IdempotencyRecord.key == consumed_key)
            rec_res = await db.execute(rec_stmt)
            rec_found = rec_res.scalars().first()
            if rec_found and rec_found.orderId:
                ord_res = await db.execute(
                    select(Order).options(selectinload(Order.address), selectinload(Order.user)).where(Order.id == rec_found.orderId)
                )
                recovered = ord_res.scalars().first()
                if recovered:
                    return recovered
            return None

        # 1. Check pending checkout cache (supports FastAPI cf_pending, Next.js draft_cf_order, and durable cf_intent DB snapshot)
        pending_data = await get_cache(f"cf_pending:{clean_id}")
        if not pending_data:
            pending_data = await get_cache(f"draft_cf_order:{clean_id}")
        if not pending_data and cf_order_id != clean_id:
            pending_data = (await get_cache(f"cf_pending:{cf_order_id}")) or (await get_cache(f"draft_cf_order:{cf_order_id}"))

        if not pending_data:
            intent_keys = [f"cf_intent:{clean_id}"]
            if cf_order_id and cf_order_id != clean_id:
                intent_keys.append(f"cf_intent:{cf_order_id}")
            intent_stmt = select(IdempotencyRecord).where(IdempotencyRecord.key.in_(intent_keys))
            intent_res = await db.execute(intent_stmt)
            intent_rec = intent_res.scalars().first()
            if intent_rec and isinstance(intent_rec.response, dict):
                pending_data = intent_rec.response

        # 2. Extract customer details
        cust_details = order_data.get("customer_details") or {}
        raw_phone = (
            cust_details.get("customer_phone")
            or (pending_data.get("customerPhone") if pending_data else None)
            or "9999999999"
        )
        clean_phone = re.sub(r"\D", "", str(raw_phone))[-10:]
        if len(clean_phone) != 10:
            clean_phone = "9999999999"

        customer_name = (
            cust_details.get("customer_name")
            or (pending_data.get("customerName") if pending_data else None)
            or "FastKirana Customer"
        )
        order_amount = float(order_data.get("order_amount") or (pending_data.get("amount") if pending_data else 0.0) or (payment_data.get("payment_amount") or 0.0))

        # 3. Find user in database
        u_stmt = select(User).where(User.phone == clean_phone)
        u_res = await db.execute(u_stmt)
        user = u_res.scalars().first()

        user_id = user.id if user else (pending_data.get("userId") if pending_data and not str(pending_data.get("userId")).startswith("guest_") else None)
        if not user_id:
            # Create user if missing
            user_id = f"usr_{uuid.uuid4().hex[:16]}"
            user = User(
                id=user_id,
                name=customer_name,
                email=f"{clean_phone}@fastkirana.in",
                phone=clean_phone,
                role="USER"
            )
            db.add(user)
            await db.flush()

        # 4. Resolve address
        address = None
        req_addr_id = pending_data.get("addressId") if pending_data else None
        if req_addr_id:
            a_stmt = select(Address).where(Address.id == req_addr_id)
            a_res = await db.execute(a_stmt)
            address = a_res.scalars().first()

        if not address and user:
            # Find default address, then any address
            a_stmt = select(Address).where(Address.userId == user.id).order_by(Address.isDefault.desc())
            a_res = await db.execute(a_stmt)
            address = a_res.scalars().first()

        if not address:
            # Fallback express zone address
            new_addr_id = f"addr_{uuid.uuid4().hex[:16]}"
            address = Address(
                id=new_addr_id,
                userId=user_id,
                label="Home",
                houseNo="Ghatampur Express Zone",
                street="NH34 Main Road",
                area="Ghatampur",
                city="Ghatampur",
                pincode="209206",
                phone=f"+91{clean_phone}",
                lat=26.1534185,
                lng=80.1714024,
                isDefault=True
            )
            db.add(address)
            await db.flush()

        # 5. Resolve items
        items_to_create = []
        is_restaurant = False
        target_restaurant_id = None
        target_shop_name = "FastKirana Express"

        recovered_delivery_method = str(pending_data.get("deliveryMethod") or "DELIVERY").upper() if pending_data else "DELIVERY"
        recovered_store_id = str(pending_data.get("storeId") or "hub-209206") if pending_data else "hub-209206"

        # Check pending cache items first
        cached_items = pending_data.get("items") if pending_data else None
        if cached_items and isinstance(cached_items, list):
            prod_ids = [str(it.get("productId") or (it.get("product") or {}).get("id") or "").strip() for it in cached_items]
            prod_ids = [pid for pid in prod_ids if pid]
            db_products = {}
            if prod_ids:
                p_res = await db.execute(select(Product).where(Product.id.in_(prod_ids)))
                for p in p_res.scalars().all():
                    db_products[p.id] = p

            for it in cached_items:
                prod = it.get("product") or it
                p_id = str(it.get("productId") or prod.get("id") or "").strip()
                db_prod = db_products.get(p_id)

                p_name = (db_prod.name if db_prod else (it.get("name") or prod.get("name"))) or "Product"
                p_price = float((db_prod.price if db_prod else None) or it.get("price") or prod.get("price") or 0.0)
                p_qty = int(it.get("quantity") or 1)
                p_rest_id = (db_prod.restaurantId if db_prod else None) or it.get("restaurantId") or prod.get("restaurantId")
                p_img = (db_prod.imageUrl if db_prod else None) or it.get("imageUrl") or prod.get("imageUrl")
                p_var = it.get("selectedVariant") or prod.get("selectedVariant")
                if p_rest_id:
                    is_restaurant = True
                    target_restaurant_id = p_rest_id

                items_to_create.append({
                    "productId": p_id or None,
                    "name": p_name,
                    "price": p_price,
                    "quantity": p_qty,
                    "imageUrl": p_img,
                    "selectedVariant": p_var,
                })

        # If no cached items, inspect user's cart in database
        if not items_to_create and user:
            cart_stmt = select(Cart).where(Cart.userId == user.id)
            cart_res = await db.execute(cart_stmt)
            cart = cart_res.scalars().first()
            if cart:
                ci_stmt = select(CartItem).options(selectinload(CartItem.product)).where(CartItem.cartId == cart.id)
                ci_res = await db.execute(ci_stmt)
                c_items = ci_res.scalars().all()
                for ci in c_items:
                    prod = ci.product
                    p_id = prod.id if prod else ci.productId
                    p_name = prod.name if prod else "Product"
                    p_price = float(ci.price or (prod.price if prod else 0.0))
                    p_qty = int(ci.quantity or 1)
                    p_rest_id = prod.restaurantId if prod else None
                    if p_rest_id:
                        is_restaurant = True
                        target_restaurant_id = p_rest_id
                    items_to_create.append({
                        "productId": p_id,
                        "name": p_name,
                        "price": p_price,
                        "quantity": p_qty,
                        "imageUrl": prod.imageUrl if prod else None,
                        "selectedVariant": ci.selectedVariant,
                    })

        # If still empty (e.g. cart cleared or instant buy), fallback to reconciled item
        if not items_to_create:
            items_to_create.append({
                "productId": None,
                "name": "Online Paid Order (Cashfree Reconciled)",
                "price": order_amount,
                "quantity": 1,
                "imageUrl": None,
                "selectedVariant": None,
            })

        # If restaurant item, find restaurant name
        if is_restaurant and target_restaurant_id:
            r_stmt = select(Restaurant).where(Restaurant.id == target_restaurant_id)
            r_res = await db.execute(r_stmt)
            r_obj = r_res.scalars().first()
            if r_obj:
                target_shop_name = r_obj.name
        elif not is_restaurant and target_restaurant_id:
            target_shop_name = "Restaurant"

        # 6. Allocate Next Order Readable ID Sequence
        order_suffix = "-R" if is_restaurant else "-G"
        try:
            seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')"))
            next_seq = seq_res.scalar()
            readable_id = f"{next_seq}{order_suffix}"
        except Exception:
            readable_id = f"FK-{int(time.time() * 1000) % 1000000:06d}{order_suffix}"
        new_order_id = f"ord_{uuid.uuid4().hex[:20]}"

        calculated_subtotal = sum(it["price"] * it["quantity"] for it in items_to_create)
        misc_fee = max(0.0, round(order_amount - calculated_subtotal, 2)) if order_amount > calculated_subtotal else 0.0

        order_notes = f"[CF_ORDER:{cf_order_id}] | Cashfree PG Paid (Ref: {cf_ref}) | Auto-Reconciled from Webhook"

        # 7. Create Order Row
        order = Order(
            id=new_order_id,
            readableId=readable_id,
            userId=user_id,
            addressId=address.id,
            combinedId=None,
            cfOrderId=cf_order_id,
            restaurantId=target_restaurant_id if is_restaurant else None,
            orderType=OrderType.RESTAURANT if is_restaurant else OrderType.GROCERY,
            status=OrderStatus.CONFIRMED,
            subtotal=calculated_subtotal if calculated_subtotal > 0 else order_amount,
            discount=0.0,
            deliveryFee=0.0,
            taxes=0.0,
            miscFee=misc_fee,
            total=order_amount,
            paymentMethod=PaymentMethod.UPI,
            paymentStatus=PaymentStatus.PAID,
            estimatedDelivery=datetime.utcnow() + timedelta(minutes=25),
            deliveryLat=address.lat,
            deliveryLng=address.lng,
            deliveryMethod=recovered_delivery_method,
            isB2B=False,
            shopName=target_shop_name,
            shopPhone="+918112849854",
            storeId=recovered_store_id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            confirmedAt=datetime.utcnow(),
            notes=order_notes,
            refundAmount=0.0
        )
        db.add(order)
        await db.flush()

        # 8. Create Order Items
        for it in items_to_create:
            oi_id = f"oi_{uuid.uuid4().hex[:20]}"
            oi = OrderItem(
                id=oi_id,
                orderId=new_order_id,
                productId=it["productId"],
                name=it["name"],
                price=it["price"],
                quantity=it["quantity"],
                imageUrl=it.get("imageUrl"),
                selectedVariant=it.get("selectedVariant"),
                costPrice=0.0,
                variants=None,
                notes=None,
                refundAmount=0.0,
                isRefunded=False
            )
            db.add(oi)

        # 9. Clear user's cart if used
        if user:
            cart_stmt = select(Cart).where(Cart.userId == user.id)
            cart_res = await db.execute(cart_stmt)
            cart = cart_res.scalars().first()
            if cart:
                await db.execute(text("DELETE FROM cart_items WHERE \"cartId\" = :cart_id"), {"cart_id": cart.id})

        # 10. Enqueue Kitchen KOT for printing
        if is_restaurant and target_restaurant_id:
            try:
                kot_items = [
                    {"name": it["name"], "quantity": it["quantity"], "restaurantId": target_restaurant_id, "isRestaurantItem": True}
                    for it in items_to_create
                ]
                kot_text = (
                    "======================================\n"
                    "            FASTKIRANA KOT\n"
                    "======================================\n"
                    f"TOKEN : #{readable_id} | {customer_name}\n"
                    f"TYPE  : {recovered_delivery_method}\n"
                    f"Print : {datetime.now().strftime('%d %b %Y %I:%M %p')}\n"
                    "--------------------------------------\n"
                    "QTY   ITEM\n"
                    "--------------------------------------\n"
                    + "\n".join([f"{it['quantity']}  x  {it['name']}" for it in items_to_create]) + "\n"
                    "--------------------------------------\n"
                    "      *** FASTKIRANA KITCHEN ***\n"
                    "======================================"
                )
                kot_payload = {
                    "orderId": new_order_id,
                    "readableId": readable_id,
                    "restaurantId": target_restaurant_id,
                    "kotText": kot_text,
                    "items": kot_items,
                    "notes": order_notes,
                    "customerName": customer_name,
                    "deliveryMethod": recovered_delivery_method,
                    "shopName": target_shop_name,
                    "printedAt": datetime.utcnow().isoformat(),
                    "manual": True,
                    "source": "webhook_auto_recovery",
                    "timestamp": int(time.time() * 1000)
                }
                kot_insert = text(
                    "INSERT INTO kitchen_kot_queue (order_id, readable_id, restaurant_id, payload, status, created_at, attempts) "
                    "VALUES (:oid, :rid, :rest_id, CAST(:payload AS jsonb), 'PENDING', NOW(), 0)"
                )
                await db.execute(kot_insert, {
                    "oid": new_order_id,
                    "rid": readable_id,
                    "rest_id": target_restaurant_id,
                    "payload": json.dumps(kot_payload)
                })
            except Exception as kot_err:
                logger.warning(f"[Auto-Recovery] KOT enqueue error: {kot_err}")

        if cons_rec:
            cons_rec.status = "COMPLETED"
            cons_rec.orderId = order.id
            cons_rec.userId = user_id

        await db.commit()
        logger.info(f"🎉 [Auto-Recovery SUCCESS] Reconstructed and placed Order #{readable_id} for {customer_name} (₹{order_amount})!")

        # 11. Async Alerts: WhatsApp & FCM & WebSockets
        try:
            from routers.orders import send_whatsapp_alert
            admin_msg = (
                f"🚨 *AUTO-RECONCILED ONLINE ORDER* #{readable_id}\n"
                f"Customer: {customer_name} ({clean_phone})\n"
                f"Total: ₹{order_amount:.0f} (PAID via Cashfree)\n"
                f"Client dropped before sync — Order recovered and dispatched automatically! ✅"
            )
            for ap in ["7054470303", "8112849854"]:
                asyncio.create_task(send_whatsapp_alert(ap, admin_msg, readable_id))
        except Exception as wa_e:
            logger.warning(f"[Auto-Recovery] WhatsApp alert failed: {wa_e}")

        # FCM to Restaurant
        if target_restaurant_id:
            try:
                from utils.firebase import send_fcm_topic_notification
                asyncio.create_task(send_fcm_topic_notification(
                    topic=f"restaurant_{target_restaurant_id}",
                    title=f"🔔 NEW ORDER: #{readable_id} (₹{order_amount:.0f})",
                    body=f"Auto-Reconciled: {', '.join([it['name'] for it in items_to_create])} - {customer_name}",
                    data={"orderId": new_order_id, "readableId": readable_id, "restaurantId": target_restaurant_id, "status": "CONFIRMED"}
                ))
            except Exception as fcm_e:
                logger.warning(f"[Auto-Recovery] FCM topic alert failed: {fcm_e}")

        return order

    except Exception as exc:
        logger.error(f"❌ [Auto-Recovery FATAL] Could not auto-recover Cashfree order {cf_order_id}: {exc}", exc_info=True)
        await db.rollback()
        try:
            from routers.orders import send_whatsapp_alert
            err_msg = f"⚠️ *CRITICAL: UNRECONCILED CASHFREE PAYMENT!*\nOrder Ref: {cf_order_id}\nPayment Ref: {cf_ref}\nPlease check Cashfree dashboard immediately!"
            for ap in ["7054470303", "8112849854"]:
                asyncio.create_task(send_whatsapp_alert(ap, err_msg, cf_order_id))
        except Exception:
            pass
        return None


@router.get("/payment/cashfree/webhook")
@router.get("/payments/cashfree/webhook")
async def cashfree_webhook_status():
    """
    Cashfree webhook health check/status endpoint.
    """
    return {"status": "active", "message": "Cashfree Webhook Endpoint Active"}


@router.post("/payment/cashfree/webhook")
@router.post("/payments/cashfree/webhook")
async def cashfree_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Webhook endpoint to receive Cashfree server-to-server transaction notifications.
    Handles PAYMENT_SUCCESS, PAYMENT_FAILED, and USER_DROPPED with full deduplication,
    FCM sound alerts to kitchen & store, WhatsApp notifications, and WebSocket broadcasts.
    """
    try:
        raw_body = await request.body()
        payload = json.loads(raw_body) if raw_body else {}
    except Exception:
        return Response(status_code=400, content="Invalid JSON")

    # Verify Cashfree webhook signature if secret configured (Fail Closed)
    webhook_secret = os.environ.get("CASHFREE_WEBHOOK_SECRET") or settings.CASHFREE_SECRET_KEY or ""
    if webhook_secret:
        signature = request.headers.get("x-webhook-signature", "")
        timestamp = request.headers.get("x-webhook-timestamp", "")
        if not signature or not timestamp:
            logger.warning("[Cashfree Webhook] Missing x-webhook-signature or x-webhook-timestamp headers")
            return Response(status_code=401, content="Missing webhook signature headers")

        import hmac, hashlib, base64
        sign_payload = timestamp + raw_body.decode("utf-8")
        digest = hmac.new(
            webhook_secret.encode("utf-8"),
            sign_payload.encode("utf-8"),
            hashlib.sha256
        ).digest()
        expected_b64 = base64.b64encode(digest).decode("utf-8")
        expected_hex = digest.hex()
        if not (hmac.compare_digest(expected_b64, signature) or hmac.compare_digest(expected_hex, signature)):
            logger.warning("[Cashfree Webhook] Invalid webhook signature received")
            return Response(status_code=401, content="Invalid webhook signature")

    event_type = payload.get("type", "")
    data = payload.get("data", {})
    order_data = data.get("order", {})
    payment_data = data.get("payment", {})

    cf_order_id = order_data.get("order_id")
    payment_status = payment_data.get("payment_status")

    if not cf_order_id:
        return Response(status_code=200, content="OK")

    clean_id = re.sub(r"_r\d+$", "", str(cf_order_id).strip())

    # ── 1. PAYMENT SUCCESS FLOW ──────────────────────────────────────────
    if event_type == "PAYMENT_SUCCESS_WEBHOOK" or payment_status == "SUCCESS":
        cf_ref = payment_data.get("cf_payment_id") or cf_order_id

        stmt = select(Order).options(
            selectinload(Order.address),
            selectinload(Order.user)
        ).where(
            (Order.id == clean_id) | 
            (Order.readableId == clean_id) | 
            (Order.id == cf_order_id) |
            (Order.cfOrderId == cf_order_id) |
            (Order.cfOrderId == clean_id)
        )
        res = await db.execute(stmt)
        order = res.scalars().first()

        if not order:
            logger.info(f"[Cashfree Webhook] Order #{cf_order_id} not found in DB! Triggering resilient auto-recovery...")
            order = await auto_recover_unplaced_cashfree_order(
                cf_order_id=str(cf_order_id),
                clean_id=clean_id,
                cf_ref=str(cf_ref),
                order_data=order_data,
                payment_data=payment_data,
                db=db
            )

        if order and order.paymentStatus != PaymentStatus.PAID:
            # Payment amount verification
            cf_amount = None
            try:
                if order_data.get("order_amount") is not None:
                    cf_amount = float(order_data.get("order_amount"))
                elif payment_data.get("payment_amount") is not None:
                    cf_amount = float(payment_data.get("payment_amount"))
            except (ValueError, TypeError):
                pass

            expected_total = float(order.total or 0.0)
            if order.combinedId:
                comb_check = await db.execute(select(func.sum(Order.total)).where(Order.combinedId == order.combinedId))
                sum_comb = comb_check.scalar()
                if sum_comb:
                    expected_total = float(sum_comb)

            if cf_amount is None or expected_total <= 0:
                logger.error(f"[Cashfree Webhook] Amount missing or invalid total (cf_amount={cf_amount}, expected={expected_total}). Rejecting.")
                return Response(status_code=400, content="Invalid or missing payment amount")

            if abs(cf_amount - expected_total) > 0.05:
                logger.error(
                    f"[Cashfree Webhook] Amount mismatch: Gateway ₹{cf_amount:.2f} != Expected ₹{expected_total:.2f}. Rejecting payment."
                )
                return Response(status_code=400, content="Payment amount mismatch")

            was_cod = (order.paymentMethod == PaymentMethod.COD)
            order.paymentStatus = PaymentStatus.PAID
            order.paymentMethod = PaymentMethod.UPI
            cf_note = f"Cashfree PG Paid (Ref: {cf_ref})"
            if not order.notes or "Cashfree PG Paid" not in order.notes:
                order.notes = f"{order.notes} | {cf_note}" if order.notes else cf_note

            if order.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                order.status = OrderStatus.CONFIRMED
                if not order.confirmedAt:
                    order.confirmedAt = datetime.utcnow()

            comb_orders = []
            if order.combinedId:
                comb_stmt = select(Order).options(
                    selectinload(Order.address),
                    selectinload(Order.user)
                ).where(Order.combinedId == order.combinedId)
                comb_res = await db.execute(comb_stmt)
                comb_orders = comb_res.scalars().all()
                for co in comb_orders:
                    co.paymentStatus = PaymentStatus.PAID
                    co.paymentMethod = PaymentMethod.UPI
                    if not co.notes or "Cashfree PG Paid" not in co.notes:
                        co.notes = f"{co.notes} | {cf_note}" if co.notes else cf_note
                    if co.status in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                        co.status = OrderStatus.CONFIRMED
                        if not co.confirmedAt:
                            co.confirmedAt = datetime.utcnow()

            # ── DISTRIBUTED ATOMIC DEDUPLICATION GUARD: Ensure alerts are sent EXACTLY ONCE ──
            order_key = str(order.combinedId or order.id)
            now_ts = time.time()
            already_notified = False

            if order.notes and "[CF_PAID_ALERT_SENT]" in order.notes:
                already_notified = True
            elif any(co.notes and "[CF_PAID_ALERT_SENT]" in co.notes for co in comb_orders):
                already_notified = True
            elif order_key in _alerted_orders_cache and (now_ts - _alerted_orders_cache[order_key]) < 600:
                already_notified = True
            else:
                try:
                    from utils.cache import acquire_lock
                    lock_acquired = await acquire_lock(f"lock:cf:paid_notif:{order_key}", ttl_seconds=3600)
                    if not lock_acquired:
                        already_notified = True
                except Exception as e:
                    logger.warning(f"[Cashfree] Webhook distributed lock check failed: {e}")

            if not already_notified:
                _alerted_orders_cache[order_key] = now_ts
                order.notes = f"{order.notes} [CF_PAID_ALERT_SENT]" if order.notes else "[CF_PAID_ALERT_SENT]"
                for co in comb_orders:
                    co.notes = f"{co.notes} [CF_PAID_ALERT_SENT]" if co.notes else "[CF_PAID_ALERT_SENT]"

            await db.commit()

            # Safely set payment confirmation cache ONLY AFTER order is committed and amount verified
            try:
                from utils.cache import set_cache
                paid_payload = {"paid": True, "paymentId": str(cf_ref), "amount": cf_amount, "currency": "INR"}
                await set_cache(f"cf_paid:{clean_id}", paid_payload, ttl_seconds=3600)
                if str(cf_order_id) != clean_id:
                    await set_cache(f"cf_paid:{cf_order_id}", paid_payload, ttl_seconds=3600)
            except Exception as e:
                logger.warning(f"[Cashfree Webhook] Redis caching failed: {e}")

            # ── Realtime Broadcast & Multi-Channel Notifications ──────────────────
            if not already_notified:
                import asyncio
                target_orders = comb_orders if comb_orders else [order]

                # 1. FCM Push to Darkstore & Restaurant Kitchen
                try:
                    from routers.orders import dispatch_isolated_order_fcm_notifications
                    for o in target_orders:
                        asyncio.create_task(
                            dispatch_isolated_order_fcm_notifications(
                                o.id,
                                o.readableId,
                                o.restaurantId,
                                o.shopName,
                                float(o.total or 0),
                                "CONFIRMED",
                                o.storeId
                            )
                        )
                except Exception as fcm_err:
                    logger.warning(f"[Cashfree Webhook] FCM dispatch notice: {fcm_err}")

                # 2. WhatsApp Notification
                try:
                    from routers.orders import send_whatsapp_alert
                    if comb_orders:
                        combined_total = sum(float(co.total or 0) for co in comb_orders)
                        base_id = str(order.readableId or "").split("-")[0] or order.id[:6].upper()
                        outlets = " + ".join(dict.fromkeys(co.shopName for co in comb_orders if co.shopName)) or "Combined Order"
                        admin_text = f"💳 *PAID Online Order (Cashfree)* #{base_id} [{outlets}] Total: ₹{combined_total:.0f}. Payment: PAID ✅"
                    else:
                        admin_text = f"💳 *PAID Online Order (Cashfree)* #{order.readableId or order.id[:6].upper()} of ₹{float(order.total or 0):.0f}. Payment: PAID ✅"

                    if was_cod:
                        admin_text = f"⚠️ *LATE PAYMENT RECONCILED* (Cashfree) #{order.readableId or order.id[:6].upper()} of ₹{float(order.total or 0):.0f}. Paid Online ✅. DO NOT COLLECT CASH!"

                    dedupe_ref = order.readableId or order.id
                    for admin_phone in ["7054470303", "8112849854"]:
                        asyncio.create_task(send_whatsapp_alert(admin_phone, admin_text, dedupe_ref))
                except Exception as wa_err:
                    logger.warning(f"[Cashfree Webhook] WhatsApp notification error: {wa_err}")

                # 3. Live WebSocket Event Broadcast to Customer & Dashboard
                try:
                    from routers.websockets import manager
                    for o in target_orders:
                        clean_oid = str(o.readableId or o.id).strip().lstrip("#")
                        asyncio.create_task(manager.broadcast_to_channel(f"order_{clean_oid}", {
                            "event": "PAYMENT_CONFIRMED",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "status": "CONFIRMED",
                            "paymentStatus": "PAID"
                        }))
                except Exception as ws_err:
                    logger.warning(f"[Cashfree Webhook] WebSocket broadcast notice: {ws_err}")

    # ── 2. PAYMENT FAILED / DROPPED FLOW ─────────────────────────────────
    elif (
        event_type in ["PAYMENT_FAILED_WEBHOOK", "PAYMENT_USER_DROPPED_WEBHOOK"] or
        payment_status in ["FAILED", "USER_DROPPED"]
    ):
        stmt = select(Order).where(
            (Order.id == clean_id) | 
            (Order.readableId == clean_id) | 
            (Order.id == cf_order_id)
        )
        res = await db.execute(stmt)
        order = res.scalars().first()
        if order and order.paymentStatus != PaymentStatus.PAID and order.paymentMethod != PaymentMethod.COD:
            order.paymentStatus = PaymentStatus.FAILED
            await db.commit()
            logger.info(f"[Cashfree Webhook] Marked order #{order.readableId or order.id} as PAYMENT_FAILED")

    return Response(status_code=200, content="OK")

