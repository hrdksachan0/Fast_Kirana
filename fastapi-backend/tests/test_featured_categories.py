"""Editorial curation validation and real endpoints with isolated persistence."""
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock
import httpx
import pytest
from fastapi import FastAPI
from database import get_db
from models import Category, DarkStore, StoreSetting
from routers import featured_categories as route
from services.campaign_config import CampaignValidationError
from services.featured_categories import validate_featured_categories, stored_featured_categories

def config(**overrides):
    return {'version': 1, 'items': [{'categoryId': 'snacks'}], **overrides}

def test_editorial_defaults_and_explicit_hidden():
    value = validate_featured_categories(config())
    assert value['title'] == 'Featured categories'
    assert value['items'][0]['badge'] == ''
    assert stored_featured_categories(json.dumps(value)) == value
    assert validate_featured_categories(config(enabled=False, items=[]))['enabled'] is False
    assert stored_featured_categories('{broken') is None

@pytest.mark.parametrize('invalid', [
    {'version': True}, {'title': ' '}, {'enabled': 'yes'}, {'items': [{'categoryId': 'x'}] * 7}, {'items': [{'categoryId': 'x'}, {'categoryId': 'x'}]},
    *[{'items': [{'categoryId': 'x', 'badge': badge}]} for badge in ['LIVE', '#1 MOST ORDERED', '20% OFF']],
    *[{'items': [{'categoryId': 'x', 'image': image}]} for image in ['javascript:alert(1)', 'http://example.test/img.png', '/%2e%2e/image.png', '//example.test/img.png', 'https://user:password@example.test/img.png']],
])
def test_invalid_curation_cannot_be_saved(invalid):
    with pytest.raises(CampaignValidationError): validate_featured_categories(config(**invalid))

@pytest.fixture
def endpoint(monkeypatch):
    app = FastAPI()
    app.include_router(route.router, prefix='/api')
    state = {'user': {'role': 'SUPER_ADMIN'}, 'rows': {}, 'writes': [], 'categories': [SimpleNamespace(id='snacks', slug='snacks', name='Snacks', parentId=None)]}
    async def execute(statement):
        entity = statement.column_descriptions[0]['entity']
        if entity is DarkStore:
            target = list(statement.compile().params.values())[0]
            return SimpleNamespace(scalar_one_or_none=lambda: None if target == 'missing' else target)
        if entity is Category: return SimpleNamespace(scalars=lambda: SimpleNamespace(all=lambda: state['categories']))
        assert entity is StoreSetting
        keys = list(statement.compile().params.values())[0]
        return SimpleNamespace(all=lambda: [SimpleNamespace(key=key, value=value) for key, value in state['rows'].items() if key in keys])
    db = SimpleNamespace(execute=execute)
    async def db_dep(): yield db
    async def admin(): return state['user']
    async def write(_db, entries):
        state['writes'].append(entries)
        state['rows'].update({key: json.dumps(value) for key, value in entries.items()})
    app.dependency_overrides[get_db] = db_dep
    app.dependency_overrides[route.require_campaign_admin] = admin
    monkeypatch.setattr(route, 'upsert_campaign_settings', write)
    monkeypatch.setattr(route, 'invalidate_campaign_caches', AsyncMock())
    return app, state

@pytest.mark.asyncio
async def test_scoped_editor_read_save_inheritance_and_global_isolation(endpoint):
    app, state = endpoint
    state['rows']['featured_categories'] = json.dumps(config())
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test') as client:
        assert (await client.get('/api/admin/featured-categories?storeId=hub-one')).json()['inherited'] is True
        response = await client.put('/api/admin/featured-categories', json={'storeId': 'hub-one', 'config': config(title='Weekend picks')})
        assert response.status_code == 200
        assert list(state['writes'][0]) == ['store:hub-one:featured_categories']
        assert 'title' not in json.loads(state['rows']['featured_categories'])
        scoped = await client.get('/api/admin/featured-categories?storeId=hub-one')
        assert scoped.json()['config']['title'] == 'Weekend picks'
        assert scoped.json()['inherited'] is False
        assert scoped.headers['cache-control'].startswith('no-store')

@pytest.mark.asyncio
async def test_scopes_malformed_and_non_grocery_references_fail_without_writes(endpoint):
    app, state = endpoint
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test') as client:
        state['user'] = {'role': 'ADMIN', 'assignedStoreId': 'hub-one'}
        assert (await client.put('/api/admin/featured-categories', json={'storeId': 'hub-two', 'config': config()})).status_code == 403
        assert (await client.put('/api/admin/featured-categories', json={'storeId': 'all', 'config': config()})).status_code == 403
        assert (await client.put('/api/admin/featured-categories', content='{broken')).status_code == 400
        state['user'] = {'role': 'SUPER_ADMIN'}
        assert (await client.put('/api/admin/featured-categories', json={'storeId': 'missing', 'config': config()})).status_code == 404
        state['categories'][0].parentId = 'parent'
        assert (await client.put('/api/admin/featured-categories', json={'config': config()})).status_code == 422
        state['categories'] = []
        assert (await client.put('/api/admin/featured-categories', json={'config': config()})).status_code == 422
        assert state['writes'] == []

@pytest.mark.asyncio
async def test_identity_headers_cannot_authorize_editor():
    app = FastAPI()
    app.include_router(route.router, prefix='/api')
    db = SimpleNamespace(execute=AsyncMock())
    async def db_dep(): yield db
    app.dependency_overrides[get_db] = db_dep
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test') as client:
        assert (await client.put('/api/admin/featured-categories', json={'config': config()}, headers={'x-user-id': 'admin', 'x-user-role': 'SUPER_ADMIN'})).status_code == 401
    db.execute.assert_not_awaited()
