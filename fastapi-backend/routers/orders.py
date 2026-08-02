from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import desc, and_
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid
import random
from database import get_db
from models import (
    Order, OrderItem, Product, User, Address, RiderWallet, 
    OrderStatus, PaymentStatus, PaymentMethod, OrderType, Role
)
from schemas import OrderOut
from routers.auth import get_current_user_from_jwt

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])

@router.get("", response_model=List[OrderOut])
async def list_user_orders(
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns user orders with items and companion order details
    """
    stmt = select(Order).options(
        selectinload(Order.items)
    ).where(Order.userId == current_user.id).order_by(desc(Order.createdAt)).limit(50)
    
    res = await db.execute(stmt)
    return res.scalars().all()

@router.get("/{order_id}")
async def get_order_by_id(
    order_id: str,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Fetch companion order if combinedId is present
    companion_data = None
    if order.combinedId:
        comp_stmt = select(Order).options(selectinload(Order.items)).where(
            and_(Order.combinedId == order.combinedId, Order.id != order.id)
        )
        comp_res = await db.execute(comp_stmt)
        companion = comp_res.scalars().first()
        if companion:
            companion_data = {
                "id": companion.id,
                "readableId": companion.readableId,
                "shopName": companion.shopName,
                "status": companion.status,
                "total": companion.total,
                "items": [{"id": i.id, "name": i.name, "quantity": i.quantity, "price": i.price} for i in companion.items]
            }

    return {
        "id": order.id,
        "readableId": order.readableId,
        "userId": order.userId,
        "addressId": order.addressId,
        "combinedId": order.combinedId,
        "restaurantId": order.restaurantId,
        "orderType": order.orderType,
        "status": order.status,
        "subtotal": order.subtotal,
        "discount": order.discount,
        "deliveryFee": order.deliveryFee,
        "taxes": order.taxes,
        "miscFee": order.miscFee,
        "total": order.total,
        "paymentMethod": order.paymentMethod,
        "paymentStatus": order.paymentStatus,
        "shopName": order.shopName,
        "createdAt": order.createdAt,
        "deliveredAt": order.deliveredAt,
        "items": [{"id": i.id, "productId": i.productId, "name": i.name, "price": i.price, "quantity": i.quantity, "image": i.image} for i in order.items],
        "companionOrder": companion_data
    }

@router.patch("/{order_id}")
async def update_order_status(
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates order status, synchronizes companion order status, and updates rider wallet on delivery
    """
    stmt = select(Order).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_status_str = payload.get("status")
    if new_status_str:
        try:
            new_status = OrderStatus(new_status_str)
            order.status = new_status
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid status: {new_status_str}")

    if "deliveryUserId" in payload:
        order.deliveryUserId = payload["deliveryUserId"]
    elif current_user.role == Role.DELIVERY and not order.deliveryUserId:
        order.deliveryUserId = current_user.id

    if "deliveryPhoto" in payload:
        order.deliveryPhoto = payload["deliveryPhoto"]
    if "deliveryLat" in payload:
        order.deliveryLat = float(payload["deliveryLat"])
    if "deliveryLng" in payload:
        order.deliveryLng = float(payload["deliveryLng"])

    if order.status == OrderStatus.DELIVERED:
        order.paymentStatus = PaymentStatus.PAID
        order.deliveredAt = datetime.utcnow()

        # Update Rider Wallet for COD order
        if order.paymentMethod == PaymentMethod.COD and order.deliveryUserId:
            wallet_stmt = select(RiderWallet).where(RiderWallet.userId == order.deliveryUserId)
            wallet_res = await db.execute(wallet_stmt)
            wallet = wallet_res.scalars().first()
            if wallet:
                wallet.cashInHand += order.total
                wallet.totalCollected += order.total
            else:
                wallet = RiderWallet(
                    id=f"rw_{order.deliveryUserId}",
                    userId=order.deliveryUserId,
                    cashInHand=order.total,
                    cashLimit=2000.0,
                    totalCollected=order.total,
                    totalDeposited=0.0
                )
                db.add(wallet)

    # Synchronize companion order status if combinedId exists
    if order.combinedId and new_status_str:
        comp_stmt = select(Order).where(and_(Order.combinedId == order.combinedId, Order.id != order.id))
        comp_res = await db.execute(comp_stmt)
        companion = comp_res.scalars().first()
        if companion:
            companion.status = order.status
            if order.deliveryUserId:
                companion.deliveryUserId = order.deliveryUserId
            if order.status == OrderStatus.DELIVERED:
                companion.paymentStatus = PaymentStatus.PAID
                companion.deliveredAt = datetime.utcnow()

    await db.commit()
    await db.refresh(order)
    return {"success": True, "orderId": order.id, "status": order.status}
