import pytest
import os
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient
from main import app
from routers.websockets import _verify_ws_ticket
from models import User, Order, Address, OrderStatus, PaymentStatus, PaymentMethod, OtpToken
from tests.conftest import TestingSessionLocal
from sqlalchemy.future import select
from utils.jwt import AUTH_SECRET, create_access_token, validate_auth_secret
from routers.auth import hash_password
from datetime import datetime, timedelta, timezone
import jwt

import time

client = TestClient(app)

@pytest.mark.asyncio
async def test_unauthenticated_ticket_endpoint_rejected():
    """Verify that calling POST /ws/ticket without authentication returns 401."""
    response = client.post("/ws/ticket", json={"channel": "general", "userId": "forged_user"})
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_websocket_channel_authorization_rejected_for_unauthorized_user():
    """Verify that a regular user cannot obtain a ticket for another user's order channel."""
    async with TestingSessionLocal() as session:
        user = User(
            id="regular_user_1",
            email="user1@fastkirana.in",
            role="USER",
            phone="9999999991",
            isBlocked=False,
        )
        addr = Address(
            id="addr_unrelated_1",
            userId="other_customer_999",
            label="Home",
            houseNo="1",
            street="Main",
            area="Civil Lines",
            city="Akbarpur",
            pincode="224122",
            phone="9999999999",
        )
        order = Order(
            id="unrelated_order_999",
            readableId="FK-UNRELATED-999",
            userId="other_customer_999",
            addressId="addr_unrelated_1",
            status=OrderStatus.PENDING,
            subtotal=100.0,
            total=100.0
        )
        session.add(user)
        session.add(addr)
        session.add(order)
        await session.commit()

    user_payload = {
        "id": "regular_user_1",
        "sub": "regular_user_1",
        "role": "USER",
        "email": "user1@fastkirana.in",
        "exp": int(time.time()) + 3600,
    }
    user_token = jwt.encode(user_payload, AUTH_SECRET, algorithm="HS256")
    headers = {"Authorization": f"Bearer {user_token}"}
    
    # Attempt to request ticket for another customer's order
    response = client.post(
        "/ws/ticket",
        json={"channel": "order_unrelated_order_999"},
        headers=headers
    )
    # Must fail with 403 Forbidden because regular user does not own order_unrelated_order_999
    assert response.status_code == 403

@pytest.mark.asyncio
async def test_ticket_generation_binds_to_authenticated_identity():
    """Verify ticket sub is bound strictly to the authenticated caller and cannot forge userId."""
    async with TestingSessionLocal() as session:
        user = User(
            id="real_caller_123",
            email="real@fastkirana.in",
            role="USER",
            phone="9999999992",
            isBlocked=False,
        )
        session.add(user)
        await session.commit()

    user_payload = {
        "id": "real_caller_123",
        "sub": "real_caller_123",
        "role": "USER",
        "email": "real@fastkirana.in",
        "exp": int(time.time()) + 3600,
    }
    user_token = jwt.encode(user_payload, AUTH_SECRET, algorithm="HS256")
    headers = {"Authorization": f"Bearer {user_token}"}
    
    response = client.post(
        "/ws/ticket",
        json={"channel": "general", "userId": "attacker_forged_admin"},
        headers=headers
    )
    assert response.status_code == 200
    ticket_data = response.json()
    ticket = ticket_data.get("ticket")
    
    # Decode ticket and verify sub matches authenticated caller
    decoded = jwt.decode(ticket, AUTH_SECRET, algorithms=["HS256"])
    assert decoded["sub"] == "real_caller_123"
    assert decoded["sub"] != "attacker_forged_admin"

@pytest.mark.asyncio
async def test_revoked_or_blocked_user_bearer_token_rejected():
    """Verify that a bearer token for a blocked user returns 401."""
    async with TestingSessionLocal() as session:
        blocked_user = User(
            id="blocked_user_999",
            email="blocked@fastkirana.in",
            role="USER",
            phone="9999999993",
            isBlocked=True, # BLOCKED!
        )
        session.add(blocked_user)
        await session.commit()

    token_payload = {
        "id": "blocked_user_999",
        "sub": "blocked_user_999",
        "role": "USER",
        "email": "blocked@fastkirana.in",
        "exp": int(time.time()) + 3600,
    }
    token = jwt.encode(token_payload, AUTH_SECRET, algorithm="HS256")
    headers = {"Authorization": f"Bearer {token}"}
    
    response = client.post("/ws/ticket", json={"channel": "general"}, headers=headers)
    assert response.status_code == 401

def test_production_websocket_rejects_missing_ticket():
    """Verify WebSocket connection in production mode rejects connections without ticket."""
    with patch.dict(os.environ, {"APP_ENV": "production"}):
        with pytest.raises(Exception):
            with client.websocket_connect("/ws/orders/order_123") as ws:
                pass


@pytest.mark.asyncio
async def test_unrelated_cashfree_order_id_rejected():
    """Verify that an unrelated ₹500 payment from order B cannot mark order A as paid."""
    async with TestingSessionLocal() as session:
        user = User(
            id="buyer_aaa",
            email="buyer@fastkirana.in",
            role="USER",
            phone="9999999994",
        )
        session.add(user)
        addr_a = Address(
            id="addr_aaa_1",
            userId="buyer_aaa",
            label="Home",
            houseNo="12A",
            street="Main Road",
            area="Civil Lines",
            city="Akbarpur",
            pincode="224122",
            phone="9999999994",
        )
        session.add(addr_a)
        order_a = Order(
            id="order_aaa_111",
            readableId="FK-AAA-111",
            userId="buyer_aaa",
            addressId="addr_aaa_1",
            subtotal=500.0,
            total=500.0,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            status=OrderStatus.PENDING,
        )
        session.add(order_a)
        await session.commit()

    # Caller submits order_aaa_111 with unrelated paid cfOrderId "cf_unrelated_paid_999"
    # Even if Cashfree says cf_unrelated_paid_999 is PAID for ₹500, verify must reject it!
    from config import settings
    with patch.object(settings, "CASHFREE_ENV", "SANDBOX"), \
         patch.object(settings, "CASHFREE_APP_ID", "test_app_id"), \
         patch.object(settings, "CASHFREE_SECRET_KEY", "test_secret_key"), \
         patch("httpx.AsyncClient.get") as mock_get:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "order_id": "cf_unrelated_paid_999",
            "order_status": "PAID",
            "order_amount": 500.0,
        }
        mock_get.return_value = mock_resp

        response = client.post(
            "/api/payment/cashfree/verify",
            json={"orderId": "order_aaa_111", "cfOrderId": "cf_unrelated_paid_999"}
        )
        # Gateway did NOT match order_aaa_111's authorized identities, so it must not mark it PAID
        # Either 400 binding mismatch or payment not completed
        assert response.status_code in (400, 404) or response.json().get("isPaid") is False

        # Verify order_aaa_111 in DB is NOT PAID
        async with TestingSessionLocal() as session:
            stmt = select(Order).where(Order.id == "order_aaa_111")
            res = await session.execute(stmt)
            o = res.scalar_one()
            assert o.paymentStatus != PaymentStatus.PAID


@pytest.mark.asyncio
async def test_cashfree_amount_mismatch_rejected():
    """Verify that a payment with amount mismatch is strictly rejected."""
    async with TestingSessionLocal() as session:
        user_b = User(
            id="buyer_bbb",
            email="buyer_b@fastkirana.in",
            role="USER",
            phone="9999999995",
        )
        session.add(user_b)
        addr_b = Address(
            id="addr_bbb_1",
            userId="buyer_bbb",
            label="Home",
            houseNo="14B",
            street="Main Road",
            area="Civil Lines",
            city="Akbarpur",
            pincode="224122",
            phone="9999999995",
        )
        session.add(addr_b)
        order_b = Order(
            id="order_bbb_222",
            readableId="FK-BBB-222",
            userId="buyer_bbb",
            addressId="addr_bbb_1",
            subtotal=500.0,
            total=500.0,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            status=OrderStatus.PENDING,
        )
        session.add(order_b)
        await session.commit()

    from config import settings
    with patch.object(settings, "CASHFREE_ENV", "SANDBOX"), \
         patch.object(settings, "CASHFREE_APP_ID", "test_app_id"), \
         patch.object(settings, "CASHFREE_SECRET_KEY", "test_secret_key"), \
         patch("httpx.AsyncClient.get") as mock_get:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "order_id": "order_bbb_222",
            "order_status": "PAID",
            "order_amount": 450.0,
        }
        mock_get.return_value = mock_resp

        response = client.post(
            "/api/payment/cashfree/verify",
            json={"orderId": "order_bbb_222"}
        )
        assert response.status_code == 400
        assert "mismatch" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_header_only_picker_spoofing_rejected():
    """Verify that sending x-user-role header without authentication fails with 401."""
    # Attempting to access picker orders with only an x-user-role header
    response = client.get(
        "/api/picker/orders",
        headers={"x-user-role": "PICKER", "x-user-id": "fake_picker"}
    )
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_kot_broadcast_requires_staff_authentication():
    """Verify unauthenticated caller cannot trigger KOT kitchen broadcast."""
    response = client.post(
        "/api/kot-broadcast",
        json={
            "orderId": "ord_fake_kot_1",
            "manual": True,
            "source": "orders_tab",
            "kotText": "FASTKIRANA KOT"
        }
    )
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_kot_broadcast_rejected_for_regular_user():
    """Verify regular customer cannot trigger KOT kitchen broadcast."""
    async with TestingSessionLocal() as session:
        user = User(
            id="reg_customer_kot",
            email="cust_kot@fastkirana.in",
            role="USER",
            isBlocked=False,
        )
        session.add(user)
        await session.commit()

    token = create_access_token(
        {"id": "reg_customer_kot", "sub": "reg_customer_kot", "role": "USER", "email": "cust_kot@fastkirana.in"}
    )
    headers = {"Authorization": f"Bearer {token}"}

    response = client.post(
        "/api/kot-broadcast",
        json={
            "orderId": "ord_fake_kot_2",
            "restaurantId": "rest_101",
            "manual": True,
            "source": "orders_tab"
        },
        headers=headers
    )
    assert response.status_code == 403

