"""Validated, store-scoped homepage campaigns stored in existing settings rows."""

from copy import deepcopy
from datetime import datetime, timezone
import json
import math
import re
from typing import Any, Mapping, Optional
from urllib.parse import unquote, urlsplit

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgres_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from models import StoreSetting

PUBLISHED_KEY = "homepage_campaign"
DRAFT_KEY = "homepage_campaign_draft"
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
HEX_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")
LABEL_DEFAULTS = {
    "sectionLabel": "Celebrate Navratri",
    "specialsHeading": "Navratri Specials",
    "curvedTabLabel": "Top Picks",
    "loadingText": "Loading this store’s festive picks…",
    "emptyText": "No matching products in this collection yet. Try another tab or search the catalogue.",
    "demoLabel": "Demo prices",
    "resultsDemoLabel": "Demo collection · illustrative prices",
}
APPEARANCE_DEFAULTS = {
    "background": "#FF831F", "card": "#FFF8DF", "text": "#985F39",
    "smallText": "#5E2E16", "headerText": "#FFF8DF", "headerOutline": "#713D21",
    "underline": "#832F27", "tabSurface": "#FFF8DF",
}


class CampaignValidationError(ValueError):
    pass


def _error(path: str, message: str):
    raise CampaignValidationError(f"{path}: {message}")


def _object(value: Any, path: str) -> dict:
    if not isinstance(value, dict):
        _error(path, "must be an object")
    return value


def _shape(value: dict, fields: set[str], path: str, *, required: Optional[set[str]] = None):
    unexpected = value.keys() - fields
    if unexpected:
        _error(path, f"unknown fields: {', '.join(sorted(unexpected))}")
    missing = (fields if required is None else required) - value.keys()
    if missing:
        _error(path, f"missing fields: {', '.join(sorted(missing))}")


def _string(value: Any, path: str, maximum: int = 240, *, empty: bool = False) -> str:
    if not isinstance(value, str) or len(value) > maximum or (not empty and not value.strip()):
        _error(path, f"must be {'a' if empty else 'a nonempty'} string of at most {maximum} characters")
    if any(ord(character) < 32 and character not in "\n\t" for character in value):
        _error(path, "contains unsupported control characters")
    return value


def _id(value: Any, path: str) -> str:
    if not isinstance(value, str) or not ID_PATTERN.fullmatch(value.strip()):
        _error(path, "must contain only letters, numbers, underscores, and hyphens")
    return value.strip()


def validate_image(value: Any, path: str = "image", *, nullable: bool = False):
    if value is None and nullable:
        return None
    image = _string(value, path, 2048)
    if image != image.strip() or "\\" in image or any(ord(c) < 32 for c in image):
        _error(path, "must be a safe image path or HTTPS URL")
    decoded = unquote(image)
    if any(ord(c) < 32 for c in decoded) or "\\" in decoded or re.search(r"%(?![0-9A-Fa-f]{2})", image):
        _error(path, "must be a safe image path or HTTPS URL")
    if any(segment in (".", "..") for segment in decoded.split("/")):
        _error(path, "relative traversal is not allowed")
    if image.startswith("https://"):
        try:
            url = urlsplit(image)
        except ValueError:
            _error(path, "must be a valid HTTPS URL")
        if not url.hostname or url.username or url.password:
            _error(path, "HTTPS images require a host and cannot contain credentials")
        return image
    if image.startswith("/") and not image.startswith("//"):
        if any(segment in (".", "..") for segment in decoded.split("/")) or decoded.startswith("//"):
            _error(path, "relative traversal and protocol-relative URLs are not allowed")
        if ":" in decoded or "#" in image or "?" in image or not re.fullmatch(r"/[\w/%.@-]+\.(?:svg|png|jpe?g|webp|avif)", image, re.IGNORECASE):
            _error(path, "local image paths cannot contain a scheme, fragment, or query")
        return image
    if not re.fullmatch(r"[\w.-]+\.(?:svg|png|jpe?g|webp|avif)", image, re.IGNORECASE) or ".." in image:
        _error(path, "use a local image file name, absolute image path, or HTTPS URL")
    return image


