import os
import json
import uuid
import asyncio
import logging
from typing import Dict, List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["Real-time WebSockets Engine"])

class ConnectionManager:
    """
    High-Performance Multi-Worker WebSocket Connection Manager.
    - Manages local in-memory connections per Uvicorn worker process.
    - Synchronizes cross-worker events via Redis Pub/Sub channel 'fastkirana:ws_broadcast'.
    - Gracefully falls back to local in-memory mode if Redis is not configured or offline.
    """
    REDIS_CHANNEL = "fastkirana:ws_broadcast"

    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.worker_id: str = str(uuid.uuid4())[:8]
        self.redis_client = None
        self.pubsub = None
        self.redis_task: Optional[asyncio.Task] = None
        self._running: bool = False

    async def start(self):
        """
        Connects to Redis Pub/Sub for horizontal multi-worker/multi-container scaling.
        """
        self._running = True
        redis_url = settings.REDIS_URL or os.getenv("REDIS_URL")
        if not redis_url:
            logger.info(f"[WebSocket] REDIS_URL not configured. Worker {self.worker_id} operating in local in-memory mode.")
            return

        try:
            import redis.asyncio as aioredis
            self.redis_client = aioredis.from_url(
                redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_timeout=3.0,
                socket_connect_timeout=3.0
            )
            await self.redis_client.ping()
            self.pubsub = self.redis_client.pubsub()
            await self.pubsub.subscribe(self.REDIS_CHANNEL)
            self.redis_task = asyncio.create_task(self._redis_listener())
            logger.info(f"[WebSocket] Worker {self.worker_id} subscribed to Redis Pub/Sub '{self.REDIS_CHANNEL}' for cross-worker broadcast.")
        except Exception as e:
            logger.warning(f"[WebSocket] Worker {self.worker_id} Redis Pub/Sub initialization skipped ({e}). Operating in local in-memory mode.")
            self.redis_client = None
            self.pubsub = None

    async def stop(self):
        """
        Gracefully terminates Redis Pub/Sub listener and connection pool.
        """
        self._running = False
        if self.redis_task and not self.redis_task.done():
            self.redis_task.cancel()
            try:
                await self.redis_task
            except asyncio.CancelledError:
                pass
            self.redis_task = None

        if self.pubsub:
            try:
                await self.pubsub.unsubscribe(self.REDIS_CHANNEL)
                await self.pubsub.close()
            except Exception:
                pass
            self.pubsub = None

        if self.redis_client:
            try:
                await self.redis_client.close()
            except Exception:
                pass
            self.redis_client = None
        logger.info(f"[WebSocket] Worker {self.worker_id} connection manager shut down.")

    async def _redis_listener(self):
        """
        Background listener task receiving cross-worker messages from Redis Pub/Sub.
        """
        try:
            async for message in self.pubsub.listen():
                if not self._running:
                    break
                if message.get("type") == "message":
                    try:
                        raw_data = message.get("data")
                        if not raw_data:
                            continue
                        packet = json.loads(raw_data)
                        origin_worker = packet.get("worker_id")
                        # Skip if published by this worker (already delivered to local sockets)
                        if origin_worker == self.worker_id:
                            continue
                        
                        channel_id = packet.get("channel")
                        payload = packet.get("payload")
                        if channel_id and payload is not None:
                            await self._send_to_local_sockets(channel_id, payload)
                    except Exception as err:
                        logger.debug(f"[WebSocket] Error parsing Redis Pub/Sub packet: {err}")
        except asyncio.CancelledError:
            pass
        except Exception as e:
            if self._running:
                logger.warning(f"[WebSocket] Redis listener interrupted: {e}")

    async def _send_to_local_sockets(self, channel_id: str, message: dict):
        """
        Deliver message directly to local sockets attached to this worker process.
        """
        if channel_id in self.active_connections:
            disconnected = []
            for connection in list(self.active_connections[channel_id]):
                try:
                    await connection.send_text(json.dumps(message))
                except Exception:
                    disconnected.append(connection)
            for conn in disconnected:
                self.disconnect(conn, channel_id)

    async def connect(self, websocket: WebSocket, channel_id: str):
        await websocket.accept()
        if channel_id not in self.active_connections:
            self.active_connections[channel_id] = []
        self.active_connections[channel_id].append(websocket)

    def disconnect(self, websocket: WebSocket, channel_id: str):
        if channel_id in self.active_connections:
            if websocket in self.active_connections[channel_id]:
                self.active_connections[channel_id].remove(websocket)
            if not self.active_connections[channel_id]:
                del self.active_connections[channel_id]

    async def broadcast_to_channel(self, channel_id: str, message: dict):
        # 1. Local delivery: Immediate zero-latency broadcast to sockets on this worker
        await self._send_to_local_sockets(channel_id, message)

        # 2. Redis Pub/Sub: Cross-worker broadcast to other Uvicorn workers & server instances
        if self.redis_client:
            try:
                packet = {
                    "worker_id": self.worker_id,
                    "channel": channel_id,
                    "payload": message
                }
                await self.redis_client.publish(self.REDIS_CHANNEL, json.dumps(packet))
            except Exception as e:
                logger.warning(f"[WebSocket] Redis Pub/Sub broadcast failed for channel '{channel_id}': {e}")

    async def broadcast(self, message: dict):
        """Broadcast to the general channel."""
        await self.broadcast_to_channel("general", message)

