"""
Restaurant & Cafe Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_, text
from sqlalchemy.orm import selectinload
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
import uuid
import re

from database import get_db
from models import (
    User, Order, OrderItem, Product, Category, Review, Role, OrderStatus, OrderType
)
from routers.auth import require_admin, require_auth
from routers.websockets import manager

router = APIRouter(prefix="/api", tags=["Restaurant & Cafe"])


# ============================================================
# PUBLIC RESTAURANTS
# ============================================================

@router.get("/restaurants")
async def get_restaurants(
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """Get all restaurants (public)."""
    from models import Restaurant
    from sqlalchemy import cast, String
    stmt = select(Restaurant).where(Restaurant.isActive == True)
    if search:
        stmt = stmt.where(or_(
            Restaurant.name.ilike(f"%{search}%"),
            cast(Restaurant.cuisineTags, String).ilike(f"%{search}%"),
        ))
    stmt = stmt.order_by(Restaurant.rating.desc().nullslast())
    result = await db.execute(stmt)
    restaurants = result.scalars().all()
    return {"restaurants": [
        {"id": r.id, "name": r.name, "slug": r.slug, "cuisine": ", ".join(r.cuisineTags) if r.cuisineTags else "",
         "imageUrl": r.logoUrl, "rating": r.rating, "deliveryTime": r.deliveryTime,
         "minOrder": 0.0, "isActive": r.isActive}
        for r in restaurants
    ]}


@router.get("/restaurants/{restaurant_id}")
async def get_restaurant(
    restaurant_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get restaurant details."""
    from models import Restaurant
    stmt = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(stmt)
    restaurant = result.scalars().first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return {"restaurant": {
        "id": restaurant.id, "name": restaurant.name, "slug": restaurant.slug,
        "cuisine": ", ".join(restaurant.cuisineTags) if restaurant.cuisineTags else "", "description": restaurant.description,
        "imageUrl": restaurant.logoUrl, "rating": restaurant.rating,
        "deliveryTime": restaurant.deliveryTime, "minOrder": 0.0,
        "phone": restaurant.ownerPhone, "address": restaurant.address
    }}


@router.get("/restaurants/{restaurant_id}/reviews")
async def get_restaurant_reviews(
    restaurant_id: str,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db)
):
    """Get reviews for a restaurant from restaurant_reviews and product reviews."""
    from models import Restaurant, RestaurantReview
    # Resolve restaurant by id or slug
    stmt = select(Restaurant).where(or_(
        Restaurant.id == restaurant_id,
        Restaurant.slug == restaurant_id
    ))
    rest_result = await db.execute(stmt)
    restaurant = rest_result.scalars().first()
    real_rest_id = restaurant.id if restaurant else restaurant_id

    # 1. Fetch direct restaurant reviews
    rest_reviews_stmt = select(RestaurantReview).options(selectinload(RestaurantReview.user)).where(
        RestaurantReview.restaurantId == real_rest_id
    ).order_by(desc(RestaurantReview.createdAt)).limit(limit)
    rest_reviews_res = await db.execute(rest_reviews_stmt)
    direct_reviews = rest_reviews_res.scalars().all()

    # 2. Fetch product reviews under this restaurant
    prod_stmt = select(Review).options(selectinload(Review.user)).join(
        Product, Review.productId == Product.id
    ).where(Product.restaurantId == real_rest_id).order_by(desc(Review.createdAt)).limit(limit)
    prod_res = await db.execute(prod_stmt)
    prod_reviews = prod_res.scalars().all()

    all_reviews_list = []
    for r in direct_reviews:
        all_reviews_list.append({
            "id": r.id,
            "rating": r.rating,
            "comment": r.comment,
            "user": {"id": r.user.id, "name": r.user.name, "image": r.user.image} if r.user else None,
            "createdAt": r.createdAt.isoformat() if r.createdAt else None
        })
    for r in prod_reviews:
        all_reviews_list.append({
            "id": r.id,
            "rating": r.rating,
            "comment": r.comment,
            "user": {"id": r.user.id, "name": r.user.name, "image": r.user.image} if r.user else None,
            "createdAt": r.createdAt.isoformat() if r.createdAt else None
        })

    # Sort combined reviews by createdAt descending
    all_reviews_list.sort(key=lambda x: x.get("createdAt") or "", reverse=True)
    total_count = len(all_reviews_list)
    avg_rating = (sum(r["rating"] for r in all_reviews_list) / total_count) if total_count > 0 else (restaurant.rating if restaurant else 4.5)

    return {
        "reviews": all_reviews_list[:limit],
        "totalCount": restaurant.reviewCount if (restaurant and restaurant.reviewCount > total_count) else total_count,
        "averageRating": round(float(avg_rating), 1)
    }


