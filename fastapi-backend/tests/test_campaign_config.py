"""Campaign contract and endpoint checks; all persistence is isolated/mocked."""

from copy import deepcopy
from datetime import datetime, timezone, timedelta
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
import jwt
import httpx
import pytest

from database import get_db
from routers import campaigns
from services.campaign_config import (
    CampaignValidationError, DRAFT_KEY, PUBLISHED_KEY, parse_stored_campaign,
    resolve_admin_store, select_published, setting_key, upsert_campaign_settings,
    validate_campaign, validate_image,
)


@pytest.fixture
def config():
    source = Path(__file__).resolve().parents[2] / "public" / "navratri" / "navratri.json"
    return json.loads(source.read_text(encoding="utf-8"))


def test_defaults_and_generic_empty_navigation(config):
    config["navigation"] = []
    result = validate_campaign(config)
    assert result["enabled"] is True
    assert result["autoplay"] is True
    assert result["decorationImage"] == "string-lights.svg"
    assert result["labels"]["demoLabel"]
    assert len(result["categories"]) == 4
    assert result["composition"] == "template"
    assert result["blocks"] == []


@pytest.mark.parametrize("kind,presentation", [("banner", "wide"), ("categories", "grid"), ("categories", "row"), ("spotlight", "wide"), ("spotlight", "offer"), ("collection", "row"), ("collection", "grid"), ("image", "wide"), ("text", "plain")])
def test_block_composition_round_trips_without_mutating_source(config, kind, presentation):
    block = {"id": "custom-block", "type": kind, "presentation": presentation,
             "title": "Weekend collection", "motion": {"preset": "float", "speed": "slow"}}
    if kind == "collection":
        block["tabId"] = config["tabs"][0]["id"]
    if kind == "image":
        block["image"] = "https://example.test/weekend.webp"
    if kind == "text":
        block["motion"]["preset"] = "slide"
    config.update(composition="blocks", blocks=[block])
    original = deepcopy(config)
    normalized = validate_campaign(config)
    assert normalized["composition"] == "blocks"
    assert normalized["blocks"][0]["enabled"] is True
    assert normalized["blocks"][0]["motion"] == block["motion"]
    assert parse_stored_campaign(json.dumps(normalized)) == normalized
    assert config == original


@pytest.mark.parametrize("change", [
    {"type": "unsupported"}, {"presentation": "offer"}, {"enabled": "true"},
    {"itemIds": ["missing"]}, {"itemIds": ["missing", "missing"]},
    {"destinationId": "missing"}, {"tabId": "missing"}, {"tabId": {}},
    {"image": "javascript:alert(1)"}, {"motion": {"preset": "unsupported"}},
    {"motion": {"speed": "very-fast"}}, {"motion": {"script": "alert(1)"}},
    {"title": "a" * 201}, {"body": "a" * 501}, {"unknown": True},
])
def test_invalid_blocks_cannot_be_published(config, change):
    config.update(composition="blocks", blocks=[{"id": "custom", "type": "banner", "presentation": "wide", **change}])
    with pytest.raises(CampaignValidationError, match="blocks"):
        validate_campaign(config)


@pytest.mark.parametrize("blocks", [[], [{"id": "hidden", "type": "banner", "enabled": False}],
    [{"id": "same", "type": "banner"}, {"id": "same", "type": "banner"}],
    [{"id": f"block-{index}", "type": "banner"} for index in range(17)]])
def test_empty_duplicate_or_oversized_compositions_are_rejected(config, blocks):
    config.update(composition="blocks", blocks=blocks)
    with pytest.raises(CampaignValidationError, match="blocks"):
        validate_campaign(config)


def test_live_blocks_require_catalogue_links_only_for_displayed_slots(config):
    config.update(demo=False, composition="blocks", blocks=[{"id": "image", "type": "image", "image": "chunri.svg"}])
    assert validate_campaign(config)["demo"] is False
    slot = config["products"][1]
    config["blocks"] = [{"id": "spotlight", "type": "spotlight", "itemIds": [slot["id"]]}]
    with pytest.raises(CampaignValidationError, match="productId"):
        validate_campaign(config)
    slot["productId"] = "catalogue-sku"
    assert validate_campaign(config)["composition"] == "blocks"


@pytest.mark.parametrize("layout", ["classic", "banner", "split", "grid", "deals"])
def test_campaign_layout_survives_validation_and_storage(config, layout):
    config["layout"] = layout
    normalized = validate_campaign(config)
    assert normalized["layout"] == layout
    assert parse_stored_campaign(json.dumps(normalized))["layout"] == layout


def test_legacy_campaign_uses_classic_layout_without_mutating_input(config):
    config.pop("layout", None)
    assert validate_campaign(config)["layout"] == "classic"
    assert "layout" not in config


