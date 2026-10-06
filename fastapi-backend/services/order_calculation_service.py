import os
import math
import time
import logging
import httpx
from typing import Optional, Dict, Any, Tuple, List

logger = logging.getLogger("order_calculation_service")


def calculate_coupon_discount(
    coupon_type: str,
    coupon_value: float,
    min_order_value: float,
    subtotal: float,
    max_discount: Optional[float] = None
) -> float:
    """
    Calculate effective coupon discount based on cart subtotal and limits.
    """
    if subtotal <= 0:
        return 0.0
    if subtotal < min_order_value:
        return 0.0

    c_type = (coupon_type or "FLAT").upper().strip()
    if c_type == "PERCENTAGE":
        raw_discount = (subtotal * float(coupon_value)) / 100.0
        if max_discount is not None and max_discount > 0:
            raw_discount = min(raw_discount, float(max_discount))
        return round(min(raw_discount, subtotal), 2)
    
    # FLAT discount
    raw_discount = float(coupon_value)
    return round(min(raw_discount, subtotal), 2)


def calculate_delivery_fee(
    subtotal: float,
    threshold: float,
    base_delivery_fee: float,
    surge_fee: float = 0.0
) -> float:
    """
    Calculate final delivery fee with free delivery threshold and surge charge.
    """
    surge = max(0.0, float(surge_fee))
    base = max(0.0, float(base_delivery_fee))
    thresh = float(threshold)

    if subtotal >= thresh:
        return round(surge, 2)
    return round(base + surge, 2)


def calculate_surge_fee(
    mode: str,
    manual_amount: float = 20.0,
    max_cap: float = 25.0,
    hub_surge_charge: float = 0.0,
    is_raining: bool = False,
    rain_amount: float = 20.0,
    demand_fee: float = 0.0
) -> float:
    """
    Calculate effective surge fee under AUTO, MANUAL_ON, or MANUAL_OFF modes.
    """
    s_mode = (mode or "MANUAL_OFF").upper().strip()
    cap = max(0.0, float(max_cap))

    if s_mode == "MANUAL_OFF":
        return 0.0
    if s_mode == "MANUAL_ON":
        return round(min(max(0.0, float(manual_amount)), cap), 2)

    # AUTO Mode: check hub-level override, then weather, then demand
    if hub_surge_charge > 0:
        return round(min(float(hub_surge_charge), cap), 2)
    if is_raining:
        return round(min(float(rain_amount), cap), 2)
    if demand_fee > 0:
        return round(min(float(demand_fee), cap), 2)

    return 0.0


# ── Strict Order Lifecycle State Machine ──
ALLOWED_STATUS_TRANSITIONS: Dict[str, list[str]] = {
    "ADMIN_PENDING": ["PENDING", "CONFIRMED", "CANCELLED"],
    "PENDING": ["CONFIRMED", "CANCELLED"],
    "CONFIRMED": ["PREPARING", "PACKED", "SHIPPED", "CANCELLED"],
    "PREPARING": ["PACKED", "SHIPPED", "CANCELLED"],
    "PACKED": ["SHIPPED", "CANCELLED"],
    "SHIPPED": ["DELIVERED", "CANCELLED"],
    "DELIVERED": [],  # Terminal state
    "CANCELLED": []   # Terminal state
}


def validate_status_transition(current_status: str, target_status: str) -> Tuple[bool, Optional[str]]:
    """
    Enforce state transitions so orders cannot make illogical jumps or revive from terminal states.
    """
    c_status = (current_status or "").upper().strip()
    t_status = (target_status or "").upper().strip()

    if c_status == t_status:
        return True, None

    if c_status in ["DELIVERED", "CANCELLED"]:
        return False, f"Cannot transition order from terminal state '{c_status}' to '{t_status}'."

    allowed = ALLOWED_STATUS_TRANSITIONS.get(c_status, [])
    if t_status not in allowed:
        return False, f"Invalid transition: '{c_status}' cannot transition directly to '{t_status}'."

    return True, None


