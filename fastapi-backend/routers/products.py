from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, not_, func, text
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import uuid
import re
import math

from database import get_db
from models import Product, Category, Review, Order, OrderItem, StoreInventory, Restaurant, User, StoreSetting
from routers.auth import get_current_user, require_admin, require_auth

router = APIRouter(prefix="/products", tags=["Products"])

# Synonym dictionary for Hinglish / common terms
SYNONYM_DICTIONARY = {
    'aalu': ['potato', 'aloo'],
    'aloo': ['potato', 'aalu'],
    'pyaz': ['onion', 'pyaj'],
    'pyaj': ['onion', 'pyaz'],
    'doodh': ['milk', 'dudh'],
    'dudh': ['milk', 'doodh'],
    'dahi': ['curd', 'yogurt'],
    'anda': ['egg', 'eggs'],
    'tamatar': ['tomato', 'tomatoes'],
    'makhan': ['butter'],
    'nimbu': ['lemon', 'lime'],
    'chai': ['tea'],
    'patti': ['tea'],
    'pani': ['water'],
    'chawal': ['rice'],
    'chini': ['sugar'],
    'namak': ['salt']
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


@router.get("")
async def get_products(
    response: Response,
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
    cache_key = f"search:{normalized_search}:{category or ''}:{sort or ''}:{page}:{limit}:{is_worker}:{restaurantId or ''}:{restaurantSlug or ''}"
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

    # Category matching
    if categoryId:
        cat_ids = [c.strip() for c in categoryId.split(",") if c.strip()]
        filters.append(Product.categoryId.in_(cat_ids))
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
            filters.append(Product.category.has(Category.slug.in_(slugs)))
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

    # Trending items check
    if trending:
        # Load best selling items
        stmt_trending = select(Product).where(
            Product.isAvailable == True,
            Product.restaurantId == None,
            Product.category.has(Category.slug != "cafe")
        ).where(or_(Product.isTopPick == True, Product.isBestSeller == True)).limit(8)
        res_trending = await db.execute(stmt_trending)
        trending_products = res_trending.scalars().all()

        return {
            "products": trending_products,
            "pagination": {
                "total": len(trending_products),
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
        # 1. Fuzzy Text Search
        search_words = normalized_search.split()
        word_clauses = []
        for w in search_words:
            syns = SYNONYM_DICTIONARY.get(w, [])
            word_options = [w] + syns
            
            # Substrings matching in Python
            or_conditions = []
            for opt in word_options:
                or_conditions.append(Product.name.ilike(f"%{opt}%"))
                or_conditions.append(Product.description.ilike(f"%{opt}%"))
                or_conditions.append(Product.restaurant.has(Restaurant.name.ilike(f"%{opt}%")))
            word_clauses.append(or_(*or_conditions))

        stmt = select(Product).where(and_(*filters, *word_clauses))
        res = await db.execute(stmt)
        matched_products = res.scalars().all()

        # Fallback to general list if no matches
        if not matched_products:
            stmt_fallback = select(Product).where(and_(*filters)).limit(500)
            res_fallback = await db.execute(stmt_fallback)
            matched_products = res_fallback.scalars().all()

        # Score matching
        scored_products = []
        for p in matched_products:
            name_score = get_fuzzy_score(normalized_search, p.name)
            p_tags = p.tags or []
            tag_score = 85.0 if any(get_fuzzy_score(normalized_search, t) > 60 for t in p_tags) else 0.0
            desc_score = get_fuzzy_score(normalized_search, p.description or "") * 0.5
            score = max(name_score, tag_score, desc_score)
            scored_products.append((p, score))

        # Filter > 35 and sort by score
        matches = [item for item in scored_products if item[1] > 35]
        matches.sort(key=lambda x: x[1], reverse=True)

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
        stmt = select(Product).where(and_(*filters)).order_by(*order_by_clauses).limit(limit + 1)
        
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

    # Local store stock overrides
    if storeId and products:
        prod_ids = [p.id for p in products]
        inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == storeId,
            StoreInventory.productId.in_(prod_ids)
        )
        inv_res = await db.execute(inv_stmt)
        inv_list = inv_res.scalars().all()
        inv_map = {inv.productId: inv.stock for inv in inv_list}

        for p in products:
            local_stock = inv_map.get(p.id, 0)
            p.stock = local_stock
            p.isAvailable = p.isAvailable and local_stock > 0

    response_data = {
        "products": products,
        "pagination": {
            "total": None if total == -1 else total,
            "page": page,
            "limit": limit,
            "totalPages": None if total == -1 else math.ceil(total / limit),
            "nextCursor": next_cursor
        }
    }

    # Save search cache
    is_cacheable = not is_worker and not includeUnavailable and not admin
    if normalized_search and is_cacheable:
        search_cache[cache_key] = response_data

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
    db: AsyncSession = Depends(get_db)
):
    """
    Get cross-selling upsell product recommendations based on cart contents.
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

    # Establish filter boundaries
    type_filters = []
    if is_as_cart:
        type_filters.append(or_(
            Product.restaurantId == OUTLET_AS_RESTAURANT_ID,
            Product.tags.op('?')('as-restaurant'),
            Product.tags.op('?')('as-cafe')
        ))
    elif is_wedson_cart:
        type_filters.append(or_(
            Product.restaurantId == OUTLET_WEDSON_ID,
            Product.tags.op('?')('wedson'),
            Product.tags.op('?')('wedson-restaurant')
        ))
    elif is_cafe_category_cart:
        type_filters.append(or_(
            Product.category.has(Category.slug.in_(['cafe', 'fastkirana-cafe', 'ice-cream', 'beverages', 'shakes'])),
            Product.tags.op('?|')(['cafe', 'ice-cream', 'beverages', 'shakes', 'mocktails'])
        ))
    else:
        type_filters.append(and_(
            Product.restaurantId == None,
            not_(Product.tags.op('?|')(['as-restaurant', 'as-cafe', 'wedson', 'wedson-restaurant']))
        ))

    recommended_products = []

    # Fallback to association rules based on tags
    target_tags = set()
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
            target_tags.update(['dairy', 'breakfast'])
        if 'breakfast' in cart_tags or 'dairy' in cart_tags:
            target_tags.update(['bakery', 'bread', 'snacks'])

    exclude_ids = list(set(cart_product_ids + [p.id for p in recommended_products]))

    if target_tags:
        stmt_tags = select(Product).where(
            Product.id.not_in(exclude_ids),
            Product.isAvailable == True,
            Product.stock > 0,
            Product.tags.op('?|')(list(target_tags)),
            *type_filters
        ).limit(6)
        res_tags = await db.execute(stmt_tags)
        recommended_products.extend(res_tags.scalars().all())

    # Fallback: general cheap popular items
    if len(recommended_products) < 4:
        exclude_ids = list(set(cart_product_ids + [p.id for p in recommended_products]))
        stmt_fallback = select(Product).where(
            Product.id.not_in(exclude_ids),
            Product.isAvailable == True,
            Product.stock > 0,
            Product.price < 150.0,
            *type_filters
        ).order_by(Product.isBestSeller.desc(), Product.sortOrder.desc()).limit(6 - len(recommended_products))
        res_fallback = await db.execute(stmt_fallback)
        recommended_products.extend(res_fallback.scalars().all())

    return {"products": recommended_products[:6]}


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
    stmt = select(Product).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    return product


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

    product = Product(
        id=str(uuid.uuid4()),
        name=name,
        slug=slug,
        description=payload.get("description"),
        imageUrl=payload.get("imageUrl"),
        categoryId=payload.get("categoryId"),
        restaurantId=payload.get("restaurantId"),
        mrp=float(payload.get("mrp", 0)),
        price=float(payload.get("price", 0)),
        discount=float(payload.get("discount", 0)),
        unit=payload.get("unit", "pcs"),
        stock=int(payload.get("stock", 0)),
        isAvailable=payload.get("isAvailable", True),
        tags=payload.get("tags", []),
        variants=payload.get("variants", []),
        minStock=int(payload.get("minStock", 10)),
        expiryDate=datetime.fromisoformat(payload.get("expiryDate")) if payload.get("expiryDate") else None,
        costPrice=float(payload.get("costPrice", 0)),
        location=payload.get("location"),
        isFlashDeal=payload.get("isFlashDeal", False),
        isTopPick=payload.get("isTopPick", False),
        isBestSeller=payload.get("isBestSeller", False),
        sortOrder=int(payload.get("sortOrder", 0)),
        barcode=payload.get("barcode")
    )

    # Restaurant rules hardening
    if product.restaurantId:
        rest_cat = await db.execute(select(Category).where(Category.slug == "restaurant"))
        cat = rest_cat.scalars().first()
        if cat:
            product.categoryId = cat.id
        
        tags_list = product.tags or []
        if "restaurant" not in tags_list:
            tags_list.append("restaurant")
        if "cafe" in tags_list:
            tags_list.remove("cafe")
        product.tags = tags_list
        product.stock = 999

    try:
        db.add(product)
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
    Update product details. Admins can update any, Chefs/Owners only their assigned restaurant.
    """
    role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")

    stmt = select(Product).where(or_(Product.id == id, Product.slug == id))
    res = await db.execute(stmt)
    product = res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Auth Guard checks
    is_admin = role == "ADMIN"
    is_chef = role in ["CHEF", "RESTAURANT_OWNER"] and assigned_restaurant_id == product.restaurantId

    if not is_admin and not is_chef:
        raise HTTPException(status_code=403, detail="Unauthorized to edit this product")

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
        'name', 'description', 'imageUrl', 'categoryId', 'restaurantId', 'unit',
        'isAvailable', 'tags', 'location', 'isFlashDeal',
        'isTopPick', 'isBestSeller', 'barcode'
    ]

    for key in updatable_fields:
        if key in payload:
            val = payload[key]
            if val == "":
                val = None
            setattr(product, key, val)

    if 'stock' in payload:
        product.stock = parse_int(payload['stock'], product.stock or 0)
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
    
    if "variants" in payload and isinstance(payload["variants"], list):
        sorted_variants = sorted(payload["variants"], key=lambda x: float(x.get("price", 0)))
        product.variants = sorted_variants
        if sorted_variants:
            final_price = float(sorted_variants[0].get("price", final_price))
            final_mrp = float(sorted_variants[0].get("mrp", final_price))

    product.price = final_price
    product.mrp = final_mrp
    product.discount = max(0, round(((final_mrp - final_price) / final_mrp) * 100.0)) if final_mrp > final_price else 0.0

    # Restaurant rules hardening
    if product.restaurantId:
        rest_cat = await db.execute(select(Category).where(Category.slug == "restaurant"))
        cat = rest_cat.scalars().first()
        if cat:
            product.categoryId = cat.id
        
        tags_list = product.tags or []
        if "restaurant" not in tags_list:
            tags_list.append("restaurant")
        if "cafe" in tags_list:
            tags_list.remove("cafe")
        product.tags = tags_list
        product.stock = 999

    try:
        await db.commit()
        search_cache.clear()
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
