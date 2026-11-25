"""Order lifecycle & mutation endpoints: status updates, rider doorstep GPS auto-learn, payment, COD conversion, and order editing."""
from fastapi import APIRouter, Depends, HTTPException, status, Body, BackgroundTasks, Header, Request, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, and_, or_, func, text, not_, delete
import os
import re
import json
import uuid
import random
import math
import httpx
import logging
import time
import asyncio
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any

from database import get_db, AsyncSessionLocal
from models import (
    Order, OrderItem, Product, User, Address, RiderWallet, 
    OrderStatus, PaymentStatus, PaymentMethod, OrderType, Role,
    StoreSetting, Coupon, FcmToken, ProductBatch, StockLog, Restaurant, Cart, CartItem, Vendor, DarkStore
)
from routers.auth import require_auth, get_current_user
from routers.websockets import manager
from utils.firebase import send_fcm_notification, send_fcm_topic_notification
from routers.orders_service import generate_id, get_last_10_digits, get_distance_km, validate_order_status_transition
from utils.idempotency import (
    generate_order_cart_signature,
    compute_request_fingerprint,
    acquire_idempotency_lock_async,
    save_idempotency_response_async,
    record_idempotency_result_db_async,
    publish_idempotency_cache_async,
    release_idempotency_lock_async,
)
from services.order_calculation_service import (
    get_delivery_rules,
    get_product_type,
    get_product_limit,
    evaluate_surge_fee,
    geocode_address,
    calculate_coupon_discount,
    calculate_delivery_fee,
    calculate_surge_fee,
    resolve_verified_addon_price,
    calculate_item_addons,
)

logger = logging.getLogger("orders")

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])
from routers.orders_notifications import (
    _order_details_cache,
    _order_details_cache_time,
    ORDER_DETAILS_CACHE_TTL,
    clear_order_cache,
    to_iso_utc,
    safe_enum_str,
    safe_float,
    send_whatsapp_alert,
    resolve_admin_alert_phones,
    get_active_alert_phones,
    upload_to_cloudinary,
    send_pwa_notification_to_roles,
    send_pwa_notification_to_user,
    dispatch_admin_order_buzzer,
    dispatch_isolated_order_fcm_notifications,
    dispatch_isolated_status_update_notifications,
    dispatch_rider_assignment_notification,
    dispatch_restaurant_order_verified_notification,
    _build_replayed_order_payload,
)

router = APIRouter()