# ── Delivery Distance & Zone Rules ──
def get_delivery_rules(distance_km: float, max_radius_km: float = 5.0, surge_fee: float = 0.0, settings_map: dict = None) -> dict:
    if settings_map is None:
        settings_map = {}

    tier1_fee = float(settings_map.get("delivery_fee_tier1", settings_map.get("delivery_fee", 25.0)))
    tier2_fee = float(settings_map.get("delivery_fee_tier2", 35.0))
    tier3_fee = float(settings_map.get("delivery_fee_tier3", 50.0))
    per_km_beyond_5km = float(settings_map.get("delivery_fee_per_km_beyond_5km", 10.0))

    tier1_threshold = float(settings_map.get("delivery_threshold_tier1", settings_map.get("grocery_free_delivery_threshold", 149.0)))
    tier2_threshold = float(settings_map.get("delivery_threshold_tier2", 249.0))
    tier3_threshold = float(settings_map.get("delivery_threshold_tier3", 349.0))

    # 1. Strictly check if distance exceeds max allowed radius
    if distance_km > max_radius_km:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": 0.0,
            "freeDeliveryThreshold": tier3_threshold + 100.0,
            "isServiceable": False,
            "zoneName": f"Outside Delivery Zone (> {max_radius_km:.1f} km)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 1: 0 - 2.0 km
    if distance_km <= 2.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": tier1_fee + surge_fee,
            "freeDeliveryThreshold": tier1_threshold,
            "isServiceable": True,
            "zoneName": "0 - 2 km (Local Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 2: 2.0 - 3.0 km
    if distance_km <= 3.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": tier2_fee + surge_fee,
            "freeDeliveryThreshold": tier2_threshold,
            "isServiceable": True,
            "zoneName": "2 - 3 km (Suburban Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 3: 3.0 - 5.0 km
    if distance_km <= 5.0:
        return {
            "distanceKm": distance_km,
            "minOrder": 0.0,
            "deliveryFee": tier3_fee + surge_fee,
            "freeDeliveryThreshold": tier3_threshold,
            "isServiceable": True,
            "zoneName": "3 - 5 km (Extended Zone)",
            "surgeFee": surge_fee,
            "maxRadiusKm": max_radius_km,
        }

    # Zone 4: Long Distance Beyond 5 km (up to max_radius_km, e.g. when manually increased)
    extra_km = math.ceil(distance_km - 5.0)
    long_distance_fee = tier3_fee + (extra_km * per_km_beyond_5km)
    long_distance_threshold = tier3_threshold + (extra_km * 50.0)

    return {
        "distanceKm": distance_km,
        "minOrder": 0.0,
        "deliveryFee": long_distance_fee + surge_fee,
        "freeDeliveryThreshold": long_distance_threshold,
        "isServiceable": True,
        "zoneName": f"5 - {max_radius_km:.0f} km (Long Distance Zone)",
        "surgeFee": surge_fee,
        "maxRadiusKm": max_radius_km,
    }


def get_product_type(p: Any) -> str:
    if getattr(p, "restaurantId", None):
        return "RESTAURANT"
    category = getattr(p, "category", None)
    category_slug = getattr(category, "slug", "") if category else ""
    tags_list = getattr(p, "tags", None) or []
    if category_slug == "cafe" or "cafe" in tags_list:
        return "CAFE"
    return "GROCERY"


def get_product_limit(p: Any) -> int:
    ptype = get_product_type(p)
    if ptype == "RESTAURANT":
        return 20
    if ptype == "CAFE":
        return 10
    return 10


# ── Weather-based Surge Evaluation ──
_weather_cache: Dict[str, dict] = {}
_weather_cache_ts: Dict[str, float] = {}
WEATHER_CACHE_TTL = 300  # 5 minutes


async def fetch_live_weather(lat: float = 26.1534, lng: float = 80.1714) -> dict:
    """Fetch current weather from Open-Meteo. Returns {temperature, condition, isRaining}."""
    key = f"{lat:.2f},{lng:.2f}"
    now = time.time()
    if key in _weather_cache and (now - _weather_cache_ts.get(key, 0)) < WEATHER_CACHE_TTL:
        return _weather_cache[key]

    try:
        async with httpx.AsyncClient(timeout=3) as client:
            resp = await client.get(
                f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,rain,showers,weather_code"
            )
            if resp.status_code != 200:
                return _weather_cache.get(key, {"temperature": 30, "condition": "Clear", "isRaining": False})
            data = resp.json()
            current = data.get("current", {})
            code = int(current.get("weather_code", 0))
            rain = float(current.get("rain", 0))
            showers = float(current.get("showers", 0))
            temp = float(current.get("temperature_2m", 30))

            heavy_rain_codes = [63, 65, 81, 82, 95, 96, 99]
            is_raining = (rain >= 1.5 or showers >= 1.5) or (rain >= 0.5 and code in heavy_rain_codes)

            condition = "Clear"
            if is_raining:
                condition = "Thunderstorm" if code in [95, 96, 99] else "Rain"
            elif code in [1, 2, 3]:
                condition = "Cloudy"

            result = {"temperature": temp, "condition": condition, "isRaining": is_raining}
            _weather_cache[key] = result
            _weather_cache_ts[key] = now
            return result
    except Exception as e:
        logger.warning(f"Weather fetch error: {e}")
        return _weather_cache.get(key, {"temperature": 30, "condition": "Clear", "isRaining": False})


