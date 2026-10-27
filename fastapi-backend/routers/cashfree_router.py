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
import math
import os
import re
import time

from config import settings
from database import get_db
from models import (
    Order, User, Address, OrderStatus, PaymentStatus, PaymentMethod,
    OrderItem, OrderType, Cart, CartItem, Product, Restaurant, Coupon,
    StoreSetting
)
from utils.firebase import send_fcm_topic_notification

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Cashfree Payment Gateway"])

CASHFREE_BASE_URL = "https://api.cashfree.com/pg" if settings.CASHFREE_ENV.upper() == "PRODUCTION" else "https://sandbox.cashfree.com/pg"


def validate_positive_quantity(val: Any) -> Optional[int]:
    """Validates that a quantity is a positive finite integer. Returns int or None if invalid."""
    if val is None:
        return 1
    try:
        f_val = float(val)
        if not math.isfinite(f_val):
            return None
        i_val = int(f_val)
        if f_val != i_val or i_val <= 0 or i_val > 1000:
            return None
        return i_val
    except (ValueError, TypeError):
        return None


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
    couponCode: Optional[str] = None
    discount: Optional[float] = None
    tipAmount: Optional[float] = None
    deliveryFee: Optional[float] = None
    packagingFee: Optional[float] = None
    packagingOption: Optional[str] = None
    walletAmountUsed: Optional[float] = None
    walletAmount: Optional[float] = None


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
    store_id: Optional[str] = "hub-209206",
    validated_quote: Optional[Dict[str, Any]] = None
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
    if validated_quote:
        w_used = float(validated_quote.get("walletAmountUsed") or validated_quote.get("wallet_amount_used") or 0.0)
        pending_payload["validated_quote"] = validated_quote
        pending_payload["validatedQuote"] = validated_quote
        pending_payload["walletAmountUsed"] = w_used
        pending_payload["wallet_amount_used"] = w_used
        pending_payload["discount"] = float(validated_quote.get("discount", 0.0))
        pending_payload["couponCode"] = validated_quote.get("couponCode")
        pending_payload["deliveryFee"] = float(validated_quote.get("deliveryFee", 0.0))
        pending_payload["packagingFee"] = float(validated_quote.get("packagingFee", 0.0))
        pending_payload["tipAmount"] = float(validated_quote.get("tipAmount", 0.0))
        pending_payload["subtotal"] = float(validated_quote.get("subtotal", 0.0))
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
    order = None
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

    authoritative_items_subtotal = 0.0
    has_items_validated = False
    canonical_accepted_lines = []
    if effective_items and isinstance(effective_items, list) and not (req.orderId and order):
        candidate_pids = set()
        for it in effective_items:
            prod_info = it.get("product") or it
            pid = str(it.get("productId") or prod_info.get("id") or "").strip()
            if pid:
                candidate_pids.add(pid)
                if "_" in pid:
                    parts = pid.split("_")
                    for i in range(1, len(parts)):
                        candidate_pids.add("_".join(parts[:i]))

        db_p_map = {}
        if candidate_pids:
            p_stmt = select(Product).where(Product.id.in_(list(candidate_pids)))
            p_res = await db.execute(p_stmt)
            for p in p_res.scalars().all():
                db_p_map[p.id] = p

        for it in effective_items:
            prod_info = it.get("product") or it
            p_id = str(it.get("productId") or prod_info.get("id") or "").strip()
            p_qty = validate_positive_quantity(it.get("quantity"))
            if p_qty is None:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid item quantity '{it.get('quantity')}'. Quantity must be a positive integer."
                )
            sel_var = it.get("selectedVariant") or prod_info.get("selectedVariant")
            db_p = db_p_map.get(p_id)
            if not db_p and "_" in p_id:
                matching_candidates = []
                parts = p_id.split("_")
                for i in range(len(parts) - 1, 0, -1):
                    cand_base = "_".join(parts[:i])
                    cand_var = "_".join(parts[i:])
                    cand_prod = db_p_map.get(cand_base)
                    if not cand_prod:
                        continue

                    if sel_var and str(sel_var).strip().lower() != cand_var.strip().lower():
                        continue

                    target_v_str = str(sel_var or cand_var).strip().lower()
                    has_var = False
                    if cand_prod.variants and isinstance(cand_prod.variants, list):
                        has_var = any(
                            isinstance(v, dict) and str(v.get("name", "")).strip().lower() == target_v_str
                            for v in cand_prod.variants
                        )

                    if has_var or (not cand_prod.variants and (cand_var == getattr(cand_prod, "unit", None) or not sel_var)):
                        matching_candidates.append((cand_prod, cand_var))

                if len(matching_candidates) == 1:
                    db_p, inferred_var = matching_candidates[0]
                    if not sel_var:
                        sel_var = inferred_var
                elif len(matching_candidates) > 1:
                    exact_var_candidates = [
                        (p, v) for p, v in matching_candidates
                        if p.variants and any(
                            isinstance(var, dict) and str(var.get("name", "")).strip() == (sel_var or v).strip()
                            for var in p.variants
                        )
                    ]
                    if len(exact_var_candidates) == 1:
                        db_p, inferred_var = exact_var_candidates[0]
                        if not sel_var:
                            sel_var = inferred_var
                    else:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Ambiguous encoded product ID '{p_id}' resolves to multiple catalog products."
                        )
                else:
                    if sel_var and p_id.endswith(f"_{sel_var}"):
                        cand_base = p_id[:-len(f"_{sel_var}")]
                        if cand_base in db_p_map:
                            db_p = db_p_map[cand_base]
                    elif len(parts) >= 2:
                        cand_base = p_id.rsplit("_", 1)[0]
                        if cand_base in db_p_map:
                            db_p = db_p_map[cand_base]
                            if not sel_var:
                                sel_var = p_id[len(cand_base) + 1:]

            if not db_p:
                raise HTTPException(
                    status_code=400,
                    detail=f"Product '{p_id}' not found in catalog."
                )

            item_price = float(db_p.price or 0.0)
            if db_p.variants and isinstance(db_p.variants, list) and len(db_p.variants) > 0:
                valid_vars = [v for v in db_p.variants if isinstance(v, dict) and v.get("name")]
                if not sel_var or not str(sel_var).strip():
                    if valid_vars:
                        sel_var = str(valid_vars[0].get("name", "")).strip()
                    else:
                        sel_var = None

                v_match = None
                if sel_var:
                    v_match = next(
                        (v for v in db_p.variants if isinstance(v, dict) and str(v.get("name", "")).strip().lower() == str(sel_var).strip().lower()),
                        None
                    )

                if v_match and "price" in v_match:
                    item_price = float(v_match["price"])
                elif not v_match:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Variant '{sel_var}' not found for product '{db_p.name}' in catalog."
                    )
                if not db_p.restaurantId and v_match:
                    if int(v_match.get("stock", 0)) < p_qty:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Insufficient stock for \"{db_p.name} ({sel_var})\". Available: {v_match.get('stock', 0)}, requested: {p_qty}."
                        )
            else:
                if not db_p.restaurantId and (db_p.stock or 0) < p_qty:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Insufficient stock for \"{db_p.name}\". Available: {db_p.stock or 0}, requested: {p_qty}."
                    )
            authoritative_items_subtotal += item_price * p_qty
            canonical_accepted_lines.append({
                "productId": db_p.id,
                "name": db_p.name,
                "price": round(item_price, 2),
                "quantity": p_qty,
                "selectedVariant": sel_var,
                "imageUrl": db_p.imageUrl,
                "categoryId": db_p.categoryId,
                "restaurantId": db_p.restaurantId,
                "menuSection": getattr(db_p, "menuSection", None),
                "cartItemId": str(it.get("cartItemId") or it.get("id") or "").strip() or None,
            })
        has_items_validated = True

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
        elif req.amount is not None:
            total_amount = float(req.amount)
        else:
            raise HTTPException(status_code=404, detail="Order not found")
    elif req.amount is not None:
        total_amount = float(req.amount)
    elif has_items_validated and authoritative_items_subtotal > 0:
        total_amount = authoritative_items_subtotal
    else:
        raise HTTPException(status_code=400, detail="orderId or amount is required")

    # Enforce authoritative server catalog pricing and build validated quote
    validated_quote_dict = None
    if has_items_validated and authoritative_items_subtotal > 0:
        validated_discount = 0.0
        payload_dict = req.orderPayload or req.cartPayload or {}
        coupon_code = req.couponCode or payload_dict.get("couponCode") or payload_dict.get("coupon")
        delivery_method = req.deliveryMethod or payload_dict.get("deliveryMethod") or "DELIVERY"
        store_id = req.storeId or payload_dict.get("storeId") or "hub-209206"
        resolved_user_id = effective_user_id or (customer_id if customer_id != "guest_customer" else None)

        # Reject non-finite or negative fees
        for fee_name, fee_val in [
            ("deliveryFee", req.deliveryFee if req.deliveryFee is not None else payload_dict.get("deliveryFee")),
            ("packagingFee", req.packagingFee if req.packagingFee is not None else payload_dict.get("packagingFee")),
            ("tipAmount", req.tipAmount if req.tipAmount is not None else (payload_dict.get("tipAmount") or payload_dict.get("tip"))),
        ]:
            if fee_val is not None and str(fee_val).strip() != "":
                try:
                    f_num = float(fee_val)
                    if not math.isfinite(f_num) or f_num < 0:
                        raise HTTPException(status_code=400, detail=f"Invalid {fee_name}: must be a non-negative finite number")
                except (ValueError, TypeError):
                    raise HTTPException(status_code=400, detail=f"Invalid {fee_name}: must be a valid number")

        if delivery_method == "PICKUP":
            delivery_fee = 0.0
            misc_fee = 0.0
        else:
            # Authoritative server delivery fee
            delivery_fee = 0.0 if authoritative_items_subtotal >= 149.0 else 25.0

            # Authoritative packaging fee
            misc_fee = 15.0 if (req.packagingOption == "PREMIUM" or payload_dict.get("packagingOption") == "PREMIUM") else 5.0

        tip_amount = 0.0
        raw_tip = req.tipAmount if req.tipAmount is not None else (payload_dict.get("tipAmount") or payload_dict.get("tip"))
        if raw_tip is not None and str(raw_tip).strip() != "":
            try:
                parsed_tip = float(raw_tip)
                if math.isfinite(parsed_tip) and parsed_tip >= 0:
                    tip_amount = round(parsed_tip, 2)
            except (ValueError, TypeError):
                pass

        c_code_clean = None
        if coupon_code:
            c_code_clean = str(coupon_code).strip().upper()
            c_stmt = select(Coupon).where(Coupon.code == c_code_clean, Coupon.isActive == True)
            c_res = await db.execute(c_stmt)
            c_obj = c_res.scalars().first()
            if c_obj:
                has_expired = c_obj.expiresAt and c_obj.expiresAt < datetime.utcnow()
                limit_reached = c_obj.maxUses and c_obj.usedCount >= c_obj.maxUses
                if not has_expired and not limit_reached:
                    already_used = False
                    if c_obj.oncePerCustomer and resolved_user_id and not str(resolved_user_id).startswith("guest_"):
                        used_res = await db.execute(
                            select(Order.id).where(
                                Order.userId == resolved_user_id,
                                Order.couponCode == c_code_clean,
                                Order.status != OrderStatus.CANCELLED
                            ).limit(1)
                        )
                        if used_res.scalars().first():
                            already_used = True

                    if not already_used:
                        eligible_subtotal = 0.0
                        has_restrictions = bool(c_obj.categoryId or c_obj.restaurantId or c_obj.menuSection or c_obj.bogoDishId)

                        if has_restrictions:
                            lines_to_check = canonical_accepted_lines if canonical_accepted_lines else effective_items
                            for it in lines_to_check:
                                prod_info = it.get("product") or it
                                it_pid = str(it.get("productId") or prod_info.get("id") or "").strip()
                                p_obj = db_p_map.get(it_pid)
                                it_price = float(it.get("price") or (p_obj.price if p_obj else 0.0))
                                it_qty = validate_positive_quantity(it.get("quantity")) or 1
                                it_cat = it.get("categoryId") or getattr(p_obj, "categoryId", None)
                                it_rest = it.get("restaurantId") or getattr(p_obj, "restaurantId", None)
                                it_menu = it.get("menuSection") or getattr(p_obj, "menuSection", None)

                                it_matches = True
                                if c_obj.categoryId and it_cat != c_obj.categoryId:
                                    it_matches = False
                                if it_matches and c_obj.restaurantId and it_rest != c_obj.restaurantId:
                                    it_matches = False
                                if it_matches and c_obj.menuSection and str(it_menu or "").strip().lower() != c_obj.menuSection.strip().lower():
                                    it_matches = False
                                if it_matches and c_obj.bogoDishId and str(it_pid or "").split("_")[0].strip() != c_obj.bogoDishId.strip():
                                    it_matches = False

                                if it_matches:
                                    eligible_subtotal += it_price * it_qty
                        else:
                            eligible_subtotal = authoritative_items_subtotal

                        if eligible_subtotal > 0 and eligible_subtotal >= (c_obj.minOrder or 0.0):
                            if c_obj.discountType in ("PERCENT", "PERCENTAGE"):
                                disc = (eligible_subtotal * float(c_obj.value)) / 100.0
                                if c_obj.maxDiscount and c_obj.maxDiscount > 0:
                                    disc = min(disc, float(c_obj.maxDiscount))
                                validated_discount = round(min(disc, eligible_subtotal, authoritative_items_subtotal), 2)
                            elif c_obj.discountType == "FLAT":
                                validated_discount = round(min(float(c_obj.value), eligible_subtotal, authoritative_items_subtotal), 2)
                            elif c_obj.discountType == "FREE_DELIVERY":
                                delivery_fee = 0.0

        # Snapshot current cart item IDs to protect newer replacement cart rows from cleanup
        active_cart_item_ids = []
        if resolved_user_id and not str(resolved_user_id).startswith("guest_"):
            try:
                cart_res = await db.execute(select(Cart.id).where(Cart.userId == resolved_user_id))
                active_cart_id = cart_res.scalars().first()
                if active_cart_id:
                    ci_res = await db.execute(select(CartItem.id).where(CartItem.cartId == active_cart_id))
                    active_cart_item_ids = [str(r) for r in ci_res.scalars().all()]
            except Exception:
                pass

        expected_gross_total = max(0.0, round(authoritative_items_subtotal - validated_discount + (0.0 if delivery_method == "PICKUP" else delivery_fee) + tip_amount + (0.0 if delivery_method == "PICKUP" else misc_fee), 2))

        # Authoritative wallet deduction verification
        req_wallet_amount = (
            req.walletAmountUsed
            if req.walletAmountUsed is not None
            else (
                req.walletAmount
                if req.walletAmount is not None
                else (
                    payload_dict.get("walletAmountUsed")
                    or payload_dict.get("walletAmount")
                    or 0.0
                )
            )
        )
        validated_wallet_deduction = 0.0
        if req_wallet_amount and float(req_wallet_amount) > 0 and resolved_user_id and not str(resolved_user_id).startswith("guest_"):
            try:
                from routers.wallet import get_or_create_wallet
                cust_wallet = await get_or_create_wallet(resolved_user_id, db)
                real_cash = float(cust_wallet.balance or 0.0)
                promo_cash = float(cust_wallet.promoBalance or 0.0)
                settings_stmt = select(StoreSetting).where(StoreSetting.key == "referral_wallet_redeem_min_order_value")
                s_row = (await db.execute(settings_stmt)).scalars().first()
                min_wallet_mov = float(s_row.value if s_row else "99")
                can_use_promo = authoritative_items_subtotal >= min_wallet_mov
                wallet_usable = real_cash + (promo_cash if can_use_promo else 0.0)
                validated_wallet_deduction = round(min(float(req_wallet_amount), wallet_usable, expected_gross_total), 2)
            except Exception as w_err:
                logger.warning(f"Error validating wallet balance for user {resolved_user_id}: {w_err}")
                validated_wallet_deduction = 0.0

        expected_quote_total = max(1.0, round(expected_gross_total - validated_wallet_deduction, 2))
        if total_amount is not None and abs(float(total_amount) - expected_quote_total) <= 0.05:
            total_amount = expected_quote_total
        elif total_amount is not None and float(total_amount) < (expected_quote_total - 0.05):
            logger.warning(
                f"[Cashfree Security] Client attempted underpayment: client amount={total_amount} < expected_quote_total={expected_quote_total}. Overriding with server price."
            )
            total_amount = expected_quote_total
        elif total_amount is None:
            total_amount = expected_quote_total

        validated_quote_dict = {
            "subtotal": round(authoritative_items_subtotal, 2),
            "discount": round(validated_discount, 2),
            "couponCode": c_code_clean if (coupon_code and validated_discount > 0) else None,
            "deliveryFee": 0.0 if delivery_method == "PICKUP" else round(delivery_fee, 2),
            "packagingFee": 0.0 if delivery_method == "PICKUP" else round(misc_fee, 2),
            "tipAmount": round(tip_amount, 2),
            "total": round(total_amount, 2),
            "grossTotal": round(expected_gross_total, 2),
            "walletAmountUsed": round(validated_wallet_deduction, 2),
            "deliveryMethod": delivery_method,
            "storeId": store_id,
            "cartItemIds": active_cart_item_ids,
            "items": canonical_accepted_lines,
        }
    elif req.amount is not None and float(req.amount) > (total_amount or 0.0):
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
            items=canonical_accepted_lines if canonical_accepted_lines else effective_items,
            delivery_method=effective_delivery_method,
            store_id=effective_store_id,
            validated_quote=validated_quote_dict
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
                        store_id=effective_store_id,
                        validated_quote=validated_quote_dict
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
                    store_id=effective_store_id,
                    validated_quote=validated_quote_dict
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
            items=canonical_accepted_lines if canonical_accepted_lines else effective_items,
            delivery_method=effective_delivery_method,
            store_id=effective_store_id,
            validated_quote=validated_quote_dict
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
    prefix_id = clean_id.split("-")[0]

    # 1. FAST PATH: Check indexed primary keys and Cashfree order IDs in ~2ms!
    stmt = select(Order).where(
        (Order.id == clean_id) |
        (Order.readableId == clean_id) |
        (Order.id == raw_id) |
        (Order.cfOrderId == clean_id) |
        (Order.cfOrderId == raw_id) |
        (Order.readableId == f"{clean_id}-G") |
        (Order.readableId == f"{clean_id}-R") |
        (Order.readableId == f"{prefix_id}-G") |
        (Order.readableId == f"{prefix_id}-R")
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
            "readableId": order.readableId,
            "paymentStatus": "PAID",
            "isPaid": True,
            "cfPaymentId": f"CF_{order.cfOrderId or order.id}",
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

    async with httpx.AsyncClient(timeout=10.0) as client:
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

            # Auto-recover and insert order into DB immediately so customer order is never missed
            recovered_order = None
            try:
                cf_ref_val = str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}"
                recovered_order = await auto_recover_unplaced_cashfree_order(
                    cf_order_id=sanitized_check_id,
                    clean_id=clean_id,
                    cf_ref=cf_ref_val,
                    order_data=cf_order or {},
                    payment_data=successful_payment or {},
                    db=db
                )
            except Exception as rec_err:
                logger.error(f"[Cashfree Verify] Auto-recover on verify notice: {rec_err}")

            return {
                "success": True,
                "orderId": recovered_order.id if recovered_order else clean_id,
                "readableId": recovered_order.readableId if recovered_order else None,
                "paymentStatus": "PAID",
                "isPaid": True,
                "cfPaymentId": str(successful_payment.get("cf_payment_id", "")) if successful_payment else f"CF_{sanitized_check_id}",
                "orderAmount": cf_amount,
            }
        status_to_return = "USER_DROPPED"
        if cf_order:
            cf_st = cf_order.get("order_status", "ACTIVE")
            if cf_st == "EXPIRED":
                status_to_return = "EXPIRED"
            elif cf_st in ("CANCELLED", "TERMINATED"):
                status_to_return = "CANCELLED"
            elif 'payments' in locals() and any(p.get("payment_status") == "SUCCESS" for p in (payments or [])):
                status_to_return = "PAID"
            elif 'payments' in locals() and any(p.get("payment_status") == "PENDING" for p in (payments or [])):
                status_to_return = "PENDING"
            elif 'payments' in locals() and any(p.get("payment_status") in ("FAILED", "CANCELLED", "USER_DROPPED") for p in (payments or [])):
                status_to_return = "FAILED"
            elif not ('payments' in locals() and payments):
                # Customer closed or cancelled gateway without completing or submitting payment
                status_to_return = "USER_DROPPED"
            elif cf_st == "ACTIVE":
                status_to_return = "ACTIVE"

        is_terminally_not_paid = status_to_return in ("FAILED", "USER_DROPPED", "CANCELLED", "EXPIRED")
        return {
            "success": False,
            "orderId": clean_id,
            "paymentStatus": status_to_return,
            "isPaid": status_to_return == "PAID",
            "message": "Payment was cancelled or could not be completed." if is_terminally_not_paid else "Payment confirmation pending with your bank.",
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
        base_order_key = re.sub(r"_r\d+$", "", cf_order_key)
        if not getattr(order, "cfOrderId", None) and base_order_key:
            order.cfOrderId = base_order_key

        try:
            from models import IdempotencyRecord
            cons_rec = IdempotencyRecord(
                key=f"consumed_payment:{base_order_key}",
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
            order.status = OrderStatus.ADMIN_PENDING

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
                    co.status = OrderStatus.ADMIN_PENDING

        # Check if wallet deduction was part of this order and debit if not yet processed
        if "[WALLET_USED:" not in (order.notes or ""):
            try:
                from utils.cache import get_cache
                p_intent_verify = await get_cache(f"cf_pending:{clean_id}") or await get_cache(f"cf_pending:{sanitized_check_id}")
                if not p_intent_verify:
                    from models import IdempotencyRecord
                    v_stmt = select(IdempotencyRecord).where(
                        IdempotencyRecord.key.in_([f"cf_intent:{clean_id}", f"cf_intent:{sanitized_check_id}"])
                    )
                    v_rec = (await db.execute(v_stmt)).scalars().first()
                    if v_rec and isinstance(v_rec.response, dict):
                        p_intent_verify = v_rec.response
                w_used_verify = float(
                    (p_intent_verify.get("validated_quote") or p_intent_verify.get("validatedQuote") or {}).get("walletAmountUsed")
                    or (p_intent_verify.get("validated_quote") or p_intent_verify.get("validatedQuote") or {}).get("wallet_amount_used")
                    or p_intent_verify.get("walletAmountUsed")
                    or p_intent_verify.get("wallet_amount_used")
                    or 0.0
                ) if p_intent_verify and isinstance(p_intent_verify, dict) else 0.0
                if w_used_verify > 0 and order.userId and not str(order.userId).startswith("guest_"):
                    from routers.wallet import debit_customer_wallet
                    from decimal import Decimal
                    await debit_customer_wallet(
                        user_id=order.userId,
                        amount=Decimal(str(w_used_verify)),
                        description=f"Wallet deduction for Order #{order.readableId}",
                        db=db,
                        metadata={"walletDeduction": w_used_verify, "cfOrderId": sanitized_check_id},
                        allow_promo=True,
                    )
                    wallet_note = f"💳 Wallet Used: ₹{w_used_verify:.2f} | [WALLET_USED:{w_used_verify:.2f}]"
                    order.notes = f"{order.notes} | {wallet_note}" if order.notes else wallet_note
                    for co in comb_orders:
                        co.notes = f"{co.notes} | {wallet_note}" if co.notes else wallet_note
            except Exception as w_v_err:
                logger.warning(f"Error debiting wallet on verify for order #{order.readableId}: {w_v_err}")

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
                            "ADMIN_PENDING",
                            o.storeId,
                            "PAID"
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
                                "ADMIN_PENDING",
                                o.storeId,
                                "PAID"
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

            # WebSocket Broadcast to Admin Dashboards on general channel
            try:
                from routers.websockets import manager
                target_orders = comb_orders if comb_orders else [order]
                for o in target_orders:
                    clean_oid = str(o.readableId or o.id).strip().lstrip("#")
                    ws_payload = {
                        "event": "NEW_ORDER",
                        "type": "new-order",
                        "orderId": o.id,
                        "readableId": o.readableId,
                        "shopName": o.shopName,
                        "status": "ADMIN_PENDING",
                        "paymentStatus": "PAID",
                        "paymentMethod": "UPI",
                        "total": float(o.total or 0),
                        "createdAt": datetime.utcnow().isoformat(),
                        "restaurantId": o.restaurantId,
                        "storeId": o.storeId,
                        "isPaid": True,
                    }
                    if background_tasks:
                        background_tasks.add_task(manager.broadcast_to_channel, "general", ws_payload)
                        background_tasks.add_task(manager.broadcast_to_channel, f"order_{clean_oid}", {
                            "event": "PAYMENT_CONFIRMED",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "status": "ADMIN_PENDING",
                            "paymentStatus": "PAID"
                        })
                    else:
                        asyncio.create_task(manager.broadcast_to_channel("general", ws_payload))
                        asyncio.create_task(manager.broadcast_to_channel(f"order_{clean_oid}", {
                            "event": "PAYMENT_CONFIRMED",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "status": "ADMIN_PENDING",
                            "paymentStatus": "PAID"
                        }))
            except Exception as ws_err:
                logger.warning(f"Cashfree WebSocket broadcast error: {ws_err}")

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

        clean_cf_id = re.sub(r"[^a-zA-Z0-9_-]", "_", str(cf_order_id).strip())[:45]

        # 0. Check if order already recovered or created with this cfOrderId / clean_id
        # Authoritative lookup strictly uses explicit order fields — NEVER free-text notes
        base_cf_id = re.sub(r"_r\d+$", "", clean_cf_id)
        prefix_id = base_cf_id.split("-")[0]
        existing_stmt = select(Order).options(
            selectinload(Order.items),
            selectinload(Order.user),
            selectinload(Order.address)
        ).where(
            or_(
                Order.cfOrderId == cf_order_id,
                Order.cfOrderId == clean_cf_id,
                Order.cfOrderId == clean_id,
                Order.cfOrderId == base_cf_id,
                Order.id == clean_id,
                Order.id == base_cf_id,
                Order.readableId == clean_id,
                Order.readableId == base_cf_id,
                Order.readableId == f"{base_cf_id}-G",
                Order.readableId == f"{base_cf_id}-R",
                Order.readableId == f"{prefix_id}-G",
                Order.readableId == f"{prefix_id}-R",
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
                existing_order.cfOrderId = base_cf_id
            if existing_order.combinedId:
                comb_res = await db.execute(select(Order).where(Order.combinedId == existing_order.combinedId))
                for co in comb_res.scalars().all():
                    if not getattr(co, "cfOrderId", None):
                        co.cfOrderId = base_cf_id
            await db.commit()
            return existing_order

        # 0.5 Atomic payment fulfillment lock to prevent concurrent duplicate recovery across workers
        consumed_key = f"consumed_payment:{base_cf_id}"
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
        # 3a. Prefer the authenticated user who initiated this checkout intent
        authenticated_user_id = pending_data.get("userId") if pending_data and not str(pending_data.get("userId")).startswith("guest_") else None
        user = None
        if authenticated_user_id:
            u_stmt = select(User).where(User.id == authenticated_user_id)
            user = (await db.execute(u_stmt)).scalars().first()

        # 3b. Fallback to phone lookup (supporting 10-digit, +91, and suffix match)
        if not user:
            u_stmt = select(User).where(
                or_(
                    User.phone == clean_phone,
                    User.phone == f"+91{clean_phone}",
                    User.phone.endswith(clean_phone)
                )
            ).order_by(User.createdAt.asc())
            user = (await db.execute(u_stmt)).scalars().first()

        user_id = user.id if user else authenticated_user_id
        if not user_id:
            # Create user if missing
            user_id = f"usr_{uuid.uuid4().hex[:16]}"
            user = User(
                id=user_id,
                name=customer_name,
                email=f"{clean_phone}@fastkirana.in",
                phone=f"+91{clean_phone}",
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

        val_quote = (pending_data.get("validated_quote") or {}) if pending_data else {}
        recovered_discount = float(val_quote.get("discount") if "discount" in val_quote else (pending_data.get("discount") or 0.0)) if pending_data else 0.0
        recovered_coupon = str(val_quote.get("couponCode") or pending_data.get("couponCode") or "").strip() or None if pending_data else None
        recovered_delivery_fee = float(val_quote.get("deliveryFee") if "deliveryFee" in val_quote else (pending_data.get("deliveryFee") or 0.0)) if pending_data else 0.0
        recovered_packaging_fee = float(val_quote.get("packagingFee") if "packagingFee" in val_quote else (pending_data.get("packagingFee") or 0.0)) if pending_data else 0.0
        recovered_tip = float(val_quote.get("tipAmount") if "tipAmount" in val_quote else (pending_data.get("tipAmount") or 0.0)) if pending_data else 0.0

        has_underpaid_conflict = False
        has_stock_conflict = False
        has_missing_product = False
        has_invalid_quantity = False
        db_products = {}

        # Check pending cache items first
        cached_items = pending_data.get("items") if pending_data else None
        if cached_items and isinstance(cached_items, list):
            prod_ids = []
            for it in cached_items:
                raw_pid = str(it.get("productId") or (it.get("product") or {}).get("id") or "").strip()
                if raw_pid:
                    prod_ids.append(raw_pid)
                    if "_" in raw_pid:
                        prod_ids.append(raw_pid.split("_")[0])
            prod_ids = list(set(prod_ids))
            if prod_ids:
                p_res = await db.execute(select(Product).where(Product.id.in_(prod_ids)).with_for_update())
                for p in p_res.scalars().all():
                    db_products[p.id] = p

            from models import StoreInventory
            store_inv_map = {}
            if recovered_store_id and recovered_store_id != "all" and prod_ids:
                try:
                    inv_stmt = select(StoreInventory).where(
                        StoreInventory.storeId == recovered_store_id,
                        StoreInventory.productId.in_(prod_ids)
                    ).with_for_update()
                    inv_res = await db.execute(inv_stmt)
                    for inv in inv_res.scalars().all():
                        store_inv_map[inv.productId] = inv
                except Exception as e:
                    logger.warning(f"[Cashfree Recovery] Could not load StoreInventory: {e}")

            # Aggregate demand across lines:
            # 1. By productId (total units demanded of this product across all variants)
            # 2. By (productId, selectedVariant) (units demanded of this specific variant)
            aggregated_product_demand = {}
            aggregated_variant_demand = {}
            for it in cached_items:
                prod = it.get("product") or it
                p_id = str(it.get("productId") or prod.get("id") or "").strip()
                p_var = it.get("selectedVariant") or prod.get("selectedVariant")
                valid_qty = validate_positive_quantity(it.get("quantity"))
                if valid_qty is None:
                    has_invalid_quantity = True
                    p_qty = 1
                else:
                    p_qty = valid_qty
                aggregated_product_demand[p_id] = aggregated_product_demand.get(p_id, 0) + p_qty
                var_key = (p_id, p_var)
                aggregated_variant_demand[var_key] = aggregated_variant_demand.get(var_key, 0) + p_qty

            quote_item_map = {}
            if isinstance(val_quote, dict) and isinstance(val_quote.get("items"), list):
                for q_it in val_quote["items"]:
                    q_pid = str(q_it.get("productId") or "").strip()
                    q_var = str(q_it.get("selectedVariant") or "").strip()
                    quote_item_map[(q_pid, q_var)] = q_it
                    if q_pid and q_pid not in quote_item_map:
                        quote_item_map[q_pid] = q_it

            for it in cached_items:
                prod = it.get("product") or it
                p_id = str(it.get("productId") or prod.get("id") or "").strip()
                p_var = it.get("selectedVariant") or prod.get("selectedVariant")
                db_prod = db_products.get(p_id)
                if db_prod is None and "_" in p_id:
                    base_pid = p_id.split("_")[0]
                    db_prod = db_products.get(base_pid)
                    if db_prod is not None and not p_var and len(p_id.split("_")) > 1:
                        p_var = p_id.split("_")[1]

                if db_prod is None and p_id:
                    has_missing_product = True

                p_name = (db_prod.name if db_prod else (it.get("name") or prod.get("name"))) or "Product"
                valid_qty = validate_positive_quantity(it.get("quantity"))
                if valid_qty is None:
                    has_invalid_quantity = True
                    p_qty = 1
                else:
                    p_qty = valid_qty
                p_img = (db_prod.imageUrl if db_prod else None) or it.get("imageUrl") or prod.get("imageUrl")
                p_cart_item_id = str(it.get("cartItemId") or it.get("id") or "").strip() or None

                # Authoritative pricing & routing
                matched_q_it = quote_item_map.get((p_id, str(p_var or "").strip())) or quote_item_map.get(p_id)
                if matched_q_it and "price" in matched_q_it:
                    p_price = float(matched_q_it["price"])
                    if matched_q_it.get("name"):
                        p_name = matched_q_it["name"]
                    if matched_q_it.get("cartItemId"):
                        p_cart_item_id = matched_q_it["cartItemId"]
                elif db_prod is not None:
                    p_price = float(db_prod.price or 0.0)
                    if p_var and db_prod.variants and isinstance(db_prod.variants, list):
                        v_obj = next((v for v in db_prod.variants if isinstance(v, dict) and v.get("name") == p_var), None)
                        if v_obj and "price" in v_obj:
                            p_price = float(v_obj["price"])
                else:
                    p_price = float(it.get("price") or prod.get("price") or 0.0)

                if db_prod is not None:
                    # Legitimate grocery products have restaurantId=None and MUST remain None!
                    p_rest_id = db_prod.restaurantId
                    total_prod_demanded = aggregated_product_demand.get(p_id, p_qty)
                    total_var_demanded = aggregated_variant_demand.get((p_id, p_var), p_qty)

                    if not p_rest_id:
                        # 1. Product-level hub inventory check (enforced for BOTH variants and plain products)
                        local_inv = store_inv_map.get(db_prod.id)
                        hub_or_global_stock = local_inv.stock if local_inv is not None else (db_prod.stock or 0)
                        if hub_or_global_stock < total_prod_demanded:
                            has_stock_conflict = True

                    if p_var and db_prod.variants and isinstance(db_prod.variants, list):
                        v_obj = next((v for v in db_prod.variants if isinstance(v, dict) and v.get("name") == p_var), None)
                        if not p_rest_id:
                            # 2. Variant-level specific stock check
                            v_stk = int(v_obj.get("stock", 0)) if v_obj else 0
                            if v_stk < total_var_demanded:
                                has_stock_conflict = True
                else:
                    p_rest_id = it.get("restaurantId") or prod.get("restaurantId")

                if p_rest_id:
                    is_restaurant = True
                    target_restaurant_id = p_rest_id

                p_cost = 0.0
                if db_prod:
                    p_cost = float(db_prod.costPrice or 0.0)
                    if p_var and db_prod.variants and isinstance(db_prod.variants, list):
                        v_target = str(p_var).strip().lower()
                        v_obj = next((
                            v for v in db_prod.variants
                            if isinstance(v, dict) and (
                                str(v.get("name") or v.get("unit") or "").strip().lower() == v_target or
                                str(v.get("name") or v.get("unit") or "").strip().lower().replace(" ", "") == v_target.replace(" ", "")
                            )
                        ), None)
                        if v_obj:
                            cp_v = v_obj.get("costPrice") or v_obj.get("cp") or v_obj.get("cost")
                            if cp_v is not None and float(cp_v) > 0:
                                p_cost = float(cp_v)
                    elif (not p_cost or p_cost <= 0) and db_prod.variants and isinstance(db_prod.variants, list):
                        for v in db_prod.variants:
                            if isinstance(v, dict):
                                cp_v = v.get("costPrice") or v.get("cp") or v.get("cost")
                                if cp_v is not None and float(cp_v) > 0:
                                    p_cost = float(cp_v)
                                    break

                items_to_create.append({
                    "productId": db_prod.id if db_prod else None,
                    "name": p_name,
                    "price": p_price,
                    "costPrice": p_cost,
                    "quantity": p_qty,
                    "imageUrl": p_img,
                    "selectedVariant": p_var,
                    "cartItemId": p_cart_item_id,
                    "restaurantId": p_rest_id,
                })

        # If no intent snapshot found, do NOT fulfill current live cart. Flag for manual reconciliation.
        has_missing_intent = False
        if not items_to_create:
            has_missing_intent = True
            items_to_create.append({
                "productId": None,
                "name": "Online Paid Order (Missing Intent - Reconciled)",
                "price": order_amount,
                "quantity": 1,
                "imageUrl": None,
                "selectedVariant": None,
                "restaurantId": target_restaurant_id if is_restaurant else None,
            })

        # Partition items into Grocery and Restaurant groups
        grocery_items = [it for it in items_to_create if not it.get("restaurantId")]
        rest_items_by_id = {}
        for it in items_to_create:
            r_id = it.get("restaurantId")
            if r_id:
                if r_id not in rest_items_by_id:
                    rest_items_by_id[r_id] = []
                rest_items_by_id[r_id].append(it)

        is_split = (len(grocery_items) > 0 and len(rest_items_by_id) > 0) or len(rest_items_by_id) > 1

        all_rest_ids = list(rest_items_by_id.keys())
        if target_restaurant_id and target_restaurant_id not in all_rest_ids:
            all_rest_ids.append(target_restaurant_id)

        restaurant_names = {}
        if all_rest_ids:
            r_stmt = select(Restaurant).where(Restaurant.id.in_(all_rest_ids))
            r_res = await db.execute(r_stmt)
            for r_obj in r_res.scalars().all():
                restaurant_names[r_obj.id] = r_obj.name

        if is_restaurant and target_restaurant_id:
            target_shop_name = restaurant_names.get(target_restaurant_id, "A.S. Restaurant" if target_restaurant_id == "REST-101" else "Restaurant")

        # 6. Allocate Next Order Readable ID Sequence
        try:
            seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')"))
            next_seq = seq_res.scalar()
        except Exception:
            next_seq = int(time.time() * 1000) % 1000000

        calculated_subtotal = sum(it["price"] * it["quantity"] for it in items_to_create)
        if val_quote and val_quote.get("subtotal") is not None:
            calculated_subtotal = float(val_quote["subtotal"])
        expected_total = max(0.0, round(calculated_subtotal - recovered_discount + recovered_delivery_fee + recovered_packaging_fee + recovered_tip, 2))
        if val_quote and val_quote.get("total") is not None:
            expected_total = float(val_quote["total"])
        order_misc_fee = max(0.0, round(recovered_packaging_fee + recovered_tip, 2))

        # Check underpayment against the complete authoritative expected total (or calculated subtotal if no quote)
        threshold_total = expected_total if (val_quote or recovered_discount > 0 or recovered_delivery_fee > 0 or recovered_packaging_fee > 0) else calculated_subtotal
        if items_to_create and (order_amount < (threshold_total - 0.05)):
            has_underpaid_conflict = True

        if has_missing_intent or has_underpaid_conflict or has_stock_conflict or has_missing_product or has_invalid_quantity:
            reconcile_reasons = []
            if has_missing_intent:
                reconcile_reasons.append("Payment received but order intent/snapshot was missing - requires manual reconciliation")
            if has_underpaid_conflict:
                reconcile_reasons.append(f"Underpaid: paid ₹{order_amount:.2f} < expected total ₹{threshold_total:.2f}")
            if has_stock_conflict:
                reconcile_reasons.append("Insufficient inventory for one or more items")
            if has_missing_product:
                reconcile_reasons.append("One or more items not found in database catalog")
            if has_invalid_quantity:
                reconcile_reasons.append("Invalid or non-positive item quantity")
            order_status = OrderStatus.ADMIN_PENDING
            order_notes = f"[RECONCILIATION_REQUIRED] {'; '.join(reconcile_reasons)} | [CF_ORDER:{cf_order_id}] Cashfree PG Paid (Ref: {cf_ref})"
        else:
            order_status = OrderStatus.ADMIN_PENDING
            order_notes = f"[CF_ORDER:{cf_order_id}] | Cashfree PG Paid (Ref: {cf_ref}) | Auto-Recovered (Awaiting Admin Confirmation)"

        # 7. Create Orders (Split into Grocery + Restaurant if mixed cart)
        combined_id = f"combined_{uuid.uuid4().hex[:9]}_{int(time.time())}" if is_split else None
        created_orders = []

        if is_split:
            raw_subtotal = sum(it["price"] * it["quantity"] for it in items_to_create)
            total_subtotal = raw_subtotal if raw_subtotal > 0 else order_amount
            rest_idx = 0

            # 7a. Split Grocery Order
            if grocery_items:
                g_id = f"ord_{uuid.uuid4().hex[:20]}"
                g_readable = f"{next_seq}-G"
                g_subtotal = sum(it["price"] * it["quantity"] for it in grocery_items)
                g_ratio = (g_subtotal / total_subtotal) if total_subtotal > 0 else 0.0
                g_discount = round(g_ratio * recovered_discount, 2)
                g_misc = order_misc_fee
                g_delivery = recovered_delivery_fee
                g_total = max(0.0, round(g_subtotal - g_discount + g_delivery + g_misc, 2))

                order_g = Order(
                    id=g_id,
                    readableId=g_readable,
                    userId=user_id,
                    addressId=address.id,
                    combinedId=combined_id,
                    cfOrderId=clean_cf_id,
                    restaurantId=None,
                    orderType=OrderType.GROCERY,
                    status=order_status,
                    subtotal=g_subtotal,
                    discount=g_discount,
                    deliveryFee=g_delivery,
                    taxes=0.0,
                    miscFee=g_misc,
                    total=g_total,
                    paymentMethod=PaymentMethod.UPI,
                    paymentStatus=PaymentStatus.PAID,
                    estimatedDelivery=datetime.utcnow() + timedelta(minutes=25),
                    deliveryLat=address.lat,
                    deliveryLng=address.lng,
                    deliveryMethod=recovered_delivery_method,
                    isB2B=False,
                    shopName="FastKirana Grocery",
                    shopPhone="9450358388",
                    storeId=recovered_store_id,
                    couponCode=recovered_coupon,
                    createdAt=datetime.utcnow(),
                    updatedAt=datetime.utcnow(),
                    confirmedAt=datetime.utcnow() if order_status == OrderStatus.CONFIRMED else None,
                    notes=order_notes,
                    refundAmount=0.0
                )
                db.add(order_g)
                await db.flush()
                created_orders.append({
                    "order": order_g,
                    "items": grocery_items,
                    "is_restaurant": False,
                    "restaurant_id": None,
                    "shop_name": "FastKirana Grocery"
                })

            # 7b. Split Restaurant Order(s)
            for r_id, r_items in rest_items_by_id.items():
                rest_idx += 1
                r_suffix = f"-R{rest_idx}" if rest_idx > 1 else "-R"
                r_id_str = f"ord_{uuid.uuid4().hex[:20]}"
                r_readable = f"{next_seq}{r_suffix}"
                r_subtotal = sum(it["price"] * it["quantity"] for it in r_items)
                r_ratio = (r_subtotal / total_subtotal) if total_subtotal > 0 else 0.0
                r_discount = round(r_ratio * recovered_discount, 2)
                r_misc = order_misc_fee if (not grocery_items and rest_idx == 1) else 0.0
                r_delivery = recovered_delivery_fee if (not grocery_items and rest_idx == 1) else 0.0
                r_total = max(0.0, round(r_subtotal - r_discount + r_delivery + r_misc, 2))
                r_shop = restaurant_names.get(r_id, "A.S. Restaurant" if r_id == "REST-101" else "Restaurant")

                order_r = Order(
                    id=r_id_str,
                    readableId=r_readable,
                    userId=user_id,
                    addressId=address.id,
                    combinedId=combined_id,
                    cfOrderId=clean_cf_id,
                    restaurantId=r_id,
                    orderType=OrderType.RESTAURANT,
                    status=order_status,
                    subtotal=r_subtotal,
                    discount=r_discount,
                    deliveryFee=r_delivery,
                    taxes=0.0,
                    miscFee=r_misc,
                    total=r_total,
                    paymentMethod=PaymentMethod.UPI,
                    paymentStatus=PaymentStatus.PAID,
                    estimatedDelivery=datetime.utcnow() + timedelta(minutes=25),
                    deliveryLat=address.lat,
                    deliveryLng=address.lng,
                    deliveryMethod=recovered_delivery_method,
                    isB2B=False,
                    shopName=r_shop,
                    shopPhone="9450358388",
                    storeId=recovered_store_id,
                    couponCode=recovered_coupon,
                    createdAt=datetime.utcnow(),
                    updatedAt=datetime.utcnow(),
                    confirmedAt=datetime.utcnow() if order_status == OrderStatus.CONFIRMED else None,
                    notes=order_notes,
                    refundAmount=0.0
                )
                db.add(order_r)
                await db.flush()
                created_orders.append({
                    "order": order_r,
                    "items": r_items,
                    "is_restaurant": True,
                    "restaurant_id": r_id,
                    "shop_name": r_shop
                })

            # Reconcile any rounding cents across orders so sum == order_amount
            sum_totals = sum(co["order"].total for co in created_orders)
            rounding_diff = round(order_amount - sum_totals, 2)
            if abs(rounding_diff) > 0 and abs(rounding_diff) <= 1.0 and created_orders:
                created_orders[0]["order"].total = max(0.0, round(created_orders[0]["order"].total + rounding_diff, 2))

        else:
            # Single non-split order
            order_suffix = "-R" if is_restaurant else "-G"
            readable_id = f"{next_seq}{order_suffix}"
            new_order_id = f"ord_{uuid.uuid4().hex[:20]}"
            order = Order(
                id=new_order_id,
                readableId=readable_id,
                userId=user_id,
                addressId=address.id,
                combinedId=None,
                cfOrderId=clean_cf_id,
                restaurantId=target_restaurant_id if is_restaurant else None,
                orderType=OrderType.RESTAURANT if is_restaurant else OrderType.GROCERY,
                status=order_status,
                subtotal=calculated_subtotal if calculated_subtotal > 0 else order_amount,
                discount=recovered_discount,
                deliveryFee=recovered_delivery_fee,
                taxes=0.0,
                miscFee=order_misc_fee,
                total=order_amount,
                paymentMethod=PaymentMethod.UPI,
                paymentStatus=PaymentStatus.PAID,
                estimatedDelivery=datetime.utcnow() + timedelta(minutes=25),
                deliveryLat=address.lat,
                deliveryLng=address.lng,
                deliveryMethod=recovered_delivery_method,
                isB2B=False,
                shopName=target_shop_name,
                shopPhone="9450358388",
                storeId=recovered_store_id,
                couponCode=recovered_coupon,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow(),
                confirmedAt=datetime.utcnow() if order_status == OrderStatus.CONFIRMED else None,
                notes=order_notes,
                refundAmount=0.0
            )
            db.add(order)
            await db.flush()
            created_orders.append({
                "order": order,
                "items": items_to_create,
                "is_restaurant": is_restaurant,
                "restaurant_id": target_restaurant_id,
                "shop_name": target_shop_name
            })

        # If wallet deduction was part of this order, debit user's wallet
        recovered_wallet_used = float(
            (pending_data.get("validated_quote") or pending_data.get("validatedQuote") or {}).get("walletAmountUsed")
            or (pending_data.get("validated_quote") or pending_data.get("validatedQuote") or {}).get("wallet_amount_used")
            or pending_data.get("walletAmountUsed")
            or pending_data.get("wallet_amount_used")
            or 0.0
        ) if pending_data else 0.0

        # Defensive fallback: If pending_data did not extract wallet amount, check gross total vs gateway paid amount
        if recovered_wallet_used == 0.0 and user_id and not str(user_id).startswith("guest_"):
            gross_total = max(0.0, round(calculated_subtotal - recovered_discount + recovered_delivery_fee + order_misc_fee, 2))
            diff = round(gross_total - order_amount, 2)
            if diff >= 1.0:
                try:
                    from routers.wallet import get_or_create_wallet
                    w_obj = await get_or_create_wallet(user_id, db)
                    if (float(w_obj.balance or 0) + float(w_obj.promoBalance or 0)) >= diff:
                        recovered_wallet_used = diff
                except Exception:
                    pass

        if recovered_wallet_used > 0 and user_id and not str(user_id).startswith("guest_"):
            try:
                from routers.wallet import debit_customer_wallet
                from decimal import Decimal
                await debit_customer_wallet(
                    user_id=user_id,
                    amount=Decimal(str(recovered_wallet_used)),
                    description=f"Wallet deduction for Order #{next_seq}",
                    db=db,
                    metadata={"walletDeduction": recovered_wallet_used, "cfOrderId": clean_cf_id},
                    allow_promo=True,
                )
                wallet_note = f"💳 Wallet Used: ₹{recovered_wallet_used:.2f} | [WALLET_USED:{recovered_wallet_used:.2f}]"
                for co in created_orders:
                    co["order"].notes = f"{co['order'].notes} | {wallet_note}" if co["order"].notes else wallet_note
            except Exception as w_err:
                logger.warning(f"Error debiting wallet on auto-recover for user {user_id}: {w_err}")

        # 8. Create Order Items for each order
        for co in created_orders:
            ord_obj = co["order"]
            for it in co["items"]:
                oi_id = f"oi_{uuid.uuid4().hex[:20]}"
                oi = OrderItem(
                    id=oi_id,
                    orderId=ord_obj.id,
                    productId=it["productId"],
                    name=it["name"],
                    price=it["price"],
                    quantity=it["quantity"],
                    imageUrl=it.get("imageUrl"),
                    selectedVariant=it.get("selectedVariant"),
                    costPrice=float(it.get("costPrice") or 0.0),
                    variants=None,
                    notes=None,
                    refundAmount=0.0,
                    isRefunded=False
                )
                db.add(oi)

        # 8.5 Enforce stock deduction ONLY for grocery products if order is CONFIRMED
        if order_status == OrderStatus.CONFIRMED:
            for it in items_to_create:
                p_id = it.get("productId")
                if not p_id or not db_products.get(p_id):
                    continue
                db_p = db_products[p_id]
                if db_p.restaurantId or it.get("restaurantId"):
                    continue
                qty = it["quantity"]
                sel_var = it.get("selectedVariant")
                prev_stock = db_p.stock or 0
                if sel_var and db_p.variants and isinstance(db_p.variants, list):
                    updated_variants = []
                    for v in db_p.variants:
                        if isinstance(v, dict) and v.get("name") == sel_var:
                            v_copy = dict(v)
                            v_copy["stock"] = max(0, int(v_copy.get("stock", 0)) - qty)
                            updated_variants.append(v_copy)
                        else:
                            updated_variants.append(v)
                    db_p.variants = updated_variants
                    db_p.stock = sum(int(v.get("stock", 0)) for v in updated_variants if isinstance(v, dict))
                else:
                    db_p.stock = max(0, prev_stock - qty)

                if recovered_store_id:
                    try:
                        from models import StoreInventory
                        inv_stmt = select(StoreInventory).where(
                            StoreInventory.productId == db_p.id,
                            StoreInventory.storeId == recovered_store_id
                        )
                        inv_res = await db.execute(inv_stmt)
                        existing_inv = inv_res.scalars().first()
                        if existing_inv:
                            existing_inv.stock = max(0, existing_inv.stock - qty)
                    except Exception as inv_err:
                        logger.warning(f"[Cashfree Recovery] StoreInventory update notice: {inv_err}")

                try:
                    from models import StockLog
                    log = StockLog(
                        id=f"sl_{uuid.uuid4().hex[:16]}",
                        productId=db_p.id,
                        quantity=-qty,
                        type="ONLINE_ORDER_RECOVERY",
                        prevStock=prev_stock,
                        newStock=db_p.stock
                    )
                    db.add(log)
                except Exception:
                    pass

            for co in created_orders:
                co["order"].notes = f"{co['order'].notes or ''} [STOCK_DEDUCTED]".strip()

        # 9. Clear ordered items from user's cart (preserving any newer cart edits)
        if user and items_to_create and order_status == OrderStatus.CONFIRMED:
            cart_stmt = select(Cart).where(Cart.userId == user.id)
            cart_res = await db.execute(cart_stmt)
            cart = cart_res.scalars().first()
            if cart:
                for it in items_to_create:
                    p_id = it.get("productId")
                    p_qty = int(it.get("quantity") or 1)
                    p_var = it.get("selectedVariant")
                    ci_id = it.get("cartItemId")
                    if not p_id and not ci_id:
                        continue

                    matched_ci = None
                    if ci_id:
                        stmt_ci = select(CartItem).where(
                            CartItem.cartId == cart.id,
                            CartItem.id == ci_id
                        )
                        ci_res = await db.execute(stmt_ci)
                        matched_ci = ci_res.scalars().first()

                    if matched_ci:
                        if matched_ci.quantity <= p_qty:
                            await db.delete(matched_ci)
                        else:
                            matched_ci.quantity -= p_qty
                    else:
                        db_p = db_products.get(p_id) if p_id else None
                        unit_val = str(db_p.unit or "").strip() if db_p else ""
                        if p_var:
                            stmt_ci = select(CartItem).where(
                                CartItem.cartId == cart.id,
                                CartItem.productId == p_id,
                                CartItem.selectedVariant == p_var
                            )
                        else:
                            conditions = [
                                CartItem.selectedVariant.is_(None),
                                CartItem.selectedVariant == ""
                            ]
                            if unit_val:
                                conditions.append(CartItem.selectedVariant == unit_val)
                            stmt_ci = select(CartItem).where(
                                CartItem.cartId == cart.id,
                                CartItem.productId == p_id,
                                or_(*conditions)
                            )
                        ci_res = await db.execute(stmt_ci)
                        remaining_to_deduct = p_qty
                        for matched_ci in ci_res.scalars().all():
                            if remaining_to_deduct <= 0:
                                break
                            if matched_ci.quantity <= remaining_to_deduct:
                                remaining_to_deduct -= matched_ci.quantity
                                await db.delete(matched_ci)
                            else:
                                matched_ci.quantity -= remaining_to_deduct
                                remaining_to_deduct = 0
                                break

        # 10. Enqueue Kitchen KOT for printing ONLY if CONFIRMED (per restaurant)
        if order_status == OrderStatus.CONFIRMED:
            for co in created_orders:
                if co["is_restaurant"] and co["restaurant_id"]:
                    r_ord = co["order"]
                    r_items = co["items"]
                    r_target_id = co["restaurant_id"]
                    r_target_shop = co["shop_name"]
                    try:
                        kot_items = [
                            {"name": it["name"], "quantity": it["quantity"], "restaurantId": r_target_id, "isRestaurantItem": True}
                            for it in r_items
                        ]
                        kot_text = (
                            "======================================\n"
                            "            FASTKIRANA KOT\n"
                            "======================================\n"
                            f"TOKEN : #{r_ord.readableId} | {customer_name}\n"
                            f"TYPE  : {recovered_delivery_method}\n"
                            f"Print : {datetime.now().strftime('%d %b %Y %I:%M %p')}\n"
                            "--------------------------------------\n"
                            "QTY   ITEM\n"
                            "--------------------------------------\n"
                            + "\n".join([f"{it['quantity']}  x  {it['name']}" for it in r_items]) + "\n"
                            "--------------------------------------\n"
                            "      *** FASTKIRANA KITCHEN ***\n"
                            "======================================"
                        )
                        kot_payload = {
                            "orderId": r_ord.id,
                            "readableId": r_ord.readableId,
                            "restaurantId": r_target_id,
                            "kotText": kot_text,
                            "items": kot_items,
                            "notes": r_ord.notes,
                            "customerName": customer_name,
                            "deliveryMethod": recovered_delivery_method,
                            "shopName": r_target_shop,
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
                            "oid": r_ord.id,
                            "rid": r_ord.readableId,
                            "rest_id": r_target_id,
                            "payload": json.dumps(kot_payload)
                        })
                    except Exception as kot_err:
                        logger.warning(f"[Auto-Recovery] KOT enqueue error for #{r_ord.readableId}: {kot_err}")

        # Choose primary order to track in cons_rec and return
        primary_order = next((co["order"] for co in created_orders if not co["is_restaurant"]), created_orders[0]["order"])
        order = primary_order
        readable_id = order.readableId
        new_order_id = order.id

        if cons_rec:
            cons_rec.status = "COMPLETED"
            cons_rec.orderId = order.id
            cons_rec.userId = user_id

        await db.commit()
        readable_summary = " / ".join([f"#{co['order'].readableId}" for co in created_orders])
        logger.info(f"🎉 [Auto-Recovery SUCCESS] Reconstructed and placed Order {readable_summary} for {customer_name} (₹{order_amount})!")

        # 11. Async Alerts: WhatsApp & FCM & WebSockets
        try:
            from routers.orders import send_whatsapp_alert
            if order_status == OrderStatus.CONFIRMED:
                admin_msg = (
                    f"🚨 *AUTO-RECONCILED ONLINE ORDER* {readable_summary}\n"
                    f"Customer: {customer_name} ({clean_phone})\n"
                    f"Total: ₹{order_amount:.0f} (PAID via Cashfree)\n"
                    f"Client dropped before sync — Order recovered and dispatched automatically! ✅"
                )
            else:
                admin_msg = (
                    f"⚠️ *RECONCILIATION REQUIRED ONLINE ORDER* {readable_summary}\n"
                    f"Customer: {customer_name} ({clean_phone})\n"
                    f"Paid: ₹{order_amount:.0f} (PAID via Cashfree) | Status: ADMIN_PENDING\n"
                    f"Reason: {order_notes}\n"
                    f"Review required before dispatch! ⚠️"
                )
            for ap in ["7054470303", "8112849854"]:
                asyncio.create_task(send_whatsapp_alert(ap, admin_msg, readable_id))
        except Exception as wa_e:
            logger.warning(f"[Auto-Recovery] WhatsApp alert failed: {wa_e}")

        for co in created_orders:
            co_ord = co["order"]
            co_items = co["items"]
            co_is_rest = co["is_restaurant"]
            co_rest_id = co["restaurant_id"]
            co_shop = co["shop_name"]

            # FCM Order Buzzer notification (to admin, store, and picker)
            try:
                from routers.orders import dispatch_isolated_order_fcm_notifications
                asyncio.create_task(dispatch_isolated_order_fcm_notifications(
                    order_id=co_ord.id,
                    readable_id=co_ord.readableId,
                    restaurant_id=co_rest_id,
                    shop_name=co_shop,
                    total=float(co_ord.total),
                    status_val=order_status.value if hasattr(order_status, "value") else str(order_status),
                    store_id=recovered_store_id,
                    payment_status="PAID"
                ))
            except Exception as fcm_err:
                logger.warning(f"[Auto-Recovery] FCM order buzzer notification failed: {fcm_err}")

            # WebSocket broadcast
            try:
                from routers.websockets import manager
                asyncio.create_task(manager.broadcast_to_channel("general", {
                    "event": "NEW_ORDER",
                    "type": "new-order",
                    "orderId": co_ord.id,
                    "readableId": co_ord.readableId,
                    "shopName": co_shop,
                    "status": order_status.value if hasattr(order_status, "value") else str(order_status),
                    "paymentStatus": "PAID",
                    "paymentMethod": "UPI",
                    "total": float(co_ord.total),
                    "createdAt": datetime.utcnow().isoformat(),
                    "restaurantId": co_rest_id,
                    "storeId": recovered_store_id,
                    "isPaid": True,
                    "combinedId": co_ord.combinedId,
                }))
            except Exception as ws_err:
                logger.warning(f"[Auto-Recovery] WebSocket broadcast failed: {ws_err}")

            # FCM to Restaurant
            if co_is_rest and co_rest_id and order_status == OrderStatus.CONFIRMED:
                try:
                    from utils.firebase import send_fcm_topic_notification
                    asyncio.create_task(send_fcm_topic_notification(
                        topic=f"restaurant_{co_rest_id}",
                        title=f"🔔 NEW ORDER: #{co_ord.readableId} (₹{co_ord.total:.0f})",
                        body=f"Auto-Reconciled: {', '.join([it['name'] for it in co_items])} - {customer_name}",
                        data={"orderId": co_ord.id, "readableId": co_ord.readableId, "restaurantId": co_rest_id, "status": "CONFIRMED"}
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

        prefix_id = clean_id.split("-")[0]
        stmt = select(Order).options(
            selectinload(Order.address),
            selectinload(Order.user)
        ).where(
            (Order.id == clean_id) | 
            (Order.readableId == clean_id) | 
            (Order.id == cf_order_id) |
            (Order.cfOrderId == cf_order_id) |
            (Order.cfOrderId == clean_id) |
            (Order.readableId == f"{clean_id}-G") |
            (Order.readableId == f"{clean_id}-R") |
            (Order.readableId == f"{prefix_id}-G") |
            (Order.readableId == f"{prefix_id}-R")
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
                order.status = OrderStatus.ADMIN_PENDING

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
                        co.status = OrderStatus.ADMIN_PENDING

            # Check if wallet deduction was part of this order and debit if not yet processed
            if "[WALLET_USED:" not in (order.notes or ""):
                try:
                    from utils.cache import get_cache
                    p_intent_wh = await get_cache(f"cf_pending:{clean_id}") or await get_cache(f"cf_pending:{cf_order_id}")
                    if not p_intent_wh:
                        from models import IdempotencyRecord
                        wh_stmt = select(IdempotencyRecord).where(
                            IdempotencyRecord.key.in_([f"cf_intent:{clean_id}", f"cf_intent:{cf_order_id}"])
                        )
                        wh_rec = (await db.execute(wh_stmt)).scalars().first()
                        if wh_rec and isinstance(wh_rec.response, dict):
                            p_intent_wh = wh_rec.response
                    w_used_wh = float(
                        (p_intent_wh.get("validated_quote") or p_intent_wh.get("validatedQuote") or {}).get("walletAmountUsed")
                        or (p_intent_wh.get("validated_quote") or p_intent_wh.get("validatedQuote") or {}).get("wallet_amount_used")
                        or p_intent_wh.get("walletAmountUsed")
                        or p_intent_wh.get("wallet_amount_used")
                        or 0.0
                    ) if p_intent_wh and isinstance(p_intent_wh, dict) else 0.0
                    if w_used_wh > 0 and order.userId and not str(order.userId).startswith("guest_"):
                        from routers.wallet import debit_customer_wallet
                        from decimal import Decimal
                        await debit_customer_wallet(
                            user_id=order.userId,
                            amount=Decimal(str(w_used_wh)),
                            description=f"Wallet deduction for Order #{order.readableId}",
                            db=db,
                            metadata={"walletDeduction": w_used_wh, "cfOrderId": str(cf_order_id)},
                            allow_promo=True,
                        )
                        wallet_note = f"💳 Wallet Used: ₹{w_used_wh:.2f} | [WALLET_USED:{w_used_wh:.2f}]"
                        order.notes = f"{order.notes} | {wallet_note}" if order.notes else wallet_note
                        for co in comb_orders:
                            co.notes = f"{co.notes} | {wallet_note}" if co.notes else wallet_note
                except Exception as w_wh_err:
                    logger.warning(f"Error debiting wallet on webhook for order #{order.readableId}: {w_wh_err}")

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
                                "ADMIN_PENDING",
                                o.storeId,
                                "PAID"
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
                            "status": "ADMIN_PENDING",
                            "paymentStatus": "PAID"
                        }))
                        asyncio.create_task(manager.broadcast_to_channel("general", {
                            "event": "NEW_ORDER",
                            "type": "new-order",
                            "orderId": o.id,
                            "readableId": o.readableId,
                            "shopName": o.shopName,
                            "status": "ADMIN_PENDING",
                            "paymentStatus": "PAID",
                            "paymentMethod": "UPI",
                            "total": float(o.total or 0),
                            "createdAt": datetime.utcnow().isoformat(),
                            "restaurantId": o.restaurantId,
                            "storeId": o.storeId,
                            "isPaid": True,
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

