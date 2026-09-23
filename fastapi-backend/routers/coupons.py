from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, or_, not_
from typing import Dict, Any, Optional, List
from datetime import datetime
import re

from database import get_db
from models import Coupon, Order, Restaurant, Product
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
    free_items = []
    free_gift_details = None
    nudge_message = None

    def parse_trigger_variant(raw):
        raw_str = str(raw or "").strip()
        size_match = re.search(r'\b(medium|large|small|regular|half|full)\b', raw_str, re.I)
        trigger_sz = size_match.group(1).lower() if size_match else None
        num_match = re.search(r'\b\d+\b', raw_str)
        min_qty = int(num_match.group(0)) if num_match else (int(raw_str) if raw_str and not trigger_sz else 1)
        return min_qty, trigger_sz

    def get_variant_text(it):
        sel = str(it.get("selectedVariant") or "")
        var = str(it.get("variant") or "")
        unit = str(it.get("unit") or "")
        nm = str(it.get("name") or "")
        p_name = str((it.get("product") or {}).get("name") or "")
        return f"{sel} {var} {unit} {nm} {p_name}".lower()

    if coupon.discountType == "BOGO":
        bogo_items = restaurant_items if coupon.restaurantId else items
        if coupon.bogoDishId:
            bogo_items = [
                it for it in bogo_items
                if (it.get("productId") or it.get("id") or (it.get("product") or {}).get("id") or "").split("_")[0] == coupon.bogoDishId
            ]
        elif coupon.menuSection:
            sec_filters = [s.strip().lower() for s in coupon.menuSection.split(",") if s.strip()]
            if sec_filters:
                known_sections = ['burger', 'sandwich', 'pasta', 'maggie', 'maggi', 'calzone', 'garlic', 'beverage', 'drink', 'dessert', 'icecream', 'biryani', 'pizza', 'shake']
                filtered_bogo = []
                for it in bogo_items:
                    m_sec = str(it.get("menuSection") or (it.get("product") or {}).get("menuSection") or "").lower()
                    tags = [str(t).lower() for t in (it.get("tags") or (it.get("product") or {}).get("tags") or [])]
                    name = str(it.get("name") or (it.get("product") or {}).get("name") or "").lower()

                    matches = False
                    for f in sec_filters:
                        if f in m_sec or any(f in t for t in tags):
                            matches = True
                            break
                        other_sections = [s for s in known_sections if f not in s and s not in f]
                        has_conflict = any(any(s in t for t in tags) for s in other_sections) or any(s in m_sec for s in other_sections)
                        if not has_conflict and f in name:
                            matches = True
                            break
                    if matches:
                        filtered_bogo.append(it)
                bogo_items = filtered_bogo

        if coupon.bogoType == "BUY_LARGE_GET_SMALL":
            trigger_var = (coupon.triggerVariant or "large").lower().strip()
            reward_var = (coupon.rewardVariant or "small").lower().strip()

            trigger_items = [it for it in bogo_items if trigger_var in get_variant_text(it)]
            total_trigger_qty = sum(int(it.get("quantity", 1)) for it in trigger_items)
            if total_trigger_qty == 0:
                sec_label = f" ({coupon.menuSection})" if coupon.menuSection else ""
                dish_label = " of selected dish" if coupon.bogoDishId else ""
                raise HTTPException(
                    status_code=400,
                    detail=f"This offer requires adding a {coupon.triggerVariant or 'Large'}{sec_label}{dish_label}."
                )

            reward_pool = bogo_items if coupon.bogoDishId else (bogo_items if coupon.menuSection else (restaurant_items if coupon.restaurantId else items))
            if coupon.defaultFreeDishId:
                reward_items = [
                    it for it in (restaurant_items if coupon.restaurantId else items)
                    if (it.get("productId") or it.get("id") or (it.get("product") or {}).get("id") or "").split("_")[0] == coupon.defaultFreeDishId
                ]
            else:
                reward_items = [it for it in reward_pool if reward_var in get_variant_text(it)]

            allowed_free = min(total_trigger_qty, coupon.maxFreeItems or 3)
            if not reward_items:
                sec_label = f" ({coupon.menuSection})" if coupon.menuSection else ""
                nudge_message = f"Add any {coupon.rewardVariant or 'Small'}{sec_label} to get it 100% FREE! 🎁"
                discount_amount = 0.0
            else:
                sorted_rewards = sorted(reward_items, key=lambda x: float(x.get("price", 0.0)))
                remaining_free = allowed_free
                for it in sorted_rewards:
                    qty = int(it.get("quantity", 1))
                    free_qty = min(qty, remaining_free)
                    price = float(it.get("price", 0.0))
                    discount_amount += free_qty * price
                    free_items.append({
                        "id": it.get("id"),
                        "productId": it.get("productId") or it.get("id"),
                        "name": it.get("name"),
                        "freeQty": free_qty,
                        "price": price
                    })
                    remaining_free -= free_qty
                    if remaining_free <= 0:
                        break

        elif coupon.bogoType == "FREE_GIFT":
            min_trigger, trigger_size = parse_trigger_variant(coupon.triggerVariant)
            qualifying_items = [it for it in bogo_items if trigger_size in get_variant_text(it)] if trigger_size else bogo_items
            total_trigger = sum(int(it.get("quantity", 1)) for it in qualifying_items)

            if total_trigger < min_trigger:
                sec_label = f" ({coupon.menuSection})" if coupon.menuSection else ""
                size_label = f" {trigger_size.upper()}" if trigger_size else ""
                raise HTTPException(
                    status_code=400,
                    detail=f"Add at least {min_trigger}{size_label} qualifying dishes{sec_label} to unlock your FREE GIFT! 🎁"
                )

            gift_dish = None
            if coupon.defaultFreeDishId:
                p_stmt = select(Product).where(Product.id == coupon.defaultFreeDishId)
                p_res = await db.execute(p_stmt)
                gift_dish = p_res.scalars().first()

            reward_tag = re.sub(r'[^a-z0-9]', '', (coupon.rewardVariant or "").lower())

            # Find matching gift in user's cart
            matching_gift_in_cart = None
            cart_pool = restaurant_items if coupon.restaurantId else items
            for it in cart_pool:
                base_id = (it.get("productId") or it.get("id") or (it.get("product") or {}).get("id") or "").split("_")[0]
                if coupon.defaultFreeDishId and base_id == coupon.defaultFreeDishId:
                    matching_gift_in_cart = it
                    break
                if reward_tag:
                    name = str(it.get("name") or (it.get("product") or {}).get("name") or "").lower()
                    m_sec = str(it.get("menuSection") or (it.get("product") or {}).get("menuSection") or "").lower()
                    tags = [str(t).lower() for t in (it.get("tags") or (it.get("product") or {}).get("tags") or [])]
                    v_text = get_variant_text(it)
                    if reward_tag in name or any(reward_tag in t for t in tags) or reward_tag in m_sec or reward_tag in v_text:
                        matching_gift_in_cart = it
                        break

            if matching_gift_in_cart:
                free_price = float(matching_gift_in_cart.get("price", gift_dish.price if gift_dish else 0.0))
                discount_amount = free_price
                free_items.append({
                    "id": matching_gift_in_cart.get("id") or (gift_dish.id if gift_dish else None),
                    "productId": matching_gift_in_cart.get("productId") or matching_gift_in_cart.get("id") or (gift_dish.id if gift_dish else None),
                    "name": matching_gift_in_cart.get("name") or (gift_dish.name if gift_dish else "Free Gift"),
                    "freeQty": 1,
                    "price": free_price
                })
            elif gift_dish:
                free_gift_details = {
                    "id": gift_dish.id,
                    "name": gift_dish.name,
                    "price": float(gift_dish.price),
                    "imageUrl": gift_dish.imageUrl,
                    "eligibleQty": 1
                }
                nudge_message = f"🎁 Congratulations! Add 1x '{gift_dish.name}' to your cart to get it 100% FREE!"
            else:
                gift_label = (coupon.rewardVariant or "Free Gift Dish").upper()
                nudge_message = f"Add any {gift_label} to get it 100% FREE! 🎁"

        elif coupon.bogoType == "CHEAPEST_FREE":
            total_qty = sum(int(it.get("quantity", 1)) for it in bogo_items)
            if total_qty < 2:
                sec_label = f" ({coupon.menuSection})" if coupon.menuSection else ""
                raise HTTPException(
                    status_code=400,
                    detail=f"Add at least 2 dishes{sec_label} to get the cheapest one FREE!"
                )
            sorted_items = sorted(bogo_items, key=lambda x: float(x.get("price", 0.0)))
            if sorted_items:
                cheapest = sorted_items[0]
                discount_amount = float(cheapest.get("price", 0.0))
                free_items.append({
                    "id": cheapest.get("id"),
                    "productId": cheapest.get("productId") or cheapest.get("id"),
                    "name": cheapest.get("name"),
                    "freeQty": 1,
                    "price": discount_amount
                })

        elif coupon.bogoType == "SAME_ITEM" or not coupon.bogoType:
            eligible = bogo_items
            if coupon.bogoDishId:
                eligible = [it for it in bogo_items if (it.get("productId") or it.get("id") or (it.get("product") or {}).get("id") or "").split("_")[0] == coupon.bogoDishId]
            max_free_cap = getattr(coupon, "maxFreeItems", 3) or 3
            for it in eligible:
                qty = int(it.get("quantity", 1))
                if qty >= 2:
                    free_count = min(qty // 2, max_free_cap)
                    discount_amount += free_count * float(it.get("price", 0.0))
                    free_items.append({
                        "id": it.get("id"),
                        "productId": it.get("productId") or it.get("id"),
                        "name": it.get("name"),
                        "freeQty": free_count,
                        "price": float(it.get("price", 0.0))
                    })
            if discount_amount == 0:
                raise HTTPException(
                    status_code=400,
                    detail="Add 2 of the same eligible item to unlock Buy 1 Get 1 Free!"
                )

        if coupon.maxDiscount and discount_amount > coupon.maxDiscount:
            discount_amount = coupon.maxDiscount

    elif coupon.discountType == "FREE_DELIVERY":
        discount_amount = 25.0
    elif coupon.discountType == "FLAT":
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
            "bogoType": coupon.bogoType,
            "triggerVariant": coupon.triggerVariant,
            "rewardVariant": coupon.rewardVariant,
            "bogoDishId": coupon.bogoDishId,
            "defaultFreeDishId": coupon.defaultFreeDishId,
            "badgeText": coupon.badgeText,
            "value": coupon.value,
            "discountAmount": round(discount_amount, 2),
            "freeItems": free_items,
            "freeGiftDetails": free_gift_details,
            "nudgeMessage": nudge_message,
        }
    }