@router.post("/restaurants/{restaurant_id}/reviews")
async def post_restaurant_review(
    restaurant_id: str,
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """Submit a review for a restaurant."""
    from models import Restaurant, RestaurantReview, User
    rating = int(payload.get("rating", 5))
    comment = str(payload.get("comment", "")).strip()

    # Resolve restaurant
    stmt = select(Restaurant).where(or_(
        Restaurant.id == restaurant_id,
        Restaurant.slug == restaurant_id
    ))
    rest_result = await db.execute(stmt)
    restaurant = rest_result.scalars().first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    # Resolve or create a default user for guest reviews if not logged in
    user_stmt = select(User).limit(1)
    user_res = await db.execute(user_stmt)
    first_user = user_res.scalars().first()
    user_id = payload.get("userId") or (first_user.id if first_user else str(uuid.uuid4()))

    new_review = RestaurantReview(
        id=str(uuid.uuid4()),
        userId=user_id,
        restaurantId=restaurant.id,
        rating=rating,
        comment=comment if comment else "Delicious food & prompt service!",
        createdAt=datetime.utcnow()
    )
    db.add(new_review)

    # Update restaurant rating and count
    restaurant.reviewCount = (restaurant.reviewCount or 0) + 1
    # Recalculate average
    new_avg = ((restaurant.rating or 4.5) * (restaurant.reviewCount - 1) + rating) / restaurant.reviewCount
    restaurant.rating = round(new_avg, 1)

    await db.commit()

    return {
        "success": True,
        "message": "Review submitted successfully",
        "review": {
            "id": new_review.id,
            "rating": new_review.rating,
            "comment": new_review.comment,
            "createdAt": new_review.createdAt.isoformat()
        },
        "newAverageRating": restaurant.rating,
        "newTotalCount": restaurant.reviewCount
    }


# ============================================================
# RESTAURANT DASHBOARD (Owner / Kitchen Console)
# ============================================================

restaurant_router = APIRouter(prefix="/restaurant-dashboard", tags=["Restaurant Dashboard"])


async def _resolve_effective_restaurant(restaurant_id: Optional[str], current_user: dict, db: AsyncSession):
    """
    Resolve target restaurant with strict multi-tenant isolation.
    - If restaurant_id is provided, look up by ID or slug.
    - If user is non-admin, verify their assignedRestaurantId matches or they own the restaurant.
    - If user is admin, allow switching to the requested restaurant_id.
    - If restaurant_id is not provided, fall back to user's assignedRestaurantId or phone match.
    """
    from models import Restaurant, User
    from sqlalchemy import or_

    role = str(current_user.get("role", "")).upper()
    is_admin = role in ["ADMIN", "SUPER_ADMIN"]

    target_id = restaurant_id.strip() if restaurant_id and restaurant_id.strip() and restaurant_id.strip().upper() != "ALL" else None

    # Handle common legacy aliases
    if target_id:
        alias_map = {
            "as-restaurant": "REST-101",
            "as-cafe": "REST-101",
            "cms2p1lap0000n0id8alldboy": "REST-101",
            "wedson-restaurant": "REST-102",
            "wedson": "REST-102",
            "bal-udyan-restaurant": "REST-103",
            "bal-udyan": "REST-103",
            "hot-pizza-lovers": "REST-104",
            "pizza-lovers": "REST-104",
        }
        target_id = alias_map.get(target_id.lower(), target_id)

    # 1. If explicit restaurant ID requested
    if target_id:
        stmt = select(Restaurant).where(or_(Restaurant.id == target_id, Restaurant.slug == target_id))
        res = await db.execute(stmt)
        rest = res.scalars().first()
        if rest:
            # If user is admin, allow full access to any outlet
            if is_admin:
                return rest
            # If non-admin, ensure outlet belongs to them
            user_assigned = current_user.get("assignedRestaurantId")
            user_phone = str(current_user.get("phone", "")).replace("+91", "").replace(" ", "").strip()
            rest_phone = str(rest.ownerPhone or "").replace("+91", "").replace(" ", "").strip()
            if user_assigned and (user_assigned == rest.id or user_assigned == rest.slug):
                return rest
            if user_phone and rest_phone and user_phone[-10:] == rest_phone[-10:]:
                return rest

            # Non-admin attempting to access another restaurant's console: strictly reject
            raise HTTPException(status_code=403, detail="Access denied: You do not have permission to access another restaurant's console.")

    # 2. Fall back to user's assignedRestaurantId in token
    assigned = current_user.get("assignedRestaurantId")
    if assigned:
        stmt = select(Restaurant).where(or_(Restaurant.id == assigned, Restaurant.slug == assigned))
        res = await db.execute(stmt)
        r = res.scalars().first()
        if r:
            return r

    # 3. Fall back to DB user profile
    user_id = current_user.get("id") or current_user.get("sub")
    if user_id:
        user_res = await db.execute(select(User).where(User.id == user_id))
        user_obj = user_res.scalars().first()
        if user_obj and user_obj.assignedRestaurantId:
            stmt = select(Restaurant).where(or_(Restaurant.id == user_obj.assignedRestaurantId, Restaurant.slug == user_obj.assignedRestaurantId))
            r = (await db.execute(stmt)).scalars().first()
            if r:
                return r

    # 4. Fall back to phone / email match
    phone = current_user.get("phone")
    email = current_user.get("email")
    filters = []
    if phone:
        clean_p = str(phone).replace("+91", "").replace(" ", "").strip()[-10:]
        filters.append(Restaurant.ownerPhone.contains(clean_p))
    if email:
        filters.append(Restaurant.ownerEmail == email)
    if filters:
        r = (await db.execute(select(Restaurant).where(or_(*filters)))).scalars().first()
        if r:
            return r

    # Default fallback for admin testing
    if is_admin:
        first_rest = (await db.execute(select(Restaurant).order_by(Restaurant.id))).scalars().first()
        return first_rest

    return None


@restaurant_router.get("/stats")
async def restaurant_dashboard_stats(
    restaurantId: Optional[str] = Query(None),
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Stats for restaurant owner dashboard with strict outlet isolation."""
    from models import PaymentMethod, PaymentStatus
    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    if not restaurant:
        return {
            "totalOrders": 0, "totalRevenue": 0.0, "totalSales": 0.0,
            "todayOrders": 0, "todayRevenue": 0.0, "todaySales": 0.0,
            "commissionRate": 20.0, "restaurantId": "", "restaurantName": ""
        }

    # Strict outlet isolation: ONLY orders matching this restaurant and not cancelled
    base_filter = [
        Order.restaurantId == restaurant.id,
        Order.orderType != OrderType.GROCERY,
        Order.status != OrderStatus.CANCELLED,
        or_(Order.paymentMethod == PaymentMethod.COD, Order.paymentStatus == PaymentStatus.PAID)
    ]

    today_start = datetime.combine(date.today(), datetime.min.time())

    # Total orders for this restaurant
    total_orders_stmt = select(func.count(Order.id)).where(and_(*base_filter))
    total_orders = (await db.execute(total_orders_stmt)).scalar() or 0

    # Total Food Item Sales (strictly food items for this restaurant, excluding grocery items)
    pure_grocery_keywords = [
        'atta', 'raw rice', 'dal', 'mustard oil', 'refined oil', 'ghee', 'washing powder',
        'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
        'harpic', 'vim bar', 'rin', 'tide', 'surf', 'namkeen packet', 'chips packet',
        'biscuit', 'sugar', 'salt', 'masala packet', 'spices', 'refill', 'packet', 'pouch',
        'campa', 'pepsi', 'coca cola', 'sprite', 'frooti', 'thums up', 'maaza', 'limca', 'sting'
    ]

    food_items_stmt = select(OrderItem, Order.createdAt).select_from(OrderItem).join(
        Order, OrderItem.orderId == Order.id
    ).options(selectinload(OrderItem.product)).where(and_(*base_filter))
    food_items_res = await db.execute(food_items_stmt)
    all_order_items = food_items_res.all()

    total_revenue = 0.0
    today_revenue = 0.0
    today_orders_set = set()

    for row in all_order_items:
        it = row[0]
        o_created = row[1]
        p = it.product
        p_rest = p.restaurantId if p else None
        name_l = (it.name or "").lower().strip()
        is_grocery = False
        if p and p.restaurantId is None:
            is_grocery = True
        elif any(gw in name_l for gw in pure_grocery_keywords):
            if not p_rest or p_rest != restaurant.id:
                is_grocery = True

        if not is_grocery or (p_rest and p_rest == restaurant.id):
            item_val = float(it.price or 0.0) * (it.quantity or 1)
            total_revenue += item_val
            if o_created and o_created >= today_start:
                today_revenue += item_val
                today_orders_set.add(it.orderId)

    today_orders = len(today_orders_set)

    # Commission rate
    comm_rate = getattr(restaurant, "commissionRate", 20.0) or 20.0
    commission_percent = (comm_rate * 100.0) if comm_rate <= 1.0 else float(comm_rate)

    return {
        "totalOrders": total_orders,
        "totalRevenue": round(float(total_revenue), 2),
        "totalSales": round(float(total_revenue), 2),
        "todayOrders": today_orders,
        "todayRevenue": round(float(today_revenue), 2),
        "todaySales": round(float(today_revenue), 2),
        "commissionRate": commission_percent,
        "restaurantId": restaurant.id,
        "restaurantName": restaurant.name,
    }


@restaurant_router.get("/orders")
async def restaurant_dashboard_orders(
    restaurantId: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(100, le=200),
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Restaurant owner & kitchen view of orders.
    Enforces absolute outlet isolation:
    - Never leaks orders from other restaurants or dark store grocery orders.
    - Strips out grocery items from combined orders so kitchen only sees restaurant items.
    """
    from models import PaymentMethod, PaymentStatus

    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    if not restaurant:
        return {"orders": [], "commissionRate": 20.0, "restaurantName": ""}

    # 1. Base conditions: strictly this restaurant, non-grocery, confirmed COD or paid online
    conditions = [
        Order.restaurantId == restaurant.id,
        Order.orderType != OrderType.GROCERY,
        Order.status != OrderStatus.ADMIN_PENDING,
        or_(Order.paymentMethod == PaymentMethod.COD, Order.paymentStatus == PaymentStatus.PAID)
    ]

    # 2. Status filtering
    if status and isinstance(status, str):
        status_clean = status.strip().lower()
        if status_clean in ["live", "active"]:
            conditions.append(Order.status.in_([
                OrderStatus.PENDING,
                OrderStatus.CONFIRMED,
                OrderStatus.PACKED,
                OrderStatus.SHIPPED,
            ]))
        elif "," in status:
            parts = [s.strip().upper() for s in status.split(",") if s.strip()]
            valid_statuses = [OrderStatus(p) for p in parts if p in OrderStatus.__members__]
            if valid_statuses:
                conditions.append(Order.status.in_(valid_statuses))
        else:
            upper_status = status.strip().upper()
            if upper_status in OrderStatus.__members__:
                conditions.append(Order.status == OrderStatus(upper_status))

    # 3. Date filtering for Sales tab
    if startDate:
        try:
            st_dt = datetime.fromisoformat(startDate.replace("Z", ""))
            conditions.append(Order.createdAt >= st_dt)
        except Exception:
            pass
    if endDate:
        try:
            end_dt = datetime.fromisoformat(endDate.replace("Z", "")) + timedelta(days=1)
            conditions.append(Order.createdAt <= end_dt)
        except Exception:
            pass

    stmt = select(Order).options(
        selectinload(Order.user),
        selectinload(Order.address),
        selectinload(Order.items).selectinload(OrderItem.product),
    ).where(and_(*conditions)).order_by(desc(Order.createdAt)).limit(limit)

    result = await db.execute(stmt)
    orders = result.scalars().all()

    # Commission rate
    comm_rate = getattr(restaurant, "commissionRate", 20.0) or 20.0
    commission_percent = (comm_rate * 100.0) if comm_rate <= 1.0 else float(comm_rate)
    commission_decimal = commission_percent / 100.0

    pure_grocery_keywords = [
        'atta', 'raw rice', 'dal', 'mustard oil', 'refined oil', 'ghee', 'washing powder',
        'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
        'harpic', 'vim bar', 'rin', 'tide', 'surf', 'namkeen packet', 'chips packet',
        'biscuit', 'sugar', 'salt', 'masala packet', 'spices', 'refill', 'packet', 'pouch',
        'campa', 'pepsi', 'coca cola', 'sprite', 'frooti', 'thums up', 'maaza', 'limca', 'sting'
    ]

    formatted_orders = []
    for o in orders:
        filtered_items = []
        food_sum = 0.0
        for it in o.items:
            it_prod = it.product
            p_rest = it_prod.restaurantId if it_prod else None
            name_l = (it.name or "").lower().strip()

            is_grocery = False
            if it_prod and it_prod.restaurantId is None:
                is_grocery = True
            elif any(gw in name_l for gw in pure_grocery_keywords):
                if not p_rest or p_rest != restaurant.id:
                    is_grocery = True

            # If it's a grocery item, skip it from the restaurant console!
            if is_grocery and (not p_rest or p_rest != restaurant.id):
                continue

            filtered_items.append({
                "id": it.id,
                "productId": it.productId,
                "name": it.name,
                "price": float(it.price),
                "quantity": it.quantity,
                "selectedVariant": it.selectedVariant,
                "imageUrl": it.imageUrl,
                "notes": it.notes,
            })
            food_sum += float(it.price) * it.quantity

        # If order had items but none belong to this restaurant, skip
        if not filtered_items and o.items:
            continue

        rest_packaging = float(o.miscFee or 0.0) if o.restaurantId else 0.0
        order_total = food_sum + rest_packaging

        clean_readable = o.readableId or (o.id[:8] if o.id else "")
        if o.combinedId and not clean_readable.endswith("-R") and not clean_readable.endswith("-G"):
            clean_readable = f"{clean_readable}-R"

        formatted_orders.append({
            "id": o.id,
            "readableId": clean_readable,
            "status": o.status.value if hasattr(o.status, "value") else str(o.status),
            "orderType": "RESTAURANT",
            "total": round(order_total, 2),
            "subtotal": round(food_sum, 2),
            "discount": float(o.discount or 0.0),
            "deliveryFee": 0.0,
            "taxes": float(o.taxes or 0.0),
            "miscFee": round(rest_packaging, 2),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, "value") else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, "value") else str(o.paymentStatus),
            "deliveryMethod": o.deliveryMethod,
            "restaurantId": o.restaurantId or restaurant.id,
            "restaurantName": restaurant.name,
            "shopName": o.shopName or restaurant.name,
            "notes": o.notes,
            "prepTime": getattr(o, "prepTime", None),
            "assignedChefId": o.assignedChefId,
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
            "user": {
                "name": o.user.name if o.user else "Customer",
                "phone": o.user.phone if o.user else "",
            },
            "address": {
                "houseNo": o.address.houseNo if o.address else "",
                "street": o.address.street if o.address else "",
                "area": o.address.area if o.address else "",
                "city": o.address.city if o.address else "",
                "pincode": o.address.pincode if o.address else "",
                "phone": o.address.phone if o.address else "",
            } if o.address else None,
            "items": filtered_items,
        })

    return {
        "orders": formatted_orders,
        "commissionRate": commission_percent,
        "commissionDecimal": commission_decimal,
        "restaurantName": restaurant.name,
    }


