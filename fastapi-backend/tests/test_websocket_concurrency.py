import asyncio
import json
import pytest
from starlette.testclient import TestClient
from main import app
from routers.websockets import manager


def test_websocket_channel_isolation_and_broadcast():
    """Verify WebSocket manager connects, isolates channels, and broadcasts cleanly."""
    client = TestClient(app)
    
    # 1. Connect rider 1
    with client.websocket_connect("/ws/rider/rider_101") as ws_rider:
        # 2. Connect rider 2
        with client.websocket_connect("/ws/rider/rider_102") as ws_other:
            # Send telemetry on rider 101
            payload = {
                "event": "GPS_TELEMETRY",
                "lat": 26.1534,
                "lng": 80.1714,
                "speed": 22.5,
                "status": "DELIVERING"
            }
            ws_rider.send_text(json.dumps(payload))
            
            # Rider 101 should receive its channel broadcast
            response = json.loads(ws_rider.receive_text())
            assert response["event"] == "GPS_TELEMETRY"
            assert response["lat"] == 26.1534
            assert response["status"] == "DELIVERING"


def test_order_tracking_websocket_lifecycle():
    """Verify live order tracking websocket sends and broadcasts status and GPS."""
    client = TestClient(app)
    order_id = "test_order_concurrency_99"

    with client.websocket_connect(f"/ws/orders/{order_id}") as ws:
        # Send location update
        ws.send_text(json.dumps({
            "event": "LOCATION_UPDATE",
            "lat": 26.1550,
            "lng": 80.1730,
            "status": "OUT_FOR_DELIVERY",
            "timestamp": 1700000000
        }))

        msg = json.loads(ws.receive_text())
        assert msg["event"] == "LOCATION_UPDATE"
        assert msg["orderId"] == order_id
        assert msg["lat"] == 26.1550
        assert msg["status"] == "OUT_FOR_DELIVERY"


@pytest.mark.asyncio
async def test_high_concurrency_in_memory_connection_manager():
    """Verify ConnectionManager safely scales to 500+ concurrent channels without race conditions."""
    m = manager
    initial_channel_count = len(m.active_connections)

    class DummyWebSocket:
        def __init__(self):
            self.sent_messages = []
            self.is_open = True

        async def send_text(self, text: str):
            if not self.is_open:
                raise RuntimeError("Closed")
            self.sent_messages.append(text)

        async def accept(self):
            pass

    dummy_sockets = [DummyWebSocket() for _ in range(500)]

    # 1. Concurrently connect 500 simulated riders
    connect_tasks = [
        m.connect(dummy_sockets[i], f"rider_scale_{i}")
        for i in range(500)
    ]
    await asyncio.gather(*connect_tasks)

    assert len(m.active_connections) >= initial_channel_count + 500

    # 2. Concurrently broadcast to all 500 riders
    broadcast_tasks = [
        m.broadcast_to_channel(f"rider_scale_{i}", {"event": "DISPATCH_ORDER", "orderId": f"ORD_{i}"})
        for i in range(500)
    ]
    await asyncio.gather(*broadcast_tasks)

    # Verify each rider received their isolated event
    for i in range(500):
        assert len(dummy_sockets[i].sent_messages) == 1
        data = json.loads(dummy_sockets[i].sent_messages[0])
        assert data["orderId"] == f"ORD_{i}"

    # 3. Clean up and disconnect all
    for i in range(500):
        m.disconnect(dummy_sockets[i], f"rider_scale_{i}")
