"""
FastAPI Health Check Endpoint
Used by container orchestrators and uptime monitors.
"""

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from datetime import datetime, timezone
import time

from database import get_db

health_router = APIRouter(tags=["Health"])

SERVER_BOOT_TIME = time.time()


@health_router.get("/health", status_code=status.HTTP_200_OK)
@health_router.get("/api/health", status_code=status.HTTP_200_OK)
async def health_check(db: AsyncSession = Depends(get_db)):
    start_time = time.perf_counter()
    is_db_connected = False
    latency_ms = None
    try:
        await db.execute(select(1))
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
        is_db_connected = True
    except Exception:
        is_db_connected = False

    payload = {
        "status": "healthy" if is_db_connected else "unhealthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "fastapi-backend",
        "database": {
            "status": "connected" if is_db_connected else "disconnected",
            "latencyMs": latency_ms
        }
    }

    if not is_db_connected:
        return JSONResponse(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, content=payload)

    return payload


@health_router.get("/health/deep", status_code=status.HTTP_200_OK)
@health_router.get("/api/health/deep", status_code=status.HTTP_200_OK)
async def deep_health_check(db: AsyncSession = Depends(get_db)):
    """
    Comprehensive deep-health diagnostic check.
    Monitors DB latency, Redis status, active WebSockets, and system uptime.
    """
    # 1. Database Ping & Latency
    db_start = time.perf_counter()
    is_db_connected = False
    db_latency_ms = None
    try:
        await db.execute(select(1))
        db_latency_ms = round((time.perf_counter() - db_start) * 1000, 2)
        is_db_connected = True
    except Exception:
        is_db_connected = False

    # 2. Redis Connection Status
    is_redis_connected = False
    redis_latency_ms = None
    try:
        from utils.cache import get_redis_connection
        redis_client = await get_redis_connection()
        if redis_client:
            r_start = time.perf_counter()
            await redis_client.ping()
            redis_latency_ms = round((time.perf_counter() - r_start) * 1000, 2)
            is_redis_connected = True
    except Exception:
        is_redis_connected = False

    # 3. Active Real-time WebSocket Metrics
    ws_connections_count = 0
    ws_channels_count = 0
    try:
        from routers.websockets import manager
        ws_channels_count = len(manager.active_connections)
        ws_connections_count = sum(len(conns) for conns in manager.active_connections.values())
    except Exception:
        pass

    # 5. Connection Pool Metrics
    pool_stats = {}
    try:
        from database import engine
        pool = engine.pool
        pool_stats = {
            "size": pool.size(),
            "checkedIn": pool.checkedin(),
            "checkedOut": pool.checkedout(),
            "overflow": pool.overflow(),
            "maxOverflow": pool._max_overflow,
            "totalActive": pool.checkedout() + pool.overflow(),
            "utilization": f"{round((pool.checkedout() / max(pool.size(), 1)) * 100)}%",
        }
    except Exception:
        pool_stats = {"status": "unavailable"}

    overall_status = "healthy" if is_db_connected else "degraded"

    payload = {
        "status": overall_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "fastapi-backend",
        "version": "2.0.0",
        "uptime": {
            "seconds": uptime_seconds,
            "readable": uptime_human,
            "bootTime": datetime.fromtimestamp(SERVER_BOOT_TIME, timezone.utc).isoformat()
        },
        "database": {
            "status": "connected" if is_db_connected else "disconnected",
            "latencyMs": db_latency_ms,
            "type": "PostgreSQL (Neon / Supabase)",
            "pool": pool_stats,
        },
        "cache": {
            "status": "connected" if is_redis_connected else "in-memory-fallback",
            "redis": is_redis_connected,
            "latencyMs": redis_latency_ms
        },
        "websockets": {
            "activeChannels": ws_channels_count,
            "activeClients": ws_connections_count
        }
    }

    if not is_db_connected:
        return JSONResponse(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, content=payload)

    return payload


@health_router.get("/health/pool", status_code=status.HTTP_200_OK)
@health_router.get("/api/health/pool", status_code=status.HTTP_200_OK)
async def pool_health():
    """Quick connection pool status for monitoring dashboards."""
    try:
        from database import engine
        pool = engine.pool
        checked_out = pool.checkedout()
        total_size = pool.size()
        overflow = pool.overflow()
        utilization_pct = round((checked_out / max(total_size, 1)) * 100)

        status_label = "healthy"
        if utilization_pct > 80:
            status_label = "warning"
        if utilization_pct > 95 or overflow > pool._max_overflow * 0.8:
            status_label = "critical"

        return {
            "status": status_label,
            "pool": {
                "size": total_size,
                "checkedIn": pool.checkedin(),
                "checkedOut": checked_out,
                "overflow": overflow,
                "maxOverflow": pool._max_overflow,
                "utilization": f"{utilization_pct}%",
            },
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"status": "error", "detail": str(e)}
        )

