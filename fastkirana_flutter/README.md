# FastKirana Flutter

Cross-platform mobile app for **FastKirana** — an ultra-fast Quick-Commerce & Multi-Restaurant Food Delivery platform built for Tier-2/3 Indian cities (Ghatampur / Kanpur Nagar).

## What This App Does

- **Grocery Delivery** — browse and order from the dark store catalog (groceries, daily essentials)
- **Food & Restaurant** — order from multi-vendor restaurants with real-time kitchen tracking
- **Split Orders** — grocery and food items in one cart automatically route to separate fulfillment (picker + kitchen)
- **Real-time Tracking** — live order status from PENDING → CONFIRMED → PACKED → SHIPPED → DELIVERED
- **Delivery Zones** — distance-tiered fees based on proximity to the Ghatampur hub (up to 5 km)
- **Rider Wallet** — COD cash-in-hand tracking with ₹2,000 safety cap
- **Coupons & Offers** — discount codes, flash deals, bestseller badges
- **Wishlist & Reorder** — save favorites, quick reorder from order history

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | Flutter 3.44+ (iOS, Android, Web) |
| **State Management** | Riverpod 2.5+ |
| **HTTP Client** | Dio with interceptors (auth, logging, fallback URLs) |
| **Realtime** | Supabase Realtime Channels, SSE polling |
| **Local Storage** | Hive (cart cache), Secure Storage (auth tokens) |
| **Maps** | Google Maps Platform (location, geocoding, distance) |
| **Notifications** | Firebase Cloud Messaging (FCM) |
| **Payments** | Razorpay (UPI, Cards, Netbanking), Paytm Checksum, COD |

## Architecture

```
lib/
├── core/                  # App config, API client, themes, utilities
│   ├── config/app_config.dart        # Build-time config, API URLs
│   ├── network/api_client.dart       # Dio instance with auth + logging + fallback
│   ├── services/                     # Logger, biometrics, notifications, location
│   └── theme/                        # Design system, responsive utils
├── data/
│   ├── models/          # Product, Cart, Order, Address, StoreSettings, etc.
│   └── repositories/    # CartRepo, OrderRepo, ProductRepo, AuthRepo, etc.
├── providers/           # Riverpod state managers (cart, auth, store settings)
├── features/            # Screen features (home, food, cart, checkout, orders, profile)
│   ├── auth/            # Login, OTP, admin/delivery login
│   ├── cart/            # Cart screen
│   ├── checkout/        # Checkout flow, payment, order success
│   ├── common/          # Shared modals (order edit, variant selector)
│   ├── delivery/        # Rider dashboard, picker console
│   ├── cafe/            # Restaurant dashboard, kitchen widgets
│   ├── admin/           # Master admin console
│   └── ...
└── widgets/             # Reusable UI (ProductCard, Shimmer, CartConflictDialog)
```

## Backend

The Flutter app connects to the **Next.js 16** backend:

- **Repository**: [`../src/`](../src/) — Next.js App Router with 45+ API routes
- **Database**: Supabase PostgreSQL (Prisma ORM)
- **Admin Portal**: `/admin` — Master console with 6 hubs, 21 tabs
- **Picker Console**: `/picker` — Dark store item picking with barcode scanning
- **Kitchen KDS**: `/restaurant-kitchen` — Chef display with auto-KOT printing
- **Delivery Portal**: `/delivery` — Rider GPS stream, COD wallet management

See the [root CLAUDE.md](../CLAUDE.md) for the full system architecture.

## Getting Started

### Prerequisites

- Flutter 3.44+ ([install](https://docs.flutter.dev/get-started/install))
- Dart 3.6+
- Android SDK / Xcode (for mobile builds)
- Web browser (for web builds)

### Setup

```bash
# Install dependencies
flutter pub get

# Run on web (port 5000)
flutter run -d chrome --web-port 5000

# Run on connected device/emulator
flutter run

# Build Android release APK
flutter build apk --release

# Build iOS release
flutter build ios --release
```

### Required Environment Variables

Pass these at build time via `--dart-define`:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhb... \
  --dart-define=GOOGLE_MAPS_API_KEY=AIza... \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_...
```

> **Security**: No production secrets are checked into source control. Use CI/CD to inject these from environment variables.

### Development

```bash
# Run the Next.js backend (in a separate terminal)
cd .. && npm run dev

# Verify the Flutter app connects to http://localhost:3000
flutter run -d chrome --web-port 5000
```

## Project Context

- **Target Cities**: Tier-2/3 Indian cities (currently Ghatampur, Kanpur Nagar, UP)
- **Delivery Radius**: 5 km from central darkstore hub
- **Dark Store**: Ghatampur Market, Kanpur Nagar, UP - 209206
- **Support**: +91 81128 49854 | fastkiranadelivery@gmail.com

## License

Proprietary — FastKirana Platform
