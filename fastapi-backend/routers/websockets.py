import os
import math
import json
import uuid
import asyncio
import logging
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional
import jwt
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, HTTPException, status, Request
from fastapi.responses import StreamingResponse
from config import settings
from database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from models import Order
from routers.auth import get_current_user

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
        # Ensure traceId is present in message for distributed end-to-end tracing
        if isinstance(message, dict) and "traceId" not in message and "trace_id" not in message:
            try:
                from services.tracer_service import TracerService
                message["traceId"] = TracerService.generate_trace_id()
            except Exception:
                pass

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

consumed_ws_tickets: Dict[str, float] = {}


async def _consume_ws_ticket(jti: str, exp: float) -> bool:
    """
    Atomically consume single-use WebSocket ticket ID.
    Uses database as the authoritative persistent ledger and Redis as the fast distributed cache.
    Guarantees zero ticket replay across Redis outage-to-healthy or healthy-to-outage transitions.
    In production environments, fails closed if neither the shared database nor Redis can ledger the ticket.
    """
    now = time.time()
    ttl = max(1, math.ceil(exp - now))
    
    from config import settings
    env_candidates = [
        os.environ.get("APP_ENV"),
        os.environ.get("NODE_ENV"),
        os.environ.get("ENVIRONMENT"),
        os.environ.get("PRODUCTION"),
    ]
    is_prod = any(
        str(val).strip().lower() in ("production", "prod", "true", "1")
        for val in env_candidates if val is not None
    )
    if not is_prod:
        sett_env = getattr(settings, "APP_ENV", "")
        if sett_env and str(sett_env).strip().lower() in ("production", "prod", "true", "1"):
            is_prod = True

    # 1. Local process-memory check for quick rejection
    if jti in consumed_ws_tickets:
        return False

    ticket_key = f"ws_ticket_{jti}"
    now_dt = datetime.utcnow()
    exp_dt = datetime.utcfromtimestamp(exp)

    # 2. Redis fast-check / atomic reservation
    redis = None
    redis_recorded = False
    try:
        from utils.cache import get_redis_connection
        redis = await get_redis_connection()
        if redis:
            acquired = await redis.set(f"consumed_ws_ticket:{jti}", "1", nx=True, ex=ttl)
            if not acquired:
                consumed_ws_tickets[jti] = exp
                return False
            redis_recorded = True
    except Exception as redis_err:
        logger.warning(f"[WebSocket] Redis check failed: {redis_err}")
        redis = None
        redis_recorded = False

    # 3. Authoritative Shared Database Ledger Check & Record
    db_recorded = False
    try:
        from main import app
        from database import get_db, AsyncSessionLocal
        from models import IdempotencyRecord
        from sqlalchemy.future import select
        from sqlalchemy.exc import IntegrityError

        async def _record_in_session(session):
            stmt = select(IdempotencyRecord).where(IdempotencyRecord.key == ticket_key)
            res = await session.execute(stmt)
            if res.scalars().first():
                return False
            rec = IdempotencyRecord(
                key=ticket_key,
                status="COMPLETED",
                createdAt=now_dt,
                expiresAt=exp_dt
            )
            session.add(rec)
            await session.commit()
            return True

        override = app.dependency_overrides.get(get_db)
        if override:
            async for session in override():
                try:
                    success = await _record_in_session(session)
                    if not success:
                        consumed_ws_tickets[jti] = exp
                        return False
                    db_recorded = True
                except IntegrityError:
                    await session.rollback()
                    consumed_ws_tickets[jti] = exp
                    return False
                break
        else:
            async with AsyncSessionLocal() as session:
                try:
                    success = await _record_in_session(session)
                    if not success:
                        consumed_ws_tickets[jti] = exp
                        return False
                    db_recorded = True
                except IntegrityError:
                    await session.rollback()
                    consumed_ws_tickets[jti] = exp
                    return False
    except Exception as db_err:
        logger.warning(f"[WebSocket] Cross-worker DB ticket consumption failed: {db_err}")

    # Fail closed: Authoritative DB ledger is required in production environments
    if is_prod and not db_recorded:
        logger.error(f"[WebSocket Security] Failing closed: Authoritative DB ledger failed to record ticket {jti} in production")
        return False

    # Fail closed across all environments if neither DB nor Redis could record the consumption
    if not (db_recorded or redis_recorded):
        logger.error(f"[WebSocket Security] Failing closed: Unable to record ticket {jti} in any shared store")
        return False

    # 4. Synchronize to Redis cache if not already recorded
    if redis and not redis_recorded:
        try:
            await redis.set(f"consumed_ws_ticket:{jti}", "1", ex=ttl)
        except Exception:
            pass

    consumed_ws_tickets[jti] = exp
    if len(consumed_ws_tickets) > 5000:
        for k in list(consumed_ws_tickets.keys()):
            if consumed_ws_tickets[k] < now:
                consumed_ws_tickets.pop(k, None)
    return True


