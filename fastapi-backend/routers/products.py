from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import or_, and_, desc
from typing import List, Optional
import json
import redis.asyncio as aioredis

from database import get_db
from models import Product, Category
from schemas import ProductOut, CategoryOut
from config import settings

router = APIRouter(prefix="/products", tags=["Products & Catalog"])

# Initialize Redis client lazily
redis_client = None
if settings.REDIS_URL:
    try:
        redis_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    except Exception as e:
        print(f"Warning: Failed to connect to Redis: {e}")

@router.get("", response_model=List[ProductOut])
async def list_products(
    category_id: Optional[str] = Query(None, alias="categoryId"),
    restaurant_id: Optional[str] = Query(None, alias="restaurantId"),
    search: Optional[str] = Query(None),
    is_available: Optional[bool] = Query(True, alias="isAvailable"),
    is_flash_deal: Optional[bool] = Query(None, alias="isFlashDeal"),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db)
):
    """
    High-performance catalog listing with optional Redis caching & eager loaded categories
    """
    cache_key = f"prods:{category_id}:{restaurant_id}:{search}:{is_available}:{is_flash_deal}:{limit}"

    # Try Redis Cache Hit (<20ms)
    if redis_client:
        try:
            cached_data = await redis_client.get(cache_key)
            if cached_data:
                return json.loads(cached_data)
        except Exception:
            pass

    stmt = select(Product).options(selectinload(Product.category))

    conditions = []
    if is_available is not None:
        conditions.append(Product.isAvailable == is_available)
    if category_id:
        conditions.append(Product.categoryId == category_id)
    
    if restaurant_id is not None:
        if restaurant_id == "":
            conditions.append(Product.restaurantId == None)
        else:
            conditions.append(Product.restaurantId == restaurant_id)

    if is_flash_deal is not None:
        conditions.append(Product.isFlashDeal == is_flash_deal)

    if search:
        search_fmt = f"%{search}%"
        conditions.append(
            or_(
                Product.name.ilike(search_fmt),
                Product.slug.ilike(search_fmt),
                Product.description.ilike(search_fmt)
            )
        )

    if conditions:
        stmt = stmt.where(and_(*conditions))

    stmt = stmt.order_by(desc(Product.sortOrder), desc(Product.createdAt)).limit(limit)
    result = await db.execute(stmt)
    products = result.scalars().all()

    # Convert to Pydantic serializable dict for Redis caching
    pydantic_prods = [ProductOut.model_validate(p).model_dump(mode="json") for p in products]

    # Save to Redis with 60-second TTL
    if redis_client:
        try:
            await redis_client.setex(cache_key, 60, json.dumps(pydantic_prods))
        except Exception:
            pass

    return products

@router.get("/categories", response_model=List[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    """
    Returns category tree with 5-minute Redis caching
    """
    cache_key = "categories:all"

    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    stmt = select(Category).order_by(Category.sortOrder.asc())
    result = await db.execute(stmt)
    categories = result.scalars().all()

    pydantic_cats = [CategoryOut.model_validate(c).model_dump(mode="json") for c in categories]

    if redis_client:
        try:
            await redis_client.setex(cache_key, 300, json.dumps(pydantic_cats))
        except Exception:
            pass

    return categories

@router.get("/{product_id}", response_model=ProductOut)
async def get_product(product_id: str, db: AsyncSession = Depends(get_db)):
    stmt = select(Product).options(selectinload(Product.category)).where(Product.id == product_id)
    result = await db.execute(stmt)
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