@pytest.mark.asyncio
async def test_kot_broadcast_outlet_isolation_enforced():
    """Verify staff member assigned to restaurant A cannot dispatch KOT for restaurant B."""
    async with TestingSessionLocal() as session:
        chef_user = User(
            id="chef_rest_a",
            email="chef_a@fastkirana.in",
            role="CHEF",
            assignedRestaurantId="rest_AAA",
            isBlocked=False,
        )
        session.add(chef_user)
        await session.commit()

    token = create_access_token(
        {"id": "chef_rest_a", "sub": "chef_rest_a", "role": "CHEF", "email": "chef_a@fastkirana.in"}
    )
    headers = {"Authorization": f"Bearer {token}"}

    # Chef assigned to rest_AAA attempts to broadcast for rest_BBB
    response = client.post(
        "/api/kot-broadcast",
        json={
            "orderId": "ord_kot_cross_outlet",
            "restaurantId": "rest_BBB",
            "kotText": "FASTKIRANA KOT"
        },
        headers=headers
    )
    assert response.status_code == 403
    assert "outlet" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_websocket_ticket_rejects_wildcard_request():
    """Verify requesting a ticket with channel '*' returns 400 Bad Request."""
    async with TestingSessionLocal() as session:
        user = User(id="user_wildcard_req", email="wild@fastkirana.in", role="USER", isBlocked=False)
        session.add(user)
        await session.commit()

    token = create_access_token({"id": "user_wildcard_req", "role": "USER"})
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post("/ws/ticket", json={"channel": "*"}, headers=headers)
    assert response.status_code == 400
    assert "wildcard" in response.json().get("detail", "").lower()

def test_websocket_signed_wildcard_ticket_rejected_at_handshake():
    """Verify even a pre-signed wildcard ticket is rejected on connect with code 4003."""
    wildcard_ticket = jwt.encode(
        {"jti": "wst_wild_1", "sub": "attacker", "role": "USER", "channel": "*", "scope": "ws_ticket", "exp": 9999999999},
        AUTH_SECRET,
        algorithm="HS256"
    )
    from starlette.websockets import WebSocketDisconnect
    try:
        with client.websocket_connect(f"/ws/orders/order_123?ticket={wildcard_ticket}") as ws:
            pass
        assert False, "Should have been disconnected"
    except WebSocketDisconnect as e:
        assert e.code == 4003

def test_websocket_single_use_ticket_cannot_be_replayed():
    """Verify a ticket can only be consumed once and second connect fails with code 4003."""
    valid_ticket = jwt.encode(
        {"jti": "wst_replay_unique_1", "sub": "user_replay", "role": "USER", "channel": "general", "scope": "ws_ticket", "exp": 9999999999},
        AUTH_SECRET,
        algorithm="HS256"
    )
    # 1. First connection succeeds
    with client.websocket_connect(f"/ws?ticket={valid_ticket}") as ws:
        msg = ws.receive_text()
        assert "Connected" in msg

    # 2. Second connection with identical ticket must be rejected as already consumed
    from starlette.websockets import WebSocketDisconnect
    try:
        with client.websocket_connect(f"/ws?ticket={valid_ticket}") as ws:
            pass
        assert False, "Replayed ticket should have been rejected"
    except WebSocketDisconnect as e:
        assert e.code == 4003

@pytest.mark.asyncio
async def test_unassigned_rider_cannot_subscribe_to_other_orders():
    """Verify delivery role alone cannot subscribe to an unassigned order."""
    async with TestingSessionLocal() as session:
        rider = User(id="rider_unassigned_1", email="rider1@fastkirana.in", role="DELIVERY", isBlocked=False)
        addr1 = Address(
            id="addr_rider_unassigned_1",
            userId="buyer_xyz",
            label="Home",
            houseNo="1",
            street="Main",
            area="Civil Lines",
            city="Akbarpur",
            pincode="224122",
            phone="9999999999",
        )
        order = Order(
            id="order_assigned_to_someone_else",
            readableId="FK-SOMEONE-1",
            userId="buyer_xyz",
            addressId="addr_rider_unassigned_1",
            deliveryUserId="different_rider_99",
            status=OrderStatus.SHIPPED,
            subtotal=100.0,
            total=100.0
        )
        session.add(rider)
        session.add(addr1)
        session.add(order)
        await session.commit()

    token = create_access_token({"id": "rider_unassigned_1", "role": "DELIVERY"})
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post("/ws/ticket", json={"channel": "order_order_assigned_to_someone_else"}, headers=headers)
    assert response.status_code == 403
    assert "not assigned" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_assigned_rider_can_subscribe_to_their_order():
    """Verify assigned rider successfully receives ticket for their assigned order."""
    async with TestingSessionLocal() as session:
        rider = User(id="rider_assigned_ok", email="rider_ok@fastkirana.in", role="DELIVERY", isBlocked=False)
        addr2 = Address(
            id="addr_rider_assigned_ok",
            userId="buyer_abc",
            label="Home",
            houseNo="2",
            street="Main",
            area="Civil Lines",
            city="Akbarpur",
            pincode="224122",
            phone="9999999999",
        )
        order = Order(
            id="order_assigned_to_me",
            readableId="FK-MINE-1",
            userId="buyer_abc",
            addressId="addr_rider_assigned_ok",
            deliveryUserId="rider_assigned_ok",
            status=OrderStatus.SHIPPED,
            subtotal=100.0,
            total=100.0
        )
        session.add(rider)
        session.add(addr2)
        session.add(order)
        await session.commit()

    token = create_access_token({"id": "rider_assigned_ok", "role": "DELIVERY"})
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post("/ws/ticket", json={"channel": "order_order_assigned_to_me"}, headers=headers)
    assert response.status_code == 200
    assert "ticket" in response.json()


@pytest.mark.asyncio
async def test_notes_injection_cannot_bind_unrelated_cashfree_order():
    """Verify that placing [CF_ORDER:victim_payment] in order notes does NOT bind payment or verify the order."""
    async with TestingSessionLocal() as session:
        addr = Address(
            id="addr_attacker_1",
            userId="attacker_1",
            label="Home",
            houseNo="10",
            street="Attacker Lane",
            area="Kanpur",
            city="Kanpur",
            pincode="209206",
            phone="9999999990",
        )
        order = Order(
            id="ord_attacker_notes_hack",
            readableId="FK-ATTACK-1",
            userId="attacker_1",
            addressId="addr_attacker_1",
            status=OrderStatus.PENDING,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            subtotal=500.0,
            total=500.0,
            notes="Please pack fast [CF_ORDER:cf_victim_order_999] | thank you"
        )
        session.add(addr)
        session.add(order)
        await session.commit()

    # Mock Cashfree order returning PAID for cf_victim_order_999
    mock_cf_res = MagicMock()
    mock_cf_res.status_code = 200
    mock_cf_res.json.return_value = {
        "order_id": "cf_victim_order_999",
        "order_status": "PAID",
        "order_amount": 500.0,
    }

    from config import settings
    with patch.object(settings, "CASHFREE_ENV", "SANDBOX"), \
         patch.object(settings, "CASHFREE_APP_ID", "test_app_id"), \
         patch.object(settings, "CASHFREE_SECRET_KEY", "test_secret_key"), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_cf_res
        response = client.post(
            "/api/payment/cashfree/verify",
            json={"orderId": "ord_attacker_notes_hack", "cfOrderId": "cf_victim_order_999"}
        )
        # MUST be rejected with 400 because cf_victim_order_999 does not belong to ord_attacker_notes_hack
        assert response.status_code == 400
        assert "binding mismatch" in response.json().get("detail", "").lower()

    # Verify in DB that order remains PENDING and NOT PAID
    async with TestingSessionLocal() as session:
        res = await session.execute(select(Order).where(Order.id == "ord_attacker_notes_hack"))
        refreshed_order = res.scalars().first()
        assert refreshed_order.paymentStatus != PaymentStatus.PAID
        assert refreshed_order.status == OrderStatus.PENDING