async def _verify_ws_ticket(ticket: Optional[str], expected_channel: str) -> Optional[dict]:
    """
    Verifies a short-lived single-use channel ticket.
    Enforces expiry claim, scope separation, single-use consumption, and exact channel authorization.
    Rejects wildcard '*' even if signed.
    Returns user payload or None.
    """
    if not ticket:
        return None
    try:
        from utils.jwt import AUTH_SECRET
        payload = jwt.decode(ticket, AUTH_SECRET, algorithms=["HS256"])
        exp = payload.get("exp")
        # Enforce exp claim is strictly present and not expired
        if not exp or datetime.now(timezone.utc).timestamp() > float(exp):
            return None

        # Check scope / type: REST credentials cannot act as socket tickets
        token_scope = payload.get("scope") or payload.get("type")
        if token_scope != "ws_ticket":
            return None

        allowed_channel = payload.get("channel")
        # Strictly reject wildcard '*' or channel mismatch
        if not allowed_channel or allowed_channel == "*" or allowed_channel != expected_channel:
            return None

        # Atomically consume single-use ticket (jti is mandatory)
        jti = payload.get("jti")
        if not jti:
            logger.warning("WebSocket ticket missing required jti claim.")
            return None

        consumed = await _consume_ws_ticket(jti, float(exp))
        if not consumed:
            logger.warning(f"WebSocket ticket {jti} already consumed or replayed.")
            return None

        return payload
    except Exception:
        return None


