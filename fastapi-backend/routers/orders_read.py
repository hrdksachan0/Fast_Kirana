"""Read-only Order endpoints: list_orders, get_order_details, and track_order."""
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
)

router = APIRouter()

@router.get("")
async def list_orders(
    is_all: bool = Query(False, alias="all"),
    storeId: Optional[str] = Query(None),
    userId: Optional[str] = Query(None),
    phone: Optional[str] = Query(None),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List user orders (normal user gets combined view; staff gets dashboard flat view).
    """
    try:
        if not current_user:
            return []

        auth_uid = current_user.get("id") or current_user.get("sub")
        role = (current_user.get("role") or "").upper()
        is_staff = role in ["ADMIN", "SUPER_ADMIN", "SUPERADMIN", "STORE_MANAGER", "CHEF", "PICKER", "DELIVERY"]
        can_query_any_customer = role in ["ADMIN", "SUPER_ADMIN", "SUPERADMIN", "STORE_MANAGER"]

        user_id = (userId or auth_uid) if can_query_any_customer else auth_uid
        if not user_id and not is_staff:
            return []

        if is_staff and is_all:
            is_superadmin = role in ["SUPER_ADMIN", "SUPERADMIN"]
            assigned_store = current_user.get("assignedStoreId") if current_user and not is_superadmin else None
            effective_store = assigned_store or storeId

            # Unassigned pickers or riders cannot view company-wide orders
            if role in ["PICKER", "DELIVERY"] and not assigned_store:
                return []

            stmt = select(Order, User).outerjoin(User, Order.userId == User.id).options(
                selectinload(Order.items),
                selectinload(Order.address)
            )

            if effective_store and effective_store != "all":
                if effective_store == "hub-209206":
                    stmt = stmt.where(or_(Order.storeId == effective_store, Order.storeId.is_(None)))
                else:
                    stmt = stmt.where(Order.storeId == effective_store)

            if role in ["CHEF", "RESTAURANT_OWNER"]:
                rest_id = current_user.get("assignedRestaurantId")
                if rest_id:
                    stmt = stmt.where(Order.restaurantId == rest_id)

            stmt = stmt.order_by(Order.createdAt.desc()).limit(1000)
            
            res = await db.execute(stmt)
            rows = res.all()

            orders_list = []
            for order, user in rows:
                orders_list.append({
                    "id": order.id,
                    "readableId": order.readableId,
                    "userId": order.userId,
                    "addressId": order.addressId,
                    "status": safe_enum_str(order.status, "PENDING"),
                    "subtotal": safe_float(order.subtotal),
                    "discount": safe_float(order.discount),
                    "deliveryFee": safe_float(order.deliveryFee),
                    "taxes": safe_float(order.taxes),
                    "miscFee": safe_float(order.miscFee),
                    "total": safe_float(order.total),
                    "paymentMethod": safe_enum_str(order.paymentMethod, "COD"),
                    "paymentStatus": safe_enum_str(order.paymentStatus, "PENDING"),
                    "estimatedDelivery": to_iso_utc(order.estimatedDelivery),
                    "createdAt": to_iso_utc(order.createdAt),
                    "updatedAt": to_iso_utc(order.updatedAt),
                    "deliveryMethod": order.deliveryMethod or "DELIVERY",
                    "isB2B": bool(order.isB2B),
                    "shopName": order.shopName,
                    "shopPhone": order.shopPhone,
                    "restaurantId": order.restaurantId,
                    "userName": user.name if user else None,
                    "userEmail": user.email if user else None,
                    "userPhone": order.shopPhone or (order.address.phone if order.address else (user.phone if user else None)),
                    "items": [{
                        "id": i.id,
                        "productId": i.productId,
                        "name": i.name,
                        "quantity": i.quantity,
                        "price": safe_float(i.price),
                        "imageUrl": i.imageUrl,
                        "selectedVariant": i.selectedVariant,
                        "notes": i.notes,
                        "restaurantId": order.restaurantId,
                        "isRestaurantItem": bool(order.restaurantId),
                        "type": "RESTAURANT" if order.restaurantId else "GROCERY",
                    } for i in order.items],
                    "address": {
                        "id": order.address.id,
                        "label": order.address.label,
                        "houseNo": order.address.houseNo,
                        "street": order.address.street,
                        "area": order.address.area,
                        "city": order.address.city,
                        "pincode": order.address.pincode,
                        "phone": order.address.phone
                    } if order.address else None
                })
            return orders_list

        # Normal user fetches their own orders (only admins/store managers may query arbitrary phone)
        email = (current_user.get("email") or "").lower().strip() if (current_user and not (can_query_any_customer and (userId or phone))) else ""
        raw_phone = (phone or current_user.get("phone")) if can_query_any_customer else current_user.get("phone")
        resolved_phone = get_last_10_digits(raw_phone) if raw_phone else ""

        # If user_id is provided but email/phone missing from session, fetch user profile from DB
        if user_id and not email and not resolved_phone:
            try:
                u_stmt = select(User).where(User.id == user_id)
                u_res = await db.execute(u_stmt)
                db_u = u_res.scalars().first()
                if db_u:
                    if db_u.email:
                        email = db_u.email.lower().strip()
                    if db_u.phone:
                        resolved_phone = get_last_10_digits(db_u.phone)
            except Exception as e:
                logger.warning(f"Could not load user profile for user_id={user_id}: {e}")

        # Find matching user IDs
        user_ids = {user_id} if user_id else set()
        if email or resolved_phone:
            u_filters = []
            if email:
                u_filters.append(func.lower(User.email) == email)
            if resolved_phone:
                u_filters.append(User.phone.like(f"%{resolved_phone}"))
            
            users_stmt = select(User.id).where(or_(*u_filters))
            users_res = await db.execute(users_stmt)
            user_ids.update(users_res.scalars().all())

        if not user_ids and not resolved_phone:
            return []

        # Query matching orders strictly by owner userId (never by shopPhone, which is the store/restaurant contact)
        orders_stmt = select(Order).options(
            selectinload(Order.items),
            selectinload(Order.address)
        )
        if not user_ids:
            return []

        orders_stmt = orders_stmt.where(Order.userId.in_(user_ids))
        orders_stmt = orders_stmt.order_by(Order.createdAt.desc())
        
        orders_res = await db.execute(orders_stmt)
        raw_orders = orders_res.scalars().all()

        # Customer grouping
        def get_combined_status(statuses: List[str]) -> str:
            upper = [str(s or "").upper().strip() for s in statuses]
            active = [s for s in upper if s != "CANCELLED"]
            if not active:
                return "CANCELLED"
            if "ADMIN_PENDING" in active:
                return "ADMIN_PENDING"
            if "PENDING" in active:
                return "PENDING"
            if "CONFIRMED" in active or "PREPARING" in active or "COOKING" in active:
                return "CONFIRMED"
            if "PACKED" in active:
                return "PACKED"
            if "SHIPPED" in active:
                return "SHIPPED"
            if active and not any(s != "DELIVERED" for s in active):
                return "DELIVERED"
            return active[0] if active else "PENDING"
            return active[0] if active else "PENDING"

        grouped_orders = []
        processed_ids = set()

        for ord in raw_orders:
            if ord.id in processed_ids:
                continue

            related = []
            for o in raw_orders:
                if o.id in processed_ids:
                    continue
                if o.id == ord.id:
                    related.append(o)
                elif ord.combinedId and o.combinedId == ord.combinedId:
                    related.append(o)
                else:
                    time_diff = abs((o.createdAt - ord.createdAt).total_seconds()) if o.createdAt and ord.createdAt else 999
                    if o.userId == ord.userId and time_diff <= 10:
                        related.append(o)

            for r in related:
                processed_ids.add(r.id)

            if len(related) == 1:
                o = related[0]
                grouped_orders.append({
                    "id": o.id,
                    "readableId": o.readableId,
                    "status": safe_enum_str(o.status, "PENDING"),
                    "subtotal": safe_float(o.subtotal),
                    "discount": safe_float(o.discount),
                    "deliveryFee": safe_float(o.deliveryFee),
                    "taxes": safe_float(o.taxes),
                    "miscFee": safe_float(o.miscFee),
                    "total": safe_float(o.total),
                    "paymentMethod": safe_enum_str(o.paymentMethod, "COD"),
                    "paymentStatus": safe_enum_str(o.paymentStatus, "PENDING"),
                    "deliveryMethod": o.deliveryMethod or "DELIVERY",
                    "createdAt": to_iso_utc(o.createdAt),
                    "shopName": (o.shopName.replace("FastKirana", "FastMinute") if o.shopName else ("FastMinute Dark Store" if not o.restaurantId else "Restaurant")),
                    "restaurantId": o.restaurantId,
                    "items": [{
                        "id": i.id,
                        "productId": i.productId,
                        "name": i.name,
                        "quantity": i.quantity,
                        "price": safe_float(i.price),
                        "imageUrl": i.imageUrl,
                        "selectedVariant": i.selectedVariant,
                        "notes": i.notes,
                        "restaurantId": o.restaurantId,
                        "isRestaurantItem": bool(o.restaurantId),
                        "type": "RESTAURANT" if o.restaurantId else "GROCERY",
                    } for i in o.items],
                    "address": {
                        "id": o.address.id,
                        "label": o.address.label,
                        "houseNo": o.address.houseNo,
                        "street": o.address.street,
                        "area": o.address.area,
                        "city": o.address.city,
                        "pincode": o.address.pincode,
                        "phone": o.address.phone
                    } if o.address else None,
                    "isCombined": False
                })
            else:
                main_order = next((r for r in related if safe_enum_str(r.orderType) != "RESTAURANT"), related[0])
                statuses = [safe_enum_str(r.status, "PENDING") for r in related]
                combined_status = get_combined_status(statuses)

                all_items = []
                seen_item_ids = set()
                for r in related:
                    for i in r.items:
                        if i.id not in seen_item_ids:
                            seen_item_ids.add(i.id)
                            all_items.append({
                                "id": i.id,
                                "productId": i.productId,
                                "name": i.name,
                                "quantity": i.quantity,
                                "price": safe_float(i.price),
                                "imageUrl": i.imageUrl,
                                "selectedVariant": i.selectedVariant,
                                "notes": i.notes,
                                "restaurantId": r.restaurantId,
                                "isRestaurantItem": bool(r.restaurantId),
                                "type": "RESTAURANT" if r.restaurantId else "GROCERY",
                            })

                base_readable_id = re.sub(r'-[GR\d]+$', '', main_order.readableId or "")

                grouped_orders.append({
                    "id": main_order.id,
                    "readableId": base_readable_id,
                    "status": combined_status,
                    "subtotal": sum(safe_float(r.subtotal) for r in related),
                    "discount": sum(safe_float(r.discount) for r in related),
                    "deliveryFee": sum(safe_float(r.deliveryFee) for r in related),
                    "taxes": sum(safe_float(r.taxes) for r in related),
                    "miscFee": sum(safe_float(r.miscFee) for r in related),
                    "total": sum(safe_float(r.total) for r in related),
                    "paymentMethod": safe_enum_str(main_order.paymentMethod, "COD"),
                    "paymentStatus": safe_enum_str(main_order.paymentStatus, "PENDING"),
                    "deliveryMethod": main_order.deliveryMethod or "DELIVERY",
                    "createdAt": to_iso_utc(main_order.createdAt),
                    "shopName": (main_order.shopName.replace("FastKirana", "FastMinute") if main_order.shopName else ("FastMinute Dark Store" if not main_order.restaurantId else "Restaurant")),
                    "restaurantId": main_order.restaurantId,
                    "items": all_items,
                    "address": {
                        "id": main_order.address.id,
                        "label": main_order.address.label,
                        "houseNo": main_order.address.houseNo,
                        "street": main_order.address.street,
                        "area": main_order.address.area,
                        "city": main_order.address.city,
                        "pincode": main_order.address.pincode,
                        "phone": main_order.address.phone
                    } if main_order.address else None,
                    "isCombined": True
                })

        grouped_orders.sort(key=lambda x: x["createdAt"] or "", reverse=True)
        return grouped_orders
    except Exception as e:
        logger.exception(f"Unhandled error in list_orders: {e}")
        return []


@router.get("/{id}")
async def get_order_details(
    id: str,
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed order history. Supports combined checkouts, direct secret tracking links, and shields worker details.
    """
    user_id = (current_user.get("id") or current_user.get("sub")) if current_user else None
    role = current_user.get("role") if current_user else None
    is_staff = role in ["ADMIN", "CHEF", "DELIVERY", "PICKER", "RESTAURANT_OWNER"] if role else False

    now = time.time()
    cache_key = f"{id}:{user_id}:{role}"
    if cache_key in _order_details_cache and (now - _order_details_cache_time.get(cache_key, 0)) < ORDER_DETAILS_CACHE_TTL:
        return _order_details_cache[cache_key]

    clean_id = id.strip().lstrip("#")
    order_conditions = [
        Order.id == id,
        Order.readableId == id,
        Order.id == clean_id,
        Order.readableId == clean_id,
        Order.cfOrderId == id,
        Order.cfOrderId == clean_id,
        Order.readableId.like(f"{clean_id}-%"),
    ]
    if len(clean_id) >= 15:
        order_conditions.append(Order.id.like(f"{clean_id}%"))
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(or_(*order_conditions)).order_by(Order.createdAt.desc())
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Direct secret link access: If order has an unguessable ID with length >= 20 and matched exactly, allow viewing
    is_direct_secret_link = (id == order.id and len(id) >= 20)

    # Access Authorization Guard: If not holding direct secret link, require user session & authorization
    if not is_direct_secret_link:
        if not current_user:
            raise HTTPException(status_code=401, detail="Authentication required to view this order")
        if not is_staff and order.userId != user_id:
            raise HTTPException(status_code=403, detail="Unauthorized to view this order")

    # Store isolation guard for staff
    if is_staff and (role or "").upper() not in ["SUPER_ADMIN", "SUPERADMIN"]:
        assigned_store = current_user.get("assignedStoreId") if current_user else None
        if assigned_store and order.storeId and order.storeId != assigned_store and role not in ["CHEF", "RESTAURANT_OWNER"]:
            raise HTTPException(status_code=403, detail="Forbidden: Order belongs to a different store hub")

    # Fetch delivery executive details (checking order and combined siblings)
    delivery_user = None
    rider_lat = None
    rider_lng = None
    target_delivery_uid = order.deliveryUserId

    if not target_delivery_uid and order.combinedId:
        comb_uid_res = await db.execute(
            select(Order.deliveryUserId).where(
                Order.combinedId == order.combinedId,
                Order.deliveryUserId.isnot(None)
            )
        )
        target_delivery_uid = comb_uid_res.scalars().first()

    if target_delivery_uid:
        rider_stmt = select(User).where(User.id == target_delivery_uid)
        rider_res = await db.execute(rider_stmt)
        rider = rider_res.scalars().first()
        if rider:
            name = rider.name or "FastMinute Delivery Executive"
            phone = rider.phone or "+919696503759"
            rider_lat = float(rider.liveLat) if rider.liveLat is not None else None
            rider_lng = float(rider.liveLng) if rider.liveLng is not None else None

            # Mask internal Admin details
            if rider.role == Role.ADMIN or name == "Admin":
                main_rider_stmt = select(User).where(User.role == Role.DELIVERY)
                main_rider_res = await db.execute(main_rider_stmt)
                main_rider = main_rider_res.scalars().first()
                if main_rider:
                    name = main_rider.name or "FastMinute Delivery Executive"
                    phone = main_rider.phone or "+919696503759"
                    if main_rider.liveLat is not None:
                        rider_lat = float(main_rider.liveLat)
                        rider_lng = float(main_rider.liveLng)

            delivery_user = {
                "id": str(target_delivery_uid),
                "name": name,
                "phone": phone,
                "lat": rider_lat,
                "lng": rider_lng,
            }

    # Sibling orders formatting for combined order types
    if order.combinedId:
        comb_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId == order.combinedId)
        comb_res = await db.execute(comb_stmt)
        combined_orders = comb_res.scalars().all()

        if len(combined_orders) > 1:
            all_items = []
            for co in combined_orders:
                all_items.extend(co.items)

            def get_combined_status(statuses: List[str]) -> str:
                upper = [str(s or "").upper().strip() for s in statuses]
                active = [s for s in upper if s != "CANCELLED"]
                if not active:
                    return "CANCELLED"
                if "ADMIN_PENDING" in active:
                    return "ADMIN_PENDING"
                if "PENDING" in active:
                    return "PENDING"
                if "CONFIRMED" in active or "PREPARING" in active or "COOKING" in active:
                    return "CONFIRMED"
                if "PACKED" in active:
                    return "PACKED"
                if "SHIPPED" in active:
                    return "SHIPPED"
                if all(s == "DELIVERED" for s in active):
                    return "DELIVERED"
                return active[0] if active else "PENDING"

            statuses = [safe_enum_str(o.status, "PENDING") for o in combined_orders]
            combined_status = get_combined_status(statuses)

            base_readable_id = re.sub(r'-[GR\d]+$', '', order.readableId or "")

            sub_orders = []
            for co in combined_orders:
                is_rest = safe_enum_str(co.orderType) == "RESTAURANT" or bool(co.restaurantId)
                sub_orders.append({
                    "id": co.id,
                    "readableId": co.readableId,
                    "type": "RESTAURANT" if is_rest else "GROCERY",
                    "shopName": (co.shopName.replace("FastKirana", "FastMinute") if co.shopName else ("Restaurant" if is_rest else "FastMinute Grocery")),
                    "status": safe_enum_str(co.status, "PENDING"),
                    "subtotal": safe_float(co.subtotal),
                    "total": safe_float(co.total),
                    "itemsCount": len(co.items),
                    "restaurantId": co.restaurantId,
                    "items": [
                        {
                            "id": i.id,
                            "productId": i.productId,
                            "name": i.name,
                            "quantity": i.quantity,
                            "price": safe_float(i.price),
                            "imageUrl": i.imageUrl,
                            "selectedVariant": i.selectedVariant,
                            "notes": i.notes,
                            "restaurantId": co.restaurantId,
                            "isRestaurantItem": is_rest,
                            "type": "RESTAURANT" if is_rest else "GROCERY",
                        }
                        for i in co.items
                    ],
                })

            grocery_sub = next((s for s in sub_orders if s["type"] == "GROCERY"), None)
            restaurant_sub = next((s for s in sub_orders if s["type"] == "RESTAURANT"), None)

            user_name = (order.user.name.strip() if (order.user and order.user.name) else None) or "Customer"
            user_email = (order.user.email if order.user else None) or ""
            user_phone = (order.address.phone if (order.address and order.address.phone) else None) or (order.user.phone if (order.user and order.user.phone) else None) or order.shopPhone or None

            comb_resp = {
                "id": order.id,
                "userId": order.userId,
                "addressId": order.addressId,
                "readableId": base_readable_id,
                "baseReadableId": base_readable_id,
                "status": combined_status,
                "subtotal": sum(safe_float(co.subtotal) for co in combined_orders),
                "discount": sum(safe_float(co.discount) for co in combined_orders),
                "deliveryFee": sum(safe_float(co.deliveryFee) for co in combined_orders),
                "taxes": sum(safe_float(co.taxes) for co in combined_orders),
                "miscFee": sum(safe_float(co.miscFee) for co in combined_orders),
                "total": sum(safe_float(co.total) for co in combined_orders),
                "paymentMethod": safe_enum_str(order.paymentMethod, "COD"),
                "paymentStatus": safe_enum_str(order.paymentStatus, "PENDING"),
                "estimatedDelivery": to_iso_utc(order.estimatedDelivery),
                "createdAt": to_iso_utc(order.createdAt),
                "updatedAt": to_iso_utc(order.updatedAt),
                "deliveryMethod": order.deliveryMethod or "DELIVERY",
                "isB2B": bool(order.isB2B),
                "shopName": order.shopName,
                "shopPhone": order.shopPhone,
                "deliveryLat": rider_lat if rider_lat is not None else order.deliveryLat,
                "deliveryLng": rider_lng if rider_lng is not None else order.deliveryLng,
                "deliveryUserId": target_delivery_uid,
                "deliveryBoyName": delivery_user["name"] if delivery_user else None,
                "deliveryBoyPhone": delivery_user["phone"] if delivery_user else None,
                "deliveryUser": delivery_user,
                "notes": order.notes,
                "couponCode": order.couponCode,
                "userName": user_name,
                "userEmail": user_email,
                "userPhone": user_phone,
                "user": {
                    "id": order.user.id if order.user else None,
                    "name": user_name,
                    "email": user_email,
                    "phone": order.user.phone if order.user else None,
                } if order.user else None,
                "items": [
                    {
                        "id": i.id,
                        "productId": i.productId,
                        "name": i.name,
                        "price": safe_float(i.price),
                        "quantity": i.quantity,
                        "imageUrl": i.imageUrl,
                        "selectedVariant": i.selectedVariant,
                        "notes": i.notes,
                    }
                    for i in all_items
                ],
                "address": {
                    "id": order.address.id,
                    "label": order.address.label,
                    "houseNo": order.address.houseNo,
                    "street": order.address.street,
                    "area": order.address.area,
                    "city": order.address.city,
                    "pincode": order.address.pincode,
                    "phone": order.address.phone,
                    "lat": float(order.address.lat) if getattr(order.address, 'lat', None) is not None else None,
                    "lng": float(order.address.lng) if getattr(order.address, 'lng', None) is not None else None,
                } if order.address else None,
                "deliveryUser": delivery_user,
                "isCombined": True,
                "groceryStatus": grocery_sub["status"] if grocery_sub else None,
                "groceryItems": grocery_sub["items"] if grocery_sub else [],
                "restaurantStatus": restaurant_sub["status"] if restaurant_sub else None,
                "restaurantName": restaurant_sub["shopName"] if restaurant_sub else None,
                "restaurantItems": restaurant_sub["items"] if restaurant_sub else [],
                "subOrders": sub_orders
            }
            _order_details_cache[cache_key] = comb_resp
            _order_details_cache_time[cache_key] = now
            return comb_resp

    # Single order payload fallback
    user_name = (order.user.name.strip() if (order.user and order.user.name) else None) or "Customer"
    user_email = (order.user.email if order.user else None) or ""
    user_phone = (order.address.phone if (order.address and order.address.phone) else None) or (order.user.phone if (order.user and order.user.phone) else None) or order.shopPhone or None
    is_rest_single = safe_enum_str(order.orderType) == "RESTAURANT" or bool(order.restaurantId)

    single_resp = {
        "id": order.id,
        "readableId": order.readableId,
        "userId": order.userId,
        "addressId": order.addressId,
        "status": safe_enum_str(order.status, "PENDING"),
        "orderType": safe_enum_str(order.orderType, "RESTAURANT" if is_rest_single else "GROCERY"),
        "restaurantId": order.restaurantId,
        "restaurantName": order.shopName if is_rest_single else None,
        "isRestaurant": is_rest_single,
        "subtotal": safe_float(order.subtotal),
        "discount": safe_float(order.discount),
        "deliveryFee": safe_float(order.deliveryFee),
        "taxes": safe_float(order.taxes),
        "miscFee": safe_float(order.miscFee),
        "total": safe_float(order.total),
        "paymentMethod": safe_enum_str(order.paymentMethod, "COD"),
        "paymentStatus": safe_enum_str(order.paymentStatus, "PENDING"),
        "estimatedDelivery": to_iso_utc(order.estimatedDelivery),
        "createdAt": to_iso_utc(order.createdAt),
        "updatedAt": to_iso_utc(order.updatedAt),
        "deliveryMethod": order.deliveryMethod or "DELIVERY",
        "isB2B": bool(order.isB2B),
        "shopName": order.shopName,
        "shopPhone": order.shopPhone,
        "deliveryLat": rider_lat if rider_lat is not None else order.deliveryLat,
        "deliveryLng": rider_lng if rider_lng is not None else order.deliveryLng,
        "deliveryUserId": target_delivery_uid,
        "deliveryBoyName": delivery_user["name"] if delivery_user else None,
        "deliveryBoyPhone": delivery_user["phone"] if delivery_user else None,
        "deliveryUser": delivery_user,
        "notes": order.notes,
        "couponCode": order.couponCode,
        "userName": user_name,
        "userEmail": user_email,
        "userPhone": user_phone,
        "user": {
            "id": order.user.id if order.user else None,
            "name": user_name,
            "email": user_email,
            "phone": order.user.phone if order.user else None,
        } if order.user else None,
        "items": [
            {
                "id": i.id,
                "productId": i.productId,
                "name": i.name,
                "price": safe_float(i.price),
                "quantity": i.quantity,
                "imageUrl": i.imageUrl,
                "selectedVariant": i.selectedVariant,
                "notes": i.notes,
                "restaurantId": order.restaurantId,
                "isRestaurantItem": is_rest_single,
                "type": "RESTAURANT" if is_rest_single else "GROCERY",
            }
            for i in order.items
        ],
        "address": {
            "id": order.address.id,
            "label": order.address.label,
            "houseNo": order.address.houseNo,
            "street": order.address.street,
            "area": order.address.area,
            "city": order.address.city,
            "pincode": order.address.pincode,
            "phone": order.address.phone,
            "lat": float(order.address.lat) if getattr(order.address, 'lat', None) is not None else None,
            "lng": float(order.address.lng) if getattr(order.address, 'lng', None) is not None else None,
        } if order.address else None,
        "deliveryUser": delivery_user
    }
    _order_details_cache[cache_key] = single_resp
    _order_details_cache_time[cache_key] = now
    return single_resp



