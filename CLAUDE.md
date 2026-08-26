# FastKirana — Complete Codebase & System Architecture Guide

> **FastKirana** is an ultra-fast, 10-minute Quick-Commerce & Multi-Restaurant Food Delivery platform built for Tier-2/3 Indian cities (Ghatampur / Kanpur Nagar).

---

## 1. High-Level Architecture Overview

```
                           ┌─────────────────────────────────────────┐
                           │         Supabase PostgreSQL DB          │
                           │   (AWS ap-south-1 • Single Source)      │
                           └──────────────▲───────────────▲──────────┘
                                          │               │
                        Prisma 7.8 (Pooler 6543)    SQLAlchemy Async (Port 5432)
                                          │               │
                     ┌────────────────────┴───┐       ┌───┴─────────────────────┐
                     │   Next.js 16 Backend   │       │   FastAPI Microservice  │
                     │  (Primary REST & SSE)  │       │ (AI Forecast, WS & ML)  │
                     └───────────▲────────────┘       └───────────▲─────────────┘
                                 │                                │
            ┌────────────────────┼────────────────────────────────┘
            │                    │
┌───────────┴────────────┐ ┌─────┴──────────────────┐ ┌─────────────────────────┐
│   Next.js Storefront   │ │  Flutter Mobile App    │ │ Admin / Ops Web Portals │
│  & Responsive Web App  │ │ (iOS, Android, Web)    │ │ • /admin (Master Console│
│  • Food & Groceries    │ │ • Riverpod + Dio       │ │ • /picker (Dark Store)  │
│  • PWA Support         │ │ • Realtime Tracking    │ │ • /delivery (Riders)    │
└────────────────────────┘ └────────────────────────┘ │ • /restaurant-kitchen   │
                                                      └─────────────────────────┘
```

---

## 2. Tech Stack Summary

| Layer | Technologies Used |
| :--- | :--- |
| **Primary Web & Admin** | Next.js 16.2.7 (App Router), React 19.2.4, TailwindCSS v4, Auth.js v5 (NextAuth), Framer Motion, Lucide Icons, Radix UI |
| **Database & ORM** | Hosted PostgreSQL on **Supabase** (Asia South-1 Mumbai), Prisma ORM 7.8 with `@prisma/adapter-pg` pool |
| **Python Microservice** | FastAPI 0.110+, Python 3.11+, Uvicorn, SQLAlchemy Async, asyncpg, pandas, scikit-learn (ML Demand Forecasting), WebSockets |
| **Mobile Application** | Flutter 3.44+ (Dart), Flutter Riverpod 2.5+, Dio HTTP Client, CachedNetworkImage, Google Fonts Inter |
| **Realtime Engine** | Server-Sent Events (SSE) `/api/sse/orders`, Supabase Realtime Channels, WebSockets `/ws` |
| **Payments** | Razorpay (Live UPI Intent, Cards, Netbanking), Paytm Checksum, Cash on Delivery (COD) with Doorstep Dynamic QR |
| **Messaging & Notifications** | Meta WhatsApp Cloud API (Automated KOT & Order Alerts), Fast2SMS (OTP), Firebase Cloud Messaging (FCM), Web Push VAPID |

---

## 3. Directory Structure

