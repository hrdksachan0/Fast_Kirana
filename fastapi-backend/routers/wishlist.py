from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import delete
from typing import Dict, Any, Optional
from datetime import datetime
import uuid
import logging

from database import get_db
from models import WishlistItem, Product
from routers.auth import require_auth

logger = logging.getLogger("wishlist")

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])


@router.get("")
async def get_wishlist(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """List current user's wishlist items with category & product details."""
    try:
        user_id = current_user.get("id")
        stmt = (
            select(WishlistItem)
            .options(
                selectinload(WishlistItem.product).selectinload(Product.category)
            )
            .where(WishlistItem.userId == user_id)
            .order_by(WishlistItem.createdAt.desc())
        )
        res = await db.execute(stmt)
        items = res.scalars().all()

        formatted = []
        for it in items:
            p = it.product
            prod_dict = None
            if p:
                prod_dict = {
                    "id": p.id,
                    "name": p.name,
                    "slug": p.slug,
                    "price": float(p.price or 0),
                    "mrp": float(p.mrp if p.mrp is not None else (p.price or 0)),
                    "discount": p.discount or 0,
                    "unit": p.unit or "1 pc",
                    "stock": p.stock or 0,
                    "isAvailable": bool(p.isAvailable),
                    "imageUrl": p.imageUrl or "",
                    "variants": p.variants or [],
                    "tags": p.tags or [],
                    "category": {
                        "id": p.category.id,
                        "name": p.category.name,
                        "slug": p.category.slug
                    } if p.category else None
                }

            formatted.append({
                "id": it.id,
                "productId": it.productId,
                "createdAt": it.createdAt.isoformat() if it.createdAt else None,
                "product": prod_dict
            })

        return {"items": formatted}
    except Exception as e:
        logger.error(f"Wishlist GET error: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch wishlist")


@router.post("")
async def add_to_wishlist(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Add a product to user's wishlist."""
    product_id = payload.get("productId")
    if not product_id:
        raise HTTPException(status_code=400, detail="Product ID required")

    user_id = current_user.get("id")

    # Check if already in wishlist
    stmt = select(WishlistItem).where(
        WishlistItem.userId == user_id,
        WishlistItem.productId == product_id
    )
    res = await db.execute(stmt)
    existing = res.scalars().first()

    if existing:
        return {"item": {"id": existing.id, "productId": existing.productId, "userId": user_id}}

    new_id = f"wsh_{uuid.uuid4().hex[:20]}"
    item = WishlistItem(
        id=new_id,
        userId=user_id,
        productId=product_id,
        createdAt=datetime.utcnow()
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)

    return {"item": {"id": item.id, "productId": item.productId, "userId": user_id}}


@router.delete("")
async def remove_from_wishlist(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Remove a product from user's wishlist."""
    product_id = payload.get("productId")
    if not product_id:
        raise HTTPException(status_code=400, detail="Product ID required")

    user_id = current_user.get("id")
    stmt = delete(WishlistItem).where(
        WishlistItem.userId == user_id,
        WishlistItem.productId == product_id
    )
    await db.execute(stmt)
    await db.commit()

    return {"success": True}
