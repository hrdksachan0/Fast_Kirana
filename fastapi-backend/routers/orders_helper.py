"""
Orders Helper Routes
Migrated from Next.js API routes to FastAPI.
These are helper endpoints that complement the main orders router.
"""

from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from typing import Dict, Any
from datetime import datetime

from database import get_db
from models import Order, OrderStatus, OrderItem
from routers.auth import require_auth

helper_router = APIRouter(prefix="/orders", tags=["Order Helpers"])


@helper_router.get("/{order_id}/items")
async def get_order_items(
    order_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get all items for a specific order."""
    result = await db.execute(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    return {
        "orderId": order.id,
        "items": [
            {
                "id": i.id, "productId": i.productId,
                "productName": i.name, "price": float(i.price),
                "quantity": i.quantity,
            }
            for i in order.items
        ]
    }


@helper_router.get("/recent")
async def get_recent_orders(
    limit: int = 10,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get recent orders for the logged-in user."""
    user_id = current_user.get("id") or current_user.get("sub")
    stmt = select(Order).where(Order.userId == user_id).order_by(Order.createdAt.desc()).limit(limit)
    result = await db.execute(stmt)
    orders = result.scalars().all()

    return {"orders": [
        {
            "id": o.id, "readableId": o.readableId,
            "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
            "total": float(o.total),
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
        }
        for o in orders
    ]}


@helper_router.patch("/{order_id}/edit")
async def edit_order(
    order_id: str,
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Edit an order (limited fields)."""
    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Only owner can edit, only when PENDING
    if order.userId != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")
    if order.status != OrderStatus.PENDING:
        raise HTTPException(status_code=400, detail="Only pending orders can be edited")

    allowed_fields = ["notes", "addressId"]
    for field in allowed_fields:
        if field in data:
            setattr(order, field, data[field])

    await db.commit()
    await db.refresh(order)
    return {"order": {"id": order.id, "notes": order.notes, "addressId": order.addressId}}


@helper_router.get("/{order_id}/live")
async def get_order_live_status(
    order_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get real-time order status with all timestamps."""
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    return {
        "id": order.id,
        "readableId": order.readableId,
        "status": order.status.value if hasattr(order.status, 'value') else str(order.status),
        "total": float(order.total),
        "paymentMethod": order.paymentMethod.value if hasattr(order.paymentMethod, 'value') else str(order.paymentMethod),
        "paymentStatus": order.paymentStatus.value if hasattr(order.paymentStatus, 'value') else str(order.paymentStatus),
        "timestamps": {
            "createdAt": order.createdAt.isoformat() if order.createdAt else None,
            "confirmedAt": order.confirmedAt.isoformat() if order.confirmedAt else None,
            "packedAt": order.packedAt.isoformat() if order.packedAt else None,
            "shippedAt": order.shippedAt.isoformat() if order.shippedAt else None,
            "deliveredAt": order.deliveredAt.isoformat() if order.deliveredAt else None,
            "cancelledAt": order.cancelledAt.isoformat() if order.cancelledAt else None,
        }
    }