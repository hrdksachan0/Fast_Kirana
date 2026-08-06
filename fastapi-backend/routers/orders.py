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
from routers.auth import require_auth

from models import Cart, CartItem

router = APIRouter(prefix="/orders", tags=["Orders & Checkout Engine"])

def generate_id(prefix: str = "ord_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


@router.post("", status_code=status.HTTP_201_CREATED)
@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new order for current user.
    Accepts items list or fetches items from user's active cart.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    address_id = payload.get("addressId")
    payment_method_str = payload.get("paymentMethod", "COD")
    items_data = payload.get("items", [])

    if not address_id:
        # Fetch user's default address if not provided
        addr_stmt = select(Address).where(Address.userId == user_id).order_by(desc(Address.isDefault))
        addr_res = await db.execute(addr_stmt)
        user_addr = addr_res.scalars().first()
        if user_addr:
            address_id = user_addr.id
        else:
            raise HTTPException(status_code=400, detail="addressId is required and user has no saved address")

    # Verify address belongs to user or exists
    addr_check = await db.execute(select(Address).where(Address.id == address_id))
    if not addr_check.scalars().first():
        raise HTTPException(status_code=404, detail="Selected address not found")

    # If items list not passed in body, pull from active cart
    cart_items_list = []
    if items_data:
        for it in items_data:
            p_id = it.get("productId")
            qty = int(it.get("quantity", 1))
            if p_id:
                p_res = await db.execute(select(Product).where(Product.id == p_id))
                prod = p_res.scalars().first()
                if prod:
                    cart_items_list.append({"product": prod, "quantity": qty, "notes": it.get("notes")})
    else:
        cart_res = await db.execute(select(Cart).where(Cart.userId == user_id))
        cart = cart_res.scalars().first()
        if cart:
            ci_res = await db.execute(select(CartItem).where(CartItem.cartId == cart.id))
            for ci in ci_res.scalars().all():
                p_res = await db.execute(select(Product).where(Product.id == ci.productId))
                prod = p_res.scalars().first()
                if prod:
                    cart_items_list.append({"product": prod, "quantity": ci.quantity, "notes": ci.notes})

    if not cart_items_list:
        raise HTTPException(status_code=400, detail="Cart is empty. Please add items to create an order.")

    subtotal = sum(item["product"].price * item["quantity"] for item in cart_items_list)
    delivery_fee = 0.0 if subtotal >= 299.0 else 30.0
    misc_fee = 5.0
    total = subtotal + delivery_fee + misc_fee

    try:
        pay_method = PaymentMethod(payment_method_str)
    except ValueError:
        pay_method = PaymentMethod.COD

    readable_id = f"{random.randint(600000, 999999)}"

    new_order = Order(
        id=generate_id("cms"),
        readableId=readable_id,
        userId=user_id,
        addressId=address_id,
        orderType=OrderType.GROCERY,
        status=OrderStatus.PENDING,
        subtotal=round(subtotal, 2),
        discount=0.0,
        deliveryFee=delivery_fee,
        taxes=0.0,
        miscFee=misc_fee,
        total=round(total, 2),
        paymentMethod=pay_method,
        paymentStatus=PaymentStatus.PAID if pay_method != PaymentMethod.COD else PaymentStatus.PENDING,
        shopName="FastKirana Dark Store",
        createdAt=datetime.utcnow()
    )
    db.add(new_order)
    await db.commit()
    await db.refresh(new_order)

    # Insert OrderItems
    for item in cart_items_list:
        prod = item["product"]
        order_item = OrderItem(
            id=generate_id("ci_"),
            orderId=new_order.id,
            productId=prod.id,
            name=prod.name,
            price=prod.price,
            quantity=item["quantity"],
            imageUrl=prod.imageUrl,
            costPrice=prod.costPrice or 0.0,
            notes=item.get("notes")
        )
        db.add(order_item)

    # Clear user's active cart after placing order
    cart_res = await db.execute(select(Cart).where(Cart.userId == user_id))
    cart = cart_res.scalars().first()
    if cart:
        ci_items = await db.execute(select(CartItem).where(CartItem.cartId == cart.id))
        for ci in ci_items.scalars().all():
            await db.delete(ci)

    await db.commit()
    await db.refresh(new_order)

    return {
        "success": True,
        "message": "Order created successfully",
        "orderId": new_order.id,
        "readableId": new_order.readableId,
        "total": new_order.total,
        "status": new_order.status
    }


@router.get("", response_model=List[OrderOut])
async def list_user_orders(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns user orders with items and companion order details
    """
    user_id = current_user.get("id") or current_user.get("sub")
    stmt = select(Order).options(
        selectinload(Order.items)
    ).where(Order.userId == user_id).order_by(desc(Order.createdAt)).limit(50)
    
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
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates order status, synchronizes companion order status, and updates rider wallet on delivery
    """
    user_id = current_user.get("id") or current_user.get("sub")
    user_role = current_user.get("role")
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
    elif user_role == Role.DELIVERY and not order.deliveryUserId:
        order.deliveryUserId = user_id

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


@router.patch("/{order_id}/status")
async def update_order_status_alias(
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Alias route for PATCH /orders/{order_id}/status
    """
    return await update_order_status(order_id=order_id, payload=payload, current_user=current_user, db=db)


@router.get("/{order_id}/track")
async def track_order(
    order_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Real-time order tracking details with delivery partner status & ETA.
    """
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.deliveryUser)
    ).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    rider_info = None
    if order.deliveryUser:
        rider_info = {
            "id": order.deliveryUser.id,
            "name": order.deliveryUser.name or "Delivery Executive",
            "phone": order.deliveryUser.phone,
            "lat": order.deliveryUser.liveLat or 26.1495,
            "lng": order.deliveryUser.liveLng or 80.1672
        }

    status_steps = [
        {"status": "PENDING", "label": "Order Placed", "completed": True, "time": order.createdAt},
        {"status": "CONFIRMED", "label": "Order Confirmed", "completed": order.confirmedAt is not None, "time": order.confirmedAt},
        {"status": "PACKED", "label": "Packing / Preparing", "completed": order.packedAt is not None, "time": order.packedAt},
        {"status": "SHIPPED", "label": "Out for Delivery", "completed": order.shippedAt is not None or str(order.status) == "SHIPPED", "time": order.shippedAt},
        {"status": "DELIVERED", "label": "Delivered", "completed": order.deliveredAt is not None or str(order.status) == "DELIVERED", "time": order.deliveredAt}
    ]

    return {
        "orderId": order.id,
        "readableId": order.readableId,
        "status": order.status,
        "estimatedDeliveryMinutes": 10 if str(order.status) in ["CONFIRMED", "PACKED", "SHIPPED"] else 0,
        "rider": rider_info,
        "shopName": order.shopName,
        "total": order.total,
        "steps": status_steps,
        "address": {
            "houseNo": order.address.houseNo if order.address else "",
            "street": order.address.street if order.address else "",
            "city": order.address.city if order.address else ""
        } if order.address else None
    }