async def evaluate_surge_fee(settings_map: dict, hub_lat: float = 26.1534, hub_lng: float = 80.1714, hub_surge_charge: float = 0.0) -> float:
    """Evaluate effective surge fee based on mode (AUTO/MANUAL_ON/MANUAL_OFF)."""
    mode = (settings_map.get("surge_mode") or "MANUAL_OFF").upper()
    max_cap = float(settings_map.get("surge_max_cap", 25))

    if mode == "MANUAL_OFF":
        return 0.0
    if mode == "MANUAL_ON":
        manual_amt = float(settings_map.get("surge_manual_amount", 20))
        return min(manual_amt, max_cap)

    # AUTO mode: check hub-level surgeCharge first, then weather, then demand
    if hub_surge_charge > 0:
        return min(hub_surge_charge, max_cap)

    weather = await fetch_live_weather(hub_lat, hub_lng)
    if weather.get("isRaining"):
        rain_amt = float(settings_map.get("surge_rain_amount", 20))
        logger.info(f"[Surge] Rain detected at ({hub_lat:.2f},{hub_lng:.2f}): {weather}. Applying rain surge Rs.{rain_amt}")
        return min(rain_amt, max_cap)

    demand_fee = float(settings_map.get("surge_charge", 0))
    return min(demand_fee, max_cap) if demand_fee > 0 else 0.0


# ── Google Maps Geocoding ──
async def geocode_address(address_str: str) -> Optional[dict]:
    api_key = os.getenv("GOOGLE_MAPS_API_KEY") or os.getenv("NEXT_PUBLIC_GOOGLE_MAPS_API_KEY")
    if not api_key:
        return None
    url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {"address": address_str, "key": api_key.strip()}
    try:
        async with httpx.AsyncClient(timeout=2) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("results") and data["results"][0].get("geometry", {}).get("location"):
                    loc = data["results"][0]["geometry"]["location"]
                    return {"lat": float(loc["lat"]), "lng": float(loc["lng"])}
    except Exception as e:
        logger.error(f"Google Maps geocode exception: {str(e)}")
    return None


# ── Addon Verification Engine ──
def resolve_verified_addon_price(db_prod: Any, sa: dict) -> float:
    """
    Look up and verify addon price strictly from the database product's addon configuration.
    Prevents client-side price tampering for food/grocery addons.
    """
    if not isinstance(sa, dict):
        return 0.0
    addon_name = sa.get("name")
    if not addon_name or not db_prod:
        return 0.0
    db_addons = getattr(db_prod, "addons", None)
    if not isinstance(db_addons, list):
        return 0.0
    for group in db_addons:
        if isinstance(group, dict) and isinstance(group.get("items"), list):
            matched = next((item for item in group["items"] if isinstance(item, dict) and item.get("name") == addon_name), None)
            if matched:
                return float(matched.get("price", 0.0))
    return 0.0


def calculate_item_addons(db_prod: Any, selected_addons: Optional[list]) -> Tuple[float, list]:
    """
    Validates all selected addons against DB product and returns total addon price + sanitized addon list.
    """
    if not selected_addons or not isinstance(selected_addons, list):
        return 0.0, []
    total = 0.0
    sanitized = []
    for sa in selected_addons:
        if not isinstance(sa, dict):
            continue
        verified_price = resolve_verified_addon_price(db_prod, sa)
        sa_copy = dict(sa)
        sa_copy["price"] = verified_price
        total += verified_price
        sanitized.append(sa_copy)
    return round(total, 2), sanitized