@restaurant_router.patch("/orders")
async def restaurant_dashboard_update_order(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Accept, pack, or reject an order from the restaurant dashboard.
    Actions: 'accept', 'pack', 'reject'.
    """
    from models import PaymentMethod, PaymentStatus
    role = str(current_user.get("role", "")).upper()
    if role not in ["RESTAURANT_OWNER", "ADMIN", "SUPER_ADMIN", "CHEF"]:
        raise HTTPException(status_code=403, detail="Forbidden")

    order_id = payload.get("orderId")
    action = payload.get("action")
    restaurant_id = payload.get("restaurantId")

    if not order_id or not action:
        raise HTTPException(status_code=400, detail="orderId and action are required")

    stmt = select(Order).options(selectinload(Order.items)).where(Order.id == order_id)
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    target_rest_id = restaurant_id or current_user.get("assignedRestaurantId")
    if role not in ["ADMIN", "SUPER_ADMIN"] and order.restaurantId != target_rest_id:
        raise HTTPException(status_code=403, detail="Forbidden: Order belongs to another restaurant")

    now = datetime.utcnow()

    if action == "accept":
        curr_status = order.status.value if hasattr(order.status, "value") else str(order.status)
        if curr_status != "PENDING":
            raise HTTPException(status_code=400, detail="Can only accept PENDING orders")

        curr_pm = order.paymentMethod.value if hasattr(order.paymentMethod, "value") else str(order.paymentMethod)
        curr_ps = order.paymentStatus.value if hasattr(order.paymentStatus, "value") else str(order.paymentStatus)

        if curr_pm != "COD" and curr_ps != "PAID":
            raise HTTPException(
                status_code=400,
                detail="Cannot accept order: Customer online payment is still pending."
            )

        order.status = OrderStatus.CONFIRMED
        order.confirmedAt = now

    elif action == "pack":
        curr_status = order.status.value if hasattr(order.status, "value") else str(order.status)
        if curr_status != "CONFIRMED":
            raise HTTPException(status_code=400, detail="Can only pack CONFIRMED orders")

        order.status = OrderStatus.PACKED
        order.packedAt = now

    elif action == "reject":
        curr_status = order.status.value if hasattr(order.status, "value") else str(order.status)
        if curr_status not in ["PENDING", "CONFIRMED"]:
            raise HTTPException(status_code=400, detail="Cannot reject this order")

        order.status = OrderStatus.CANCELLED
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use: accept, pack, reject")

    await db.commit()
    await db.refresh(order)

    # Broadcast real-time order status update
    try:
        await manager.broadcast({
            "event": "ORDER_STATUS_UPDATED",
            "orderId": order.id,
            "readableId": order.readableId,
            "status": order.status.value if hasattr(order.status, "value") else str(order.status),
            "restaurantId": order.restaurantId,
        })
    except Exception:
        pass

    return {
        "success": True,
        "order": {
            "id": order.id,
            "readableId": order.readableId,
            "status": order.status.value if hasattr(order.status, "value") else str(order.status),
            "total": float(order.total),
            "restaurantId": order.restaurantId,
            "updatedAt": now.isoformat()
        }
    }



@restaurant_router.get("/products")
async def restaurant_dashboard_products(
    restaurantId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner's products with strict outlet isolation."""
    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    if not restaurant:
        return {"products": [], "restaurant": None}

    stmt = select(Product).options(
        selectinload(Product.category)
    ).where(Product.restaurantId == restaurant.id).order_by(desc(Product.createdAt))
    result = await db.execute(stmt)
    products = result.scalars().all()
    return {
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "description": p.description,
                "price": float(p.price),
                "mrp": float(p.mrp) if p.mrp else float(p.price),
                "stock": p.stock,
                "isAvailable": p.isAvailable,
                "imageUrl": p.imageUrl,
                "menuSection": getattr(p, "menuSection", None) or (p.category.name if p.category else "Main Menu"),
                "category": {"id": p.category.id, "name": p.category.name} if p.category else None,
                "variants": p.variants,
                "tags": p.tags,
            }
            for p in products
        ],
        "restaurant": {
            "id": restaurant.id,
            "name": restaurant.name,
            "slug": restaurant.slug,
            "isOpen": restaurant.isOpen,
            "commissionRate": getattr(restaurant, "commissionRate", 20.0) or 20.0,
        }
    }


