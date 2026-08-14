# FastKirana Technical Architecture Document (TAD)

**Architecture Level:** Enterprise Microservices + Serverless Hybrid  
**Primary Database:** PostgreSQL 15 (Managed Cloud DB)  
**ORM Layer:** Prisma ORM (Next.js) & SQLAlchemy Async (FastAPI)

---

## 1. System Topology & Infrastructure Diagram

```
                 +---------------------------------------+
                 |       Client Access Layer             |
                 |  Next.js Web | Flutter Mobile App     |
                 +-------------------+-------------------+
                                     |
                                     v
                 +-------------------+-------------------+
                 |           API Proxy / Router          |
                 |   Next.js Rewrites / Cloudflare CDN   |
                 +---------+-------------------+---------+
                           |                   |
            +--------------+                   +--------------+
            v                                                 v
+-----------+-------------------+           +-----------------+-----------------+
|      Next.js Node.js API      |           |     FastAPI Async Python Server   |
|   (Web SSR & Server Actions)  |           |     (Mobile App, WebSockets, AI)  |
+-----------+-------------------+           +-----------------+-----------------+
            |                                                 |
            +-------------------+-----------------------------+
                                |
                                v
                +---------------+------------------+
                |     PostgreSQL 15 Database       |
                |  (Shared Schema & Tables)        |
                +---------------+------------------+
                                |
             +------------------+------------------+
             v                                     v
  +----------+---------+                +----------+---------+
  |  Redis Cache / Pub |                |  Sentry Error Log  |
  +--------------------+                +--------------------+
```

---

## 2. Core Service Stack & Responsibilities

### 2.1 Next.js 15 Web Application (`Fastkirana`)
- **Role**: Customer Web Storefront, Admin Dashboard, Web Analytics, NextAuth session management.
- **ORM**: Prisma ORM with PostgreSQL driver.
- **Port**: `3000` (Production: Vercel serverless edge).

### 2.2 FastAPI Microservice (`fastapi-backend/`)
- **Role**: Backend for Flutter Mobile App, Real-Time WebSockets (`/api/ws/...`), AI Demand Forecasting (`/api/forecast`), Rider Cash Ledger, Paytm Integration.
- **ORM**: SQLAlchemy Async (`asyncpg`).
- **Port**: `8000` (Production: Render / AWS EC2).

### 2.3 Shared Database Engine (PostgreSQL)
- Both Next.js and FastAPI connect to the exact same PostgreSQL database instance.
- **Shared Schema Tables**: `users`, `orders`, `order_items`, `products`, `categories`, `addresses`, `restaurants`, `rider_wallets`, `store_settings`.

---

## 3. Database Entity Relationship & Key Schemas

```sql
users (id, email, phone, role, assignedRestaurantId, liveLat, liveLng)
  |
  +--< orders (id, combinedId, userId, addressId, restaurantId, status, subtotal, miscFee, total, deliveryMethod)
        |
        +--< order_items (id, orderId, productId, name, price, quantity, costPrice)
        |
        +--> address (id, label, houseNo, street, area, city, pincode, lat, lng)
```

---

## 4. Real-Time Event Communication

1. **Order Status Updates**:
   - Web App uses Server-Sent Events (SSE) via `/api/orders/[id]/tracking-stream`.
   - Flutter App & Consoles connect to FastAPI WebSocket `/api/ws/orders/[id]`.
2. **KOT Printing & Kitchen Chime**:
   - Web Socket connection streams live order pushes directly to Kitchen Console with dynamic sound alerts.
