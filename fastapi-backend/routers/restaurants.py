from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, not_, func, text
from typing import List, Dict, Any, Optional
import uuid
import re

from database import get_db
from models import Restaurant, User, Product, Order
from routers.auth import get_current_user, require_admin, require_auth

router = APIRouter(prefix="/restaurants", tags=["Restaurants"])


def generate_restaurant_slug(name: str) -> str:
    slug = name.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'\s+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')


@router.get("")
async def get_restaurants(
    cuisine: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    all: bool = Query(False),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List active or all restaurants, with cuisine and case-insensitive search queries.
    """
    role = current_user.get("role") if current_user else None
    is_admin = role == "ADMIN"

    filters = []
    if not is_admin or not all:
        filters.append(Restaurant.isActive == True)

    if cuisine:
        filters.append(Restaurant.cuisineTags.op('?')(cuisine))

    if search:
        filters.append(Restaurant.name.ilike(f"%{search}%"))

    stmt = select(Restaurant).where(*filters).order_by(Restaurant.sortOrder.desc(), Restaurant.createdAt.desc())
    res = await db.execute(stmt)
    restaurants = res.scalars().all()

    # Hydrate products counts & staff details
    result = []
    for r in restaurants:
        # Staff list query
        staff_stmt = select(User.id, User.name, User.email, User.phone, User.role, User.assignedRestaurantId).where(
            User.assignedRestaurantId == r.id
        )
        staff_res = await db.execute(staff_stmt)
        staff = [dict(s._mapping) for s in staff_res.all()]

        # Products count
        p_count_stmt = select(func.count(Product.id)).where(Product.restaurantId == r.id)
        p_count_res = await db.execute(p_count_stmt)
        p_count = p_count_res.scalar()

        r_dict = {
            "id": r.id,
            "name": r.name,
            "slug": r.slug,
            "description": r.description,
            "logoUrl": r.logoUrl,
            "bannerUrl": r.bannerUrl,
            "address": r.address,
            "city": r.city,
            "cuisineTags": r.cuisineTags,
            "deliveryTime": r.deliveryTime,
            "distance": r.distance,
            "lat": r.lat,
            "lng": r.lng,
            "isVeg": r.isVeg,
            "isPureVeg": r.isPureVeg,
            "isOpen": r.isOpen,
            "openTime": r.openTime,
            "closeTime": r.closeTime,
            "sortOrder": r.sortOrder,
            "discountOffer": r.discountOffer,
            "discountBadge": r.discountBadge,
            "commissionRate": r.commissionRate,
            "ownerPhone": r.ownerPhone,
            "ownerEmail": r.ownerEmail,
            "isActive": r.isActive,
            "rating": r.rating,
            "menuSections": r.menuSections,
            "createdAt": r.createdAt,
            "updatedAt": r.updatedAt,
            "staff": staff,
            "_count": {
                "products": p_count
            }
        }
        result.append(r_dict)

    return result


@router.post("", status_code=201)
async def create_restaurant(
    payload: Dict[str, Any] = Body(...),
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new restaurant and assign owners (Admin only).
    """
    name = payload.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="Missing required field: name")

    slug = generate_restaurant_slug(name)
    stmt_exist = select(Restaurant).where(Restaurant.slug == slug)
    res_exist = await db.execute(stmt_exist)
    if res_exist.scalars().first():
        slug = f"{slug}-{uuid.uuid4().hex[:4]}"

    owner_user_id = payload.get("ownerUserId")

    def parse_float(val, default=None):
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

    restaurant = Restaurant(
        id=str(uuid.uuid4()),
        name=name,
        slug=slug,
        description=payload.get("description"),
        logoUrl=payload.get("logoUrl"),
        bannerUrl=payload.get("bannerUrl"),
        address=payload.get("address"),
        city=payload.get("city"),
        cuisineTags=payload.get("cuisineTags", []),
        deliveryTime=payload.get("deliveryTime", "30-40 min"),
        distance=payload.get("distance", "0 km"),
        lat=parse_float(payload.get("lat")),
        lng=parse_float(payload.get("lng")),
        isVeg=bool(payload.get("isVeg", False)),
        isPureVeg=bool(payload.get("isPureVeg", False)),
        isOpen=bool(payload.get("isOpen", True)),
        openTime=payload.get("openTime", "09:00"),
        closeTime=payload.get("closeTime", "22:00"),
        sortOrder=parse_int(payload.get("sortOrder"), 0),
        discountOffer=payload.get("discountOffer"),
        discountBadge=payload.get("discountBadge"),
        commissionRate=parse_float(payload.get("commissionRate"), 0.15),
        ownerPhone=payload.get("ownerPhone"),
        ownerEmail=payload.get("ownerEmail"),
        isActive=bool(payload.get("isActive", True)),
        rating=parse_float(payload.get("rating"), 4.0),
        menuSections=payload.get("menuSections", [])
    )

    try:
        db.add(restaurant)
        await db.commit()

        # Update owner user role and assignment
        if owner_user_id:
            user_stmt = select(User).where(User.id == owner_user_id)
            user_res = await db.execute(user_stmt)
            user = user_res.scalars().first()
            if user:
                user.assignedRestaurantId = restaurant.id
                user.role = "RESTAURANT_OWNER"
                await db.commit()

        return restaurant
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create restaurant: {str(e)}")


