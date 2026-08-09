import sys
import os
import asyncio
import pytest
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from httpx import AsyncClient, ASGITransport
from main import app
from utils.jwt import create_access_token

@pytest.mark.asyncio
async def test_all_api_routes():
    # Create test JWT headers for authenticated routes
    test_token = create_access_token({"id": "test_admin_id", "email": "admin@fastkirana.in", "role": "ADMIN"})
    auth_headers = {"Authorization": f"Bearer {test_token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Health check
        res_health = await ac.get("/health")
        assert res_health.status_code == 200
        print("[OK] /health PASSED:", res_health.json())

        # 2. Categories
        res_cat = await ac.get("/api/products/categories")
        assert res_cat.status_code == 200
        cats = res_cat.json()
        assert isinstance(cats, list)
        print(f"[OK] /api/products/categories PASSED: {len(cats)} categories found")

        # 3. Products
        res_prod = await ac.get("/api/products?limit=5")
        assert res_prod.status_code == 200
        prods = res_prod.json()
        assert isinstance(prods, list)
        print(f"[OK] /api/products PASSED: {len(prods)} products found")

        # 4. Delivery Wallet (Protected - requires auth)
        res_wallet = await ac.get("/api/delivery/wallet", headers=auth_headers)
        assert res_wallet.status_code == 200
        wallet_data = res_wallet.json()
        assert "wallet" in wallet_data
        print("[OK] /api/delivery/wallet PASSED:", wallet_data["wallet"])

        # 5. Admin Rider Cash Summary (Protected - requires admin auth)
        res_admin = await ac.get("/api/admin/rider-cash", headers=auth_headers)
        assert res_admin.status_code == 200
        admin_data = res_admin.json()
        assert "summary" in admin_data
        print("[OK] /api/admin/rider-cash PASSED:", admin_data["summary"])

        # 6. AI Demand Forecast (Protected - requires admin auth)
        res_forecast = await ac.get("/api/forecast/demand", headers=auth_headers)
        assert res_forecast.status_code == 200
        fc_data = res_forecast.json()
        assert "status" in fc_data
        print("[OK] /api/forecast/demand PASSED:", fc_data["status"])
