from fastapi import FastAPI, Request, Depends
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

from utils.logging_config import setup_logging
logger = setup_logging(settings.APP_ENV)

from contextlib import asynccontextmanager
from fastapi_cache import FastAPICache
from fastapi_cache.backends.inmemory import InMemoryBackend

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Warm up PostgreSQL Connection Pool (Zero Cold Starts)
    try:
        from database import engine
        from sqlalchemy import text
        async with engine.begin() as conn:
            await conn.execute(text("SELECT 1"))
        logger.info("[Lifespan] PostgreSQL connection pool warmed up successfully.")
    except Exception as e:
        logger.warning(f"[Lifespan] DB pool warmup skipped/failed: {e}")

    # 2. Initialize high-performance caching (Redis if configured, otherwise fast in-memory)
    if settings.REDIS_URL:
        try:
            from redis import asyncio as aioredis
            from fastapi_cache.backends.redis import RedisBackend
            redis = aioredis.from_url(settings.REDIS_URL)
            FastAPICache.init(RedisBackend(redis), prefix="fastkirana-cache")
            logger.info("[Lifespan] Redis cache initialized.")
        except Exception:
            FastAPICache.init(InMemoryBackend(), prefix="fastkirana-cache")
    else:
        FastAPICache.init(InMemoryBackend(), prefix="fastkirana-cache")

    # 3. Initialize WebSocket Redis Pub/Sub for multi-worker scaling
    try:
        from routers.websockets import manager as ws_manager
        await ws_manager.start()
    except Exception as e:
        logger.warning(f"[Lifespan] WebSocket Redis Pub/Sub initialization skipped: {e}")

    yield

    # 4. Graceful Shutdown: Stop WebSocket Pub/Sub & Dispose DB connection pool cleanly
    try:
        from routers.websockets import manager as ws_manager
        await ws_manager.stop()
    except Exception:
        pass

    try:
        from database import engine
        await engine.dispose()
        logger.info("[Lifespan] Database connection pool disposed cleanly.")
    except Exception:
        pass

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

# High-Performance Response Compression: Compress all HTTP responses >= 1000 bytes by ~75%
from starlette.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)

import uuid

# Configure SlowAPI Route Rate Limiter (with fallback if dependency pending)
try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.util import get_remote_address
    from slowapi.errors import RateLimitExceeded
    limiter = Limiter(key_func=get_remote_address)
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
except ImportError:
    limiter = None

# Configure CORS Middleware for Web & Mobile
_cors_origins = [
    "https://fastkirana.in",
    "https://www.fastkirana.in",
    "https://admin.fastkirana.in",
    "https://store.fastkirana.in",
    "https://api.fastkirana.in",
]
_env_domains = [d.strip() for d in os.getenv("CORS_ORIGINS", "").split(",") if d.strip()]
if _env_domains:
    _cors_origins.extend(_env_domains)

if settings.APP_ENV != "production":
    _cors_origins.extend([
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://localhost:5173",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
    ])

_cors_allow_all = os.getenv("CORS_ALLOW_ALL", "false").lower() == "true"

from services.tracer_service import TracerService

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _cors_allow_all else _cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "x-user-id",
        "x-user-role",
        "x-user-email",
        "x-user-phone",
        "x-internal-secret",
        "x-store-id",
        "x-request-id",
        "x-trace-id",
        "traceparent",
    ],
    expose_headers=["x-process-time", "x-request-id", "x-trace-id", "traceparent"],
)

# In-memory sliding window rate limiter for public scraper protection
_ip_request_history: dict = {}
_MAX_REQUESTS_PER_MINUTE = 200

# Middleware for Request Correlation ID, Enterprise Security Headers, Rate Limiting & Distributed Tracing
@app.middleware("http")
async def enterprise_security_and_tracing_middleware(request: Request, call_next):
    # 1. Request Correlation ID & W3C Distributed Tracing
    request_id = request.headers.get("x-request-id") or f"req-{uuid.uuid4().hex[:10]}"
    request.state.request_id = request_id

    trace_info = TracerService.parse_trace_headers(dict(request.headers))
    trace_id = trace_info["trace_id"]
    parent_span_id = trace_info.get("parent_span_id")
    request.state.trace_id = trace_id

    span = TracerService.start_span(
        name="fastapi_http_request",
        trace_id=trace_id,
        parent_span_id=parent_span_id,
        attributes={"path": request.url.path, "method": request.method},
    )
    request.state.trace_span = span

    # 2. Public Scraper & Abuse Rate Limiting (exclude health, probes, docs, webhooks)
    path = request.url.path
    if not (path.startswith("/health") or path.startswith("/readyz") or path.startswith("/api/readyz") or path.startswith("/api/healthz") or path.startswith("/docs") or path.startswith("/openapi") or path.startswith("/ws") or "webhook" in path):
        client_ip = request.client.host if request.client else "unknown"
        now_ts = time.time()
        history = [ts for ts in _ip_request_history.get(client_ip, []) if now_ts - ts < 60]
        if len(history) >= _MAX_REQUESTS_PER_MINUTE:
            span.end(extra_attributes={"rate_limited": True})
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "error": "Too Many Requests",
                    "message": "Rate limit exceeded. Please try again in a few seconds.",
                    "requestId": request_id,
                    "traceId": trace_id,
                },
                headers={
                    "Retry-After": "30",
                    "X-Request-ID": request_id,
                    "X-Trace-Id": trace_id,
                    "traceparent": span.traceparent,
                }
            )
        history.append(now_ts)
        _ip_request_history[client_ip] = history

    # 3. Execution Timing
    start_time = time.perf_counter()
    try:
        response = await call_next(request)
        process_time = time.perf_counter() - start_time
        span.end(extra_attributes={"status_code": response.status_code, "duration_ms": process_time * 1000})
    except Exception as exc:
        process_time = time.perf_counter() - start_time
        span.end(extra_attributes={"duration_ms": process_time * 1000}, error=str(exc))
        raise exc

    # 4. Observability & Tracing Headers
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = f"{process_time:.4f}s"
    response.headers["X-Trace-Id"] = trace_id
    response.headers["traceparent"] = span.traceparent

    # 5. Enterprise Security Headers (Clickjacking, MIME-sniffing, XSS protection)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    return response

