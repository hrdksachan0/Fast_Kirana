import pytest
from starlette.testclient import TestClient
from main import app
from utils.cache import get_cached, set_cached, invalidate_catalog_cache


def test_gzip_compression_on_large_responses():
    """Verify GZipMiddleware compresses HTTP payloads >= 1000 bytes when client supports gzip."""
    client = TestClient(app)

    # 1. Request with Accept-Encoding: gzip
    response = client.get("/api/categories", headers={"Accept-Encoding": "gzip"})
    assert response.status_code == 200

    # If the payload is >= 1000 bytes, Starlette compresses it with gzip
    if len(response.content) >= 1000 or "content-encoding" in response.headers:
        assert response.headers.get("content-encoding") == "gzip"


def test_catalog_categories_multi_tier_cache_headers():
    """Verify /api/categories sets Cache-Control and X-FastKirana-Cache HIT/MISS headers."""
    client = TestClient(app)

    # 1. First request
    res1 = client.get("/api/categories")
    assert res1.status_code == 200
    assert "cache-control" in res1.headers
    assert "public" in res1.headers["cache-control"]
    assert res1.headers.get("x-fastkirana-cache") in ["MISS", "HIT"]

    # 2. Second request should hit memory/Redis cache
    res2 = client.get("/api/categories")
    assert res2.status_code == 200
    assert res2.headers.get("x-fastkirana-cache") == "HIT"


def test_banners_cache_headers():
    """Verify /api/banners sets Cache-Control and X-FastKirana-Cache headers."""
    client = TestClient(app)

    res1 = client.get("/api/banners")
    assert res1.status_code == 200
    assert "cache-control" in res1.headers
    assert res1.headers.get("x-fastkirana-cache") in ["MISS", "HIT"]


@pytest.mark.asyncio
async def test_catalog_invalidation_clears_all_patterns():
    """Verify invalidate_catalog_cache clears catalog, products, product_detail, categories, and banners."""
    await set_cached("products:test", {"data": 1}, 60)
    await set_cached("product_detail:123:all", {"data": 2}, 60)
    await set_cached("categories:test", {"data": 3}, 60)
    await set_cached("banners:test", {"data": 4}, 60)

    # Verify keys are set
    assert await get_cached("products:test") is not None
    assert await get_cached("product_detail:123:all") is not None

    # Invalidate all catalog caches
    await invalidate_catalog_cache()

    # All should now be None
    assert await get_cached("products:test") is None
    assert await get_cached("product_detail:123:all") is None
    assert await get_cached("categories:test") is None
    assert await get_cached("banners:test") is None
