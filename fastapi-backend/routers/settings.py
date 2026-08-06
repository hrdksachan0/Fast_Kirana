"""
Settings & Location Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, Optional

from database import get_db
from models import Store, StoreSetting
from routers.auth import require_auth, require_admin

router = APIRouter(prefix="/settings", tags=["Settings & Location"])


# ============================================================
# PUBLIC SETTINGS
# ============================================================

@router.get("")
async def get_public_settings(
    db: AsyncSession = Depends(get_db)
):
    """Get public app settings (delivery zones, payment config, etc.)."""
    result = await db.execute(select(StoreSetting))
    settings = result.scalars().all()
    return {"settings": {s.key: s.value for s in settings}}


@router.patch("")
async def update_settings(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update app settings (admin only)."""
    for key, value in data.items():
        result = await db.execute(select(StoreSetting).where(StoreSetting.key == key))
        setting = result.scalars().first()
        if setting:
            setting.value = str(value)
        else:
            setting = StoreSetting(key=key, value=str(value))
            db.add(setting)
    await db.commit()
    return {"success": True}


# ============================================================
# LOCATION CHECKS
# ============================================================

location_router = APIRouter(prefix="/location", tags=["Location"])


@location_router.get("/check-store")
async def check_nearest_store(
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    pincode: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """Check if location is within a store's delivery zone."""
    # Simple check - find nearest store
    stmt = select(Store).where(Store.isActive == True)
    result = await db.execute(stmt)
    stores = result.scalars().all()

    if not stores:
        return {"available": False, "message": "No stores found"}

    # If lat/lng provided, find nearest (simplified)
    # In production, use PostGIS for proper distance calculation
    nearest = None
    if lat is not None and lng is not None:
        for s in stores:
            if s.lat is not None and s.lng is not None:
                nearest = s
                break

    if pincode:
        # Match by pincode
        for s in stores:
            if s.address and pincode in s.address:
                nearest = s
                break

    if nearest:
        return {
            "available": True,
            "storeId": nearest.id,
            "storeName": nearest.name,
            "storeType": nearest.type,
        }
    return {"available": False, "message": "No store in your area"}
