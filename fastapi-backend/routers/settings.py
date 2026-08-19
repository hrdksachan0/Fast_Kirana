from fastapi import APIRouter, Depends, HTTPException, Query, Body, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

from database import get_db
from models import Store, StoreSetting
from routers.auth import require_auth, require_admin

router = APIRouter(prefix="/settings", tags=["Settings & Location"])

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
    "store_phone": "+91 70544 70303",
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
    "grocery_free_delivery_threshold": "200",
    "cafe_free_delivery_threshold": "200",
    "combined_free_delivery_threshold": "200",
    "delivery_fee": "25",
    "contact_phone": "+91 70544 70303",
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
    db: AsyncSession = Depends(get_db)
):
    """
    Get public app settings (delivery zones, payment config, etc.)
    with dynamic open/close scheduler under IST timezone.
    """
    try:
        result = await db.execute(select(StoreSetting))
        settings_list = result.scalars().all()

        settings_map = DEFAULT_SETTINGS.copy()
        for s in settings_list:
            settings_map[s.key] = s.value

        # Dynamically evaluate store opening status in IST
        settings_map["grocery_mart_open"] = "true" if check_is_store_open(settings_map, "grocery") else "false"
        settings_map["cafe_open"] = "true" if check_is_store_open(settings_map, "cafe") else "false"
        settings_map["restaurant_open"] = "true" if check_is_store_open(settings_map, "restaurant") else "false"

        response.headers["Cache-Control"] = "public, max-age=5, stale-while-revalidate=30"
        return settings_map
    except Exception as e:
        # Fallback to defaults
        settings_map = DEFAULT_SETTINGS.copy()
        settings_map["grocery_mart_open"] = "true" if check_is_store_open(settings_map, "grocery") else "false"
        settings_map["cafe_open"] = "true" if check_is_store_open(settings_map, "cafe") else "false"
        settings_map["restaurant_open"] = "true" if check_is_store_open(settings_map, "restaurant") else "false"

        response.headers["Cache-Control"] = "public, max-age=5, stale-while-revalidate=30"
        return settings_map


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
