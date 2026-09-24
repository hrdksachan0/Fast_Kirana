from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, func, and_, or_, text
from typing import List, Dict, Any, Optional
from datetime import datetime, time
import urllib.parse
import math

from database import get_db
from models import Order, OrderItem, RiderWallet, CashDepositTransaction, User, Address, OrderStatus, PaymentMethod, PaymentStatus, StoreSetting
from routers.auth import require_auth
from routers.websockets import manager
from routers.orders import send_pwa_notification_to_user

# In-memory deduplication set for 500m proximity arrival alerts (max 2,000 orders)
_arriving_soon_alerted_orders = set()


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate great circle distance between two GPS coordinates in kilometers.
    """
    R = 6371.0 # Earth's radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


router = APIRouter(prefix="/delivery", tags=["Delivery & Rider Operations"])


def require_delivery_or_admin(current_user: dict) -> dict:
    role = current_user.get("role")
    if role not in ["DELIVERY", "ADMIN"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden: Delivery or Admin role required")
    return current_user


@router.get("/wallet")
async def get_rider_wallet(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get real-time rider wallet info, cash capacity limits, and recent deposits.
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")

    today_start = datetime.combine(datetime.utcnow().date(), time.min)

    # Ensure wallet exists
    wallet_stmt = select(RiderWallet).where(RiderWallet.userId == user_id)
    wallet_res = await db.execute(wallet_stmt)
    wallet = wallet_res.scalars().first()

    if not wallet:
        wallet = RiderWallet(
            id=f"rw_{user_id}",
            userId=user_id,
            cashInHand=0.0,
            cashLimit=2000.0,
            totalCollected=0.0,
            totalDeposited=0.0
        )
        db.add(wallet)
        await db.commit()
        await db.refresh(wallet)

    # Fetch today's COD delivered orders
    cod_stmt = select(Order).where(
        Order.deliveryUserId == user_id,
        Order.status == OrderStatus.DELIVERED,
        Order.paymentMethod == PaymentMethod.COD,
        Order.deliveredAt >= today_start
    ).order_by(Order.deliveredAt.desc())
    cod_res = await db.execute(cod_stmt)
    today_cod_orders = cod_res.scalars().all()

    # Fetch recent cash deposits
    dep_stmt = select(CashDepositTransaction).options(selectinload(CashDepositTransaction.admin)).where(
        CashDepositTransaction.riderId == user_id
    ).order_by(desc(CashDepositTransaction.createdAt)).limit(10)
    dep_res = await db.execute(dep_stmt)
    recent_deposits = dep_res.scalars().all()

    is_locked = wallet.cashInHand >= wallet.cashLimit
    is_warning = wallet.cashInHand >= wallet.cashLimit * 0.75

    return {
        "wallet": {
            "cashInHand": float(wallet.cashInHand),
            "cashLimit": float(wallet.cashLimit),
            "totalCollected": float(wallet.totalCollected),
            "totalDeposited": float(wallet.totalDeposited),
            "isLocked": is_locked,
            "isWarning": is_warning,
            "remainingLimit": max(0.0, float(wallet.cashLimit - wallet.cashInHand))
        },
        "todayCodOrders": [
            {
                "id": o.id,
                "readableId": o.readableId,
                "total": float(o.total),
                "deliveredAt": o.deliveredAt.isoformat() if o.deliveredAt else None,
                "cashSettledToAdmin": o.cashSettledToAdmin,
                "shopName": o.shopName
            } for o in today_cod_orders
        ],
        "recentDeposits": [
            {
                "id": d.id,
                "amount": float(d.amount),
                "adminName": d.admin.name if d.admin else "Admin",
                "notes": d.notes,
                "createdAt": d.createdAt.isoformat() if d.createdAt else None
            } for d in recent_deposits
        ]
    }


@router.get("/orders")
async def get_delivery_orders(
    storeId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get active delivery orders to process (returns flat list matching Next.js).
    Scoped to assigned dark store hub if provided.
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")
    effective_store_id = storeId or current_user.get("assignedStoreId")

    today_start = datetime.combine(datetime.utcnow().date(), time.min)

    # Filter matching status criteria
    status_filters = [
        and_(
            Order.status.in_([OrderStatus.PENDING, OrderStatus.CONFIRMED, OrderStatus.PACKED]),
            or_(Order.deliveryUserId.is_(None), Order.deliveryUserId == "", Order.deliveryUserId == user_id)
        ),
        and_(
            Order.status == OrderStatus.SHIPPED,
            or_(Order.deliveryUserId == user_id, Order.deliveryUserId.is_(None), Order.deliveryUserId == "")
        ),
        and_(
            Order.status == OrderStatus.DELIVERED,
            Order.deliveryUserId == user_id,
            or_(Order.deliveredAt >= today_start, Order.updatedAt >= today_start, Order.createdAt >= today_start)
        )
    ]

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(
        or_(Order.deliveryMethod == "DELIVERY", Order.deliveryMethod == None),
        or_(*status_filters)
    )

    if effective_store_id and effective_store_id != "all":
        stmt = stmt.where(Order.storeId == effective_store_id)

    stmt = stmt.order_by(Order.createdAt.desc())

    res = await db.execute(stmt)
    orders = res.scalars().all()

    if not orders:
        return []

    # Companion orders sharing combinedId
    combined_ids = list(set([o.combinedId for o in orders if o.combinedId]))
    companion_orders = []
    if combined_ids:
        comp_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId.in_(combined_ids))
        comp_res = await db.execute(comp_stmt)
        companion_orders = comp_res.scalars().all()

    # ─── Smart Rider Batching Engine (2 Orders within 800m-1.5km) ───
    unassigned_pickup_orders = [
        o for o in orders
        if (not o.deliveryUserId or o.deliveryUserId == "") and
        o.status in [OrderStatus.PENDING, OrderStatus.CONFIRMED, OrderStatus.PACKED]
    ]

    batch_map = {}
    paired = set()
    for i in range(len(unassigned_pickup_orders)):
        o1 = unassigned_pickup_orders[i]
        if o1.id in paired:
            continue
        lat1 = (o1.address.lat if o1.address else None) or o1.deliveryLat
        lng1 = (o1.address.lng if o1.address else None) or o1.deliveryLng
        if lat1 is None or lng1 is None:
            continue

        best_partner = None
        min_dist = float("inf")
        for j in range(i + 1, len(unassigned_pickup_orders)):
            o2 = unassigned_pickup_orders[j]
            if o2.id in paired:
                continue
            if o1.storeId != o2.storeId:
                continue

            lat2 = (o2.address.lat if o2.address else None) or o2.deliveryLat
            lng2 = (o2.address.lng if o2.address else None) or o2.deliveryLng
            if lat2 is None or lng2 is None:
                continue

            dist = haversine_km(lat1, lng1, lat2, lng2)
            if dist <= 1.5 and dist < min_dist:
                min_dist = dist
                best_partner = o2

        if best_partner is not None:
            batch_id = f"batch_{o1.id}_{best_partner.id}"
            paired.add(o1.id)
            paired.add(best_partner.id)
            dist_meters = int(min_dist * 1000)

            batch_map[o1.id] = {
                "isBatch": True,
                "batchGroupId": batch_id,
                "partnerOrderId": best_partner.id,
                "partnerOrderReadableId": best_partner.readableId or best_partner.id,
                "partnerCustomerName": best_partner.user.name if best_partner.user else "Customer",
                "bonusEarning": 12.0,
                "distanceBetweenDropsMeters": dist_meters,
                "stopIndex": 1,
                "totalStops": 2,
            }
            batch_map[best_partner.id] = {
                "isBatch": True,
                "batchGroupId": batch_id,
                "partnerOrderId": o1.id,
                "partnerOrderReadableId": o1.readableId or o1.id,
                "partnerCustomerName": o1.user.name if o1.user else "Customer",
                "bonusEarning": 12.0,
                "distanceBetweenDropsMeters": dist_meters,
                "stopIndex": 2,
                "totalStops": 2,
            }

    # Also compute batching for orders assigned to the same rider (Out For Delivery / Active)
    assigned_groups = {}
    for o in orders:
        if o.deliveryUserId and o.status in [OrderStatus.SHIPPED, OrderStatus.PACKED, OrderStatus.CONFIRMED]:
            assigned_groups.setdefault(o.deliveryUserId, []).append(o)

    for rider_id, r_orders in assigned_groups.items():
        if len(r_orders) >= 2:
            for i in range(len(r_orders)):
                o1 = r_orders[i]
                if o1.id in paired:
                    continue
                lat1 = (o1.address.lat if o1.address else None) or o1.deliveryLat
                lng1 = (o1.address.lng if o1.address else None) or o1.deliveryLng
                if lat1 is None or lng1 is None:
                    continue

                best_partner = None
                min_dist = float("inf")
                for j in range(i + 1, len(r_orders)):
                    o2 = r_orders[j]
                    if o2.id in paired:
                        continue
                    lat2 = (o2.address.lat if o2.address else None) or o2.deliveryLat
                    lng2 = (o2.address.lng if o2.address else None) or o2.deliveryLng
                    if lat2 is None or lng2 is None:
                        continue
                    dist = haversine_km(lat1, lng1, lat2, lng2)
                    if dist < min_dist:
                        min_dist = dist
                        best_partner = o2

                if best_partner is not None:
                    batch_id = f"batch_{o1.id}_{best_partner.id}"
                    paired.add(o1.id)
                    paired.add(best_partner.id)
                    dist_meters = int(min_dist * 1000)

                    batch_map[o1.id] = {
                        "isBatch": True,
                        "batchGroupId": batch_id,
                        "partnerOrderId": best_partner.id,
                        "partnerOrderReadableId": best_partner.readableId or best_partner.id,
                        "partnerCustomerName": best_partner.user.name if best_partner.user else "Customer",
                        "bonusEarning": 12.0,
                        "distanceBetweenDropsMeters": dist_meters,
                        "stopIndex": 1,
                        "totalStops": 2,
                    }
                    batch_map[best_partner.id] = {
                        "isBatch": True,
                        "batchGroupId": batch_id,
                        "partnerOrderId": o1.id,
                        "partnerOrderReadableId": o1.readableId or o1.id,
                        "partnerCustomerName": o1.user.name if o1.user else "Customer",
                        "bonusEarning": 12.0,
                        "distanceBetweenDropsMeters": dist_meters,
                        "stopIndex": 2,
                        "totalStops": 2,
                    }

    result = []
    for o in orders:
        companion_data = None
        if o.combinedId:
            matching = next((c for c in companion_orders if c.combinedId == o.combinedId and c.id != o.id), None)
            if matching:
                companion_data = {
                    "id": matching.id,
                    "readableId": matching.readableId,
                    "combinedId": matching.combinedId,
                    "restaurantId": matching.restaurantId,
                    "shopName": matching.shopName,
                    "status": matching.status.value if hasattr(matching.status, "value") else str(matching.status),
                    "total": float(matching.total),
                    "items": [{"id": i.id, "name": i.name, "quantity": i.quantity} for i in matching.items]
                }

        result.append({
            "id": o.id,
            "readableId": o.readableId,
            "combinedId": o.combinedId,
            "restaurantId": o.restaurantId,
            "storeId": o.storeId,
            "orderType": o.orderType.value if hasattr(o.orderType, "value") else str(o.orderType),
            "userId": o.userId,
            "addressId": o.addressId,
            "status": o.status.value if hasattr(o.status, "value") else str(o.status),
            "subtotal": float(o.subtotal),
            "discount": float(o.discount),
            "deliveryFee": float(o.deliveryFee),
            "taxes": float(o.taxes),
            "miscFee": float(o.miscFee),
            "total": float(o.total),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, "value") else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, "value") else str(o.paymentStatus),
            "estimatedDelivery": o.estimatedDelivery.isoformat() if o.estimatedDelivery else None,
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
            "shopName": o.shopName,
            "deliveryUserId": o.deliveryUserId,
            "notes": o.notes,
            "confirmedAt": o.confirmedAt.isoformat() if o.confirmedAt else None,
            "packedAt": o.packedAt.isoformat() if o.packedAt else None,
            "shippedAt": o.shippedAt.isoformat() if o.shippedAt else None,
            "deliveredAt": o.deliveredAt.isoformat() if o.deliveredAt else None,
            "deliveryLat": o.deliveryLat,
            "deliveryLng": o.deliveryLng,
            "items": [{"id": i.id, "name": i.name, "price": float(i.price), "quantity": i.quantity, "selectedVariant": getattr(i, "selectedVariant", None)} for i in o.items],
            "user": {"name": o.user.name or "Customer", "phone": o.user.phone} if o.user else {"name": "Customer", "phone": None},
            "address": {
                "id": o.address.id,
                "label": o.address.label,
                "houseNo": o.address.houseNo,
                "street": o.address.street,
                "area": o.address.area,
                "city": o.address.city,
                "pincode": o.address.pincode,
                "phone": o.address.phone,
                "lat": o.address.lat,
                "lng": o.address.lng,
            } if o.address else None,
            "companionOrder": companion_data,
            "batch": batch_map.get(o.id)
        })

    return result


@router.get("/orders/{id}/qr")
async def get_doorstep_qr(
    id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Generate dynamic UPI payment Intent QR URL for doorstep collections.
    """
    require_delivery_or_admin(current_user)

    stmt = select(Order).where(Order.id == id)
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    upi_vpa_stmt = select(StoreSetting).where(StoreSetting.key == "store_upi_vpa")
    upi_vpa_res = await db.execute(upi_vpa_stmt)
    upi_vpa_setting = upi_vpa_res.scalars().first()

    upi_vpa = upi_vpa_setting.value if upi_vpa_setting else "7054470303@paytm"
    payee_name = urllib.parse.quote("FastKirana Store")
    note = urllib.parse.quote(f"Payment for Order #{order.readableId or order.id[:8]}")
    amount = f"{float(order.total):.2f}"
    tr = f"FK{order.readableId or order.id[:8]}"

    upi_uri = f"upi://pay?pa={upi_vpa}&pn={payee_name}&am={amount}&cu=INR&tn={note}&tr={tr}"
    qr_image_url = f"https://api.qrserver.com/v1/create-qr-code/?size=280x280&data={urllib.parse.quote(upi_uri)}"

    return {
        "orderId": order.id,
        "readableId": order.readableId,
        "amount": float(order.total),
        "upiVpa": upi_vpa,
        "upiUri": upi_uri,
        "qrImageUrl": qr_image_url,
        "paymentStatus": order.paymentStatus.value,
        "paymentMethod": order.paymentMethod.value
    }


