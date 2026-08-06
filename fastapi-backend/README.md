# FastKirana FastAPI Backend

High-performance Python FastAPI microservice for FastKirana e-commerce platform.

## 🚀 Quick Start

### Option 1: One-Click Start (Windows)
```bash
start.bat
```

### Option 2: Manual
```bash
# Create virtual environment
python -m venv venv

# Activate
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your DATABASE_URL and AUTH_SECRET

# Initialize database (creates tables)
python init_db.py

# Start server
uvicorn main:app --reload
```

## 📍 Endpoints

- **Swagger docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health check**: http://localhost:8000/health

## 📂 Project Structure

```
fastapi-backend/
├── main.py                 # FastAPI app entry point
├── config.py               # Environment configuration
├── database.py             # Async SQLAlchemy engine
├── models.py               # Database ORM models
├── init_db.py              # Table creation script
├── start.bat               # Windows quick start
├── requirements.txt        # Python dependencies
├── .env.example            # Environment template
└── routers/                # API endpoint modules
    ├── auth.py             # Login, signup, OTP
    ├── products.py         # Products & categories
    ├── cart.py             # Shopping cart
    ├── orders.py           # Order creation & tracking
    ├── addresses.py        # User addresses
    ├── payments.py         # Payment verification
    ├── paytm.py            # Paytm gateway
    ├── delivery.py         # Delivery & rider wallet
    ├── picker.py           # Picker/chef orders
    ├── restaurant.py       # Restaurants & cafe
    ├── admin.py            # Admin (rider cash, dashboard)
    ├── admin_extended.py   # Admin (products, orders, etc.)
    ├── profile.py          # User profile
    ├── settings.py         # Store settings & location
    ├── forecast.py         # AI demand forecasting
    ├── orders_helper.py    # Order helpers
    ├── products_helper.py  # Product helpers
    ├── public.py           # Public endpoints
    └── websockets.py       # WebSocket connections
```

## 🔑 Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL connection string |
| `AUTH_SECRET` | ✅ | JWT signing secret (32+ chars) |
| `NEXT_PUBLIC_APP_URL` | ✅ | Frontend URL (CORS) |
| `REDIS_URL` | ❌ | Redis cache (optional) |
| `SENTRY_DSN` | ❌ | Sentry monitoring (optional) |
| `PAYTM_MID` | ❌ | Paytm Merchant ID |
| `PAYTM_MERCHANT_KEY` | ❌ | Paytm Merchant Key |
| `GOOGLE_MAPS_API_KEY` | ❌ | Google Maps API |

## 🗄️ Database

PostgreSQL required (12+).

**Local**: https://www.postgresql.org/download/
**Cloud**: https://neon.tech (free tier)

## 📝 API Routes

Total **79+ endpoints** migrated from Next.js API.

See Swagger docs for full list: http://localhost:8000/docs

## 🔐 Authentication

JWT-based with role guards:
- `require_auth` — Any authenticated user
- `require_admin` — ADMIN only
- `require_delivery` — DELIVERY/ADMIN
- `require_staff` — All staff roles

## 📜 License

MIT