@pytest.mark.parametrize("layout", [None, "carousel", "CLASSIC", 1, [], {}])
def test_unknown_campaign_layouts_are_rejected(config, layout):
    config["layout"] = layout
    with pytest.raises(CampaignValidationError, match="layout"):
        validate_campaign(config)


@pytest.mark.parametrize("template", ["diwali", "holi", "ramadan", "daily-essentials", "value-picks", "summer", "monsoon"])
def test_bundled_templates_are_accepted_by_publish_contract(template):
    source = Path(__file__).resolve().parents[2] / "public" / "navratri" / "templates" / f"{template}.json"
    config = json.loads(source.read_text(encoding="utf-8"))
    result = validate_campaign(config)
    assert result == {**config, "composition": "template", "blocks": []}
    assert result["demo"] is True


@pytest.mark.parametrize("image", ["javascript:alert(1)", "data:image/svg+xml;base64,abc", "http://example.com/a.png", "//example.com/a.png", "../a.svg", "/assets/../a.svg", "/assets/%2e%2e/a.svg", "https://user:password@example.com/a.png", "https://example.com/\na.svg"])
def test_unsafe_image_sources_rejected(image):
    with pytest.raises(CampaignValidationError):
        validate_image(image)


@pytest.mark.parametrize("image", ["dandiya.svg", "/brand/campaign.webp", "https://example.com/image.png?width=400", "hero.avif"])
def test_valid_local_and_https_images(image):
    assert validate_image(image) == image


@pytest.mark.parametrize("mutate", [
    lambda config: config["timings"].update(headerMs=100),
    lambda config: config["timings"].update(crossfadeMs=1500),
    lambda config: config["products"][0].update(price=-1),
    lambda config: config["products"][0].update(price=float("nan")),
    lambda config: config["products"][0].update(price=999, originalPrice=1),
    lambda config: config["products"][0].update(destinationId="missing"),
    lambda config: config["products"][0].update(categoryId="missing"),
    lambda config: config["headers"].append(deepcopy(config["headers"][0])),
    lambda config: config.update(categories=config["categories"][:3]),
    lambda config: config.update(tabs=[]),
    lambda config: config.update(demo=False),
    lambda config: config.update(appearance={"background": "red"}),
    lambda config: config.update(unexpected="ignored-but-unsafe"),
    lambda config: config["headers"][0].pop("image"),
])
def test_invalid_campaign_rejected(config, mutate):
    mutate(config)
    with pytest.raises(CampaignValidationError):
        validate_campaign(config)


def test_live_campaign_requires_every_catalogue_reference(config):
    config["demo"] = False
    for index, product in enumerate(config["products"]):
        product["productId"] = f"catalogue-product-{index}"
    assert validate_campaign(config)["demo"] is False
    del config["products"][-1]["productId"]
    with pytest.raises(CampaignValidationError, match="productId"):
        validate_campaign(config)


def test_public_selection_never_reads_draft_and_disabled_scope_blocks_fallback(config):
    draft = {**config, "headers": [{**config["headers"][0], "title": "PRIVATE DRAFT"}]}
    rows = {DRAFT_KEY: json.dumps(draft)}
    assert select_published(rows, None) is None
    rows[PUBLISHED_KEY] = json.dumps(config)
    scoped = {**config, "enabled": False}
    rows[setting_key(PUBLISHED_KEY, "hub-one")] = json.dumps(scoped)
    assert select_published(rows, "hub-one")["enabled"] is False
    assert select_published(rows, "hub-two")["headers"][0]["title"] != "PRIVATE DRAFT"
    rows[setting_key(PUBLISHED_KEY, "hub-one")] = "invalid-json"
    assert select_published(rows, "hub-one") is None
    assert parse_stored_campaign("{broken") is None


@pytest.mark.parametrize("requested", ["hub-two", "all", "ALL", ""])
def test_branch_admin_cannot_select_another_or_global_scope(requested):
    with pytest.raises(PermissionError):
        resolve_admin_store({"role": "ADMIN", "assignedStoreId": "hub-one"}, requested)


def test_admin_scope_defaults_to_assignment_and_root_can_select_store():
    assert resolve_admin_store({"role": "ADMIN", "assignedStoreId": "hub-one"}) == "hub-one"
    assert resolve_admin_store({"role": "ADMIN", "email": "admin@fastkirana.com"}, "hub-two") == "hub-two"
    assert resolve_admin_store({"role": "SUPER_ADMIN"}, "all") is None
    with pytest.raises(PermissionError):
        resolve_admin_store({"role": "USER"}, "hub-one")


