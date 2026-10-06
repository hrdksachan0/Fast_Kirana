import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from database import get_db
from unittest.mock import AsyncMock


@pytest.mark.asyncio
async def test_liveness_probe_healthz():
    """Verify /healthz liveness probe returns HTTP 200 with status healthy and probe liveness."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/healthz")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["probe"] == "liveness"
    assert "uptimeSeconds" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_liveness_probe_api_healthz():
    """Verify /api/healthz alias returns HTTP 200."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/api/healthz")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["probe"] == "liveness"


@pytest.mark.asyncio
async def test_readiness_probe_readyz_healthy():
    """Verify /readyz readiness probe returns HTTP 200 with DB pool status connected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/readyz")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ready"
    assert data["probe"] == "readiness"
    assert "checks" in data
    assert data["checks"]["database"]["status"] == "connected"
    assert data["checks"]["database"]["latencyMs"] is not None
    assert "redis" in data["checks"]


@pytest.mark.asyncio
async def test_readiness_probe_api_readyz():
    """Verify /api/readyz alias returns HTTP 200."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/api/readyz")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ready"
    assert data["checks"]["database"]["status"] == "connected"


@pytest.mark.asyncio
async def test_readiness_probe_database_failure_returns_503():
    """Verify /readyz returns HTTP 503 and not_ready when database connection fails."""
    async def failing_get_db():
        mock_session = AsyncMock()
        mock_session.execute.side_effect = Exception("Database connection pool timeout")
        yield mock_session

    original_override = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = failing_get_db
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            res = await ac.get("/readyz")
        assert res.status_code == 503
        data = res.json()
        assert data["status"] == "not_ready"
        assert data["checks"]["database"]["status"] == "disconnected"
        assert "Database connection pool timeout" in data["checks"]["database"]["error"]
    finally:
        if original_override:
            app.dependency_overrides[get_db] = original_override
        else:
            app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_probes_exempt_from_rate_limiting():
    """Ensure high-frequency probe polling does not get rate-limited with HTTP 429."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        for _ in range(15):
            res_live = await ac.get("/healthz")
            assert res_live.status_code == 200
            res_ready = await ac.get("/readyz")
            assert res_ready.status_code == 200
