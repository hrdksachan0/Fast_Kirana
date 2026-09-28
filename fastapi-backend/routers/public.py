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


# In-memory directions route cache (Zero billing / Zero excess API calls)
_DIRECTIONS_CACHE = {}

@router.get("/directions")
async def get_directions(
    origin: str = Query(..., description="Origin lat,lng"),
    destination: str = Query(..., description="Destination lat,lng")
):
    """
    Get road-network directions polyline between two coordinates.
    Zero-cost architecture: In-memory cache + Free OSRM primary + Google Maps fallback.
    """
    import os
    import httpx

    cache_key = f"{origin}->{destination}"
    if cache_key in _DIRECTIONS_CACHE:
        return {"success": True, "cached": True, **_DIRECTIONS_CACHE[cache_key]}

    try:
        o_lat, o_lng = [float(x.strip()) for x in origin.split(",")]
        d_lat, d_lng = [float(x.strip()) for x in destination.split(",")]
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid coordinates format. Use lat,lng")

    # 1. TIER 1: Free Open-Source Routing Machine (OSRM, ₹0 cloud cost)
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            osrm_url = f"https://router.project-osrm.org/route/v1/driving/{o_lng},{o_lat};{d_lng},{d_lat}?overview=full&geometries=geojson"
            resp = await client.get(osrm_url)
            if resp.status_code == 200:
                data = resp.json()
                routes = data.get("routes", [])
                if routes:
                    raw_coords = routes[0].get("geometry", {}).get("coordinates", [])
                    points = [[c[1], c[0]] for c in raw_coords if len(c) >= 2]
                    result = {
                        "provider": "osrm",
                        "points": points,
                        "distanceMeters": routes[0].get("distance"),
                        "durationSeconds": routes[0].get("duration"),
                    }
                    _DIRECTIONS_CACHE[cache_key] = result
                    return {"success": True, "cached": False, **result}
    except Exception:
        pass

    # 2. TIER 2: Google Maps Directions API (Fallback if OSRM is down, cached)
    api_key = os.getenv("GOOGLE_MAPS_API_KEY", "")
    if api_key:
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                gmaps_url = "https://maps.googleapis.com/maps/api/directions/json"
                resp = await client.get(
                    gmaps_url,
                    params={
                        "origin": f"{o_lat},{o_lng}",
                        "destination": f"{d_lat},{d_lng}",
                        "mode": "driving",
                        "key": api_key,
                    }
                )
                if resp.status_code == 200:
                    data = resp.json()
                    routes = data.get("routes", [])
                    if routes:
                        polyline = routes[0].get("overview_polyline", {}).get("points")
                        leg = (routes[0].get("legs") or [{}])[0]
                        result = {
                            "provider": "google",
                            "polyline": polyline,
                            "distanceMeters": leg.get("distance", {}).get("value"),
                            "durationSeconds": leg.get("duration", {}).get("value"),
                        }
                        _DIRECTIONS_CACHE[cache_key] = result
                        return {"success": True, "cached": False, **result}
        except Exception:
            pass

    # 3. TIER 3: Geodesic fallback
    fallback = {
        "provider": "direct",
        "points": [[o_lat, o_lng], [d_lat, d_lng]],
    }
    return {"success": True, "cached": False, **fallback}


# ============================================================
# TELEMETRY & DIAGNOSTICS
# ============================================================

@router.post("/telemetry/errors")
async def report_client_error(
    payload: Dict[str, Any] = Body(...)
):
    """
    Ingest client telemetry error logs.
    """
    message = payload.get("message", "Unknown client error")
    severity = payload.get("severity", "ERROR")
    route = payload.get("route", "unknown")
    stack = payload.get("stack")
    metadata = payload.get("metadata")
    log_prefix = "🚨 [TELEMETRY_CRITICAL]" if severity == "CRITICAL" else "⚠️ [TELEMETRY_CLIENT_ERROR]"
    print(f"{log_prefix} [{route}] {message} metadata={metadata} stack={stack[:200] if stack else None}")
    return {"success": True, "received": True}


@router.post("/revalidate-bridge")
async def revalidate_bridge(
    payload: Dict[str, Any] = Body(default={}),
    x_api_secret: Optional[str] = None
):
    """
    Bridge cache revalidation endpoint.
    """
    import os
    auth_secret = os.getenv("AUTH_SECRET")
    if auth_secret and x_api_secret != auth_secret:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return {"success": True}


@router.get("/diagnostics")
async def get_system_diagnostics(
    db: AsyncSession = Depends(get_db)
):
    """
    System diagnostics report for admin and operations.
    """
    import os
    from sqlalchemy import func
    report = {
        "timestamp": datetime.utcnow().isoformat(),
        "env": {
            "NODE_ENV": os.getenv("NODE_ENV", "production"),
            "APP_ENV": os.getenv("APP_ENV", "production"),
            "DATABASE_URL": "CONFIGURED" if os.getenv("DATABASE_URL") else "MISSING",
        },
        "database": {
            "status": "unknown",
            "error": None,
            "userCount": 0,
        },
        "smtp": {
            "status": "CONFIGURED" if os.getenv("SMTP_HOST") else "NOT_CONFIGURED",
        }
    }
    try:
        res = await db.execute(select(func.count(User.id)))
        report["database"]["userCount"] = res.scalar() or 0
        report["database"]["status"] = "CONNECTED"
    except Exception as e:
        report["database"]["status"] = "FAILED"
        report["database"]["error"] = str(e)

    return report