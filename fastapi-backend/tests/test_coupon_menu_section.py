import pytest
import uuid
from httpx import AsyncClient, ASGITransport
from datetime import datetime, timezone, timedelta
from tests.conftest import TestingSessionLocal
from main import app
from models import Coupon


@pytest.mark.asyncio
async def test_menu_section_flat_coupon_validation():
    # 1. Create a menu-section flat coupon (e.g. FLAT50 on "pizza")
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=str(uuid.uuid4()),
            code="PIZZA50",
            discountType="FLAT",
            value=50.0,
            minOrder=150.0,
            menuSection="pizza",
            isActive=True,
            expiresAt=datetime.now(timezone.utc) + timedelta(days=5),
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Cart with matching pizza (₹200) + non-matching beverage (₹100) -> total subtotal ₹300
        payload = {
            "code": "PIZZA50",
            "subtotal": 300.0,
            "items": [
                {
                    "id": "prod_pizza_1",
                    "name": "Margherita Pizza",
                    "price": 200.0,
                    "quantity": 1,
                    "menuSection": "Pizzas",
                    "tags": ["pizza", "veg"],
                },
                {
                    "id": "prod_coke_1",
                    "name": "Coca Cola Can",
                    "price": 100.0,
                    "quantity": 1,
                    "menuSection": "Beverages",
                    "tags": ["beverage", "drink"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["coupon"]["discountAmount"] == 50.0
        assert data["coupon"]["code"] == "PIZZA50"


@pytest.mark.asyncio
async def test_menu_section_percent_coupon_only_discounts_eligible_items():
    # 20% off on burgers, minOrder 100
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=str(uuid.uuid4()),
            code="BURGER20",
            discountType="PERCENT",
            value=20.0,
            minOrder=100.0,
            menuSection="burger",
            isActive=True,
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # ₹200 burger + ₹300 cake -> total ₹500, but only ₹200 is burger.
        # 20% of ₹200 is ₹40 (NOT 20% of ₹500 = ₹100).
        payload = {
            "code": "BURGER20",
            "subtotal": 500.0,
            "items": [
                {
                    "id": "prod_b1",
                    "name": "Veg Whopper",
                    "price": 200.0,
                    "quantity": 1,
                    "menuSection": "Burgers",
                    "tags": ["burger"],
                },
                {
                    "id": "prod_d1",
                    "name": "Chocolate Pastry",
                    "price": 300.0,
                    "quantity": 1,
                    "menuSection": "Desserts",
                    "tags": ["dessert", "sweet"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["coupon"]["discountAmount"] == 40.0


@pytest.mark.asyncio
async def test_menu_section_min_order_failed_when_total_cart_is_high_but_section_is_low():
    # Min order ₹250 in pasta section
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=str(uuid.uuid4()),
            code="PASTAOFF",
            discountType="FLAT",
            value=40.0,
            minOrder=250.0,
            menuSection="pasta",
            isActive=True,
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Cart total is ₹600, but pasta is only ₹150 (< ₹250)
        payload = {
            "code": "PASTAOFF",
            "subtotal": 600.0,
            "items": [
                {
                    "id": "prod_pasta_1",
                    "name": "Arrabiata Pasta",
                    "price": 150.0,
                    "quantity": 1,
                    "menuSection": "Pasta",
                    "tags": ["pasta"],
                },
                {
                    "id": "prod_drink_1",
                    "name": "Cold Coffee Shake",
                    "price": 450.0,
                    "quantity": 1,
                    "menuSection": "Beverages",
                    "tags": ["beverage", "shake"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 400
        assert "Minimum order of ₹250.00 in the 'pasta' menu section is required" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_menu_section_no_matching_items_rejected():
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=str(uuid.uuid4()),
            code="SANDWICH50",
            discountType="FLAT",
            value=50.0,
            minOrder=100.0,
            menuSection="sandwich",
            isActive=True,
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Cart has only pizza and beverage, 0 sandwiches
        payload = {
            "code": "SANDWICH50",
            "subtotal": 400.0,
            "items": [
                {
                    "id": "prod_p1",
                    "name": "Farmhouse Pizza",
                    "price": 300.0,
                    "quantity": 1,
                    "menuSection": "Pizza",
                    "tags": ["pizza"],
                },
                {
                    "id": "prod_c1",
                    "name": "Soda",
                    "price": 100.0,
                    "quantity": 1,
                    "menuSection": "Beverages",
                    "tags": ["beverage"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 400
        assert "This coupon is only valid for items in the 'sandwich' menu section" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_menu_section_multi_section_matching():
    # Coupon applies to both pizza AND burger
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=str(uuid.uuid4()),
            code="FASTFOOD30",
            discountType="PERCENT",
            value=10.0,
            minOrder=200.0,
            menuSection="pizza,burger",
            isActive=True,
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # ₹150 pizza + ₹120 burger + ₹100 ice cream -> Fast food subtotal = ₹270
        # 10% of ₹270 is ₹27.0
        payload = {
            "code": "FASTFOOD30",
            "subtotal": 370.0,
            "items": [
                {
                    "id": "prod_p1",
                    "name": "Paneer Pizza",
                    "price": 150.0,
                    "quantity": 1,
                    "menuSection": "Pizzas",
                    "tags": ["pizza"],
                },
                {
                    "id": "prod_b1",
                    "name": "Aloo Tikki Burger",
                    "price": 120.0,
                    "quantity": 1,
                    "menuSection": "Burgers",
                    "tags": ["burger"],
                },
                {
                    "id": "prod_i1",
                    "name": "Vanilla Ice Cream",
                    "price": 100.0,
                    "quantity": 1,
                    "menuSection": "Desserts",
                    "tags": ["icecream", "dessert"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["coupon"]["discountAmount"] == 27.0


@pytest.mark.asyncio
async def test_menu_section_id_matching():
    """Verify coupon configured with specific Section ID (e.g. sec_pizza_mu2pffns) matches product tags and section ID."""
    sec_id = "sec_pizza_mu2pffns"
    async with TestingSessionLocal() as session:
        coupon = Coupon(
            id=f"cpn_secid_{uuid.uuid4().hex[:8]}",
            code="PIZZAID50",
            discountType="FLAT",
            value=50.0,
            minOrder=100.0,
            menuSection=sec_id,
            isActive=True,
        )
        session.add(coupon)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "code": "PIZZAID50",
            "subtotal": 250.0,
            "items": [
                {
                    "id": "prod_sec_p1",
                    "name": "Special Cheese Pizza",
                    "price": 250.0,
                    "quantity": 1,
                    "menuSectionId": sec_id,
                    "tags": [sec_id, "pizza", "restaurant"],
                }
            ]
        }
        resp = await ac.post("/api/coupons/validate", json=payload)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["coupon"]["discountAmount"] == 50.0
        assert data["coupon"]["code"] == "PIZZAID50"
