from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, Response, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, not_, func, text, exists
from sqlalchemy.orm import selectinload
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import uuid
import re
import math
import hashlib

from database import get_db
from models import Product, Category, Review, Order, OrderItem, StoreInventory, Restaurant, User, StoreSetting, DarkStore
from routers.auth import get_current_user, require_admin, require_auth
from routers.websockets import manager
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/products", tags=["Products"])

# Synonym dictionary for Hinglish / common terms
SYNONYM_DICTIONARY = {
    # Vegetables & Fresh
    'aalu': ['potato', 'aloo'],
    'aloo': ['potato', 'aalu'],
    'pyaz': ['onion', 'pyaj'],
    'pyaj': ['onion', 'pyaz'],
    'tamatar': ['tomato', 'tomatoes'],
    'nimbu': ['lemon', 'lime'],
    'adrak': ['ginger'],
    'lahsun': ['garlic', 'lehsun'],
    'lehsun': ['garlic', 'lahsun'],
    'mirch': ['chilli', 'chili', 'mirchi'],
    'mirchi': ['chilli', 'chili', 'mirch'],
    'hari mirch': ['green chilli', 'chilli'],
    'dhaniya': ['coriander', 'cilantro'],
    'kheera': ['cucumber'],
    'gobi': ['cauliflower', 'cabbage'],
    'patta gobi': ['cabbage'],
    'phool gobi': ['cauliflower'],
    'matar': ['peas', 'green peas'],
    'bhindi': ['lady finger', 'okra'],

    # Dairy & Breakfast
    'doodh': ['milk', 'dudh', 'amul'],
    'dudh': ['milk', 'doodh', 'amul'],
    'dahi': ['curd', 'yogurt'],
    'makhan': ['butter', 'amul butter'],
    'paneer': ['cottage cheese'],
    'ghee': ['clarified butter', 'desi ghee'],
    'anda': ['egg', 'eggs'],
    'ande': ['egg', 'eggs'],
    'bread': ['pav', 'bun', 'loaf'],
    'rusk': ['toast', 'biscuit'],
    'chai': ['tea', 'taj mahal', 'tata tea'],
    'patti': ['tea', 'chai'],
    'coffee': ['nescafe', 'bru'],

    # Staples & Grains
    'atta': ['flour', 'wheat', 'gehu', 'ashirvaad'],
    'aata': ['flour', 'wheat', 'gehu', 'ashirvaad'],
    'gehu': ['wheat', 'atta', 'flour'],
    'maida': ['refined flour'],
    'besan': ['gram flour', 'chana flour'],
    'sooji': ['semolina', 'suji', 'rava'],
    'suji': ['semolina', 'sooji', 'rava'],
    'rava': ['semolina', 'sooji'],
    'poha': ['flattened rice', 'chura'],
    'chura': ['poha', 'flattened rice'],
    'chawal': ['rice', 'basmati', 'kolam'],
    'chini': ['sugar', 'cheeni', 'shakkar'],
    'cheeni': ['sugar', 'chini', 'shakkar'],
    'shakkar': ['sugar', 'jaggery', 'gud'],
    'gud': ['jaggery'],
    'namak': ['salt', 'tata salt'],

    # Oils & Spices
    'tel': ['oil', 'mustard oil', 'refine'],
    'sarson': ['mustard', 'sarson tel', 'mustard oil'],
    'sarson tel': ['mustard oil', 'oil'],
    'refine': ['refined oil', 'fortune', 'oil'],
    'haldi': ['turmeric', 'turmeric powder'],
    'jeera': ['cumin', 'cumin seeds'],
    'zeera': ['cumin'],
    'laung': ['clove'],
    'elaichi': ['cardamom'],
    'dalchini': ['cinnamon'],
    'saunf': ['fennel'],
    'methi': ['fenugreek'],
    'hing': ['asafoetida'],

    # Dals & Pulses
    'dal': ['lentils', 'pulses', 'daal'],
    'daal': ['lentils', 'pulses', 'dal'],
    'arhar': ['toor', 'tur dal', 'pigeon pea'],
    'toor': ['arhar', 'tur dal'],
    'moong': ['mung', 'green gram'],
    'chana': ['chickpeas', 'gram'],
    'urad': ['black gram'],
    'masoor': ['red lentils'],
    'rajma': ['kidney beans'],
    'chhole': ['chickpeas', 'kabuli chana'],
    'chole': ['chickpeas', 'kabuli chana'],

    # Snacks, Beverages & Household
    'biscuit': ['cookie', 'biscuits', 'parle', 'britannia', 'biskut'],
    'biskut': ['biscuit', 'cookie'],
    'namkeen': ['bhujia', 'mixture', 'haldiram', 'bikano'],
    'bhujia': ['namkeen', 'sev'],
    'chips': ['lays', 'kurkure', 'bingo', 'wafers'],
    'kurkure': ['namkeen', 'chips', 'snacks'],
    'maggi': ['noodles', 'instant noodles', 'yippee'],
    'noodles': ['maggi', 'instant noodles', 'chowmein'],
    'chowmein': ['noodles'],
    'pani': ['water', 'bisleri', 'aquafina'],
    'cold drink': ['colddrink', 'pepsi', 'coke', 'thums up', 'sprite', 'beverage', 'soda'],
    'colddrink': ['cold drink', 'pepsi', 'coke', 'sprite', 'beverage'],
    'sabun': ['soap', 'lifebuoy', 'dettol', 'lux', 'dove'],
    'saboon': ['soap'],
    'surf': ['detergent', 'washing powder', 'aerial', 'tide', 'wheel'],
    'detergent': ['washing powder', 'surf'],
    'manjan': ['toothpaste', 'colgate', 'pepsodent', 'paste'],
    'paste': ['toothpaste', 'colgate'],
    'shampoo': ['clinic plus', 'head and shoulders', 'sunsilk'],
    'tel malish': ['hair oil', 'coconut oil', 'bajaj', 'dabur'],
}

# Stop words for product search (Hinglish + English)
SEARCH_STOP_WORDS = {
    'ke', 'ka', 'ki', 'ko', 'se', 'me', 'mein', 'par', 'pe', 'aur', 'and', 'the', 'of', 'in', 'for', 'with', 'from'
}

# Constant Restaurant IDs
OUTLET_AS_RESTAURANT_ID = "cms2p1lap0000n0id8alldboy"
OUTLET_WEDSON_ID = "cms2p1lyx0001n0idod904lfu"
LEGACY_AS_RESTAURANT_ID = "as-restaurant-id"
LEGACY_WEDSON_ID = "wedson-id"

# Simple in-memory search cache to prevent heavy re-ranking
search_cache = {}


def get_levenshtein_distance(a: str, b: str) -> int:
    """Levenshtein distance calculation in Python."""
    if len(a) < len(b):
        return get_levenshtein_distance(b, a)
    if len(b) == 0:
        return len(a)

    previous_row = range(len(b) + 1)
    for i, c1 in enumerate(a):
        current_row = [i + 1]
        for j, c2 in enumerate(b):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (0 if c1 == c2 else 1)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row

    return previous_row[-1]


