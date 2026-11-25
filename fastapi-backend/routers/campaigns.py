"""Admin draft/publish workflow and public published homepage campaign."""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import DarkStore, User, Product, StoreInventory, StoreSetting
from sqlalchemy.orm import selectinload
from utils.jwt import get_clean_secret, extract_user_from_token, is_token_expired
from services.campaign_config import (
    CampaignValidationError, DRAFT_KEY, PUBLISHED_KEY, normalize_store_id,
    parse_stored_campaign, read_campaign_settings, resolve_admin_store,
    select_published, setting_key, upsert_campaign_settings, validate_campaign,
)
from services.campaign_bento_config import (
    DEFAULT_CAMPAIGN_BENTO_CONFIG,
    bento_draft_key,
    bento_published_key,
    collect_bento_product_ids,
    is_bento_card_visible,
    parse_stored_bento,
    validate_bento_config,
)
from copy import deepcopy
import json

router = APIRouter(tags=["Homepage Campaign"])
logger = logging.getLogger("campaigns")
campaign_security = HTTPBearer(auto_error=False)


async def require_campaign_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(campaign_security),
    db: AsyncSession = Depends(get_db),
):
    """Signed mobile/API Bearer identity, then fresh database permissions.

    This endpoint deliberately does not use compatibility identity headers or
    cached token role/store claims. Browser sessions use the local Next route.
    """
    if not credentials or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="A verified Bearer token is required")
    payload = extract_user_from_token(credentials.credentials)
    if not payload or is_token_expired(payload):
        raise HTTPException(status_code=401, detail="Invalid or expired Bearer token")
    if payload.get("scope") == "ws_ticket" or payload.get("type") == "ws_ticket":
        raise HTTPException(status_code=401, detail="WebSocket single-purpose tickets cannot be used for REST endpoints")
    user_id = payload.get("id") or payload.get("sub")
    if not isinstance(user_id, str) or not user_id.strip() or user_id.startswith("mock-id-"):
        raise HTTPException(status_code=401, detail="An authenticated user ID is required")
    try:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            import re
            from sqlalchemy import or_
            raw_phone = str(payload.get("phone") or "")
            digits10 = re.sub(r"\D", "", raw_phone)[-10:] if raw_phone else ""
            if len(digits10) == 10:
                p_res = await db.execute(
                    select(User)
                    .where(
                        User.deletedAt.is_(None),
                        or_(
                            User.phone == digits10,
                            User.phone == f"+91{digits10}",
                            User.phone == f"91{digits10}",
                        ),
                    )
                    .order_by(User.createdAt.asc())
                )
                user = p_res.scalars().first()
    except Exception as error:
        raise HTTPException(status_code=503, detail="Authorization is unavailable") from error
    if user is None or user.deletedAt:
        raise HTTPException(status_code=401, detail="Account is unavailable")
    if user.isBlocked:
        raise HTTPException(status_code=403, detail="Account is blocked")
    role = str(user.role.value if hasattr(user.role, "value") else user.role).upper()
    if role not in ("ADMIN", "SUPER_ADMIN"):
        raise HTTPException(status_code=403, detail="Admin access required")
    return {
        "id": user.id, "role": role, "email": user.email, "phone": user.phone,
        "assignedStoreId": user.assignedStoreId,
        "assignedRestaurantId": user.assignedRestaurantId,
    }


def no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store, max-age=0"


async def admin_scope(user: dict, requested, db: AsyncSession):
    try:
        store_id = resolve_admin_store(user, requested)
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except CampaignValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    if store_id:
        result = await db.execute(select(DarkStore.id).where(DarkStore.id == store_id))
        if result.scalar_one_or_none() is None:
            raise HTTPException(status_code=404, detail="Store not found")
    return store_id


