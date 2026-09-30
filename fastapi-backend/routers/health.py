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

    # 4. Server Uptime Calculation
    uptime_seconds = int(time.time() - SERVER_BOOT_TIME)
    days = uptime_seconds // 86400
    hours = (uptime_seconds % 86400) // 3600
    minutes = (uptime_seconds % 3600) // 60
    secs = uptime_seconds % 60
    uptime_human = f"{days}d {hours}h {minutes}m {secs}s" if days > 0 else f"{hours}h {minutes}m {secs}s"

    # 5. Connection Pool Metrics
    pool_stats = {}
    try:
        from database import engine
        pool = engine.pool
        size = pool.size()
        checked_out = pool.checkedout()
        overflow = pool.overflow()
        max_overflow = getattr(pool, "_max_overflow", 10)
        pool_stats = {
            "size": size,
            "checkedIn": pool.checkedin(),
            "checkedOut": checked_out,
            "overflow": overflow,
            "maxOverflow": max_overflow,
            "totalActive": checked_out + overflow,
            "utilization": f"{round((checked_out / max(size, 1)) * 100)}%",
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


from fastapi.responses import PlainTextResponse

@health_router.get("/metrics", response_class=PlainTextResponse)
@health_router.get("/api/metrics", response_class=PlainTextResponse)
async def prometheus_metrics():
    """
    Standard Prometheus / Grafana metrics exporter endpoint.
    Exposes real-time DB connection pool stats, active WebSockets, and system uptime.
    Scrapeable by Prometheus, Grafana Cloud, Datadog, or Railway metrics.
    """
    lines = []
    
    # 1. System Uptime
    uptime_sec = int(time.time() - SERVER_BOOT_TIME)
    lines.append("# HELP fastkirana_uptime_seconds Total seconds since FastAPI server boot")
    lines.append("# TYPE fastkirana_uptime_seconds gauge")
    lines.append(f"fastkirana_uptime_seconds {uptime_sec}")
    lines.append("")

    # 2. Database Connection Pool Metrics
    try:
        from database import engine
        pool = engine.pool
        size = pool.size()
        checked_in = pool.checkedin()
        checked_out = pool.checkedout()
        overflow = pool.overflow()
        max_overflow = getattr(pool, "_max_overflow", 10)
        utilization = round(checked_out / max(size, 1), 4)

        lines.append("# HELP fastkirana_db_pool_size Configured SQLAlchemy connection pool size")
        lines.append("# TYPE fastkirana_db_pool_size gauge")
        lines.append(f"fastkirana_db_pool_size {size}")
        lines.append("")

        lines.append("# HELP fastkirana_db_pool_checked_in Idle database connections in pool")
        lines.append("# TYPE fastkirana_db_pool_checked_in gauge")
        lines.append(f"fastkirana_db_pool_checked_in {checked_in}")
        lines.append("")

        lines.append("# HELP fastkirana_db_pool_checked_out Active database connections in use")
        lines.append("# TYPE fastkirana_db_pool_checked_out gauge")
        lines.append(f"fastkirana_db_pool_checked_out {checked_out}")
        lines.append("")

        lines.append("# HELP fastkirana_db_pool_overflow Active overflow connections beyond pool size")
        lines.append("# TYPE fastkirana_db_pool_overflow gauge")
        lines.append(f"fastkirana_db_pool_overflow {overflow}")
        lines.append("")

        lines.append("# HELP fastkirana_db_pool_max_overflow Maximum allowed overflow connections")
        lines.append("# TYPE fastkirana_db_pool_max_overflow gauge")
        lines.append(f"fastkirana_db_pool_max_overflow {max_overflow}")
        lines.append("")

        lines.append("# HELP fastkirana_db_pool_utilization_ratio Database connection pool utilization ratio (0.0 to 1.0)")
        lines.append("# TYPE fastkirana_db_pool_utilization_ratio gauge")
        lines.append(f"fastkirana_db_pool_utilization_ratio {utilization}")
        lines.append("")
    except Exception as e:
        lines.append(f"# Error collecting DB pool metrics: {e}")

    # 3. Active Real-time WebSocket Metrics
    try:
        from routers.websockets import manager
        ws_channels = len(manager.active_connections)
        ws_clients = sum(len(conns) for conns in manager.active_connections.values())

        lines.append("# HELP fastkirana_websocket_active_channels Number of active WebSocket channels")
        lines.append("# TYPE fastkirana_websocket_active_channels gauge")
        lines.append(f"fastkirana_websocket_active_channels {ws_channels}")
        lines.append("")

        lines.append("# HELP fastkirana_websocket_active_clients Number of active real-time WebSocket clients")
        lines.append("# TYPE fastkirana_websocket_active_clients gauge")
        lines.append(f"fastkirana_websocket_active_clients {ws_clients}")
        lines.append("")
    except Exception:
        pass

    return PlainTextResponse("\n".join(lines) + "\n", media_type="text/plain; version=0.0.4; charset=utf-8")


