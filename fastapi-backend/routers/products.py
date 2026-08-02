from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, desc
from typing import List, Optional
from database import get_db
from models import Product, Category
from schemas import ProductOut, CategoryOut

router = APIRouter(prefix="/products", tags=["Products & Catalog"])

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
    High-performance catalog listing with restaurant & store filtering
    """
    stmt = select(Product)

    conditions = []
    if is_available is not None:
        conditions.append(Product.isAvailable == is_available)
    if category_id:
        conditions.append(Product.categoryId == category_id)
    
    # Strictly filter by restaurantId if provided (prevents darkstore products leaking into restaurant search)
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
    return products

@router.get("/categories", response_model=List[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    stmt = select(Category).order_by(Category.sortOrder.asc())
    result = await db.execute(stmt)
    return result.scalars().all()

@router.get("/{product_id}", response_model=ProductOut)
async def get_product(product_id: str, db: AsyncSession = Depends(get_db)):
    stmt = select(Product).where(Product.id == product_id)
    result = await db.execute(stmt)
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