async def invalidate_campaign_caches():
    # Campaign GET itself is uncached. Also invalidate existing settings/home
    # payload caches so legacy consumers cannot retain a prior publication.
    from routers.settings import clear_settings_cache
    from routers.stores_service import clear_stores_cache
    from utils.cache import invalidate_cache_pattern
    clear_settings_cache()
    clear_stores_cache()
    for pattern in ("settings:*", "home:*", "homepage:*", "homepage_campaign:*"):
        try:
            await invalidate_cache_pattern(pattern)
        except Exception:
            logger.warning("Unable to invalidate campaign cache %s", pattern, exc_info=True)


@router.get("/homepage-campaign")
async def get_homepage_campaign(
    response: Response,
    storeId: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    no_cache(response)
    try:
        store_id = normalize_store_id(storeId)
    except CampaignValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    settings = await read_campaign_settings(db, store_id)
    return {"campaign": select_published(settings, store_id)}


@router.get("/admin/campaign")
async def get_admin_campaign(
    response: Response,
    storeId: Optional[str] = Query(None),
    current_admin: dict = Depends(require_campaign_admin),
    db: AsyncSession = Depends(get_db),
):
    no_cache(response)
    store_id = await admin_scope(current_admin, storeId, db)
    settings = await read_campaign_settings(db, store_id, include_draft=True)
    return {
        "draft": parse_stored_campaign(settings.get(setting_key(DRAFT_KEY, store_id))),
        "published": parse_stored_campaign(settings.get(setting_key(PUBLISHED_KEY, store_id))),
    }


@router.put("/admin/campaign")
async def update_admin_campaign(
    request: Request,
    response: Response,
    current_admin: dict = Depends(require_campaign_admin),
    db: AsyncSession = Depends(get_db),
):
    no_cache(response)
    try:
        payload = await request.json()
    except (ValueError, UnicodeDecodeError) as error:
        raise HTTPException(status_code=400, detail="Malformed JSON request") from error
    if not isinstance(payload, dict):
        raise HTTPException(status_code=422, detail="Request body must be an object")
    action = payload.get("action")
    if action not in ("save-draft", "publish", "disable"):
        raise HTTPException(status_code=422, detail="action must be save-draft, publish, or disable")
    store_id = await admin_scope(current_admin, payload.get("storeId"), db)
    settings = await read_campaign_settings(db, store_id, include_draft=True)
    try:
        if action == "disable":
            campaign = select_published(settings, store_id)
            if campaign is None:
                if payload.get("campaign") is None:
                    raise HTTPException(status_code=400, detail="No published campaign to disable")
                campaign = validate_campaign(payload["campaign"])
            campaign = {**campaign, "enabled": False}
            entries = {setting_key(PUBLISHED_KEY, store_id): campaign}
        else:
            if payload.get("campaign") is None:
                raise HTTPException(status_code=422, detail="campaign is required")
            campaign = validate_campaign(payload["campaign"])
            entries = {setting_key(DRAFT_KEY, store_id): campaign}
            if action == "publish":
                entries[setting_key(PUBLISHED_KEY, store_id)] = campaign
        await upsert_campaign_settings(db, entries)
    except CampaignValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    if action != "save-draft":
        await invalidate_campaign_caches()
    return {
        "success": True,
        "draft": campaign if action in ("save-draft", "publish") else parse_stored_campaign(settings.get(setting_key(DRAFT_KEY, store_id))),
        "published": campaign if action in ("publish", "disable") else parse_stored_campaign(settings.get(setting_key(PUBLISHED_KEY, store_id))),
    }


# ─────────────────────────────────────────────────────────────────────────────
# 6-CARD CAMPAIGN BENTO ENDPOINTS (100% FastAPI Parity with Next.js)
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/campaign-bento")
async def get_campaign_bento(
    response: Response,
    storeId: Optional[str] = Query(None),
    includeHidden: bool = Query(False),
    db: AsyncSession = Depends(get_db),
):
    if includeHidden:
        no_cache(response)
    else:
        response.headers["Cache-Control"] = "public, s-maxage=10, stale-while-revalidate=50"

    try:
        store_id = normalize_store_id(storeId)
    except CampaignValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

    key = bento_published_key(store_id)
    keys = list(dict.fromkeys([key, "campaign_bento"]))
    res = await db.execute(select(StoreSetting).where(StoreSetting.key.in_(keys)))
    rows_by_key = {row.key: row.value for row in res.scalars().all()}

    config = (
        parse_stored_bento(rows_by_key.get(key))
        or parse_stored_bento(rows_by_key.get("campaign_bento"))
        or deepcopy(DEFAULT_CAMPAIGN_BENTO_CONFIG)
    )

    effective_store_id = store_id or "hub-209206"
    linked_ids = collect_bento_product_ids(config)
    linked_products = []
    product_avail_map = {}

    if linked_ids:
        prod_res = await db.execute(
            select(Product)
            .options(selectinload(Product.category))
            .where(Product.id.in_(linked_ids), Product.restaurantId.is_(None))
        )
        raw_prods = prod_res.scalars().all()

        inv_res = await db.execute(
            select(StoreInventory).where(
                StoreInventory.storeId == effective_store_id,
                StoreInventory.productId.in_(linked_ids),
            )
        )
        inv_by_pid = {inv.productId: inv for inv in inv_res.scalars().all()}

        for p in raw_prods:
            inv = inv_by_pid.get(p.id)
            stock = inv.stock if inv is not None else (p.stock or 0)
            is_avail = (inv.isAvailable and stock > 0) if inv is not None else (bool(p.isAvailable) and stock > 0)
            price = inv.priceOverride if (inv is not None and inv.priceOverride is not None) else p.price
            mrp = p.mrp or price
            discount = max(0, round(((mrp - price) / mrp) * 100)) if mrp > price else (p.discount or 0)

            cat_obj = None
            if p.category is not None:
                cat_obj = {
                    "id": p.category.id,
                    "name": p.category.name,
                    "slug": p.category.slug,
                    "imageUrl": getattr(p.category, "imageUrl", None),
                    "emoji": getattr(p.category, "emoji", None),
                }

            linked_products.append({
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "description": p.description,
                "imageUrl": p.imageUrl,
                "categoryId": p.categoryId,
                "restaurantId": p.restaurantId,
                "mrp": mrp,
                "price": price,
                "discount": discount,
                "unit": p.unit,
                "stock": stock,
                "isAvailable": is_avail,
                "tags": p.tags or [],
                "variants": p.variants,
                "category": cat_obj,
            })
            product_avail_map[p.id] = bool(is_avail and stock > 0)

    def eval_card(card: dict, items: list) -> dict:
        if not isinstance(card, dict):
            return {}
        in_stock_count = 0
        for item in items or []:
            if not isinstance(item, dict):
                continue
            pid = item.get("productId")
            if not pid:
                in_stock_count += 1
            elif product_avail_map.get(pid):
                in_stock_count += 1

        is_visible, reason = is_bento_card_visible(card, in_stock_count, effective_store_id)
        return {
            **card,
            "enabled": bool(card.get("enabled")) if includeHidden else is_visible,
            "isRuleActive": is_visible,
            "visibilityReason": reason,
            "inStockItemsCount": in_stock_count,
        }

    fm = config.get("freshMarket") or {}
    fm_items = [
        item
        for tab in (fm.get("tabs") or [])
        if isinstance(tab, dict)
        for item in (tab.get("items") or [])
        if isinstance(item, dict)
    ]
    ssu = config.get("seasonalSwitchUp") or {}
    ssu_items = [
        item
        for tab in (ssu.get("tabs") or [])
        if isinstance(tab, dict)
        for item in (tab.get("items") or [])
        if isinstance(item, dict)
    ] + [item for item in (ssu.get("items") or []) if isinstance(item, dict)]

    gb = config.get("giftingBoutique") or {}
    gb_items = [x for x in (gb.get("heroItem"), gb.get("miniItem")) if isinstance(x, dict)]

    processed_campaign = {
        **config,
        "seasonalSwitchUp": eval_card(ssu, ssu_items or [{"productId": None}]),
        "freshMarket": eval_card(fm, fm_items),
        "dailyRestock": eval_card(config.get("dailyRestock") or {}, (config.get("dailyRestock") or {}).get("items") or []),
        "valuePicks": eval_card(config.get("valuePicks") or {}, (config.get("valuePicks") or {}).get("items") or []),
        "giftingBoutique": eval_card(gb, gb_items),
        "movieNight": eval_card(config.get("movieNight") or {}, (config.get("movieNight") or {}).get("items") or []),
        "breakfastClub": eval_card(config.get("breakfastClub") or {}, (config.get("breakfastClub") or {}).get("items") or []),
    }

    return {"campaign": processed_campaign, "linkedProducts": linked_products}


@router.get("/admin/campaign-bento")
async def get_admin_campaign_bento(
    response: Response,
    storeId: Optional[str] = Query(None),
    current_admin: dict = Depends(require_campaign_admin),
    db: AsyncSession = Depends(get_db),
):
    no_cache(response)
    store_id = await admin_scope(current_admin, storeId, db)
    d_key = bento_draft_key(store_id)
    p_key = bento_published_key(store_id)
    keys = list(dict.fromkeys([d_key, p_key, "campaign_bento"]))
    res = await db.execute(select(StoreSetting).where(StoreSetting.key.in_(keys)))
    rows_by_key = {row.key: row.value for row in res.scalars().all()}

    draft = parse_stored_bento(rows_by_key.get(d_key))
    published = parse_stored_bento(rows_by_key.get(p_key)) or parse_stored_bento(rows_by_key.get("campaign_bento"))
    return {"draft": draft, "published": published}


@router.put("/admin/campaign-bento")
async def update_admin_campaign_bento(
    request: Request,
    response: Response,
    current_admin: dict = Depends(require_campaign_admin),
    db: AsyncSession = Depends(get_db),
):
    no_cache(response)
    try:
        payload = await request.json()
    except (ValueError, UnicodeDecodeError) as error:
        raise HTTPException(status_code=400, detail="Malformed JSON request") from error
    if not isinstance(payload, dict):
        raise HTTPException(status_code=422, detail="Request body must be an object")

    action = str(payload.get("action") or "")
    if action not in ("save-draft", "publish", "disable", "reset"):
        raise HTTPException(status_code=422, detail="action must be save-draft, publish, disable, or reset")

    store_id = await admin_scope(current_admin, payload.get("storeId"), db)
    d_key = bento_draft_key(store_id)
    p_key = bento_published_key(store_id)
    keys = list(dict.fromkeys([d_key, p_key, "campaign_bento"]))
    res = await db.execute(select(StoreSetting).where(StoreSetting.key.in_(keys)))
    rows_by_key = {row.key: row.value for row in res.scalars().all()}

    try:
        if action == "disable":
            source = parse_stored_bento(rows_by_key.get(p_key)) or parse_stored_bento(rows_by_key.get("campaign_bento"))
            if not source:
                source = validate_bento_config(payload["campaign"]) if payload.get("campaign") else deepcopy(DEFAULT_CAMPAIGN_BENTO_CONFIG)
            campaign = {**source, "enabled": False}
            entries = {p_key: campaign}
        elif action == "reset":
            campaign = deepcopy(DEFAULT_CAMPAIGN_BENTO_CONFIG)
            entries = {d_key: campaign, p_key: campaign}
        else:
            if payload.get("campaign") is None:
                raise HTTPException(status_code=422, detail="campaign is required")
            campaign = validate_bento_config(payload["campaign"])
            entries = {d_key: campaign}
            if action == "publish":
                entries[p_key] = campaign

        await upsert_campaign_settings(db, entries)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

    if action != "save-draft":
        await invalidate_campaign_caches()

    return {
        "success": True,
        "draft": parse_stored_bento(rows_by_key.get(d_key)) if action == "disable" else campaign,
        "published": parse_stored_bento(rows_by_key.get(p_key)) if action == "save-draft" else campaign,
    }
