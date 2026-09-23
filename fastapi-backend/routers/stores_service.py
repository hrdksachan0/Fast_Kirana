from fastapi import APIRouter, Depends, HTTPException, Query, Response, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, text
from typing import Optional, Dict, Any, List
import math
import time
import re
import logging

from database import get_db
from models import DarkStore, StoreSetting, Restaurant

logger = logging.getLogger("stores_service")

router = APIRouter(tags=["Store Status & Hubs"])

DEFAULT_STORE_LAT = 26.1534185
DEFAULT_STORE_LNG = 80.1714024


def get_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lng / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(R * c, 2)


def get_delivery_rules(distance_km: float, options: Dict[str, Any] = None) -> Dict[str, Any]:
    options = options or {}
    settings = options.get("settings", {})
    max_radius_km = float(options.get("maxRadiusKm") or settings.get("delivery_radius", 5.0))
    surge_fee = float(options.get("surgeFee") or 0)
    surge_reason = options.get("surgeReason")

    tier1_fee = float(options.get("tier1Fee") or settings.get("delivery_fee_tier1", settings.get("delivery_fee", 25)))
    tier2_fee = float(options.get("tier2Fee") or settings.get("delivery_fee_tier2", 35))
    tier3_fee = float(options.get("tier3Fee") or settings.get("delivery_fee_tier3", 50))
    per_km_beyond_5 = float(options.get("perKmFeeBeyond5km") or settings.get("delivery_fee_per_km_beyond_5km", 10))

    tier1_thresh = float(options.get("tier1Threshold") or settings.get("delivery_threshold_tier1", settings.get("grocery_free_delivery_threshold", 199)))
    tier2_thresh = float(options.get("tier2Threshold") or settings.get("delivery_threshold_tier2", 299))
    tier3_thresh = float(options.get("tier3Threshold") or settings.get("delivery_threshold_tier3", 399))

    raw_city = options.get("cityName") or options.get("storeName") or settings.get("store_name", "")
    city_match = re.sub(r"\s+(Hub|Market|Central|Dark\s*Store).*$", "", str(raw_city), flags=re.IGNORECASE).strip() or "Local"

    if distance_km > max_radius_km:
        return {
            "distanceKm": distance_km,
            "minOrder": 20,
            "deliveryFee": 0,
            "baseFee": 0,
            "freeDeliveryThreshold": tier3_thresh + 100,
            "isServiceable": False,
            "zoneName": f"Outside Delivery Zone (> {max_radius_km:.1f} km)",
            "surgeFee": surge_fee,
            "surgeReason": surge_reason,
            "maxRadiusKm": max_radius_km,
        }

    if distance_km <= 2.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0,
            "deliveryFee": tier1_fee + surge_fee,
            "baseFee": tier1_fee,
            "freeDeliveryThreshold": tier1_thresh,
            "isServiceable": True,
            "zoneName": f"0 - 2 km ({city_match} Local Zone)",
            "surgeFee": surge_fee,
            "surgeReason": surge_reason,
            "maxRadiusKm": max_radius_km,
        }

    if distance_km <= 3.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0,
            "deliveryFee": tier2_fee + surge_fee,
            "baseFee": tier2_fee,
            "freeDeliveryThreshold": tier2_thresh,
            "isServiceable": True,
            "zoneName": "2 - 3 km (Suburban Zone)",
            "surgeFee": surge_fee,
            "surgeReason": surge_reason,
            "maxRadiusKm": max_radius_km,
        }

    if distance_km <= 5.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0,
            "deliveryFee": tier3_fee + surge_fee,
            "baseFee": tier3_fee,
            "freeDeliveryThreshold": tier3_thresh,
            "isServiceable": True,
            "zoneName": "3 - 5 km (Extended Zone)",
            "surgeFee": surge_fee,
            "surgeReason": surge_reason,
            "maxRadiusKm": max_radius_km,
        }

    extra_km = math.ceil(distance_km - 5.0)
    long_distance_fee = tier3_fee + (extra_km * per_km_beyond_5)
    long_distance_thresh = tier3_thresh + (extra_km * 50)

    return {
        "distanceKm": distance_km,
        "minOrder": 0,
        "deliveryFee": long_distance_fee + surge_fee,
        "baseFee": long_distance_fee,
        "freeDeliveryThreshold": long_distance_thresh,
        "isServiceable": True,
        "zoneName": f"5 - {int(max_radius_km)} km (Long Distance Zone)",
        "surgeFee": surge_fee,
        "surgeReason": surge_reason,
        "maxRadiusKm": max_radius_km,
    }