@router.get("/{id}")
async def get_restaurant_details(
    id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed restaurant info by ID or Slug, including active staff list and order counts.
    """
    stmt = select(Restaurant).where(or_(Restaurant.id == id, Restaurant.slug == id))
    res = await db.execute(stmt)
    restaurant = res.scalars().first()

    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    # Fetch staff details
    staff_stmt = select(User.id, User.name, User.email, User.phone, User.role).where(
        User.assignedRestaurantId == restaurant.id
    )
    staff_res = await db.execute(staff_stmt)
    staff = [dict(s._mapping) for s in staff_res.all()]

    # Fetch counts
    p_count_stmt = select(func.count(Product.id)).where(Product.restaurantId == restaurant.id)
    p_count_res = await db.execute(p_count_stmt)
    p_count = p_count_res.scalar()

    o_count_stmt = select(func.count(Order.id)).where(Order.restaurantId == restaurant.id)
    o_count_res = await db.execute(o_count_stmt)
    o_count = o_count_res.scalar()

    r_dict = {
        "id": restaurant.id,
        "name": restaurant.name,
        "slug": restaurant.slug,
        "description": restaurant.description,
        "logoUrl": restaurant.logoUrl,
        "bannerUrl": restaurant.bannerUrl,
        "address": restaurant.address,
        "city": restaurant.city,
        "cuisineTags": restaurant.cuisineTags,
        "deliveryTime": restaurant.deliveryTime,
        "distance": restaurant.distance,
        "lat": restaurant.lat,
        "lng": restaurant.lng,
        "isVeg": restaurant.isVeg,
        "isPureVeg": restaurant.isPureVeg,
        "isOpen": restaurant.isOpen,
        "openTime": restaurant.openTime,
        "closeTime": restaurant.closeTime,
        "sortOrder": restaurant.sortOrder,
        "discountOffer": restaurant.discountOffer,
        "discountBadge": restaurant.discountBadge,
        "commissionRate": restaurant.commissionRate,
        "ownerPhone": restaurant.ownerPhone,
        "ownerEmail": restaurant.ownerEmail,
        "isActive": restaurant.isActive,
        "rating": restaurant.rating,
        "menuSections": restaurant.menuSections,
        "createdAt": restaurant.createdAt,
        "updatedAt": restaurant.updatedAt,
        "staff": staff,
        "_count": {
            "products": p_count,
            "orders": o_count
        }
    }

    return r_dict


@router.patch("/{id}")
async def update_restaurant(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update restaurant details. Admins can edit any restaurant; chefs/owners only their assigned restaurant.
    """
    role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")

    stmt = select(Restaurant).where(or_(Restaurant.id == id, Restaurant.slug == id))
    res = await db.execute(stmt)
    restaurant = res.scalars().first()

    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    is_admin = role == "ADMIN"
    is_owner_or_chef = role in ["RESTAURANT_OWNER", "CHEF"] and assigned_restaurant_id == restaurant.id

    if not is_admin and not is_owner_or_chef:
        raise HTTPException(status_code=403, detail="Unauthorized to edit this restaurant")

    owner_user_id = payload.get("ownerUserId")

    # Name change updates slug
    final_slug = restaurant.slug
    if payload.get("name") and payload.get("name") != restaurant.name:
        slug = generate_restaurant_slug(payload["name"])
        stmt_exist = select(Restaurant).where(Restaurant.slug == slug, Restaurant.id != restaurant.id)
        res_exist = await db.execute(stmt_exist)
        if res_exist.scalars().first():
            final_slug = f"{slug}-{uuid.uuid4().hex[:4]}"
        else:
            final_slug = slug

    allowed_keys = [
        'name', 'description', 'logoUrl', 'bannerUrl', 'address', 'city',
        'cuisineTags', 'deliveryTime', 'distance', 'lat', 'lng', 'isVeg',
        'isPureVeg', 'isOpen', 'openTime', 'closeTime', 'sortOrder',
        'discountOffer', 'discountBadge', 'commissionRate', 'ownerPhone',
        'ownerEmail', 'isActive', 'rating', 'menuSections'
    ]

    float_keys = ['lat', 'lng', 'commissionRate', 'rating']
    int_keys = ['sortOrder']

    for key in allowed_keys:
        if key in payload:
            # Enforce non-admin limits
            if not is_admin and key in ['commissionRate', 'isActive']:
                continue
            val = payload[key]
            if key in ['lat', 'lng']:
                if val is None or val == "":
                    val = None
                else:
                    try:
                        val = float(val)
                    except (ValueError, TypeError):
                        val = getattr(restaurant, key)
            elif key in ['commissionRate', 'rating']:
                if val is None or val == "":
                    val = getattr(restaurant, key, 10.0) or 10.0
                else:
                    try:
                        val = float(val)
                    except (ValueError, TypeError):
                        val = getattr(restaurant, key, 10.0) or 10.0
            elif key in int_keys:
                if val is None or val == "":
                    val = getattr(restaurant, key, 0) or 0
                else:
                    try:
                        val = int(val)
                    except (ValueError, TypeError):
                        val = getattr(restaurant, key, 0) or 0
            setattr(restaurant, key, val)

    restaurant.slug = final_slug

    try:
        res_id = restaurant.id
        await db.commit()

        # Update owner assignment if requested by ADMIN
        if owner_user_id and is_admin:
            # Unassign previous heads
            await db.execute(
                text('UPDATE users SET "assignedRestaurantId" = NULL WHERE "assignedRestaurantId" = :res_id AND id != :owner_id'),
                {"res_id": res_id, "owner_id": owner_user_id}
            )
            
            # Assign the new head
            user_stmt = select(User).where(User.id == owner_user_id)
            user_res = await db.execute(user_stmt)
            user = user_res.scalars().first()
            if user:
                user.assignedRestaurantId = res_id
                user.role = "RESTAURANT_OWNER"
            await db.commit()

        # Fetch fresh hydrated details
        fresh_dict = await get_restaurant_details(res_id, db)
        return fresh_dict
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update restaurant: {str(e)}")


@router.delete("/{id}")
async def delete_restaurant(
    id: str,
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Deactivate a restaurant (Admin only).
    """
    stmt = select(Restaurant).where(or_(Restaurant.id == id, Restaurant.slug == id))
    res = await db.execute(stmt)
    restaurant = res.scalars().first()

    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    try:
        restaurant.isActive = False
        await db.commit()
        return {"message": "Restaurant successfully deactivated"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete restaurant: {str(e)}")
