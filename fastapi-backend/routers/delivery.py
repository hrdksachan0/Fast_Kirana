from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, func
from typing import List, Dict, Any
from database import get_db
from models import Order, OrderItem, RiderWallet, CashDepositTransaction, User, OrderStatus
from routers.auth import require_delivery
import urllib.parse

router = APIRouter(prefix="/delivery", tags=["Delivery & Rider Wallet"])

@router.get("/wallet")
async def get_rider_wallet(
    current_user: dict = Depends(require_delivery),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns real-time rider wallet info, cash capacity, and deposit history
    """
    user_id = current_user.get("id") or current_user.get("sub")
    stmt = select(RiderWallet).where(RiderWallet.userId == user_id)
    res = await db.execute(stmt)
    wallet = res.scalars().first()

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

    is_locked = wallet.cashInHand >= wallet.cashLimit
    is_warning = wallet.cashInHand >= wallet.cashLimit * 0.75

    # Fetch today's cash deposits
    dep_stmt = select(CashDepositTransaction).where(
        CashDepositTransaction.riderId == user_id
    ).order_by(desc(CashDepositTransaction.createdAt)).limit(10)
    dep_res = await db.execute(dep_stmt)
    deposits = dep_res.scalars().all()

    return {
        "wallet": {
            "cashInHand": wallet.cashInHand,
            "cashLimit": wallet.cashLimit,
            "totalCollected": wallet.totalCollected,
            "totalDeposited": wallet.totalDeposited,
            "isLocked": is_locked,
            "isWarning": is_warning,
            "remainingLimit": max(0.0, wallet.cashLimit - wallet.cashInHand)
        },
        "recentDeposits": [
            {
                "id": d.id,
                "amount": d.amount,
                "notes": d.notes,
                "createdAt": d.createdAt
            } for d in deposits
        ]
    }

@router.get("/orders")
async def get_delivery_orders(
    current_user: dict = Depends(require_delivery),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns delivery orders grouped by combinedId for multi-pickup handling
    """
    user_id = current_user.get("id") or current_user.get("sub")
    stmt = select(Order).options(selectinload(Order.items), selectinload(Order.address), selectinload(Order.user)).where(
        (Order.deliveryUserId == None) | (Order.deliveryUserId == user_id)
    ).order_by(desc(Order.createdAt)).limit(50)

    res = await db.execute(stmt)
    orders = res.scalars().all()

    # Find companion orders sharing combinedId
    combined_ids = list(set([o.combinedId for o in orders if o.combinedId]))
    companion_map = {}
    if combined_ids:
        comp_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId.in_(combined_ids))
        comp_res = await db.execute(comp_stmt)
        comp_orders = comp_res.scalars().all()
        for co in comp_orders:
            companion_map[co.id] = co

    result = []
    for o in orders:
        companion_data = None
        if o.combinedId:
            matching = [co for co in companion_map.values() if co.combinedId == o.combinedId and co.id != o.id]
            if matching:
                m = matching[0]
                companion_data = {
                    "id": m.id,
                    "readableId": m.readableId,
                    "shopName": m.shopName,
                    "status": m.status,
                    "total": m.total,
                    "items": [{"id": i.id, "name": i.name, "quantity": i.quantity} for i in m.items]
                }

        result.append({
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "status": o.status,
            "total": o.total,
            "paymentMethod": o.paymentMethod,
            "paymentStatus": o.paymentStatus,
            "shopName": o.shopName,
            "createdAt": o.createdAt,
            "user": {"name": o.user.name if o.user else "Customer", "phone": o.user.phone if o.user else None},
            "address": {
                "houseNo": o.address.houseNo if o.address else "",
                "street": o.address.street if o.address else "",
                "area": o.address.area if o.address else "",
                "city": o.address.city if o.address else "",
                "lat": o.address.lat if o.address else None,
                "lng": o.address.lng if o.address else None,
            } if o.address else None,
            "items": [{"id": i.id, "name": i.name, "price": i.price, "quantity": i.quantity} for i in o.items],
            "companionOrder": companion_data
        })

    return result

@router.get("/orders/{order_id}/qr")
async def get_doorstep_qr(
    order_id: str,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Order).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    upi_vpa = "7054470303@paytm"
    payee_name = urllib.parse.quote("FastKirana Store")
    note = urllib.parse.quote(f"Payment for Order #{order.readableId or order.id[:8]}")
    amount = f"{order.total:.2f}"
    tr = f"FK{order.readableId or order.id[:8]}"

    upi_uri = f"upi://pay?pa={upi_vpa}&pn={payee_name}&am={amount}&cu=INR&tn={note}&tr={tr}"
    qr_image_url = f"https://api.qrserver.com/v1/create-qr-code/?size=280x280&data={urllib.parse.quote(upi_uri)}"

    return {
        "orderId": order.id,
        "readableId": order.readableId,
        "amount": order.total,
        "upiVpa": upi_vpa,
        "upiUri": upi_uri,
        "qrImageUrl": qr_image_url,
        "paymentStatus": order.paymentStatus,
        "paymentMethod": order.paymentMethod
    }
