import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from httpx import AsyncClient, ASGITransport
from main import app

@pytest.mark.asyncio
async def test_root_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "docs" in data

@pytest.mark.asyncio
async def test_health_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.asyncio
async def test_auth_refresh_no_token():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post("/api/auth/refresh", json={})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_auth_refresh_valid_token(prepare_database):
    from tests.conftest import TestingSessionLocal
    from models import User, Role
    from utils.jwt import create_access_token, decode_nextauth_jwt

    async with TestingSessionLocal() as session:
        user = User(
            id="test_refresh_user_1",
            email="refresh@test.com",
            phone="+919876543210",
            name="Refresh Test User",
            role=Role.USER.value,
            isBlocked=False,
        )
        session.add(user)
        await session.commit()

    token = create_access_token({
        "id": "test_refresh_user_1",
        "email": "refresh@test.com",
        "name": "Refresh Test User",
        "role": "USER",
    })

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post(
            "/api/auth/refresh",
            json={"refreshToken": token},
        )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "token" in data
    assert "refreshToken" in data
    assert data["user"]["id"] == "test_refresh_user_1"

