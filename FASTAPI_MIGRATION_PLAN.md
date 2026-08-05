# FastAPI Migration Plan — Full Backend Switch

## Overview
Migrate all 70 Next.js API routes to FastAPI in one deploy (big-bang cutover).

## Architecture After Migration

```
┌──────────────────────────────────────────────────────┐
│              Frontend (Next.js 16)                    │
│  - All UI pages (SSR + Client) stay as-is            │
│  - Calls FastAPI via NEXT_PUBLIC_API_URL             │
│                                                       │
│  Removed:                                            │
│  ✗ src/app/api/** (70 routes deleted)                │
│  ✗ @prisma/client (backend uses SQLAlchemy)          │
└──────────────────────┬───────────────────────────────┘
                       │ HTTP/REST (JSON)
                       ↓
┌──────────────────────────────────────────────────────┐
│            FastAPI Backend (Python)                   │
│  Port: 8000                                           │
│                                                       │
│  ✅ Authentication: NextAuth JWT validation          │
│  ✅ Authorization: Role-based guards                 │
│  ✅ CORS: Allow Next.js origin                       │
│  ✅ Error handling: Global exception handler          │
│  ✅ All 70 API routes                                 │
│  ✅ Real-time: SSE + WebSocket                       │
│  ✅ ML/AI: Demand forecasting (existing)             │
│  ✅ Database: PostgreSQL via SQLAlchemy               │
│  ✅ Cache: Redis (optional)                           │
└──────────────────────┬───────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────┐
│         PostgreSQL (shared with Prisma)               │
│  - Same DB, same tables                               │
│  - Prisma ORM for admin scripts only                  │
│  - SQLAlchemy ORM for FastAPI                         │
└──────────────────────────────────────────────────────┘
```

## Database Strategy: Shared PostgreSQL

### Why Shared DB?
- **Zero downtime**: No data migration needed
- **Single source of truth**: Same tables
- **Easy rollback**: Just revert NEXT_PUBLIC_API_URL
- **Prisma migrations still work**: Use `npx prisma migrate` for schema changes

### SQLAlchemy Models
- Mirror Prisma schema in `fastapi-backend/models.py`
- Add missing columns: `deletedAt`, `blockReason`, `blockedAt`, `isB2B`, etc.
- Keep both ORMs in sync manually

## Migration Phases

### **Phase 15.1: FastAPI Foundation (2-3 hours)**
**Goal:** FastAPI server ready to accept all requests

**Tasks:**
1. Update SQLAlchemy models to match Prisma schema
   - Add: `deletedAt`, `deletedAt` index
   - Add: `User.blockReason`, `User.blockedAt`
   - Add: `Order.isB2B`, `Order.shopName`, `Order.shopPhone`
   - Add: `Product.isFlashDeal`, `Product.isTopPick`, `Product.isBestSeller`
   - Add: `OrderItem.mrp`, `OrderItem.costPrice`
   - Add: `RiderWallet`, `CashDepositTransaction`
   - Add: `StoreSetting` model
   - Add: `ProductImage`, `ProductBatch` (if needed)

2. Setup JWT validation middleware
   - Read NextAuth JWT secret from `AUTH_SECRET`
   - Validate token on every request
   - Extract: `userId`, `role`, `email`, `phone`
   - Attach `current_user` to request state

3. Add role-based authorization decorators
   - `@require_admin`
   - `@require_staff`
   - `@require_authenticated`

4. Setup CORS for Next.js origin
   - Allow `NEXT_PUBLIC_APP_URL`
   - Allow credentials

### **Phase 15.2: Core API Routes (3-4 hours)**
**Goal:** Implement 40 essential routes

**Priority order:**
1. Auth routes (5)
   - POST /api/auth/login (email/password)
   - POST /api/auth/signup
   - POST /api/auth/otp/send
   - POST /api/auth/otp/verify
   - GET /api/auth/email/check

2. User routes (4)
   - GET /api/profile
   - POST /api/profile/setup
   - POST /api/profile/update-phone
   - POST /api/profile/update-email

3. Product routes (5)
   - GET /api/products
   - GET /api/products/{id}
   - GET /api/products/buy-again
   - GET /api/products/live-stock
   - GET /api/products/validate-cart

4. Cart routes (2)
   - GET /api/cart
   - POST /api/cart/add
   - DELETE /api/cart/remove
   - POST /api/cart/apply-coupon

