"""Store-scoped 6-Card Campaign Bento configuration & visibility engine for FastAPI."""

from copy import deepcopy
from datetime import datetime, timezone, timedelta
import json
import re
from typing import Any, Dict, List, Optional, Tuple

BENTO_PUBLISHED_KEY = "campaign_bento"
BENTO_DRAFT_KEY = "campaign_bento_draft"
STORE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")

DEFAULT_CAMPAIGN_BENTO_CONFIG: Dict[str, Any] = {
    "version": 1,
    "enabled": True,
    "seasonalSwitchUp": {
        "enabled": False,
        "sortOrder": 1,
        "badge": "01",
        "backgroundColor": "#D6EEFF",
        "borderColor": "#C0E2FD",
        "accentColor": "#0284C7",
        "textColor": "#1E3A8A",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "ALL_DAY",
        "targetHubs": ["all"],
        "title": "The Seasonal Switch-Up",
        "subtitle": "POWERED BY Cetaphil DOT & KEY",
        "tabs": [
            {"id": "body-lotions", "label": "Body Lotions", "icon": "🧴", "image": "/navratri/categories/body.png", "items": []},
            {"id": "face-moisturizers", "label": "Face Moisturizers", "icon": "✨", "image": "/navratri/categories/face.png", "items": []},
            {"id": "lip-balm", "label": "Lip Balm", "icon": "💄", "image": "/navratri/categories/lip.png", "items": []},
            {"id": "hair-care", "label": "Hair Care", "icon": "💆", "image": "/navratri/categories/hair.png", "items": []},
            {"id": "lip-mask", "label": "Lip Mask", "icon": "💋", "image": "/navratri/categories/lip.png", "items": []},
        ],
        "items": [],
    },
    "freshMarket": {
        "enabled": False,
        "sortOrder": 2,
        "badge": "02",
        "backgroundColor": "#E6F9EE",
        "borderColor": "#BBEFD2",
        "accentColor": "#15803D",
        "textColor": "#064E3B",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "ALL_DAY",
        "targetHubs": ["all"],
        "title": "Fresh Market",
        "subtitle": "Handpicked daily farm-fresh essentials",
        "headerImage": "/navratri/bloom-panoramic-header.svg",
        "pillLabel": "FARM FRESH",
        "ctaLabel": "See all fresh picks",
        "destinationCategorySlug": "fruits-vegetables",
        "tabs": [
            {
                "id": "sabzi",
                "label": "Sabzi",
                "icon": "🍅",
                "image": "/navratri/ref-fresh-tomato.png",
                "items": [
                    {
                        "id": "tomato",
                        "productId": None,
                        "keywords": ["tomato", "tamatar"],
                        "fallbackName": "Tomato",
                        "fallbackUnit": "500 g",
                        "fallbackPrice": 25,
                        "fallbackMrp": 30,
                        "fallbackImage": "/navratri/ref-fresh-tomato.png",
                    },
                    {
                        "id": "cucumber",
                        "productId": None,
                        "keywords": ["cucumber", "kheera"],
                        "fallbackName": "Cucumber",
                        "fallbackUnit": "500 g",
                        "fallbackPrice": 30,
                        "fallbackMrp": 35,
                        "fallbackImage": "/navratri/ref-fresh-cucumber.png",
                    },
                ],
            },
            {
                "id": "fruits",
                "label": "Fruits",
                "icon": "🥭",
                "image": "/navratri/summer-mango.svg",
                "items": [
                    {
                        "id": "mango",
                        "productId": None,
                        "keywords": ["mango", "safeda", "aam", "apple", "banana"],
                        "fallbackName": "Safeda Mango",
                        "fallbackUnit": "1 kg",
                        "fallbackPrice": 160,
                        "fallbackMrp": 200,
                        "fallbackImage": "/navratri/summer-mango.svg",
                    },
                ],
            },
            {
                "id": "herbs",
                "label": "Herbs",
                "icon": "🌿",
                "image": "/navratri/fresh-coriander.svg",
                "items": [
                    {
                        "id": "coriander",
                        "productId": None,
                        "keywords": ["coriander", "dhaniya"],
                        "fallbackName": "Fresh Coriander",
                        "fallbackUnit": "100 g",
                        "fallbackPrice": 15,
                        "fallbackMrp": 20,
                        "fallbackImage": "/navratri/fresh-coriander.svg",
                    },
                ],
            },
        ],
    },
    "dailyRestock": {
        "enabled": True,
        "sortOrder": 2,
        "badge": "02",
        "backgroundColor": "#F4F9FD",
        "borderColor": "#E0F2FE",
        "accentColor": "#0284C7",
        "textColor": "#0F172A",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "ALL_DAY",
        "targetHubs": ["all"],
        "title": "Daily Restock",
        "subtitle": "Everyday groceries at your fingertips",
        "headerImage": "/navratri/daily-grocery-basket.svg",
        "items": [
            {
                "id": "milk-daily",
                "productId": None,
                "keywords": ["milk", "taaza", "gold milk", "amul", "doodh"],
                "fallbackName": "Milk",
                "fallbackUnit": "500 ml",
                "fallbackPrice": 30,
                "fallbackMrp": 32,
                "fallbackImage": "/navratri/daily-milk.svg",
            },
            {
                "id": "bread-daily",
                "productId": None,
                "keywords": ["bread", "brown bread", "sandwich bread", "pav"],
                "fallbackName": "Bread",
                "fallbackUnit": "400 g",
                "fallbackPrice": 45,
                "fallbackMrp": 50,
                "fallbackImage": "/navratri/daily-bread.svg",
            },
            {
                "id": "atta-daily",
                "productId": None,
                "keywords": ["atta", "aashirvaad", "wheat flour", "chakki"],
                "fallbackName": "Atta",
                "fallbackUnit": "1 kg",
                "fallbackPrice": 55,
                "fallbackMrp": 65,
                "fallbackImage": "/navratri/ref-atta-1kg.png",
            },
        ],
    },
    "valuePicks": {
        "enabled": False,
        "sortOrder": 3,
        "badge": "03",
        "backgroundColor": "#FEFCE8",
        "borderColor": "#FEF08A",
        "accentColor": "#15803D",
        "textColor": "#78350F",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "ALL_DAY",
        "targetHubs": ["all"],
        "title": "Value Picks",
        "subtitle": "Save more on your daily essentials",
        "items": [
            {
                "id": "atta-value-1kg",
                "productId": None,
                "keywords": ["atta 1kg", "1 kg atta", "atta"],
                "perUnitLabel": "₹60/kg",
                "fallbackName": "Atta",
                "fallbackUnit": "1 kg",
                "fallbackPrice": 60,
                "fallbackMrp": 68,
                "fallbackImage": "/navratri/ref-atta-1kg.png",
            },
            {
                "id": "atta-value-5kg",
                "productId": None,
                "keywords": ["atta 5kg", "5 kg atta", "5kg", "aashirvaad 5"],
                "badge": "Better value",
                "perUnitLabel": "₹50/kg",
                "fallbackName": "Atta 5kg",
                "fallbackUnit": "5 kg",
                "fallbackPrice": 250,
                "fallbackMrp": 295,
                "fallbackImage": "/navratri/ref-atta-5kg.png",
            },
        ],
    },
    "giftingBoutique": {
        "enabled": True,
        "sortOrder": 4,
        "badge": "",
        "backgroundColor": "#FDF2F4",
        "borderColor": "#FCE7F3",
        "accentColor": "#15803D",
        "textColor": "#831843",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "ALL_DAY",
        "targetHubs": ["all"],
        "title": "Gifting Boutique",
        "subtitle": "Thoughtful gifts for special occasions",
        "heroItem": {
            "id": "rose-bouquet",
            "productId": None,
            "keywords": ["rose", "bouquet", "flower", "gift box", "ferrero", "celebrations"],
            "fallbackName": "Rose bouquet",
            "fallbackUnit": "8 stems",
            "fallbackPrice": 399,
            "fallbackMrp": 499,
            "fallbackImage": "/navratri/ref-rose-bouquet.png",
        },
        "miniItem": {
            "id": "choco-cake",
            "productId": None,
            "keywords": ["chocolate cake", "cake", "dairy milk", "silk", "chocolate"],
            "fallbackName": "Chocolate cake",
            "fallbackUnit": "500 g",
            "fallbackPrice": 499,
            "fallbackMrp": 599,
            "fallbackImage": "/navratri/ref-chocolate-cake.png",
        },
        "occasions": [
            {"id": "birthday", "label": "Birthday", "icon": "🎂"},
            {"id": "anniversary", "label": "Anniversary", "icon": "🤍"},
        ],
    },
    "movieNight": {
        "enabled": False,
        "sortOrder": 5,
        "badge": "05",
        "backgroundColor": "#251640",
        "borderColor": "#382458",
        "accentColor": "#15803D",
        "textColor": "#FFFFFF",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "EVENING",
        "targetHubs": ["all"],
        "title": "Movie Night",
        "subtitle": "Snacks for the perfect watch time",
        "heroImage": "/navratri/ref-movie-cinema-scene.png",
        "items": [
            {
                "id": "popcorn-movie",
                "productId": None,
                "keywords": ["popcorn", "act ii", "corn"],
                "fallbackName": "Popcorn",
                "fallbackUnit": "60 g",
                "fallbackPrice": 40,
                "fallbackMrp": 45,
                "fallbackImage": "/navratri/movie-popcorn.svg",
            },
        ],
    },
    "breakfastClub": {
        "enabled": False,
        "sortOrder": 6,
        "badge": "06",
        "backgroundColor": "#FFF8F0",
        "borderColor": "#FEE6D1",
        "accentColor": "#15803D",
        "textColor": "#9A3412",
        "minInStockItems": 1,
        "scheduleEnabled": False,
        "startDate": None,
        "endDate": None,
        "timeSlot": "MORNING",
        "targetHubs": ["all"],
        "title": "Breakfast Club",
        "subtitle": "Your quick breakfast list",
        "heroImage": "/navratri/ref-breakfast-toast.png",
        "items": [
            {
                "id": "bread",
                "productId": None,
                "keywords": ["bread", "brown bread", "sandwich"],
                "checkedByDefault": True,
                "fallbackName": "Bread",
                "fallbackUnit": "400 g",
                "fallbackPrice": 45,
                "fallbackMrp": 50,
                "fallbackImage": "/navratri/daily-bread.svg",
            },
        ],
    },
}


