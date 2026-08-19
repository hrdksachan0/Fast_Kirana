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
    start_time = time.time()
    try:
        await db.execute(select(1))
        latency_ms = round((time.time() - start_time) * 1000, 2)
        return {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": "fastapi-backend",
            "database": {
                "status": "connected",
                "latencyMs": latency_ms
            }
        }
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "service": "fastapi-backend",
                "error": str(e)
            }
        )