@router.patch("/{id}")
async def update_order(
    request: Request,
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Update order workflow status, claim pickers/riders, deduct stock, and notify clients.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")

    stmt = select(Order).options(
        selectinload(Order.items).selectinload(OrderItem.product),
        selectinload(Order.address),
        selectinload(Order.user),
        selectinload(Order.deliveryUser)
    ).where(or_(
        Order.id == id,
        Order.readableId == id,
        Order.readableId.ilike(f"{id}%"),
        Order.combinedId == id
    ))
    res = await db.execute(stmt)
    orders_matched = res.scalars().all()

    if not orders_matched:
        raise HTTPException(status_code=404, detail="Order not found")

    order = orders_matched[0]

    target_status_str = payload.get("status")
    delivery_photo = payload.get("deliveryPhoto")
    delivery_lat = payload.get("deliveryLat")
    delivery_lng = payload.get("deliveryLng")
    prep_time = payload.get("prepTime")
    is_rider_cash = payload.get("isRiderCash", True)
    payment_collected_by = payload.get("paymentCollectedBy")
    delivery_user_id = payload.get("deliveryUserId")

    is_admin = role == "ADMIN"
    is_delivery = role == "DELIVERY"
    is_picker = role == "PICKER"
    is_restaurant_staff = role in ["CHEF", "RESTAURANT_OWNER"]
    is_owner = order.userId == user_id
    is_restaurant_order = bool(order.restaurantId or order.orderType == OrderType.RESTAURANT)

    if not is_owner and not is_admin and not is_delivery and not is_picker and not is_restaurant_staff:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Handle Route, Notes, or Rider Assignment without changing Status
    has_notes = "notes" in payload
    has_route = "deliveryRoute" in payload
    has_duid = "deliveryUserId" in payload

    if not target_status_str:
        if has_notes or has_route or has_duid:
            updated_notes = payload.get("notes")
            delivery_route = payload.get("deliveryRoute")
            if delivery_route and not updated_notes:
                clean_route = str(delivery_route).upper().strip()
                updated_notes = f"{order.notes or ''} | ROUTE:{clean_route}".strip(" |")

            if updated_notes is not None:
                order.notes = updated_notes

            if has_duid:
                raw_duid = payload.get("deliveryUserId")
                if not raw_duid or str(raw_duid).strip().upper() in ["", "UNASSIGNED", "NONE", "NULL"]:
                    order.deliveryUserId = None
                    order.deliveryLat = None
                    order.deliveryLng = None
                else:
                    order.deliveryUserId = str(raw_duid).strip()

            order.updatedAt = datetime.utcnow()

            companions = []
            if order.combinedId:
                sibling_stmt = select(Order).options(
                    selectinload(Order.items).selectinload(OrderItem.product),
                    selectinload(Order.address),
                    selectinload(Order.user),
                    selectinload(Order.deliveryUser)
                ).where(Order.combinedId == order.combinedId, Order.id != order.id)
                sibling_res = await db.execute(sibling_stmt)
                companions = list(sibling_res.scalars().all())

            for companion in companions:
                if updated_notes is not None:
                    companion.notes = updated_notes
                if has_duid:
                    companion.deliveryUserId = order.deliveryUserId
                companion.updatedAt = datetime.utcnow()

            await db.commit()
            await db.refresh(order)
            clear_order_cache(order.id)
            if order.combinedId:
                clear_order_cache(order.combinedId)
            for companion in companions:
                clear_order_cache(companion.id)
                if companion.combinedId:
                    clear_order_cache(companion.combinedId)

            # 🚨 TRIGGER RIDER ASSIGNMENT BUZZER ALERT & REALTIME WHEN RIDER ASSIGNED (NO STATUS CHANGE)
            if has_duid and order.deliveryUserId:
                background_tasks.add_task(
                    dispatch_rider_assignment_notification,
                    order.id,
                    order.readableId,
                    order.deliveryUserId,
                    order.status.value,
                    float(order.total or 0.0),
                    order.storeId
                )

            return {
                "success": True,
                "message": "Order updated successfully",
                "order": {
                    "id": order.id,
                    "readableId": order.readableId,
                    "status": order.status.value,
                    "notes": order.notes,
                    "deliveryUserId": order.deliveryUserId,
                    "updatedAt": order.updatedAt.isoformat()
                }
            }
        else:
            raise HTTPException(status_code=400, detail="status is required")

    status_alias_map = {
        "PREPARING": OrderStatus.CONFIRMED,
        "PROCESSING": OrderStatus.CONFIRMED,
        "READY": OrderStatus.PACKED,
        "OUT_FOR_DELIVERY": OrderStatus.SHIPPED,
        "COMPLETED": OrderStatus.DELIVERED,
    }

    raw_status_str = str(target_status_str).upper()
    if raw_status_str in status_alias_map:
        target_status = status_alias_map[raw_status_str]
    else:
        try:
            target_status = OrderStatus(raw_status_str)
        except ValueError:
            target_status = OrderStatus.CONFIRMED

    # Enforce order state machine transitions
    from services.order_calculation_service import validate_status_transition
    is_valid_transition, transition_err = validate_status_transition(order.status.value, target_status.value)
    if not is_valid_transition and not is_admin:
        raise HTTPException(status_code=400, detail=transition_err)

    # Strict Role Assignment for Status Transitions
    if target_status == OrderStatus.CANCELLED:
        if is_owner and not is_admin:
            # Customers can freely cancel orders before store confirmation (ADMIN_PENDING or PENDING)
            if order.status not in [OrderStatus.ADMIN_PENDING, OrderStatus.PENDING]:
                raise HTTPException(
                    status_code=400,
                    detail="Order cannot be cancelled after it has been confirmed by the store. Please contact support."
                )
        elif not (is_admin or is_picker or is_restaurant_staff or is_delivery):
            raise HTTPException(status_code=403, detail="Unauthorized to cancel this order")
    elif target_status in [OrderStatus.CONFIRMED, OrderStatus.PACKED]:
        if is_restaurant_order:
            if not (is_admin or is_restaurant_staff):
                raise HTTPException(status_code=403, detail="Only restaurant staff can accept or pack restaurant orders")
        else:
            if not (is_admin or is_picker):
                raise HTTPException(status_code=403, detail="Only Dark Store pickers can accept or pack grocery orders")
            picker_store = current_user.get("assignedStoreId")
            if not is_admin and picker_store and order.storeId and order.storeId != picker_store:
                raise HTTPException(status_code=403, detail="Forbidden: You can only pick/pack orders for your assigned store hub")
    elif target_status in [OrderStatus.SHIPPED, OrderStatus.DELIVERED]:
        if not (is_admin or is_delivery):
            raise HTTPException(status_code=403, detail="Only delivery riders can ship or deliver orders")
        rider_store = current_user.get("assignedStoreId")
        if not is_admin and rider_store and order.storeId and order.storeId != rider_store:
            raise HTTPException(status_code=403, detail="Forbidden: You can only deliver orders for your assigned store hub")

    # Store-scoped admin check
    is_superadmin = (current_user.get("role") or "").upper() in ["SUPER_ADMIN", "SUPERADMIN"]
    admin_store = current_user.get("assignedStoreId")
    if is_admin and not is_superadmin and admin_store and order.storeId and order.storeId != admin_store:
        raise HTTPException(status_code=403, detail="Forbidden: Order belongs to a different store hub")

    if is_restaurant_staff and not is_admin:
        if not order.restaurantId:
            raise HTTPException(
                status_code=403,
                detail="Restaurant staff cannot manage dark store grocery orders"
            )
        if not assigned_restaurant_id:
            user_stmt = select(User.assignedRestaurantId).where(User.id == user_id)
            user_res = await db.execute(user_stmt)
            assigned_restaurant_id = user_res.scalar_one_or_none()

        if not assigned_restaurant_id:
            raise HTTPException(
                status_code=403,
                detail="No restaurant assigned to your staff account"
            )

        rest_stmt = select(Restaurant.id, Restaurant.slug).where(
            or_(Restaurant.id == assigned_restaurant_id, Restaurant.slug == assigned_restaurant_id)
        )
        rest_res = await db.execute(rest_stmt)
        matched_rest = rest_res.mappings().first()
        outlet_ids = {assigned_restaurant_id}
        if matched_rest:
            outlet_ids.add(matched_rest["id"])
            if matched_rest["slug"]:
                outlet_ids.add(matched_rest["slug"])

        if order.restaurantId not in outlet_ids:
            raise HTTPException(
                status_code=403,
                detail="You can only manage orders for your assigned restaurant outlet"
            )

    # Claim locks
    if target_status == OrderStatus.CONFIRMED:
        if is_restaurant_order:
            if order.assignedChefId and order.assignedChefId != user_id:
                raise HTTPException(status_code=409, detail="Order is already claimed by another chef")
        else:
            if order.assignedPickerId and order.assignedPickerId != user_id:
                raise HTTPException(status_code=409, detail="Order is already claimed by another picker")

    if target_status == OrderStatus.SHIPPED:
        if order.deliveryUserId and order.deliveryUserId != user_id:
            raise HTTPException(status_code=409, detail="Order is already claimed by another delivery rider")

    # C3 FIX: Stock is already deducted at order creation (lines 896-938).
    # Do NOT deduct again on PACKED to avoid double deduction.
    # The PACKED transition only marks the order as physically packed.
    if target_status == OrderStatus.PACKED and order.status != OrderStatus.PACKED:
        pass  # No stock deduction — already done at creation

    # Restore stock on CANCELLED state transition
    if target_status == OrderStatus.CANCELLED and order.status != OrderStatus.CANCELLED:
        if "[STOCK_DEDUCTED]" in (order.notes or ""):
            items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
            items_res = await db.execute(items_stmt)
            order_items = items_res.scalars().all()

            for item in order_items:
                if not item.productId:
                    continue
                
                prod_stmt = select(Product).options(selectinload(Product.category)).where(Product.id == item.productId)
                prod_res = await db.execute(prod_stmt)
                product = prod_res.scalars().first()

                if not product:
                    continue

                # Skip stock restoration for Cafe & Restaurant items
                p_type = get_product_type(product)
                if p_type in ["CAFE", "RESTAURANT"]:
                    continue

                if item.selectedVariant:
                    if product.variants:
                        updated_variants = []
                        for v in product.variants:
                            if v.get("name") == item.selectedVariant:
                                v["stock"] = v.get("stock", 0) + item.quantity
                            updated_variants.append(v)
                        new_total_stock = sum(v.get("stock", 0) for v in updated_variants)
                        product.variants = updated_variants
                        product.stock = new_total_stock
                else:
                    batches_stmt = select(ProductBatch).where(ProductBatch.productId == item.productId).order_by(ProductBatch.expiryDate.asc())
                    batches_res = await db.execute(batches_stmt)
                    batches = batches_res.scalars().all()

                    if batches:
                        batches[0].quantity += item.quantity
                        product.stock = sum(b.quantity for b in batches)
                    else:
                        product.stock += item.quantity

                # If order was associated with a dark store, restore localized stock in StoreInventory
                if order.storeId:
                    try:
                        from models import StoreInventory
                        inv_stmt = select(StoreInventory).where(
                            StoreInventory.productId == item.productId,
                            StoreInventory.storeId == order.storeId
                        )
                        inv_res = await db.execute(inv_stmt)
                        existing_inv = inv_res.scalars().first()
                        if existing_inv:
                            existing_inv.stock += item.quantity
                    except Exception as inv_restore_err:
                        logger.warning(f"Could not restore StoreInventory for product {item.productId} at store {order.storeId}: {inv_restore_err}")

            order.notes = (order.notes or "").replace("[STOCK_DEDUCTED]", "[STOCK_RESTORED]").strip()

        # Automatic refund for wallet balance if applied
        if "[WALLET_USED:" in (order.notes or "") and "[WALLET_REFUNDED]" not in (order.notes or ""):
            try:
                from routers.wallet import credit_customer_wallet
                from decimal import Decimal
                w_match = re.search(r"\[WALLET_USED:([0-9.]+)\]", order.notes or "")
                if w_match:
                    refund_amt = Decimal(w_match.group(1))
                    if refund_amt > Decimal("0.00"):
                        tx_ref_id = f"wtx_ref_{order.id}"
                        meta = {
                            "orderId": order.id,
                            "readableId": order.readableId,
                            "combinedId": order.combinedId
                        }
                        await credit_customer_wallet(
                            user_id=order.userId,
                            amount=refund_amt,
                            description=f"Refund for cancelled order #{order.readableId} 👛",
                            db=db,
                            tx_id=tx_ref_id,
                            metadata=meta
                        )
                        order.notes = f"{order.notes or ''} | [WALLET_REFUNDED]".strip(" |")
                        logger.info(f"Refunded ₹{refund_amt} to customer {order.userId} for cancelled order #{order.readableId}")
            except Exception as ref_err:
                logger.error(f"Error refunding wallet for cancelled order {order.id}: {ref_err}")

    # Cloudinary upload on deliver pings
    final_delivery_photo = delivery_photo
    # Delivery photos are completely disabled (privacy & fast zero-friction delivery)
    final_delivery_photo = None

    # Update database values
    order.status = target_status
    if "notes" in payload:
        order.notes = payload.get("notes")
    elif "deliveryRoute" in payload:
        clean_route = str(payload.get("deliveryRoute")).upper().strip()
        order.notes = f"{order.notes or ''} | ROUTE:{clean_route}".strip(" |")
    order.updatedAt = datetime.utcnow()

    if target_status == OrderStatus.DELIVERED:
        safe_photo = None
        cash_amount_custom = payload.get("cashAmount")

        # Rider / Staff delivery attribution:
        if is_delivery:
            # Explicitly attribute delivered order to the active delivery rider
            order.deliveryUserId = user_id
        elif is_admin:
            # When admin delivers directly, do NOT attribute to any rider unless admin explicitly passed deliveryUserId
            if "deliveryUserId" in payload:
                raw_duid = payload.get("deliveryUserId")
                if raw_duid and str(raw_duid).strip().upper() not in ["", "UNASSIGNED", "NONE", "NULL"]:
                    order.deliveryUserId = str(raw_duid).strip()
                else:
                    order.deliveryUserId = None
            elif not order.deliveryUserId:
                order.deliveryUserId = None
        elif "deliveryUserId" in payload:
            raw_duid = payload.get("deliveryUserId")
            if raw_duid and str(raw_duid).strip().upper() not in ["", "UNASSIGNED", "NONE", "NULL"]:
                order.deliveryUserId = str(raw_duid).strip()

        # Determine actual payment method on delivery:
        # Preserve COD unless customer was already paid online or paid via doorstep UPI QR
        is_already_paid_online = (
            order.paymentStatus == PaymentStatus.PAID and
            order.paymentMethod != PaymentMethod.COD
        )
        is_explicit_online = (
            is_already_paid_online or
            order.paymentMethod in [PaymentMethod.UPI, PaymentMethod.CARD, PaymentMethod.WALLET] or
            payment_collected_by == "ONLINE"
        )

        if cash_amount_custom is not None:
            try:
                order_cash_collected = max(0.0, float(cash_amount_custom))
            except (ValueError, TypeError):
                order_cash_collected = float(order.total)
            if order_cash_collected > 0:
                new_payment_method = PaymentMethod.COD
            else:
                new_payment_method = PaymentMethod.UPI
        elif is_explicit_online:
            new_payment_method = PaymentMethod.UPI
            order_cash_collected = 0.0
        else:
            new_payment_method = PaymentMethod.COD
            order_cash_collected = float(order.total)

        order.paymentStatus = PaymentStatus.PAID
        order.paymentMethod = new_payment_method

        # If COD order was delivered by Admin/Staff (not rider), cash went directly to Counter (Galla)
        if new_payment_method == PaymentMethod.COD and (is_admin and not is_delivery and payment_collected_by != "RIDER"):
            order.cashSettledToAdmin = True
            order.cashSettledAt = datetime.utcnow()

        order.deliveryPhoto = safe_photo
        order.deliveryLat = float(delivery_lat) if delivery_lat is not None else None
        order.deliveryLng = float(delivery_lng) if delivery_lng is not None else None
        order.deliveredAt = datetime.utcnow()

        # 🛡️ 7-Guard Rider Doorstep GPS Auto-Learn (fixes old/fallback customer pins once, never overwrites real pins)
        if order.deliveryLat is not None and order.deliveryLng is not None and order.addressId and (is_delivery or payment_collected_by == "RIDER"):
            try:
                d_lat = float(order.deliveryLat)
                d_lng = float(order.deliveryLng)
                raw_acc = payload.get("deliveryGpsAccuracy")
                gps_acc = float(raw_acc) if raw_acc is not None else None
                notes_lower = (order.notes or "").lower()
                is_pickup_or_gift = (
                    (order.deliveryMethod or "").upper() == "PICKUP"
                    or "order for:" in notes_lower
                    or order.addressId == "addr_default_ghatampur"
                )
                # Guard 3 & 5: Accuracy <= 65m (if provided) and not pickup/gift
                if not is_pickup_or_gift and (gps_acc is None or gps_acc <= 65.0):
                    hub_lat, hub_lng = 26.1534185, 80.1714024
                    if order.storeId:
                        hub_res = await db.execute(select(DarkStore).where(DarkStore.id == order.storeId))
                        hub_row = hub_res.scalars().first()
                        if hub_row and getattr(hub_row, "latitude", None) and getattr(hub_row, "longitude", None):
                            hub_lat, hub_lng = float(hub_row.latitude), float(hub_row.longitude)

                    rider_dist_from_hub_m = get_distance_km(hub_lat, hub_lng, d_lat, d_lng) * 1000.0
                    # Guard 2 & 6: Rider must be 80m..12km away from Darkstore Hub
                    if 80.0 < rider_dist_from_hub_m <= 12000.0:
                        addr_res = await db.execute(select(Address).where(Address.id == order.addressId))
                        addr_row = addr_res.scalars().first()
                        if addr_row and (addr_row.label or "").upper() != "STORE_PICKUP":
                            # Guard 1: ONLY auto-learn if saved pin is missing/0 or Darkstore fallback (<= 50m)
                            addr_is_fallback = (
                                addr_row.lat is None
                                or addr_row.lng is None
                                or (addr_row.lat == 0.0 and addr_row.lng == 0.0)
                                or (get_distance_km(hub_lat, hub_lng, float(addr_row.lat), float(addr_row.lng)) * 1000.0 <= 50.0)
                            )
                            if addr_is_fallback:
                                # Guard 4: Batch-slide protection — ensure same rider did not deliver a different address within 90s & 35m
                                cutoff = datetime.utcnow() - timedelta(seconds=90)
                                recent_res = await db.execute(
                                    select(Order).where(
                                        and_(
                                            Order.deliveryUserId == order.deliveryUserId,
                                            Order.status == OrderStatus.DELIVERED,
                                            Order.id != order.id,
                                            Order.addressId != order.addressId,
                                            Order.deliveredAt >= cutoff,
                                            Order.deliveryLat.isnot(None),
                                            Order.deliveryLng.isnot(None),
                                        )
                                    )
                                )
                                is_batch_slide = any(
                                    get_distance_km(d_lat, d_lng, float(r.deliveryLat), float(r.deliveryLng)) * 1000.0 < 35.0
                                    for r in recent_res.scalars().all()
                                )
                                if not is_batch_slide:
                                    addr_row.lat = d_lat
                                    addr_row.lng = d_lng
                                    logger.info(f"[AutoLearn] Upgraded fallback pin for address {addr_row.id} -> ({d_lat:.6f}, {d_lng:.6f})")
            except Exception as al_err:
                logger.warning(f"[AutoLearn] Non-fatal skip for order {order.id}: {al_err}")

        # Trigger Refer & Earn reward for referrer on successful first order delivery
        try:
            async with db.begin_nested():
                from routers.referral import process_referral_reward_on_delivery
                await process_referral_reward_on_delivery(order, db)
        except Exception as ref_err:
            logger.warning(f"Referral delivery reward hook error for order {order.id}: {ref_err}")

        # Update Rider Wallet for Cash collected ONLY if a genuine delivery rider collected it
        if order_cash_collected > 0 and order.deliveryUserId and (is_delivery or payment_collected_by == "RIDER"):
            wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
            wallet_res = await db.execute(wallet_stmt)
            wallet = wallet_res.scalars().first()

            if wallet:
                wallet.cashInHand += order_cash_collected
                wallet.totalCollected += order_cash_collected
            else:
                wallet = RiderWallet(
                    id=f"rw_{order.deliveryUserId}",
                    userId=order.deliveryUserId,
                    cashInHand=order_cash_collected,
                    cashLimit=2000.0,
                    totalCollected=order_cash_collected,
                    totalDeposited=0.0
                )
                db.add(wallet)

    elif target_status == OrderStatus.SHIPPED:
        if role == Role.DELIVERY:
            # Concurrency check / Double-claim guard:
            if order.deliveryUserId and order.deliveryUserId != user_id and order.status == OrderStatus.SHIPPED:
                raise HTTPException(status_code=409, detail="Order has already been picked up by another rider")
            order.deliveryUserId = user_id
            # Query rider live lat/lng
            r_stmt = select(User).where(User.id == user_id)
            r_res = await db.execute(r_stmt)
            r_rider = r_res.scalars().first()
            if r_rider and r_rider.liveLat is not None and r_rider.liveLng is not None:
                order.deliveryLat = float(r_rider.liveLat)
                order.deliveryLng = float(r_rider.liveLng)
        elif "deliveryUserId" in payload:
            raw_duid = payload.get("deliveryUserId")
            if not raw_duid or str(raw_duid).strip().upper() in ["", "UNASSIGNED", "NONE", "NULL"]:
                order.deliveryUserId = None
                order.deliveryLat = None
                order.deliveryLng = None
            else:
                order.deliveryUserId = str(raw_duid).strip()
                if order.deliveryUserId != "store_admin_self":
                    r_stmt = select(User).where(User.id == order.deliveryUserId)
                    r_res = await db.execute(r_stmt)
                    r_user = r_res.scalars().first()
                    if r_user and r_user.liveLat is not None and r_user.liveLng is not None:
                        order.deliveryLat = float(r_user.liveLat)
                        order.deliveryLng = float(r_user.liveLng)
        elif delivery_user_id:
            order.deliveryUserId = delivery_user_id

        if delivery_lat is not None and delivery_lng is not None:
            order.deliveryLat = float(delivery_lat)
            order.deliveryLng = float(delivery_lng)
        order.shippedAt = datetime.utcnow()

    elif target_status == OrderStatus.PACKED:
        order.packedAt = datetime.utcnow()
        # Open Pool Model: Order stays unassigned for store riders to claim manually from "Ready for Pickup"
        # or for Admin to assign/reassign via dropdown. No blind auto-dispatch.
        if "deliveryUserId" in payload:
            raw_duid = payload.get("deliveryUserId")
            if not raw_duid or str(raw_duid).strip().upper() in ["", "UNASSIGNED", "NONE", "NULL"]:
                order.deliveryUserId = None
                order.deliveryLat = None
                order.deliveryLng = None
            else:
                order.deliveryUserId = str(raw_duid).strip()
                if order.deliveryUserId != "store_admin_self":
                    r_stmt = select(User).where(User.id == order.deliveryUserId)
                    r_res = await db.execute(r_stmt)
                    r_user = r_res.scalars().first()
                    if r_user and r_user.liveLat is not None and r_user.liveLng is not None:
                        order.deliveryLat = float(r_user.liveLat)
                        order.deliveryLng = float(r_user.liveLng)

    elif target_status == OrderStatus.CONFIRMED:
        order.confirmedAt = datetime.utcnow()
        if role == Role.CHEF:
            order.assignedChefId = user_id
        elif role == Role.PICKER:
            order.assignedPickerId = user_id

        if prep_time and str(prep_time).isdigit():
            order.estimatedDelivery = datetime.utcnow() + timedelta(minutes=int(prep_time))

        if "deliveryUserId" in payload:
            raw_duid = payload.get("deliveryUserId")
            if not raw_duid or str(raw_duid).strip().upper() in ["", "UNASSIGNED", "NONE", "NULL"]:
                order.deliveryUserId = None
                order.deliveryLat = None
                order.deliveryLng = None
            else:
                order.deliveryUserId = str(raw_duid).strip()

    # General Rider Assignment Guard: Always update deliveryUserId if explicitly passed in payload
    if "deliveryUserId" in payload and target_status != OrderStatus.DELIVERED:
        raw_duid = payload.get("deliveryUserId")
        if not raw_duid or str(raw_duid).strip().upper() in ["", "UNASSIGNED", "NONE", "NULL"]:
            order.deliveryUserId = None
            order.deliveryLat = None
            order.deliveryLng = None
        else:
            order.deliveryUserId = str(raw_duid).strip()
            if order.deliveryUserId != "store_admin_self":
                r_stmt = select(User).where(User.id == order.deliveryUserId)
                r_res = await db.execute(r_stmt)
                r_user = r_res.scalars().first()
                if r_user and r_user.liveLat is not None and r_user.liveLng is not None:
                    order.deliveryLat = float(r_user.liveLat)
                    order.deliveryLng = float(r_user.liveLng)

    # Sibling synchronization (H6 FIX: outlet isolation, cascade-cancel on explicit all, customer cancel, or admin actions)
    is_explicit_all = payload.get("scope") == "ALL" or payload.get("updateCombined") is True
    is_customer_cancel = is_owner and target_status == OrderStatus.CANCELLED
    is_admin_cancel = is_admin and target_status == OrderStatus.CANCELLED
    should_sync_status = (
        is_explicit_all or
        is_customer_cancel or
        is_admin_cancel or
        is_admin or
        target_status in [OrderStatus.CONFIRMED, OrderStatus.SHIPPED, OrderStatus.DELIVERED, OrderStatus.CANCELLED]
    )

    companions = []
    if order.combinedId:
        sibling_stmt = select(Order).options(
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.address),
            selectinload(Order.user),
            selectinload(Order.deliveryUser)
        ).where(Order.combinedId == order.combinedId, Order.id != order.id)
        sibling_res = await db.execute(sibling_stmt)
        companions = list(sibling_res.scalars().all())

    # Fallback companion detection via readableId base (e.g. 2103-G / 2103-R)
    if not companions and order.readableId and ("-G" in order.readableId or "-R" in order.readableId):
        base_readable = re.sub(r'-[GR\d]+$', '', order.readableId)
        if base_readable:
            base_stmt = select(Order).options(
                selectinload(Order.items).selectinload(OrderItem.product),
                selectinload(Order.address),
                selectinload(Order.user),
                selectinload(Order.deliveryUser)
            ).where(
                Order.readableId.like(f"{base_readable}-%"),
                Order.id != order.id
            )
            base_res = await db.execute(base_stmt)
            companions = list(base_res.scalars().all())

    for companion in companions:
        if should_sync_status:
            companion.status = order.status
            companion.updatedAt = datetime.utcnow()
            if target_status == OrderStatus.CANCELLED:
                if "[WALLET_USED:" in (companion.notes or "") and "[WALLET_REFUNDED]" not in (companion.notes or ""):
                    try:
                        from routers.wallet import credit_customer_wallet
                        from decimal import Decimal
                        comp_w_match = re.search(r"\[WALLET_USED:([0-9.]+)\]", companion.notes or "")
                        if comp_w_match:
                            comp_refund_amt = Decimal(comp_w_match.group(1))
                            if comp_refund_amt > Decimal("0.00"):
                                comp_tx_ref_id = f"wtx_ref_{companion.id}"
                                comp_meta = {
                                    "orderId": companion.id,
                                    "readableId": companion.readableId,
                                    "combinedId": companion.combinedId
                                }
                                await credit_customer_wallet(
                                    user_id=companion.userId,
                                    amount=comp_refund_amt,
                                    description=f"Refund for cancelled order #{companion.readableId} 👛",
                                    db=db,
                                    tx_id=comp_tx_ref_id,
                                    metadata=comp_meta
                                )
                                companion.notes = f"{companion.notes or ''} | [WALLET_REFUNDED]".strip(" |")
                                logger.info(f"Refunded companion ₹{comp_refund_amt} to customer {companion.userId} for order #{companion.readableId}")
                    except Exception as comp_ref_err:
                        logger.error(f"Error refunding companion wallet for order {companion.id}: {comp_ref_err}")
        if "deliveryUserId" in payload or role == Role.DELIVERY:
            companion.deliveryUserId = order.deliveryUserId
            companion.deliveryLat = order.deliveryLat
            companion.deliveryLng = order.deliveryLng
        elif order.deliveryUserId:
            companion.deliveryUserId = order.deliveryUserId
        if "notes" in payload or "deliveryRoute" in payload:
            companion.notes = order.notes
        if target_status == OrderStatus.DELIVERED:
            companion.paymentStatus = PaymentStatus.PAID
            companion.paymentMethod = order.paymentMethod
            companion.deliveredAt = datetime.utcnow()
            companion.status = OrderStatus.DELIVERED
            companion.updatedAt = datetime.utcnow()

    await db.commit()
    await db.refresh(order)
    clear_order_cache(order.id)
    if order.combinedId:
        clear_order_cache(order.combinedId)

    for companion in companions:
        clear_order_cache(companion.id)
        if companion.combinedId:
            clear_order_cache(companion.combinedId)
        status_trace_id = getattr(request.state, "trace_id", None) or payload.get("traceId") or payload.get("trace_id")
        try:
            await manager.broadcast_to_channel("general", {
                "event": "STATUS_UPDATE",
                "orderId": companion.id,
                "status": companion.status.value,
                "traceId": status_trace_id,
                "order": {
                    "id": companion.id,
                    "status": companion.status.value,
                    "total": float(companion.total),
                    "updatedAt": companion.updatedAt.isoformat(),
                    "traceId": status_trace_id,
                }
            })
            await manager.broadcast_to_channel(f"order_{companion.id}", {
                "event": "STATUS_UPDATE",
                "orderId": companion.id,
                "restaurantId": companion.restaurantId,
                "status": companion.status.value,
                "lat": companion.deliveryLat,
                "lng": companion.deliveryLng,
                "traceId": status_trace_id,
            })
            if companion.readableId:
                await manager.broadcast_to_channel(f"order_{companion.readableId}", {
                    "event": "STATUS_UPDATE",
                    "orderId": companion.id,
                    "readableId": companion.readableId,
                    "restaurantId": companion.restaurantId,
                    "status": companion.status.value,
                    "lat": companion.deliveryLat,
                    "lng": companion.deliveryLng,
                    "traceId": status_trace_id,
                })
            if companion.restaurantId:
                await manager.broadcast_to_channel(f"restaurant_{companion.restaurantId}", {
                    "event": "STATUS_UPDATE",
                    "orderId": companion.id,
                    "restaurantId": companion.restaurantId,
                    "status": companion.status.value,
                    "traceId": status_trace_id,
                })
        except Exception as comp_err:
            logger.warning(f"Failed companion broadcast for {companion.id}: {comp_err}")

    # Dispatch real-time WebSocket alerts
    status_trace_id = getattr(request.state, "trace_id", None) or payload.get("traceId") or payload.get("trace_id")
    await manager.broadcast_to_channel("general", {
        "event": "STATUS_UPDATE",
        "orderId": order.id,
        "status": order.status.value,
        "traceId": status_trace_id,
        "order": {
            "id": order.id,
            "status": order.status.value,
            "total": float(order.total),
            "updatedAt": order.updatedAt.isoformat(),
            "traceId": status_trace_id,
        }
    })
    
    await manager.broadcast_to_channel(f"order_{order.id}", {
        "event": "STATUS_UPDATE",
        "orderId": order.id,
        "restaurantId": order.restaurantId,
        "status": order.status.value,
        "lat": order.deliveryLat,
        "lng": order.deliveryLng,
        "traceId": status_trace_id,
    })

    if order.readableId:
        try:
            await manager.broadcast_to_channel(f"order_{order.readableId}", {
                "event": "STATUS_UPDATE",
                "orderId": order.id,
                "readableId": order.readableId,
                "restaurantId": order.restaurantId,
                "status": order.status.value,
                "lat": order.deliveryLat,
                "lng": order.deliveryLng,
                "traceId": status_trace_id,
            })
        except Exception:
            pass

    # Strict restaurant channel real-time update
    if order.restaurantId:
        rest_ws_payload = {
            "event": "STATUS_UPDATE",
            "orderId": order.id,
            "restaurantId": order.restaurantId,
            "status": order.status.value,
            "order": {
                "id": order.id,
                "readableId": order.readableId,
                "status": order.status.value,
                "restaurantId": order.restaurantId,
                "total": float(order.total),
                "updatedAt": order.updatedAt.isoformat()
            }
        }
        await manager.broadcast_to_channel(f"restaurant_{order.restaurantId}", rest_ws_payload)
        await manager.broadcast_to_channel(f"kitchen_{order.restaurantId}", rest_ws_payload)

    # Zero-load instant broadcast to Supabase Realtime for Admin consoles, Riders, and Customer devices
    try:
        from utils.supabase_broadcast import broadcast_supabase_realtime
        sb_topics = [
            "admin-global-orders-websocket",
            f"order-live-tracking-{order.id}",
        ]
        if order.readableId:
            clean_r = str(order.readableId).strip().lstrip("#")
            sb_topics.append(f"order-live-tracking-{clean_r}")
        if order.userId:
            sb_topics.append(f"customer-orders-{order.userId}")
        if order.restaurantId:
            sb_topics.append(f"restaurant-orders-{order.restaurantId}")

        sb_payload = {
            "id": order.id,
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "deliveryUserId": order.deliveryUserId,
            "restaurantId": order.restaurantId,
            "storeId": order.storeId,
            "paymentStatus": getattr(order.paymentStatus, "value", str(order.paymentStatus or "")),
            "updatedAt": order.updatedAt.isoformat() if order.updatedAt else datetime.utcnow().isoformat()
        }
        asyncio.create_task(broadcast_supabase_realtime(sb_topics, "status_update", sb_payload))
        if order.status.value == "SHIPPED" and order.deliveryUserId:
            asyncio.create_task(broadcast_supabase_realtime(["admin-global-orders-websocket"], "order_claimed", sb_payload))
    except Exception as sb_err:
        logger.warning(f"[SupabaseBroadcast] Order status dispatch note: {sb_err}")

    # Trigger Rich PWA & Mobile Push Notification for customer and staff roles
    base_order_no = re.sub(r'-[GR\d]+$', '', order.readableId or "")
    st_val = order.status.value.upper()

    stage_titles = {
        "CONFIRMED": "🏪 Order Confirmed!",
        "PREPARING": "👨‍🍳 Food Being Prepared!",
        "COOKING": "👨‍🍳 Cooking in Progress!",
        "PACKED": "📦 Items Packed & Ready!",
        "SHIPPED": "🚴 Out for Delivery!",
        "ARRIVING_SOON": "🛵 Delivery Partner Arriving in 2 Mins!",
        "DELIVERED": "🎉 Order Delivered Successfully!",
        "CANCELLED": "❌ Order Cancelled",
    }

    stage_bodies = {
        "CONFIRMED": f"Store has accepted order #{base_order_no} and preparation has started.",
        "PREPARING": f"The kitchen is freshly preparing your dishes for order #{base_order_no}.",
        "COOKING": f"Chefs are putting final touches on order #{base_order_no}.",
        "PACKED": f"Order #{base_order_no} is packed and ready for dispatch.",
        "SHIPPED": f"Your delivery partner has picked up order #{base_order_no} and is on the way! ⚡",
        "ARRIVING_SOON": f"Your delivery partner is right around the corner (~500m away). Get ready to collect order #{base_order_no}!",
        "DELIVERED": f"Your order #{base_order_no} has arrived. Enjoy your meal / groceries!",
        "CANCELLED": f"Order #{base_order_no} has been cancelled.",
    }

    status_title = stage_titles.get(st_val, f"Order #{base_order_no} Update 🔔")
    status_body = stage_bodies.get(st_val, f"Your FastMinute order #{base_order_no} is now {st_val}.")

    cust_phone = None
    if hasattr(order, "customerPhone") and order.customerPhone:
        cust_phone = order.customerPhone
    else:
        try:
            if order.address and getattr(order.address, "phone", None):
                cust_phone = order.address.phone
            elif order.user and getattr(order.user, "phone", None):
                cust_phone = order.user.phone
        except Exception:
            pass

    # 🚨 DISPATCH RIDER ALARM IF RIDER WAS ASSIGNED DURING THIS STATUS UPDATE
    if order.deliveryUserId and (has_duid or "deliveryUserId" in payload or target_status == OrderStatus.SHIPPED):
        background_tasks.add_task(
            dispatch_rider_assignment_notification,
            order.id,
            order.readableId,
            order.deliveryUserId,
            order.status.value,
            float(order.total or 0.0),
            order.storeId
        )

    # 👨‍🍳 DISPATCH KITCHEN BUZZER ALARM WHEN ADMIN VERIFICATION IS DONE
    if order.restaurantId and target_status in [OrderStatus.CONFIRMED, OrderStatus.PENDING]:
        background_tasks.add_task(
            dispatch_restaurant_order_verified_notification,
            order.id,
            order.readableId,
            order.restaurantId,
            order.shopName,
            float(order.total or 0.0)
        )

    background_tasks.add_task(
        send_pwa_notification_to_user,
        order.userId,
        status_title,
        status_body,
        {
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "type": "ORDER_STATUS_UPDATE",
            "screen": "order-tracking",
            "role": "CUSTOMER",
            "isLiveTracking": "true",
        },
        db,
        cust_phone
    )

    # Strict outlet-isolated notifications (Never leak food order updates to grocery pickers, or vice versa)
    background_tasks.add_task(
        dispatch_isolated_status_update_notifications,
        order.id,
        order.readableId,
        order.restaurantId,
        order.shopName,
        st_val,
        order.storeId,
        order.deliveryUserId
    )

    deliv_user_dict = None
    if order.deliveryUserId:
        try:
            du_stmt = select(User).where(User.id == order.deliveryUserId)
            du_res = await db.execute(du_stmt)
            du_obj = du_res.scalars().first()
            if du_obj:
                deliv_user_dict = {"name": du_obj.name, "phone": du_obj.phone}
        except Exception:
            pass

    return {
        "id": order.id,
        "readableId": order.readableId,
        "status": order.status.value,
        "total": float(order.total),
        "paymentMethod": order.paymentMethod.value,
        "paymentStatus": order.paymentStatus.value,
        "estimatedDelivery": to_iso_utc(order.estimatedDelivery),
        "createdAt": to_iso_utc(order.createdAt),
        "updatedAt": to_iso_utc(order.updatedAt),
        "deliveryPhoto": order.deliveryPhoto,
        "deliveryLat": order.deliveryLat,
        "deliveryLng": order.deliveryLng,
        "deliveryMethod": order.deliveryMethod,
        "deliveryUserId": order.deliveryUserId,
        "assignedPickerId": order.assignedPickerId,
        "assignedChefId": order.assignedChefId,
        "confirmedAt": to_iso_utc(order.confirmedAt),
        "packedAt": to_iso_utc(order.packedAt),
        "shippedAt": to_iso_utc(order.shippedAt),
        "deliveredAt": to_iso_utc(order.deliveredAt),
        "shopName": order.shopName,
        "shopPhone": order.shopPhone,
        "notes": order.notes,
        "couponCode": order.couponCode,
        "deliveryUser": deliv_user_dict,
    }