@router.post("/ticket")
async def create_ws_ticket(
    body: dict,
    request: Request = None,
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Issue short-lived single-use channel ticket for browser/mobile WebSocket connections.
    Requires authenticated user and enforces exact channel authorization.
    Rejects wildcard '*', empty, and unauthorized channels.
    """
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required to obtain WebSocket ticket"
        )

    user_id = current_user.get("id") or current_user.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user identity"
        )

    user_role = str(current_user.get("role", "USER")).upper()
    channel = str(body.get("channel", "")).strip()

    # 1. Strictly reject wildcard '*', empty or malformed channels
    if not channel or channel == "*" or len(channel) > 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or unsupported channel identifier. Wildcard '*' is prohibited."
        )

    # 2. Enforce exact resource/channel authorization
    if channel == "general":
        pass
    elif channel.startswith("order_"):
        target_order_id = channel.removeprefix("order_").strip()
        if not target_order_id or target_order_id == "*":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid order channel format")
        
        stmt = select(Order.userId, Order.deliveryUserId).where(
            (Order.id == target_order_id) | (Order.readableId == target_order_id)
        )
        res = await db.execute(stmt)
        order_row = res.first()
        if not order_row and user_role not in ["ADMIN", "SUPER_ADMIN"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

        if user_role in ["ADMIN", "SUPER_ADMIN"]:
            pass
        elif user_role in ["RIDER", "DELIVERY"]:
            # Delivery rider can ONLY subscribe to an order if assigned to deliver it
            if not order_row or str(order_row[1] or "") != str(user_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Forbidden: You are not assigned to deliver this order"
                )
        else:
            # Customer can only subscribe to their own order
            if not order_row or str(order_row[0] or "") != str(user_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Forbidden: You are not authorized to subscribe to this order's live updates"
                )
    elif channel.startswith("restaurant_"):
        target_rid = channel.removeprefix("restaurant_").strip()
        if not target_rid or target_rid == "*":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid restaurant channel format")
        user_assigned_rid = current_user.get("assignedRestaurantId")
        if user_role not in ["ADMIN", "SUPER_ADMIN"] and str(user_assigned_rid) != str(target_rid):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: You are not authorized for this restaurant console channel"
            )
    elif channel.startswith("rider_"):
        target_rider_id = channel.removeprefix("rider_").strip()
        if not target_rider_id or target_rider_id == "*":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid rider channel format")
        if user_role not in ["ADMIN", "SUPER_ADMIN"] and str(user_id) != str(target_rider_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: You are not authorized for this rider channel"
            )
    elif channel in ["admin", "admin_live", "kitchen_all"]:
        if user_role not in ["ADMIN", "SUPER_ADMIN"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Admin privilege required for this channel"
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported channel type"
        )

    from utils.jwt import AUTH_SECRET
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=120)
    ticket_payload = {
        "jti": f"wst_{uuid.uuid4().hex}",
        "sub": user_id,
        "id": user_id,
        "role": user_role,
        "channel": channel,
        "scope": "ws_ticket",
        "type": "ws_ticket",
        "exp": int(expires_at.timestamp())
    }
    ticket = jwt.encode(ticket_payload, AUTH_SECRET, algorithm="HS256")
    return {"ticket": ticket, "channel": channel, "expiresIn": 120}


@router.post("/broadcast")
async def http_broadcast(
    payload: dict,
    request: Request,
    current_user: Optional[dict] = Depends(get_current_user),
):
    """
    HTTP POST trigger to broadcast events to any authorized WebSocket channel.
    Secured by INTERNAL_API_SECRET or Admin authentication.
    Wildcard broadcast is strictly rejected.
    """
    x_internal = request.headers.get("x-internal-secret", "").strip()
    internal_secret = os.getenv("INTERNAL_API_SECRET", "").strip()
    is_internal = bool(internal_secret and x_internal == internal_secret)

    is_admin = False
    if current_user:
        role = str(current_user.get("role", "")).upper()
        if role in ["ADMIN", "SUPER_ADMIN"]:
            is_admin = True

    if not is_internal and not is_admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Internal secret or Admin authentication required to trigger broadcasts"
        )

    channel = payload.get("channel", "general")
    if not channel or channel == "*":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Wildcard '*' or empty channel broadcast is prohibited"
        )

    message = payload.get("message", payload)
    await manager.broadcast_to_channel(channel, message)
    return {"success": True, "channel": channel}

@router.websocket("")
@router.websocket("/")
async def root_websocket(
    websocket: WebSocket,
    ticket: Optional[str] = Query(None),
    token: Optional[str] = Query(None)
):
    """
    General WebSocket connection endpoint for real-time broadcasts
    """
    channel = "general"
    auth_ticket = ticket or token
    if not auth_ticket:
        await websocket.close(code=4003, reason="Unauthorized: Ticket or token required")
        return
    user = await _verify_ws_ticket(auth_ticket, channel)
    if not user:
        await websocket.close(code=4003, reason="Unauthorized: Valid ticket required")
        return

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
async def order_tracking_websocket(
    websocket: WebSocket,
    order_id: str,
    ticket: Optional[str] = Query(None),
    token: Optional[str] = Query(None)
):
    """
    Live real-time order tracking WebSocket for customers & delivery riders.
    Secured via channel-bound ticket or bearer token query param.
    """
    channel = f"order_{order_id}"
    auth_ticket = ticket or token
    if not auth_ticket:
        await websocket.close(code=4003, reason="Unauthorized: Ticket or token required")
        return
    user = await _verify_ws_ticket(auth_ticket, channel)
    if not user:
        await websocket.close(code=4003, reason="Unauthorized: Valid ticket required")
        return

    user_role = str(user.get("role", "USER")).upper()
    await manager.connect(websocket, channel)
    try:
        while True:
            # Receive GPS ping or status update message
            data = await websocket.receive_text()
            if data in ("ping", '{"type":"ping"}'):
                await websocket.send_text(json.dumps({"event": "PONG"}))
                continue

            try:
                payload = json.loads(data)
            except Exception:
                continue
            
            # Authorize realtime publication separately from subscription:
            # Customers are subscribers only; only verified delivery personnel and admins can broadcast location/status
            if user_role not in ["ADMIN", "SUPER_ADMIN", "RIDER", "DELIVERY"]:
                continue

            # Broadcast location or status to all connected clients on this order channel
            await manager.broadcast_to_channel(channel, {
                "event": payload.get("event", "LOCATION_UPDATE"),
                "orderId": order_id,
                "lat": payload.get("lat"),
                "lng": payload.get("lng"),
                "status": payload.get("status"),
                "timestamp": payload.get("timestamp")
            })
    except WebSocketDisconnect:
        manager.disconnect(websocket, channel)

@router.websocket("/rider/{rider_id}")
async def rider_location_websocket(
    websocket: WebSocket,
    rider_id: str,
    ticket: Optional[str] = Query(None),
    token: Optional[str] = Query(None)
):
    """
    Real-time rider GPS stream for admin live operations tracking
    """
    channel = f"rider_{rider_id}"
    auth_ticket = ticket or token
    if not auth_ticket:
        await websocket.close(code=4003, reason="Unauthorized: Ticket or token required")
        return
    user = await _verify_ws_ticket(auth_ticket, channel)
    if not user:
        await websocket.close(code=4003, reason="Unauthorized: Valid ticket required")
        return

    await manager.connect(websocket, channel)
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            await manager.broadcast_to_channel(channel, payload)
    except WebSocketDisconnect:
        manager.disconnect(websocket, channel)


@router.websocket("/restaurant/{restaurant_id}")
async def restaurant_console_websocket(
    websocket: WebSocket,
    restaurant_id: str,
    ticket: Optional[str] = Query(None),
    token: Optional[str] = Query(None)
):
    """
    Real-time restaurant kitchen & order stream strictly isolated for this restaurant outlet
    """
    clean_rid = restaurant_id.strip()
    channel = f"restaurant_{clean_rid}"
    auth_ticket = ticket or token
    if not auth_ticket:
        await websocket.close(code=4003, reason="Unauthorized: Ticket or token required")
        return
    user = await _verify_ws_ticket(auth_ticket, channel)
    if not user:
        await websocket.close(code=4003, reason="Unauthorized: Valid ticket required")
        return

    await manager.connect(websocket, channel)
    try:
        await websocket.send_text(json.dumps({
            "event": "CONNECTED",
            "channel": channel,
            "restaurantId": clean_rid
        }))
        while True:
            data = await websocket.receive_text()
            try:
                payload = json.loads(data)
            except Exception:
                payload = {"event": "MESSAGE", "data": data}
            payload["restaurantId"] = clean_rid
            await manager.broadcast_to_channel(channel, payload)
    except WebSocketDisconnect:
        manager.disconnect(websocket, channel)

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