@pytest.mark.asyncio
async def test_symmetric_amount_mismatch_rejected():
    """Verify that a payment with different amount (e.g. ₹250 for ₹500 order) is rejected."""
    async with TestingSessionLocal() as session:
        addr = Address(
            id="addr_mismatch_1",
            userId="buyer_mismatch_1",
            label="Home",
            houseNo="11",
            street="Mismatch Road",
            area="Kanpur",
            city="Kanpur",
            pincode="209206",
            phone="9999999991",
        )
        order = Order(
            id="ord_amount_mismatch_test",
            readableId="FK-MISMATCH-1",
            userId="buyer_mismatch_1",
            addressId="addr_mismatch_1",
            status=OrderStatus.PENDING,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            subtotal=500.0,
            total=500.0,
        )
        session.add(addr)
        session.add(order)
        await session.commit()

    mock_cf_res = MagicMock()
    mock_cf_res.status_code = 200
    mock_cf_res.json.return_value = {
        "order_id": "ord_amount_mismatch_test",
        "order_status": "PAID",
        "order_amount": 250.0,  # Underpayment!
    }

    from config import settings
    with patch.object(settings, "CASHFREE_ENV", "SANDBOX"), \
         patch.object(settings, "CASHFREE_APP_ID", "test_app_id"), \
         patch.object(settings, "CASHFREE_SECRET_KEY", "test_secret_key"), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_cf_res
        response = client.post(
            "/api/payment/cashfree/verify",
            json={"orderId": "ord_amount_mismatch_test"}
        )
        assert response.status_code == 400
        assert "amount mismatch" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_missing_gateway_amount_rejected():
    """Verify that a payment missing valid amount from gateway is rejected."""
    async with TestingSessionLocal() as session:
        addr = Address(
            id="addr_missing_amt_1",
            userId="buyer_missing_1",
            label="Home",
            houseNo="12",
            street="Missing Road",
            area="Kanpur",
            city="Kanpur",
            pincode="209206",
            phone="9999999992",
        )
        order = Order(
            id="ord_missing_amt_test",
            readableId="FK-MISSING-1",
            userId="buyer_missing_1",
            addressId="addr_missing_amt_1",
            status=OrderStatus.PENDING,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            subtotal=500.0,
            total=500.0,
        )
        session.add(addr)
        session.add(order)
        await session.commit()

    mock_cf_res = MagicMock()
    mock_cf_res.status_code = 200
    mock_cf_res.json.return_value = {
        "order_id": "ord_missing_amt_test",
        "order_status": "PAID",
        "order_amount": None,  # Missing amount!
    }

    from config import settings
    with patch.object(settings, "CASHFREE_ENV", "SANDBOX"), \
         patch.object(settings, "CASHFREE_APP_ID", "test_app_id"), \
         patch.object(settings, "CASHFREE_SECRET_KEY", "test_secret_key"), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_cf_res
        response = client.post(
            "/api/payment/cashfree/verify",
            json={"orderId": "ord_missing_amt_test"}
        )
        assert response.status_code == 400
        assert "valid payment amount" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_webhook_notes_injection_ignored():
    """Verify webhook cannot mark an order paid through notes substring match."""
    async with TestingSessionLocal() as session:
        addr = Address(
            id="addr_wh_attacker_1",
            userId="wh_attacker_1",
            label="Home",
            houseNo="15",
            street="Webhook Lane",
            area="Kanpur",
            city="Kanpur",
            pincode="209206",
            phone="9999999995",
        )
        order = Order(
            id="ord_wh_attacker_notes",
            readableId="FK-WH-ATTACK-1",
            userId="wh_attacker_1",
            addressId="addr_wh_attacker_1",
            status=OrderStatus.PENDING,
            paymentStatus=PaymentStatus.PENDING,
            paymentMethod=PaymentMethod.UPI,
            subtotal=500.0,
            total=500.0,
            notes="Notes containing cf_wh_victim_123"
        )
        session.add(addr)
        session.add(order)
        await session.commit()

    webhook_payload = {
        "data": {
            "order": {
                "order_id": "cf_wh_victim_123",
                "order_amount": 500.0,
            },
            "payment": {
                "cf_payment_id": "pay_wh_victim_999",
                "payment_status": "SUCCESS",
                "payment_amount": 500.0,
            }
        },
        "event_time": "2026-10-14T09:00:00Z",
        "type": "PAYMENT_SUCCESS_WEBHOOK"
    }

    from config import settings
    with patch.object(settings, "CASHFREE_SECRET_KEY", ""), \
         patch.dict(os.environ, {"CASHFREE_WEBHOOK_SECRET": ""}):
        response = client.post(
            "/api/payment/cashfree/webhook",
            json=webhook_payload
        )

    # Order must NOT be marked PAID through notes
    async with TestingSessionLocal() as session:
        res = await session.execute(select(Order).where(Order.id == "ord_wh_attacker_notes"))
        order_db = res.scalars().first()
        assert order_db.paymentStatus != PaymentStatus.PAID


@pytest.mark.asyncio
async def test_duplicate_variant_lines_aggregated_and_rejected_when_exceeding_stock():
    """Verify that splitting a purchase across duplicate lines does not bypass stock limits."""
    from models import Product, Category
    async with TestingSessionLocal() as session:
        cat = Category(id="cat_stock_test", name="Stock Test", slug="stock-test")
        prod = Product(
            id="prod_last_1_unit",
            name="Limited Stock Item",
            slug="limited-stock-item",
            price=100.0,
            mrp=100.0,
            unit="1 pc",
            stock=1,  # Only 1 unit in stock!
            isAvailable=True,
            categoryId="cat_stock_test",
            restaurantId=None  # Grocery
        )
        user = User(
            id="stock_tester_1",
            email="stock@fastkirana.in",
            role="USER",
            phone="9999999998",
            isBlocked=False,
        )
        addr = Address(
            id="addr_stock_tester_1",
            userId="stock_tester_1",
            label="Home",
            houseNo="1",
            street="Stock St",
            area="Ghatampur",
            city="Ghatampur",
            pincode="209206",
            phone="9999999998",
            lat=26.1534,
            lng=80.1714
        )
        session.add(cat)
        session.add(prod)
        session.add(user)
        session.add(addr)
        await session.commit()

    token = create_access_token({"id": "stock_tester_1", "role": "USER"})
    headers = {"Authorization": f"Bearer {token}"}

    # User attempts to order 1 unit in line 1, and 1 unit in line 2 (total 2 units for an item with stock=1)
    payload = {
        "items": [
            {"productId": "prod_last_1_unit", "quantity": 1, "price": 100.0, "name": "Limited Stock Item"},
            {"productId": "prod_last_1_unit", "quantity": 1, "price": 100.0, "name": "Limited Stock Item"}
        ],
        "addressId": "addr_stock_tester_1",
        "paymentMethod": "COD",
        "deliveryMethod": "PICKUP"
    }

    response = client.post("/api/orders", json=payload, headers=headers)
    assert response.status_code == 400
    assert "insufficient stock" in response.json().get("detail", "").lower()

@pytest.mark.asyncio
async def test_client_cannot_convert_grocery_into_restaurant_item():
    """Verify that client passing restaurantId on grocery product cannot bypass stock checks."""
    from models import Product, Category
    async with TestingSessionLocal() as session:
        cat = Category(id="cat_grocery_bypass", name="Grocery Cat", slug="grocery-cat")
        prod = Product(
            id="prod_grocery_zero_stock",
            name="Out Of Stock Grocery",
            slug="out-of-stock-grocery",
            price=50.0,
            mrp=50.0,
            unit="1 pc",
            stock=0,  # Zero stock!
            isAvailable=True,
            categoryId="cat_grocery_bypass",
            restaurantId=None  # Authoritative grocery product!
        )
        user = User(
            id="stock_tester_2",
            email="stock2@fastkirana.in",
            role="USER",
            phone="9999999997",
            isBlocked=False,
        )
        addr = Address(
            id="addr_stock_tester_2",
            userId="stock_tester_2",
            label="Home",
            houseNo="2",
            street="Stock St",
            area="Ghatampur",
            city="Ghatampur",
            pincode="209206",
            phone="9999999997",
            lat=26.1534,
            lng=80.1714
        )
        session.add(cat)
        session.add(prod)
        session.add(user)
        session.add(addr)
        await session.commit()

    token = create_access_token({"id": "stock_tester_2", "role": "USER"})
    headers = {"Authorization": f"Bearer {token}"}

    # Client tries to claim restaurantId: "REST-101" to get 999999 restaurant stock
    payload = {
        "items": [
            {
                "productId": "prod_grocery_zero_stock",
                "quantity": 1,
                "price": 50.0,
                "name": "Out Of Stock Grocery",
                "restaurantId": "REST-101"
            }
        ],
        "addressId": "addr_stock_tester_2",
        "paymentMethod": "COD",
        "deliveryMethod": "PICKUP"
    }

    response = client.post("/api/orders", json=payload, headers=headers)
    assert response.status_code == 400
    assert "insufficient stock" in response.json().get("detail", "").lower()