5. Order routes (6)
   - POST /api/orders
   - GET /api/orders
   - GET /api/orders/{id}
   - PATCH /api/orders/{id} (cancel)
   - POST /api/orders/{id}/live
   - GET /api/orders/{id}/qr

6. Address routes (2)
   - GET /api/addresses
   - POST /api/addresses
   - PUT /api/addresses/{id}
   - DELETE /api/addresses/{id}

7. Coupon routes (2)
   - GET /api/coupons
   - POST /api/coupons/validate

8. Settings routes (1)
   - GET /api/settings

9. Upload routes (1)
   - POST /api/upload

10. Banners routes (1)
    - GET /api/banners

11. Categories routes (3)
    - GET /api/categories
    - GET /api/categories/{id}
    - GET /api/categories/sort-rule

12. Restaurant routes (2)
    - GET /api/restaurants
    - GET /api/restaurants/{id}
    - GET /api/restaurants/{id}/reviews

### **Phase 15.3: Admin API Routes (2-3 hours)**
**Goal:** Implement 35 admin routes

**Sub-routers:**
1. `/api/admin/users` (5 routes)
   - GET / (list)
   - GET /{id}
   - POST /assignable
   - PATCH /{id}/block
   - GET /{id}/addresses

2. `/api/admin/products` (6 routes)
   - GET /
   - POST /
   - PUT /{id}
   - DELETE /{id}
   - POST /bulk-import
   - POST /bulk-sort

3. `/api/admin/orders` (5 routes)
   - GET /
   - GET /{id}
   - POST /create-on-behalf
   - DELETE /delete-cancelled
   - PATCH /{id}/status

4. `/api/admin/categories` (2 routes)
   - GET /
   - PUT /{id}/sort-rule

5. `/api/admin/banners` (3 routes)
   - GET /
   - POST /
   - PUT /{id}
   - DELETE /{id}

6. `/api/admin/coupons` (5 routes)
   - GET /
   - POST /
   - PUT /{id}
   - DELETE /{id}
   - POST /validate

7. `/api/admin/inventory` (4 routes)
   - GET /pos-checkout
   - GET /history
   - POST /import
   - GET /master-lookup

8. `/api/admin/settings` (1 route)
   - GET /
   - PUT /

9. `/api/admin/stores` (2 routes)
   - GET /
   - PUT /{id}

10. `/api/admin/reports` (1 route)
    - GET /

11. `/api/admin/reviews` (2 routes)
    - GET /
    - DELETE /{id}

12. `/api/admin/push-notifications` (2 routes)
    - POST /send
    - POST /subscribe

13. `/api/admin/alerts` (1 route)
    - GET /

14. `/api/admin/payouts` (2 routes)
    - GET /
    - POST /

15. `/api/admin/rider-cash` (2 routes)
    - GET /
    - POST /

16. `/api/admin/inward` (1 route)
    - POST /

17. `/api/admin/live-carts` (2 routes)
    - GET /
    - POST /notify

18. `/api/admin/restaurant-sales` (1 route)
    - GET /

### **Phase 15.4: Special Routes (1-2 hours)**
**Goal:** Handle SSE, WebSocket, cron, payment callbacks

1. SSE routes
   - GET /api/sse/orders (Server-Sent Events)

2. WebSocket routes
   - WS /api/ws/orders/{order_id}

3. Cron routes
   - GET /api/cron/keep-alive

4. Payment routes (Paytm mock)
   - POST /api/payment/paytm/initiate
   - POST /api/payment/paytm/callback
   - POST /api/payment/paytm/mock-success

5. Delivery-specific routes
   - GET /api/delivery-check
   - POST /api/delivery/location
   - GET /api/delivery/orders
   - GET /api/delivery/orders/{id}/qr

6. Picker routes
   - GET /api/picker/orders

7. Cafe/Restaurant dashboard
   - GET /api/restaurant-dashboard/orders
   - GET /api/restaurant-dashboard/products
   - GET /api/restaurant-dashboard/products/{id}
   - GET /api/restaurant-dashboard/stats
   - GET /api/cafe/reports
   - GET /api/restaurant/reports

### **Phase 15.5: Frontend Integration (1-2 hours)**
**Goal:** Next.js calls FastAPI instead of its own API routes

**Changes:**
1. Update `NEXT_PUBLIC_API_URL` in `.env`
   - Development: `http://localhost:8000`
   - Production: `https://api.fastkirana.in`

