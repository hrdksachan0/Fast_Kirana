from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, Response, Request, Header
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
import time

from database import get_db
from models import Product, Category, Review, Order, OrderItem, StoreInventory, Restaurant, User, StoreSetting, DarkStore
from routers.auth import get_current_user, require_admin, require_auth
from routers.websockets import manager
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/products", tags=["Products"])

from services.search_service import SYNONYM_DICTIONARY, get_levenshtein_distance, get_fuzzy_score, expand_search_terms
from services.product_service import get_product_type, get_product_limit, generate_slug, serialize_product

SYNONYM_DICTIONARY = {
    # 🥔 Vegetables & Fresh
    'aalu': ['potato', 'aloo', 'potatoes'],
    'aloo': ['potato', 'aalu', 'potatoes'],
    'potato': ['aloo', 'aalu', 'potatoes'],
    'potatoes': ['aloo', 'aalu', 'potato'],
    'pyaz': ['onion', 'pyaj', 'kanda', 'onions'],
    'pyaj': ['onion', 'pyaz', 'kanda', 'onions'],
    'kanda': ['onion', 'pyaz', 'pyaj'],
    'onion': ['pyaz', 'pyaj', 'kanda', 'onions'],
    'onions': ['pyaz', 'pyaj', 'kanda', 'onion'],
    'tamatar': ['tomato', 'tomatoes'],
    'tomato': ['tamatar', 'tomatoes'],
    'tomatoes': ['tamatar', 'tomato'],
    'nimbu': ['lemon', 'lime'],
    'lemon': ['nimbu', 'lime'],
    'adrak': ['ginger'],
    'ginger': ['adrak'],
    'lahsun': ['garlic', 'lehsun'],
    'lehsun': ['garlic', 'lahsun'],
    'garlic': ['lahsun', 'lehsun'],
    'mirch': ['chilli', 'chili', 'mirchi', 'green chilli', 'red chilli'],
    'mirchi': ['chilli', 'chili', 'mirch'],
    'chilli': ['mirch', 'mirchi', 'green chilli', 'red chilli'],
    'chili': ['mirch', 'mirchi', 'green chilli'],
    'hari mirch': ['green chilli', 'chilli', 'mirch'],
    'lal mirch': ['red chilli', 'chilli', 'mirch'],
    'dhaniya': ['coriander', 'cilantro'],
    'coriander': ['dhaniya'],
    'kheera': ['cucumber', 'khira'],
    'cucumber': ['kheera'],
    'gobi': ['cauliflower', 'cabbage', 'gobhi'],
    'patta gobi': ['cabbage', 'band gobhi'],
    'phool gobi': ['cauliflower', 'gobhi'],
    'cabbage': ['patta gobi', 'gobi'],
    'cauliflower': ['phool gobi', 'gobi'],
    'matar': ['peas', 'green peas', 'muttar'],
    'peas': ['matar', 'green peas'],
    'bhindi': ['lady finger', 'okra', 'bhendi'],
    'lady finger': ['bhindi', 'okra'],

    # 🥛 Dairy & Breakfast
    'doodh': ['milk', 'dudh', 'amul', 'amul milk', 'dairy'],
    'dudh': ['milk', 'doodh', 'amul', 'amul milk', 'dairy'],
    'milk': ['doodh', 'dudh', 'amul', 'dairy', 'cow milk'],
    'dahi': ['curd', 'yogurt', 'amul masti'],
    'curd': ['dahi', 'yogurt'],
    'yogurt': ['dahi', 'curd'],
    'makhan': ['butter', 'amul butter', 'white butter'],
    'butter': ['makhan', 'amul butter', 'amul'],
    'paneer': ['cottage cheese', 'amul paneer', 'fresh paneer'],
    'cheese': ['paneer', 'amul cheese', 'slice cheese'],
    'ghee': ['clarified butter', 'desi ghee', 'amul ghee'],
    'desi ghee': ['ghee', 'amul ghee'],
    'chhaas': ['buttermilk', 'chach', 'mattha', 'amul masti'],
    'chach': ['buttermilk', 'chhaas', 'mattha'],
    'lassi': ['buttermilk', 'sweet lassi', 'amul'],
    'anda': ['egg', 'eggs', 'white eggs'],
    'ande': ['egg', 'eggs', 'white eggs'],
    'egg': ['anda', 'ande', 'eggs'],
    'eggs': ['anda', 'ande', 'egg'],
    'bread': ['pav', 'bun', 'loaf', 'white bread', 'brown bread', 'harvest'],
    'pav': ['bread', 'bun'],
    'bun': ['bread', 'pav'],
    'rusk': ['toast', 'biscuit', 'britannia rusk', 'toast rusk'],
    'toast': ['rusk', 'biscuit'],
    'chai': ['tea', 'taj mahal', 'tata tea', 'red label', 'patti'],
    'tea': ['chai', 'tata tea', 'red label', 'taj mahal', 'patti'],
    'patti': ['tea', 'chai', 'chai patti'],
    'coffee': ['nescafe', 'bru', 'instant coffee'],
    'nescafe': ['coffee'],
    'bru': ['coffee'],

    # 🌾 Staples & Grains
    'atta': ['flour', 'wheat', 'gehu', 'ashirvaad', 'chakki atta', 'aata'],
    'aata': ['flour', 'wheat', 'gehu', 'ashirvaad', 'chakki atta', 'atta'],
    'flour': ['atta', 'aata', 'wheat', 'maida'],
    'wheat': ['gehu', 'atta', 'flour'],
    'gehu': ['wheat', 'atta', 'flour'],
    'maida': ['refined flour', 'all purpose flour'],
    'besan': ['gram flour', 'chana flour'],
    'sooji': ['semolina', 'suji', 'rava'],
    'suji': ['semolina', 'sooji', 'rava'],
    'rava': ['semolina', 'sooji', 'suji'],
    'poha': ['flattened rice', 'chura', 'thick poha'],
    'chura': ['poha', 'flattened rice'],
    'chawal': ['rice', 'basmati', 'kolam', 'daawat', 'india gate'],
    'rice': ['chawal', 'basmati', 'kolam', 'daawat', 'india gate'],
    'basmati': ['rice', 'chawal', 'daawat', 'india gate'],
    'chini': ['sugar', 'cheeni', 'shakkar'],
    'cheeni': ['sugar', 'chini', 'shakkar'],
    'sugar': ['chini', 'cheeni', 'shakkar'],
    'shakkar': ['sugar', 'jaggery', 'gud', 'chini'],
    'gud': ['jaggery', 'gur'],
    'jaggery': ['gud', 'gur'],
    'namak': ['salt', 'tata salt'],
    'salt': ['namak', 'tata salt'],

    # 🫒 Oils & Spices
    'tel': ['oil', 'mustard oil', 'refine', 'fortune', 'sarson'],
    'oil': ['tel', 'mustard oil', 'refined oil', 'fortune', 'sarson'],
    'sarson': ['mustard', 'sarson tel', 'mustard oil', 'kachi ghani'],
    'sarson tel': ['mustard oil', 'oil', 'kachi ghani'],
    'mustard oil': ['sarson tel', 'oil', 'fortune', 'kachi ghani'],
    'refine': ['refined oil', 'fortune', 'oil', 'soya oil'],
    'refined oil': ['refine', 'fortune', 'oil', 'soya'],
    'haldi': ['turmeric', 'turmeric powder'],
    'turmeric': ['haldi'],
    'jeera': ['cumin', 'cumin seeds', 'zeera'],
    'zeera': ['cumin', 'jeera'],
    'cumin': ['jeera', 'zeera'],
    'laung': ['clove'],
    'elaichi': ['cardamom', 'elachi'],
    'dalchini': ['cinnamon'],
    'saunf': ['fennel', 'fennel seeds'],
    'methi': ['fenugreek'],
    'hing': ['asafoetida'],
    'masala': ['garam masala', 'spices', 'mdh', 'everest'],

    # 🍲 Dals & Pulses
    'dal': ['lentils', 'pulses', 'daal'],
    'daal': ['lentils', 'pulses', 'dal'],
    'arhar': ['toor', 'tur dal', 'pigeon pea', 'arhar dal'],
    'toor': ['arhar', 'tur dal', 'toor dal'],
    'moong': ['mung', 'green gram', 'moong dal', 'dhuli moong'],
    'chana': ['chickpeas', 'gram', 'chana dal', 'kala chana'],
    'urad': ['black gram', 'urad dal', 'dhuli urad'],
    'masoor': ['red lentils', 'masoor dal'],
    'rajma': ['kidney beans', 'chitra rajma'],
    'chhole': ['chickpeas', 'kabuli chana', 'chole'],
    'chole': ['chickpeas', 'kabuli chana', 'chhole'],

    # 🍪 Snacks, Biscuits & Munchies
    'biscuit': ['cookie', 'biscuits', 'parle', 'britannia', 'biskut', 'good day', 'marie gold'],
    'biscuits': ['biscuit', 'cookie', 'parle', 'britannia'],
    'biskut': ['biscuit', 'cookie', 'parle'],
    'parle': ['parle-g', 'biscuit', 'rusk', 'krackjack', 'monaco'],
    'parle-g': ['parle', 'biscuit', 'gluco'],
    'good day': ['biscuit', 'britannia', 'butter cookie'],
    'namkeen': ['bhujia', 'mixture', 'haldiram', 'bikano', 'sev'],
    'bhujia': ['namkeen', 'sev', 'haldiram', 'bikano', 'aloo bhujia'],
    'chips': ['lays', 'kurkure', 'bingo', 'wafers', 'crisps'],
    'lays': ['chips', 'wafers', 'crisps'],
    'kurkure': ['namkeen', 'chips', 'snacks', 'tedhe medhe'],
    'maggi': ['noodles', 'instant noodles', 'yippee', 'maggie'],
    'magg': ['maggi', 'noodles', 'instant noodles', 'yippee'],
    'maggie': ['maggi', 'noodles', 'instant noodles', 'yippee'],
    'noodles': ['maggi', 'instant noodles', 'chowmein', 'yippee'],
    'chowmein': ['noodles', 'maggi'],
    'chocolate': ['cadbury', 'dairy milk', 'kitkat', '5 star', 'chocolates', 'silk'],
    'chocolates': ['chocolate', 'cadbury', 'dairy milk', 'kitkat'],
    'cadbury': ['chocolate', 'dairy milk', 'silk', '5 star'],

    # 🥤 Beverages & Water
    'pani': ['water', 'bisleri', 'aquafina', 'mineral water'],
    'water': ['pani', 'bisleri', 'aquafina', 'mineral water'],
    'cold drink': ['colddrink', 'pepsi', 'coke', 'thums up', 'sprite', 'beverage', 'soda', 'frooti', 'maaza', 'sting'],
    'colddrink': ['cold drink', 'pepsi', 'coke', 'sprite', 'beverage'],
    'coke': ['cold drink', 'beverage', 'coca cola'],
    'pepsi': ['cold drink', 'beverage'],
    'sprite': ['cold drink', 'beverage'],
    'frooti': ['mango drink', 'cold drink', 'juice'],
    'maaza': ['mango drink', 'cold drink', 'juice'],
    'juice': ['real juice', 'tropicana', 'frooti', 'maaza'],

    # 🧼 Cleaning, Detergents & Home Care
    'sabun': ['soap', 'lifebuoy', 'dettol', 'lux', 'dove', 'santoor', 'bath soap'],
    'saboon': ['soap', 'sabun'],
    'soap': ['sabun', 'lifebuoy', 'dettol', 'lux', 'dove', 'santoor'],
    'surf': ['detergent', 'washing powder', 'aerial', 'tide', 'wheel', 'ghadi', 'surf excel'],
    'detergent': ['washing powder', 'surf', 'aerial', 'tide', 'wheel', 'ghadi'],
    'washing powder': ['detergent', 'surf', 'tide', 'aerial', 'wheel', 'ghadi'],
    'bartan': ['vim', 'dishwash', 'scrub', 'vim bar', 'bartan sabun'],
    'vim': ['dishwash', 'bartan', 'vim bar', 'lemon vim'],
    'dishwash': ['vim', 'bartan', 'vim bar', 'pril'],
    'harpic': ['toilet cleaner', 'cleaner'],
    'toilet cleaner': ['harpic', 'cleaner'],
    'manjan': ['toothpaste', 'colgate', 'pepsodent', 'paste', 'dant kanti'],
    'paste': ['toothpaste', 'colgate', 'pepsodent', 'close up'],
    'toothpaste': ['paste', 'colgate', 'pepsodent', 'close up', 'dant kanti'],
    'colgate': ['toothpaste', 'paste', 'toothbrush'],
    'brush': ['toothbrush', 'colgate', 'oral b'],
    'toothbrush': ['brush', 'colgate', 'oral b'],
    'shampoo': ['clinic plus', 'head and shoulders', 'sunsilk', 'dove', 'pantene'],
    'hair oil': ['coconut oil', 'bajaj', 'dabur', 'amla', 'parachute'],
    'tel malish': ['hair oil', 'coconut oil', 'bajaj', 'dabur'],
    'all out': ['mosquito', 'good knight', 'liquid refill'],
    'machhar': ['all out', 'good knight', 'mosquito repellent'],

    # 🌸 Women's Hygiene & Personal Care
    'woman': ['women', 'womens', 'pad', 'pads', 'sanitary', 'whisper', 'stayfree', 'sofy', 'hygiene'],
    'women': ['woman', 'womens', 'pad', 'pads', 'sanitary', 'whisper', 'stayfree', 'sofy', 'hygiene'],
    'womens': ['women', 'woman', 'pad', 'pads', 'sanitary', 'whisper', 'stayfree', 'sofy', 'hygiene'],
    'pad': ['pads', 'sanitary', 'whisper', 'stayfree', 'sofy', 'hygiene', 'women'],
    'pads': ['pad', 'sanitary', 'whisper', 'stayfree', 'sofy', 'hygiene', 'women'],
    'sanitary': ['pad', 'pads', 'whisper', 'stayfree', 'hygiene', 'women', 'sofy'],
    'whisper': ['whisper', 'pad', 'pads', 'sanitary', 'women', 'hygiene'],
    'stayfree': ['stayfree', 'pad', 'pads', 'sanitary', 'women'],
    'sofy': ['sofy', 'pad', 'pads', 'sanitary', 'women'],
    'periods': ['pad', 'pads', 'sanitary', 'whisper', 'stayfree', 'women'],

    # 🧔 Men's Grooming
    'man': ['men', 'shaving', 'razor', 'gillette', 'blade'],
    'men': ['man', 'shaving', 'razor', 'gillette', 'blade', 'grooming'],
    'razor': ['shaving', 'blade', 'gillette', 'guard'],
    'shaving': ['razor', 'blade', 'gillette', 'foam', 'gel'],
    'gillette': ['razor', 'blade', 'shaving', 'guard'],

    # 🍬 Sweets & Mithai
    'soan': ['soan papdi', 'papdi', 'mithai', 'haldiram', 'bikano', 'sweets'],
    'papdi': ['soan papdi', 'soan', 'mithai', 'sweets'],
    'soan papdi': ['soan', 'papdi', 'mithai', 'haldiram', 'bikano', 'sweets'],
    'mithai': ['sweets', 'soan papdi', 'gulab jamun', 'rasgulla', 'laddu', 'barfi'],
    'sweets': ['mithai', 'chocolates', 'dessert', 'soan papdi', 'gulab jamun'],

    # 👶 Baby Care
    'baby': ['diaper', 'diapers', 'pampers', 'huggies', 'mamy poko', 'wipes', 'baby soap'],
    'diaper': ['diapers', 'pampers', 'huggies', 'mamy poko', 'baby'],
    'diapers': ['diaper', 'pampers', 'huggies', 'mamy poko', 'baby'],
    'pampers': ['diaper', 'diapers', 'baby', 'huggies'],
    'huggies': ['diaper', 'diapers', 'baby', 'pampers'],
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

from utils.cache import get_cached, set_cached, invalidate_cache_pattern, invalidate_catalog_cache

# In-memory product & search cache to prevent heavy re-ranking and repeated DB queries
search_cache: Dict[str, Any] = {}
search_cache_time: Dict[str, float] = {}
PRODUCTS_CACHE_TTL: float = 60.0

def clear_products_cache():
    global search_cache, search_cache_time
    search_cache.clear()
    search_cache_time.clear()

@router.post("/clear-cache")
async def api_clear_products_cache():
    clear_products_cache()
    await invalidate_catalog_cache()
    return {"success": True, "message": "Products cache cleared"}



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
        rest_scope = Product.restaurant.has(Restaurant.storeId == storeId)
        p_filter.append(or_(Product.restaurantId == None, rest_scope))

    p_stmt = select(
        func.max(Product.updatedAt),
        func.count(Product.id)
    )
    if p_filter:
        p_stmt = p_stmt.where(and_(*p_filter))

    p_res = await db.execute(p_stmt)
    first_row = p_res.first()
    p_max_dt = first_row[0] if first_row else None
    p_count = first_row[1] if first_row else 0

    c_stmt = select(func.count(Category.id))
    c_res = await db.execute(c_stmt)
    c_count = c_res.scalar() or 0

    p_version = int(p_max_dt.timestamp() * 1000) if p_max_dt else int(datetime.utcnow().timestamp() * 1000)
    c_version = int(c_count * 1000)

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
    header_store = request.headers.get("x-store-id")
    raw_store = storeId or header_store
    target_store = raw_store if (raw_store and raw_store.lower() != "all") else None

    # Only default for generic customer requests when NO store is provided at all
    if not target_store and not admin and not is_worker and not includeUnavailable:
        target_store = "hub-209206"

    # Check cache for public catalog and search requests (<5ms response)
    is_cacheable = not is_worker and not includeUnavailable and not admin
    cache_key = f"products:{target_store}:{normalized_search}:{category or ''}:{categoryId or ''}:{sort or ''}:{page}:{limit}:{restaurantId or ''}:{restaurantSlug or ''}:{excludeRestaurant}"
    now = time.time()

    if is_cacheable:
        cached_result = await get_cached(cache_key)
        if cached_result is not None:
            response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
            response.headers["X-FastKirana-Cache"] = "HIT"
            return cached_result

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

    # Store ID Isolation: Customers only see in-stock products in target store.
    # Admins/Workers see the entire catalog so they can manage, toggle availability, and replenish stock.
    if admin or is_worker or includeUnavailable:
        grocery_scope = Product.restaurantId.is_(None)
    else:
        inv_sub_conditions = [
            StoreInventory.productId == Product.id,
            StoreInventory.storeId == target_store,
            StoreInventory.stock > 0
        ]
        grocery_scope = and_(
            Product.restaurantId.is_(None),
            exists().where(and_(*inv_sub_conditions))
        )

    rest_scope = Product.restaurant.has(Restaurant.storeId == target_store)
    filters.append(or_(grocery_scope, rest_scope))

    # Store-wise category status check (hide closed categories for customers)
    if not admin and not is_worker:
        try:
            store_prefix = f"store:{target_store}:category_open_"
            closed_cats_res = await db.execute(
                select(StoreSetting.key).where(
                    and_(
                        StoreSetting.key.startswith(store_prefix),
                        StoreSetting.value == "false"
                    )
                )
            )
            closed_slugs = [k[len(store_prefix):] for k in closed_cats_res.scalars().all()]
            if closed_slugs:
                filters.append(not_(Product.category.has(Category.slug.in_(closed_slugs))))
        except Exception as cat_err:
            logger.warning(f"Failed to check closed categories for store {target_store}: {cat_err}")

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
        is_sql_match = bool(matched_products)
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
            p_tags = [t.lower() for t in (p.tags or [])]
            p_words = set(re.findall(r'\b\w+\b', p.name.lower()))

            # Exact or synonym tag match bonus
            tag_score = 90.0 if any(
                t == normalized_search or t in SYNONYM_DICTIONARY.get(normalized_search, [])
                for t in p_tags
            ) else (85.0 if any(get_fuzzy_score(normalized_search, t) > 60 for t in p_tags) else 0.0)

            desc_score = get_fuzzy_score(normalized_search, p.description or "") * 0.5

            # Synonym match bonus (require whole-word match or substantial substring)
            syn_score = 0.0
            for opt in (phrase_syns if phrase_syns else []):
                if opt in p_words:
                    syn_score = max(syn_score, 85.0)
                elif len(opt) >= 4 and opt in p.name.lower():
                    syn_score = max(syn_score, 75.0)
                elif any(opt in t for t in p_tags):
                    syn_score = max(syn_score, 80.0)

            for w in search_words:
                for syn in SYNONYM_DICTIONARY.get(w, []):
                    if syn in p_words:
                        syn_score = max(syn_score, 85.0)
                    elif len(syn) >= 4 and syn in p.name.lower():
                        syn_score = max(syn_score, 70.0)
                    elif any(syn == t or (len(syn) >= 4 and syn in t) for t in p_tags):
                        syn_score = max(syn_score, 80.0)

            score = max(name_score, tag_score, desc_score, syn_score)
            if score > 35:
                scored_products.append((p, score))

        # Filter > 35 and sort by score
        matches = scored_products
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

    # Local store stock and price overrides applied ONLY to serialized dicts (NEVER modifying ORM instances!)
    inv_map = {}
    if target_store and products:
        prod_ids = [p.id for p in products]
        inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == target_store,
            StoreInventory.productId.in_(prod_ids)
        )
        inv_res = await db.execute(inv_stmt)
        inv_list = inv_res.scalars().all()
        inv_map = {inv.productId: (inv.stock, inv.priceOverride) for inv in inv_list}

    serialized_products = []
    is_admin_mode = bool(admin or is_worker or includeUnavailable)
    for p in products:
        if p.restaurantId:
            local_stk = p.stock or 99999
            local_prc = None
        else:
            inv_info = inv_map.get(p.id)
            if inv_info:
                local_stk = inv_info[0]
                local_prc = inv_info[1]
            else:
                local_stk = (p.stock or 0) if is_admin_mode else 0
                local_prc = None
        serialized_products.append(serialize_product(p, local_stock=local_stk, is_admin=is_admin_mode, local_price=local_prc))

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

    # Save cache with bounded LRU eviction
    if is_cacheable:
        if len(search_cache) > 1000:
            for k in list(search_cache.keys())[:200]:
                search_cache.pop(k, None)
                search_cache_time.pop(k, None)
        search_cache[cache_key] = response_data
        search_cache_time[cache_key] = now
        await set_cached(cache_key, response_data, 60)

    # Provide ETag header for client validation but always deliver full JSON payload to prevent empty cold-start state
    if is_cacheable and serialized_products:
        etag_seed = f"{len(serialized_products)}:{serialized_products[0]['id']}:{serialized_products[-1]['id']}:{serialized_products[0].get('stock', 0)}:{serialized_products[-1].get('stock', 0)}"
        etag = f'"{hashlib.md5(etag_seed.encode()).hexdigest()[:16]}"'
        response.headers["ETag"] = etag

    response.headers["Cache-Control"] = "public, s-maxage=300, stale-while-revalidate=86400" if is_cacheable else "no-store, max-age=0, must-revalidate"
    if is_cacheable:
        response.headers["X-FastKirana-Cache"] = "MISS"
    return response_data