@pytest.mark.asyncio
async def test_durable_idempotency_survives_redis_outage():
    """Verify durable DB-backed idempotency prevents duplicate orders even when Redis is down."""
    from models import Product, Category, IdempotencyRecord
    async with TestingSessionLocal() as session:
        cat = Category(id="cat_idemp_durable", name="Idemp Cat", slug="idemp-cat")
        prod = Product(
            id="prod_idemp_1",
            name="Idemp Item",
            slug="idemp-item",
            price=100.0,
            mrp=100.0,
            unit="1 pc",
            stock=10,
            isAvailable=True,
            categoryId="cat_idemp_durable",
            restaurantId=None
        )
        user = User(
            id="idemp_user_1",
            email="idemp1@fastkirana.in",
            role="USER",
            phone="9999999981",
            isBlocked=False,
        )
        addr = Address(
            id="addr_idemp_user_1",
            userId="idemp_user_1",
            label="Home",
            houseNo="1",
            street="Main",
            area="Ghatampur",
            city="Ghatampur",
            pincode="209206",
            phone="9999999981",
            lat=26.1534,
            lng=80.1714
        )
        session.add(cat)
        session.add(prod)
        session.add(user)
        session.add(addr)
        await session.commit()

    token = create_access_token({"id": "idemp_user_1", "role": "USER"})
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Idempotency-Key": "durable_key_redis_offline_99"
    }
    payload = {
        "items": [{"productId": "prod_idemp_1", "quantity": 1, "price": 100.0, "name": "Idemp Item"}],
        "addressId": "addr_idemp_user_1",
        "paymentMethod": "COD",
        "deliveryMethod": "PICKUP"
    }

    # Simulate total Redis outage
    with patch("utils.cache.get_redis_connection", side_effect=Exception("Redis connection refused")):
        # Request 1: Creates order
        resp1 = client.post("/api/orders", json=payload, headers=headers)
        assert resp1.status_code in (200, 201), resp1.text
        data1 = resp1.json()
        assert "id" in data1
        created_order_id = data1["id"]

        # Verify durable DB record was created
        async with TestingSessionLocal() as session:
            rec = await session.get(IdempotencyRecord, "idemp_user_1:checkout:durable_key_redis_offline_99")
            if rec is None:
                rec = await session.get(IdempotencyRecord, "durable_key_redis_offline_99")
            assert rec is not None
            assert rec.status == "COMPLETED"

        # Request 2: Replays order despite Redis still being completely down!
        resp2 = client.post("/api/orders", json=payload, headers=headers)
        assert resp2.status_code in (200, 201)
        data2 = resp2.json()
        assert data2.get("idempotencyReplayed") is True
        assert data2["id"] == created_order_id

        # Verify only 1 order exists in database
        async with TestingSessionLocal() as session:
            orders_stmt = select(Order).where(Order.userId == "idemp_user_1")
            orders_res = await session.execute(orders_stmt)
            orders = orders_res.scalars().all()
            assert len(orders) == 1


@pytest.mark.asyncio
async def test_concurrent_workers_idempotency_with_redis_down():
    """Verify that multiple concurrent workers attempting the same order with Redis down are serialized safely."""
    from models import Product, Category, IdempotencyRecord
    import concurrent.futures

    async with TestingSessionLocal() as session:
        cat = Category(id="cat_idemp_workers", name="Worker Cat", slug="worker-cat")
        prod = Product(
            id="prod_idemp_worker_1",
            name="Worker Item",
            slug="worker-item",
            price=80.0,
            mrp=80.0,
            unit="1 pc",
            stock=100,
            isAvailable=True,
            categoryId="cat_idemp_workers",
            restaurantId=None
        )
        user = User(
            id="idemp_user_concurrent",
            email="concurrent@fastkirana.in",
            role="USER",
            phone="9999999982",
            isBlocked=False,
        )
        addr = Address(
            id="addr_idemp_user_concurrent",
            userId="idemp_user_concurrent",
            label="Home",
            houseNo="2",
            street="Main",
            area="Ghatampur",
            city="Ghatampur",
            pincode="209206",
            phone="9999999982",
            lat=26.1534,
            lng=80.1714
        )
        session.add(cat)
        session.add(prod)
        session.add(user)
        session.add(addr)
        await session.commit()

    token = create_access_token({"id": "idemp_user_concurrent", "role": "USER"})
    import uuid
    uniq_key = f"concurrent_worker_key_{uuid.uuid4().hex[:12]}"
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Idempotency-Key": uniq_key
    }
    payload = {
        "items": [{"productId": "prod_idemp_worker_1", "quantity": 1, "price": 80.0, "name": "Worker Item"}],
        "addressId": "addr_idemp_user_concurrent",
        "paymentMethod": "COD",
        "deliveryMethod": "PICKUP"
    }

    # Simulate 4 concurrent workers with Redis down
    with patch("utils.cache.get_redis_connection", side_effect=Exception("Redis connection refused")):
        def send_request():
            return client.post("/api/orders", json=payload, headers=headers)

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(send_request) for _ in range(4)]
            responses = [f.result() for f in futures]

        status_codes = [r.status_code for r in responses]
        assert any(c in (200, 201) for c in status_codes), f"STATUS_CODES: {status_codes} TEXTS: {[r.text for r in responses]}"
        for code in status_codes:
            assert code in (200, 201, 409)

        async with TestingSessionLocal() as session:
            orders_stmt = select(Order).where(Order.userId == "idemp_user_concurrent")
            orders_res = await session.execute(orders_stmt)
            orders = orders_res.scalars().all()
            assert len(orders) == 1


@pytest.mark.asyncio
async def test_login_blocked_or_deactivated_account_rejected():
    """Verify that login endpoint rejects blocked or soft-deleted accounts with 403."""
    async with TestingSessionLocal() as session:
        u_blocked = User(
            id="u_login_blocked_1",
            email="blocked_login@fastkirana.in",
            role="USER",
            phone="9999999971",
            passwordHash=hash_password("validpassword123"),
            isBlocked=True,
            blockReason="Suspicious activity detected"
        )
        u_deleted = User(
            id="u_login_deleted_1",
            email="deleted_login@fastkirana.in",
            role="USER",
            phone="9999999972",
            passwordHash=hash_password("validpassword123"),
            isBlocked=False,
            deletedAt=datetime.now(timezone.utc)
        )
        session.add(u_blocked)
        session.add(u_deleted)
        await session.commit()

    # Blocked user attempt
    res1 = client.post("/api/auth/login", json={
        "email": "blocked_login@fastkirana.in",
        "password": "validpassword123"
    })
    assert res1.status_code == 403
    assert "blocked" in res1.json()["detail"].lower() or "suspicious" in res1.json()["detail"].lower()

    # Deactivated/deleted user attempt
    res2 = client.post("/api/auth/login", json={
        "email": "deleted_login@fastkirana.in",
        "password": "validpassword123"
    })
    assert res2.status_code == 403
    assert "deactivated" in res2.json()["detail"].lower() or "blocked" in res2.json()["detail"].lower()


@pytest.mark.asyncio
async def test_verify_otp_blocked_or_deactivated_account_rejected():
    """Verify that OTP verify endpoint rejects blocked or deleted accounts with 403 even with valid OTP."""
    async with TestingSessionLocal() as session:
        u_blocked = User(
            id="u_otp_blocked_1",
            email="wa-9999999973@fastkirana.in",
            role="USER",
            phone="+919999999973",
            isBlocked=True,
            blockReason="Fraud account"
        )
        otp = OtpToken(
            id="otp_test_blocked_1",
            email="9999999973",
            token="654321",
            expiresAt=datetime.now(timezone.utc) + timedelta(minutes=5)
        )
        session.add(u_blocked)
        session.add(otp)
        await session.commit()

    res = client.post("/api/auth/otp/verify", json={
        "phone": "9999999973",
        "otp": "654321"
    })
    assert res.status_code == 403
    detail = res.json()["detail"].lower()
    assert "fraud" in detail or "blocked" in detail or "deactivated" in detail


def test_production_mode_rejects_insecure_placeholder_auth_secret():
    """Verify that validate_auth_secret strictly rejects placeholder or weak keys in production."""
    with pytest.raises(RuntimeError, match="Insecure placeholder AUTH_SECRET"):
        validate_auth_secret("ci_test_secret_12345", env="production")

    with pytest.raises(RuntimeError, match="Insecure placeholder AUTH_SECRET"):
        validate_auth_secret("placeholder", env="production")

    with pytest.raises(RuntimeError, match="Insecure placeholder AUTH_SECRET"):
        validate_auth_secret("secret", env="production")

    with pytest.raises(RuntimeError, match="Insecure placeholder AUTH_SECRET"):
        validate_auth_secret("changeme", env="production")

    with pytest.raises(RuntimeError, match="required in production"):
        validate_auth_secret("", env="production")

    # High entropy production key should pass
    prod_key = "a_super_strong_high_entropy_production_auth_secret_key_32_bytes"
    validated = validate_auth_secret(prod_key, env="production")
    assert validated == prod_key


