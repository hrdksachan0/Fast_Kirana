from fastapi import APIRouter, Depends, HTTPException, Query, Body, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import os
import re
import uuid
import logging

logger = logging.getLogger("settings")

from database import get_db
from models import Store, StoreSetting, DarkStore, StoreInventory, Restaurant
from routers.auth import require_auth, require_admin
from routers.stores_service import clear_stores_cache
import time

router = APIRouter(prefix="/settings", tags=["Settings & Location"])

_settings_cache: Dict[str, Any] = {}
_settings_cache_time: Dict[str, float] = {}
SETTINGS_CACHE_TTL: float = 30.0

def clear_settings_cache():
    global _settings_cache, _settings_cache_time
    _settings_cache.clear()
    _settings_cache_time.clear()

@router.post("/clear-cache")
async def api_clear_settings_cache():
    clear_settings_cache()
    clear_stores_cache()
    return {"success": True, "message": "Settings and stores cache cleared"}

DEFAULT_SUPPORT_PHONE = os.getenv("SUPPORT_PHONE", "+91 8112849854")

DEFAULT_SETTINGS = {
    "deliveries_count": "10,000+",
    "rating_value": "4.8",
    "happy_families": "5,000+",
    "trusted_text": "✨ Trusted by 5,000+ families in your town",
    "grocery_mart_open": "true",
    "cafe_open": "true",
    "restaurant_open": "true",
    "grocery_auto_timing": "false",
    "grocery_open_time": "06:00",
    "grocery_close_time": "23:59",
    "cafe_auto_timing": "false",
    "cafe_open_time": "06:00",
    "cafe_close_time": "23:59",
    "restaurant_auto_timing": "false",
    "restaurant_open_time": "06:00",
    "restaurant_close_time": "23:59",
    "delivery_radius": "2",
    "store_lat": "26.1534185",
    "store_lng": "80.1714024",
    "store_pincode": "209206",
    "store_phone": DEFAULT_SUPPORT_PHONE,
    "store_address": "NH34, Ghatampur, Kanpur Nagar",
    "shop_name": "FastKirana Dark Store",
    "min_order_value": "20",
    "avg_delivery_time": "8 min",
    "delivered_today": "1,231+",
    "fresh_stock_loaded": "2 hrs ago",
    "only_cod": "false",
    "tax_rate": "5",
    "misc_fee": "0",
    "misc_fee_label": "Miscellaneous Additions",
    "grocery_free_delivery_threshold": "149",
    "cafe_free_delivery_threshold": "149",
    "combined_free_delivery_threshold": "149",
    "delivery_threshold_tier1": "149",
    "delivery_threshold_tier2": "249",
    "delivery_threshold_tier3": "349",
    "delivery_fee": "25",
    "contact_phone": DEFAULT_SUPPORT_PHONE,
    "contact_email": "help@fastkirana.com",
    "contact_timings": "6 AM - 12 AM",
    "contact_address": "NH34, Ghatampur, Kanpur Nagar",
    "hero_greeting_closed": "We're resting right now 💤",
    "hero_subtitle_closed": "FastKirana Cafe & Mart are resting. We will be back to serve you fresh & hot goodies soon!",
    "hero_greeting_morning": "Good morning, let's get breakfast! 🌅",
    "hero_subtitle_morning_mart_closed": "Grocery Mart is resting, but our Cafe is firing up fresh hot brews and breakfast specials! ☕✨",
    "hero_subtitle_morning_cafe_closed": "Cafe is taking a break, but Grocery Mart is wide open and delivering fresh milk & fruits! 🥛📦",
    "hero_subtitle_morning_both_open": "Fresh milk, fruits, hot brews, and breakfast essentials delivered in minutes.",
    "hero_greeting_afternoon": "Good afternoon! Ready for lunch? 🍛",
    "hero_subtitle_afternoon_mart_closed": "Grocery Mart is resting, but our Cafe is cooking delicious hot lunch dishes and rolls! 🥡✨",
    "hero_subtitle_afternoon_cafe_closed": "Cafe is taking a break, but Grocery Mart is delivering lunch staples, dal, and rice! 🌾📦",
    "hero_subtitle_afternoon_both_open": "Atta, rice, dal, fresh vegetables, and delicious hot rolls delivered fast.",
    "hero_greeting_evening": "It's snack o'clock! Tea & snacks are ready ☕",
    "hero_subtitle_evening_mart_closed": "Grocery Mart is taking a break, but our Cafe is steaming hot chai & fresh samosas! ☕🥟",
    "hero_subtitle_evening_cafe_closed": "Cafe is resting, but Grocery Mart is delivering chips, biscuits, and munchies! 🍿📦",
    "hero_subtitle_evening_both_open": "Samosas, munchies, chips, and chilled soft drinks ready for tea time.",
    "hero_greeting_night": "Late night cravings? We got you! 🌙",
    "hero_subtitle_night_mart_closed": "Grocery Mart is closed. Cafe is open to deliver hot night snacks & dessert cravings! 🍧✨",
    "hero_subtitle_night_cafe_closed": "Cafe kitchen is resting, but Grocery Mart is active for ice cream, drinks & munchies! 🍦📦",
    "hero_subtitle_night_both_open": "Indulge in ice creams, chocolates, late night munchies, and cafe specialties.",
    "restaurant_commission": "10",
    "restaurant_profit_share": "15",
    "cafe_commission": "10",
    "cafe_profit_share": "15",
    "cafe_default_margin": "30",
    "restaurant_default_margin": "30",
    "whatsapp_notify_store_phone": "true",
    "store_alert_phones": "",
}


