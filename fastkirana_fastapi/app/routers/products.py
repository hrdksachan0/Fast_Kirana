from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from ..core.database import get_db
from ..models.product import Product
from ..models.category import Category
from ..schemas.product import ProductOut

router = APIRouter(prefix="/products", tags=["Products"])

@router.get("", response_model=List[ProductOut])
def get_products(
    category: Optional[str] = None,
    restaurantId: Optional[str] = None,
    restaurantSlug: Optional[str] = None,
    search: Optional[str] = None,
    trending: Optional[bool] = False,
    limit: int = Query(100, le=200),
    page: int = 1,
    db: Session = Depends(get_db)
):
    query = db.query(Product).options(joinedload(Product.category)).filter(Product.isAvailable == True)

    if restaurantId:
        query = query.filter(Product.restaurantId == restaurantId)
    elif restaurantSlug:
        from ..models.restaurant import Restaurant
        rest = db.query(Restaurant).filter(Restaurant.slug == restaurantSlug).first()
        if rest:
            query = query.filter(Product.restaurantId == rest.id)
    elif category:
        slugs = [s.strip() for s in category.split(",") if s.strip()]
        cat_ids = [c.id for c in db.query(Category.id).filter(Category.slug.in_(slugs)).all()]
        if cat_ids:
            query = query.filter(Product.categoryId.in_(cat_ids))
    elif not search:
        # Default grocery view
        query = query.filter(Product.restaurantId == None)

    if search:
        search_fmt = f"%{search.lower().strip()}%"
        query = query.filter(
            Product.name.ilike(search_fmt) | Product.description.ilike(search_fmt)
        )

    if trending:
        query = query.filter(Product.isBestSeller == True)

    products = query.order_by(Product.sortOrder.desc(), Product.createdAt.desc()).limit(limit).all()
    return products

@router.get("/{id_or_slug}", response_model=ProductOut)
def get_product(id_or_slug: str, db: Session = Depends(get_db)):
    product = db.query(Product).options(joinedload(Product.category)).filter(
        (Product.id == id_or_slug) | (Product.slug == id_or_slug)
    ).first()
    if not product:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Product not found")
    return product
