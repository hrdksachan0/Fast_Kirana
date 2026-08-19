from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_, text
from sqlalchemy.orm import selectinload
from typing import List, Dict, Any, Optional
from datetime import datetime
import re

from database import get_db
from models import Order, OrderItem, User, Product, Address, Restaurant, OrderStatus, OrderType, Role
from routers.auth import require_auth

picker_router = APIRouter(prefix="/picker", tags=["Picker & Chef Operations"])


def require_picker_or_chef(current_user: dict) -> dict:
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
    """
    Get list of active PENDING/CONFIRMED orders to pick or cook (returns flat array matching Next.js).
    """
    require_picker_or_chef(current_user)
    user_role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")

    # Staff checks
    if user_role in ["CHEF", "RESTAURANT_OWNER"]:
        email_str = current_user.get("email", "").lower()
        is_restaurant_chef = email_str.startswith("restaurant") or user_role == "RESTAURANT_OWNER"
        if is_restaurant_chef and type != "restaurant":
            raise HTTPException(status_code=401, detail="Unauthorized")
        if not is_restaurant_chef and type != "cafe":
            raise HTTPException(status_code=401, detail="Unauthorized")

    if user_role == "PICKER" and type in ["cafe", "restaurant"]:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Build filters
    filters = [Order.status.in_([OrderStatus.PENDING, OrderStatus.CONFIRMED])]

    if type == "cafe":
        if assigned_restaurant_id:
            filters.append(Order.restaurantId == assigned_restaurant_id)
        else:
            filters.append(or_(Order.restaurantId != None, Order.orderType == OrderType.RESTAURANT))
    elif type == "restaurant":
        if assigned_restaurant_id:
            filters.append(Order.restaurantId == assigned_restaurant_id)
        else:
            filters.append(or_(Order.restaurantId != None, Order.orderType == OrderType.RESTAURANT))
    else:
        filters.append(Order.restaurantId == None)
        filters.append(or_(Order.orderType == OrderType.GROCERY, Order.orderType == None))

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(*filters).order_by(Order.createdAt.asc())

    res = await db.execute(stmt)
    orders = res.scalars().all()

    if not orders:
        return []

    # Get companion orders sharing combinedId
    combined_ids = list(set([o.combinedId for o in orders if o.combinedId]))
    companion_orders = []
    if combined_ids:
        comp_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId.in_(combined_ids))
        comp_res = await db.execute(comp_stmt)
        companion_orders = comp_res.scalars().all()

    # Hydrate active worker names
    picker_ids = [o.assignedPickerId for o in orders if o.assignedPickerId]
    chef_ids = [o.assignedChefId for o in orders if o.assignedChefId]
    worker_ids = list(set(picker_ids + chef_ids))
    
    workers = {}
    if worker_ids:
        w_stmt = select(User.id, User.name, User.phone).where(User.id.in_(worker_ids))
        w_res = await db.execute(w_stmt)
        for w in w_res.all():
            workers[w.id] = {"name": w.name or "Staff", "phone": w.phone}

    # Fetch restaurants
    restaurant_ids = list(set([o.restaurantId for o in orders if o.restaurantId]))
    restaurants = {}
    if restaurant_ids:
        r_stmt = select(Restaurant).where(Restaurant.id.in_(restaurant_ids))
        r_res = await db.execute(r_stmt)
        for r in r_res.scalars().all():
            restaurants[r.id] = r

    result = []
    for o in orders:
        order_items = []
        for i in o.items:
            # Query product details to populate relations
            p_stmt = select(Product).options(selectinload(Product.category)).where(Product.id == i.productId)
            p_res = await db.execute(p_stmt)
            p_obj = p_res.scalars().first()
            
            order_items.append({
                "id": i.id,
                "productId": i.productId,
                "name": i.name,
                "price": float(i.price),
                "quantity": i.quantity,
                "imageUrl": i.imageUrl,
                "selectedVariant": i.selectedVariant,
                "notes": i.notes,
                "product": {
                    "id": p_obj.id,
                    "name": p_obj.name,
                    "imageUrl": p_obj.imageUrl,
                    "variants": p_obj.variants,
                    "category": {
                        "id": p_obj.category.id,
                        "name": p_obj.category.name,
                        "slug": p_obj.category.slug
                    } if p_obj and p_obj.category else None
                } if p_obj else None
            })

        user_data = {"name": o.user.name or "Customer", "phone": o.user.phone} if o.user else {"name": "Customer", "phone": None}
        assigned_picker = workers.get(o.assignedPickerId)
        assigned_chef = workers.get(o.assignedChefId)
        rest_obj = restaurants.get(o.restaurantId)

        # Companion order formatting
        companion_data = None
        if o.combinedId:
            matching = next((c for c in companion_orders if c.combinedId == o.combinedId and c.id != o.id), None)
            if matching:
                companion_data = {
                    "id": matching.id,
                    "status": matching.status.value,
                    "shopName": matching.shopName,
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
            "deliveryMethod": o.deliveryMethod,
            "shopName": o.shopName,
            "notes": o.notes,
            "restaurantId": o.restaurantId,
            "items": order_items,
            "user": user_data,
            "assignedPicker": assigned_picker,
            "assignedChef": assigned_chef,
            "address": {
                "houseNo": o.address.houseNo if o.address else "",
                "street": o.address.street if o.address else "",
                "area": o.address.area if o.address else "",
                "city": o.address.city if o.address else "",
                "pincode": o.address.pincode if o.address else "",
                "phone": o.address.phone if o.address else None,
            } if o.address else None,
            "restaurant": {
                "id": rest_obj.id,
                "name": rest_obj.name,
                "address": rest_obj.address,
                "logoUrl": rest_obj.logoUrl,
                "ownerPhone": rest_obj.ownerPhone
            } if rest_obj else None,
            "restaurantName": rest_obj.name if rest_obj else o.shopName,
            "companionOrder": companion_data
        })

    return result