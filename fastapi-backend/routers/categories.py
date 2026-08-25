from fastapi import APIRouter, Depends, HTTPException, status, Body, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from typing import Dict, Any, Optional
import uuid
import re
import httpx
import os
import asyncio

from database import get_db
from models import Category, Product
from routers.auth import require_admin

router = APIRouter(prefix="/categories", tags=["Categories"])


def generate_id(prefix: str = "cat_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r'[^a-z0-9]+', '-', text)
    text = re.sub(r'(^-|-$)+', '', text)
    return text


async def trigger_revalidation(category_slug: Optional[str] = None):
    """
    Trigger Next.js frontend cache revalidation in the background.
    """
    try:
        app_url = os.getenv("NEXT_PUBLIC_APP_URL", "http://localhost:3000")
        auth_secret = os.getenv("AUTH_SECRET", "")
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{app_url}/api/revalidate-bridge",
                json={"categorySlug": category_slug},
                headers={"x-api-secret": auth_secret},
                timeout=3.0
            )
    except Exception as e:
        print(f"Failed to trigger storefront revalidation: {e}")


@router.get("")
async def get_categories(
    response: Response,
    admin: Optional[str] = None,
    all: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Get all categories. If not admin/all, filters out 'cafe' and 'restaurant'.
    """
    include_all = (admin == "true") or (all == "true")

    try:
        # Build query to include count of products in each category
        stmt = (
            select(Category, func.count(Product.id).label("product_count"))
            .outerjoin(Product, Category.id == Product.categoryId)
        )

        if not include_all:
            stmt = stmt.where(~Category.slug.in_(["cafe", "restaurant"]))

        stmt = stmt.group_by(Category.id).order_by(Category.sortOrder.asc())

        result = await db.execute(stmt)
        categories_data = []
        for category, count in result:
            categories_data.append({
                "id": category.id,
                "name": category.name,
                "slug": category.slug,
                "imageUrl": category.imageUrl,
                "parentId": category.parentId,
                "sortOrder": category.sortOrder,
                "_count": {
                    "products": count
                }
            })

        response.headers["Cache-Control"] = "public, s-maxage=120, stale-while-revalidate=300"
        return categories_data
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch categories: {str(e)}"
        )


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: Dict[str, Any] = Body(...),
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new category. Only accessible by Admins.
    """
    name = payload.get("name")
    image_url = payload.get("imageUrl", "📦")
    sort_order = payload.get("sortOrder", 0)
    parent_id = payload.get("parentId")

    if not name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name is required"
        )

    try:
        slug = slugify(name)

        # Check if slug exists to generate a unique variant if needed
        stmt = select(Category).where(Category.slug == slug)
        result = await db.execute(stmt)
        existing = result.scalars().first()

        final_slug = slug
        if existing:
            # Append 4 random hex chars to make it unique
            final_slug = f"{slug}-{uuid.uuid4().hex[:4]}"

        # Parse sort order
        try:
            sort_order_int = int(sort_order)
        except (ValueError, TypeError):
            sort_order_int = 0

        new_category = Category(
            id=generate_id(),
            name=name,
            slug=final_slug,
            imageUrl=image_url,
            sortOrder=sort_order_int,
            parentId=parent_id if parent_id else None
        )

        db.add(new_category)
        await db.commit()
        await db.refresh(new_category)

        # Trigger Next.js storefront revalidation in background
        asyncio.create_task(trigger_revalidation(new_category.slug))

        # Replicate Prisma response structure
        return {
            "id": new_category.id,
            "name": new_category.name,
            "slug": new_category.slug,
            "imageUrl": new_category.imageUrl,
            "parentId": new_category.parentId,
            "sortOrder": new_category.sortOrder
        }

    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create category: {str(e)}"
        )


@router.patch("/{id}")
async def update_category(
    id: str,
    payload: Dict[str, Any] = Body(...),
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Update an existing category. Only accessible by Admins.
    """
    try:
        stmt = select(Category).where(Category.id == id)
        result = await db.execute(stmt)
        category = result.scalars().first()

        if not category:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Category not found"
            )

        name = payload.get("name")
        image_url = payload.get("imageUrl")
        sort_order = payload.get("sortOrder")
        parent_id = payload.get("parentId")

        if image_url is not None:
            category.imageUrl = image_url
        if sort_order is not None:
            try:
                category.sortOrder = int(sort_order)
            except (ValueError, TypeError):
                category.sortOrder = 0
        if "parentId" in payload:
            category.parentId = parent_id if parent_id else None

        if name is not None and name != category.name:
            category.name = name
            slug = slugify(name)

            # Check if slug exists for another category
            stmt_slug = select(Category).where(Category.slug == slug, Category.id != id)
            result_slug = await db.execute(stmt_slug)
            existing = result_slug.scalars().first()

            final_slug = slug
            if existing:
                final_slug = f"{slug}-{uuid.uuid4().hex[:4]}"
            category.slug = final_slug

        await db.commit()
        await db.refresh(category)

        # Trigger revalidation
        asyncio.create_task(trigger_revalidation(category.slug))

        return {
            "id": category.id,
            "name": category.name,
            "slug": category.slug,
            "imageUrl": category.imageUrl,
            "parentId": category.parentId,
            "sortOrder": category.sortOrder
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update category: {str(e)}"
        )


@router.delete("/{id}")
async def delete_category(
    id: str,
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete an existing category. Only accessible by Admins if it has no active products.
    """
    try:
        stmt = select(Category).where(Category.id == id)
        result = await db.execute(stmt)
        category = result.scalars().first()

        if not category:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Category not found"
            )

        # Check if category has associated products
        stmt_count = select(func.count(Product.id)).where(Product.categoryId == id)
        result_count = await db.execute(stmt_count)
        product_count = result_count.scalar() or 0

        if product_count > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Category contains active products. Please reassign or delete the products first."
            )

        category_slug = category.slug
        await db.delete(category)
        await db.commit()

        # Trigger revalidation
        asyncio.create_task(trigger_revalidation(category_slug))

        return {"success": True, "message": "Category deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete category: {str(e)}"
        )


