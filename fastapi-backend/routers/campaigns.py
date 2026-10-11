"""Admin draft/publish workflow and public published homepage campaign."""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import DarkStore, User
from utils.jwt import get_clean_secret
from services.campaign_config import (
    CampaignValidationError, DRAFT_KEY, PUBLISHED_KEY, normalize_store_id,
    parse_stored_campaign, read_campaign_settings, resolve_admin_store,
    select_published, setting_key, upsert_campaign_settings, validate_campaign,
)

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
    secret = get_clean_secret("AUTH_SECRET")
    if not secret:
        raise HTTPException(status_code=503, detail="Authentication is unavailable")
    try:
        payload = jwt.decode(credentials.credentials, secret, algorithms=["HS256"], options={"require": ["exp"]})
    except jwt.PyJWTError as error:
        raise HTTPException(status_code=401, detail="Invalid or expired Bearer token") from error
    user_id = payload.get("id") or payload.get("sub")
    if not isinstance(user_id, str) or not user_id.strip() or user_id.startswith("mock-id-"):
        raise HTTPException(status_code=401, detail="An authenticated user ID is required")
    try:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
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
