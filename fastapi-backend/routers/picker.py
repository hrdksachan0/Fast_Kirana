"""
Picker Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_
from sqlalchemy.orm import selectinload
from typing import List, Dict, Any, Optional
from datetime import datetime
import uuid

from database import get_db
from models import Order, OrderItem, User, Product, OrderStatus, OrderType, Role, CartItem
from routers.auth import require_auth

picker_router = APIRouter(prefix="/picker", tags=["Picker & Chef"])


def require_picker_or_chef(current_user: dict) -> dict:
    """Allow PICKER, CHEF, RESTAURANT_OWNER, ADMIN."""
    role = current_user.get("role")
    if role not in ["PICKER", "CHEF", "RESTAURANT_OWNER", "ADMIN"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    return current_user


@picker_router.get("/orders")
async def get_picker_orders(
    type: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get orders for picker/chef dashboard."""
    user_role = current_user.get("role")
    user_id = current_user.get("id") or current_user.get("sub")
    require_picker_or_chef(current_user)

    if user_role in ("CHEF", "RESTAURANT_OWNER") and type not in ("cafe", "restaurant"):
        if user_role == "RESTAURANT_OWNER":
            pass  # allow
        else:
            raise HTTPException(status_code=403, detail="Unauthorized for this type")

    if user_role == "PICKER" and type in ("cafe", "restaurant"):
        raise HTTPException(status_code=403, detail="Pickers only handle grocery orders")

    # Build query
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.user),
        selectinload(Order.address),
    )

    statuses = [OrderStatus.PENDING, OrderStatus.CONFIRMED]
    if type == "cafe":
        stmt = stmt.where(
            and_(
                Order.status.in_(statuses),
                Order.orderType == OrderType.RESTAURANT
            )
        )
    elif type == "restaurant":
        stmt = stmt.where(
            and_(
                Order.status.in_(statuses),
                Order.orderType == OrderType.RESTAURANT
            )
        )
    else:
        # Grocery orders
        stmt = stmt.where(
            and_(
                Order.status.in_(statuses),
                Order.orderType == OrderType.GROCERY
            )
        )

    stmt = stmt.order_by(Order.createdAt.asc()).limit(50)
    result = await db.execute(stmt)
    orders = result.scalars().all()

    return {
        "orders": [
            {
                "id": o.id,
                "readableId": o.readableId,
                "userId": o.userId,
                "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
                "total": float(o.total),
                "subtotal": float(o.subtotal),
                "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, 'value') else str(o.paymentMethod),
                "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, 'value') else str(o.paymentStatus),
                "createdAt": o.createdAt.isoformat() if o.createdAt else None,
                "user": {"name": o.user.name if o.user else "Customer", "phone": o.user.phone if o.user else None} if o.user else None,
                "address": {
                    "houseNo": o.address.houseNo if o.address else "",
                    "street": o.address.street if o.address else "",
                    "area": o.address.area if o.address else "",
                    "city": o.address.city if o.address else "",
                    "pincode": o.address.pincode if o.address else "",
                } if o.address else None,
                "items": [
                    {"id": i.id, "productId": i.productId, "quantity": i.quantity,
                     "selectedVariant": i.selectedVariant, "notes": i.notes}
                    for i in o.items
                ] if hasattr(o, 'items') else [],
            }
            for o in orders
        ]
    }


@picker_router.patch("/orders/{order_id}/status")
async def picker_update_order_status(
    order_id: str,
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Update order status from picker/chef view."""
    require_picker_or_chef(current_user)

    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_status = data.get("status")
    if new_status:
        try:
            order.status = OrderStatus(new_status)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid status")

    # Timestamp fields
    if new_status == "CONFIRMED" and not order.confirmedAt:
        order.confirmedAt = datetime.utcnow()
    elif new_status == "PACKED" and not order.packedAt:
        order.packedAt = datetime.utcnow()
    elif new_status == "SHIPPED" and not order.shippedAt:
        order.shippedAt = datetime.utcnow()

    await db.commit()
    await db.refresh(order)
    return {"order": {"id": order.id, "status": order.status.value if hasattr(order.status, 'value') else str(order.status)}}