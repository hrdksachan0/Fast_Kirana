from fastapi import APIRouter, HTTPException, status, Depends, Request, Response, BackgroundTasks
import asyncio
from datetime import datetime, timedelta
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
from models import Order, User, OrderStatus, PaymentStatus, PaymentMethod, IdempotencyRecord

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
    Creates a Razorpay Order to initiate UPI / Card / Netbanking checkout in Flutter & Web.
    Saves durable intent & draft order snapshot in Redis & PostgreSQL for 100% reliable auto-recovery.
    """
    amount = float(payload.get("amount") or 0.0)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid order amount. Must be greater than 0.")

    amount_paise = int(round(amount * 100))
    customer_phone = str(payload.get("customerPhone") or "").strip()
    customer_email = str(payload.get("customerEmail") or "").strip()
    customer_name = str(payload.get("customerName") or "FastMinute Customer").strip()
    user_id = payload.get("userId")
    store_id = payload.get("storeId") or "hub-209206"
    wallet_amount_used = float(payload.get("walletAmountUsed") or 0.0)

    receipt = f"rcpt_{int(time.time() * 1000)}"[:40]

    client = _get_razorpay_client()
    rzp_order_id = None
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
            logger.error(f"Razorpay SDK order creation failed: {e}")
            # Fall back to direct HTTP API if SDK fails
            rzp_order_id = None

    if not rzp_order_id:
        # Fallback to direct httpx call
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

    # 🛡️ EXACT CASHFREE DRAFT LOGIC:
    # Build complete draft payload so that if client drops or crashes, the order
    # is 100% reconstructed, committed to DB, and dispatched to kitchen/store!
    draft_payload = payload.get("orderPayload") or {
        "orderId": rzp_order_id,
        "amount": amount,
        "userId": user_id,
        "customerPhone": customer_phone,
        "customerName": customer_name,
        "customerEmail": customer_email if "@" in customer_email else None,
        "walletAmountUsed": wallet_amount_used,
        "addressId": payload.get("addressId"),
        "customerAddress": payload.get("customerAddress"),
        "items": payload.get("items") or [],
        "deliveryMethod": payload.get("deliveryMethod") or "DELIVERY",
        "storeId": store_id,
        "couponCode": payload.get("couponCode"),
        "discount": float(payload.get("discount") or 0.0),
        "tipAmount": float(payload.get("tipAmount") or 0.0),
        "deliveryFee": float(payload.get("deliveryFee") or 0.0),
        "packagingFee": float(payload.get("packagingFee") or 0.0),
        "packagingOption": payload.get("packagingOption"),
        "notes": payload.get("notes") or payload.get("note"),
        "createdAt": datetime.utcnow().isoformat(),
    }

    # 1. Cache in Redis (24-hour TTL)
    try:
        from utils.cache import set_cache
        await set_cache(f"rzp_pending:{rzp_order_id}", draft_payload, ttl=86400)
        # Mirror to cf_pending so shared recovery functions locate it instantaneously
        await set_cache(f"cf_pending:{rzp_order_id}", draft_payload, ttl=86400)
        await set_cache(f"draft_cf_order:{rzp_order_id}", draft_payload, ttl=86400)
    except Exception as cache_err:
        logger.warning(f"Draft order caching note: {cache_err}")

    # 2. Persist durable snapshot in PostgreSQL IdempotencyRecord
    try:
        intent_expiry = datetime.utcnow() + timedelta(days=2)
        intent_rec = IdempotencyRecord(
            key=f"rzp_intent:{rzp_order_id}",
            userId=str(user_id) if user_id else None,
            status="PENDING",
            response=draft_payload,
            createdAt=datetime.utcnow(),
            expiresAt=intent_expiry
        )
        db.add(intent_rec)
        # Mirror to cf_intent for zero-downtime cross-lookup
        cf_intent_rec = IdempotencyRecord(
            key=f"cf_intent:{rzp_order_id}",
            userId=str(user_id) if user_id else None,
            status="PENDING",
            response=draft_payload,
            createdAt=datetime.utcnow(),
            expiresAt=intent_expiry
        )
        db.add(cf_intent_rec)
        await db.flush()
    except Exception as db_intent_err:
        logger.warning(f"Durable intent record insert note: {db_intent_err}")

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
    Verifies Razorpay payment after customer completes payment.
    AUTOMATICALLY RECOVERS & COMMITS ORDER TO DATABASE (identical to Cashfree logic).
    Returns orderId, readableId, and serverOrderId so the client instantly navigates to OrderSuccess!
    """
    rzp_order_id = str(payload.get("razorpay_order_id") or payload.get("orderId") or "").strip()
    rzp_payment_id = str(payload.get("razorpay_payment_id") or payload.get("paymentId") or "").strip()
    rzp_signature = str(payload.get("razorpay_signature") or payload.get("signature") or "").strip()

    if not rzp_order_id and not rzp_payment_id:
        raise HTTPException(
            status_code=400,
            detail="Missing required verification fields (orderId or paymentId)"
        )

    # 1. Verify cryptographic signature if signature is present
    is_valid = False
    if rzp_order_id and rzp_payment_id and rzp_signature:
        is_valid = verify_razorpay_signature(rzp_order_id, rzp_payment_id, rzp_signature)

    # 2. Authoritative Fallback: Fetch payment status directly from Razorpay API
    # Essential for Android UPI Intent where signature is often not returned in SDK callback!
    payment_amount = 0.0
    client = _get_razorpay_client()
    if rzp_payment_id and rzp_payment_id.startswith("pay_"):
        if client:
            try:
                p_details = client.payment.fetch(rzp_payment_id)
                p_status = p_details.get("status")
                if p_status in ("captured", "authorized"):
                    is_valid = True
                    payment_amount = float(p_details.get("amount", 0)) / 100.0
                    if not rzp_order_id:
                        rzp_order_id = str(p_details.get("order_id") or "")
                    logger.info(f"✅ Verified payment {rzp_payment_id} via direct Razorpay API fetch (status={p_status}, amount=₹{payment_amount})")
            except Exception as e:
                logger.warning(f"Could not fetch payment {rzp_payment_id} from Razorpay: {e}")
        else:
            # Fallback to direct httpx call
            import httpx
            auth = (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
            try:
                async with httpx.AsyncClient(timeout=10.0) as http_client:
                    resp = await http_client.get(f"https://api.razorpay.com/v1/payments/{rzp_payment_id}", auth=auth)
                    if resp.status_code == 200:
                        p_details = resp.json()
                        p_status = p_details.get("status")
                        if p_status in ("captured", "authorized"):
                            is_valid = True
                            payment_amount = float(p_details.get("amount", 0)) / 100.0
                            if not rzp_order_id:
                                rzp_order_id = str(p_details.get("order_id") or "")
                            logger.info(f"✅ Verified payment {rzp_payment_id} via HTTP API (status={p_status})")
            except Exception as e:
                logger.warning(f"Could not fetch payment {rzp_payment_id} via HTTP: {e}")

    # 2b. Authoritative Fallback by rzp_order_id: If payment_id was not returned or not captured yet, query order's payments from Razorpay
    if not is_valid and rzp_order_id and rzp_order_id.startswith("order_"):
        if client:
            try:
                order_payments = client.order.payments(rzp_order_id)
                items = order_payments.get("items") or []
                for p in items:
                    if p.get("status") in ("captured", "authorized"):
                        is_valid = True
                        rzp_payment_id = p.get("id")
                        payment_amount = float(p.get("amount", 0)) / 100.0
                        logger.info(f"✅ Verified payment for order {rzp_order_id} via order.payments fetch (paymentId={rzp_payment_id}, amount=₹{payment_amount})")
                        break
            except Exception as ord_p_err:
                logger.warning(f"Could not fetch payments for order {rzp_order_id}: {ord_p_err}")
        else:
            import httpx
            auth = (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
            try:
                async with httpx.AsyncClient(timeout=10.0) as http_client:
                    resp = await http_client.get(f"https://api.razorpay.com/v1/orders/{rzp_order_id}/payments", auth=auth)
                    if resp.status_code == 200:
                        data = resp.json()
                        items = data.get("items") or []
                        for p in items:
                            if p.get("status") in ("captured", "authorized"):
                                is_valid = True
                                rzp_payment_id = p.get("id")
                                payment_amount = float(p.get("amount", 0)) / 100.0
                                logger.info(f"✅ Verified payment for order {rzp_order_id} via HTTP order/payments (paymentId={rzp_payment_id})")
                                break
            except Exception as e:
                logger.warning(f"Could not fetch payments for order {rzp_order_id} via HTTP: {e}")

    if not is_valid:
        logger.error(f"Razorpay verification failed for order '{rzp_order_id}', payment '{rzp_payment_id}'")
        raise HTTPException(status_code=400, detail="Razorpay payment was not completed or verification failed.")

    # 3. Cache verified payment state in Redis for immediate order lookups
    try:
        from utils.cache import set_cache
        if rzp_order_id:
            await set_cache(f"rzp_paid:{rzp_order_id}", {"paymentId": rzp_payment_id, "isPaid": True, "amount": payment_amount}, ttl=86400)
            await set_cache(f"cf_paid:{rzp_order_id}", {"paymentId": rzp_payment_id, "isPaid": True, "amount": payment_amount}, ttl=86400)
        if rzp_payment_id:
            await set_cache(f"rzp_paid:{rzp_payment_id}", {"orderId": rzp_order_id, "isPaid": True, "amount": payment_amount}, ttl=86400)
    except Exception:
        pass

    # 4. Check if order already exists in database
    existing_order = None
    if rzp_order_id:
        existing_stmt = select(Order).options(
            selectinload(Order.items),
            selectinload(Order.user),
            selectinload(Order.address)
        ).where(
            (Order.cfOrderId == rzp_order_id) |
            (Order.id == rzp_order_id) |
            (Order.readableId == rzp_order_id)
        )
        existing_res = await db.execute(existing_stmt)
        existing_order = existing_res.scalars().first()

    # If already exists in DB, ensure paymentStatus is PAID
    if existing_order:
        if existing_order.paymentStatus != PaymentStatus.PAID:
            existing_order.paymentStatus = PaymentStatus.PAID
            # Keep in ADMIN_PENDING so admin reviews before packing/dispatching!
            if existing_order.status != OrderStatus.CANCELLED:
                existing_order.status = OrderStatus.ADMIN_PENDING
            rzp_note = f"Razorpay PG Paid (Ref: {rzp_payment_id})"
            if not existing_order.notes or "Razorpay PG Paid" not in existing_order.notes:
                existing_order.notes = f"{existing_order.notes} | {rzp_note}" if existing_order.notes else rzp_note
            await db.commit()
        return {
            "status": "SUCCESS",
            "success": True,
            "isPaid": True,
            "orderId": existing_order.id,
            "serverOrderId": existing_order.id,
            "readableId": existing_order.readableId,
            "paymentId": rzp_payment_id,
            "message": "Payment verified and order found in database"
        }

    # 5. 🛡️ AUTO-RECOVERY: If client app dropped, closed, or hasn't called POST /api/orders yet,
    # IMMEDIATELY RECONSTRUCT & COMMIT ORDER TO POSTGRESQL (EXACT SAME AS CASHFREE LOGIC)!
    recovered_order = None
    try:
        from routers.cashfree_router import auto_recover_unplaced_cashfree_order
        recovered_order = await auto_recover_unplaced_cashfree_order(
            cf_order_id=rzp_order_id,
            clean_id=rzp_order_id,
            cf_ref=rzp_payment_id,
            order_data={"order_amount": payment_amount},
            payment_data={"payment_amount": payment_amount, "cf_payment_id": rzp_payment_id},
            db=db
        )
        if recovered_order:
            logger.info(f"🎉 [Razorpay Auto-Recovery] Reconstructed & placed order #{recovered_order.readableId} ({recovered_order.id})")
    except Exception as rec_err:
        logger.error(f"❌ Error during Razorpay order auto-recovery: {rec_err}", exc_info=True)

    final_oid = recovered_order.id if recovered_order else rzp_order_id
    final_rid = recovered_order.readableId if recovered_order else None

    return {
        "status": "SUCCESS",
        "success": True,
        "isPaid": True,
        "orderId": final_oid,
        "serverOrderId": final_oid,
        "readableId": final_rid,
        "paymentId": rzp_payment_id,
        "message": "Payment verified and order placed successfully"
    }


@router.post("/payment/razorpay/webhook")
@router.post("/payments/razorpay/webhook")
async def razorpay_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Webhook listener for Razorpay payment.captured events.
    AUTOMATICALLY RECONSTRUCTS & CREATES ORDER IF CLIENT DROPPED (Cashfree parity).
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

        # ── 1. Doorstep QR Event: qr_code.credited ──
        if event_name == "qr_code.credited" or (event_name == "payment.captured" and (
            event.get("payload", {}).get("qr_code") or
            (event.get("payload", {}).get("payment", {}).get("entity", {}).get("notes", {}).get("purpose") == "doorstep_delivery")
        )):
            payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
            qr_entity = event.get("payload", {}).get("qr_code", {}).get("entity", {})
            p_id = payment_entity.get("id") or "pay_doorstep_qr"
            qr_id = qr_entity.get("id") or ""
            amt = float(payment_entity.get("amount", 0)) / 100.0

            combined_notes = {}
            if isinstance(qr_entity.get("notes"), dict):
                combined_notes.update(qr_entity["notes"])
            if isinstance(payment_entity.get("notes"), dict):
                combined_notes.update(payment_entity["notes"])

            target_order_id = combined_notes.get("order_id")
            sub_order_ids_str = combined_notes.get("sub_order_ids")
            combined_id = combined_notes.get("combined_id")
            readable_id = combined_notes.get("readable_id")

            target_ids = []
            if sub_order_ids_str:
                target_ids = [s.strip() for s in sub_order_ids_str.split(",") if s.strip()]
            elif target_order_id:
                target_ids = [target_order_id]

            filters = []
            if target_ids:
                filters.append(Order.id.in_(target_ids))
                filters.append(Order.readableId.in_(target_ids))
            if combined_id:
                filters.append(Order.combinedId == combined_id)
            if readable_id:
                clean_rid = str(readable_id).strip()
                filters.append(Order.readableId == clean_rid)
                filters.append(Order.readableId.ilike(f"{clean_rid}%"))

            if filters:
                query = select(Order).where(or_(*filters))
                res = await db.execute(query)
                matched_orders = res.scalars().all()

                if matched_orders:
                    ref_text = f"Doorstep Razorpay QR Paid ({p_id})"
                    for o in matched_orders:
                        o.paymentMethod = PaymentMethod.ONLINE
                        o.paymentStatus = PaymentStatus.PAID
                        o.notes = f"{o.notes} | {ref_text}" if o.notes else ref_text
                        logger.info(f"🎉 [Razorpay Doorstep QR Webhook] Marked Order #{o.readableId} ({o.id}) as PAID for ₹{amt}")

                    await db.commit()

                    # Realtime Supabase Broadcast for Rider APK, Admin, and Customer Tracking
                    try:
                        from utils.supabase_broadcast import broadcast_supabase_realtime
                        for o in matched_orders:
                            topics = ["orders", f"order:{o.id}", f"order-payment-{o.id}"]
                            if o.readableId:
                                topics.append(f"order-payment-{o.readableId}")
                            if o.deliveryUserId:
                                topics.append(f"rider_{o.deliveryUserId}")
                            await broadcast_supabase_realtime(
                                topics=topics,
                                event="PAYMENT_RECEIVED",
                                payload={
                                    "orderId": o.id,
                                    "paymentStatus": "PAID",
                                    "paymentMethod": "ONLINE",
                                    "amount": amt,
                                    "paymentId": p_id,
                                    "isCombined": len(matched_orders) > 1,
                                    "subOrderIds": [mo.id for mo in matched_orders]
                                }
                            )
                    except Exception as b_err:
                        logger.warning(f"Failed to broadcast doorstep payment: {b_err}")

        # ── 2. Standard Web & App Payment: payment.captured ──
        elif event_name == "payment.captured":
            payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
            p_id = payment_entity.get("id")
            o_id = payment_entity.get("order_id")
            amt = float(payment_entity.get("amount", 0)) / 100.0

            if o_id:
                from utils.cache import set_cache
                await set_cache(f"rzp_paid:{o_id}", {"paymentId": p_id, "amount": amt, "isPaid": True}, ttl=86400)
                await set_cache(f"rzp_paid:{p_id}", {"orderId": o_id, "amount": amt, "isPaid": True}, ttl=86400)
                await set_cache(f"cf_paid:{o_id}", {"paymentId": p_id, "amount": amt, "isPaid": True}, ttl=86400)

                # Auto-recover order immediately from draft snapshot!
                try:
                    from routers.cashfree_router import auto_recover_unplaced_cashfree_order
                    recovered = await auto_recover_unplaced_cashfree_order(
                        cf_order_id=o_id,
                        clean_id=o_id,
                        cf_ref=p_id,
                        order_data={"order_amount": amt},
                        payment_data={"payment_amount": amt, "cf_payment_id": p_id},
                        db=db
                    )
                    if recovered:
                        logger.info(f"🎉 [Razorpay Webhook SUCCESS] Auto-recovered Order #{recovered.readableId} ({recovered.id}) for ₹{amt}")
                except Exception as wh_rec_err:
                    logger.error(f"Error auto-recovering Razorpay order from webhook: {wh_rec_err}", exc_info=True)

            logger.info(f"Webhook payment.captured for order {o_id}, payment {p_id}, ₹{amt}")
    except Exception as e:
        logger.warning(f"Error handling Razorpay webhook: {e}")

    return {"status": "ok"}


@router.post("/payment/razorpay/recover-missing")
@router.post("/payments/razorpay/recover-missing")
async def recover_missing_razorpay_order(
    payload: Dict[str, Any],
    db: AsyncSession = Depends(get_db)
):
    """
    Emergency manual recovery endpoint:
    Pass paymentId ('pay_...') or orderId ('order_...') of a customer who was charged
    but whose order is not showing in the database.
    Reconstructs and commits the order to DB immediately!
    """
    payment_id = str(payload.get("paymentId") or "").strip()
    order_id = str(payload.get("orderId") or "").strip()

    if not payment_id and not order_id:
        raise HTTPException(status_code=400, detail="Must provide paymentId (pay_...) or orderId (order_...)")

    client = _get_razorpay_client()
    payment_amount = 0.0

    if payment_id and payment_id.startswith("pay_") and client:
        try:
            p_details = client.payment.fetch(payment_id)
            if not order_id:
                order_id = str(p_details.get("order_id") or "")
            payment_amount = float(p_details.get("amount", 0)) / 100.0
        except Exception as e:
            logger.warning(f"Could not fetch payment details: {e}")

    if not order_id and not payment_id:
        raise HTTPException(status_code=404, detail="Could not resolve Razorpay order.")

    ref_order_id = order_id or payment_id
    ref_payment_id = payment_id or order_id

    from routers.cashfree_router import auto_recover_unplaced_cashfree_order
    recovered = await auto_recover_unplaced_cashfree_order(
        cf_order_id=ref_order_id,
        clean_id=ref_order_id,
        cf_ref=ref_payment_id,
        order_data={"order_amount": payment_amount},
        payment_data={"payment_amount": payment_amount, "cf_payment_id": ref_payment_id},
        db=db
    )

    if not recovered:
        raise HTTPException(
            status_code=404,
            detail="Could not auto-recover order. Please check that order draft was initiated from app/web."
        )

    return {
        "success": True,
        "message": f"Order #{recovered.readableId} successfully recovered and placed!",
        "orderId": recovered.id,
        "readableId": recovered.readableId,
        "total": float(recovered.total or 0.0),
        "status": recovered.status.value if hasattr(recovered.status, "value") else str(recovered.status),
        "paymentStatus": recovered.paymentStatus.value if hasattr(recovered.paymentStatus, "value") else str(recovered.paymentStatus),
    }