@pytest.mark.asyncio
async def test_publish_storage_is_one_upsert_and_commit(config):
    db = SimpleNamespace(
        get_bind=lambda: SimpleNamespace(dialect=SimpleNamespace(name="postgresql")),
        execute=AsyncMock(), commit=AsyncMock(),
    )
    await upsert_campaign_settings(db, {DRAFT_KEY: config, PUBLISHED_KEY: config})
    assert db.execute.await_count == 1
    assert db.commit.await_count == 1
    statement = db.execute.await_args.args[0]
    assert "ON CONFLICT" in str(statement)
    assert "homepage_campaign" not in str(statement)  # Bound values, never interpolated SQL.
    db.execute.side_effect = RuntimeError("write failed")
    db.commit.reset_mock()
    with pytest.raises(RuntimeError):
        await upsert_campaign_settings(db, {PUBLISHED_KEY: config})
    db.commit.assert_not_awaited()


@pytest.fixture
def endpoint_app(monkeypatch):
    app = FastAPI()
    app.include_router(campaigns.router, prefix="/api")
    rows = {}
    state = {"user": {"role": "ADMIN", "id": "test-admin", "email": "admin@fastkirana.com"}, "writes": []}
    async def user():
        identity = state["user"]
        if identity is None:
            raise HTTPException(status_code=401, detail="Authentication required")
        if identity.get("role") not in ("ADMIN", "SUPER_ADMIN"):
            raise HTTPException(status_code=403, detail="Admin access required")
        return identity
    async def db():
        yield SimpleNamespace(execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: "hub-one")))
    async def read(_db, store_id, *, include_draft=False):
        keys = {PUBLISHED_KEY, setting_key(PUBLISHED_KEY, store_id)}
        if include_draft:
            keys.add(setting_key(DRAFT_KEY, store_id))
        return {key: value for key, value in rows.items() if key in keys}
    async def write(_db, entries):
        state["writes"].append(deepcopy(entries))
        rows.update({key: json.dumps(value) for key, value in entries.items()})
    app.dependency_overrides[campaigns.require_campaign_admin] = user
    app.dependency_overrides[get_db] = db
    monkeypatch.setattr(campaigns, "read_campaign_settings", read)
    monkeypatch.setattr(campaigns, "upsert_campaign_settings", write)
    monkeypatch.setattr(campaigns, "invalidate_campaign_caches", AsyncMock())
    return app, rows, state


@pytest.mark.asyncio
async def test_endpoint_draft_isolation_publish_and_disable(config, endpoint_app):
    app, rows, _ = endpoint_app
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.put("/api/admin/campaign", json={"action": "save-draft", "campaign": config})
        assert response.status_code == 200
        assert DRAFT_KEY in rows and PUBLISHED_KEY not in rows
        assert (await client.get("/api/homepage-campaign")).json() == {"campaign": None}
        assert (await client.get("/api/admin/campaign")).json()["draft"] is not None
        response = await client.put("/api/admin/campaign", json={"action": "publish", "campaign": config})
        assert response.status_code == 200
        assert rows[DRAFT_KEY] == rows[PUBLISHED_KEY]
        assert (await client.get("/api/homepage-campaign")).json()["campaign"]["demo"] is True
        response = await client.put("/api/admin/campaign", json={"action": "disable"})
        assert response.status_code == 200
        assert json.loads(rows[DRAFT_KEY])["enabled"] is True
        assert (await client.get("/api/homepage-campaign")).json()["campaign"]["enabled"] is False
        assert response.headers["cache-control"].startswith("no-store")


@pytest.mark.asyncio
async def test_endpoints_reject_auth_scope_and_malformed_inputs(config, endpoint_app):
    app, _, state = endpoint_app
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        state["user"] = None
        assert (await client.get("/api/admin/campaign")).status_code == 401
        state["user"] = {"role": "USER", "id": "test-user"}
        assert (await client.put("/api/admin/campaign", json={"action": "publish", "campaign": config})).status_code == 403
        state["user"] = {"role": "ADMIN", "assignedStoreId": "hub-one"}
        assert (await client.get("/api/admin/campaign?storeId=hub-two")).status_code == 403
        assert (await client.put("/api/admin/campaign", json={"action": "publish", "storeId": "all", "campaign": config})).status_code == 403
        assert (await client.put("/api/admin/campaign", content="{broken", headers={"Content-Type": "application/json"})).status_code == 400
        assert (await client.put("/api/admin/campaign", json={"action": "publish"})).status_code == 422
        assert (await client.put("/api/admin/campaign", json={"action": "publish", "campaign": {}})).status_code == 422
        assert not state["writes"]