@router.get("/buy-again")
async def get_buy_again(
    storeId: Optional[str] = Query(None),
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
                prod_stmt = select(Product).options(selectinload(Product.category), selectinload(Product.restaurant)).where(Product.id.in_(p_ids))
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
        fallback_conditions = [Product.isAvailable == True]
        if existing_ids:
            fallback_conditions.append(Product.id.not_in(existing_ids))

        if storeId and storeId != "all":
            inv_sub = [StoreInventory.productId == Product.id, StoreInventory.storeId == storeId, StoreInventory.stock > 0]
            fallback_conditions.append(or_(
                Product.restaurant.has(Restaurant.storeId == storeId),
                and_(Product.restaurantId.is_(None), exists().where(and_(*inv_sub))),
                and_(Product.restaurantId.is_(None), Product.stock > 0)
            ))
        else:
            fallback_conditions.append(or_(
                Product.restaurantId.is_not(None),
                Product.stock > 0
            ))

        fallback_stmt = select(Product).options(selectinload(Product.category), selectinload(Product.restaurant)).where(
            and_(*fallback_conditions)
        ).limit(8 - len(products))
        fallback_res = await db.execute(fallback_stmt)
        popular_products = fallback_res.scalars().all()

        mock_days = [2, 5, 7, 12, 15, 9, 4, 6]
        for idx, p in enumerate(popular_products):
            ordered_product_days[p.id] = mock_days[idx % len(mock_days)]
            products.append(p)

    # Format output with live stock, availability, and restaurant info
    formatted = []
    for p in products[:8]:
        category_slug = p.category.slug if p.category else "general"
        is_restaurant = bool(p.restaurantId)
        stock_val = p.stock if p.stock is not None and p.stock > 0 else (999 if is_restaurant else (p.stock if p.stock is not None else 50))
        formatted.append({
            "id": p.id,
            "name": p.name,
            "slug": p.slug,
            "imageUrl": p.imageUrl,
            "price": float(p.price) if p.price is not None else 0.0,
            "mrp": float(p.mrp) if p.mrp is not None else float(p.price or 0.0),
            "unit": p.unit or "",
            "stock": stock_val,
            "isAvailable": p.isAvailable is not False and (is_restaurant or stock_val > 0),
            "restaurantId": p.restaurantId,
            "restaurantName": p.restaurant.name if getattr(p, "restaurant", None) else None,
            "lastOrderedDays": ordered_product_days.get(p.id, 3),
            "categorySlug": category_slug,
            "category": {"id": p.category.id, "name": p.category.name, "slug": p.category.slug} if p.category else None
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
    try:
        cart_product_ids = [pid for pid in productIds.split(",") if pid]
        if not cart_product_ids:
            return {"products": []}

        stmt = select(Product).options(selectinload(Product.category), selectinload(Product.restaurant)).where(Product.id.in_(cart_product_ids))
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
            stmt_tags = select(Product).options(selectinload(Product.category), selectinload(Product.restaurant)).where(
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
            stmt_fallback = select(Product).options(selectinload(Product.category), selectinload(Product.restaurant)).where(
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
                n = (prod.name or "").lower()
                tags_str = ",".join(prod.tags or []).lower()
                if any(k in n or k in tags_str for k in ['thums up', 'thumsup', 'coke', 'coca cola', 'pepsi', 'sprite', 'cold drink', 'limca', 'fanta', 'frooti']):
                    return 0
                if any(k in n or k in tags_str for k in ['ice cream', 'ice-cream', 'cornetto', 'chocobar', 'kulfi', 'cone', 'shake', 'cold coffee']):
                    return 1
                if any(k in n or k in tags_str for k in ['beverage', 'drink', 'juice']):
                    return 2
                return 3
            recommended_products.sort(key=food_upsell_rank)

        # De-duplicate and serialize
        seen_ids = set()
        unique_products = []
        for p in recommended_products:
            if p.id not in seen_ids:
                seen_ids.add(p.id)
                unique_products.append(serialize_product(p))

        return {"products": unique_products[:8]}
    except Exception as e:
        logger.warning(f"Error generating upsell recommendations: {e}")
        return {"products": []}


@router.post("/validate-cart")
async def validate_checkout_cart(
    payload: Dict[str, Any] = Body(...),
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Validate checkout cart items, updating client on stock shortages, caps, and price changes.
    """
    items = payload.get("items", [])
    target_store = payload.get("storeId") or storeId or "hub-209206"
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

    stmt = select(Product).options(selectinload(Product.category)).where(Product.id.in_(product_ids))
    res = await db.execute(stmt)
    db_products = res.scalars().all()

    # Fetch store inventory overlay for target hub (e.g. Ghatampur hub-209206)
    store_inv_map = {}
    if target_store and target_store != "all":
        inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == target_store,
            StoreInventory.productId.in_(product_ids)
        )
        inv_res = await db.execute(inv_stmt)
        store_inv_map = {inv.productId: inv for inv in inv_res.scalars().all()}

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
        local_inv = store_inv_map.get(product_id)

        # Availability Check
        is_restaurant = bool(db_product.restaurantId if db_product else False)
        is_available = db_product.isAvailable if db_product else False
        if not is_restaurant and local_inv is not None:
            is_available = is_available and local_inv.isAvailable

        if not db_product or not is_available:
            updates.append({
                "type": "OUT_OF_STOCK",
                "productId": client_pid,
                "name": client_product.get("name", "Product")
            })
            continue

        # Resolve variant and local inventory details
        db_price = (local_inv.priceOverride if (local_inv and local_inv.priceOverride is not None) else db_product.price)
        db_mrp = db_product.mrp
        db_stock = db_product.stock if is_restaurant else (local_inv.stock if local_inv else db_product.stock)

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
    response: Response,
    storeId: Optional[str] = Query(None),
    x_store_id: Optional[str] = Header(None, alias="x-store-id"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed product info by ID or Slug, including reviews and category metadata.
    Uses ultra-fast multi-tier caching (60s TTL).
    """
    target_store = storeId or x_store_id
    cache_key = f"product_detail:{id}:{target_store or 'all'}"
    cached = await get_cached(cache_key)
    if cached is not None:
        response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
        response.headers["X-FastKirana-Cache"] = "HIT"
        return cached

    stmt = select(Product).options(
        selectinload(Product.category),
        selectinload(Product.restaurant)
    ).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    local_stock = None
    local_price = None
    if target_store:
        if product.restaurantId:
            if product.restaurant and product.restaurant.storeId and product.restaurant.storeId != target_store:
                serialized = serialize_product(product, local_stock=0)
                await set_cached(cache_key, serialized, 60)
                response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
                response.headers["X-FastKirana-Cache"] = "MISS"
                return serialized
            local_stock = product.stock or 99999
        else:
            inv_stmt = select(StoreInventory).where(
                StoreInventory.storeId == target_store,
                StoreInventory.productId == product.id
            )
            inv_res = await db.execute(inv_stmt)
            inv = inv_res.scalars().first()
            local_stock = inv.stock if inv else 0
            local_price = inv.priceOverride if inv else None

    serialized = serialize_product(product, local_stock=local_stock, local_price=local_price)
    await set_cached(cache_key, serialized, 60)
    response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
    response.headers["X-FastKirana-Cache"] = "MISS"
    return serialized


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
        unit=(str(payload.get("unit") or "").strip()) or ("1 Serving" if final_rest_id else "1 pc"),
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

        # Multi-Hub Store Inventory Seeding
        initial_stock_num = 99999 if final_rest_id else int(payload.get("stock", 0))
        target_store_id = (payload.get("storeId") if payload.get("storeId") != "all" else None) or admin_user.get("assignedStoreId")

        from models import StoreInventory, DarkStore
        try:
            stores_res = await db.execute(select(DarkStore.id))
            all_store_ids = stores_res.scalars().all()
            for sid in all_store_ids:
                store_stock = initial_stock_num if (not target_store_id or sid == target_store_id) else 0
                db.add(StoreInventory(
                    productId=product.id,
                    storeId=sid,
                    stock=store_stock,
                    isAvailable=True
                ))
        except Exception as seed_err:
            logger.warning(f"Could not seed store_inventories for product {product.id}: {seed_err}")

        await db.commit()
        await db.refresh(product)
        clear_products_cache()
        await invalidate_catalog_cache()

        # Trigger Next.js storefront ISR revalidation
        try:
            from routers.categories import trigger_revalidation
            cat_slug = None
            if product.categoryId:
                cat_res = await db.execute(select(Category.slug).where(Category.id == product.categoryId))
                cat_slug = cat_res.scalar_one_or_none()
            await trigger_revalidation(cat_slug)
        except Exception as rev_err:
            logger.warning(f"Failed to trigger revalidation on product create: {rev_err}")

        return serialize_product(product, local_stock=initial_stock_num, is_admin=True)
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

    # Auth Guard checks - role-based isolation
    is_admin = role in ["ADMIN", "SUPER_ADMIN"]
    is_chef = role in ["CHEF", "RESTAURANT_OWNER"]
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
                elif key == 'unit':
                    # Unit is NON-NULLABLE in PostgreSQL schema. Never allow None or empty!
                    val = val if val else (product.unit or ('1 Serving' if product.restaurantId else '1 pc'))
                elif key == 'name':
                    val = val if val else product.name
                elif val == "":
                    val = None
            elif key == 'unit' and (val is None or val == ""):
                val = product.unit or ('1 Serving' if product.restaurantId else '1 pc')
            elif key == 'name' and (val is None or val == ""):
                val = product.name
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

    if target_store_id and target_store_id != 'all':
        has_stock = "stock" in payload
        has_price_override = "priceOverride" in payload or ("price" in payload and target_store_id != "hub-209206")
        val = parse_int(payload['stock'], 0) if has_stock else None
        price_ovr = parse_float(payload.get('priceOverride') or payload.get('price'), None) if has_price_override else None
        if has_stock or has_price_override:
            try:
                inv_stmt = select(StoreInventory).where(
                    StoreInventory.productId == product.id,
                    StoreInventory.storeId == target_store_id
                )
                inv_res = await db.execute(inv_stmt)
                existing_inv = inv_res.scalars().first()
                if existing_inv:
                    if val is not None:
                        existing_inv.stock = val
                    if price_ovr is not None:
                        existing_inv.priceOverride = price_ovr
                else:
                    new_inv = StoreInventory(
                        productId=product.id,
                        storeId=target_store_id,
                        stock=val if val is not None else (product.stock or 0),
                        priceOverride=price_ovr
                    )
                    db.add(new_inv)
            except Exception as inv_err:
                print(f"Warning: Failed to update StoreInventory in product update: {inv_err}")

    try:
        await db.commit()
        await db.refresh(product)
        clear_products_cache()
        await invalidate_catalog_cache()

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
        clear_products_cache()
        await invalidate_catalog_cache()

        return {"message": "Product permanently deleted"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete product: {str(e)}")
