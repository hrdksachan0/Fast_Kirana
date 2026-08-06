"""
Public Routes (no auth required)
Banners, coupons/validate, public settings, geocode
"""

from fastapi import APIRouter, Depends, HTTPException, Body, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, Optional
from datetime import datetime

from database import get_db
from models import Banner, StoreSetting, User, Order, OrderStatus, Coupon

router = APIRouter(prefix="/api", tags=["Public"])


# ============================================================
# BANNERS (Public)
# ============================================================

@router.get("/banners")
async def get_public_banners(
    type: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """Get active banners for public storefront."""
    stmt = select(Banner).where(Banner.isActive == True)
    if type == "cafe":
        stmt = stmt.where(Banner.title.ilike("%cafe%"))
    elif type == "grocery":
        stmt = stmt.where(or_(Banner.title.is_(None), ~Banner.title.ilike("%cafe%")))
    stmt = stmt.order_by(Banner.sortOrder)
    result = await db.execute(stmt)
    banners = result.scalars().all()
    return {"banners": [
        {"id": b.id, "title": b.title, "subtitle": b.subtitle,
         "imageUrl": b.imageUrl, "link": b.link}
        for b in banners
    ]}


# ============================================================
# COUPONS VALIDATE (Public, but rate-limited)
# ============================================================

@router.post("/coupons/validate")
async def validate_coupon(
    data: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """Validate a coupon code and calculate discount."""
    code = (data.get("code") or "").upper()
    subtotal = float(data.get("subtotal", 0))
    items = data.get("items", [])

    if not code:
        raise HTTPException(status_code=400, detail="Coupon code is required")

    stmt = select(Coupon).where(Coupon.code == code)
    result = await db.execute(stmt)
    coupon = result.scalars().first()
    if not coupon or not coupon.isActive:
        raise HTTPException(status_code=400, detail="Invalid or inactive coupon code")

    # Check expiration
    if coupon.expiresAt and coupon.expiresAt < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Coupon code has expired")

    # Check usage limit
    if coupon.maxUses and coupon.usedCount >= coupon.maxUses:
        raise HTTPException(status_code=400, detail="Coupon code limit reached")

    # Calculate discount
    eligible_subtotal = subtotal
    if coupon.categoryId:
        if not items:
            raise HTTPException(status_code=400, detail="Category-restricted coupon requires cart items")
        category_items = [i for i in items if i.get("categoryId") == coupon.categoryId]
        eligible_subtotal = sum(float(i.get("price", 0)) * int(i.get("quantity", 0)) for i in category_items)
        if eligible_subtotal == 0:
            raise HTTPException(status_code=400, detail="No items in the restricted category")
        if eligible_subtotal < coupon.minOrder:
            raise HTTPException(status_code=400, detail=f"Minimum order of ₹{coupon.minOrder} required")
    elif subtotal < coupon.minOrder:
        raise HTTPException(status_code=400, detail=f"Minimum order of ₹{coupon.minOrder} required")

    if coupon.discountType == "FLAT":
        discount = min(coupon.value, eligible_subtotal)
    elif coupon.discountType == "PERCENT":
        discount = (eligible_subtotal * coupon.value) / 100
        if coupon.maxDiscount:
            discount = min(discount, coupon.maxDiscount)
    else:
        discount = 0

    return {
        "message": "Coupon applied successfully!",
        "coupon": {
            "id": coupon.id, "code": coupon.code,
            "discountType": coupon.discountType, "value": coupon.value,
            "discountAmount": round(discount, 2),
        }
    }


# ============================================================
# GEOCODE (Google Maps proxy)
# ============================================================

@router.get("/geocode/key")
async def get_geocode_key(
    db: AsyncSession = Depends(get_db)
):
    """Return public Google Maps API key (client-side use)."""
    import os
    return {"key": os.getenv("GOOGLE_MAPS_API_KEY", "")}


@router.get("/geocode")
async def geocode_address(
    address: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Forward geocoding with Google Maps API."""
    import os
    import httpx
    api_key = os.getenv("GOOGLE_MAPS_API_KEY", "")
    if not api_key:
        raise HTTPException(status_code=503, detail="Geocoding not configured")
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://maps.googleapis.com/maps/api/geocode/json",
            params={"address": address, "key": api_key}
        )
        return response.json()