@pytest.mark.asyncio
async def test_scoped_admin_read_does_not_leak_global_draft(config, endpoint_app):
    app, rows, state = endpoint_app
    rows[DRAFT_KEY] = json.dumps(config)
    rows[PUBLISHED_KEY] = json.dumps(config)
    state["user"] = {"role": "ADMIN", "assignedStoreId": "hub-one"}
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        assert (await client.get("/api/admin/campaign")).json() == {"draft": None, "published": None}
        public = (await client.get("/api/homepage-campaign?storeId=hub-one")).json()["campaign"]
        assert public is not None
        assert (await client.put("/api/admin/campaign", json={"action": "disable"})).status_code == 200
        assert json.loads(rows[PUBLISHED_KEY]).get("enabled", True) is True
        assert (await client.get("/api/homepage-campaign?storeId=hub-one")).json()["campaign"]["enabled"] is False


def signed_credentials(monkeypatch, **claims):
    secret = "campaign-testing-auth-secret-not-production"
    monkeypatch.setenv("AUTH_SECRET", secret)
    payload = {"id": "real-admin", "role": "SUPER_ADMIN", "assignedStoreId": "hub-old", "exp": datetime.now(timezone.utc) + timedelta(minutes=5), **claims}
    token = jwt.encode(payload, secret, algorithm="HS256")
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def current_account(**overrides):
    return SimpleNamespace(
        **{"id": "real-admin", "role": "ADMIN", "email": "current@example.com", "phone": None,
           "assignedStoreId": "hub-current", "assignedRestaurantId": None,
           "isBlocked": False, "deletedAt": None, **overrides}
    )


@pytest.mark.asyncio
async def test_campaign_auth_rejects_missing_bearer_without_user_lookup():
    db = SimpleNamespace(execute=AsyncMock())
    with pytest.raises(HTTPException) as error:
        await campaigns.require_campaign_admin(None, db)
    assert error.value.status_code == 401
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_campaign_auth_refreshes_signed_role_and_store(monkeypatch):
    credentials = signed_credentials(monkeypatch)
    db = SimpleNamespace(execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: current_account())))
    identity = await campaigns.require_campaign_admin(credentials, db)
    assert identity["role"] == "ADMIN"
    assert identity["assignedStoreId"] == "hub-current"
    assert identity["email"] == "current@example.com"
    db.execute.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("account,status", [(current_account(role="USER"), 403), (current_account(isBlocked=True), 403), (current_account(deletedAt=datetime.now(timezone.utc)), 401), (None, 401)])
async def test_campaign_auth_rejects_revoked_blocked_deleted_accounts(monkeypatch, account, status):
    credentials = signed_credentials(monkeypatch)
    db = SimpleNamespace(execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: account)))
    with pytest.raises(HTTPException) as error:
        await campaigns.require_campaign_admin(credentials, db)
    assert error.value.status_code == status


@pytest.mark.asyncio
async def test_campaign_auth_expired_forged_and_idless_tokens_do_not_query_users(monkeypatch):
    db = SimpleNamespace(execute=AsyncMock())
    expired = signed_credentials(monkeypatch, exp=1)
    idless = signed_credentials(monkeypatch, id=None)
    forged = HTTPAuthorizationCredentials(scheme="Bearer", credentials=jwt.encode({"id": "real-admin", "exp": datetime.now(timezone.utc) + timedelta(minutes=5)}, "wrong-testing-secret-with-at-least-32-bytes", algorithm="HS256"))
    for credentials in (expired, idless, forged):
        with pytest.raises(HTTPException) as error:
            await campaigns.require_campaign_admin(credentials, db)
        assert error.value.status_code == 401
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_campaign_endpoint_ignores_identity_headers_even_with_internal_secret(monkeypatch):
    monkeypatch.setenv("INTERNAL_API_SECRET", "isolated-test-internal-secret")
    app = FastAPI()
    app.include_router(campaigns.router, prefix="/api")
    db = SimpleNamespace(execute=AsyncMock())
    async def fake_db():
        yield db
    app.dependency_overrides[get_db] = fake_db
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        headers = {"x-user-id": "real-admin", "x-user-role": "ADMIN", "x-user-email": "admin@fastkirana.com", "x-internal-secret": "isolated-test-internal-secret"}
        assert (await client.get("/api/admin/campaign", headers=headers)).status_code == 401
        assert (await client.put("/api/admin/campaign", headers=headers, json={"action": "disable"})).status_code == 401
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_campaign_auth_database_outage_and_missing_secret_fail_closed(monkeypatch):
    credentials = signed_credentials(monkeypatch)
    db = SimpleNamespace(execute=AsyncMock(side_effect=RuntimeError("database unavailable")))
    with pytest.raises(HTTPException) as error:
        await campaigns.require_campaign_admin(credentials, db)
    assert error.value.status_code == 503
    monkeypatch.delenv("AUTH_SECRET")
    db.execute.reset_mock()
    with pytest.raises(HTTPException) as error:
        await campaigns.require_campaign_admin(credentials, db)
    assert error.value.status_code == 503
    db.execute.assert_not_awaited()