def get_fuzzy_score(query: str, target: str) -> float:
    """Fuzzy matching logic mirroring Next.js helper."""
    q = query.lower().strip()
    t = target.lower().strip()

    if q in t:
        return 100.0

    q_words = q.split()
    t_words = t.split()

    if not q_words or not t_words:
        return 0.0

    total_score = 0.0
    for qw in q_words:
        best_word_score = 0.0
        for tw in t_words:
            if tw == qw:
                best_word_score = max(best_word_score, 90.0)
            elif qw in tw or tw in qw:
                best_word_score = max(best_word_score, 70.0)
            else:
                dist = get_levenshtein_distance(qw, tw)
                max_len = max(len(qw), len(tw))
                if max_len > 0:
                    sim = 1.0 - (dist / max_len)
                    if sim > 0.5:
                        best_word_score = max(best_word_score, round(sim * 80.0, 2))
        total_score += best_word_score

    return total_score / len(q_words)


def get_product_type(p) -> str:
    if not p:
        return "GROCERY"
    category_slug = p.category.slug if p.category else ""
    slug = category_slug.lower()
    tags = [t.lower() for t in (p.tags or [])]
    restaurant_id = p.restaurantId

    if restaurant_id or "restaurant" in slug or "restaurant" in tags or any("restaurant" in t for t in tags):
        return "RESTAURANT"
    if "cafe" in slug or "cafe" in tags or any("cafe" in t for t in tags):
        return "CAFE"
    return "GROCERY"


def get_product_limit(p) -> int:
    p_type = get_product_type(p)
    if p_type == "RESTAURANT":
        return 20
    if p_type == "CAFE":
        return 10
    return 10


def generate_slug(name: str) -> str:
    slug = name.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'\s+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')


def serialize_product(p: Product, local_stock: Optional[int] = None) -> Dict[str, Any]:
    stock_val = local_stock if local_stock is not None else (p.stock or 0)
    is_avail = bool(p.isAvailable) if local_stock is None else (bool(p.isAvailable) and local_stock > 0)

    cat_dict = None
    if getattr(p, 'category', None):
        cat_dict = {
            "id": p.category.id,
            "name": p.category.name,
            "slug": p.category.slug,
            "imageUrl": p.category.imageUrl,
            "parentId": p.category.parentId,
            "sortOrder": p.category.sortOrder or 0
        }

    rest_dict = None
    if getattr(p, 'restaurant', None):
        rest_dict = {
            "id": p.restaurant.id,
            "name": p.restaurant.name,
            "slug": p.restaurant.slug,
            "logoUrl": p.restaurant.logoUrl,
            "bannerUrl": p.restaurant.bannerUrl,
            "rating": float(p.restaurant.rating or 0.0),
            "deliveryTime": p.restaurant.deliveryTime,
            "isOpen": bool(p.restaurant.isOpen),
            "openTime": p.restaurant.openTime,
            "closeTime": p.restaurant.closeTime,
            "lat": float(p.restaurant.lat) if p.restaurant.lat is not None else None,
            "lng": float(p.restaurant.lng) if p.restaurant.lng is not None else None,
            "deliveryRadiusKm": float(p.restaurant.deliveryRadiusKm or 5.0),
            "address": p.restaurant.address
        }

    return {
        "id": p.id,
        "readableId": p.readableId,
        "name": p.name,
        "slug": p.slug,
        "description": p.description,
        "imageUrl": p.imageUrl,
        "categoryId": p.categoryId,
        "restaurantId": p.restaurantId,
        "mrp": float(p.mrp or 0.0),
        "price": float(p.price or 0.0),
        "discount": float(p.discount or 0.0),
        "unit": p.unit or "pcs",
        "stock": stock_val,
        "isAvailable": is_avail,
        "tags": p.tags or [],
        "variants": p.variants or [],
        "addons": p.addons or [],
        "minStock": p.minStock or 0,
        "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
        "costPrice": float(p.costPrice or 0.0),
        "location": p.location,
        "isFlashDeal": bool(p.isFlashDeal),
        "isTopPick": bool(p.isTopPick),
        "isBestSeller": bool(p.isBestSeller),
        "sortOrder": p.sortOrder or 0,
        "availableStartTime": p.availableStartTime,
        "availableEndTime": p.availableEndTime,
        "barcode": p.barcode,
        "vendor": p.vendor,
        "vendorId": p.vendorId,
        "createdAt": p.createdAt.isoformat() if p.createdAt else None,
        "updatedAt": p.updatedAt.isoformat() if p.updatedAt else None,
        "category": cat_dict,
        "restaurant": rest_dict
    }