@router.post("/orders/{id}/qr")
async def confirm_doorstep_qr_payment(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Confirm dynamic UPI payment collection for COD deliveries.
    """
    require_delivery_or_admin(current_user)
    reference_id = payload.get("referenceId")

    stmt = select(Order).where(Order.id == id)
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    try:
        order.paymentMethod = PaymentMethod.UPI
        order.paymentStatus = PaymentStatus.PAID
        ref_text = f"Doorstep UPI Paid (Ref: {reference_id or 'QR Scan'})"
        order.notes = f"{order.notes} | {ref_text}" if order.notes else ref_text

        await db.commit()
        await db.refresh(order)

        return {
            "success": True,
            "message": "Payment converted to UPI successfully!",
            "order": {
                "id": order.id,
                "paymentMethod": order.paymentMethod.value,
                "paymentStatus": order.paymentStatus.value,
                "notes": order.notes
            }
        }
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to confirm payment: {str(e)}")


@router.get("/location")
async def get_rider_delivery_location(
    orderId: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """
    H21 FIX: Public endpoint to get live tracking coordinates of rider, store, and customer.
    No auth required so customer tracking links work without login friction.
    Gracefully handles unassigned rider state without throwing 400.
    """
    clean_id = orderId.strip().lstrip("#")
    stmt = select(Order).options(
        selectinload(Order.address),
        selectinload(Order.restaurant)
    ).where(or_(Order.id == clean_id, Order.readableId == clean_id))
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    rest_lat = float(order.restaurant.lat) if (order.restaurant and order.restaurant.lat is not None) else 26.1534185
    rest_lng = float(order.restaurant.lng) if (order.restaurant and order.restaurant.lng is not None) else 80.1714024
    cust_lat = float(order.address.lat) if (order.address and order.address.lat is not None) else rest_lat
    cust_lng = float(order.address.lng) if (order.address and order.address.lng is not None) else rest_lng

    if not order.deliveryUserId:
        return {
            "rider": None,
            "restaurant": {"lat": rest_lat, "lng": rest_lng},
            "customer": {"lat": cust_lat, "lng": cust_lng},
            "status": order.status.value,
            "message": "Order is being prepared. Delivery partner will be assigned shortly."
        }

    # Fetch active coordinates from User model
    r_stmt = select(User).where(User.id == order.deliveryUserId)
    r_res = await db.execute(r_stmt)
    rider = r_res.scalars().first()

    lat = rider.liveLat if (rider and rider.liveLat is not None) else (order.deliveryLat or rest_lat)
    lng = rider.liveLng if (rider and rider.liveLng is not None) else (order.deliveryLng or rest_lng)

    return {
        "rider": {
            "name": rider.name if rider else "Delivery Partner",
            "phone": rider.phone if rider else None,
            "lat": float(lat),
            "lng": float(lng),
        },
        "restaurant": {
            "lat": rest_lat,
            "lng": rest_lng,
        },
        "customer": {
            "lat": cust_lat,
            "lng": cust_lng,
        },
        "status": order.status.value
    }


@router.post("/location")
async def update_rider_live_location(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """
    Update rider's live tracking GPS coordinates and active order coordinates.
    Also triggers automatic 'Arriving in 2 Mins' notification when rider enters within 500m.
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")
    lat = payload.get("lat")
    lng = payload.get("lng")
    order_id = payload.get("orderId")

    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="Missing lat or lng coordinates")

    try:
        stmt = select(User).where(User.id == user_id)
        res = await db.execute(stmt)
        user = res.scalars().first()

        if user:
            user.liveLat = float(lat)
            user.liveLng = float(lng)

            active_order = None
            # Also update active Order delivery coordinates if orderId provided
            if order_id:
                clean_oid = str(order_id).strip().lstrip("#")
                o_stmt = select(Order).options(selectinload(Order.address)).where(or_(Order.id == clean_oid, Order.readableId == clean_oid))
                o_res = await db.execute(o_stmt)
                active_order = o_res.scalars().first()
                if active_order:
                    active_order.deliveryLat = float(lat)
                    active_order.deliveryLng = float(lng)

            await db.commit()

            # Zero-latency WebSocket broadcast to customer live tracking screen
            if order_id:
                clean_oid = str(order_id).strip().lstrip("#")
                try:
                    await manager.broadcast_to_channel(f"order_{clean_oid}", {
                        "event": "LOCATION_UPDATE",
                        "orderId": clean_oid,
                        "lat": float(lat),
                        "lng": float(lng),
                        "heading": float(payload.get("heading") or 0.0),
                        "speed": float(payload.get("speed") or 0.0),
                        "timestamp": datetime.utcnow().isoformat()
                    })
                except Exception:
                    pass

            # Proximity Arrival Trigger: Notify customer when rider is <= 500m (~2 minutes away)
            target_order = active_order
            if not target_order:
                active_ship_stmt = select(Order).options(selectinload(Order.address)).where(
                    Order.deliveryUserId == user_id,
                    Order.status == OrderStatus.SHIPPED
                ).order_by(desc(Order.createdAt)).limit(1)
                active_ship_res = await db.execute(active_ship_stmt)
                target_order = active_ship_res.scalars().first()

            if target_order and target_order.status == OrderStatus.SHIPPED:
                cust_addr = target_order.address
                if not cust_addr and target_order.addressId:
                    a_stmt = select(Address).where(Address.id == target_order.addressId)
                    a_res = await db.execute(a_stmt)
                    cust_addr = a_res.scalars().first()

                if cust_addr and cust_addr.lat is not None and cust_addr.lng is not None:
                    dist_km = haversine_km(float(lat), float(lng), float(cust_addr.lat), float(cust_addr.lng))
                    if dist_km <= 0.5:
                        if target_order.id not in _arriving_soon_alerted_orders:
                            _arriving_soon_alerted_orders.add(target_order.id)
                            if len(_arriving_soon_alerted_orders) > 2000:
                                _arriving_soon_alerted_orders.pop()

                            dist_meters = max(50, int(dist_km * 1000))
                            arriving_title = "🛵 Delivery Partner Arriving in 2 Mins!"
                            arriving_body = f"Your rider is ~{dist_meters}m away! Please get ready to receive order #{target_order.readableId}."

                            if target_order.userId:
                                background_tasks.add_task(
                                    send_pwa_notification_to_user,
                                    target_order.userId,
                                    arriving_title,
                                    arriving_body,
                                    {
                                        "orderId": target_order.id,
                                        "readableId": str(target_order.readableId or ""),
                                        "status": "ARRIVING_SOON",
                                        "type": "ORDER_STATUS_UPDATE"
                                    },
                                    None,
                                    cust_addr.phone if cust_addr else None
                                )

                            try:
                                await manager.broadcast_to_channel(f"order_{target_order.id}", {
                                    "event": "ARRIVING_SOON",
                                    "orderId": target_order.id,
                                    "distanceKm": dist_km,
                                    "status": "ARRIVING_SOON"
                                })
                            except Exception:
                                pass

            # Also broadcast to rider stream
            try:
                await manager.broadcast_to_channel(f"rider_{user_id}", {
                    "event": "RIDER_GPS_UPDATE",
                    "riderId": user_id,
                    "lat": float(lat),
                    "lng": float(lng),
                    "timestamp": datetime.utcnow().isoformat()
                })
            except Exception:
                pass

            return {"success": True}
        else:
            raise HTTPException(status_code=404, detail="User not found")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update coordinates: {str(e)}")


