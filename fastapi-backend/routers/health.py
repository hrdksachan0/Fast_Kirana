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