def _entries(value: Any, path: str, minimum: int, maximum: int) -> list[dict]:
    if not isinstance(value, list) or not minimum <= len(value) <= maximum:
        _error(path, f"must contain {minimum}–{maximum} entries")
    seen = set()
    for index, item in enumerate(value):
        entry = _object(item, f"{path}[{index}]")
        identifier = _id(entry.get("id"), f"{path}[{index}].id")
        entry["id"] = identifier
        if identifier in seen:
            _error(path, f"duplicate id {identifier}")
        seen.add(identifier)
    return value


def _keywords(value: Any, path: str):
    if not isinstance(value, list) or len(value) > 40:
        _error(path, "must be an array of at most 40 keywords")
    for index, keyword in enumerate(value):
        value[index] = _string(keyword.strip() if isinstance(keyword, str) else keyword, f"{path}[{index}]", 80)


def validate_campaign(value: Any) -> dict:
    campaign = deepcopy(_object(value, "campaign"))
    _shape(campaign, {"version", "layout", "composition", "blocks", "demo", "enabled", "autoplay", "searchPrefix", "decorationImage", "labels", "appearance", "timings", "searchSuggestions", "navigation", "headers", "products", "categories", "tabs", "destinations"}, "campaign", required={"version", "demo", "timings", "searchSuggestions", "headers", "products", "categories", "tabs", "destinations"})
    if campaign.get("version") != 1 or isinstance(campaign.get("version"), bool):
        _error("version", "unsupported schema version; expected 1")
    if campaign.get("layout", "classic") not in ("classic", "banner", "split", "grid", "deals"):
        _error("layout", "must be classic, banner, split, grid, or deals")
    for flag in ("demo", "enabled", "autoplay"):
        if flag == "demo" or flag in campaign:
            if not isinstance(campaign.get(flag), bool):
                _error(flag, "must be a boolean")
    timings = _object(campaign.get("timings"), "timings")
    _shape(timings, {"headerMs", "productMs", "searchMs", "crossfadeMs"}, "timings")
    for key in ("headerMs", "productMs", "searchMs", "crossfadeMs"):
        number = timings.get(key)
        minimum, maximum = (0, 1200) if key == "crossfadeMs" else (1500, 60000)
        if isinstance(number, bool) or not isinstance(number, int) or not minimum <= number <= maximum:
            _error(f"timings.{key}", f"must be an integer between {minimum} and {maximum}")
    suggestions = campaign.get("searchSuggestions")
    if not isinstance(suggestions, list) or not 1 <= len(suggestions) <= 12:
        _error("searchSuggestions", "must contain 1–12 suggestions")
    for index, suggestion in enumerate(suggestions):
        _string(suggestion, f"searchSuggestions[{index}]", 200)
    navigation = _entries(campaign.get("navigation", []), "navigation", 0, 12)
    headers = _entries(campaign.get("headers"), "headers", 1, 8)
    products = _entries(campaign.get("products"), "products", 1, 12)
    categories = _entries(campaign.get("categories"), "categories", 4, 4)
    tabs = _entries(campaign.get("tabs"), "tabs", 1, 8)
    destinations = _entries(campaign.get("destinations"), "destinations", 1, 80)
    destination_ids = {item["id"] for item in destinations}
    category_ids = {item["id"] for item in categories}
    if campaign.get("composition", "template") not in ("template", "blocks"):
        _error("composition", "must be template or blocks")
    blocks = _entries(campaign.get("blocks", []), "blocks", 0, 16)
    presentations = {
        "banner": ("wide",), "categories": ("grid", "row"),
        "spotlight": ("wide", "offer"), "collection": ("grid", "row"),
        "image": ("wide",), "text": ("plain",),
    }
    for index, block in enumerate(blocks):
        base = f"blocks[{index}]"
        _shape(block, {"id", "type", "enabled", "title", "body", "image", "destinationId", "itemIds", "tabId", "presentation", "motion"}, base, required={"id", "type"})
        kind = block.get("type")
        if not isinstance(kind, str) or kind not in presentations:
            _error(f"{base}.type", "unknown block type")
        block.setdefault("enabled", True)
        if not isinstance(block["enabled"], bool):
            _error(f"{base}.enabled", "must be a boolean")
        block.setdefault("title", "")
        block.setdefault("body", "")
        _string(block["title"], f"{base}.title", 200, empty=True)
        _string(block["body"], f"{base}.body", 500, empty=True)
        block.setdefault("image", None)
        validate_image(block["image"], f"{base}.image", nullable=True)
        block.setdefault("destinationId", None)
        if block["destinationId"] is not None:
            block["destinationId"] = _id(block["destinationId"], f"{base}.destinationId")
            if block["destinationId"] not in destination_ids:
                _error(f"{base}.destinationId", "must reference an existing destination")
        block.setdefault("presentation", "wide")
        if block["presentation"] not in presentations[kind]:
            _error(f"{base}.presentation", "unsupported presentation for this block")
        source = headers if kind == "banner" else categories if kind == "categories" else products if kind == "spotlight" else []
        available = {item["id"] for item in source}
        item_ids = block.setdefault("itemIds", [])
        if not isinstance(item_ids, list) or len(item_ids) > 12:
            _error(f"{base}.itemIds", "must be an array of at most 12 item IDs")
        block["itemIds"] = [_id(item, f"{base}.itemIds") for item in item_ids]
        if len(set(block["itemIds"])) != len(block["itemIds"]) or any(item not in available for item in block["itemIds"]):
            _error(f"{base}.itemIds", "must reference unique existing items for this block")
        block.setdefault("tabId", None)
        if block["tabId"] is not None:
            block["tabId"] = _id(block["tabId"], f"{base}.tabId")
        if kind == "collection":
            if block["tabId"] not in {item["id"] for item in tabs}:
                _error(f"{base}.tabId", "must reference an existing collection")
        elif block["tabId"] is not None:
            _error(f"{base}.tabId", "only collection blocks use a collection")
        if kind == "image" and not block["image"]:
            _error(f"{base}.image", "image banners need artwork")
        if kind == "text" and not (block["title"].strip() or block["body"].strip()):
            _error(f"{base}.title", "text blocks need a heading or message")
        motion = block.setdefault("motion", {"preset": "fade", "speed": "normal"})
        _object(motion, f"{base}.motion")
        _shape(motion, {"preset", "speed"}, f"{base}.motion", required=set())
        motion.setdefault("preset", "fade")
        motion.setdefault("speed", "normal")
        if motion["preset"] not in ("none", "fade", "slide", "float", "zoom", "sparkle"):
            _error(f"{base}.motion.preset", "unknown motion preset")
        if motion["speed"] not in ("slow", "normal", "fast"):
            _error(f"{base}.motion.speed", "must be slow, normal, or fast")
        if kind == "text" and motion["preset"] not in ("none", "fade", "slide"):
            _error(f"{base}.motion", "text blocks support no effect, soft fade, or slide in")
    if campaign.get("composition") == "blocks" and not any(block["enabled"] for block in blocks):
        _error("blocks", "add at least one visible block")
    campaign["blocks"] = blocks
    for index, destination in enumerate(destinations):
        _shape(destination, {"id", "kind", "query"}, f"destinations[{index}]")
        if destination.get("kind") != "search":
            _error(f"destinations[{index}].kind", "only search destinations are supported")
        _string(destination.get("query"), f"destinations[{index}].query", 200, empty=True)
    for section, entries in (("navigation", navigation), ("categories", categories), ("products", products)):
        for index, entry in enumerate(entries):
            destination_id = entry.get("destinationId")
            if destination_id is None and section == "navigation":
                continue
            entry["destinationId"] = _id(destination_id, f"{section}[{index}].destinationId")
            if entry["destinationId"] not in destination_ids:
                _error(f"{section}[{index}].destinationId", "must reference an existing destination")
    for index, entry in enumerate(navigation):
        _shape(entry, {"id", "label", "destinationId"}, f"navigation[{index}]")
        _string(entry.get("label"), f"navigation[{index}].label", 200)
    for index, header in enumerate(headers):
        base = f"headers[{index}]"
        _shape(header, {"id", "kind", "eyebrow", "title", "subtitle", "image"}, base)
        if header.get("kind") not in ("illustration", "title", "brand"):
            _error(f"{base}.kind", "must be illustration, title, or brand")
        _string(header.get("title"), f"{base}.title", 200)
        _string(header.get("eyebrow"), f"{base}.eyebrow", 200, empty=True)
        _string(header.get("subtitle"), f"{base}.subtitle", 200, empty=True)
        validate_image(header.get("image"), f"{base}.image", nullable=True)
    for section, entries in (("categories", categories), ("tabs", tabs)):
        for index, entry in enumerate(entries):
            base = f"{section}[{index}]"
            _shape(entry, {"id", "label", "image", "keywords", "destinationId"} if section == "categories" else {"id", "label", "image", "keywords", "productIds"}, base, required={"id", "label", "image", "keywords"})
            _string(entry.get("label"), f"{base}.label", 200)
            validate_image(entry.get("image"), f"{base}.image")
            _keywords(entry.get("keywords"), f"{base}.keywords")
            if section == "tabs" and "productIds" in entry:
                p_ids = entry.get("productIds") or []
                if not isinstance(p_ids, list):
                    _error(f"{base}.productIds", "must be a list of product IDs")
                entry["productIds"] = [str(pid).strip() for pid in p_ids if str(pid).strip()]
    for index, product in enumerate(products):
        base = f"products[{index}]"
        _shape(product, {"id", "name", "image", "originalPrice", "price", "currency", "categoryId", "destinationId", "productId"}, base, required={"id", "name", "image", "originalPrice", "price", "currency", "categoryId", "destinationId"})
        _string(product.get("name"), f"{base}.name", 200)
        validate_image(product.get("image"), f"{base}.image")
        product["categoryId"] = _id(product.get("categoryId"), f"{base}.categoryId")
        if product["categoryId"] not in category_ids:
            _error(f"{base}.categoryId", "must reference an existing category")
        if product.get("currency") != "INR":
            _error(f"{base}.currency", "only INR is supported")
        for field in ("price", "originalPrice"):
            number = product.get(field)
            if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or number < 0:
                _error(f"{base}.{field}", "must be a finite nonnegative number")
        if product["price"] > product["originalPrice"]:
            _error(f"{base}.price", "cannot exceed originalPrice")
        if "productId" in product:
            product["productId"] = _id(product["productId"], f"{base}.productId")
        displayed = campaign.get("composition", "template") == "template" or any(
            block["enabled"] and block["type"] == "spotlight" and
            (not block["itemIds"] or product["id"] in block["itemIds"]) for block in blocks)
        if not campaign["demo"] and displayed and not product.get("productId"):
            _error(f"{base}.productId", "live campaigns require a catalogue product reference")
    if "searchPrefix" in campaign:
        _string(campaign["searchPrefix"], "searchPrefix", 200)
    validate_image(campaign.get("decorationImage", "string-lights.svg"), "decorationImage", nullable=True)
    for field, defaults in (("labels", LABEL_DEFAULTS), ("appearance", APPEARANCE_DEFAULTS)):
        options = _object(campaign.get(field, {}), field)
        if field in campaign and options.keys() != defaults.keys():
            _error(field, "must include every configured option")
        for key, option in options.items():
            if key not in defaults:
                _error(f"{field}.{key}", "unknown option")
            if field == "appearance":
                if not isinstance(option, str) or not HEX_PATTERN.fullmatch(option):
                    _error(f"{field}.{key}", "must be a six-digit hex colour")
            else:
                _string(option, f"{field}.{key}", 500 if key == "emptyText" else 200)
    if len(json.dumps(campaign, ensure_ascii=False, allow_nan=False).encode("utf-8")) > 131072:
        _error("campaign", "configuration exceeds 128 KB")
    campaign.setdefault("enabled", True)
    campaign.setdefault("layout", "classic")
    campaign.setdefault("composition", "template")
    campaign.setdefault("autoplay", True)
    campaign.setdefault("searchPrefix", "Search for")
    campaign.setdefault("decorationImage", "string-lights.svg")
    campaign.setdefault("labels", deepcopy(LABEL_DEFAULTS))
    campaign.setdefault("appearance", deepcopy(APPEARANCE_DEFAULTS))
    campaign.setdefault("navigation", [])
    return campaign