def bento_draft_key(store_id: Optional[str]) -> str:
    return f"store:{store_id}:{BENTO_DRAFT_KEY}" if store_id else BENTO_DRAFT_KEY


def bento_published_key(store_id: Optional[str]) -> str:
    return f"store:{store_id}:{BENTO_PUBLISHED_KEY}" if store_id else BENTO_PUBLISHED_KEY


def parse_stored_bento(raw_value: Optional[str]) -> Optional[Dict[str, Any]]:
    if not raw_value:
        return None
    try:
        parsed = json.loads(raw_value)
        if not isinstance(parsed, dict):
            return None
        merged = deepcopy(DEFAULT_CAMPAIGN_BENTO_CONFIG)
        for k, v in parsed.items():
            if isinstance(v, dict) and isinstance(merged.get(k), dict):
                merged[k] = {**merged[k], **v}
            else:
                merged[k] = v
        return merged
    except Exception:
        return None


def validate_bento_config(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise ValueError("Bento campaign configuration must be a JSON object")
    raw_bytes = len(json.dumps(data).encode("utf-8"))
    if raw_bytes > 131072:
        raise ValueError("Bento campaign configuration exceeds 128 KB")
    merged = deepcopy(DEFAULT_CAMPAIGN_BENTO_CONFIG)
    for k, v in data.items():
        if isinstance(v, dict) and isinstance(merged.get(k), dict):
            merged[k] = {**merged[k], **v}
        else:
            merged[k] = v
    return merged


def collect_bento_product_ids(config: Dict[str, Any]) -> List[str]:
    slots: List[Dict[str, Any]] = []
    for card_key in ("seasonalSwitchUp", "freshMarket"):
        card = config.get(card_key) or {}
        for tab in card.get("tabs") or []:
            if isinstance(tab, dict):
                slots.extend(s for s in (tab.get("items") or []) if isinstance(s, dict))
        slots.extend(s for s in (card.get("items") or []) if isinstance(s, dict))

    for card_key in ("dailyRestock", "valuePicks", "movieNight", "breakfastClub"):
        card = config.get(card_key) or {}
        slots.extend(s for s in (card.get("items") or []) if isinstance(s, dict))

    gb = config.get("giftingBoutique") or {}
    if isinstance(gb.get("heroItem"), dict):
        slots.append(gb["heroItem"])
    if isinstance(gb.get("miniItem"), dict):
        slots.append(gb["miniItem"])

    pids: List[str] = []
    seen = set()
    for slot in slots:
        pid = slot.get("productId")
        if isinstance(pid, str) and pid.strip() and pid.strip() not in seen:
            seen.add(pid.strip())
            pids.append(pid.strip())
    return pids


def is_bento_card_visible(
    card: Dict[str, Any],
    in_stock_count: int,
    current_store_id: Optional[str] = None,
) -> Tuple[bool, Optional[str]]:
    if not card.get("enabled", False):
        return False, "Card manually disabled by admin"

    target_hubs = card.get("targetHubs") or []
    if isinstance(target_hubs, list) and len(target_hubs) > 0 and "all" not in target_hubs:
        if current_store_id and current_store_id not in target_hubs:
            return False, f"Not targeted to hub {current_store_id}"

    min_required = int(card.get("minInStockItems") or 1)
    if min_required > 0 and in_stock_count < min_required:
        return False, f"In-stock items ({in_stock_count}) below required minimum ({min_required})"

    if card.get("scheduleEnabled"):
        now_utc = datetime.now(timezone.utc)
        ist_now = now_utc + timedelta(hours=5, minutes=30)

        start_date = card.get("startDate")
        if isinstance(start_date, str) and start_date.strip():
            try:
                start_dt = datetime.fromisoformat(start_date.replace("Z", "+00:00"))
                if start_dt.tzinfo is None:
                    start_dt = start_dt.replace(tzinfo=timezone.utc)
                if now_utc < start_dt:
                    return False, "Campaign schedule has not started yet"
            except Exception:
                pass

        end_date = card.get("endDate")
        if isinstance(end_date, str) and end_date.strip():
            try:
                end_dt = datetime.fromisoformat(end_date.replace("Z", "+00:00"))
                if end_dt.tzinfo is None:
                    end_dt = end_dt.replace(tzinfo=timezone.utc)
                if now_utc > end_dt:
                    return False, "Campaign schedule has ended"
            except Exception:
                pass

        time_slot = card.get("timeSlot") or "ALL_DAY"
        if time_slot != "ALL_DAY":
            time_in_hours = ist_now.hour + (ist_now.minute / 60.0)
            if time_slot == "MORNING" and (time_in_hours < 6 or time_in_hours >= 11.5):
                return False, "Active only in morning (06:00 - 11:30 AM)"
            if time_slot == "AFTERNOON" and (time_in_hours < 11.5 or time_in_hours >= 17):
                return False, "Active only in afternoon (11:30 AM - 05:00 PM)"
            if time_slot == "EVENING" and (time_in_hours < 17 or time_in_hours >= 22):
                return False, "Active only in evening (05:00 PM - 10:00 PM)"
            if time_slot == "NIGHT" and (6 <= time_in_hours < 22):
                return False, "Active only in night (10:00 PM - 06:00 AM)"

    return True, None
