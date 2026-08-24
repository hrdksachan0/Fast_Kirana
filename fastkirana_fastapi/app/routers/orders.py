from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session, joinedload
from typing import List, Dict, Any
import uuid
from datetime import datetime
from ..core.database import get_db
from ..core.security import get_current_user, CurrentUser
from ..models.order import Order, OrderItem
from ..models.address import Address
from ..schemas.order import OrderOut, OrderCreateIn

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.get("", response_model=List[OrderOut])
def get_user_orders(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    orders = db.query(Order).options(joinedload(Order.items)).filter(
        Order.userId == user.id
    ).order_by(Order.createdAt.desc()).all()
    return orders

@router.get("/{order_id}", response_model=OrderOut)
def get_order_details(
    order_id: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.id == order_id
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order

@router.post("", response_model=OrderOut)
def place_order(
    payload: OrderCreateIn,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not payload.items:
        raise HTTPException(status_code=400, detail="Order items cannot be empty")

    subtotal = sum(item.price * item.quantity for item in payload.items)
    delivery_fee = 0.0 if subtotal >= 199 else 25.0
    total = subtotal + delivery_fee

    order_id = f"ord_{uuid.uuid4().hex[:16]}"
    readable_id = f"FK-{datetime.now().strftime('%y%m%d')}-{uuid.uuid4().hex[:4].upper()}"

    new_order = Order(
        id=order_id,
        readableId=readable_id,
        userId=user.id,
        addressId=payload.addressId,
        restaurantId=payload.restaurantId,
        orderType=payload.orderType,
        status="PENDING",
        subtotal=subtotal,
        deliveryFee=delivery_fee,
        total=total,
        paymentMethod=payload.paymentMethod,
        paymentStatus="PENDING",
        deliveryMethod=payload.deliveryMethod,
        notes=payload.notes,
        couponCode=payload.couponCode
    )
    db.add(new_order)

    for item in payload.items:
        new_order_item = OrderItem(
            id=f"oi_{uuid.uuid4().hex[:16]}",
            orderId=order_id,
            productId=item.productId,
            name=item.name,
            price=item.price,
            quantity=item.quantity,
            imageUrl=item.imageUrl,
            selectedVariant=item.selectedVariant,
            notes=item.notes
        )
        db.add(new_order_item)

    db.commit()
    db.refresh(new_order)
    return new_order

@router.patch("/{order_id}")
def update_order_status(
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_status = payload.get("status")
    if new_status:
        order.status = new_status
        if new_status == "CONFIRMED":
            order.confirmedAt = datetime.now()
        elif new_status == "PACKED":
            order.packedAt = datetime.now()
        elif new_status == "SHIPPED":
            order.shippedAt = datetime.now()
        elif new_status == "DELIVERED":
            order.deliveredAt = datetime.now()

    db.commit()
    return {"success": True, "status": order.status}
