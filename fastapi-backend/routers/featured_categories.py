from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from models import Category, StoreSetting
from routers.campaigns import require_campaign_admin, admin_scope, no_cache, invalidate_campaign_caches
from services.campaign_config import CampaignValidationError, setting_key, upsert_campaign_settings
from services.featured_categories import KEY, is_grocery_parent, stored_featured_categories, validate_featured_categories

router = APIRouter(prefix='/admin/featured-categories', tags=['Featured categories'])

@router.get('')
async def get_featured_categories(response: Response, storeId: str | None = Query(None), current_admin: dict = Depends(require_campaign_admin), db: AsyncSession = Depends(get_db)):
    no_cache(response)
    store_id = await admin_scope(current_admin, storeId, db)
    result = await db.execute(select(StoreSetting.key, StoreSetting.value).where(StoreSetting.key.in_({KEY, setting_key(KEY, store_id)})))
    settings = {row.key: row.value for row in result.all()}
    own_key = setting_key(KEY, store_id)
    return {'config': stored_featured_categories(settings.get(own_key, settings.get(KEY))), 'inherited': bool(store_id and own_key not in settings)}

@router.put('')
async def update_featured_categories(request: Request, response: Response, current_admin: dict = Depends(require_campaign_admin), db: AsyncSession = Depends(get_db)):
    no_cache(response)
    try:
        payload = await request.json()
    except (ValueError, UnicodeDecodeError) as error:
        raise HTTPException(400, 'Malformed JSON request') from error
    if not isinstance(payload, dict):
        raise HTTPException(422, 'Request body must be an object')
    store_id = await admin_scope(current_admin, payload.get('storeId'), db)
    try:
        config = validate_featured_categories(payload.get('config'))
    except CampaignValidationError as error:
        raise HTTPException(422, str(error)) from error
    ids = [item['categoryId'] for item in config['items']]
    result = await db.execute(select(Category).where(Category.id.in_(ids)))
    valid = {category.id for category in result.scalars().all() if is_grocery_parent(category)}
    if any(category_id not in valid for category_id in ids):
        raise HTTPException(422, 'Choose existing grocery parent categories')
    await upsert_campaign_settings(db, {setting_key(KEY, store_id): config})
    await invalidate_campaign_caches()
    return {'success': True, 'config': config, 'inherited': False}