@router.get("/{order_id}/track")
async def track_order(
    order_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Real-time order tracking details with delivery partner status & ETA.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    role = current_user.get("role")
    is_staff = role in ["ADMIN", "CHEF", "DELIVERY", "PICKER", "RESTAURANT_OWNER"]

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address)
    ).where(or_(Order.id == order_id, Order.readableId == order_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if not is_staff and order.userId != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    rider_info = None
    if order.deliveryUserId:
        rider_stmt = select(User).where(User.id == order.deliveryUserId)
        rider_res = await db.execute(rider_stmt)
        rider = rider_res.scalars().first()
        if rider:
            rider_info = {
                "id": rider.id,
                "name": rider.name or "Delivery Executive",
                "phone": rider.phone,
                "lat": rider.liveLat or 26.1495,
                "lng": rider.liveLng or 80.1672
            }

    status_steps = [
        {"status": "PENDING", "label": "Order Placed", "completed": True, "time": to_iso_utc(order.createdAt)},
        {"status": "CONFIRMED", "label": "Order Confirmed", "completed": order.confirmedAt is not None, "time": to_iso_utc(order.confirmedAt)},
        {"status": "PACKED", "label": "Packing / Preparing", "completed": order.packedAt is not None, "time": to_iso_utc(order.packedAt)},
        {"status": "SHIPPED", "label": "Out for Delivery", "completed": order.shippedAt is not None or order.status == OrderStatus.SHIPPED, "time": to_iso_utc(order.shippedAt)},
        {"status": "DELIVERED", "label": "Delivered", "completed": order.deliveredAt is not None or order.status == OrderStatus.DELIVERED, "time": to_iso_utc(order.deliveredAt)}
    ]

    return {
        "orderId": order.id,
        "readableId": order.readableId,
        "status": order.status.value,
        "estimatedDeliveryMinutes": 10 if order.status.value in ["CONFIRMED", "PACKED", "SHIPPED"] else 0,
        "rider": rider_info,
        "shopName": order.shopName,
        "total": float(order.total),
        "steps": status_steps,
        "address": {
            "houseNo": order.address.houseNo,
            "street": order.address.street,
            "city": order.address.city
        } if order.address else None
    }
