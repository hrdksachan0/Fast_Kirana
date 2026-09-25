from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, ORJSONResponse
import os
import time
from config import settings
from routers import products, delivery, admin, admin_extended, forecast, orders, websockets, auth, cart, addresses, payments, restaurant, picker, profile, settings as store_settings_router, orders_helper, products_helper, public, paytm, fcm, categories, banners, restaurants, coupons, health, upload, cron

try:
    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration
    if settings.SENTRY_DSN:
        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.APP_ENV,
            traces_sample_rate=0.2,
            integrations=[
                StarletteIntegration(transaction_style="endpoint"),
                FastApiIntegration(transaction_style="endpoint"),
            ],
        )
except ImportError:
    sentry_sdk = None

from contextlib import asynccontextmanager
from fastapi_cache import FastAPICache
from fastapi_cache.backends.inmemory import InMemoryBackend

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize high-performance caching (Redis if configured, otherwise fast in-memory)
    if settings.REDIS_URL:
        try:
            from redis import asyncio as aioredis
            from fastapi_cache.backends.redis import RedisBackend
            redis = aioredis.from_url(settings.REDIS_URL)
            FastAPICache.init(RedisBackend(redis), prefix="fastkirana-cache")
        except Exception:
            FastAPICache.init(InMemoryBackend(), prefix="fastkirana-cache")
    else:
        FastAPICache.init(InMemoryBackend(), prefix="fastkirana-cache")
    yield

from starlette.types import ASGIApp, Scope, Receive, Send

class TrailingSlashMiddleware:
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http" and scope["path"] != "/" and scope["path"].endswith("/"):
            scope["path"] = scope["path"].rstrip("/")
        await self.app(scope, receive, send)

app = FastAPI(
    title=settings.APP_NAME,
    description="High-Performance Python FastAPI Microservice for FastKirana E-Commerce, AI Demand Forecasting, Real-Time WebSockets, & Rider Wallet Ledger.",
    version="2.0.0",
    docs_url="/docs" if settings.APP_ENV != "production" else "/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
    redirect_slashes=True,
    default_response_class=ORJSONResponse,
)

app.add_middleware(TrailingSlashMiddleware)

from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")

import uuid

# Configure CORS Middleware for Web & Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# GZip Compression Middleware (Reduces payload size by ~80% for fast mobile load)
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Middleware for Process Time Header & Request Logging
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = f"{process_time:.4f}s"
    return response

from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.exceptions import RequestValidationError
import uuid

# Global Exception Handlers for transparent, actionable UX feedback
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    detail_str = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": detail_str,
            "detail": detail_str,
            "message": detail_str,
            "statusCode": exc.status_code
        },
        headers=getattr(exc, "headers", None)
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    error_messages = []
    for err in errors:
        loc = " -> ".join([str(l) for l in err.get("loc", []) if l != "body"])
        msg = err.get("msg", "Invalid value")
        error_messages.append(f"{loc}: {msg}" if loc else msg)
    summary = "; ".join(error_messages) if error_messages else "Invalid request data"
    
    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": summary,
            "detail": summary,
            "message": summary,
            "rawErrors": errors,
            "statusCode": 422
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    correlation_id = str(uuid.uuid4())
    print(f"CRITICAL ERROR [CorrelationID: {correlation_id}] on {request.url}: {exc}")
    if settings.SENTRY_DSN:
        sentry_sdk.capture_exception(exc)
    err_str = str(exc) or "An internal server error occurred. Please contact support."
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": err_str,
            "detail": err_str,
            "message": err_str,
            "correlationId": correlation_id,
            "statusCode": 500
        }
    )

# Include API Routers
app.include_router(products.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(delivery.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(admin_extended.router, prefix="/api")
app.include_router(forecast.router, prefix="/api")
app.include_router(websockets.router, prefix="/api")
app.include_router(websockets.router)
app.include_router(auth.router, prefix="/api")
app.include_router(coupons.router, prefix="/api")
app.include_router(cart.router, prefix="/api")
app.include_router(addresses.router, prefix="/api")
app.include_router(payments.router, prefix="/api")
app.include_router(restaurants.router, prefix="/api")
app.include_router(restaurant.router)
app.include_router(restaurant.restaurant_router, prefix="/api")
app.include_router(restaurant.restaurant_router)
app.include_router(restaurant.cafe_router, prefix="/api")
app.include_router(restaurant.cafe_router)
app.include_router(restaurant.restaurant_report_router, prefix="/api")
app.include_router(restaurant.restaurant_report_router)
app.include_router(picker.picker_router, prefix="/api")
app.include_router(picker.picker_router)
app.include_router(profile.router, prefix="/api")
app.include_router(banners.router, prefix="/api")
app.include_router(store_settings_router.router)
app.include_router(store_settings_router.router, prefix="/api")
app.include_router(store_settings_router.location_router, prefix="/api")
app.include_router(orders_helper.helper_router, prefix="/api")
app.include_router(products_helper.helper_router, prefix="/api")
app.include_router(products_helper.search_router, prefix="/api")
app.include_router(products_helper.search_router)
app.include_router(public.router)
app.include_router(paytm.router)
app.include_router(fcm.router, prefix="/api")
app.include_router(categories.router, prefix="/api")

from routers import razorpay_router, cashfree_router, kot, vendors, stores_service, wishlist, push
app.include_router(vendors.vendors_router, prefix="/api")
app.include_router(vendors.vendors_router, prefix="/api/admin")
app.include_router(stores_service.router, prefix="/api")
app.include_router(stores_service.router)
app.include_router(wishlist.router, prefix="/api")
app.include_router(wishlist.router)
app.include_router(push.router, prefix="/api")
app.include_router(push.router)
app.include_router(websockets.sse_router, prefix="/api")
app.include_router(websockets.sse_router)
app.include_router(admin.superadmin_router, prefix="/api")
app.include_router(admin.superadmin_router)
app.include_router(razorpay_router.router, prefix="/api")
app.include_router(razorpay_router.router)
app.include_router(cashfree_router.router, prefix="/api")
app.include_router(cashfree_router.router)
app.include_router(kot.router, prefix="/api")
app.include_router(kot.router)
app.include_router(upload.router, prefix="/api")
app.include_router(cron.router, prefix="/api")
app.include_router(cron.router)
app.include_router(health.health_router)

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