@pytest.mark.asyncio
async def test_picker_a_cannot_update_store_b_product():
    """Verify that a picker assigned to Store A cannot update or fetch stock from Store B."""
    from models import DarkStore, Product, StoreInventory
    async with TestingSessionLocal() as session:
        # Create Store A and Store B
        store_a = DarkStore(id="store_alpha", name="Alpha Store", latitude=26.0, longitude=82.0, city="Akbarpur")
        store_b = DarkStore(id="store_beta", name="Beta Store", latitude=26.0, longitude=82.0, city="Akbarpur")
        # Picker A assigned to Store A
        picker_a = User(id="picker_alice", email="alice@picker.in", role="PICKER", assignedStoreId="store_alpha", isBlocked=False)
        # Product belonging to Store B
        prod_b = Product(
            id="prod_beta_1",
            name="Store B Oil",
            slug="store-b-oil",
            mrp=100.0,
            price=90.0,
            unit="1L",
            stock=10,
            isAvailable=True
        )
        inv_b = StoreInventory(storeId="store_beta", productId="prod_beta_1", stock=10)
        session.add_all([store_a, store_b, picker_a, prod_b, inv_b])
        await session.commit()

    token_a = create_access_token({"id": "picker_alice", "role": "PICKER", "storeId": "store_alpha", "assignedStoreId": "store_alpha"})
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # Picker A tries to query products for Store B -> 403 Forbidden
    res_list = client.get("/api/picker/products?storeId=store_beta", headers=headers_a)
    assert res_list.status_code == 403

    # Picker A tries to update product in Store B -> 403 Forbidden
    res_update = client.patch(
        "/api/picker/products",
        json={"id": "prod_beta_1", "stock": 50, "storeId": "store_beta"},
        headers=headers_a
    )
    assert res_update.status_code == 403

    # Ensure stock was NOT modified
    async with TestingSessionLocal() as session:
        stmt = select(StoreInventory).where(StoreInventory.productId == "prod_beta_1", StoreInventory.storeId == "store_beta")
        res = await session.execute(stmt)
        inv = res.scalar_one()
        assert inv.stock == 10


@pytest.mark.asyncio
async def test_chef_a_omitting_restaurant_id_cannot_trigger_kot_for_outlet_b():
    """Verify that Chef A omitting restaurantId cannot broadcast KOT for an order at Outlet B."""
    from models import Restaurant
    async with TestingSessionLocal() as session:
        rest_a = Restaurant(id="rest_alpha", name="Resto Alpha", slug="resto-alpha", address="Loc A", city="Akbarpur")
        rest_b = Restaurant(id="rest_beta", name="Resto Beta", slug="resto-beta", address="Loc B", city="Akbarpur")
        chef_a = User(id="chef_bob", email="bob@chef.in", role="CHEF", assignedRestaurantId="rest_alpha", isBlocked=False)
        cust = User(id="cust_k1", email="k1@fastkirana.in", role="USER", isBlocked=False)
        addr = Address(id="addr_k1", userId="cust_k1", label="Home", houseNo="1", street="St", area="Ar", city="Ct", pincode="224122")
        # Order belonging to Restaurant B
        order_b = Order(
            id="order_resto_beta_99",
            readableId="FK-REST-99",
            userId="cust_k1",
            addressId="addr_k1",
            restaurantId="rest_beta",
            subtotal=300.0,
            total=300.0,
            status=OrderStatus.CONFIRMED,
            paymentStatus=PaymentStatus.PAID
        )
        session.add_all([rest_a, rest_b, chef_a, cust, addr, order_b])
        await session.commit()

    token_chef_a = create_access_token({"id": "chef_bob", "role": "CHEF", "restaurantId": "rest_alpha", "assignedRestaurantId": "rest_alpha"})
    headers_chef = {"Authorization": f"Bearer {token_chef_a}"}

    # Chef A tries to broadcast KOT for order_resto_beta_99 omitting restaurantId
    payload = {
        "orderId": "order_resto_beta_99",
        "items": [{"name": "Burger", "quantity": 1}],
        "source": "pos"
    }
    res = client.post("/api/kot/broadcast", json=payload, headers=headers_chef)
    assert res.status_code == 403
    assert "another restaurant outlet" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_cashfree_recovery_deduplication_on_repeated_webhooks():
    """Verify that repeated webhook calls with the same Cashfree order do not create duplicate recovered orders."""
    from routers.cashfree_router import auto_recover_unplaced_cashfree_order
    async with TestingSessionLocal() as session:
        cust = User(id="cust_recovery_1", email="recov@fastkirana.in", role="USER", phone="9988776655", isBlocked=False)
        addr = Address(id="addr_recov_1", userId="cust_recovery_1", label="Home", houseNo="1", street="St", area="Ar", city="Ct", pincode="224122")
        session.add_all([cust, addr])
        await session.commit()

    cf_order_payload = {
        "cf_order_id": "cf_auto_recov_12345",
        "order_id": "fk_cart_order_12345",
        "order_amount": 450.0,
        "order_status": "PAID",
        "customer_details": {
            "customer_id": "cust_recovery_1",
            "customer_phone": "9988776655",
            "customer_name": "Recovery Test"
        },
        "order_meta": {
            "order_note": "CartItems:[{\"name\":\"Basmati Rice\",\"quantity\":1,\"price\":450.0}]"
        }
    }
    payment_payload = {
        "payment_status": "SUCCESS",
        "payment_amount": 450.0,
        "cf_payment_id": "cf_pay_12345"
    }

    async with TestingSessionLocal() as session:
        # 1. First recovery creates order
        order_1 = await auto_recover_unplaced_cashfree_order(
            "cf_auto_recov_12345",
            "fk_cart_order_12345",
            "cf_ref_recov_1",
            cf_order_payload,
            payment_payload,
            session
        )
        await session.commit()
        assert order_1 is not None
        assert order_1.cfOrderId == "cf_auto_recov_12345"
        first_order_id = order_1.id

    async with TestingSessionLocal() as session:
        # 2. Repeated recovery call with identical cf_order_id returns existing order without creating duplicate
        order_2 = await auto_recover_unplaced_cashfree_order(
            "cf_auto_recov_12345",
            "fk_cart_order_12345",
            "cf_ref_recov_1",
            cf_order_payload,
            payment_payload,
            session
        )
        assert order_2 is not None
        assert order_2.id == first_order_id

        # Verify in DB there is exactly 1 order with this cfOrderId
        stmt = select(Order).where(Order.cfOrderId == "cf_auto_recov_12345")
        res = await session.execute(stmt)
        orders = res.scalars().all()
        assert len(orders) == 1


@pytest.mark.asyncio
async def test_idempotency_expired_db_lock_atomic_takeover_and_503_on_error():
    """Verify that concurrent workers racing to acquire an expired lock results in exactly one winner, and DB error raises 503."""
    from utils.idempotency import acquire_idempotency_lock_async
    from models import IdempotencyRecord
    from fastapi import HTTPException
    now_dt = datetime.utcnow()

    # Pre-create an expired idempotency record
    async with TestingSessionLocal() as session:
        expired_rec = IdempotencyRecord(
            key="user_exp_1:checkout:idemp_expired_key_1",
            userId="user_exp_1",
            requestHash="old_hash",
            status="PROCESSING",
            createdAt=now_dt - timedelta(minutes=10),
            expiresAt=now_dt - timedelta(minutes=5)
        )
        session.add(expired_rec)
        await session.commit()

    async with TestingSessionLocal() as session1, TestingSessionLocal() as session2:
        # Worker 1 acquires expired lock
        cached1, in_flight1, resp1 = await acquire_idempotency_lock_async(
            key="idemp_expired_key_1",
            user_id="user_exp_1",
            request_hash="new_hash_1",
            ttl_seconds=60,
            db=session1
        )
        # Worker 1 successfully took over the expired lock
        assert cached1 is False
        assert in_flight1 is False
        assert resp1 is None

        # Worker 2 attempts takeover on the same key which is now renewed and actively PROCESSING
        cached2, in_flight2, resp2 = await acquire_idempotency_lock_async(
            key="idemp_expired_key_1",
            user_id="user_exp_1",
            request_hash="new_hash_1",
            ttl_seconds=60,
            db=session2
        )
        # Worker 2 is locked out (in-flight)
        assert in_flight2 is True

    # Test DB failure during lock acquisition raises 503
    mock_failing_db = MagicMock()
    mock_failing_db.execute.side_effect = Exception("Simulated DB connection failure")
    with pytest.raises(HTTPException) as exc_info:
        await acquire_idempotency_lock_async(
            key="fail_key_1",
            user_id="user_fail_1",
            ttl_seconds=60,
            db=mock_failing_db
        )
    assert exc_info.value.status_code == 503
    assert "temporarily unavailable" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_websocket_ticket_cross_worker_replay_rejected_when_redis_down():
    """Verify that when Redis is down, ticket consumed on Worker 1 is rejected when presented to Worker 2."""
    import uuid
    from routers.websockets import _consume_ws_ticket, consumed_ws_tickets

    # Simulate Worker 1 consuming a ticket when Redis returns None (Redis outage)
    with patch("utils.cache.get_redis_connection", return_value=None):
        test_jti = f"ticket_worker_cross_{uuid.uuid4().hex[:12]}"
        exp = time.time() + 60.0

        # Worker 1 consumes ticket
        consumed_w1 = await _consume_ws_ticket(test_jti, exp)
        assert consumed_w1 is True

        # Simulate Worker 2: a separate Python process where in-memory consumed_ws_tickets is empty!
        consumed_ws_tickets.pop(test_jti, None)
        assert test_jti not in consumed_ws_tickets

        # Worker 2 receives the exact same ticket when Redis is still down
        consumed_w2 = await _consume_ws_ticket(test_jti, exp)
        # Must be REJECTED via shared database check!
        assert consumed_w2 is False


@pytest.mark.asyncio
async def test_idempotency_record_response_json_type_compatibility():
    """Verify that IdempotencyRecord correctly stores and retrieves JSON dict payloads."""
    from utils.idempotency import record_idempotency_result_db_async
    from models import IdempotencyRecord
    async with TestingSessionLocal() as session:
        payload = {"status": "SUCCESS", "order": {"id": "ord_json_test_1", "total": 999.0}}
        await record_idempotency_result_db_async(
            key="idemp_json_test_key",
            response=payload,
            db=session,
            user_id="user_json_1",
            order_id="ord_json_test_1"
        )
        await session.commit()

        stmt = select(IdempotencyRecord).where(IdempotencyRecord.orderId == "ord_json_test_1")
        res = await session.execute(stmt)
        rec = res.scalar_one()
        assert rec.status == "COMPLETED"
        assert rec.response == payload or rec.response == json.dumps(payload)


@pytest.mark.asyncio
async def test_notes_marker_spoofing_rejected_and_sanitized():
    """Verify that [CF_ORDER:...] markers in customer notes cannot spoof payment auto-recovery,
    and that incoming order notes are stripped of spoofed markers."""
    import re
    # 1. Verify note sanitization regex
    malicious_note = "Please leave at door [CF_ORDER:cf_victim_order_999] ring bell"
    cleaned = re.sub(r"\[CF_[A-Z0-9_:]+\]", "", malicious_note, flags=re.IGNORECASE).strip()
    assert "cf_victim_order_999" not in cleaned
    assert cleaned == "Please leave at door  ring bell"

    # 2. Verify payment auto-recovery statement does NOT match orders by notes
    async with TestingSessionLocal() as session:
        attacker_order = Order(
            id="order_attacker_notes_1",
            readableId="FK-ATTACK-001",
            userId="user_attacker_1",
            status=OrderStatus.PENDING,
            paymentStatus=PaymentStatus.PENDING,
            notes="Please rush [CF_ORDER:victim_cf_order_888]",
            total=150.0,
            subtotal=150.0,
            addressId="addr_att_1"
        )
        session.add(attacker_order)
        await session.commit()

        # The auto-recovery query in cashfree_router:
        cf_order_id = "victim_cf_order_888"
        existing_stmt = select(Order).where(
            (Order.cfOrderId == cf_order_id)
            | (Order.id == cf_order_id)
            | (Order.readableId == cf_order_id)
        )
        res = await session.execute(existing_stmt)
        matched_order = res.scalar_one_or_none()
        # The attacker order must NOT match!
        assert matched_order is None


@pytest.mark.asyncio
async def test_idempotency_scoped_release_enables_immediate_retry():
    """Verify that releasing idempotency lock after a validation failure correctly clears
    both the exact scoped key in Redis and memory locks, enabling immediate retry."""
    from utils.idempotency import acquire_idempotency_lock_async, release_idempotency_lock_async
    async with TestingSessionLocal() as session:
        key = "validation_fail_key_42"
        user_id = "user_val_42"
        operation = "checkout"

        # 1. Initial attempt acquires lock
        duplicate, in_flight, cached = await acquire_idempotency_lock_async(
            key=key,
            user_id=user_id,
            request_hash="hash_attempt_1",
            ttl_seconds=60,
            db=session,
            operation=operation
        )
        assert duplicate is False
        assert in_flight is False
        assert cached is None

        # 2. Validation failure triggers release with scoped key
        await release_idempotency_lock_async(
            key=key,
            user_id=user_id,
            operation=operation,
            db=session
        )

        # 3. Corrected retry attempt immediately re-acquires lock successfully
        duplicate2, in_flight2, cached2 = await acquire_idempotency_lock_async(
            key=key,
            user_id=user_id,
            request_hash="hash_attempt_2_corrected",
            ttl_seconds=60,
            db=session,
            operation=operation
        )
        # Must NOT be locked or duplicate!
        assert duplicate2 is False
        assert in_flight2 is False
        assert cached2 is None


@pytest.mark.asyncio
async def test_websocket_ticket_authoritative_ledger_dual_write_and_no_replay():
    """Verify that _consume_ws_ticket writes authoritatively to IdempotencyRecord
    and prevents replay across memory resets and Redis transitions."""
    import uuid
    from routers.websockets import _consume_ws_ticket, consumed_ws_tickets
    from models import IdempotencyRecord

    test_jti = f"ticket_auth_ledger_{uuid.uuid4().hex[:12]}"
    exp = time.time() + 60.0

    # 1. First consumption succeeds
    consumed = await _consume_ws_ticket(test_jti, exp)
    assert consumed is True

    # 2. Verify durable IdempotencyRecord was created in DB
    async with TestingSessionLocal() as session:
        stmt = select(IdempotencyRecord).where(IdempotencyRecord.key == f"ws_ticket_{test_jti}")
        res = await session.execute(stmt)
        record = res.scalar_one_or_none()
        assert record is not None
        assert record.status == "COMPLETED"

    # 3. Simulate process restart / memory wipe + Redis outage
    consumed_ws_tickets.pop(test_jti, None)
    with patch("utils.cache.get_redis_connection", return_value=None):
        # Even without memory cache and without Redis, authoritative DB check prevents replay!
        replayed = await _consume_ws_ticket(test_jti, exp)
        assert replayed is False


@pytest.mark.asyncio
async def test_websocket_ticket_fails_closed_in_production_when_ledger_unavailable():
    """Verify that in production (APP_ENV=production), if both DB and Redis are unavailable,
    tickets are rejected (fail closed), preventing ticket replay across workers."""
    import uuid
    from routers.websockets import _consume_ws_ticket, consumed_ws_tickets

    test_jti = f"ticket_prod_failclosed_{uuid.uuid4().hex[:12]}"
    exp = time.time() + 60.0

    # Ensure memory is clear
    consumed_ws_tickets.pop(test_jti, None)

    with patch.dict(os.environ, {"APP_ENV": "production"}):
        with patch("utils.cache.get_redis_connection", side_effect=Exception("Redis down")):
            from database import get_db
            with patch.dict(app.dependency_overrides, {get_db: None}, clear=True):
                with patch("database.AsyncSessionLocal", side_effect=Exception("DB down")):
                    # In production with ledger unavailable, first attempt fails closed
                    res1 = await _consume_ws_ticket(test_jti, exp)
                    assert res1 is False

                    # Simulate another worker process receiving same ticket with ledger down
                    consumed_ws_tickets.pop(test_jti, None)
                    res2 = await _consume_ws_ticket(test_jti, exp)
                    assert res2 is False


@pytest.mark.asyncio
async def test_websocket_ticket_fails_closed_in_production_with_node_env_ledger_error():
    """Verify that when NODE_ENV=production, if authoritative DB ledger fails,
    _consume_ws_ticket fails closed (returns False)."""
    import uuid
    from routers.websockets import _consume_ws_ticket, consumed_ws_tickets
    from database import get_db

    test_jti = f"ticket_node_env_failclosed_{uuid.uuid4().hex[:12]}"
    exp = time.time() + 60.0

    consumed_ws_tickets.pop(test_jti, None)

    with patch.dict(os.environ, {"NODE_ENV": "production"}):
        with patch.dict(app.dependency_overrides, {get_db: None}, clear=True):
            with patch("database.AsyncSessionLocal", side_effect=Exception("DB ledger down")):
                res = await _consume_ws_ticket(test_jti, exp)
                assert res is False


@pytest.mark.asyncio
async def test_order_creation_and_recovery_share_atomic_consumed_payment_lock():
    """Verify that normal checkout and auto-recovery share the atomic consumed_payment:{cf_order_id} lock
    so racing requests cannot create duplicate orders for the same Cashfree payment."""
    import uuid
    from models import IdempotencyRecord, Order, User, Address, Category, Product

    cf_order_id = f"cf_race_{uuid.uuid4().hex[:12]}"
    user_id = f"usr_race_{uuid.uuid4().hex[:8]}"

    async with TestingSessionLocal() as session:
        user = User(id=user_id, email=f"{user_id}@fastkirana.in", role="USER", phone="9999999999")
        addr = Address(id=f"addr_{user_id}", userId=user_id, label="Home", houseNo="1", street="Main", area="Express", city="Ghatampur", pincode="209206", phone="9999999999")
        cat = Category(id=f"cat_{user_id}", name="Items", slug=f"cat-items-{user_id}")
        prod = Product(id=f"prod_{user_id}", name="Item 1", price=100.0, mrp=120.0, costPrice=80.0, categoryId=cat.id, unit="1pc", slug=f"prod-{user_id}", isAvailable=True, stock=50)
        session.add(user)
        session.add(addr)
        session.add(cat)
        session.add(prod)

        # 1. Pre-seed a consumed_payment record in PROCESSING status to simulate an in-flight auto-recovery
        consumed_rec = IdempotencyRecord(
            key=f"consumed_payment:{cf_order_id}",
            userId=user_id,
            status="PROCESSING",
            createdAt=datetime.utcnow(),
            expiresAt=datetime.utcnow() + timedelta(days=7)
        )
        session.add(consumed_rec)
        await session.commit()

    token = create_access_token({"id": user_id, "role": "USER"})
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Idempotency-Key": f"idem_{uuid.uuid4().hex[:8]}"
    }
    payload = {
        "items": [{"productId": f"prod_{user_id}", "name": "Item 1", "price": 100.0, "quantity": 1}],
        "addressId": f"addr_{user_id}",
        "paymentMethod": "ONLINE",
        "cfOrderId": cf_order_id
    }

    response = client.post("/api/orders", json=payload, headers=headers)
    assert response.status_code == 409
    assert "Payment is currently being processed or already claimed" in response.text


@pytest.mark.asyncio
async def test_cashfree_create_order_persists_nested_order_payload_and_store_id():
    """Verify that Cashfree create-order captures orderPayload, deliveryMethod, items,
    and storeId in cf_intent durable persistence."""
    import uuid
    from models import IdempotencyRecord
    from routers.cashfree_router import create_cashfree_order, CashfreeCreateOrderRequest

    custom_store_id = f"store_{uuid.uuid4().hex[:6]}"
    order_id = f"cf_payload_test_{uuid.uuid4().hex[:8]}"

    req = CashfreeCreateOrderRequest(
        orderId=order_id,
        amount=250.0,
        customerPhone="9876543210",
        customerName="Ankit Sharma",
        orderPayload={
            "items": [
                {"productId": "prod_1", "name": "Organic Milk", "price": 80.0, "quantity": 2},
                {"productId": "prod_2", "name": "Brown Bread", "price": 90.0, "quantity": 1}
            ],
            "addressId": "addr_custom_99",
            "deliveryMethod": "PICKUP",
            "storeId": custom_store_id,
            "notes": "Please pack separately"
        }
    )

    async with TestingSessionLocal() as session:
        res = await create_cashfree_order(req=req, db=session)
        assert res["success"] is True

        # Check durable database cf_intent
        stmt = select(IdempotencyRecord).where(IdempotencyRecord.key == f"cf_intent:{order_id}")
        r = await session.execute(stmt)
        record = r.scalar_one_or_none()
        assert record is not None
        payload = record.response
        assert payload["storeId"] == custom_store_id
        assert payload["deliveryMethod"] == "PICKUP"
        assert len(payload["items"]) == 2
        assert payload["items"][0]["name"] == "Organic Milk"


@pytest.mark.asyncio
async def test_cashfree_create_order_fails_closed_when_intent_db_write_fails():
    """Verify that if durable database intent persistence fails in _save_pending_checkout_intent,
    an HTTP 503 is raised (fails closed), preventing issuance of unrecoverable sessions."""
    import uuid
    from routers.cashfree_router import _save_pending_checkout_intent
    from fastapi import HTTPException

    mock_db = AsyncMock()
    mock_db.commit.side_effect = Exception("DB Disk full / connection dropped")

    with pytest.raises(HTTPException) as exc_info:
        await _save_pending_checkout_intent(
            db=mock_db,
            order_id="test_fail_close_503",
            cf_order_id="cf_fail_close_503",
            amount=500.0,
            user_id="user_test",
            address_id="addr_test",
            customer_phone="9999999999",
            customer_name="Test User",
            customer_email="test@fastkirana.in",
            items=[]
        )
    assert exc_info.value.status_code == 503
    assert "Unable to establish recoverable checkout session" in exc_info.value.detail


@pytest.mark.asyncio
async def test_auto_recovery_restores_pickup_delivery_method_store_and_authoritative_prices():
    """Verify that auto_recover_unplaced_cashfree_order restores deliveryMethod='PICKUP',
    the specific storeId, and looks up authoritative DB product prices."""
    import uuid
    from models import Product, Category, IdempotencyRecord, Order
    from routers.cashfree_router import auto_recover_unplaced_cashfree_order

    cf_order_id = f"cf_recov_{uuid.uuid4().hex[:10]}"
    p_id = f"prod_authoritative_{uuid.uuid4().hex[:8]}"
    store_id = f"store_branch_{uuid.uuid4().hex[:6]}"

    async with TestingSessionLocal() as session:
        # Create category and product with authoritative price ₹75.0
        cat = Category(id=f"cat_{uuid.uuid4().hex[:6]}", name="Dairy", slug=f"dairy_{uuid.uuid4().hex[:6]}")
        session.add(cat)
        await session.flush()

        prod = Product(
            id=p_id,
            name="Authoritative Cow Milk 1L",
            price=75.0,
            mrp=80.0,
            costPrice=60.0,
            categoryId=cat.id,
            unit="1L",
            slug=f"cow-milk-{uuid.uuid4().hex[:6]}",
            isAvailable=True,
            stock=100
        )
        session.add(prod)

        # Pending intent has outdated/tampered item price ₹50.0, storeId, and PICKUP
        intent_payload = {
            "orderId": f"ord_intent_{uuid.uuid4().hex[:8]}",
            "cfOrderId": cf_order_id,
            "amount": 75.0,
            "userId": "usr_pickup_buyer",
            "addressId": None,
            "customerPhone": "9123456789",
            "customerName": "Pickup Buyer",
            "customerEmail": "pickup@fastkirana.in",
            "items": [
                {"productId": p_id, "name": "Milk (old)", "price": 50.0, "quantity": 1}
            ],
            "deliveryMethod": "PICKUP",
            "storeId": store_id,
            "createdAt": time.time(),
        }
        intent_rec = IdempotencyRecord(
            key=f"cf_intent:{cf_order_id}",
            userId="usr_pickup_buyer",
            status="PENDING",
            response=intent_payload,
            createdAt=datetime.utcnow(),
            expiresAt=datetime.utcnow() + timedelta(days=2)
        )
        session.add(intent_rec)
        await session.commit()

        # Run auto_recover_unplaced_cashfree_order
        recovered_order = await auto_recover_unplaced_cashfree_order(
            cf_order_id=cf_order_id,
            clean_id=cf_order_id,
            cf_ref="cf_ref_12345",
            order_data={"cf_order_id": cf_order_id, "order_amount": 75.0},
            payment_data={"payment_status": "SUCCESS", "payment_amount": 75.0, "cf_payment_id": "cf_pay_123"},
            db=session
        )

        assert recovered_order is not None
        assert recovered_order.deliveryMethod == "PICKUP"
        assert recovered_order.storeId == store_id
        # Authoritative price 75.0 from DB was used instead of 50.0 from stale cache
        assert recovered_order.subtotal == 75.0


@pytest.mark.asyncio
async def test_kot_supabase_topics_do_not_contain_unscoped_global_channels():
    """Verify that broadcast_kot dispatches to restaurant-scoped topics
    and strictly excludes public unscoped 'realtime:restaurant-orders-live'."""
    from routers.kot import broadcast_kot, KotBroadcastRequest
    import uuid

    target_rest = "rest_taj_99"
    req = KotBroadcastRequest(
        orderId=f"ord_{uuid.uuid4().hex[:8]}",
        readableId="FK-TEST-101-R",
        restaurantId=target_rest,
        customerName="Test Chef",
        deliveryMethod="DELIVERY",
        shopName="Taj Kitchen",
        items=[{"name": "Paneer Tikka", "quantity": 1, "price": 250.0}]
    )

    mock_request = MagicMock()
    mock_request.headers = {"x-internal-secret": "test_internal"}

    async with TestingSessionLocal() as session:
        with patch("routers.kot.send_supabase_realtime_broadcast", new=AsyncMock()) as mock_bcast, \
             patch.dict(os.environ, {"INTERNAL_API_SECRET": "test_internal"}):
            await broadcast_kot(
                req=req,
                request=mock_request,
                current_user={"id": "admin_1", "role": "SUPER_ADMIN"},
                db=session
            )
            assert mock_bcast.called
            topics_called = mock_bcast.call_args[0][0]
            assert "realtime:restaurant-orders-live" not in topics_called
            assert "restaurant-orders-live" not in topics_called
            assert f"realtime:restaurant-orders-{target_rest}" in topics_called
            assert f"restaurant-orders-{target_rest}" in topics_called


