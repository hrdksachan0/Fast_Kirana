from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time
from config import settings
from routers import products, delivery, admin, forecast, orders, websockets

app = FastAPI(
    title=settings.APP_NAME,
    description="High-Performance Python FastAPI Microservice for FastKirana E-Commerce, AI Demand Forecasting, Real-Time WebSockets, & Rider Wallet Ledger.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS Middleware for Next.js Frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
    print(f"CRITICAL ERROR on {request.url}: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal Server Error", "detail": str(exc)}
    )

# Include API Routers
app.include_router(products.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(delivery.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(forecast.router, prefix="/api")
app.include_router(websockets.router, prefix="/api")

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": settings.APP_NAME,
        "environment": settings.APP_ENV,
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": time.time()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