@router.get("/catalog")
async def get_categories_catalog(
    includeProducts: bool = False,
    limitPerCat: int = 8,
    db: AsyncSession = Depends(get_db)
):
    """
    Get structured grocery categories catalog with product counts and preview items.
    """
    stmt = (
        select(Category)
        .where(~Category.slug.in_(["restaurant-food", "restaurant", "cafe"]))
        .order_by(Category.sortOrder.asc())
    )
    res = await db.execute(stmt)
    categories = res.scalars().all()

    formatted = []
    for cat in categories:
        # Product count
        count_stmt = select(func.count(Product.id)).where(
            Product.categoryId == cat.id,
            Product.restaurantId.is_(None),
            Product.isAvailable == True
        )
        count_res = await db.execute(count_stmt)
        p_count = count_res.scalar() or 0

        cat_dict = {
            "id": cat.id,
            "name": cat.name,
            "slug": cat.slug,
            "imageUrl": cat.imageUrl,
            "parentId": cat.parentId,
            "sortOrder": cat.sortOrder,
            "productCount": p_count,
            "products": []
        }

        if includeProducts:
            prods_stmt = select(Product).where(
                Product.categoryId == cat.id,
                Product.restaurantId.is_(None),
                Product.isAvailable == True
            ).order_by(Product.sortOrder.desc(), Product.createdAt.desc()).limit(limitPerCat)
            prods_res = await db.execute(prods_stmt)
            prods = prods_res.scalars().all()
            cat_dict["products"] = [{
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "price": p.price,
                "mrp": p.mrp,
                "discount": p.discount,
                "unit": p.unit,
                "stock": p.stock,
                "imageUrl": p.imageUrl
            } for p in prods]

        formatted.append(cat_dict)

    return {
        "success": True,
        "totalCategories": len(formatted),
        "categories": formatted
    }


@router.get("/{id}/products")
async def get_category_products(
    id: str,
    page: int = 1,
    limit: int = 30,
    sort: str = "default",
    search: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Get paginated grocery products for a specific category ID.
    """
    stmt = select(Category).where(
        or_(Category.id == id, Category.slug == id)
    )
    res = await db.execute(stmt)
    category = res.scalars().first()

    if not category:
        raise HTTPException(status_code=404, detail="Category not found")

    filters = [
        Product.categoryId == category.id,
        Product.restaurantId.is_(None),
        Product.isAvailable == True
    ]

    if search:
        filters.append(Product.name.ilike(f"%{search}%"))

    order_by_clause = [Product.sortOrder.desc(), Product.createdAt.desc()]
    if sort == "price-asc":
        order_by_clause = [Product.price.asc(), Product.sortOrder.desc()]
    elif sort == "price-desc":
        order_by_clause = [Product.price.desc(), Product.sortOrder.desc()]
    elif sort == "newest":
        order_by_clause = [Product.createdAt.desc()]
    elif sort == "popular":
        order_by_clause = [Product.isBestSeller.desc(), Product.sortOrder.desc()]

    count_stmt = select(func.count(Product.id)).where(*filters)
    count_res = await db.execute(count_stmt)
    total_count = count_res.scalar() or 0

    skip = (max(1, page) - 1) * limit
    prods_stmt = select(Product).where(*filters).order_by(*order_by_clause).offset(skip).limit(limit)
    prods_res = await db.execute(prods_stmt)
    products = prods_res.scalars().all()

    total_pages = (total_count + limit - 1) // limit if total_count > 0 else 1

    return {
        "success": True,
        "category": {
            "id": category.id,
            "name": category.name,
            "slug": category.slug,
            "imageUrl": category.imageUrl,
            "sortOrder": category.sortOrder
        },
        "pagination": {
            "totalItems": total_count,
            "totalPages": total_pages,
            "currentPage": page,
            "limit": limit,
            "hasNextPage": page < total_pages,
            "hasPrevPage": page > 1
        },
        "products": [{
            "id": p.id,
            "name": p.name,
            "slug": p.slug,
            "description": p.description,
            "imageUrl": p.imageUrl,
            "price": p.price,
            "mrp": p.mrp,
            "discount": p.discount,
            "unit": p.unit,
            "stock": p.stock,
            "isAvailable": p.isAvailable,
            "tags": p.tags,
            "categoryId": p.categoryId
        } for p in products]
    }