manager = ConnectionManager()

@router.post("/broadcast")
async def http_broadcast(payload: dict):
    """
    HTTP POST trigger to broadcast events to any WebSocket channel (e.g. general, order_{id}, etc.)
    """
    channel = payload.get("channel", "general")
    message = payload.get("message", payload)
    await manager.broadcast_to_channel(channel, message)
    return {"success": True, "channel": channel}

@router.websocket("")
@router.websocket("/")
async def root_websocket(websocket: WebSocket):
    """
    General WebSocket connection endpoint for real-time broadcasts
    """
    await manager.connect(websocket, "general")
    try:
        await websocket.send_text(json.dumps({"event": "CONNECTED", "message": "Connected to FastKirana WebSocket Server"}))
        while True:
            data = await websocket.receive_text()
            if data == "ping" or data == '{"type":"ping"}':
                await websocket.send_text(json.dumps({"event": "PONG"}))
            else:
                await websocket.send_text(json.dumps({"event": "ECHO", "data": data}))
    except WebSocketDisconnect:
        manager.disconnect(websocket, "general")


@router.websocket("/orders/{order_id}")
async def order_tracking_websocket(websocket: WebSocket, order_id: str):
    """
    Live real-time order tracking WebSocket for customers & delivery riders
    """
    await manager.connect(websocket, f"order_{order_id}")
    try:
        while True:
            # Receive GPS ping or status update message
            data = await websocket.receive_text()
            payload = json.loads(data)
            
            # Broadcast location or status to all connected clients on this order channel
            await manager.broadcast_to_channel(f"order_{order_id}", {
                "event": payload.get("event", "LOCATION_UPDATE"),
                "orderId": order_id,
                "lat": payload.get("lat"),
                "lng": payload.get("lng"),
                "status": payload.get("status"),
                "timestamp": payload.get("timestamp")
            })
    except WebSocketDisconnect:
        manager.disconnect(websocket, f"order_{order_id}")

@router.websocket("/rider/{rider_id}")
async def rider_location_websocket(websocket: WebSocket, rider_id: str):
    """
    Real-time rider GPS stream for admin live operations tracking
    """
    await manager.connect(websocket, f"rider_{rider_id}")
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            await manager.broadcast_to_channel(f"rider_{rider_id}", payload)
    except WebSocketDisconnect:
        manager.disconnect(websocket, f"rider_{rider_id}")


@router.websocket("/restaurant/{restaurant_id}")
async def restaurant_console_websocket(websocket: WebSocket, restaurant_id: str):
    """
    Real-time restaurant kitchen & order stream strictly isolated for this restaurant outlet
    """
    clean_rid = restaurant_id.strip()
    await manager.connect(websocket, f"restaurant_{clean_rid}")
    try:
        await websocket.send_text(json.dumps({
            "event": "CONNECTED",
            "channel": f"restaurant_{clean_rid}",
            "restaurantId": clean_rid
        }))
        while True:
            data = await websocket.receive_text()
            try:
                payload = json.loads(data)
            except Exception:
                payload = {"event": "MESSAGE", "data": data}
            payload["restaurantId"] = clean_rid
            await manager.broadcast_to_channel(f"restaurant_{clean_rid}", payload)
    except WebSocketDisconnect:
        manager.disconnect(websocket, f"restaurant_{clean_rid}")


from fastapi.responses import StreamingResponse
from fastapi import Request
import time
import uuid

sse_router = APIRouter(prefix="/sse", tags=["SSE Real-Time Stream"])

@sse_router.get("/orders")
async def sse_orders_stream(request: Request):
    """
    Server-Sent Events (SSE) stream for real-time order notifications.
    Keeps connection alive with periodic heartbeats every 15 seconds.
    """
    async def event_generator():
        # Yield initial connection event
        yield f"data: {json.dumps({'type': 'connected', 'timestamp': int(time.time() * 1000)})}\n\n"

        while True:
            if await request.is_disconnected():
                break
            await asyncio.sleep(15.0)
            yield f"data: {json.dumps({'type': 'ping', 'timestamp': int(time.time() * 1000)})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )

