import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from main import app
from routers.orders import (
    dispatch_isolated_order_fcm_notifications,
    dispatch_isolated_status_update_notifications,
)
from utils.firebase import is_order_buzzer_alert, is_order_status_update

client = TestClient(app)


@pytest.mark.asyncio
async def test_admin_pending_notifies_admin_only():
    with patch("routers.orders.send_fcm_topic_notification", new_callable=AsyncMock) as mock_topic, \
         patch("routers.orders.send_fcm_notification", new_callable=AsyncMock) as mock_direct:
        await dispatch_isolated_order_fcm_notifications(
            order_id="ord_1",
            readable_id="FK-1001",
            restaurant_id="REST-101",
            shop_name="Wedson",
            total=250.0,
            status_val="ADMIN_PENDING",
            store_id="hub-209206",
            payment_status="PENDING",
        )
        sent_topics = [call.args[0] for call in mock_topic.call_args_list]
        assert "admin_orders_hub-209206" in sent_topics
        assert "admin_orders" in sent_topics
        assert not any(t.startswith("restaurant_") for t in sent_topics)
        assert not any(t.startswith("delivery_orders") for t in sent_topics)
        assert not any(t.startswith("picker_orders") for t in sent_topics)
        mock_direct.assert_not_awaited()


@pytest.mark.asyncio
async def test_auto_approved_restaurant_order_notifies_restaurant_and_rider_not_admin():
    with patch("routers.orders.send_fcm_topic_notification", new_callable=AsyncMock) as mock_topic, \
         patch("routers.orders.send_fcm_notification", new_callable=AsyncMock):
        await dispatch_isolated_order_fcm_notifications(
            order_id="ord_2",
            readable_id="FK-1002",
            restaurant_id="REST-102",
            shop_name="Wedson",
            total=300.0,
            status_val="PENDING",
            store_id="hub-209206",
            payment_status="PAID",
        )
        sent_topics = [call.args[0] for call in mock_topic.call_args_list]
        assert "restaurant_REST-102" in sent_topics
        assert "delivery_orders_hub-209206" in sent_topics
        assert not any(t.startswith("admin_orders") for t in sent_topics)
        assert not any(t.startswith("picker_orders") for t in sent_topics)


@pytest.mark.asyncio
async def test_restaurant_status_updates_do_not_chime_except_cancel():
    with patch("routers.orders.send_fcm_topic_notification", new_callable=AsyncMock) as mock_topic:
        for st in ["CONFIRMED", "PACKED", "SHIPPED", "DELIVERED"]:
            await dispatch_isolated_status_update_notifications(
                order_id="ord_3",
                readable_id="FK-1003",
                restaurant_id="REST-101",
                shop_name="A.S. Restaurant",
                status_val=st,
                store_id="hub-209206",
            )
        sent_topics = [call.args[0] for call in mock_topic.call_args_list]
        assert not any(t.startswith("restaurant_") for t in sent_topics)

        mock_topic.reset_mock()
        await dispatch_isolated_status_update_notifications(
            order_id="ord_3",
            readable_id="FK-1003",
            restaurant_id="REST-101",
            shop_name="A.S. Restaurant",
            status_val="CANCELLED",
            store_id="hub-209206",
        )
        sent_topics = [call.args[0] for call in mock_topic.call_args_list]
        assert sent_topics == ["restaurant_REST-101"]


def test_cancelled_notification_is_quiet():
    data = {"status": "CANCELLED", "restaurantId": "REST-101", "screen": "restaurant-console"}
    assert is_order_buzzer_alert("Order Cancelled", "Order #1003 cancelled", data) is False
    assert is_order_status_update("Order Cancelled", "Order #1003 cancelled", data) is False


def test_fcm_unregister_handles_empty_and_token():
    res_empty = client.post("/api/fcm/unregister", json={})
    assert res_empty.status_code == 200
    assert res_empty.json().get("success") is True