```
d:\Fastkirana\
├── src/                          # Next.js Application Source (Web Storefront + Admin + APIs)
│   ├── app/                      # Next.js App Router Pages & API Routes
│   │   ├── (auth)/               # Login & Signup flows
│   │   ├── admin/                # Master Admin Operations Hub (6 major hubs, 21 tabs)
│   │   ├── picker/               # Dark Store Item Picking Console (Barcode scanning)
│   │   ├── delivery/             # Delivery Rider Mobile Web Portal (GPS stream, COD wallet)
│   │   ├── restaurant-kitchen/   # Cloud Kitchen / Chef KDS (KOT sound alerts & printing)
│   │   ├── food/                 # Food & Restaurant ordering storefront
│   │   ├── order/[id]/           # Real-time Order Tracking web page
│   │   └── api/                  # Over 45+ Server-Side REST Endpoints
│   │       ├── admin/            # Admin CRUD (products, categories, coupons, reports, users)
│   │       ├── auth/             # OTP send/verify, credentials, direct login
│   │       ├── orders/           # Order placement, split routing, status update, SSE live stream
│   │       ├── products/         # Catalog search, fuzzy matching, stock validation
│   │       ├── cart/             # Shopping cart remote sync & upsells
│   │       ├── wishlist/         # Saved favorite products
│   │       ├── coupons/          # Coupon validation and discount computation
│   │       ├── payment/          # Razorpay & Paytm order creation and signature verification
│   │       ├── delivery/         # Rider location ping & wallet cash settlement
│   │       └── settings/         # Store operational status, IST schedule, delivery fees
│   ├── components/               # Reusable React Components (Admin tabs, Modals, Banners)
│   └── lib/                      # Database client, auth guards, distance matrix, WhatsApp, KOT printing
│
├── fastkirana_flutter/           # Flutter Cross-Platform Mobile Application
│   └── lib/
│       ├── core/                 # AppConfig, API Client (Dio), Themes, Page Transitions
│       ├── data/
│       │   ├── models/           # Order, Product, Category, Cart, Restaurant, Address, User, StoreSettings
│       │   └── repositories/     # AuthRepository, OrderRepository, CartRepository, ProductRepository, etc.
│       ├── providers/            # Riverpod state managers (cartProvider, authProvider, storeSettingsProvider)
│       ├── features/             # Screen features (home, food/cafe, cart, checkout, orders, profile)
│       └── widgets/              # Reusable UI components (ProductCard, RestaurantCard, Stepper)
│
├── fastapi-backend/              # Python FastAPI Microservice (Port 8000)
│   ├── routers/                  # 28 Async Routers (auth, products, orders, delivery, forecast, admin)
│   ├── models.py                 # 26 SQLAlchemy Async Models mirroring Supabase PostgreSQL
│   ├── database.py               # Asyncpg connection engine with SSL & statement pooling
│   └── main.py                   # FastAPI Application Entry & WebSockets engine
│
├── prisma/
│   └── schema.prisma             # Master Database Schema (32 Models, 6 Enums)
└── .env                          # Root Environment Variables (Supabase, Razorpay, WhatsApp, Auth)
```

---

## 4. Key Business Logic & Workflows

### 🛒 Multi-Vendor Split Orders
When a customer adds both **Dark Store Groceries** and **Restaurant Food** into their cart:
1. Next.js `/api/orders` automatically creates **two synchronized sub-orders** (`GROCERY` and `RESTAURANT`) under a single `combinedId` with shared readable ID (e.g. `#1089` -> `#1089-G` and `#1089-R`).
2. Single delivery fee is charged to the customer.
3. Grocery picker receives the grocery items in `/picker`.
4. Restaurant chef receives food items in `/restaurant-kitchen` with auto-KOT printing.
5. Delivery rider is assigned to pick up from both locations before reaching the customer.

### 🛵 Rider Wallet & COD Cash Limit
1. For COD orders, when a rider marks an order `DELIVERED`, cash-in-hand is added to the rider's `RiderWallet`.
2. Hard safety cap: **₹2,000**. If cash-in-hand exceeds this limit, new COD assignments are automatically blocked until cash is deposited with Admin.
3. Admin approves physical cash hand-offs via `/api/admin/rider-cash`, recording a `CashDepositTransaction`.

### ⚡ 4-Stage Connected Tracking Stepper
Order tracking states:
- `PENDING` -> `CONFIRMED` -> `PACKED` -> `SHIPPED` (Rider on the way) -> `DELIVERED`
- Real-time updates delivered to Flutter app via polling `/api/orders/{id}` and to web via SSE `/api/orders/{id}/live`.

---

## 5. Environment & Development Commands

### Next.js Web & Admin:
```bash
npm run dev        # Starts Next.js on http://localhost:3000
npm run build      # Production build
npx prisma generate
npx prisma validate
```

### Flutter Mobile App:
```bash
cd fastkirana_flutter
flutter pub get
flutter run -d chrome --web-port 5000 --release    # Run Web app
flutter build apk --release                        # Build Android APK
```

### FastAPI Microservice:
```bash
cd fastapi-backend
uvicorn main:app --reload --port 8000
```
