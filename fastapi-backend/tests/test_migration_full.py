import sys
import os
import pytest
from httpx import AsyncClient, ASGITransport

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from utils.jwt import create_access_token


@pytest.mark.asyncio
async def test_full_migration_suite():
    admin_token = create_access_token({
        "id": "test_admin_user",
        "email": "admin@fastkirana.in",
        "role": "ADMIN"
    })
    auth_headers = {"Authorization": f"Bearer {admin_token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Root & Health
        r = await client.get("/")
        assert r.status_code == 200
        assert r.json()["status"] == "online"

        r = await client.get("/health")
        assert r.status_code == 200
        assert r.json()["status"] == "healthy"

        # 2. Categories (Read-Only)
        r = await client.get("/api/categories")
        assert r.status_code == 200
        data = r.json()
        assert isinstance(data, list)
        print(f"\n[PASS] Categories count: {len(data)}")

        # 3. Banners (Read-Only)
        r = await client.get("/api/banners")
        assert r.status_code == 200
        banners = r.json()
        assert isinstance(banners, (list, dict))
        print("[PASS] Banners response verified")

        # 4. Restaurants (Read-Only)
        r = await client.get("/api/restaurants")
        assert r.status_code == 200
        restaurants = r.json()
        assert isinstance(restaurants, list)
        print(f"[PASS] Restaurants count: {len(restaurants)}")

        # 5. Cart (Phase 2)
        r = await client.get("/api/cart")
        assert r.status_code == 200
        cart_data = r.json()
        assert cart_data.get("success") is True
        print("[PASS] Cart empty state verified")

        # 6. Coupons List (Phase 2)
        r = await client.get("/api/coupons")
        assert r.status_code == 200
        coupons = r.json()
        assert isinstance(coupons, list)
        print(f"[PASS] Active coupons count: {len(coupons)}")

        # 7. Coupons Validation (Phase 2)
        r = await client.post("/api/coupons/validate", json={
            "code": "BOGO",
            "subtotal": 150.0,
            "items": [{"restaurantId": "REST-104", "price": 150.0, "quantity": 1}]
        })
        assert r.status_code in [200, 400]  # Valid if BOGO exists, 400 with clean message if not
        print("[PASS] Coupon validation response verified:", r.status_code)

        # 8. Cashfree Create Order (Phase 1)
        r = await client.post("/api/payment/cashfree/create-order", json={
            "amount": 10.0,
            "customerPhone": "9876543210",
            "customerName": "Test Customer"
        })
        assert r.status_code == 200
        cf_data = r.json()
        assert cf_data.get("success") is True
        assert "paymentSessionId" in cf_data
        print("[PASS] Cashfree order creation session:", cf_data.get("orderId"))

        # 9. Cashfree Verify (Phase 1)
        cf_order_id = cf_data.get("cfOrderId") or cf_data.get("orderId")
        r = await client.post("/api/payment/cashfree/verify", json={
            "cfOrderId": cf_order_id
        })
        assert r.status_code == 200
        verify_data = r.json()
        assert "paymentStatus" in verify_data
        print("[PASS] Cashfree verify checked successfully, status:", verify_data.get("paymentStatus"))

        # 10. KOT Kitchen Thermal Print Broadcast (Phase 1)
        r = await client.post("/api/kot-broadcast", json={
            "orderId": "test_migration_kot_1",
            "readableId": "FK-TEST-1",
            "restaurantId": "REST-104",
            "kotText": "FASTKIRANA KOT UNIT TEST"
        })
        assert r.status_code == 200
        kot_data = r.json()
        assert kot_data.get("success") is True
        print("[PASS] KOT broadcast verified:", kot_data)

        # 11. Store Settings (Read-Only)
        r = await client.get("/settings")
        assert r.status_code == 200
        print("[PASS] Store settings verified")

        # 12. Authenticated Admin Route
        r = await client.get("/api/admin/rider-cash", headers=auth_headers)
        assert r.status_code == 200
        print("[PASS] Admin rider cash reconciliation verified")

        # 13. AI Demand Forecast Route
        r = await client.get("/api/forecast/demand", headers=auth_headers)
        assert r.status_code == 200
        print("[PASS] AI Demand forecasting verified")