@router.post("/batch/accept")
async def accept_batch_orders(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Accept multiple clustered orders in a single trip for batch delivery.
    Assigns rider to all orders, marks them as SHIPPED with shippedAt timestamp.
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")
    order_ids = payload.get("orderIds") or []

    if not order_ids or not isinstance(order_ids, list):
        raise HTTPException(status_code=400, detail="orderIds list is required")

    try:
        clean_ids = [str(oid).strip().lstrip("#") for oid in order_ids]
        stmt = select(Order).where(Order.id.in_(clean_ids))
        res = await db.execute(stmt)
        orders = res.scalars().all()

        if len(orders) != len(clean_ids):
            found_ids = {o.id for o in orders}
            missing = [cid for cid in clean_ids if cid not in found_ids]
            if missing:
                r_stmt = select(Order).where(Order.readableId.in_(missing))
                r_res = await db.execute(r_stmt)
                r_orders = r_res.scalars().all()
                orders = list(orders) + list(r_orders)

        if not orders:
            raise HTTPException(status_code=404, detail="No matching orders found to batch accept")

        # Verify none of them are already claimed by another rider
        for o in orders:
            if o.deliveryUserId and o.deliveryUserId != user_id:
                raise HTTPException(
                    status_code=400,
                    detail=f"Order #{o.readableId or o.id[:8]} is already assigned to another rider"
                )

        now = datetime.utcnow()
        for o in orders:
            o.deliveryUserId = user_id
            o.status = OrderStatus.SHIPPED
            o.shippedAt = now

        await db.commit()

        # Broadcast SHIPPED status to WebSockets for all accepted orders
        for o in orders:
            try:
                await manager.broadcast_to_channel(f"order_{o.id}", {
                    "event": "STATUS_UPDATE",
                    "orderId": o.id,
                    "status": "SHIPPED",
                    "timestamp": now.isoformat()
                })
            except Exception:
                pass

        return {
            "success": True,
            "message": f"Successfully accepted {len(orders)} orders for batch delivery!",
            "orderIds": [o.id for o in orders],
            "bonusEarning": 12.0 if len(orders) >= 2 else 0.0
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to batch accept orders: {str(e)}")

