from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, func, and_, or_, text
from typing import List, Dict, Any, Optional
from datetime import datetime, time
import urllib.parse

from database import get_db
from models import Order, OrderItem, RiderWallet, CashDepositTransaction, User, Address, OrderStatus, PaymentMethod, PaymentStatus
from routers.auth import require_auth


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
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get active delivery orders to process (returns flat list matching Next.js).
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")

    today_start = datetime.combine(datetime.utcnow().date(), time.min)

    # Filter matching status criteria
    status_filters = [
        and_(
            Order.status.in_([OrderStatus.CONFIRMED, OrderStatus.PREPARING, OrderStatus.PACKED]),
            or_(Order.deliveryUserId == None, Order.deliveryUserId == user_id)
        ),
        and_(
            Order.status == OrderStatus.SHIPPED,
            Order.deliveryUserId == user_id
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
    ).order_by(Order.createdAt.desc())

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

    result = []
    for o in orders:
        companion_data = None
        if o.combinedId:
            matching = next((c for c in companion_orders if c.combinedId == o.combinedId and c.id != o.id), None)
            if matching:
                companion_data = {
                    "id": matching.id,
                    "readableId": matching.readableId,
                    "shopName": matching.shopName,
                    "status": matching.status.value,
                    "total": float(matching.total),
                    "items": [{"id": i.id, "name": i.name, "quantity": i.quantity} for i in matching.items]
                }

        result.append({
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "addressId": o.addressId,
            "status": o.status.value,
            "subtotal": float(o.subtotal),
            "discount": float(o.discount),
            "deliveryFee": float(o.deliveryFee),
            "taxes": float(o.taxes),
            "miscFee": float(o.miscFee),
            "total": float(o.total),
            "paymentMethod": o.paymentMethod.value,
            "paymentStatus": o.paymentStatus.value,
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
            "items": [{"id": i.id, "name": i.name, "price": float(i.price), "quantity": i.quantity} for i in o.items],
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
            "companionOrder": companion_data
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
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get live location coordinates of delivery partner, store (restaurant), and customer.
    """
    stmt = select(Order).options(
        selectinload(Order.address),
        selectinload(Order.restaurant)
    ).where(Order.id == orderId)
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if not order.deliveryUserId:
        raise HTTPException(status_code=400, detail="No delivery agent assigned")

    # Fetch active coordinates from User model
    r_stmt = select(User).where(User.id == order.deliveryUserId)
    r_res = await db.execute(r_stmt)
    rider = r_res.scalars().first()

    lat = rider.liveLat if (rider and rider.liveLat is not None) else (order.restaurant.lat if order.restaurant else 26.1534185)
    lng = rider.liveLng if (rider and rider.liveLng is not None) else (order.restaurant.lng if order.restaurant else 80.1714024)

    return {
        "rider": {
            "name": rider.name if rider else "Rider",
            "phone": rider.phone if rider else None,
            "lat": float(lat) if lat is not None else 26.1534185,
            "lng": float(lng) if lng is not None else 80.1714024,
        },
        "restaurant": {
            "lat": float(order.restaurant.lat) if (order.restaurant and order.restaurant.lat is not None) else 26.1534185,
            "lng": float(order.restaurant.lng) if (order.restaurant and order.restaurant.lng is not None) else 80.1714024,
        },
        "customer": {
            "lat": float(order.address.lat) if (order.address and order.address.lat is not None) else 26.1534185,
            "lng": float(order.address.lng) if (order.address and order.address.lng is not None) else 80.1714024,
        },
        "status": order.status.value
    }


@router.post("/location")
async def update_rider_live_location(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update rider's live tracking GPS coordinates.
    """
    require_delivery_or_admin(current_user)
    user_id = current_user.get("id") or current_user.get("sub")
    lat = payload.get("lat")
    lng = payload.get("lng")

    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="Missing lat or lng coordinates")

    try:
        stmt = select(User).where(User.id == user_id)
        res = await db.execute(stmt)
        user = res.scalars().first()

        if user:
            user.liveLat = float(lat)
            user.liveLng = float(lng)
            await db.commit()
            return {"success": True}
        else:
            raise HTTPException(status_code=404, detail="User not found")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update coordinates: {str(e)}")