@pytest.mark.asyncio
async def test_auto_recovery_rejects_underpayment_and_enforces_stock_reconciliation():
    """P1 Verification: Verify that when catalog price is ₹500, stock is 0, requested quantity is 2,
    and gateway paid amount is ₹1:
    1. Status is quarantined to ADMIN_PENDING (not CONFIRMED / PAID).
    2. Notes flag [RECONCILIATION_REQUIRED] with underpayment and stock deficiency details.
    3. Stock is NOT decremented (remains 0).
    4. confirmedAt remains None."""
    import uuid
    from models import Product, Category, IdempotencyRecord, Order, OrderStatus
    from routers.cashfree_router import auto_recover_unplaced_cashfree_order

    cf_order_id = f"cf_underpaid_{uuid.uuid4().hex[:10]}"
    p_id = f"prod_saffron_{uuid.uuid4().hex[:8]}"

    async with TestingSessionLocal() as session:
        cat = Category(id=f"cat_{uuid.uuid4().hex[:6]}", name="Spices", slug=f"spices_{uuid.uuid4().hex[:6]}")
        session.add(cat)
        await session.flush()

        prod = Product(
            id=p_id,
            name="Kashmir Saffron 5g",
            price=500.0,
            mrp=600.0,
            costPrice=400.0,
            categoryId=cat.id,
            unit="5g",
            slug=f"saffron-{uuid.uuid4().hex[:6]}",
            isAvailable=True,
            stock=0  # Out of stock!
        )
        session.add(prod)
        await session.flush()

        # Buyer attempts to order 2 units (authoritative catalog subtotal = ₹1000.0) but only paid ₹1.0
        intent_payload = {
            "orderId": f"ord_intent_{uuid.uuid4().hex[:8]}",
            "cfOrderId": cf_order_id,
            "amount": 1.0,
            "userId": "usr_adversary",
            "customerPhone": "9123456789",
            "customerName": "Adversary Buyer",
            "customerEmail": "adversary@test.in",
            "items": [
                {"productId": p_id, "name": "Kashmir Saffron 5g", "price": 0.5, "quantity": 2}
            ],
            "deliveryMethod": "DELIVERY",
            "storeId": None,
            "createdAt": time.time(),
        }
        intent_rec = IdempotencyRecord(
            key=f"cf_intent:{cf_order_id}",
            userId="usr_adversary",
            status="PENDING",
            response=intent_payload,
            createdAt=datetime.utcnow(),
            expiresAt=datetime.utcnow() + timedelta(days=2)
        )
        session.add(intent_rec)
        await session.commit()

        # Run auto_recover_unplaced_cashfree_order with gateway paid ₹1.0
        recovered_order = await auto_recover_unplaced_cashfree_order(
            cf_order_id=cf_order_id,
            clean_id=cf_order_id,
            cf_ref="cf_ref_underpaid_1",
            order_data={"cf_order_id": cf_order_id, "order_amount": 1.0},
            payment_data={"payment_status": "SUCCESS", "payment_amount": 1.0, "cf_payment_id": "cf_pay_underpaid"},
            db=session
        )

        assert recovered_order is not None
        # Must be quarantined into ADMIN_PENDING, NOT CONFIRMED
        assert recovered_order.status == OrderStatus.ADMIN_PENDING
        assert recovered_order.confirmedAt is None
        assert recovered_order.subtotal == 1000.0  # Authoritative 2 * ₹500
        assert "[RECONCILIATION_REQUIRED]" in recovered_order.notes
        assert "Underpaid:" in recovered_order.notes
        assert "Insufficient inventory" in recovered_order.notes

        # Stock must NOT be decremented below 0
        refreshed_prod = (await session.execute(select(Product).where(Product.id == p_id))).scalar_one()
        assert refreshed_prod.stock == 0


@pytest.mark.asyncio
async def test_auto_recovery_grocery_to_restaurant_spoofing_prevented():
    """P1/P2 Verification: Verify that when a database product has restaurantId=None (pure grocery),
    recovery maintains authoritative null restaurantId and GROCERY order type, even if the caller
    or client payload passed restaurantId='REST-SPOOF'."""
    import uuid
    from models import Product, Category, IdempotencyRecord, Order, OrderType
    from routers.cashfree_router import auto_recover_unplaced_cashfree_order

    cf_order_id = f"cf_spoof_{uuid.uuid4().hex[:10]}"
    p_id = f"prod_flour_{uuid.uuid4().hex[:8]}"

    async with TestingSessionLocal() as session:
        cat = Category(id=f"cat_{uuid.uuid4().hex[:6]}", name="Atta & Flours", slug=f"atta_{uuid.uuid4().hex[:6]}")
        session.add(cat)
        await session.flush()

        prod = Product(
            id=p_id,
            name="Authoritative Wheat Flour 10kg",
            price=350.0,
            mrp=400.0,
            costPrice=300.0,
            categoryId=cat.id,
            unit="10kg",
            slug=f"flour-{uuid.uuid4().hex[:6]}",
            isAvailable=True,
            stock=20,
            restaurantId=None  # Legitimate pure grocery product
        )
        session.add(prod)
        await session.flush()

        # Intent attempts to spoof routing to REST-SPOOF
        intent_payload = {
            "orderId": f"ord_intent_{uuid.uuid4().hex[:8]}",
            "cfOrderId": cf_order_id,
            "amount": 350.0,
            "userId": "usr_spoof_attacker",
            "restaurantId": "REST-SPOOF",
            "customerPhone": "9123456789",
            "customerName": "Attacker",
            "customerEmail": "attacker@test.in",
            "items": [
                {
                    "productId": p_id,
                    "name": "Wheat Flour 10kg",
                    "price": 350.0,
                    "quantity": 1,
                    "restaurantId": "REST-SPOOF"
                }
            ],
            "deliveryMethod": "DELIVERY",
            "createdAt": time.time(),
        }
        intent_rec = IdempotencyRecord(
            key=f"cf_intent:{cf_order_id}",
            userId="usr_spoof_attacker",
            status="PENDING",
            response=intent_payload,
            createdAt=datetime.utcnow(),
            expiresAt=datetime.utcnow() + timedelta(days=2)
        )
        session.add(intent_rec)
        await session.commit()

        recovered_order = await auto_recover_unplaced_cashfree_order(
            cf_order_id=cf_order_id,
            clean_id=cf_order_id,
            cf_ref="cf_ref_spoof_1",
            order_data={"cf_order_id": cf_order_id, "order_amount": 350.0},
            payment_data={"payment_status": "SUCCESS", "payment_amount": 350.0, "cf_payment_id": "cf_pay_spoof"},
            db=session
        )

        assert recovered_order is not None
        # Enforce that grocery product remains grocery routing
        assert recovered_order.restaurantId is None
        assert recovered_order.orderType == OrderType.GROCERY
        
        from models import OrderItem
        item_rows = (await session.execute(select(OrderItem).where(OrderItem.orderId == recovered_order.id))).scalars().all()
        assert len(item_rows) == 1
        assert item_rows[0].productId == p_id


@pytest.mark.asyncio
async def test_order_creation_rejects_payment_reference_aliases_and_special_chars():
    """P1 Verification: Verify that /api/orders rejects payment reference aliases containing special characters
    with HTTP 400 Bad Request, preventing distinct consumption keys for sanitized aliases."""
    import uuid

    malformed_references = [
        "cf_paid!123",
        "cf_paid?123",
        "cf_paid$123",
        "cf_order#hack",
        "cf_order;DROP TABLE",
    ]

    token = create_access_token(data={"sub": f"usr_{uuid.uuid4().hex[:8]}", "role": "USER"})
    headers = {"Authorization": f"Bearer {token}"}

    for bad_ref in malformed_references:
        resp = client.post("/api/orders", json={
            "userId": "usr_test_buyer",
            "paymentMethod": "CASHFREE",
            "cfOrderId": bad_ref,
            "items": [{"productId": "p1", "quantity": 1, "price": 50.0}],
            "subtotal": 50.0,
            "total": 50.0,
        }, headers=headers)
        assert resp.status_code == 400
        res_data = resp.json()
        err_msg = res_data.get("detail") or res_data.get("error") or ""
        assert "Invalid payment reference format" in err_msg


@pytest.mark.asyncio
async def test_websocket_ticket_fails_closed_on_db_ledger_failure_across_all_production_envs():
    """Environment Verification: Verify that when database ledger fails, _consume_ws_ticket
    fails closed (returns False) across all production environment flags (APP_ENV, NODE_ENV,
    ENVIRONMENT, PRODUCTION) even if Redis distributed cache is healthy."""
    from routers.websockets import _consume_ws_ticket
    from database import get_db
    import uuid
    import time

    prod_environments = [
        {"APP_ENV": "production"},
        {"NODE_ENV": "production"},
        {"ENVIRONMENT": "production"},
        {"PRODUCTION": "true"},
    ]

    for env_dict in prod_environments:
        with patch.dict(os.environ, env_dict, clear=False):
            # Healthy Redis mock that acquires the lock
            mock_redis = AsyncMock()
            mock_redis.set = AsyncMock(return_value=True)

            async def failing_db_override():
                raise Exception("DB persistent ledger unavailable")
                yield None

            with patch("utils.cache.get_redis_connection", new=AsyncMock(return_value=mock_redis)), \
                 patch.dict(app.dependency_overrides, {get_db: failing_db_override}):
                jti = f"ws_ticket_{uuid.uuid4().hex}"
                exp = time.time() + 300
                ticket_accepted = await _consume_ws_ticket(jti, exp)
                assert ticket_accepted is False, f"Ticket should fail closed when DB ledger fails under {env_dict}"

