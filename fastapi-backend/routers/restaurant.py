"""
Restaurant & Cafe Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_
from sqlalchemy.orm import selectinload
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
import uuid

from database import get_db
from models import (
    User, Order, Product, Category, Review, Role, OrderStatus, OrderType
)
from routers.auth import require_admin, require_auth

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
    """Get reviews for a restaurant."""
    # Restaurant's reviews are reviews on its products
    from models import Restaurant
    stmt = select(Restaurant).where(Restaurant.id == restaurant_id)
    rest_result = await db.execute(stmt)
    restaurant = rest_result.scalars().first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    stmt = select(Review).options(selectinload(Review.user)).join(
        Product, r.id == Product.id
    ).where(Product.restaurantId == restaurant_id).order_by(desc(Review.createdAt)).limit(limit)

    result = await db.execute(stmt)
    reviews = result.scalars().all()
    return {"reviews": [
        {"id": r.id, "rating": r.rating, "comment": r.comment,
         "user": {"id": r.user.id, "name": r.user.name, "image": r.user.image} if r.user else None,
         "createdAt": r.createdAt.isoformat() if r.createdAt else None}
        for r in reviews
    ]}


# ============================================================
# RESTAURANT DASHBOARD (Owner)
# ============================================================

restaurant_router = APIRouter(prefix="/restaurant-dashboard", tags=["Restaurant Dashboard"])


@restaurant_router.get("/stats")
async def restaurant_dashboard_stats(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Stats for restaurant owner dashboard."""
    user_id = current_user.get("id") or current_user.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Get restaurant managed by this user
    from models import Restaurant
    stmt = select(Restaurant).where(Restaurant.ownerId == user_id)
    result = await db.execute(stmt)
    restaurant = result.scalars().first()
    if not restaurant:
        return {"totalOrders": 0, "totalRevenue": 0, "todayOrders": 0, "todayRevenue": 0}

    today_start = datetime.combine(date.today(), datetime.min.time())

    # Total stats
    total_stmt = select(
        func.count(Order.id),
        func.coalesce(func.sum(Order.total), 0.0)
    ).where(Order.restaurantId == restaurant.id)
    total_orders, total_revenue = (await db.execute(total_stmt)).first() or (0, 0.0)

    # Today stats
    today_stmt = select(
        func.count(Order.id),
        func.coalesce(func.sum(Order.total), 0.0)
    ).where(and_(Order.restaurantId == restaurant.id, Order.createdAt >= today_start))
    today_orders, today_revenue = (await db.execute(today_stmt)).first() or (0, 0.0)

    return {
        "totalOrders": total_orders,
        "totalRevenue": float(total_revenue),
        "todayOrders": today_orders,
        "todayRevenue": float(today_revenue),
        "restaurantId": restaurant.id,
        "restaurantName": restaurant.name,
    }


@restaurant_router.get("/orders")
async def restaurant_dashboard_orders(
    status: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner view of orders."""
    user_id = current_user.get("id") or current_user.get("sub")
    from models import Restaurant
    stmt = select(Restaurant).where(Restaurant.ownerId == user_id)
    result = await db.execute(stmt)
    restaurant = result.scalars().first()
    if not restaurant:
        return {"orders": []}

    stmt = select(Order).options(selectinload(Order.user)).where(Order.restaurantId == restaurant.id)
    if status:
        stmt = stmt.where(Order.status == OrderStatus(status))
    stmt = stmt.order_by(desc(Order.createdAt)).limit(50)
    result = await db.execute(stmt)
    orders = result.scalars().all()
    return {"orders": [
        {"id": o.id, "readableId": o.readableId, "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
         "total": float(o.total), "user": {"name": o.user.name if o.user else None, "phone": o.user.phone if o.user else None},
         "createdAt": o.createdAt.isoformat() if o.createdAt else None}
        for o in orders
    ]}


@restaurant_router.get("/products")
async def restaurant_dashboard_products(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner's products."""
    user_id = current_user.get("id") or current_user.get("sub")
    from models import Restaurant
    stmt = select(Restaurant).where(Restaurant.ownerId == user_id)
    result = await db.execute(stmt)
    restaurant = result.scalars().first()
    if not restaurant:
        return {"products": []}

    stmt = select(Product).where(Product.restaurantId == restaurant.id).order_by(desc(Product.createdAt))
    result = await db.execute(stmt)
    products = result.scalars().all()
    return {"products": [
        {"id": p.id, "name": p.name, "price": p.price, "mrp": p.mrp,
         "stock": p.stock, "isAvailable": p.isAvailable, "imageUrl": p.imageUrl}
        for p in products
    ]}


@restaurant_router.get("/products/{product_id}")
async def restaurant_dashboard_product_detail(
    product_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant owner's product details."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"product": {
        "id": product.id, "name": product.name, "description": product.description,
        "price": product.price, "mrp": product.mrp, "stock": product.stock,
        "isAvailable": product.isAvailable, "imageUrl": product.imageUrl,
        "tags": product.tags, "variants": product.variants
    }}


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
    user_id = current_user.get("id") or current_user.get("sub")

    stmt = select(
        func.date(Order.createdAt).label("date"),
        func.count(Order.id).label("orders"),
        func.coalesce(func.sum(Order.total), 0.0).label("revenue")
    ).where(
        and_(Order.createdAt >= since, Order.userId == user_id)
    ).group_by(func.date(Order.createdAt)).order_by(func.date(Order.createdAt))

    result = await db.execute(stmt)
    return {"reports": [
        {"date": str(r.date), "orders": r.orders, "revenue": float(r.revenue)}
        for r in result.all()
    ]}