@router.patch("/{order_id}/status")
async def update_order_status_alias(
    request: Request,
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Alias route for status updates.
    """
    return await update_order(request=request, id=order_id, payload=payload, current_user=current_user, db=db, background_tasks=background_tasks)


@router.delete("/cancelled-orders")
async def delete_all_cancelled_orders(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Purge all cancelled orders and their child items from database. (ADMIN ONLY)
    """
    role = current_user.get("role")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only ADMIN can bulk delete cancelled orders")

    res = await db.execute(select(Order.id).where(Order.status == OrderStatus.CANCELLED))
    cancelled_ids = list(res.scalars().all())

    if not cancelled_ids:
        return {"message": "No cancelled orders found", "deletedCount": 0}

    await db.execute(delete(OrderItem).where(OrderItem.orderId.in_(cancelled_ids)))
    await db.execute(delete(Order).where(Order.id.in_(cancelled_ids)))
    await db.commit()

    return {"message": f"Successfully deleted {len(cancelled_ids)} cancelled orders", "deletedCount": len(cancelled_ids)}


@router.patch("/{id}/payment")
async def update_order_payment(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Admin route to edit/override order payment method (COD, UPI, CARD) and adjust Rider Cash In Hand.
    """
    role = current_user.get("role")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only ADMIN can edit order payment details")

    stmt = select(Order).where(Order.id == id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_method = payload.get("paymentMethod")
    new_status = payload.get("paymentStatus")
    cash_collected = payload.get("cashAmount")

    old_method = order.paymentMethod.value
    order_total = float(order.total)

    if new_method:
        try:
            order.paymentMethod = PaymentMethod(new_method.upper())
        except ValueError:
            pass

    if new_status:
        try:
            order.paymentStatus = PaymentStatus(new_status.upper())
        except ValueError:
            pass

    # Adjust Rider Wallet if rider was assigned
    if order.deliveryUserId:
        wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
        wallet_res = await db.execute(wallet_stmt)
        wallet = wallet_res.scalars().first()

        if wallet:
            # If changing from COD to UPI -> reduce cashInHand by order_total
            if old_method == "COD" and new_method in ["UPI", "CARD", "ONLINE"]:
                wallet.cashInHand = max(0.0, float(wallet.cashInHand) - order_total)
            # If changing from UPI to COD -> add order_total to cashInHand
            elif old_method != "COD" and new_method == "COD":
                wallet.cashInHand = float(wallet.cashInHand) + order_total

            # If explicit custom cashAmount provided
            if cash_collected is not None:
                wallet.cashInHand = max(0.0, float(cash_collected))

    await db.commit()
    await db.refresh(order)
    clear_order_cache(order.id)
    if order.combinedId:
        clear_order_cache(order.combinedId)

    return {
        "message": "Order payment updated successfully",
        "orderId": order.id,
        "paymentMethod": order.paymentMethod.value,
        "paymentStatus": order.paymentStatus.value
    }


@router.post("/{id}/convert-to-cod")
async def convert_order_to_cod(
    id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Customer / Staff fallback: Convert an unpaid online order to Cash on Delivery (COD).
    Updates order status to CONFIRMED so preparation can begin immediately.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")

    clean_id = id.strip()
    stmt = select(Order).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_owner = bool(user_id and order.userId == user_id)
    is_admin = role == "ADMIN"
    if not is_owner and not is_admin and user_id:
        raise HTTPException(status_code=403, detail="Unauthorized to modify this order")

    if order.paymentStatus == PaymentStatus.PAID:
        raise HTTPException(status_code=400, detail="Order has already been paid online")

    if order.status == OrderStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Order has been cancelled and cannot be converted")

    now = datetime.utcnow()

    # If part of combined order group, convert all companion sub-orders
    if order.combinedId:
        combined_stmt = select(Order).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(combined_stmt)
        related_orders = comb_res.scalars().all()
        for o in related_orders:
            o.paymentMethod = PaymentMethod.COD
            o.paymentStatus = PaymentStatus.PENDING
            o.status = OrderStatus.CONFIRMED
            o.confirmedAt = now
            o.updatedAt = now
    else:
        order.paymentMethod = PaymentMethod.COD
        order.paymentStatus = PaymentStatus.PENDING
        order.status = OrderStatus.CONFIRMED
        order.confirmedAt = now
        order.updatedAt = now

    await db.commit()
    await db.refresh(order)
    clear_order_cache(order.id)
    if order.combinedId:
        clear_order_cache(order.combinedId)

    # Broadcast real-time WebSocket update
    try:
        await manager.broadcast_to_channel("general", {
            "type": "order-converted-cod",
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "paymentMethod": "COD"
        })
    except Exception as ws_err:
        logger.warning(f"Failed to broadcast convert-to-cod via websocket: {ws_err}")

    return {
        "success": True,
        "message": "Order converted to Cash on Delivery successfully",
        "orderId": order.id,
        "status": order.status.value,
        "paymentMethod": "COD"
    }


def normalize_restaurant_id(rid: Optional[str]) -> Optional[str]:
    if not rid:
        return None
    r = str(rid).strip().lower()
    if "as-restaurant" in r or "as-cafe" in r or "101" in r or "cms2p1lap" in r:
        return "REST-101"
    if "wedson" in r or "102" in r:
        return "REST-102"
    if "bal-udyan" in r or "103" in r or "cmsbhxb6a" in r:
        return "REST-103"
    if "hot-pizza" in r or "pizza-lovers" in r or "pizza lover" in r or "104" in r:
        return "REST-104"
    if "zayka" in r or "105" in r or "0b2470fa" in r:
        return "REST-105"
    if "radha" in r or "106" in r:
        return "REST-106"
    return str(rid).strip()


@router.post("/{id}/edit")
async def edit_order(
    id: str,
    payload: Dict[str, Any] = Body(...),
    request: Request = None,
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Staff / Admin Order Editing Endpoint.
    Supports single-domain editing as well as multi-domain order splitting (-G, -R, -R2)
    with combined delivery fee threshold management.
    """
    effective_user_id = current_user.get("id") if current_user else None
    effective_role = (current_user.get("role") or "").upper() if current_user else ""
    assigned_restaurant_id = current_user.get("assignedRestaurantId") if current_user else None

    # Fallback: check x-user-id header ONLY for verified internal service callers
    if not effective_role or effective_role == "USER":
        x_internal_secret = request.headers.get("x-internal-secret") if request else None
        internal_secret = os.getenv("INTERNAL_API_SECRET", "").strip()
        is_internal_service = bool(internal_secret and x_internal_secret == internal_secret)
        if is_internal_service:
            header_user_id = request.headers.get("x-user-id") if request else None
            if header_user_id and not header_user_id.startswith("mock-id-"):
                u_stmt = select(User).where(User.id == header_user_id)
                u_res = await db.execute(u_stmt)
                db_user = u_res.scalars().first()
                if db_user and not getattr(db_user, "isBlocked", False):
                    effective_user_id = db_user.id
                    effective_role = db_user.role.value if hasattr(db_user.role, "value") else str(db_user.role)
                    assigned_restaurant_id = db_user.assignedRestaurantId

    allowed_roles = ["ADMIN", "CHEF", "PICKER", "RESTAURANT_OWNER", "SUPER_ADMIN", "MANAGER"]
    if effective_role not in allowed_roles:
        raise HTTPException(status_code=403, detail="Unauthorized: insufficient role to edit orders")

    updated_items = payload.get("updatedItems")
    if not isinstance(updated_items, list):
        raise HTTPException(status_code=400, detail="updatedItems must be an array")

    out_of_stock_product_ids = payload.get("outOfStockProductIds") or []

    # 1. Fetch current order by id or readableId
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.user)
    ).where(or_(Order.id == id, Order.readableId == id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Outlet isolation check for chef / restaurant owner
    if effective_role in ["CHEF", "RESTAURANT_OWNER"]:
        if assigned_restaurant_id and order.restaurantId:
            norm_assigned = normalize_restaurant_id(assigned_restaurant_id)
            norm_order_rest = normalize_restaurant_id(order.restaurantId)
            if norm_assigned and norm_order_rest and norm_assigned != norm_order_rest:
                raise HTTPException(status_code=403, detail="You can only edit orders for your assigned restaurant")

    order_status_val = order.status.value if hasattr(order.status, "value") else str(order.status)
    if order_status_val in ["DELIVERED", "CANCELLED"]:
        raise HTTPException(status_code=400, detail=f"Order is already {order_status_val} and cannot be edited")
    if effective_role not in ["ADMIN", "SUPER_ADMIN"]:
        if order_status_val in ["PACKED", "SHIPPED"]:
            raise HTTPException(status_code=400, detail=f"Order is already {order_status_val} and cannot be edited")

    # 1B. Fetch existing companion orders early for stock restoration and discount synchronization
    existing_companions = []
    base_rid = re.sub(r"-(G|R\d*)$", "", order.readableId or "", flags=re.IGNORECASE).strip()
    c_conds = []
    if order.combinedId:
        c_conds.append(Order.combinedId == order.combinedId)
    if base_rid and len(base_rid) >= 2:
        c_conds.append(and_(Order.userId == order.userId, Order.readableId.like(f"{base_rid}-%")))
    if c_conds:
        c_stmt = select(Order).options(selectinload(Order.items)).where(
            and_(or_(*c_conds), Order.id != order.id)
        )
        c_res = await db.execute(c_stmt)
        existing_companions = list(c_res.scalars().all())

    # Helper: Ensure readableId is globally unique in orders table to prevent UniqueViolationError
    async def resolve_unique_readable_id(candidate_id: Optional[str], target_order_id: Optional[str], order_type: OrderType) -> str:
        clean = (candidate_id or "").strip()
        if not clean or clean in ["-G", "-R", "-R1", "-R2", "-R3"]:
            try:
                seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
                clean = str(seq_res.scalar())
            except Exception:
                clean = f"FK-{int(time.time() * 1000) % 1000000:06d}"
            suffix = "-G" if order_type == OrderType.GROCERY else "-R"
            clean = f"{clean}{suffix}"

        curr = clean
        for _ in range(10):
            stmt = select(Order.id).where(Order.readableId == curr)
            if target_order_id:
                stmt = stmt.where(Order.id != target_order_id)
            res = await db.execute(stmt)
            if not res.scalar_one_or_none():
                return curr

            # Collision! Fetch fresh DB sequence to generate a guaranteed unique readableId
            try:
                seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
                next_seq = seq_res.scalar()
                suffix_match = re.search(r"-(G|R\d*)$", curr, flags=re.IGNORECASE)
                suffix_str = suffix_match.group(0).upper() if suffix_match else ("-G" if order_type == OrderType.GROCERY else "-R")
                curr = f"{next_seq}{suffix_str}"
            except Exception:
                curr = f"{clean}_{uuid.uuid4().hex[:4]}"

        return curr

    # 2. Adjust out of stock products if provided
    if out_of_stock_product_ids and isinstance(out_of_stock_product_ids, list):
        for prod_id in out_of_stock_product_ids:
            p_stmt = select(Product).where(Product.id == prod_id)
            p_res = await db.execute(p_stmt)
            p_obj = p_res.scalars().first()
            if p_obj:
                p_obj.isAvailable = False
                p_obj.stock = 0

    # 3. Revert stock of existing order items across both this order and its companions
    all_old_items_to_revert = list(order.items or [])
    for comp in existing_companions:
        all_old_items_to_revert.extend(comp.items or [])

    for item in all_old_items_to_revert:
        if not item.productId:
            continue
        p_stmt = select(Product).where(Product.id == item.productId)
        p_res = await db.execute(p_stmt)
        p_obj = p_res.scalars().first()
        if not p_obj or p_obj.restaurantId:
            continue

        if item.selectedVariant and p_obj.variants and isinstance(p_obj.variants, list):
            updated_variants = []
            for v in p_obj.variants:
                if isinstance(v, dict) and v.get("name") == item.selectedVariant:
                    v_copy = dict(v)
                    v_copy["stock"] = int(v_copy.get("stock", 0)) + (item.quantity or 1)
                    updated_variants.append(v_copy)
                else:
                    updated_variants.append(v)
            new_total = sum(int(v.get("stock", 0)) for v in updated_variants if isinstance(v, dict))
            p_obj.variants = updated_variants
            p_obj.stock = new_total
        else:
            p_obj.stock = (p_obj.stock or 0) + (item.quantity or 1)

    # 4. Classify new updated items into grocery vs restaurant
    grocery_group = []
    restaurant_groups = {}

    for item in updated_items:
        if not item or not isinstance(item, dict):
            continue
        qty = int(item.get("quantity") or 1)
        if qty <= 0:
            continue

        prod_id = item.get("productId")
        product = None
        if prod_id and isinstance(prod_id, str) and not prod_id.startswith("custom_"):
            prod_stmt = select(Product).options(
                selectinload(Product.restaurant),
                selectinload(Product.category)
            ).where(Product.id == prod_id)
            prod_res = await db.execute(prod_stmt)
            product = prod_res.scalars().first()

        item_price = float(product.price) if product else 0.0
        if effective_role in ["ADMIN", "SUPER_ADMIN"]:
            if item.get("price") is not None:
                item_price = max(0.0, float(item["price"]))
        elif not product and item.get("price") is not None:
            item_price = max(0.0, float(item["price"]))

        item_name = item.get("name") or (product.name if product else "Item")
        item_rest_id = str(item.get("restaurantId") or "").strip() or None
        item_shop_name = str(item.get("shopName") or "").strip() or None

        is_restaurant = False
        resolved_rest_id = None
        resolved_shop_name = None
        resolved_shop_phone = None

        if product:
            raw_rest_id = product.restaurantId or (product.restaurant.id if product.restaurant else None)
            if raw_rest_id:
                is_restaurant = True
                resolved_rest_id = normalize_restaurant_id(raw_rest_id) or raw_rest_id
                resolved_shop_name = product.restaurant.name if product.restaurant else item_shop_name or "Restaurant"
                resolved_shop_phone = product.restaurant.ownerPhone if product.restaurant else None
            else:
                is_restaurant = False
                resolved_rest_id = None
                resolved_shop_name = "FastMinute Grocery"
                resolved_shop_phone = None
        else:
            explicit_rest_id = normalize_restaurant_id(item_rest_id) if item_rest_id else None
            if explicit_rest_id:
                is_restaurant = True
                resolved_rest_id = explicit_rest_id
                resolved_shop_name = item_shop_name or "Restaurant"
                resolved_shop_phone = order.shopPhone
            elif str(order.orderType.value if hasattr(order.orderType, "value") else order.orderType) == "RESTAURANT" and order.restaurantId and effective_role in ["CHEF", "RESTAURANT_OWNER"]:
                is_restaurant = True
                resolved_rest_id = normalize_restaurant_id(order.restaurantId) or order.restaurantId
                resolved_shop_name = order.shopName or "Restaurant"
                resolved_shop_phone = order.shopPhone
            else:
                is_restaurant = False
                resolved_rest_id = None
                resolved_shop_name = "FastMinute Grocery"
                resolved_shop_phone = None

        classified = {
            "item": item,
            "product": product,
            "itemPrice": item_price,
            "itemQty": qty,
            "itemName": item_name,
            "isRestaurant": is_restaurant,
            "restaurantId": resolved_rest_id,
            "shopName": resolved_shop_name,
            "shopPhone": resolved_shop_phone
        }

        if is_restaurant:
            key = resolved_rest_id or normalize_restaurant_id(order.restaurantId) or "REST-101"
            if key not in restaurant_groups:
                restaurant_groups[key] = {
                    "items": [],
                    "shopName": resolved_shop_name or order.shopName or "Restaurant",
                    "shopPhone": resolved_shop_phone or order.shopPhone
                }
            restaurant_groups[key]["items"].append(classified)
        else:
            grocery_group.append(classified)

    has_grocery_items = len(grocery_group) > 0
    restaurant_keys = list(restaurant_groups.keys())
    has_restaurant_items = len(restaurant_keys) > 0
    is_mixed = (has_grocery_items and has_restaurant_items) or len(restaurant_keys) > 1 or bool(order.combinedId and (has_grocery_items or has_restaurant_items))

    # Fetch fee settings
    settings_stmt = select(StoreSetting)
    settings_res = await db.execute(settings_stmt)
    settings_rows = settings_res.scalars().all()
    settings_map = {s.key: s.value for s in settings_rows}

    delivery_fee_setting = float(settings_map.get("delivery_fee") or 25.0)
    misc_fee_setting = float(settings_map.get("misc_fee") or 5.0)

    async def insert_items_for_order(target_order_id: str, items_list: list) -> float:
        subtotal = 0.0
        for ci in items_list:
            subtotal += ci["itemPrice"] * ci["itemQty"]
            order_item = OrderItem(
                id=str(uuid.uuid4()),
                orderId=target_order_id,
                productId=ci["product"].id if ci["product"] else None,
                name=ci["itemName"],
                price=ci["itemPrice"],
                quantity=ci["itemQty"],
                selectedVariant=ci["item"].get("selectedVariant"),
                imageUrl=ci["item"].get("imageUrl") or (ci["product"].imageUrl if ci["product"] else None),
                notes=ci["item"].get("notes"),
                costPrice=(lambda p, v_name: (
                    next((float(v.get("costPrice") or v.get("cp") or 0.0) for v in p.variants if isinstance(v, dict) and str(v.get("name") or "").strip().lower() == str(v_name or "").strip().lower() and (v.get("costPrice") or v.get("cp"))), None)
                    or next((float(v.get("costPrice") or v.get("cp") or 0.0) for v in p.variants if isinstance(v, dict) and (v.get("costPrice") or v.get("cp"))), None)
                    or float(p.costPrice or 0.0)
                ) if p and p.variants and isinstance(p.variants, list) else float(p.costPrice or 0.0) if p else 0.0)(ci["product"], ci["item"].get("selectedVariant"))
            )
            db.add(order_item)

            # Deduct stock for grocery items
            if ci["product"] and not ci["isRestaurant"]:
                p_item = ci["product"]
                if ci["item"].get("selectedVariant") and p_item.variants and isinstance(p_item.variants, list):
                    updated_v = []
                    for v in p_item.variants:
                        if isinstance(v, dict) and v.get("name") == ci["item"]["selectedVariant"]:
                            v_copy = dict(v)
                            v_copy["stock"] = max(0, int(v_copy.get("stock", 0)) - ci["itemQty"])
                            updated_v.append(v_copy)
                        else:
                            updated_v.append(v)
                    p_item.variants = updated_v
                    p_item.stock = sum(int(v.get("stock", 0)) for v in updated_v if isinstance(v, dict))
                else:
                    p_item.stock = max(0, (p_item.stock or 0) - ci["itemQty"])

        return subtotal

    # =====================================================================
    # SINGLE-DOMAIN PATH
    # =====================================================================
    if not is_mixed:
        # Delete old items
        await db.execute(delete(OrderItem).where(OrderItem.orderId == order.id))

        all_items = grocery_group if has_grocery_items else [item for g in restaurant_groups.values() for item in g["items"]]
        subtotal_val = await insert_items_for_order(order.id, all_items)

        dynamic_order_type = order.orderType
        dynamic_restaurant_id = order.restaurantId
        dynamic_shop_name = order.shopName
        dynamic_shop_phone = order.shopPhone

        if has_restaurant_items:
            first_key = normalize_restaurant_id(restaurant_keys[0]) or restaurant_keys[0]
            first_group = restaurant_groups.get(restaurant_keys[0]) or restaurant_groups.get(first_key) or list(restaurant_groups.values())[0]
            dynamic_order_type = OrderType.RESTAURANT
            dynamic_restaurant_id = first_key

            rest_stmt = select(Restaurant).where(Restaurant.id == first_key)
            rest_res = await db.execute(rest_stmt)
            db_rest = rest_res.scalars().first()

            dynamic_shop_name = db_rest.name if db_rest else (first_group.get("shopName") or "Restaurant")
            dynamic_shop_phone = db_rest.ownerPhone if db_rest else first_group.get("shopPhone")
        elif has_grocery_items:
            dynamic_order_type = OrderType.GROCERY
            dynamic_restaurant_id = None
            dynamic_shop_name = "FastMinute Grocery"
            dynamic_shop_phone = None

        # Clean up any orphaned companion orders since this is now single-domain
        for ec in existing_companions:
            await db.execute(delete(OrderItem).where(OrderItem.orderId == ec.id))
            await db.execute(delete(Order).where(Order.id == ec.id))
        order.combinedId = None

        # Delivery fee calculation
        threshold = float(settings_map.get("grocery_free_delivery_threshold") or 200.0)
        if str(dynamic_order_type) == "RESTAURANT":
            threshold = float(settings_map.get("cafe_free_delivery_threshold") or 200.0)

        calc_delivery_fee = 0.0
        calc_misc_fee = 0.0
        if str(order.deliveryMethod) == "DELIVERY":
            calc_delivery_fee = 0.0 if subtotal_val >= threshold else delivery_fee_setting
            calc_misc_fee = float(settings_map.get("misc_fee") or 5.0)

        total_discount = float(order.discount or 0.0) + sum(float(ec.discount or 0.0) for ec in existing_companions)
        clean_discount = min(total_discount, subtotal_val)
        taxes_val = 0.0
        total_val = max(0.0, round(subtotal_val + calc_delivery_fee + taxes_val + calc_misc_fee - clean_discount, 2))

        # Check online payment difference for single-domain
        orig_paid = float(order.total or 0.0) if str(getattr(order.paymentStatus, "value", order.paymentStatus)).upper() == "PAID" else 0.0
        if orig_paid > 0:
            diff = round(orig_paid - total_val, 2)
            if diff > 0:
                order.refundAmount = round(float(order.refundAmount or 0.0) + diff, 2)
                notes_str = str(order.notes or "")
                if f"Refund due: Rs.{diff}" not in notes_str:
                    order.notes = (notes_str + f" | [Item swap: Rs.{diff:.2f} refund/credit due]").strip(" |")
            elif diff < 0:
                extra = abs(diff)
                notes_str = str(order.notes or "")
                if f"Extra payable: Rs.{extra}" not in notes_str:
                    order.notes = (notes_str + f" | [Item swap: Rs.{extra:.2f} extra payable on delivery]").strip(" |")

        order.subtotal = subtotal_val
        order.discount = clean_discount
        order.deliveryFee = calc_delivery_fee
        order.miscFee = calc_misc_fee
        order.taxes = taxes_val
        order.total = total_val
        order.orderType = dynamic_order_type
        order.restaurantId = dynamic_restaurant_id
        order.shopName = dynamic_shop_name
        order.shopPhone = dynamic_shop_phone

        base_clean = re.sub(r"-(G|R\d*)$", "", order.readableId or "", flags=re.IGNORECASE).strip()
        candidate_rid = f"{base_clean}-R" if dynamic_order_type == OrderType.RESTAURANT else base_clean
        order.readableId = await resolve_unique_readable_id(candidate_rid, order.id, dynamic_order_type)

        if str(dynamic_order_type) == "GROCERY":
            order.assignedChefId = None
        elif str(dynamic_order_type) == "RESTAURANT":
            order.assignedPickerId = None

        await db.commit()
        await db.refresh(order)

        # Broadcast SSE / WebSocket
        try:
            await manager.broadcast_to_channel("general", {
                "type": "order-edited",
                "orderId": order.id,
                "readableId": order.readableId,
                "shopName": dynamic_shop_name,
                "restaurantId": dynamic_restaurant_id,
                "total": total_val,
                "orderType": str(dynamic_order_type.value if hasattr(dynamic_order_type, "value") else dynamic_order_type)
            })
        except Exception:
            pass

        return {
            "success": True,
            "id": order.id,
            "orderId": order.id,
            "readableId": order.readableId,
            "total": total_val,
            "orderType": str(dynamic_order_type.value if hasattr(dynamic_order_type, "value") else dynamic_order_type),
            "restaurantId": dynamic_restaurant_id,
            "shopName": dynamic_shop_name
        }

    # =====================================================================
    # MIXED-DOMAIN PATH (Order Splitting & Multi-Domain Swap)
    # =====================================================================
    base_readable_id = re.sub(r"-(G|R\d*)$", "", order.readableId or "", flags=re.IGNORECASE).strip()
    if not base_readable_id:
        try:
            seq_res = await db.execute(text("SELECT nextval('order_readable_id_seq')::int as nextval"))
            base_readable_id = str(seq_res.scalar())
        except Exception:
            base_readable_id = f"FK-{int(time.time() * 1000) % 1000000:06d}"
    combined_id = order.combinedId or f"combined_{uuid.uuid4().hex[:9]}_{int(datetime.utcnow().timestamp())}"
    current_is_grocery = (str(order.orderType.value if hasattr(order.orderType, "value") else order.orderType) == "GROCERY") or not order.restaurantId

    sub_orders = []
    if has_grocery_items:
        existing_grocery = order if current_is_grocery else next((c for c in existing_companions if str(c.orderType.value if hasattr(c.orderType, "value") else c.orderType) == "GROCERY"), None)
        sub_orders.append({
            "orderId": existing_grocery.id if existing_grocery else None,
            "items": grocery_group,
            "type": OrderType.GROCERY,
            "restaurantId": None,
            "shopName": "FastMinute Grocery",
            "shopPhone": None,
            "readableId": f"{base_readable_id}-G",
            "isNew": existing_grocery is None
        })

    rest_idx = 0
    for r_id in restaurant_keys:
        rest_idx += 1
        r_group = restaurant_groups[r_id]
        normalized_r_id = normalize_restaurant_id(r_id)
        existing_rest = order if (not current_is_grocery and normalize_restaurant_id(order.restaurantId) == normalized_r_id) else next(
            (c for c in existing_companions if str(c.orderType.value if hasattr(c.orderType, "value") else c.orderType) == "RESTAURANT" and normalize_restaurant_id(c.restaurantId) == normalized_r_id),
            None
        )
        suffix = "-R" if rest_idx == 1 else f"-R{rest_idx}"
        sub_orders.append({
            "orderId": existing_rest.id if existing_rest else None,
            "items": r_group["items"],
            "type": OrderType.RESTAURANT,
            "restaurantId": normalized_r_id,
            "shopName": r_group["shopName"],
            "shopPhone": r_group["shopPhone"],
            "readableId": f"{base_readable_id}{suffix}",
            "isNew": existing_rest is None
        })

    # Ensure original order is claimed by one of the sub-orders
    if not any(s["orderId"] == order.id for s in sub_orders) and sub_orders:
        cand = next((s for s in sub_orders if s["type"] == order.orderType and s["orderId"] is None), None) or \
               next((s for s in sub_orders if s["orderId"] is None), None) or sub_orders[0]
        cand["orderId"] = order.id
        cand["isNew"] = False

    prepared = []
    all_order_ids = []

    for spec in sub_orders:
        target_id = spec["orderId"]
        spec["readableId"] = await resolve_unique_readable_id(spec.get("readableId"), target_id, spec["type"])
        if spec["isNew"]:
            new_ord = Order(
                id=str(uuid.uuid4()),
                userId=order.userId,
                readableId=spec["readableId"],
                addressId=order.addressId,
                combinedId=combined_id,
                orderType=spec["type"],
                status=order.status,
                subtotal=0.0,
                discount=0.0,
                deliveryFee=0.0,
                taxes=0.0,
                miscFee=0.0,
                total=0.0,
                paymentMethod=order.paymentMethod,
                paymentStatus=order.paymentStatus,
                deliveryMethod=order.deliveryMethod,
                isB2B=order.isB2B,
                storeId=order.storeId,
                couponCode=order.couponCode,
                shopName=spec["shopName"],
                shopPhone=spec["shopPhone"],
                restaurantId=spec["restaurantId"],
                deliveryLat=order.deliveryLat,
                deliveryLng=order.deliveryLng,
                deliveryUserId=order.deliveryUserId,
                estimatedDelivery=order.estimatedDelivery,
                notes=order.notes,
                assignedPickerId=order.assignedPickerId if spec["type"] == OrderType.GROCERY else None,
                assignedChefId=order.assignedChefId if spec["type"] == OrderType.RESTAURANT else None,
            )
            db.add(new_ord)
            await db.flush()
            target_id = new_ord.id

        await db.execute(delete(OrderItem).where(OrderItem.orderId == target_id))
        all_order_ids.append(target_id)
        subtotal_val = await insert_items_for_order(target_id, spec["items"])
        prepared.append({
            "targetOrderId": target_id,
            "spec": spec,
            "subtotalVal": subtotal_val
        })

    # Global combined delivery fee calculation
    total_combined_subtotal = sum(p["subtotalVal"] for p in prepared)
    combined_threshold = float(settings_map.get("delivery_threshold_tier1", settings_map.get("grocery_free_delivery_threshold", 149.0)))
    is_combined_free = (str(order.deliveryMethod) != "DELIVERY") or (total_combined_subtotal >= combined_threshold)

    grocery_in_prepared = any(p["spec"]["type"] == OrderType.GROCERY for p in prepared)
    delivery_fee_charged = is_combined_free
    misc_fee_charged = str(order.deliveryMethod) != "DELIVERY"

    # Discount preservation and proportional apportionment
    total_combined_discount = float(order.discount or 0.0) + sum(float(ec.discount or 0.0) for ec in existing_companions)
    remaining_discount = total_combined_discount

    primary_total = 0.0
    primary_order_type = ""
    primary_restaurant_id = None
    primary_shop_name = ""

    final_combined_id = combined_id if len(prepared) > 1 else None

    for idx, p in enumerate(prepared):
        calc_del = 0.0
        calc_misc = 0.0
        p_type = p["spec"]["type"]

        if p_type == OrderType.GROCERY:
            if not delivery_fee_charged and p["subtotalVal"] > 0:
                calc_del = delivery_fee_setting
                delivery_fee_charged = True
            if not misc_fee_charged and p["subtotalVal"] > 0:
                calc_misc = misc_fee_setting
                misc_fee_charged = True
        elif p_type == OrderType.RESTAURANT:
            if not misc_fee_charged and p["subtotalVal"] > 0:
                calc_misc = float(settings_map.get("packaging_fee") or 5.0)
                misc_fee_charged = True
            if not grocery_in_prepared and not delivery_fee_charged and p["subtotalVal"] > 0:
                calc_del = delivery_fee_setting
                delivery_fee_charged = True

        disc = 0.0
        if total_combined_subtotal > 0 and remaining_discount > 0:
            if idx == len(prepared) - 1:
                disc = min(remaining_discount, p["subtotalVal"])
            else:
                ratio = p["subtotalVal"] / total_combined_subtotal
                disc = min(round(total_combined_discount * ratio, 2), p["subtotalVal"])
                remaining_discount = max(0.0, round(remaining_discount - disc, 2))

        tot = max(0.0, round(p["subtotalVal"] + calc_del + calc_misc - disc, 2))
        p["totalVal"] = tot

        u_ord_stmt = select(Order).where(Order.id == p["targetOrderId"])
        u_ord_res = await db.execute(u_ord_stmt)
        target_ord = u_ord_res.scalars().first()

        target_ord.combinedId = final_combined_id
        target_ord.readableId = p["spec"]["readableId"]
        target_ord.subtotal = p["subtotalVal"]
        target_ord.discount = disc
        target_ord.deliveryFee = calc_del
        target_ord.miscFee = calc_misc
        target_ord.total = tot
        target_ord.orderType = p["spec"]["type"]
        target_ord.restaurantId = p["spec"]["restaurantId"]
        target_ord.shopName = p["spec"]["shopName"]

        if p["targetOrderId"] == order.id:
            primary_total = tot
            primary_order_type = str(p["spec"]["type"].value if hasattr(p["spec"]["type"], "value") else p["spec"]["type"])
            primary_restaurant_id = p["spec"]["restaurantId"]
            primary_shop_name = p["spec"]["shopName"]

    order.combinedId = final_combined_id

    # Track online payment difference (refund or extra payable)
    total_original_paid = (float(order.total or 0.0) if str(getattr(order.paymentStatus, "value", order.paymentStatus)).upper() == "PAID" else 0.0) + \
                          sum(float(ec.total or 0.0) for ec in existing_companions if str(getattr(ec.paymentStatus, "value", ec.paymentStatus)).upper() == "PAID")
    new_combined_total = sum(p["totalVal"] for p in prepared)
    if total_original_paid > 0:
        diff = round(total_original_paid - new_combined_total, 2)
        if diff > 0:
            order.refundAmount = round(float(order.refundAmount or 0.0) + diff, 2)
            existing_notes = str(order.notes or "")
            if f"Refund due: Rs.{diff}" not in existing_notes:
                order.notes = (existing_notes + f" | [Item swap: Rs.{diff:.2f} refund/credit due]").strip(" |")
        elif diff < 0:
            extra = abs(diff)
            existing_notes = str(order.notes or "")
            if f"Extra payable: Rs.{extra}" not in existing_notes:
                order.notes = (existing_notes + f" | [Item swap: Rs.{extra:.2f} extra payable on delivery]").strip(" |")

    # Clean up orphaned companion orders
    for ec in existing_companions:
        if ec.id not in all_order_ids:
            await db.execute(delete(OrderItem).where(OrderItem.orderId == ec.id))
            await db.execute(delete(Order).where(Order.id == ec.id))

    await db.commit()

    # Broadcast SSE / WebSocket to real-time consoles
    try:
        await manager.broadcast_to_channel("general", {
            "type": "order-edited",
            "orderId": order.id,
            "readableId": order.readableId,
            "combinedId": final_combined_id,
            "total": primary_total,
            "subOrders": [p["spec"]["readableId"] for p in prepared]
        })
        for p in prepared:
            if p["spec"]["restaurantId"]:
                await manager.broadcast_to_channel(f"restaurant_{p['spec']['restaurantId']}", {
                    "type": "order-edited",
                    "orderId": p["targetOrderId"],
                    "readableId": p["spec"]["readableId"],
                })
    except Exception:
        pass

    return {
        "success": True,
        "id": order.id,
        "orderId": order.id,
        "readableId": order.readableId,
        "combinedId": final_combined_id,
        "total": primary_total,
        "orderType": primary_order_type,
        "restaurantId": primary_restaurant_id,
        "shopName": primary_shop_name,
        "split": len(prepared) > 1,
        "subOrders": [
            {
                "orderId": p["targetOrderId"],
                "type": str(p["spec"]["type"].value if hasattr(p["spec"]["type"], "value") else p["spec"]["type"]),
                "readableId": p["spec"]["readableId"],
                "shopName": p["spec"]["shopName"],
                "total": p["totalVal"]
            }
            for p in prepared
        ]
    }

