"""
Product Service for FastKirana FastAPI Backend
Handles Product serialization, type determination, stock boundaries, and cart validation.
"""

from typing import Dict, Any, List, Optional
import re
import math
import uuid

def get_product_type(p) -> str:
    """Determines if a product is GROCERY, CAFE, or RESTAURANT."""
    if not p:
        return "GROCERY"
    category_slug = ""
    # Safe check in __dict__ avoids triggering lazy loading IO in SQLAlchemy async
    if "category" in p.__dict__ and p.__dict__["category"]:
        category_slug = getattr(p.__dict__["category"], "slug", "") or ""
    elif hasattr(p, "category_slug"):
        category_slug = getattr(p, "category_slug", "") or ""
    slug = category_slug.lower()
    tags = [t.lower() for t in (getattr(p, "tags", []) or [])]
    restaurant_id = getattr(p, "restaurantId", None)

    if restaurant_id or "restaurant" in slug or "restaurant" in tags or any("restaurant" in t for t in tags):
        return "RESTAURANT"
    if "cafe" in slug or "cafe" in tags or any("cafe" in t for t in tags):
        return "CAFE"
    return "GROCERY"


def get_product_limit(p) -> int:
    """Calculates maximum order limit for a product."""
    p_type = get_product_type(p)
    if p_type == "RESTAURANT":
        return 20
    if p_type == "CAFE":
        return 10
    return 10


def generate_slug(name: str) -> str:
    """Generates a URL-friendly slug from a product name."""
    slug = name.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'\s+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')


def serialize_product(
    p, 
    local_stock: Optional[int] = None, 
    is_admin: bool = False,
    local_price: Optional[float] = None
) -> Dict[str, Any]:
    """
    Serializes a Product ORM model to API JSON dictionary.
    Supports localized price overrides, category/restaurant payloads, and stock calculation.
    """
    if not p:
        return {}

    stock_val = local_stock if local_stock is not None else (getattr(p, "stock", 0) or 0)
    if is_admin:
        is_avail = bool(getattr(p, "isAvailable", True))
    else:
        is_avail = bool(getattr(p, "isAvailable", True)) if local_stock is None else (bool(getattr(p, "isAvailable", True)) and local_stock > 0)

    # Localized price override support
    effective_mrp = float(getattr(p, "mrp", 0.0) or 0.0)
    effective_price = float(local_price) if (local_price is not None and local_price > 0) else float(getattr(p, "price", 0.0) or 0.0)
    if effective_mrp < effective_price:
        effective_mrp = effective_price
    effective_discount = round(((effective_mrp - effective_price) / effective_mrp) * 100) if effective_mrp > effective_price else 0.0

    cat_dict = None
    if getattr(p, 'category', None):
        cat_dict = {
            "id": p.category.id,
            "name": p.category.name,
            "slug": p.category.slug,
            "imageUrl": getattr(p.category, "imageUrl", None),
            "parentId": getattr(p.category, "parentId", None),
            "sortOrder": getattr(p.category, "sortOrder", 0) or 0
        }

    rest_dict = None
    if getattr(p, 'restaurant', None):
        rest_dict = {
            "id": p.restaurant.id,
            "name": p.restaurant.name,
            "slug": p.restaurant.slug,
            "logoUrl": getattr(p.restaurant, "logoUrl", None),
            "bannerUrl": getattr(p.restaurant, "bannerUrl", None),
            "rating": float(getattr(p.restaurant, "rating", 0.0) or 0.0),
            "deliveryTime": getattr(p.restaurant, "deliveryTime", None),
            "isOpen": bool(getattr(p.restaurant, "isOpen", True)),
            "openTime": getattr(p.restaurant, "openTime", None),
            "closeTime": getattr(p.restaurant, "closeTime", None),
            "lat": float(p.restaurant.lat) if getattr(p.restaurant, "lat", None) is not None else None,
            "lng": float(p.restaurant.lng) if getattr(p.restaurant, "lng", None) is not None else None,
            "deliveryRadiusKm": float(getattr(p.restaurant, "deliveryRadiusKm", 5.0) or 5.0),
            "address": getattr(p.restaurant, "address", None)
        }

    p_type = get_product_type(p)
    max_limit = get_product_limit(p)

    return {
        "id": p.id,
        "readableId": getattr(p, "readableId", None),
        "name": p.name,
        "slug": getattr(p, "slug", None) or generate_slug(p.name),
        "description": getattr(p, "description", "") or "",
        "imageUrl": getattr(p, "imageUrl", None),
        "categoryId": getattr(p, "categoryId", None),
        "restaurantId": getattr(p, "restaurantId", None),
        "mrp": effective_mrp,
        "price": effective_price,
        "discount": effective_discount,
        "priceOverride": float(local_price) if local_price is not None else None,
        "unit": getattr(p, "unit", "pcs") or "pcs",
        "stock": stock_val,
        "isAvailable": is_avail,
        "tags": getattr(p, "tags", []) or [],
        "variants": getattr(p, "variants", []) or [],
        "addons": getattr(p, "addons", []) or [],
        "minStock": getattr(p, "minStock", 0) or 0,
        "expiryDate": p.expiryDate.isoformat() if getattr(p, "expiryDate", None) else None,
        "costPrice": float(getattr(p, "costPrice", 0.0) or 0.0),
        "location": getattr(p, "location", None),
        "isFlashDeal": bool(getattr(p, "isFlashDeal", False)),
        "isTopPick": bool(getattr(p, "isTopPick", False)),
        "isBestSeller": bool(getattr(p, "isBestSeller", False)),
        "sortOrder": getattr(p, "sortOrder", 0) or 0,
        "availableStartTime": getattr(p, "availableStartTime", None),
        "availableEndTime": getattr(p, "availableEndTime", None),
        "barcode": getattr(p, "barcode", None),
        "vendor": getattr(p, "vendor", None),
        "vendorId": getattr(p, "vendorId", None),
        "createdAt": p.createdAt.isoformat() if getattr(p, "createdAt", None) else None,
        "updatedAt": p.updatedAt.isoformat() if getattr(p, "updatedAt", None) else None,
        "category": cat_dict,
        "restaurant": rest_dict
    }
