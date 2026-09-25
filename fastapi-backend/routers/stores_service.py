from fastapi import APIRouter, Depends, HTTPException, Query, Response, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, text
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
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


# ─── In-Memory TTL Cache for High Performance ────────────────────────────────────
_hubs_cache: Optional[Dict[str, Any]] = None
_hubs_cache_time: float = 0
HUBS_CACHE_TTL: float = 60.0

_status_cache: Dict[str, Any] = {}
_status_cache_time: float = 0
STATUS_CACHE_TTL: float = 30.0

def clear_stores_cache():
    global _hubs_cache, _hubs_cache_time, _status_cache, _status_cache_time
    _hubs_cache = None
    _hubs_cache_time = 0
    _status_cache.clear()
    _status_cache_time = 0


@router.post("/stores/clear-cache")
async def api_clear_stores_cache():
    clear_stores_cache()
    return {"success": True, "message": "Stores and status caches cleared"}


# ─── 1. GET /stores/hubs ────────────────────────────────────────────────────────

@router.get("/stores/hubs")
async def get_store_hubs(
    response: Response,
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieve all active DarkStore hubs with delivery radius, coordinates, and surge info.
    Uses in-memory cache (<5ms response).
    """
    global _hubs_cache, _hubs_cache_time
    now = time.time()
    if _hubs_cache and (now - _hubs_cache_time) < HUBS_CACHE_TTL:
        response.headers["Cache-Control"] = "public, max-age=30, stale-while-revalidate=60"
        response.headers["X-FastKirana-Cache"] = "HIT"
        return _hubs_cache

    try:
        stmt = select(DarkStore).where(DarkStore.isActive == True).order_by(DarkStore.name.asc())
        res = await db.execute(stmt)
        stores = res.scalars().all()

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

        _hubs_cache = {"success": True, "hubs": formatted}
        _hubs_cache_time = now

        response.headers["Cache-Control"] = "public, max-age=30, stale-while-revalidate=60"
        response.headers["X-FastKirana-Cache"] = "MISS"
        return _hubs_cache
    except Exception as e:
        logger.error(f"Failed to fetch store hubs: {e}")
        return {"success": False, "error": "Failed to fetch hubs", "hubs": []}


def get_ist_now() -> datetime:
    # Always compute exact Indian Standard Time: UTC + 5:30
    return datetime.utcnow() + timedelta(hours=5, minutes=30)


def parse_time_to_minutes(time_str: str) -> Optional[int]:
    if not time_str or not isinstance(time_str, str):
        return None
    clean = str(time_str).strip().upper()
    is_pm = "PM" in clean
    is_am = "AM" in clean
    clean = re.sub(r"[A-Z]", "", clean).strip()
    parts = clean.split(":")
    if len(parts) < 2:
        return None
    try:
        h = int(parts[0])
        m = int(parts[1])
        if is_pm and h < 12:
            h += 12
        if is_am and h == 12:
            h = 0
        return h * 60 + m
    except Exception:
        return None


def check_is_store_open(settings_map: Dict[str, str], prefix: str) -> bool:
    auto_timing = settings_map.get(f"{prefix}_auto_timing") == "true"
    if not auto_timing:
        if prefix == "grocery":
            return settings_map.get("grocery_mart_open") != "false"
        if prefix == "cafe":
            return settings_map.get("cafe_open") != "false"
        return settings_map.get("restaurant_open") != "false"

    open_time = settings_map.get(f"{prefix}_open_time") or ("06:00" if prefix == "grocery" else "10:00")
    close_time = settings_map.get(f"{prefix}_close_time") or ("23:59" if prefix == "grocery" else "22:00")

    ist_now = get_ist_now()
    current_min = ist_now.hour * 60 + ist_now.minute

    open_min = parse_time_to_minutes(open_time) or (6 * 60 if prefix == "grocery" else 10 * 60)
    close_min = parse_time_to_minutes(close_time) or (23 * 60 + 59 if prefix == "grocery" else 22 * 60)

    if (open_min == 0 and close_min >= 1439) or (open_min == close_min):
        return True

    if close_min >= open_min:
        return open_min <= current_min <= close_min
    else:
        # Crosses midnight, e.g. 18:00 to 02:00
        return current_min >= open_min or current_min <= close_min


def check_restaurant_is_open(restaurant: Any) -> bool:
    if not restaurant or not getattr(restaurant, "isActive", True):
        return False

    # 1. Operating hours check in IST
    open_time = getattr(restaurant, "openTime", None)
    close_time = getattr(restaurant, "closeTime", None)

    if open_time and close_time:
        open_min = parse_time_to_minutes(open_time)
        close_min = parse_time_to_minutes(close_time)
        if open_min is not None and close_min is not None:
            is_24h = open_min == 0 and (close_min >= 1439 or close_min == 0)
            if not is_24h:
                ist_now = get_ist_now()
                current_min = ist_now.hour * 60 + ist_now.minute
                if close_min >= open_min:
                    is_within = open_min <= current_min <= close_min
                else:
                    is_within = current_min >= open_min or current_min <= close_min
                if not is_within:
                    return False

    # 2. Check if manually paused today
    if not getattr(restaurant, "isOpen", True):
        up_at = getattr(restaurant, "updatedAt", None)
        if up_at:
            ist_now = get_ist_now()
            ist_up = up_at + timedelta(hours=5, minutes=30)
            # If paused on a previous day, auto-reopen today on schedule!
            if ist_up.date() < ist_now.date():
                return True
        return False

    return True


# ─── 2. GET /store-status ───────────────────────────────────────────────────────

@router.get("/store-status")
async def get_store_status(
    response: Response,
    hubId: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Check live operational status for grocery, cafe, and restaurants in Indian Standard Time (IST).
    Uses in-memory cache (<5ms response).
    """
    global _status_cache, _status_cache_time
    target_hub_id = hubId or storeId
    cache_key = str(target_hub_id or "all")
    now = time.time()

    if cache_key in _status_cache and (now - _status_cache_time) < STATUS_CACHE_TTL:
        response.headers["Cache-Control"] = "public, s-maxage=15, stale-while-revalidate=30"
        response.headers["X-FastKirana-Cache"] = "HIT"
        return _status_cache[cache_key]

    try:
        # Settings query
        stmt = select(StoreSetting)
        res = await db.execute(stmt)
        settings_list = res.scalars().all()
        settings_map = {s.key: s.value for s in settings_list if not s.key.startswith("store:")}

        # Layer store-scoped overrides if a specific dark store hub is queried
        if target_hub_id and target_hub_id != "all":
            store_prefix = f"store:{target_hub_id}:"
            for s in settings_list:
                if s.key.startswith(store_prefix):
                    sub_key = s.key[len(store_prefix):]
                    settings_map[sub_key] = s.value

            hub_stmt = select(DarkStore).where(DarkStore.id == target_hub_id)
            hub_res = await db.execute(hub_stmt)
            hub = hub_res.scalars().first()
            if hub:
                if hub.groceryOpen is not None and settings_map.get("grocery_auto_timing") != "true":
                    settings_map["grocery_mart_open"] = "true" if hub.groceryOpen else "false"
                if hub.deliveryRadiusKm:
                    settings_map["delivery_radius"] = str(hub.deliveryRadiusKm)

        # Restaurants query
        rest_stmt = select(Restaurant).where(Restaurant.isActive == True)
        rest_res = await db.execute(rest_stmt)
        restaurants = rest_res.scalars().all()

        outlet_statuses = {}
        for r in restaurants:
            r_open = check_restaurant_is_open(r)
            outlet_statuses[r.id] = r_open
            if r.slug:
                outlet_statuses[r.slug] = r_open

        # Evaluate live IST operational status
        grocery_mart_open = check_is_store_open(settings_map, "grocery")
        cafe_open = check_is_store_open(settings_map, "cafe")
        restaurant_open = check_is_store_open(settings_map, "restaurant")

        # Specific outlet overrides for main brands if active
        wedson = next((r for r in restaurants if "wedson" in (r.slug or "").lower() or "wedson" in (r.name or "").lower()), None)
        if wedson:
            restaurant_open = check_restaurant_is_open(wedson)
            if wedson.openTime:
                settings_map["restaurant_open_time"] = wedson.openTime
            if wedson.closeTime:
                settings_map["restaurant_close_time"] = wedson.closeTime

        cafe_outlet = next((r for r in restaurants if "cafe" in (r.slug or "").lower() or "cafe" in (r.name or "").lower() or "a.s." in (r.name or "").lower()), None)
        if cafe_outlet:
            cafe_open = check_restaurant_is_open(cafe_outlet)
            if cafe_outlet.openTime:
                settings_map["cafe_open_time"] = cafe_outlet.openTime
            if cafe_outlet.closeTime:
                settings_map["cafe_close_time"] = cafe_outlet.closeTime

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

        _status_cache[cache_key] = payload
        _status_cache_time = now

        response.headers["Cache-Control"] = "public, s-maxage=15, stale-while-revalidate=30"
        response.headers["X-FastKirana-Cache"] = "MISS"
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