@restaurant_router.get("/products/{product_id}")
async def restaurant_dashboard_product_detail(
    product_id: str,
    restaurantId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner's product details with strict outlet verification."""
    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    result = await db.execute(select(Product).where(or_(Product.id == product_id, Product.slug == product_id)))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    is_admin = str(current_user.get("role", "")).upper() in ["ADMIN", "SUPER_ADMIN"]
    if not is_admin and restaurant and product.restaurantId != restaurant.id:
        raise HTTPException(status_code=403, detail="You do not have permission to view products belonging to another restaurant")

    return {"product": {
        "id": product.id, "name": product.name, "description": product.description,
        "price": product.price, "mrp": product.mrp, "stock": product.stock,
        "isAvailable": product.isAvailable, "imageUrl": product.imageUrl,
        "tags": product.tags, "variants": product.variants
    }}


@restaurant_router.post("/products")
async def restaurant_dashboard_create_product(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Add a new dish/product to the restaurant with strict outlet tenant isolation.
    Dishes are strictly attached to this restaurant and detached from grocery categories.
    """
    restaurant = await _resolve_effective_restaurant(payload.get("restaurantId"), current_user, db)
    if not restaurant:
        raise HTTPException(status_code=403, detail="No active restaurant assigned or found for this account")

    name = str(payload.get("name", "")).strip()
    if not name:
        raise HTTPException(status_code=400, detail="Dish name is required")

    # Generate unique slug
    base_slug = re.sub(r'[^a-z0-9\s-]', '', name.lower()).strip()
    base_slug = re.sub(r'\s+', '-', base_slug)
    slug = f"{restaurant.slug}-{base_slug}" if restaurant.slug else base_slug
    stmt_exist = select(Product).where(Product.slug == slug)
    res_exist = await db.execute(stmt_exist)
    if res_exist.scalars().first():
        slug = f"{slug}-{uuid.uuid4().hex[:4]}"

    def parse_float(val, default=0.0):
        if val is None or val == "":
            return default
        try:
            return float(val)
        except Exception:
            return default

    def parse_int(val, default=0):
        if val is None or val == "":
            return default
        try:
            return int(val)
        except Exception:
            return default

    raw_price = parse_float(payload.get("price"), 0.0)
    raw_mrp = parse_float(payload.get("mrp"), raw_price)
    variants = payload.get("variants")
    if variants and isinstance(variants, list) and len(variants) > 0:
        variants = sorted(variants, key=lambda x: parse_float(x.get("price", 0)))
        raw_price = parse_float(variants[0].get("price"), raw_price)
        raw_mrp = parse_float(variants[0].get("mrp"), raw_price)

    discount = max(0.0, round(((raw_mrp - raw_price) / raw_mrp) * 100.0)) if raw_mrp > raw_price else 0.0

    readable_id = None
    try:
        max_res = await db.execute(select(func.max(Product.readableId)))
        max_id = max_res.scalar() or 300000
        readable_id = int(max_id) + 1
    except Exception:
        pass

    new_dish = Product(
        id=str(uuid.uuid4()),
        readableId=readable_id,
        name=name,
        slug=slug,
        description=payload.get("description"),
        imageUrl=payload.get("imageUrl") or "🍲",
        restaurantId=restaurant.id,
        categoryId=None,
        mrp=raw_mrp,
        price=raw_price,
        discount=discount,
        unit=payload.get("unit") or "1 Serving",
        stock=parse_int(payload.get("stock"), 999),
        isAvailable=bool(payload.get("isAvailable", True)),
        tags=[str(t).strip() for t in payload.get("tags") if str(t).strip()] if isinstance(payload.get("tags"), list) else ["restaurant"],
        variants=variants if isinstance(variants, (list, dict)) else None,
        addons=payload.get("addons") if isinstance(payload.get("addons"), list) else None,
        costPrice=parse_float(payload.get("costPrice"), 0.0),
        sortOrder=parse_int(payload.get("sortOrder"), 0),
    )

    db.add(new_dish)
    await db.commit()
    await db.refresh(new_dish)

    try:
        await manager.broadcast_to_channel(f"restaurant_{restaurant.id}", {
            "event": "PRODUCT_CREATED",
            "productId": new_dish.id,
            "restaurantId": restaurant.id,
            "name": new_dish.name,
            "price": new_dish.price,
            "isAvailable": new_dish.isAvailable,
        })
        await manager.broadcast_to_channel("general", {
            "event": "PRODUCT_CREATED",
            "productId": new_dish.id,
            "restaurantId": restaurant.id,
        })
    except Exception:
        pass

    return {
        "success": True,
        "message": "Dish added successfully to restaurant menu",
        "product": {
            "id": new_dish.id,
            "name": new_dish.name,
            "price": new_dish.price,
            "mrp": new_dish.mrp,
            "discount": new_dish.discount,
            "isAvailable": new_dish.isAvailable,
            "stock": new_dish.stock,
            "restaurantId": new_dish.restaurantId,
            "imageUrl": new_dish.imageUrl,
        }
    }


@restaurant_router.patch("/products/{product_id}")
async def restaurant_dashboard_update_product(
    product_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update dish price, mrp, stock, availability, name, description or variants
    with strict restaurant tenant isolation.
    """
    restaurant = await _resolve_effective_restaurant(payload.get("restaurantId"), current_user, db)
    result = await db.execute(select(Product).where(or_(Product.id == product_id, Product.slug == product_id)))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    is_admin = str(current_user.get("role", "")).upper() in ["ADMIN", "SUPER_ADMIN"]
    if not is_admin and restaurant and product.restaurantId != restaurant.id:
        raise HTTPException(status_code=403, detail="You can only modify products belonging to your assigned restaurant")

    def parse_float(val, default=0.0):
        if val is None or val == "":
            return default
        try:
            return float(val)
        except Exception:
            return default

    def parse_int(val, default=0):
        if val is None or val == "":
            return default
        try:
            return int(val)
        except Exception:
            return default

    if "name" in payload and payload["name"]:
        product.name = str(payload["name"]).strip()
    if "description" in payload:
        product.description = str(payload["description"]).strip() if payload["description"] else None
    if "imageUrl" in payload and payload["imageUrl"]:
        product.imageUrl = str(payload["imageUrl"]).strip()
    if "unit" in payload and payload["unit"]:
        product.unit = str(payload["unit"]).strip()

    if "isAvailable" in payload:
        product.isAvailable = bool(payload["isAvailable"])
    if "stock" in payload:
        product.stock = parse_int(payload["stock"], product.stock or 0)

    # Price & MRP updates
    price_updated = False
    if "price" in payload:
        product.price = parse_float(payload["price"], product.price)
        price_updated = True
    if "mrp" in payload:
        product.mrp = parse_float(payload["mrp"], product.mrp)
        price_updated = True
    elif price_updated and (product.mrp is None or product.mrp < product.price):
        product.mrp = product.price

    if "costPrice" in payload:
        product.costPrice = parse_float(payload["costPrice"], product.costPrice or 0.0)

    # Recalculate discount %
    if product.mrp and product.price and product.mrp > product.price:
        product.discount = max(0.0, round(((product.mrp - product.price) / product.mrp) * 100.0))
    else:
        product.discount = 0.0

    if "variants" in payload:
        product.variants = payload["variants"] if isinstance(payload["variants"], (list, dict)) else None
    if "tags" in payload:
        product.tags = [str(t).strip() for t in payload["tags"] if str(t).strip()] if isinstance(payload["tags"], list) else product.tags

    await db.commit()
    await db.refresh(product)

    try:
        await manager.broadcast_to_channel(f"restaurant_{product.restaurantId}", {
            "event": "PRODUCT_UPDATED",
            "productId": product.id,
            "restaurantId": product.restaurantId,
            "name": product.name,
            "price": product.price,
            "mrp": product.mrp,
            "isAvailable": product.isAvailable,
            "stock": product.stock,
        })
        await manager.broadcast_to_channel("general", {
            "event": "PRODUCT_UPDATED",
            "productId": product.id,
            "restaurantId": product.restaurantId,
            "isAvailable": product.isAvailable,
        })
    except Exception:
        pass

    return {
        "success": True,
        "message": "Dish details updated successfully",
        "product": {
            "id": product.id,
            "name": product.name,
            "description": product.description,
            "isAvailable": product.isAvailable,
            "stock": product.stock,
            "price": product.price,
            "mrp": product.mrp,
            "discount": product.discount,
            "unit": product.unit,
            "imageUrl": product.imageUrl,
            "variants": product.variants,
        }
    }


@restaurant_router.delete("/products/{product_id}")
async def restaurant_dashboard_delete_product(
    product_id: str,
    restaurantId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a dish from the restaurant menu with strict tenant validation.
    Orders containing this product preserve their historical item records.
    """
    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    result = await db.execute(select(Product).where(or_(Product.id == product_id, Product.slug == product_id)))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    is_admin = str(current_user.get("role", "")).upper() in ["ADMIN", "SUPER_ADMIN"]
    if not is_admin and restaurant and product.restaurantId != restaurant.id:
        raise HTTPException(status_code=403, detail="You can only delete dishes belonging to your assigned restaurant")

    try:
        # Decouple foreign keys to preserve past order history
        await db.execute(text("UPDATE order_items SET \"productId\" = NULL WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        try:
            await db.execute(text("DELETE FROM reviews WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
            await db.execute(text("DELETE FROM cart_items WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        except Exception:
            pass

        prod_id = product.id
        rest_id = product.restaurantId
        await db.delete(product)
        await db.commit()

        try:
            if rest_id:
                await manager.broadcast_to_channel(f"restaurant_{rest_id}", {
                    "event": "PRODUCT_DELETED",
                    "productId": prod_id,
                    "restaurantId": rest_id,
                })
            await manager.broadcast_to_channel("general", {
                "event": "PRODUCT_DELETED",
                "productId": prod_id,
                "restaurantId": rest_id,
            })
        except Exception:
            pass

        return {"success": True, "message": "Dish deleted successfully from menu"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete dish: {str(e)}")


# ============================================================
# CAFE REPORTS
# ============================================================

cafe_router = APIRouter(prefix="/cafe", tags=["Cafe"])


@cafe_router.get("/reports")
async def cafe_reports(
    range: str = Query("7d"),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Cafe-specific sales reports."""
    days = 7 if range == "7d" else (30 if range == "30d" else 1)
    since = datetime.utcnow() - timedelta(days=days)

    stmt = select(
        func.date(Order.createdAt).label("date"),
        func.count(Order.id).label("orders"),
        func.coalesce(func.sum(Order.total), 0.0).label("revenue")
    ).where(
        and_(Order.createdAt >= since, Order.orderType == OrderType.RESTAURANT)
    ).group_by(func.date(Order.createdAt)).order_by(func.date(Order.createdAt))

    result = await db.execute(stmt)
    return {"reports": [
        {"date": str(r.date), "orders": r.orders, "revenue": float(r.revenue)}
        for r in result.all()
    ]}


# ============================================================
# RESTAURANT REPORTS (Owner & Web Kitchen Console)
# ============================================================

restaurant_report_router = APIRouter(prefix="/restaurant", tags=["Restaurant Reports"])


@restaurant_report_router.get("/reports")
async def restaurant_owner_reports(
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    restaurantId: Optional[str] = Query(None),
    range: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Comprehensive Restaurant Financials, Sales Analytics, and Dishes Sold Report.
    Used by Web Restaurant Console (RestaurantSalesConsole.tsx) and Flutter Kitchen.
    """
    from models import Restaurant, RestaurantPayout, StoreSetting, OrderItem
    from sqlalchemy import desc

    # 1. Resolve effective restaurant with multi-tenant isolation
    restaurant = await _resolve_effective_restaurant(restaurantId, current_user, db)
    if not restaurant:
        return {
            "summary": {
                "totalSales": 0.0,
                "totalCost": 0.0,
                "totalDiscount": 0.0,
                "totalTaxes": 0.0,
                "totalMisc": 0.0,
                "netProfit": 0.0,
                "restaurantProfit": 0.0,
                "adminProfit": 0.0,
                "ordersCount": 0,
                "avgOrderValue": 0.0,
                "commissionRate": 20.0,
                "profitShareRate": 80.0,
                "lastSettledDate": None,
                "lastSettledAmount": None,
                "lastSettledTxnId": None,
                "delivery": {"ordersCount": 0, "sales": 0.0, "restaurantProfit": 0.0, "adminProfit": 0.0},
                "pickup": {"ordersCount": 0, "sales": 0.0, "restaurantProfit": 0.0, "adminProfit": 0.0}
            },
            "dailySales": [],
            "topProducts": []
        }

    # 2. Time range calculation (IST-aware)
    ist_offset = timedelta(hours=5, minutes=30)
    now_utc = datetime.utcnow()
    now_ist = now_utc + ist_offset

    if startDate:
        try:
            start_local = datetime.strptime(f"{startDate[:10]} 00:00:00", "%Y-%m-%d %H:%M:%S")
            start = start_local - ist_offset
        except Exception:
            start = now_utc - timedelta(days=7)
    elif range == "today":
        start_local = datetime.combine(now_ist.date(), datetime.min.time())
        start = start_local - ist_offset
    elif range == "yesterday":
        start_local = datetime.combine((now_ist - timedelta(days=1)).date(), datetime.min.time())
        start = start_local - ist_offset
    elif range in ["30d", "30days"]:
        start = now_utc - timedelta(days=30)
    else:
        start = now_utc - timedelta(days=7)

    if endDate:
        try:
            end_local = datetime.strptime(f"{endDate[:10]} 23:59:59", "%Y-%m-%d %H:%M:%S")
            end = end_local - ist_offset
        except Exception:
            end = now_utc
    elif range == "yesterday":
        end_local = datetime.combine((now_ist - timedelta(days=1)).date(), datetime.max.time())
        end = end_local - ist_offset
    else:
        end = now_utc + timedelta(days=1)

    # 3. Commission rate resolution
    raw_comm = getattr(restaurant, "commissionRate", 20.0)
    if raw_comm is None:
        raw_comm = 20.0
    comm_rate_val = float(raw_comm)
    commission_rate_pct = comm_rate_val if comm_rate_val > 1.0 else (comm_rate_val * 100.0)
    commission_ratio = commission_rate_pct / 100.0
    profit_share_pct = 100.0 - commission_rate_pct
    restaurant_default_margin = 30.0

    # 4. Latest settled payout
    payout_stmt = select(RestaurantPayout).where(
        and_(RestaurantPayout.restaurantId == restaurant.id, RestaurantPayout.status == "PAID")
    ).order_by(desc(RestaurantPayout.paidAt)).limit(1)
    payout_res = await db.execute(payout_stmt)
    latest_payout = payout_res.scalars().first()

    # 5. Pure grocery keywords to prevent non-restaurant leak
    pure_grocery_keywords = [
        'atta', 'raw rice', 'dal', 'mustard oil', 'refined oil', 'ghee', 'washing powder',
        'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
        'harpic', 'vim bar', 'rin', 'tide', 'surf', 'namkeen packet', 'chips packet',
        'biscuit', 'sugar', 'salt', 'masala packet', 'spices', 'refill', 'packet', 'pouch',
        'campa', 'pepsi', 'coca cola', 'sprite', 'frooti', 'thums up', 'maaza', 'limca', 'sting',
        'cold drink'
    ]

    # 6. Fetch delivered orders strictly matching this restaurant
    orders_stmt = select(Order).options(
        selectinload(Order.items).selectinload(OrderItem.product)
    ).where(
        and_(
            Order.status.in_([OrderStatus.DELIVERED, "DELIVERED"]),
            Order.orderType != OrderType.GROCERY,
            or_(
                Order.restaurantId == restaurant.id,
                Order.items.any(OrderItem.productId.in_(
                    select(Product.id).where(Product.restaurantId == restaurant.id)
                ))
            ),
            Order.createdAt >= start,
            Order.createdAt <= end
        )
    ).order_by(Order.createdAt.asc())

    orders_res = await db.execute(orders_stmt)
    orders = orders_res.scalars().all()

    # Financial accumulators
    total_sales = 0.0
    total_cost = 0.0
    total_discount = 0.0
    total_taxes = 0.0
    total_misc = 0.0
    total_restaurant_profit = 0.0
    total_admin_profit = 0.0

    delivery_orders_count = 0
    delivery_sales = 0.0
    delivery_rest_profit = 0.0
    delivery_admin_profit = 0.0

    pickup_orders_count = 0
    pickup_sales = 0.0
    pickup_rest_profit = 0.0
    pickup_admin_profit = 0.0

    daily_trend_map: Dict[str, Dict[str, Any]] = {}
    top_products_map: Dict[str, Dict[str, Any]] = {}

    for o in orders:
        is_pickup = str(getattr(o, "deliveryMethod", "") or "").upper() in ["PICKUP", "SELF_PICKUP", "TAKEAWAY"]
        o_date_ist = (o.createdAt + ist_offset) if o.createdAt else now_ist
        date_key = o_date_ist.strftime("%d %b")

        if date_key not in daily_trend_map:
            daily_trend_map[date_key] = {
                "date": date_key,
                "sales": 0.0,
                "profit": 0.0,
                "adminProfit": 0.0,
                "orders": 0
            }

        daily_entry = daily_trend_map[date_key]
        daily_entry["orders"] += 1

        order_rest_sales = 0.0
        order_cost = 0.0
        order_rest_profit = 0.0
        order_admin_profit = 0.0

        for it in (o.items or []):
            p = it.product
            p_rest = p.restaurantId if p else None
            name_l = (it.name or "").lower().strip()

            # Skip grocery items
            is_grocery = False
            if p and p.restaurantId is None:
                is_grocery = True
            elif any(gw in name_l for gw in pure_grocery_keywords):
                if not p_rest or p_rest != restaurant.id:
                    is_grocery = True

            if is_grocery and (not p_rest or p_rest != restaurant.id):
                continue

            qty = int(it.quantity or 1)
            unit_price = float(it.price or 0.0)
            item_sales = unit_price * qty

            item_admin_profit = item_sales * commission_ratio
            item_rest_profit = item_sales - item_admin_profit

            # Cost calculation
            item_cost_per_unit = float(it.costPrice or (p.costPrice if p else 0.0) or 0.0)
            if item_cost_per_unit <= 0.0:
                item_cost_per_unit = unit_price * (1.0 - restaurant_default_margin / 100.0)
            item_cost = item_cost_per_unit * qty

            order_rest_sales += item_sales
            order_admin_profit += item_admin_profit
            order_rest_profit += item_rest_profit
            order_cost += item_cost

            # Top product tracking
            prod_key = f"{it.productId or it.name}_{it.selectedVariant or ''}"
            if prod_key not in top_products_map:
                top_products_map[prod_key] = {
                    "name": it.name + (f" ({it.selectedVariant})" if it.selectedVariant else ""),
                    "quantity": 0,
                    "sales": 0.0,
                    "profit": 0.0,
                    "adminProfit": 0.0
                }
            top_products_map[prod_key]["quantity"] += qty
            top_products_map[prod_key]["sales"] += item_sales
            top_products_map[prod_key]["profit"] += item_rest_profit
            top_products_map[prod_key]["adminProfit"] += item_admin_profit

        # If order had no specific items matching restaurant, use order food subtotal if restaurant order
        if order_rest_sales <= 0.0 and (o.restaurantId == restaurant.id):
            order_rest_sales = float(o.subtotal or o.total or 0.0)
            order_admin_profit = order_rest_sales * commission_ratio
            order_rest_profit = order_rest_sales - order_admin_profit
            order_cost = order_rest_sales * (1.0 - restaurant_default_margin / 100.0)

        if order_rest_sales > 0:
            total_sales += order_rest_sales
            total_admin_profit += order_admin_profit
            total_restaurant_profit += order_rest_profit
            total_cost += order_cost

            daily_entry["sales"] += order_rest_sales
            daily_entry["profit"] += order_rest_profit
            daily_entry["adminProfit"] += order_admin_profit

            if is_pickup:
                pickup_orders_count += 1
                pickup_sales += order_rest_sales
                pickup_rest_profit += order_rest_profit
                pickup_admin_profit += order_admin_profit
            else:
                delivery_orders_count += 1
                delivery_sales += order_rest_sales
                delivery_rest_profit += order_rest_profit
                delivery_admin_profit += order_admin_profit

    net_kitchen_profit = total_restaurant_profit - total_cost
    orders_count = len(orders)
    avg_order_value = (total_sales / orders_count) if orders_count > 0 else 0.0

    daily_sales = list(daily_trend_map.values())
    top_products = sorted(list(top_products_map.values()), key=lambda x: x["quantity"], reverse=True)

    return {
        "summary": {
            "totalSales": round(total_sales, 2),
            "totalCost": round(total_cost, 2),
            "totalDiscount": round(total_discount, 2),
            "totalTaxes": round(total_taxes, 2),
            "totalMisc": round(total_misc, 2),
            "restaurantProfit": round(total_restaurant_profit, 2),
            "adminProfit": round(total_admin_profit, 2),
            "netProfit": round(net_kitchen_profit, 2),
            "ordersCount": orders_count,
            "avgOrderValue": round(avg_order_value, 2),
            "commissionRate": round(commission_rate_pct, 1),
            "profitShareRate": round(profit_share_pct, 1),
            "lastSettledDate": latest_payout.paidAt.isoformat() if (latest_payout and latest_payout.paidAt) else None,
            "lastSettledAmount": float(latest_payout.amount) if (latest_payout and latest_payout.amount) else None,
            "lastSettledTxnId": latest_payout.transactionId if latest_payout else None,
            "delivery": {
                "ordersCount": delivery_orders_count,
                "sales": round(delivery_sales, 2),
                "restaurantProfit": round(delivery_rest_profit, 2),
                "adminProfit": round(delivery_admin_profit, 2),
            },
            "pickup": {
                "ordersCount": pickup_orders_count,
                "sales": round(pickup_sales, 2),
                "restaurantProfit": round(pickup_rest_profit, 2),
                "adminProfit": round(pickup_admin_profit, 2),
            }
        },
        "dailySales": daily_sales,
        "topProducts": top_products
    }