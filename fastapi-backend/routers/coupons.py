from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, not_
from typing import Dict, Any, Optional, List
from datetime import datetime

from database import get_db
from models import Coupon, Order, Restaurant
from routers.auth import get_current_user


router = APIRouter(prefix="/coupons", tags=["Coupons"])


@router.post("/validate")
async def validate_coupon(
    payload: Dict[str, Any] = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Validate a promo voucher code, computing flat or percentage discount amounts
    under active constraints (expiry, category, restaurant limits, etc.).
    """
    code = payload.get("code")
    subtotal = float(payload.get("subtotal", 0.0))
    items = payload.get("items", [])

    if not code:
        raise HTTPException(status_code=400, detail="Coupon code is required")

    upper_code = code.strip().upper()

    # Find coupon
    stmt = select(Coupon).where(Coupon.code == upper_code)
    res = await db.execute(stmt)
    coupon = res.scalars().first()

    if not coupon or not coupon.isActive:
        raise HTTPException(status_code=400, detail="Invalid or inactive coupon code")

    # Expiry Check
    if coupon.expiresAt and coupon.expiresAt < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Coupon code has expired")

    # Usage Count Check
    if coupon.maxUses and coupon.usedCount >= coupon.maxUses:
        raise HTTPException(status_code=400, detail="Coupon code limit reached")

    # Once Per Customer Check
    if coupon.oncePerCustomer:
        user_id = current_user.get("id") if current_user else None
        if not user_id:
            raise HTTPException(status_code=400, detail="Please log in to use this coupon")

        order_stmt = select(func.count(Order.id)).where(
            Order.userId == user_id,
            Order.couponCode == upper_code,
            Order.status != "CANCELLED"
        )
        order_res = await db.execute(order_stmt)
        already_used = order_res.scalar()

        if already_used > 0:
            raise HTTPException(status_code=400, detail="You have already used this coupon code once")

    eligible_subtotal = subtotal

    # Category Restriction
    if coupon.categoryId:
        if not items:
            raise HTTPException(status_code=400, detail="This coupon is restricted to a category. Cart items are required.")

        category_items = [i for i in items if i.get("categoryId") == coupon.categoryId]
        category_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in category_items)

        if category_subtotal == 0:
            raise HTTPException(status_code=400, detail="This coupon is only valid for items in the restricted category.")

        if category_subtotal < coupon.minOrder:
            raise HTTPException(
                status_code=400,
                detail=f"Minimum order of ₹{coupon.minOrder:.2f} in the restricted category is required."
            )
        eligible_subtotal = category_subtotal

    # Restaurant Restriction
    elif coupon.restaurantId:
        if not items:
            raise HTTPException(status_code=400, detail="This coupon is restricted to a restaurant. Cart items are required.")

        # Find restaurant details
        res_stmt = select(Restaurant.name).where(Restaurant.id == coupon.restaurantId)
        res_res = await db.execute(res_stmt)
        restaurant_name = res_res.scalars().first() or "the restricted restaurant"

        restaurant_items = []
        for i in items:
            item_res_id = i.get("restaurantId") or (i.get("product") or {}).get("restaurantId")
            if item_res_id == coupon.restaurantId:
                restaurant_items.append(i)

        restaurant_subtotal = sum(float(i.get("price", 0.0)) * int(i.get("quantity", 1)) for i in restaurant_items)

        if restaurant_subtotal == 0:
            raise HTTPException(
                status_code=400,
                detail=f"This coupon is only valid for items from {restaurant_name}."
            )

        if restaurant_subtotal < coupon.minOrder:
            raise HTTPException(
                status_code=400,
                detail=f"Minimum order of ₹{coupon.minOrder:.2f} from {restaurant_name} is required."
            )
        eligible_subtotal = restaurant_subtotal

    # Global Min Order Check
    else:
        if subtotal < coupon.minOrder:
            raise HTTPException(
                status_code=400,
                detail=f"Minimum order of ₹{coupon.minOrder:.2f} required for this coupon"
            )

    # Calculate Discount
    discount_amount = 0.0
    if coupon.discountType == "FLAT":
        discount_amount = min(coupon.value, eligible_subtotal)
    elif coupon.discountType == "PERCENT":
        discount_amount = (eligible_subtotal * coupon.value) / 100.0
        if coupon.maxDiscount:
            discount_amount = min(discount_amount, coupon.maxDiscount)

    return {
        "message": "Coupon applied successfully!",
        "coupon": {
            "id": coupon.id,
            "code": coupon.code,
            "discountType": coupon.discountType,
            "value": coupon.value,
            "discountAmount": round(discount_amount, 2)
        }
    }