@router.get("")
async def get_active_coupons(
    restaurantId: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    List all active, unexpired coupons for storefront / checkout display.
    """
    now = datetime.utcnow()
    conditions = [
        Coupon.isActive == True,
        or_(Coupon.expiresAt == None, Coupon.expiresAt > now)
    ]
    if restaurantId:
        conditions.append(
            or_(
                Coupon.restaurantId == restaurantId,
                and_(Coupon.restaurantId == None, Coupon.categoryId == None)
            )
        )

    stmt = select(Coupon).where(and_(*conditions)).order_by(Coupon.value.desc())
    res = await db.execute(stmt)
    coupons = res.scalars().all()

    return [
        {
            "id": c.id,
            "code": c.code,
            "discountType": c.discountType,
            "bogoType": c.bogoType,
            "badgeText": c.badgeText,
            "value": float(c.value or 0.0),
            "minOrder": float(c.minOrder or 0.0),
            "maxDiscount": float(c.maxDiscount) if c.maxDiscount else None,
            "categoryId": c.categoryId,
            "restaurantId": c.restaurantId,
            "menuSection": c.menuSection,
            "bogoDishId": c.bogoDishId,
            "autoApply": bool(c.autoApply),
            "isActive": c.isActive,
            "expiresAt": c.expiresAt.isoformat() if c.expiresAt else None,
        }
        for c in coupons
    ]