def get_ist_time() -> datetime:
    # Indian Standard Time (IST) = UTC + 5:30
    return datetime.utcnow() + timedelta(hours=5, minutes=30)


def check_is_store_open(settings_map: Dict[str, str], prefix: str) -> bool:
    auto_timing = settings_map.get(f"{prefix}_auto_timing") == "true"
    if not auto_timing:
        if prefix == "grocery":
            return settings_map.get("grocery_mart_open") != "false"
        if prefix == "cafe":
            return settings_map.get("cafe_open") != "false"
        return settings_map.get("restaurant_open") != "false"

    open_time = settings_map.get(f"{prefix}_open_time", "06:00")
    close_time = settings_map.get(f"{prefix}_close_time", "23:59")

    ist_now = get_ist_time()
    current_total = ist_now.hour * 60 + ist_now.minute

    try:
        open_h, open_m = map(int, open_time.split(":"))
        open_total = open_h * 60 + open_m
    except Exception:
        open_total = 6 * 60

    try:
        close_h, close_m = map(int, close_time.split(":"))
        close_total = close_h * 60 + close_m
    except Exception:
        close_total = 23 * 60 + 59

    if close_total >= open_total:
        return open_total <= current_total <= close_total
    else:
        # Midnight crossing
        return current_total >= open_total or current_total <= close_total


# ============================================================
# PUBLIC SETTINGS
# ============================================================