def normalize_store_id(value: Any) -> Optional[str]:
    if value is None or value == "" or value in ("all", "ALL"):
        return None
    return _id(value, "storeId")


def resolve_admin_store(user: Mapping[str, Any], requested: Any = None) -> Optional[str]:
    role = str(user.get("role", "")).upper()
    if role not in ("ADMIN", "SUPER_ADMIN"):
        raise PermissionError("Admin access required")
    target = normalize_store_id(requested)
    assigned = user.get("assignedStoreId")
    if assigned:
        if requested is not None and target != assigned:
            raise PermissionError("Access is restricted to your assigned store")
        return normalize_store_id(assigned)
    email = str(user.get("email") or "").lower()
    if role != "SUPER_ADMIN" and (email.startswith("admin.hub-") or email.endswith("@users.fastkirana.in")):
        raise PermissionError("A branch admin must have an assigned store")
    return target


def setting_key(base: str, store_id: Optional[str]) -> str:
    return f"store:{store_id}:{base}" if store_id else base


def parse_stored_campaign(value: Optional[str]) -> Optional[dict]:
    if not value:
        return None
    try:
        return validate_campaign(json.loads(value))
    except (ValueError, TypeError, KeyError, OverflowError):
        return None


def select_published(settings: Mapping[str, str], store_id: Optional[str]) -> Optional[dict]:
    key = setting_key(PUBLISHED_KEY, store_id)
    if key in settings:
        return parse_stored_campaign(settings[key])
    return parse_stored_campaign(settings.get(PUBLISHED_KEY))


async def read_campaign_settings(db, store_id: Optional[str], *, include_draft: bool = False) -> dict[str, str]:
    keys = {PUBLISHED_KEY, setting_key(PUBLISHED_KEY, store_id)}
    if include_draft:
        keys.add(setting_key(DRAFT_KEY, store_id))
    result = await db.execute(select(StoreSetting.key, StoreSetting.value).where(StoreSetting.key.in_(keys)))
    return {row.key: row.value for row in result.all()}


async def upsert_campaign_settings(db, entries: Mapping[str, dict]):
    """One statement/transaction publishes draft and live rows together."""
    dialect = db.get_bind().dialect.name
    insert = sqlite_insert if dialect == "sqlite" else postgres_insert
    rows = [{"key": key, "value": json.dumps(config, ensure_ascii=False, allow_nan=False)} for key, config in entries.items()]
    statement = insert(StoreSetting).values(rows)
    statement = statement.on_conflict_do_update(
        index_elements=[StoreSetting.key],
        set_={"value": statement.excluded.value, "updatedAt": datetime.now(timezone.utc).replace(tzinfo=None)},
    )
    await db.execute(statement)
    await db.commit()
