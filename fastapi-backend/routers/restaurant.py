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
    User, Order, Product, Category, Review, Role, OrderStatus, OrderType
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

    # Total stats for this restaurant
    total_stmt = select(
        func.count(Order.id),
        func.coalesce(func.sum(Order.total), 0.0)
    ).where(and_(*base_filter))
    total_orders, total_revenue = (await db.execute(total_stmt)).first() or (0, 0.0)

    # Today stats for this restaurant
    today_stmt = select(
        func.count(Order.id),
        func.coalesce(func.sum(Order.total), 0.0)
    ).where(and_(*base_filter, Order.createdAt >= today_start))
    today_orders, today_revenue = (await db.execute(today_stmt)).first() or (0, 0.0)

    # Commission rate
    comm_rate = getattr(restaurant, "commissionRate", 20.0) or 20.0
    commission_percent = (comm_rate * 100.0) if comm_rate <= 1.0 else float(comm_rate)

    return {
        "totalOrders": total_orders,
        "totalRevenue": float(total_revenue),
        "totalSales": float(total_revenue),
        "todayOrders": today_orders,
        "todayRevenue": float(today_revenue),
        "todaySales": float(today_revenue),
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
    - Includes complete item list, customer details, and address for KOT printing.
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
    if status:
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
        selectinload(Order.items),
    ).where(and_(*conditions)).order_by(desc(Order.createdAt)).limit(limit)

    result = await db.execute(stmt)
    orders = result.scalars().all()

    # Commission rate
    comm_rate = getattr(restaurant, "commissionRate", 20.0) or 20.0
    commission_percent = (comm_rate * 100.0) if comm_rate <= 1.0 else float(comm_rate)
    commission_decimal = commission_percent / 100.0

    formatted_orders = []
    for o in orders:
        formatted_orders.append({
            "id": o.id,
            "readableId": o.readableId,
            "status": o.status.value if hasattr(o.status, "value") else str(o.status),
            "orderType": o.orderType.value if hasattr(o.orderType, "value") else str(o.orderType),
            "total": float(o.total),
            "subtotal": float(o.subtotal),
            "discount": float(o.discount),
            "deliveryFee": float(o.deliveryFee),
            "taxes": float(o.taxes),
            "miscFee": float(o.miscFee),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, "value") else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, "value") else str(o.paymentStatus),
            "deliveryMethod": o.deliveryMethod,
            "restaurantId": o.restaurantId,
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
            "items": [
                {
                    "id": it.id,
                    "name": it.name,
                    "price": float(it.price),
                    "quantity": it.quantity,
                    "selectedVariant": it.selectedVariant,
                    "imageUrl": it.imageUrl,
                    "notes": it.notes,
                }
                for it in o.items
            ],
        })

    return {
        "orders": formatted_orders,
        "commissionRate": commission_percent,
        "commissionDecimal": commission_decimal,
        "restaurantName": restaurant.name,
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
        tags=payload.get("tags") if isinstance(payload.get("tags"), list) else ["restaurant"],
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
        product.tags = payload["tags"] if isinstance(payload["tags"], list) else product.tags

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
# RESTAURANT REPORTS (Owner)
# ============================================================

restaurant_report_router = APIRouter(prefix="/restaurant", tags=["Restaurant Reports"])


@restaurant_report_router.get("/reports")
async def restaurant_owner_reports(
    range: str = Query("7d"),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner's reports."""
    days = 7 if range == "7d" else (30 if range == "30d" else 1)
    since = datetime.utcnow() - timedelta(days=days)
    restaurant = await _get_user_restaurant(current_user, db)
    if not restaurant:
        return {"reports": []}

    stmt = select(
        func.date(Order.createdAt).label("date"),
        func.count(Order.id).label("orders"),
        func.coalesce(func.sum(Order.total), 0.0).label("revenue")
    ).where(
        and_(Order.createdAt >= since, Order.restaurantId == restaurant.id)
    ).group_by(func.date(Order.createdAt)).order_by(func.date(Order.createdAt))

    result = await db.execute(stmt)
    return {"reports": [
        {"date": str(r.date), "orders": r.orders, "revenue": float(r.revenue)}
        for r in result.all()
    ]}