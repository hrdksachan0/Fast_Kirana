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
    db_status = "connected"
    latency_ms = None
    try:
        await db.execute(select(1))
        latency_ms = round((time.time() - start_time) * 1000, 2)
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return {
        "status": "healthy" if db_status == "connected" else "degraded",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "fastapi-backend",
        "database": {
            "status": db_status,
            "latencyMs": latency_ms
        }
    }