@router.get("")
async def get_public_settings(
    response: Response,
    storeId: Optional[str] = Query(None),
    hubId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Get public app settings (delivery zones, payment config, etc.)
    with dynamic open/close scheduler under IST timezone and multi-hub layering.
    Uses ultra-fast memory cache (<5ms response).
    """
    effective_store_id = storeId or hubId
    cache_key = str(effective_store_id or "default")
    now = time.time()

    if cache_key in _settings_cache and (now - _settings_cache_time.get(cache_key, 0)) < SETTINGS_CACHE_TTL:
        response.headers["Cache-Control"] = "public, s-maxage=30, stale-while-revalidate=60"
        response.headers["X-FastKirana-Cache"] = "HIT"
        return _settings_cache[cache_key]

    try:
        result = await db.execute(select(StoreSetting))
        settings_list = result.scalars().all()

        settings_map = DEFAULT_SETTINGS.copy()
        for s in settings_list:
            if not s.key.startswith("store:"):
                settings_map[s.key] = s.value

        # Layer store-scoped overrides if a specific dark store hub is queried
        if effective_store_id and effective_store_id != "all":
            store_prefix = f"store:{effective_store_id}:"
            for s in settings_list:
                if s.key.startswith(store_prefix):
                    sub_key = s.key[len(store_prefix):]
                    settings_map[sub_key] = s.value

            try:
                hub_res = await db.execute(select(DarkStore).where(DarkStore.id == effective_store_id))
                hub = hub_res.scalars().first()
                if hub:
                    settings_map["store_id"] = hub.id
                    settings_map["store_name"] = hub.name
                    settings_map["store_lat"] = str(hub.latitude)
                    settings_map["store_lng"] = str(hub.longitude)
                    if hub.deliveryRadiusKm:
                        settings_map["delivery_radius"] = str(hub.deliveryRadiusKm)
                    if hub.groceryOpen is not None:
                        settings_map["grocery_mart_open"] = "true" if hub.groceryOpen else "false"
            except Exception as hub_err:
                logger.warning(f"Failed to query specific hub {effective_store_id}: {hub_err}")

        # Dynamically evaluate store opening status in IST
        settings_map["grocery_mart_open"] = "true" if check_is_store_open(settings_map, "grocery") else "false"
        settings_map["cafe_open"] = "true" if check_is_store_open(settings_map, "cafe") else "false"
        settings_map["restaurant_open"] = "true" if check_is_store_open(settings_map, "restaurant") else "false"

        # Populate outlet statuses
        try:
            rest_res = await db.execute(select(Restaurant).where(Restaurant.isActive == True))
            for r in rest_res.scalars().all():
                from routers.stores_service import check_restaurant_is_open
                r_open = check_restaurant_is_open(r)
                settings_map[f"outlet_open_{r.id}"] = "true" if r_open else "false"
                if r.slug:
                    settings_map[f"outlet_open_{r.slug}"] = "true" if r_open else "false"
        except Exception as rest_err:
            logger.warning(f"Failed to populate outlet statuses in settings: {rest_err}")

        # Store in cache
        _settings_cache[cache_key] = settings_map
        _settings_cache_time[cache_key] = now

        response.headers["Cache-Control"] = "public, s-maxage=30, stale-while-revalidate=60"
        response.headers["X-FastKirana-Cache"] = "MISS"
        return settings_map
    except Exception as e:
        logger.error(f"Error in get_public_settings: {e}")
        # Fallback to defaults
        settings_map = DEFAULT_SETTINGS.copy()
        settings_map["grocery_mart_open"] = "true" if check_is_store_open(settings_map, "grocery") else "false"
        settings_map["cafe_open"] = "true" if check_is_store_open(settings_map, "cafe") else "false"
        settings_map["restaurant_open"] = "true" if check_is_store_open(settings_map, "restaurant") else "false"

        response.headers["Cache-Control"] = "public, s-maxage=30, stale-while-revalidate=60"
        return settings_map


@router.patch("")
async def update_settings(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update app settings (admin only). Supports storeId scoped overrides."""
    store_id = data.pop("storeId", None)
    is_store_scoped = bool(store_id and store_id != "all")
    prefix = f"store:{store_id}:" if is_store_scoped else ""

    for key, value in data.items():
        scoped_key = f"{prefix}{key}" if is_store_scoped else key
        result = await db.execute(select(StoreSetting).where(StoreSetting.key == scoped_key))
        setting = result.scalars().first()
        if setting:
            setting.value = str(value)
        else:
            setting = StoreSetting(key=scoped_key, value=str(value))
            db.add(setting)

        # If base Ghatampur hub, sync un-scoped legacy keys too
        if store_id == "hub-209206":
            base_res = await db.execute(select(StoreSetting).where(StoreSetting.key == key))
            base_setting = base_res.scalars().first()
            if base_setting:
                base_setting.value = str(value)
            else:
                db.add(StoreSetting(key=key, value=str(value)))

    # Sync DarkStore table fields for this specific hub or default central hub
    target_hub_id = store_id if (is_store_scoped and store_id) else "hub-209206"
    hub_res = await db.execute(select(DarkStore).where(DarkStore.id == target_hub_id))
    hub_obj = hub_res.scalars().first()
    if hub_obj:
        if "grocery_mart_open" in data:
            is_open = str(data["grocery_mart_open"]).lower() == "true"
            hub_obj.groceryOpen = is_open
            if is_open:
                hub_obj.closeReason = None
                hub_obj.pauseUntil = None
            else:
                hub_obj.closeReason = "MANUAL_OFF"
        if "delivery_radius" in data:
            try:
                hub_obj.deliveryRadiusKm = float(data["delivery_radius"])
            except Exception:
                pass
        if "store_lat" in data and "store_lng" in data:
            try:
                hub_obj.latitude = float(data["store_lat"])
                hub_obj.longitude = float(data["store_lng"])
            except Exception:
                pass

    await db.commit()
    clear_stores_cache()
    clear_settings_cache()
    return {"success": True}


# ============================================================
# SERVICEABILITY TOGGLE (PAUSE / RESUME / CLOSE_TODAY)
# ============================================================

from pydantic import BaseModel
from typing import Literal


class ServiceabilityToggleRequest(BaseModel):
    targetType: Literal["HUB", "RESTAURANT", "GLOBAL"] = "HUB"
    targetId: Optional[str] = None
    action: Literal["RESUME", "PAUSE", "CLOSE_TODAY"]
    pauseMinutes: Optional[int] = None
    reason: Optional[str] = "OPERATIONAL_ADJUSTMENT"
    customReasonText: Optional[str] = None


@router.post("/serviceability/toggle")
async def toggle_serviceability(
    body: ServiceabilityToggleRequest,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Pause, resume, or close-for-day a hub, restaurant, or the global platform.
    Zepto/Swiggy-style busy-mode toggling with mandatory reason for audit trail.
    """
    final_reason = (body.customReasonText or "").strip() or body.reason or "OPERATIONAL_ADJUSTMENT"
    now = datetime.utcnow()

    pause_until: Optional[datetime] = None
    is_open = True

    if body.action == "PAUSE":
        minutes = body.pauseMinutes or 30
        pause_until = now + timedelta(minutes=minutes)
        is_open = False
    elif body.action == "CLOSE_TODAY":
        pause_until = None
        is_open = False
    elif body.action == "RESUME":
        pause_until = None
        is_open = True

    # ── 1. HUB / DARKSTORE ──
    if body.targetType == "HUB":
        store_id = body.targetId or "hub-209206"

        hub_res = await db.execute(select(DarkStore).where(DarkStore.id == store_id))
        hub = hub_res.scalars().first()
        if not hub:
            raise HTTPException(status_code=404, detail=f"Hub '{store_id}' not found")

        hub.groceryOpen = is_open
        hub.pauseUntil = pause_until
        hub.closeReason = None if is_open else final_reason
        hub.closedByUserId = current_admin.get("id")

        # Sync StoreSetting for backward compatibility
        store_prefix = f"store:{store_id}:"
        scoped_key = f"{store_prefix}grocery_mart_open"
        scoped_res = await db.execute(select(StoreSetting).where(StoreSetting.key == scoped_key))
        scoped_setting = scoped_res.scalars().first()
        if scoped_setting:
            scoped_setting.value = str(is_open).lower()
        else:
            db.add(StoreSetting(key=scoped_key, value=str(is_open).lower()))

        # If it's the central hub, also sync the global legacy key
        if store_id == "hub-209206":
            base_res = await db.execute(select(StoreSetting).where(StoreSetting.key == "grocery_mart_open"))
            base_setting = base_res.scalars().first()
            if base_setting:
                base_setting.value = str(is_open).lower()
            else:
                db.add(StoreSetting(key="grocery_mart_open", value=str(is_open).lower()))

        await db.commit()
        clear_stores_cache()
        clear_settings_cache()

        status_str = "ONLINE" if is_open else ("PAUSED" if pause_until else "CLOSED")
        if is_open:
            msg = f"{hub.name} is now ONLINE and accepting orders."
        elif pause_until:
            msg = f"{hub.name} paused until {pause_until.strftime('%I:%M %p')}."
        else:
            msg = f"{hub.name} is CLOSED for the day."

        return {
            "success": True,
            "targetType": "HUB",
            "targetId": store_id,
            "storeName": hub.name,
            "status": status_str,
            "pauseUntil": pause_until.isoformat() if pause_until else None,
            "closeReason": hub.closeReason,
            "message": msg,
        }

    # ── 2. RESTAURANT / KITCHEN ──
    if body.targetType == "RESTAURANT":
        if not body.targetId:
            raise HTTPException(status_code=400, detail="targetId (restaurantId) is required for RESTAURANT toggle")

        rest_res = await db.execute(select(Restaurant).where(Restaurant.id == body.targetId))
        rest = rest_res.scalars().first()
        if not rest:
            raise HTTPException(status_code=404, detail=f"Restaurant '{body.targetId}' not found")

        rest.isOpen = is_open
        rest.pauseUntil = pause_until
        rest.closeReason = None if is_open else final_reason

        await db.commit()
        clear_stores_cache()
        clear_settings_cache()

        status_str = "ONLINE" if is_open else ("PAUSED" if pause_until else "CLOSED")
        if is_open:
            msg = f"{rest.name} kitchen is now OPEN."
        elif pause_until:
            msg = f"{rest.name} paused until {pause_until.strftime('%I:%M %p')}."
        else:
            msg = f"{rest.name} kitchen is CLOSED."

        return {
            "success": True,
            "targetType": "RESTAURANT",
            "targetId": body.targetId,
            "restaurantName": rest.name,
            "status": status_str,
            "pauseUntil": rest.pauseUntil.isoformat() if rest.pauseUntil else None,
            "closeReason": rest.closeReason,
            "message": msg,
        }

    # ── 3. GLOBAL PLATFORM ──
    if body.targetType == "GLOBAL":
        for key_name in ["global_store_open", "grocery_mart_open"]:
            key_res = await db.execute(select(StoreSetting).where(StoreSetting.key == key_name))
            existing = key_res.scalars().first()
            if existing:
                existing.value = str(is_open).lower()
            else:
                db.add(StoreSetting(key=key_name, value=str(is_open).lower()))

        await db.commit()
        clear_stores_cache()
        clear_settings_cache()

        return {
            "success": True,
            "targetType": "GLOBAL",
            "status": "ONLINE" if is_open else "CLOSED",
            "message": "Global platform is ONLINE." if is_open else "Global platform is set to EMERGENCY OFFLINE.",
        }

    raise HTTPException(status_code=400, detail="Invalid targetType")


# ============================================================
# LOCATION CHECKS & WAITLIST
# ============================================================

from models import DarkStore, StoreInventory, Restaurant
import math
import json
from sqlalchemy import func, text


def is_point_in_polygon(point: dict, polygon: list) -> bool:
    x = point.get("lat", 0.0)
    y = point.get("lng", 0.0)
    inside = False
    j = len(polygon) - 1
    for i in range(len(polygon)):
        xi = polygon[i].get("lat", 0.0)
        yi = polygon[i].get("lng", 0.0)
        xj = polygon[j].get("lat", 0.0)
        yj = polygon[j].get("lng", 0.0)

        intersect = ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi if (yj - yi) != 0 else 0.000001) + xi)
        if intersect:
            inside = not inside
        j = i
    return inside


def calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    d_lat = (lat2 - lat1) * (math.pi / 180.0)
    d_lon = (lon2 - lon1) * (math.pi / 180.0)
    a = (
        math.sin(d_lat / 2.0) * math.sin(d_lat / 2.0)
        + math.cos(lat1 * (math.pi / 180.0))
        * math.cos(lat2 * (math.pi / 180.0))
        * math.sin(d_lon / 2.0)
        * math.sin(d_lon / 2.0)
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


location_router = APIRouter(prefix="/location", tags=["Location"])


@location_router.get("/check-store")
async def check_nearest_store(
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Check if location is within a dark store's delivery polygon or radius.
    Returns full hub details, serviceability status, distance, inventory count, and coming soon status.
    """
    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="Missing coordinates (lat, lng required)")

    try:
        # Fetch all active dark stores
        stmt = select(DarkStore).where(DarkStore.isActive == True)
        res = await db.execute(stmt)
        stores = res.scalars().all()

        matched_store = None
        matched_distance_km = 0.0

        # 1. Check delivery polygon containment first
        for s in stores:
            if s.deliveryPolygon:
                try:
                    poly = s.deliveryPolygon
                    if isinstance(poly, str):
                        poly = json.loads(poly)
                    if isinstance(poly, list) and len(poly) >= 3:
                        if is_point_in_polygon({"lat": lat, "lng": lng}, poly):
                            matched_store = s
                            matched_distance_km = calculate_distance_km(lat, lng, float(s.latitude), float(s.longitude))
                            break
                except Exception as e:
                    pass

        # 2. Check circular delivery radius (Haversine distance)
        if not matched_store:
            closest_store = None
            min_dist = float("inf")
            for s in stores:
                dist = calculate_distance_km(lat, lng, float(s.latitude), float(s.longitude))
                allowed_radius = float(s.deliveryRadiusKm or 5.0)
                if dist <= allowed_radius and dist < min_dist:
                    min_dist = dist
                    closest_store = s

            if closest_store:
                matched_store = closest_store
                matched_distance_km = min_dist

        is_inside_zone = matched_store is not None

        # 3. Overall closest hub for distance reporting if outside zone
        closest_hub = None
        closest_hub_distance = float("inf")
        for s in stores:
            dist = calculate_distance_km(lat, lng, float(s.latitude), float(s.longitude))
            if dist < closest_hub_distance:
                closest_hub_distance = dist
                closest_hub = s

        target_store = matched_store or closest_hub or (stores[0] if stores else None)

        if not target_store:
            # Fallback mock central hub
            return {
                "id": "hub-209206",
                "name": "Ghatampur Central Hub",
                "latitude": 26.1534,
                "longitude": 80.1714,
                "isActive": True,
                "surgeCharge": 0.0,
                "groceryOpen": True,
                "deliveryPolygon": None,
                "deliveryRadiusKm": 5.0,
                "isServiceable": False,
                "distanceKm": 0.0,
                "hasInventory": False,
                "inventoryCount": 0,
                "hasRestaurants": False,
                "restaurantCount": 0,
                "isComingSoon": False,
            }

        # Check inventory & restaurant availability for this hub
        inventory_count = 0
        restaurant_count = 0
        try:
            inv_stmt = select(func.count(StoreInventory.productId)).where(
                StoreInventory.storeId == target_store.id,
                StoreInventory.stock > 0
            )
            inv_res = await db.execute(inv_stmt)
            inventory_count = inv_res.scalar() or 0

            rest_stmt = select(func.count(Restaurant.id)).where(
                Restaurant.isActive == True,
                Restaurant.storeId == target_store.id
            )
            rest_res = await db.execute(rest_stmt)
            restaurant_count = rest_res.scalar() or 0
        except Exception:
            pass

        is_coming_soon = is_inside_zone and inventory_count == 0 and restaurant_count == 0

        poly_data = target_store.deliveryPolygon
        if isinstance(poly_data, str):
            try:
                poly_data = json.loads(poly_data)
            except Exception:
                poly_data = None

        return {
            "id": target_store.id,
            "name": target_store.name,
            "latitude": float(target_store.latitude),
            "longitude": float(target_store.longitude),
            "isActive": target_store.isActive,
            "surgeCharge": float(target_store.surgeCharge or 0.0),
            "groceryOpen": getattr(target_store, "groceryOpen", True),
            "deliveryPolygon": poly_data,
            "deliveryRadiusKm": float(target_store.deliveryRadiusKm or 5.0),
            "isServiceable": is_inside_zone,
            "distanceKm": round(matched_distance_km if is_inside_zone else closest_hub_distance, 2),
            "hasInventory": inventory_count > 0,
            "inventoryCount": inventory_count,
            "hasRestaurants": restaurant_count > 0,
            "restaurantCount": restaurant_count,
            "isComingSoon": is_coming_soon,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"check-store error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@location_router.post("/notify-waitlist")
async def register_waitlist(payload: Dict[str, Any] = Body(...), db: AsyncSession = Depends(get_db)):
    """
    Registers customer phone for waitlist notification when an upcoming hub goes live.
    """
    phone = str(payload.get("phone", "")).strip()
    if not phone or len(re.sub(r"\D", "", phone)) < 10:
        raise HTTPException(status_code=400, detail="Please enter a valid 10-digit mobile number")

    cleaned_phone = re.sub(r"\D", "", phone)[-10:]
    lat = float(payload.get("latitude")) if payload.get("latitude") is not None else None
    lng = float(payload.get("longitude")) if payload.get("longitude") is not None else None
    final_hub = str(payload.get("hubName", "Upcoming Zone")).strip()
    final_area = str(payload.get("areaName", "")).strip() or None

    try:
        # Dynamically ensure table exists
        await db.execute(text("""
            CREATE TABLE IF NOT EXISTS hub_waitlist (
                id TEXT PRIMARY KEY,
                phone TEXT NOT NULL,
                latitude DOUBLE PRECISION,
                longitude DOUBLE PRECISION,
                hub_name TEXT,
                area_name TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        """))
        record_id = f"wait_{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:6]}"
        await db.execute(text("""
            INSERT INTO hub_waitlist (id, phone, latitude, longitude, hub_name, area_name, created_at)
            VALUES (:id, :phone, :lat, :lng, :hub_name, :area_name, NOW())
            ON CONFLICT (id) DO NOTHING;
        """), {
            "id": record_id,
            "phone": cleaned_phone,
            "lat": lat,
            "lng": lng,
            "hub_name": final_hub,
            "area_name": final_area
        })
        await db.commit()
    except Exception as e:
        await db.rollback()
        logger.warning(f"Waitlist insert error: {e}")

    return {
        "success": True,
        "message": f"Thanks! We will notify {cleaned_phone} on WhatsApp the moment FastKirana goes live in {final_hub}!"
    }