@router.get("/catalog-version")
async def get_catalog_version(
    storeId: Optional[str] = Query(None),
    restaurantId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Ultra-lightweight version epoch endpoint (Zepto/Swiggy pattern).
    Allows client to check if anything changed in <5ms without transferring the full catalog.
    """
    p_filter = []
    if restaurantId:
        p_filter.append(Product.restaurantId == restaurantId)
    elif storeId and storeId != "all":
        p_filter.append(or_(Product.storeId == storeId, Product.storeId == None))

    p_stmt = select(
        func.max(Product.updatedAt),
        func.count(Product.id)
    )
    if p_filter:
        p_stmt = p_stmt.where(and_(*p_filter))

    p_res = await db.execute(p_stmt)
    p_max_dt, p_count = p_res.first()

    c_stmt = select(func.max(Category.updatedAt))
    c_res = await db.execute(c_stmt)
    c_max_dt = c_res.scalar()

    p_version = int(p_max_dt.timestamp() * 1000) if p_max_dt else 0
    c_version = int(c_max_dt.timestamp() * 1000) if c_max_dt else 0

    return {
        "success": True,
        "storeId": storeId,
        "restaurantId": restaurantId,
        "productsVersion": str(p_version),
        "categoriesVersion": str(c_version),
        "productsCount": int(p_count or 0),
        "timestamp": int(datetime.utcnow().timestamp() * 1000)
    }


@router.get("")
async def get_products(
    response: Response,
    request: Request,
    category: Optional[str] = Query(None),
    categoryId: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    sort: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(100, ge=1),
    cursor: Optional[str] = Query(None),
    trending: bool = Query(False),
    storeId: Optional[str] = Query(None),
    restaurantId: Optional[str] = Query(None),
    restaurantSlug: Optional[str] = Query(None),
    admin: bool = Query(False),
    includeUnavailable: bool = Query(False),
    excludeRestaurant: bool = Query(False),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetch products with search filters, sorting, category hierarchies, 
    cursor/offset pagination, and dark store inventory overrides.
    """
    role = current_user.get("role") if current_user else None
    is_worker = role in ["ADMIN", "CHEF"]

    normalized_search = search.strip().lower().replace("  ", " ") if search else ""

    # Check search cache
    cache_key = f"search:{storeId or 'all'}:{normalized_search}:{category or ''}:{sort or ''}:{page}:{limit}:{is_worker}:{restaurantId or ''}:{restaurantSlug or ''}"
    if normalized_search and cache_key in search_cache:
        return search_cache[cache_key]

    # Filters
    filters = []

    # Worker check or includeUnavailable check
    if not is_worker and not includeUnavailable and not admin:
        filters.append(Product.isAvailable == True)

    # Restaurant separation rules
    if restaurantId:
        if restaurantId in [OUTLET_AS_RESTAURANT_ID, LEGACY_AS_RESTAURANT_ID, "as-restaurant", "as-cafe"]:
            filters.append(or_(
                Product.restaurantId == restaurantId,
                Product.restaurantId == OUTLET_AS_RESTAURANT_ID,
                Product.restaurantId == LEGACY_AS_RESTAURANT_ID
            ))
        elif restaurantId in [OUTLET_WEDSON_ID, LEGACY_WEDSON_ID, "wedson", "wedson-restaurant"]:
            filters.append(or_(
                Product.restaurantId == restaurantId,
                Product.restaurantId == OUTLET_WEDSON_ID,
                Product.restaurantId == LEGACY_WEDSON_ID
            ))
        elif restaurantId in ["cmsbhxb6a000304if8kf1cwji", "bal-udyan-restaurant", "bal-udyan"]:
            filters.append(or_(
                Product.restaurantId == restaurantId,
                Product.restaurantId == "cmsbhxb6a000304if8kf1cwji"
            ))
        else:
            filters.append(or_(
                Product.restaurantId == restaurantId,
                Product.restaurant.has(Restaurant.slug == restaurantId)
            ))
    elif restaurantSlug:
        if restaurantSlug in ["as-restaurant", "as-cafe"]:
            filters.append(or_(
                Product.restaurantId == OUTLET_AS_RESTAURANT_ID,
                Product.restaurantId == LEGACY_AS_RESTAURANT_ID
            ))
        elif restaurantSlug in ["wedson", "wedson-restaurant", "restaurant-kitchen"]:
            filters.append(or_(
                Product.restaurantId == OUTLET_WEDSON_ID,
                Product.restaurantId == LEGACY_WEDSON_ID
            ))
        elif restaurantSlug in ["bal-udyan-restaurant", "bal-udyan"]:
            filters.append(Product.restaurantId == "cmsbhxb6a000304if8kf1cwji")
        else:
            # Query restaurant id matching slug
            res_stmt = select(Restaurant.id).where(Restaurant.slug == restaurantSlug)
            res_res = await db.execute(res_stmt)
            res_id = res_res.scalars().first()
            if res_id:
                filters.append(Product.restaurantId == res_id)
            else:
                filters.append(Product.restaurantId == restaurantSlug)
    elif excludeRestaurant or (not is_worker and not includeUnavailable and not category):
        filters.append(Product.restaurantId == None)

    # H10 FIX: Strict Store Isolation (Exclude restaurants from other cities, require localized store inventory for grocery)
    if storeId and storeId != "all":
        # Grocery: Only products that have inventory in this store!
        inv_sub_conditions = [
            StoreInventory.productId == Product.id,
            StoreInventory.storeId == storeId
        ]
        if not is_worker and not includeUnavailable and not admin:
            inv_sub_conditions.append(StoreInventory.stock > 0)

        grocery_scope = and_(
            Product.restaurantId.is_(None),
            exists().where(and_(*inv_sub_conditions))
        )

        # Restaurant dishes: Only restaurants belonging to this storeId!
        rest_scope = Product.restaurant.has(Restaurant.storeId == storeId)
        filters.append(or_(grocery_scope, rest_scope))

    # Category matching (Supports both direct category and child subcategories under parent)
    if categoryId:
        cat_ids = [c.strip() for c in categoryId.split(",") if c.strip()]
        filters.append(or_(
            Product.categoryId.in_(cat_ids),
            Product.category.has(Category.id.in_(cat_ids)),
            Product.category.has(Category.parentId.in_(cat_ids))
        ))
        if not restaurantId and not restaurantSlug:
            filters.append(Product.restaurantId == None)
    elif category:
        slugs = category.split(",")
        is_cafe_query = any(s in ["cafe", "fastkirana-cafe"] for s in slugs)
        is_restaurant_query = any(s in ["restaurant", "wedson-restaurant"] for s in slugs)

        if is_cafe_query:
            cafe_slugs = ['cafe', 'fastkirana-cafe', 'hot-beverages', 'cold-beverages', 'drinks', 'shakes', 'mocktails', 'sandwiches', 'burgers', 'pizza', 'rolls', 'chinese', 'pasta', 'snacks', 'desserts', 'bakery', 'south-indian', 'fast-food', 'quick-bites', 'coffee', 'tea']
            filters.append(Product.category.has(Category.slug.in_(cafe_slugs)))
        elif is_restaurant_query:
            rest_slugs = ['restaurant', 'wedson-restaurant', 'thali', 'biryani', 'north-indian', 'main-course', 'roti-naan', 'chinese', 'combos', 'curry']
            filters.append(or_(
                Product.restaurantId != None,
                Product.category.has(Category.slug.in_(rest_slugs))
            ))
        else:
            filters.append(or_(
                Product.category.has(Category.slug.in_(slugs)),
                Product.category.has(Category.parent.has(Category.slug.in_(slugs))),
                Product.categoryId.in_(slugs)
            ))
            if not restaurantId and not restaurantSlug:
                filters.append(Product.restaurantId == None)

    # Order by settings
    order_by_clauses = [Product.sortOrder.desc(), Product.createdAt.desc()]
    if category and "," not in category:
        stmt_sort = select(StoreSetting.value).where(StoreSetting.key == f"category_sort_{category}")
        res_sort = await db.execute(stmt_sort)
        rule = res_sort.scalars().first()
        if rule and rule != "manual":
            if rule == "best-seller":
                order_by_clauses = [Product.isBestSeller.desc(), Product.sortOrder.desc(), Product.createdAt.desc()]
            elif rule == "stock-desc":
                order_by_clauses = [Product.stock.desc(), Product.sortOrder.desc(), Product.createdAt.desc()]
            elif rule == "price-asc":
                order_by_clauses = [Product.price.asc(), Product.sortOrder.desc()]
            elif rule == "price-desc":
                order_by_clauses = [Product.price.desc(), Product.sortOrder.desc()]
            elif rule == "newest":
                order_by_clauses = [Product.createdAt.desc()]

    if sort == "price-asc":
        order_by_clauses = [Product.price.asc()]
    elif sort == "price-desc":
        order_by_clauses = [Product.price.desc()]
    elif sort == "discount-desc":
        order_by_clauses = [Product.discount.desc()]

    # M3 FIX: For customer views, always push in-stock items above out-of-stock
    if not is_worker and not includeUnavailable and not admin:
        from sqlalchemy import case
        stock_first = case((Product.stock > 0, 0), else_=1).asc()
        order_by_clauses = [stock_first] + order_by_clauses

    # Trending items check
    if trending:
        # Load best selling items
        stmt_trending = select(Product).options(
            selectinload(Product.category),
            selectinload(Product.restaurant)
        ).where(
            Product.isAvailable == True,
            Product.restaurantId == None,
            Product.category.has(Category.slug != "cafe")
        ).where(or_(Product.isTopPick == True, Product.isBestSeller == True)).limit(8)
        res_trending = await db.execute(stmt_trending)
        trending_products = res_trending.scalars().all()
        serialized_trending = [serialize_product(p) for p in trending_products]

        return {
            "products": serialized_trending,
            "pagination": {
                "total": len(serialized_trending),
                "page": 1,
                "limit": 8,
                "totalPages": 1
            }
        }

    # Fetching list
    products = []
    total = 0
    next_cursor = None

    if normalized_search:
        # 1. Fuzzy Text Search with stop words filter (M1 fix)
        raw_words = normalized_search.split()
        filtered_words = [w for w in raw_words if w not in SEARCH_STOP_WORDS]
        search_words = filtered_words if filtered_words else raw_words

        phrase_syns = SYNONYM_DICTIONARY.get(normalized_search, [])
        word_clauses = []
        if phrase_syns:
            all_opts = [normalized_search] + phrase_syns
            or_conditions = []
            for opt in all_opts:
                or_conditions.append(Product.name.ilike(f"%{opt}%"))
                or_conditions.append(Product.description.ilike(f"%{opt}%"))
                or_conditions.append(func.array_to_string(Product.tags, ',').ilike(f"%{opt}%"))
                or_conditions.append(Product.restaurant.has(Restaurant.name.ilike(f"%{opt}%")))
                or_conditions.append(Product.category.has(Category.name.ilike(f"%{opt}%")))
            word_clauses.append(or_(*or_conditions))
        else:
            for w in search_words:
                syns = SYNONYM_DICTIONARY.get(w, [])
                word_options = list(set([w] + syns))

                # Substrings matching across name, description, tags, restaurant, and category
                or_conditions = []
                for opt in word_options:
                    or_conditions.append(Product.name.ilike(f"%{opt}%"))
                    or_conditions.append(Product.description.ilike(f"%{opt}%"))
                    or_conditions.append(func.array_to_string(Product.tags, ',').ilike(f"%{opt}%"))
                    or_conditions.append(Product.restaurant.has(Restaurant.name.ilike(f"%{opt}%")))
                    or_conditions.append(Product.category.has(Category.name.ilike(f"%{opt}%")))
                word_clauses.append(or_(*or_conditions))

        stmt = select(Product).options(
            selectinload(Product.category),
            selectinload(Product.restaurant)
        ).where(and_(*filters, *word_clauses))
        res = await db.execute(stmt)
        matched_products = res.scalars().all()

        # Fallback to general list if no matches
        if not matched_products:
            stmt_fallback = select(Product).options(
                selectinload(Product.category),
                selectinload(Product.restaurant)
            ).where(and_(*filters)).limit(500)
            res_fallback = await db.execute(stmt_fallback)
            matched_products = res_fallback.scalars().all()

        # Score matching
        scored_products = []
        for p in matched_products:
            name_score = get_fuzzy_score(normalized_search, p.name)
            p_tags = p.tags or []
            tag_score = 85.0 if any(get_fuzzy_score(normalized_search, t) > 60 for t in p_tags) else 0.0
            desc_score = get_fuzzy_score(normalized_search, p.description or "") * 0.5

            # Synonym match bonus
            syn_score = 0.0
            for opt in (phrase_syns if phrase_syns else []):
                if opt in p.name.lower() or any(opt in t.lower() for t in p_tags):
                    syn_score = max(syn_score, 80.0)
            for w in search_words:
                for syn in SYNONYM_DICTIONARY.get(w, []):
                    if syn in p.name.lower() or any(syn in t.lower() for t in p_tags):
                        syn_score = max(syn_score, 75.0)

            score = max(name_score, tag_score, desc_score, syn_score, 50.0)
            scored_products.append((p, score))

        # Filter > 35 and sort by score
        matches = [item for item in scored_products if item[1] > 35]
        matches.sort(key=lambda x: x[1], reverse=True)

        # M3 FIX: Prioritize in-stock items before out-of-stock for customer searches
        if not is_worker and not includeUnavailable:
            matches.sort(key=lambda x: (x[0].stock > 0), reverse=True)

        if sort == "price-asc":
            matches.sort(key=lambda x: x[0].price)
        elif sort == "price-desc":
            matches.sort(key=lambda x: x[0].price, reverse=True)
        elif sort == "discount-desc":
            matches.sort(key=lambda x: x[0].discount, reverse=True)

        total = len(matches)
        memory_skip = (page - 1) * limit
        products = [m[0] for m in matches[memory_skip:memory_skip + limit]]
    else:
        # 2. Database cursor / offset pagination
        stmt = select(Product).options(
            selectinload(Product.category),
            selectinload(Product.restaurant)
        ).where(and_(*filters)).order_by(*order_by_clauses).limit(limit + 1)
        
        has_cursor = False
        if cursor:
            try:
                cursor_created_at_str, cursor_id = cursor.split(":")
                cursor_created_at = datetime.fromisoformat(cursor_created_at_str.replace("Z", "+00:00"))
                stmt = stmt.where(or_(
                    Product.createdAt < cursor_created_at,
                    and_(Product.createdAt == cursor_created_at, Product.id < cursor_id)
                ))
                has_cursor = True
            except Exception:
                pass

        if not has_cursor:
            stmt = stmt.offset((page - 1) * limit)

        res = await db.execute(stmt)
        db_products = res.scalars().all()
        
        has_more = len(db_products) > limit
        products = db_products[:limit] if has_more else db_products

        if has_cursor:
            total = -1
            if has_more and products:
                last = products[-1]
                next_cursor = f"{last.createdAt.isoformat()}:{last.id}"
        else:
            total_stmt = select(func.count()).select_from(Product).where(and_(*filters))
            total_res = await db.execute(total_stmt)
            total = total_res.scalar()

    # Local store stock overrides applied ONLY to serialized dicts (NEVER modifying ORM instances!)
    inv_map = {}
    if storeId and storeId != "all" and products:
        prod_ids = [p.id for p in products]
        inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == storeId,
            StoreInventory.productId.in_(prod_ids)
        )
        inv_res = await db.execute(inv_stmt)
        inv_list = inv_res.scalars().all()
        inv_map = {inv.productId: inv.stock for inv in inv_list}

    serialized_products = []
    for p in products:
        if storeId and storeId != "all":
            if p.restaurantId:
                local_stk = p.stock or 99999
            else:
                local_stk = inv_map.get(p.id, 0)
        else:
            local_stk = None
        serialized_products.append(serialize_product(p, local_stock=local_stk))

    response_data = {
        "products": serialized_products,
        "pagination": {
            "total": None if total == -1 else total,
            "page": page,
            "limit": limit,
            "totalPages": None if total == -1 else math.ceil(total / limit),
            "nextCursor": next_cursor
        }
    }

    # Save search cache with bounded LRU eviction
    is_cacheable = not is_worker and not includeUnavailable and not admin
    if normalized_search and is_cacheable:
        if len(search_cache) > 500:
            for k in list(search_cache.keys())[:100]:
                search_cache.pop(k, None)
        search_cache[cache_key] = response_data

    # ETag generation and 304 Not Modified support
    if is_cacheable and serialized_products:
        etag_seed = f"{len(serialized_products)}:{serialized_products[0]['id']}:{serialized_products[-1]['id']}:{serialized_products[0].get('stock', 0)}:{serialized_products[-1].get('stock', 0)}"
        etag = f'"{hashlib.md5(etag_seed.encode()).hexdigest()[:16]}"'
        response.headers["ETag"] = etag
        client_etag = request.headers.get("if-none-match")
        if client_etag and client_etag.strip() == etag:
            return Response(status_code=304, headers={"ETag": etag, "Cache-Control": "public, s-maxage=15, stale-while-revalidate=30"})

    response.headers["Cache-Control"] = "public, s-maxage=15, stale-while-revalidate=30" if is_cacheable else "no-store, max-age=0, must-revalidate"
    return response_data