from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.exceptions import RequestValidationError

# Global Exception Handlers for transparent, actionable UX feedback
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    detail_str = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    req_id = getattr(request.state, "request_id", None)
    return ORJSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": detail_str,
            "detail": detail_str,
            "message": detail_str,
            "statusCode": exc.status_code,
            "requestId": req_id
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
    req_id = getattr(request.state, "request_id", None)
    
    return ORJSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": summary,
            "detail": summary,
            "message": summary,
            "rawErrors": errors,
            "statusCode": 422,
            "requestId": req_id
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    correlation_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    logger.error(f"CRITICAL ERROR [ReqID: {correlation_id}] on {request.url}: {exc}")
    if settings.SENTRY_DSN:
        sentry_sdk.capture_exception(exc)
    err_str = str(exc) or "An internal server error occurred. Please contact support."
    return ORJSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": err_str,
            "detail": err_str,
            "message": err_str,
            "correlationId": correlation_id,
            "requestId": correlation_id,
            "statusCode": 500
        }
    )

# OpenAPI Swagger Customization: Adds 'Authorize 🔓' button for JWT testing
from fastapi.openapi.utils import get_openapi

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"] = openapi_schema.get("components", {})
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Enter your JWT token to authorize admin and protected endpoints directly in Swagger UI."
        }
    }
    openapi_schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

# Include API Routers (Standardized on /api prefix)
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
app.include_router(restaurant.router)  # Already defines prefix="/api"
app.include_router(restaurant.restaurant_router, prefix="/api")
app.include_router(restaurant.cafe_router, prefix="/api")
app.include_router(restaurant.restaurant_report_router, prefix="/api")
app.include_router(picker.picker_router, prefix="/api")
app.include_router(profile.router, prefix="/api")
app.include_router(banners.router, prefix="/api")
app.include_router(store_settings_router.router, prefix="/api")
app.include_router(store_settings_router.router)
app.include_router(store_settings_router.location_router, prefix="/api")
app.include_router(orders_helper.helper_router, prefix="/api")
app.include_router(products_helper.helper_router, prefix="/api")
app.include_router(products_helper.search_router, prefix="/api")
app.include_router(public.router)  # Already defines prefix="/api"
app.include_router(paytm.router)   # Already defines prefix="/api/payment/paytm"
app.include_router(fcm.router, prefix="/api")
app.include_router(categories.router, prefix="/api")

from routers import cashfree_router, kot, vendors, stores_service, wishlist, push
app.include_router(vendors.vendors_router, prefix="/api")
app.include_router(vendors.vendors_router, prefix="/api/admin")
app.include_router(stores_service.router, prefix="/api")
app.include_router(wishlist.router, prefix="/api")
app.include_router(push.router, prefix="/api")
app.include_router(websockets.sse_router, prefix="/api")
app.include_router(admin.superadmin_router, prefix="/api")
app.include_router(cashfree_router.router, prefix="/api")
app.include_router(kot.router, prefix="/api")
app.include_router(upload.router, prefix="/api")
app.include_router(cron.router, prefix="/api")
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

@app.get("/healthz", tags=["Health"], summary="Kubernetes / Docker Liveness Probe")
async def liveness_probe():
    """
    Kubernetes / Docker Liveness Probe.
    Returns HTTP 200 immediately if Python process and ASGI event loop are responsive.
    Does not touch database or external services to avoid cascading restart loops.
    """
    return await health.liveness_check()

from database import get_db
from sqlalchemy.ext.asyncio import AsyncSession

@app.get("/readyz", tags=["Health"], summary="Kubernetes / Docker Readiness Probe")
async def readiness_probe(db: AsyncSession = Depends(get_db)):
    """
    Kubernetes / Docker Readiness Probe.
    Verifies active connectivity to:
    1. PostgreSQL database pool (SELECT 1).
    2. Redis cache & Pub/Sub (redis.ping()) if configured.
    Returns HTTP 200 if ready; HTTP 503 if DB or configured cache is disconnected.
    """
    return await health.readiness_check(db=db)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
