from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import os
import time
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

from config import settings
from routers import products, delivery, admin, forecast, orders, websockets, auth, cart, addresses, payments

# Initialize Sentry Error Monitoring if DSN is set
if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.APP_ENV,
        traces_sample_rate=0.2,
        integrations=[
            StarletteIntegration(transaction_style="endpoint"),
            FastApiIntegration(at_exit=True),
        ],
    )

app = FastAPI(
    title=settings.APP_NAME,
    description="High-Performance Python FastAPI Microservice for FastKirana E-Commerce, AI Demand Forecasting, Real-Time WebSockets, & Rider Wallet Ledger.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

import uuid

# Configure CORS Middleware for Next.js Frontend
app_origin = os.getenv("NEXT_PUBLIC_APP_URL", "http://localhost:3000")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[app_origin, "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware for Process Time Header & Request Logging
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = f"{process_time:.4f}s"
    return response

# Global Exception Handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    correlation_id = str(uuid.uuid4())
    print(f"CRITICAL ERROR [CorrelationID: {correlation_id}] on {request.url}: {exc}")
    if settings.SENTRY_DSN:
        sentry_sdk.capture_exception(exc)
    return JSONResponse(
        status_code=500,
        content={"error": "An internal server error occurred. Please contact support.", "correlationId": correlation_id}
    )

# Include API Routers
app.include_router(products.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(delivery.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(forecast.router, prefix="/api")
app.include_router(websockets.router, prefix="/api")
app.include_router(websockets.router)
app.include_router(auth.router, prefix="/api")
app.include_router(cart.router, prefix="/api")
app.include_router(addresses.router, prefix="/api")
app.include_router(payments.router, prefix="/api")

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": settings.APP_NAME,
        "environment": settings.APP_ENV,
        "docs": "/docs",
        "sentryEnabled": bool(settings.SENTRY_DSN),
        "redisConfigured": bool(settings.REDIS_URL)
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "sentry": bool(settings.SENTRY_DSN),
        "redis": bool(settings.REDIS_URL)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
