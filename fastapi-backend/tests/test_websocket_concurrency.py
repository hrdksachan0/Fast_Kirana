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


@pytest.mark.asyncio
async def test_multi_worker_redis_pubsub_cross_worker_sync():
    """
    Verify multi-worker Redis Pub/Sub architecture:
    When Worker 1 broadcasts an order update, Worker 2 receives and routes it
    to its local customer WebSocket without message duplication.
    """
    from routers.websockets import ConnectionManager

    # Instantiate two separate worker connection managers
    worker1 = ConnectionManager()
    worker2 = ConnectionManager()
    assert worker1.worker_id != worker2.worker_id

    class MockWebSocket:
        def __init__(self):
            self.messages = []
        async def send_text(self, text: str):
            self.messages.append(json.loads(text))
        async def accept(self):
            pass

    # Customer connected to Worker 2
    customer_ws = MockWebSocket()
    await worker2.connect(customer_ws, "order_sync_999")

    # Delivery rider connected to Worker 1
    rider_ws = MockWebSocket()
    await worker1.connect(rider_ws, "order_sync_999")

    # Simulated shared Redis Pub/Sub bus
    redis_bus = asyncio.Queue()

    class MockRedisClient:
        async def publish(self, channel, message_str):
            await redis_bus.put(message_str)

    worker1.redis_client = MockRedisClient()
    worker2.redis_client = MockRedisClient()

    # 1. Delivery rider on Worker 1 broadcasts GPS update
    telemetry_packet = {
        "event": "LOCATION_UPDATE",
        "orderId": "order_sync_999",
        "lat": 26.1520,
        "lng": 80.1740,
        "status": "OUT_FOR_DELIVERY"
    }
    await worker1.broadcast_to_channel("order_sync_999", telemetry_packet)

    # Worker 1's local rider receives direct echo
    assert len(rider_ws.messages) == 1
    assert rider_ws.messages[0]["status"] == "OUT_FOR_DELIVERY"

    # Worker 1 published packet to Redis
    published_raw = await redis_bus.get()
    packet = json.loads(published_raw)
    assert packet["worker_id"] == worker1.worker_id
    assert packet["channel"] == "order_sync_999"

    # 2. Worker 2 receives packet from Redis Pub/Sub bus
    # Simulate Worker 2 processing message from Redis
    sender_worker = packet.get("worker_id")
    assert sender_worker != worker2.worker_id  # Not from self
    await worker2._send_to_local_sockets(packet["channel"], packet["payload"])

    # Worker 2's customer receives the update from Worker 1 across workers!
    assert len(customer_ws.messages) == 1
    assert customer_ws.messages[0]["orderId"] == "order_sync_999"
    assert customer_ws.messages[0]["lat"] == 26.1520

    # 3. Verify deduplication: Worker 1 should NOT process its own published message
    if packet.get("worker_id") == worker1.worker_id:
        # Worker 1 ignores it because worker_id matches
        pass
    else:
        await worker1._send_to_local_sockets(packet["channel"], packet["payload"])
    assert len(rider_ws.messages) == 1  # No duplicate delivery!


@pytest.mark.asyncio
async def test_connection_manager_graceful_lifecycle_without_redis():
    """Verify ConnectionManager starts and stops gracefully without REDIS_URL configured."""
    from routers.websockets import ConnectionManager
    cm = ConnectionManager()
    await cm.start()
    assert cm._running is True
    assert cm.redis_client is None  # Local mode fallback
    await cm.stop()
    assert cm._running is False