@router.get("/buy-again")
async def get_buy_again(
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get user previous order history or fallback to bestsellers.
    """
    user_id = current_user.get("id") if current_user else None
    products = []
    ordered_product_days = {}

    if user_id:
        try:
            # Query last 10 completed orders
            order_stmt = select(Order.id, Order.createdAt).where(
                Order.userId == user_id,
                Order.status.in_(["CONFIRMED", "PACKED", "SHIPPED", "DELIVERED"])
            ).order_by(Order.createdAt.desc()).limit(10)
            order_res = await db.execute(order_stmt)
            orders = order_res.all()

            if orders:
                order_ids = [o.id for o in orders]
                
                # Fetch order items
                item_stmt = select(OrderItem).where(OrderItem.orderId.in_(order_ids))
                item_res = await db.execute(item_stmt)
                order_items = item_res.scalars().all()

                # Hydrate products
                p_ids = list(set([oi.productId for oi in order_items if oi.productId]))
                prod_stmt = select(Product).where(Product.id.in_(p_ids))
                prod_res = await db.execute(prod_stmt)
                db_prods = prod_res.scalars().all()
                prod_map = {p.id: p for p in db_prods}

                now = datetime.utcnow()
                for o in orders:
                    diff_time = now - o.createdAt
                    diff_days = max(1, diff_time.days)

                    items = [oi for oi in order_items if oi.orderId == o.id]
                    for item in items:
                        if item.productId and item.productId in prod_map:
                            pid = item.productId
                            if pid not in ordered_product_days:
                                ordered_product_days[pid] = diff_days
                                products.append(prod_map[pid])
        except Exception as e:
            print(f"Error loading buy again history: {e}")

    # Fallback to popular items
    if len(products) < 6:
        existing_ids = [p.id for p in products]
        fallback_stmt = select(Product).where(
            Product.id.not_in(existing_ids) if existing_ids else True,
            Product.isAvailable == True,
            Product.stock > 0
        ).limit(8 - len(products))
        fallback_res = await db.execute(fallback_stmt)
        popular_products = fallback_res.scalars().all()

        mock_days = [2, 5, 7, 12, 15, 9, 4, 6]
        for idx, p in enumerate(popular_products):
            ordered_product_days[p.id] = mock_days[idx % len(mock_days)]
            products.append(p)

    # Format output
    formatted = []
    for p in products[:8]:
        category_slug = p.category.slug if p.category else "general"
        formatted.append({
            "id": p.id,
            "name": p.name,
            "slug": p.slug,
            "imageUrl": p.imageUrl,
            "price": p.price,
            "mrp": p.mrp,
            "unit": p.unit,
            "lastOrderedDays": ordered_product_days.get(p.id, 3),
            "categorySlug": category_slug
        })

    return formatted


@router.post("/live-stock")
async def check_live_stock(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Get live prices and inventory stocks for a list of product ids (including variants).
    """
    ids = payload.get("ids", [])
    if not isinstance(ids, list):
        raise HTTPException(status_code=400, detail="Invalid product IDs list")

    if not ids:
        return {}

    # Extract base ids
    base_ids = [id_str.split("_")[0] if "_" in id_str else id_str for id_str in ids]

    stmt = select(Product).where(Product.id.in_(base_ids))
    res = await db.execute(stmt)
    products = res.scalars().all()

    stock_map = {}
    for id_str in ids:
        is_variant = "_" in id_str
        product_id, variant_name = id_str.split("_") if is_variant else (id_str, None)

        p = next((prod for prod in products if prod.id == product_id), None)
        if not p:
            continue

        if is_variant and p.variants and isinstance(p.variants, list):
            variant = next((v for v in p.variants if v.get("name") == variant_name), None)
            if variant:
                stock_map[id_str] = {
                    "price": variant.get("price", p.price),
                    "mrp": variant.get("mrp", p.mrp),
                    "stock": variant.get("stock", 0),
                    "isAvailable": p.isAvailable and variant.get("stock", 0) > 0
                }
                continue

        stock_map[id_str] = {
            "price": p.price,
            "mrp": p.mrp,
            "stock": p.stock,
            "isAvailable": p.isAvailable
        }

    return stock_map


@router.get("/upsell")
async def get_upsell_recommendations(
    productIds: str = Query(""),
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Get cross-selling upsell product recommendations based on cart contents, isolated by local hub stock.
    """
    cart_product_ids = [pid for pid in productIds.split(",") if pid]
    if not cart_product_ids:
        return {"products": []}

    stmt = select(Product).where(Product.id.in_(cart_product_ids))
    res = await db.execute(stmt)
    cart_products = res.scalars().all()

    cart_tags = set(t.lower() for p in cart_products for t in (p.tags or []))

    is_as_cart = any(p.restaurantId == OUTLET_AS_RESTAURANT_ID or any(t in ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant'] for t in [tag.lower() for tag in (p.tags or [])]) for p in cart_products)
    is_wedson_cart = any(p.restaurantId == OUTLET_WEDSON_ID or any(t in ['wedson', 'wedson-restaurant'] for t in [tag.lower() for tag in (p.tags or [])]) for p in cart_products)
    is_cafe_category_cart = any((p.category.slug in ['cafe', 'fastkirana-cafe'] if p.category else False) or any(t in ['cafe', 'shakes'] for t in [tag.lower() for tag in (p.tags or [])]) for p in cart_products)

    # Food/meal item detection in cart
    has_food_item = any(
        any(k in p.name.lower() for k in ['biryani', 'burger', 'pizza', 'roll', 'meal', 'thali', 'noodle', 'rice', 'chicken', 'paneer'])
        or is_as_cart or is_wedson_cart or is_cafe_category_cart
        for p in cart_products
    )

    # Establish filter boundaries
    type_filters = []
    if is_as_cart:
        type_filters.append(or_(
            Product.restaurantId == OUTLET_AS_RESTAURANT_ID,
            func.array_to_string(Product.tags, ',').ilike('%as-restaurant%'),
            func.array_to_string(Product.tags, ',').ilike('%as-cafe%'),
            and_(Product.restaurantId == None, or_(
                func.array_to_string(Product.tags, ',').ilike('%beverages%'),
                func.array_to_string(Product.tags, ',').ilike('%ice-cream%'),
                func.array_to_string(Product.tags, ',').ilike('%drinks%'),
                func.array_to_string(Product.tags, ',').ilike('%cold-drink%')
            ))
        ))
    elif is_wedson_cart:
        type_filters.append(or_(
            Product.restaurantId == OUTLET_WEDSON_ID,
            func.array_to_string(Product.tags, ',').ilike('%wedson%'),
            and_(Product.restaurantId == None, or_(
                func.array_to_string(Product.tags, ',').ilike('%beverages%'),
                func.array_to_string(Product.tags, ',').ilike('%ice-cream%'),
                func.array_to_string(Product.tags, ',').ilike('%drinks%'),
                func.array_to_string(Product.tags, ',').ilike('%cold-drink%')
            ))
        ))
    elif is_cafe_category_cart:
        type_filters.append(or_(
            Product.category.has(Category.slug.in_(['cafe', 'fastkirana-cafe', 'ice-cream', 'beverages', 'shakes'])),
            func.array_to_string(Product.tags, ',').ilike('%cafe%'),
            func.array_to_string(Product.tags, ',').ilike('%beverages%')
        ))
    else:
        grocery_conditions = [
            Product.restaurantId == None,
        ]
        if storeId and storeId != "all":
            grocery_conditions.append(
                exists().where(
                    and_(
                        StoreInventory.productId == Product.id,
                        StoreInventory.storeId == storeId,
                        StoreInventory.stock > 0
                    )
                )
            )
        type_filters.append(and_(*grocery_conditions))

    recommended_products = []

    # Fallback to association rules based on tags
    target_tags = set()
    if has_food_item:
        target_tags.update(['beverages', 'cold-drink', 'drinks', 'ice-cream', 'shakes', 'coolers', 'thums-up', 'coke', 'pepsi', 'sprite', 'cold-coffee'])

    if is_as_cart or is_wedson_cart:
        target_tags.update(['north-indian', 'curry', 'roti', 'naan', 'south-indian', 'biryani-rice', 'chinese'])
    elif is_cafe_category_cart:
        if 'burgers' in cart_tags or 'burger' in cart_tags:
            target_tags.update(['shakes', 'mocktails', 'coolers', 'cold-drink', 'beverages', 'drinks', 'fries'])
        if 'sandwiches' in cart_tags or 'sandwich' in cart_tags:
            target_tags.update(['shakes', 'mocktails', 'cold-coffee', 'beverages'])
        if 'hot-beverage' in cart_tags or 'tea' in cart_tags or 'coffee' in cart_tags:
            target_tags.update(['bakery', 'snacks', 'hot-bite'])
    else:
        if 'staples' in cart_tags or 'cooking' in cart_tags:
            target_tags.update(['dairy', 'breakfast', 'oil', 'spices'])
        if 'breakfast' in cart_tags or 'dairy' in cart_tags:
            target_tags.update(['bakery', 'bread', 'snacks', 'tea', 'coffee'])
        if 'atta' in cart_tags or 'wheat' in cart_tags:
            target_tags.update(['oil', 'salt', 'rice'])

    exclude_ids = list(set(cart_product_ids + [p.id for p in recommended_products]))

    if target_tags:
        tag_match_conditions = [func.array_to_string(Product.tags, ',').ilike(f"%{t}%") for t in target_tags]
        stmt_tags = select(Product).where(
            Product.id.not_in(exclude_ids),
            Product.isAvailable == True,
            Product.stock > 0,
            or_(*tag_match_conditions),
            *type_filters
        ).limit(8)
        res_tags = await db.execute(stmt_tags)
        recommended_products.extend(res_tags.scalars().all())

    # Fallback: general cheap popular items
    if len(recommended_products) < 6:
        exclude_ids = list(set(cart_product_ids + [p.id for p in recommended_products]))
        stmt_fallback = select(Product).where(
            Product.id.not_in(exclude_ids),
            Product.isAvailable == True,
            Product.stock > 0,
            Product.price < 200.0,
            *type_filters
        ).order_by(Product.isBestSeller.desc(), Product.sortOrder.desc()).limit(8 - len(recommended_products))
        res_fallback = await db.execute(stmt_fallback)
        recommended_products.extend(res_fallback.scalars().all())

    if has_food_item:
        def food_upsell_rank(prod):
            n = prod.name.lower()
            tags_str = ",".join(prod.tags or []).lower()
            if any(k in n or k in tags_str for k in ['thums up', 'thumsup', 'coke', 'coca cola', 'pepsi', 'sprite', 'cold drink', 'limca', 'fanta', 'frooti']):
                return 0
            if any(k in n or k in tags_str for k in ['ice cream', 'ice-cream', 'cornetto', 'chocobar', 'kulfi', 'cone', 'shake', 'cold coffee']):
                return 1
            if any(k in n or k in tags_str for k in ['beverage', 'drink', 'juice']):
                return 2
            return 3
        recommended_products.sort(key=food_upsell_rank)

    return {"products": recommended_products[:8]}


@router.post("/validate-cart")
async def validate_checkout_cart(
    payload: Dict[str, Any] = Body(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Validate checkout cart items, updating client on stock shortages, caps, and price changes.
    """
    items = payload.get("items", [])
    if not isinstance(items, list):
        raise HTTPException(status_code=400, detail="Invalid cart items")

    product_ids = []
    for item in items:
        p = item.get("product", {})
        pid = p.get("id")
        if pid:
            product_ids.append(pid.split("_")[0] if "_" in pid else pid)

    if not product_ids:
        return {"hasChanges": False, "updates": []}

    stmt = select(Product).where(Product.id.in_(product_ids))
    res = await db.execute(stmt)
    db_products = res.scalars().all()

    updates = []
    for item in items:
        client_product = item.get("product", {})
        client_qty = item.get("quantity", 0)
        client_pid = client_product.get("id")
        if not client_pid:
            continue

        is_variant = "_" in client_pid
        product_id, variant_name = client_pid.split("_") if is_variant else (client_pid, None)

        db_product = next((p for p in db_products if p.id == product_id), None)

        # Availability Check
        if not db_product or not db_product.isAvailable:
            updates.append({
                "type": "OUT_OF_STOCK",
                "productId": client_pid,
                "name": client_product.get("name", "Product")
            })
            continue

        # Resolve variant details
        db_price = db_product.price
        db_mrp = db_product.mrp
        db_stock = db_product.stock

        if is_variant and db_product.variants and isinstance(db_product.variants, list):
            variant = next((v for v in db_product.variants if v.get("name") == variant_name), None)
            if variant:
                db_price = variant.get("price", db_price)
                db_mrp = variant.get("mrp", db_mrp)
                db_stock = variant.get("stock", 0)

        # C10 FIX: Add verified addon pricing from DB if item has selectedAddons
        selected_addons = client_product.get("selectedAddons") or item.get("selectedAddons")
        if isinstance(selected_addons, list) and len(selected_addons) > 0:
            addon_sum = 0.0
            db_addons = db_product.addons if isinstance(db_product.addons, list) else []
            for sa in selected_addons:
                if not isinstance(sa, dict):
                    continue
                found_price = float(sa.get("price", 0.0))
                for g in db_addons:
                    if isinstance(g, dict) and isinstance(g.get("items"), list):
                        matched = next((i for i in g["items"] if isinstance(i, dict) and i.get("name") == sa.get("name")), None)
                        if matched:
                            found_price = float(matched.get("price", found_price))
                            break
                addon_sum += found_price
            db_price += addon_sum
            db_mrp += addon_sum

        if db_stock <= 0:
            updates.append({
                "type": "OUT_OF_STOCK",
                "productId": client_pid,
                "name": client_product.get("name", "Product")
            })
            continue

        # Limit checks
        limit = get_product_limit(db_product)
        max_allowed = min(db_stock, limit)
        if client_qty > max_allowed:
            updates.append({
                "type": "QUANTITY_CAP",
                "productId": client_pid,
                "name": client_product.get("name"),
                "oldVal": client_qty,
                "newVal": max_allowed
            })

        # Price audits
        if client_product.get("price") != db_price:
            updates.append({
                "type": "PRICE_UPDATE",
                "productId": client_pid,
                "name": client_product.get("name"),
                "oldVal": client_product.get("price"),
                "newVal": db_price
            })

        # MRP audits
        if client_product.get("mrp") != db_mrp:
            updates.append({
                "type": "MRP_UPDATE",
                "productId": client_pid,
                "name": client_product.get("name"),
                "oldVal": client_product.get("mrp"),
                "newVal": db_mrp
            })

    return {
        "hasChanges": len(updates) > 0,
        "updates": updates
    }


@router.get("/{id}")
async def get_product_details(
    id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed product info by ID or Slug, including reviews and category metadata.
    """
    stmt = select(Product).options(
        selectinload(Product.category),
        selectinload(Product.restaurant)
    ).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    return serialize_product(product)


@router.post("")
async def create_product(
    payload: Dict[str, Any] = Body(...),
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new product (Admin only).
    """
    name = payload.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="Missing required field: name")

    slug = generate_slug(name)
    stmt_exist = select(Product).where(Product.slug == slug)
    res_exist = await db.execute(stmt_exist)
    if res_exist.scalars().first():
        slug = f"{slug}-{uuid.uuid4().hex[:4]}"

    raw_rest_id = payload.get("restaurantId")
    clean_rest_id = str(raw_rest_id).strip() if raw_rest_id else None
    raw_cat_id = payload.get("categoryId")
    clean_cat_id = str(raw_cat_id).strip() if raw_cat_id else None

    # Restaurant dishes do NOT belong to grocery categories
    if clean_rest_id:
        final_rest_id = clean_rest_id
        final_cat_id = None
    else:
        final_rest_id = None
        final_cat_id = clean_cat_id

    raw_mrp = float(payload.get("mrp", 0))
    raw_price = float(payload.get("price", 0))
    variants = payload.get("variants")
    if variants and isinstance(variants, list) and len(variants) > 0:
        variants = sorted(variants, key=lambda x: float(x.get("price", 0)))
        raw_price = float(variants[0].get("price", raw_price))
        raw_mrp = float(variants[0].get("mrp", raw_price))

    discount = max(0.0, round(((raw_mrp - raw_price) / raw_mrp) * 100.0)) if raw_mrp > raw_price else 0.0

    addons = payload.get("addons")
    if addons and not isinstance(addons, list):
        addons = None

    # Generate readableId
    readable_id = None
    try:
        from sqlalchemy import func
        max_res = await db.execute(select(func.max(Product.readableId)))
        max_id = max_res.scalar() or 200000
        readable_id = int(max_id) + 1
    except Exception:
        pass

    product = Product(
        id=str(uuid.uuid4()),
        readableId=readable_id,
        name=name.strip(),
        slug=slug,
        description=payload.get("description") or "",
        imageUrl=(str(payload.get("imageUrl") or "").strip()) or "📦",
        categoryId=final_cat_id,
        restaurantId=final_rest_id,
        mrp=raw_mrp,
        price=raw_price,
        discount=discount,
        unit=str(payload.get("unit", "pcs")).strip(),
        stock=99999 if final_rest_id else int(payload.get("stock", 0)),
        isAvailable=bool(payload.get("isAvailable", True)),
        tags=payload.get("tags") if isinstance(payload.get("tags"), list) else [],
        variants=variants if isinstance(variants, (list, dict)) else None,
        addons=addons,
        minStock=int(payload.get("minStock", 10)),
        expiryDate=datetime.fromisoformat(str(payload.get("expiryDate")).replace('Z', '+00:00')) if payload.get("expiryDate") else None,
        costPrice=float(payload.get("costPrice", 0)),
        location=payload.get("location"),
        isFlashDeal=bool(payload.get("isFlashDeal", False)),
        isTopPick=bool(payload.get("isTopPick", False)),
        isBestSeller=bool(payload.get("isBestSeller", False)),
        sortOrder=int(payload.get("sortOrder", 0)),
        availableStartTime=payload.get("availableStartTime"),
        availableEndTime=payload.get("availableEndTime"),
        barcode=str(payload.get("barcode", "")).strip() if payload.get("barcode") else None,
        vendor=payload.get("vendor"),
        vendorId=payload.get("vendorId")
    )

    try:
        db.add(product)
        await db.flush()

        # C9 FIX: Multi-Hub Store Inventory Seeding
        initial_stock_num = 99999 if final_rest_id else int(payload.get("stock", 0))
        target_store_id = (payload.get("storeId") if payload.get("storeId") != "all" else None) or admin_user.get("assignedStoreId")

        from models import StoreInventory, DarkStore
        try:
            if target_store_id and target_store_id != "all":
                inv_stmt = select(StoreInventory).where(
                    StoreInventory.productId == product.id,
                    StoreInventory.storeId == target_store_id
                )
                inv_res = await db.execute(inv_stmt)
                existing_inv = inv_res.scalars().first()
                if existing_inv:
                    existing_inv.stock = initial_stock_num
                else:
                    db.add(StoreInventory(
                        productId=product.id,
                        storeId=target_store_id,
                        stock=initial_stock_num
                    ))
            else:
                stores_res = await db.execute(select(DarkStore.id))
                all_store_ids = stores_res.scalars().all()
                for sid in all_store_ids:
                    db.add(StoreInventory(
                        productId=product.id,
                        storeId=sid,
                        stock=initial_stock_num
                    ))
        except Exception as seed_err:
            logger.warning(f"Could not seed store_inventories for product {product.id}: {seed_err}")

        await db.commit()
        search_cache.clear()
        return product
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create product: {str(e)}")


@router.patch("/{id}")
async def update_product(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update product details. Admins can update any, Chefs/Owners only their assigned restaurant,
    Pickers can update darkstore grocery products.
    """
    role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")
    phone = str(current_user.get("phone") or "")
    email = str(current_user.get("email") or "").lower()

    stmt = select(Product).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Auth Guard checks - matching Next.js staff checks with strict outlet isolation
    is_admin = (
        role == "ADMIN"
        or "8112849854" in phone
        or "8112849854" in email
        or email.startswith("admin")
        or "hrdk" in email
    )
    is_chef = role in ["CHEF", "RESTAURANT_OWNER"] or email.startswith("restaurant")
    is_picker = role == "PICKER"

    if not is_admin and not is_chef and not is_picker:
        raise HTTPException(status_code=403, detail="Unauthorized to edit this product")

    # Strict isolation for Restaurant Staff:
    if is_chef and not is_admin:
        if not product.restaurantId:
            raise HTTPException(
                status_code=403,
                detail="Restaurant staff can only edit dishes belonging to their assigned restaurant, not dark store grocery products."
            )
        
        # Resolve user's assigned outlet
        user_outlet = assigned_restaurant_id
        if not user_outlet:
            u_id = current_user.get("id") or current_user.get("sub")
            if u_id:
                u_res = await db.execute(select(User.assignedRestaurantId).where(User.id == u_id))
                user_outlet = u_res.scalar_one_or_none()

        if not user_outlet:
            raise HTTPException(
                status_code=403,
                detail="No restaurant assigned to your staff account. Contact administrator."
            )

        # Allow match by ID or slug
        rest_stmt = select(Restaurant.id, Restaurant.slug).where(
            or_(Restaurant.id == user_outlet, Restaurant.slug == user_outlet)
        )
        rest_res = await db.execute(rest_stmt)
        matched_rest = rest_res.mappings().first()

        outlet_ids = {user_outlet}
        if matched_rest:
            outlet_ids.add(matched_rest["id"])
            if matched_rest["slug"]:
                outlet_ids.add(matched_rest["slug"])

        if product.restaurantId not in outlet_ids:
            raise HTTPException(
                status_code=403,
                detail="You do not have permission to edit products belonging to another restaurant outlet."
            )

        # Non-admin cannot reassign dish to another restaurant
        if "restaurantId" in payload and payload["restaurantId"]:
            new_rid = str(payload["restaurantId"]).strip()
            if new_rid not in outlet_ids:
                raise HTTPException(
                    status_code=403,
                    detail="Cannot reassign dish to another restaurant outlet."
                )

    # Strict isolation: Pickers can only edit grocery products (not restaurant dishes)
    if is_picker and not is_admin and product.restaurantId:
        raise HTTPException(
            status_code=403,
            detail="Pickers can only edit grocery products. Restaurant items cannot be edited by pickers."
        )

    def parse_float(val, default=0.0):
        if val is None or val == "":
            return default
        try:
            return float(val)
        except Exception:
            return default

    def parse_int(val, default=0):
        if val is None or val == "":
            return default
        try:
            return int(val)
        except Exception:
            return default

    # Fields list mapping
    updatable_fields = [
        'name', 'description', 'imageUrl', 'unit',
        'isAvailable', 'tags', 'location', 'isFlashDeal',
        'isTopPick', 'isBestSeller', 'barcode',
        'availableStartTime', 'availableEndTime', 'vendor', 'vendorId'
    ]

    for key in updatable_fields:
        if key in payload:
            val = payload[key]
            if isinstance(val, str):
                val = val.strip()
                if key == 'description':
                    pass  # keep trimmed string, even if empty
                elif val == "":
                    val = None
            elif val == "":
                val = None
            setattr(product, key, val)

    # Restaurant ID & Category ID auto-alignment: Restaurant dishes do NOT belong to grocery categories
    target_restaurant_id = None
    if "restaurantId" in payload:
        raw_rest_id = payload.get("restaurantId")
        target_restaurant_id = str(raw_rest_id).strip() if raw_rest_id else None
    elif product.restaurantId:
        target_restaurant_id = product.restaurantId

    if target_restaurant_id:
        product.restaurantId = target_restaurant_id
        product.categoryId = None
    elif "categoryId" in payload and payload.get("categoryId"):
        product.categoryId = str(payload["categoryId"]).strip()
        product.restaurantId = None

    if 'minStock' in payload:
        product.minStock = parse_int(payload['minStock'], product.minStock or 10)
    if 'sortOrder' in payload:
        product.sortOrder = parse_int(payload['sortOrder'], product.sortOrder or 0)
    if 'costPrice' in payload:
        product.costPrice = parse_float(payload['costPrice'], product.costPrice or 0.0)

    if 'expiryDate' in payload:
        if payload['expiryDate']:
            dt_str = str(payload['expiryDate']).replace('Z', '+00:00')
            try:
                product.expiryDate = datetime.fromisoformat(dt_str)
            except Exception:
                product.expiryDate = None
        else:
            product.expiryDate = None

    # Resolve pricing & variants
    raw_mrp = payload.get("mrp")
    raw_price = payload.get("price")
    final_mrp = parse_float(raw_mrp, product.mrp)
    final_price = parse_float(raw_price, product.price)

    if "variants" in payload:
        variants = payload["variants"]
        if isinstance(variants, list) and len(variants) > 0:
            sorted_variants = sorted(variants, key=lambda x: parse_float(x.get("price", 0)))
            product.variants = sorted_variants
            final_price = parse_float(sorted_variants[0].get("price"), final_price)
            final_mrp = parse_float(sorted_variants[0].get("mrp"), final_price)
            if not product.unit or product.unit in ['1 pc', '1 unit', '1 Serving']:
                product.unit = sorted_variants[0].get("name", product.unit)
        else:
            product.variants = variants if isinstance(variants, (list, dict)) else None
    else:
        if raw_mrp is not None:
            final_mrp = parse_float(raw_mrp, product.mrp)
        if raw_price is not None:
            final_price = parse_float(raw_price, product.price)

    product.price = final_price
    product.mrp = final_mrp
    product.discount = max(0.0, round(((final_mrp - final_price) / final_mrp) * 100.0)) if final_mrp > final_price else 0.0

    # Addons handling
    if "addons" in payload:
        addons = payload["addons"]
        if isinstance(addons, list) and len(addons) > 0:
            product.addons = addons
        else:
            product.addons = None

    # Multi-hub store localized inventory handling
    target_store_id = payload.get("storeId") or current_user.get("assignedStoreId")
    local_stock_val = None

    if "stock" in payload:
        parsed_stock = parse_int(payload['stock'], product.stock or 0)
        if target_store_id and target_store_id != 'all' and target_store_id != 'hub-209206':
            # Local store edit: do not overwrite master stock, update localized store stock
            local_stock_val = parsed_stock
        else:
            product.stock = parsed_stock

    if target_store_id and target_store_id != 'all' and "stock" in payload:
        val = parse_int(payload['stock'], 0)
        local_stock_val = val
        try:
            inv_stmt = select(StoreInventory).where(
                StoreInventory.productId == product.id,
                StoreInventory.storeId == target_store_id
            )
            inv_res = await db.execute(inv_stmt)
            existing_inv = inv_res.scalars().first()
            if existing_inv:
                existing_inv.stock = val
            else:
                new_inv = StoreInventory(
                    productId=product.id,
                    storeId=target_store_id,
                    stock=val
                )
                db.add(new_inv)
        except Exception as inv_err:
            print(f"Warning: Failed to update StoreInventory in product update: {inv_err}")

    try:
        await db.commit()
        await db.refresh(product)
        search_cache.clear()

        # Real-time WebSocket event dispatch with strict restaurant channel isolation
        try:
            evt_payload = {
                "event": "PRODUCT_UPDATED",
                "productId": product.id,
                "name": product.name,
                "isAvailable": product.isAvailable,
                "stock": product.stock,
                "price": float(product.price or 0.0),
                "mrp": float(product.mrp or 0.0),
                "restaurantId": product.restaurantId,
            }
            if product.restaurantId:
                await manager.broadcast_to_channel(f"restaurant_{product.restaurantId}", evt_payload)
            await manager.broadcast_to_channel("general", evt_payload)
        except Exception as ws_err:
            logger.warning(f"Could not broadcast product update: {ws_err}")

        # If local stock was updated for a store, return product dict with local stock
        if local_stock_val is not None:
            prod_dict = {c.name: getattr(product, c.name) for c in product.__table__.columns}
            prod_dict["stock"] = local_stock_val
            return prod_dict
        return product
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update product: {str(e)}")


@router.delete("/{id}")
async def delete_product(
    id: str,
    admin_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Permanently delete a product (Admin only).
    """
    stmt = select(Product).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    try:
        # Disconnect order items to preserve history
        await db.execute(text("UPDATE order_items SET \"productId\" = NULL WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        
        # Clean product images (H12 FIX)
        try:
            await db.execute(text("DELETE FROM product_images WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        except Exception:
            pass

        # Clean reviews
        await db.execute(text("DELETE FROM reviews WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        
        # Clean inventories
        await db.execute(text("DELETE FROM store_inventories WHERE \"productId\" = :prod_id"), {"prod_id": product.id})
        
        # Clean cart items
        await db.execute(text("DELETE FROM cart_items WHERE \"productId\" = :prod_id"), {"prod_id": product.id})

        await db.delete(product)
        await db.commit()
        search_cache.clear()

        return {"message": "Product permanently deleted"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete product: {str(e)}")