2. Create `src/lib/api-client.ts`
   - Wrapper around `fetch()` that:
     - Adds `Authorization: Bearer <token>` from session
     - Adds base URL from env
     - Handles errors uniformly
     - Parses JSON responses

3. Replace all `fetch('/api/...')` calls in Next.js pages
   - Use regex to find all fetch calls
   - Replace with `apiClient.get('/api/...')` or similar

4. Remove Next.js API routes
   - Move all route.ts files to backup folder
   - Keep `src/app/api/auth/[...nextauth]/route.ts` (NextAuth needs it)
   - Delete all other 69 route.ts files

5. Update `next.config.ts`
   - Remove API rewrites (if any)
   - Ensure API proxy is not used

### **Phase 15.6: Testing & Deploy (1-2 hours)**
**Goal:** Production-ready deployment

**Tests:**
1. Unit tests for each FastAPI route
2. Integration tests (order flow, auth flow, admin flow)
3. Load test (100 concurrent orders)
4. Security test (JWT validation, CORS, rate limiting)

**Deploy:**
1. Deploy FastAPI to Render/Railway (existing render.yaml exists)
2. Deploy Next.js to Vercel
3. Update DNS to point api.fastkirana.in to FastAPI
4. Smoke test all features
5. Monitor logs for 24 hours

## Files to Create/Modify

### FastAPI Backend
```
fastapi-backend/
├── main.py (update: add new routers)
├── config.py (update: add AUTH_SECRET, DB_URL)
├── database.py (update: SQLAlchemy async engine)
├── models.py (update: add all Prisma models)
├── schemas.py (update: add all request/response schemas)
├── requirements.txt (update: add pyjwt, bcrypt, python-multipart)
├── routers/
│   ├── __init__.py (update)
│   ├── auth.py (expand)
│   ├── products.py (expand)
│   ├── orders.py (expand)
│   ├── delivery.py (expand)
│   ├── admin.py (expand)
│   ├── forecast.py (keep)
│   ├── websockets.py (keep)
│   ├── users.py (new)
│   ├── cart.py (new)
│   ├── addresses.py (new)
│   ├── coupons.py (new)
│   ├── settings.py (new)
│   ├── upload.py (new)
│   ├── banners.py (new)
│   ├── categories.py (new)
│   ├── restaurants.py (new)
│   ├── reviews.py (new)
│   ├── push.py (new)
│   ├── paytm.py (new)
│   ├── picker.py (new)
│   ├── restaurant_dashboard.py (new)
│   ├── sse.py (new)
│   └── cron.py (new)
├── middleware/
│   ├── __init__.py (new)
│   ├── auth.py (new: JWT validation)
│   └── cors.py (new: CORS handling)
├── utils/
│   ├── __init__.py (new)
│   ├── jwt.py (new: JWT encode/decode)
│   ├── security.py (new: password hashing)
│   └── helpers.py (new: phone normalization, etc.)
└── tests/
    └── (update)
```

### Next.js Frontend
```
src/
├── lib/
│   └── api-client.ts (NEW: fetch wrapper)
├── app/api/ (DELETE 69 routes, keep auth)
│   └── auth/[...nextauth]/route.ts (KEEP)
├── .env (UPDATE: add NEXT_PUBLIC_API_URL)
└── next.config.ts (UPDATE: remove API rewrites)
```

## Estimated Timeline

| Phase | Tasks | Time |
|-------|-------|------|
| 15.1: Foundation | Models + JWT + CORS | 2-3 hours |
| 15.2: Core APIs | 40 routes | 3-4 hours |
| 15.3: Admin APIs | 35 routes | 2-3 hours |
| 15.4: Special routes | SSE + WS + cron | 1-2 hours |
| 15.5: Frontend integration | api-client.ts + migration | 1-2 hours |
| 15.6: Testing + Deploy | Unit + integration + deploy | 1-2 hours |
| **Total** | **~130 routes** | **10-16 hours** |

## Risk Mitigation

1. **Zero data loss**: Same DB, no migration
2. **Easy rollback**: Change NEXT_PUBLIC_API_URL back to Next.js
3. **Gradual testing**: Test each router before moving to next
4. **Staging environment**: Test on staging before production

## Next Steps

1. Confirm plan with you
2. Start Phase 15.1: Update FastAPI models
3. Migrate routes in batches
4. Test each batch
5. Cutover

---

**Ready to start?** 🚀