# ─── 1. GET /stores/hubs ────────────────────────────────────────────────────────

@router.get("/stores/hubs")
async def get_store_hubs(
    response: Response,
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieve all active DarkStore hubs with delivery radius, coordinates, and surge info.
    Matches Next.js /api/stores/hubs exactly.
    """
    try:
        stmt = select(DarkStore).where(DarkStore.isActive == True).order_by(DarkStore.name.asc())
        res = await db.execute(stmt)
        stores = res.scalars().all()

        settings_stmt = select(StoreSetting)
        settings_res = await db.execute(settings_stmt)
        settings_list = settings_res.scalars().all()
        settings_map = {s.key: s.value for s in settings_list}

        formatted = []
        for s in stores:
            live_surge_fee = float(s.surgeCharge or 0)
            is_surge_active = live_surge_fee > 0
            surge_reason = ""
            city = re.sub(r"\s+(Hub|Market|Central|Dark\s*Store).*$", "", s.name, flags=re.IGNORECASE).strip()

            formatted.append({
                "id": s.id,
                "name": s.name,
                "latitude": float(s.latitude or DEFAULT_STORE_LAT),
                "longitude": float(s.longitude or DEFAULT_STORE_LNG),
                "deliveryRadiusKm": float(s.deliveryRadiusKm or 5.0),
                "isActive": bool(s.isActive),
                "groceryOpen": bool(getattr(s, "groceryOpen", True)),
                "surgeCharge": live_surge_fee,
                "surgeActive": is_surge_active,
                "surgeReason": surge_reason,
                "city": city,
            })

        response.headers["Cache-Control"] = "public, max-age=15, stale-while-revalidate=30"
        return {"success": True, "hubs": formatted}
    except Exception as e:
        logger.error(f"Failed to fetch store hubs: {e}")
        return {"success": False, "error": "Failed to fetch hubs", "hubs": []}


# ─── 2. GET /store-status ───────────────────────────────────────────────────────

@router.get("/store-status")
async def get_store_status(
    response: Response,
    hubId: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Check live operational status for grocery, cafe, and restaurants.
    Matches Next.js /api/store-status response schema.
    """
    try:
        target_hub_id = hubId or storeId

        # Settings query
        stmt = select(StoreSetting)
        res = await db.execute(stmt)
        settings_list = res.scalars().all()
        settings_map = {s.key: s.value for s in settings_list}

        # Restaurants query
        rest_stmt = select(Restaurant).where(Restaurant.isActive == True)
        rest_res = await db.execute(rest_stmt)
        restaurants = rest_res.scalars().all()

        outlet_statuses = {}
        for r in restaurants:
            outlet_statuses[r.id] = bool(r.isOpen)
            if r.slug:
                outlet_statuses[r.slug] = bool(r.isOpen)

        # Check hub grocery open status if hubId provided
        grocery_mart_open = settings_map.get("grocery_mart_open", "true").lower() == "true"
        if target_hub_id and target_hub_id != "all":
            hub_stmt = select(DarkStore).where(DarkStore.id == target_hub_id)
            hub_res = await db.execute(hub_stmt)
            hub = hub_res.scalars().first()
            if hub and hasattr(hub, "groceryOpen"):
                grocery_mart_open = bool(hub.groceryOpen)

        cafe_open = settings_map.get("cafe_open", "true").lower() == "true"
        restaurant_open = settings_map.get("restaurant_open", "true").lower() == "true"

        surge_fee = float(settings_map.get("surge_fee", "0") or 0)
        surge_active = surge_fee > 0

        payload = {
            "grocery_mart_open": "true" if grocery_mart_open else "false",
            "cafe_open": "true" if cafe_open else "false",
            "restaurant_open": "true" if restaurant_open else "false",
            "delivery_radius": settings_map.get("delivery_radius", "5.0"),
            "delivery_fee": settings_map.get("delivery_fee", "25"),
            "delivery_fee_tier1": settings_map.get("delivery_fee_tier1", "25"),
            "delivery_threshold_tier1": settings_map.get("delivery_threshold_tier1", "199"),
            "delivery_fee_tier2": settings_map.get("delivery_fee_tier2", "35"),
            "delivery_threshold_tier2": settings_map.get("delivery_threshold_tier2", "299"),
            "delivery_fee_tier3": settings_map.get("delivery_fee_tier3", "50"),
            "delivery_threshold_tier3": settings_map.get("delivery_threshold_tier3", "399"),
            "delivery_fee_per_km_beyond_5km": settings_map.get("delivery_fee_per_km_beyond_5km", "10"),
            "grocery_free_delivery_threshold": settings_map.get("grocery_free_delivery_threshold", "199"),
            "cafe_free_delivery_threshold": settings_map.get("cafe_free_delivery_threshold", "199"),
            "combined_free_delivery_threshold": settings_map.get("combined_free_delivery_threshold", "199"),
            "misc_fee": settings_map.get("misc_fee", "0"),
            "misc_fee_label": settings_map.get("misc_fee_label", "Miscellaneous Additions"),
            "store_lat": settings_map.get("store_lat", str(DEFAULT_STORE_LAT)),
            "store_lng": settings_map.get("store_lng", str(DEFAULT_STORE_LNG)),
            "surge_active": "true" if surge_active else "false",
            "surge_fee": str(surge_fee),
            "outlets": outlet_statuses,
            "timestamp": int(time.time() * 1000)
        }

        response.headers["Cache-Control"] = "public, s-maxage=10, stale-while-revalidate=30"
        return payload
    except Exception as e:
        logger.error(f"Store status API error: {e}")
        return {
            "grocery_mart_open": "true",
            "cafe_open": "true",
            "restaurant_open": "true",
            "delivery_radius": "5.0",
            "store_lat": str(DEFAULT_STORE_LAT),
            "store_lng": str(DEFAULT_STORE_LNG),
            "surge_active": "false",
            "surge_fee": "0",
            "outlets": {},
            "timestamp": int(time.time() * 1000)
        }


# ─── 3. GET /delivery-check ─────────────────────────────────────────────────────

@router.get("/delivery-check")
async def check_delivery(
    lat: float = Query(...),
    lng: float = Query(...),
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Calculate delivery distance and serviceability rules for customer coordinates.
    Matches Next.js /api/delivery-check.
    """
    try:
        store_lat = DEFAULT_STORE_LAT
        store_lng = DEFAULT_STORE_LNG
        max_radius_km = 5.0
        surge_fee = 0.0

        stmt = select(StoreSetting)
        res = await db.execute(stmt)
        settings_map = {s.key: s.value for s in res.scalars().all()}

        if storeId and storeId != "all":
            hub_stmt = select(DarkStore).where(DarkStore.id == storeId)
            hub_res = await db.execute(hub_stmt)
            hub = hub_res.scalars().first()
            if hub:
                if hub.latitude:
                    store_lat = float(hub.latitude)
                if hub.longitude:
                    store_lng = float(hub.longitude)
                if hub.deliveryRadiusKm:
                    max_radius_km = float(hub.deliveryRadiusKm)
                if hub.surgeCharge:
                    surge_fee = float(hub.surgeCharge)
        else:
            if settings_map.get("store_lat"):
                store_lat = float(settings_map["store_lat"])
            if settings_map.get("store_lng"):
                store_lng = float(settings_map["store_lng"])
            if settings_map.get("delivery_radius"):
                max_radius_km = float(settings_map["delivery_radius"])
            if settings_map.get("surge_fee"):
                surge_fee = float(settings_map["surge_fee"])

        dist_km = get_distance_km(store_lat, store_lng, lat, lng)
        rules = get_delivery_rules(dist_km, {
            "maxRadiusKm": max_radius_km,
            "surgeFee": surge_fee,
            "settings": settings_map,
            "storeName": settings_map.get("store_name", "Ghatampur Central Hub")
        })

        return rules
    except Exception as e:
        logger.error(f"Delivery check error: {e}")
        raise HTTPException(status_code=500, detail="Failed to check delivery")
