# FastKirana — Codebase Library Audit & Recommendations

_Generated: 2026-08-05_

---

## 1. App Scale Overview

| Metric | Value |
|---|---|
| Frontend source files | 270 (`.ts` + `.tsx`) |
| Frontend source lines | ~79,246 |
| Backend source lines | ~1,435 (Python) |
| Frontend deps in `package.json` | 30+ |
| Backend deps in `requirements.txt` | 15 |

The frontend is clearly the main codebase. The FastAPI backend (under `fastapi-backend/`) is small (~1,400 lines) and already reasonably structured.

---

## 2. Heaviest Files (Lines of Code)

These files are primary refactoring candidates. Large single-file components are hard to maintain and test.

| File | Lines | Risk |
|---|---|---|
| `src/components/admin/admin-dashboard.tsx` | 7,444 | **Critical** — monolithic dashboard, mix of UI + logic + API calls |
| `src/app/checkout/page.tsx` | 1,918 | High — checkout flow with pricing, discounts, validation |
| `src/app/picker/page.tsx` | 1,864 | High — order picker with live updates, filtering, actions |
| `src/app/delivery/page.tsx` | 1,780 | High — delivery tracking, map, status, wallet |
| `src/components/admin/admin-inventory-center.tsx` | 1,765 | High — complex inventory management |
| `src/components/admin/cafe-orders-console.tsx` | 1,540 | High — cafe order management console |
| `src/components/admin/restaurant-orders-console.tsx` | 1,494 | High — restaurant order console |
| `src/components/order/order-tracker.tsx` | 1,471 | High — real-time order tracking |
| `src/components/admin/restaurant-form.tsx` | 1,460 | High — restaurant create/edit form |
| `src/components/admin/admin-settings.tsx` | 1,399 | Medium-High — settings panels |

**Recommendation**: Split each of these into smaller sub-components. A 7,444-line dashboard should be 10–20 focused components. The pages should extract business logic into custom hooks or service modules.

---

## 3. Custom Code That Deserves a Library

### 3.1 Debounce / Throttle (Custom)

**Found in:**
- `src/hooks/use-debounce.ts`
- Used by: `admin-dashboard.tsx`, `create-order-modal.tsx`, `cafe-storefront.tsx`, `cart-sync-provider.tsx`, `search-overlay.tsx`

**Recommendation**: Replace with `use-debounce` from `usehooks-ts` (or `@usedispatch/use-debounce`).

```bash
npm install @usedispatch/use-debounce   # or usehooks-ts
```

**Benefit**: Standardized API, better edge-case handling (leading/trailing options), fewer bugs.

---

### 3.2 Date/Time Utilities

**Found in:**
- `src/lib/dish-timing.ts` — custom time slot generation
- `src/lib/restaurant-schedule.ts` — restaurant open/close schedule logic
- `src/lib/constants.ts` — hardcoded date format strings scattered across 20+ files

**Pattern spotted**: Inline `new Date(...).toLocaleTimeString()`, manual `getHours()/getMinutes()` arithmetic in 10+ files including admin routes, checkout, delivery, picker, food pages.

**Recommendation**: Use `date-fns` (already in `package.json`) consistently. Move all date-formatting into a shared `src/lib/date-helpers.ts` with named helpers like `formatOrderTime`, `formatDeliveryETA`, `isStoreOpen`.

**Benefit**: Consistent formatting, i18n-ready, fewer timezone bugs.

---

### 3.3 CSV / Data Import/Export

**Found in:**
- `src/components/admin/admin-csv-import.tsx` (780 lines) — custom CSV parsing logic

**Recommendation**: Replace with `papaparse` for parsing and `json2csv` for export.

```bash
npm install papaparse json2csv
```

**Benefit**: Handles edge cases (quoted fields, different delimiters, streaming large files), well-tested, reduces 780-line component.

---

### 3.4 Validation / Schema

Already using `zod` and `@hookform/resolvers` — this is good. But many API route handlers (`src/app/api/admin/orders/create-on-behalf/route.ts`, etc.) do manual validation with ad-hoc checks instead of reusing Zod schemas.

**Recommendation**: Extract all API validation into shared Zod schemas in `src/lib/validators.ts`. Use `zod` for frontend form validation too (already partially done with react-hook-form).

**Benefit**: DRY validation, catches errors early, one source of truth.

---

### 3.5 Form State Management

`react-hook-form` is used, but many components (admin pages, checkout, create-order-modal) manage form state with React `useState` + manual validation.

**Recommendation**: Standardize on `react-hook-form` + `zod` for all forms. Add `@hookform/resolvers` (already installed) consistently.

---

### 3.6 Notifications / Toasts

`sonner` is installed but underused. Several components use custom toast implementations or inline alerts.

**Recommendation**: Standardize on `sonner` (already a dependency) and remove any custom toast code.

---

### 3.7 Map / Location Picking

**Found in:**
- `src/components/shared/map-picker.tsx` (415 lines)
- `src/components/shared/free-map-picker.tsx` (366 lines)
- `src/components/shared/location-picker.tsx` (628 lines)

These are custom map implementations. There are 3 separate map-related components.

**Recommendation**: If using Google Maps, consolidate with `@react-google-maps/api`. If using Leaflet, use `react-leaflet`. Currently no map library is in `package.json`, meaning the maps are likely rendered as images or custom canvas — this is fragile.

**Library**: `@react-google-maps/api` or `react-leaflet`

```bash
npm install @react-google-maps/api   # if using Google Maps
# or
npm install react-leaflet             # if using open-source maps
```

**Benefit**: Proper map interactivity, marker clustering, geolocation, touch support.

---

### 3.8 QR Code Generation

Found in `src/app/api/delivery/orders/[id]/qr/route.ts`.

**Recommendation**: Use `qrcode` or `qrcode.react` instead of any custom generation.

```bash
npm install qrcode
```

---

### 3.9 Phone Number Parsing / SMS

**Found in:**
- `src/lib/fast2sms.ts`
- `src/lib/whatsapp.ts`
- OTP send/verify routes

**Recommendation**: Use `libphonenumber-js` for phone number parsing/validation. Already a common pattern in Indian apps (Fast2SMS, WhatsApp).

```bash
npm install libphonenumber-js
```

---

### 3.10 State Management

`zustand` is installed and used (cart-store, ui-store). `@tanstack/react-query` is also present. This is good. But some pages still use `useState` for server-state (product data, order data) instead of React Query.

**Recommendation**: Migrate all server data fetching to `@tanstack/react-query` (already a dependency). This will reduce API-fetch boilerplate and add caching, refetching, and stale-while-revalidate for free.

---

### 3.11 Push Notifications

`web-push` is used in both Next.js and FastAPI backends. The notification logic is split across both. The `src/lib/push-notification.ts` and `src/components/providers/push-notification-provider.tsx` seem custom.

**Recommendation**: Consider `@vite-pwa/notify` or keep `web-push` (it's the standard). But consolidate the logic into a single provider component and remove duplication.

---

### 3.12 Payment — Custom Checksum

**Found in:** `src/lib/paytm-checksum.ts`

This is a custom Paytm checksum implementation. Paytm provides an official SDK.

**Recommendation**: Use Paytm's official SDK or a maintained package instead of custom checksum logic.

```bash
npm install paytm-pg-node-sdk   # or equivalent
```

---

### 3.13 Image Optimization / Manipulation

Custom image handling in several components (product images, banners). Next.js has built-in `Image` component, but there's no image manipulation library for resizing/cropping on upload.

**Recommendation**: Use `sharp` (already in Node ecosystem) for server-side image processing during upload.

---

### 3.14 No CSV/XLSX Library on Frontend

No Excel export library. Admin reports likely export as CSV only.

**Recommendation**: Add `xlsx` (SheetJS) for Excel export from admin reports.

```bash
npm install xlsx
```

---

### 3.15 Revalidation Cache

**Found in:** `src/lib/revalidate.ts`, `src/lib/search-cache.ts`, `src/lib/settings-cache.ts`

Custom in-memory caching. Good for speed, but no eviction, no persistence, no distributed cache.

**Recommendation**: For production, consider `lru-cache` for LRU eviction. Or move to Redis (already in FastAPI backend).

```bash
npm install lru-cache
```

---

## 4. Backend Observations (`fastapi-backend/`)

| Area | Current | Recommendation |
|---|---|---|
| ORM | SQLAlchemy 2.x (async) | Good — modern, well-maintained |
| Auth | JWT + `python-dotenv` | Fine, but could use `python-jose[cryptography]` for JWT |
| Validation | Pydantic v2 | Excellent |
| ML/Forecast | `scikit-learn`, `pandas` | Good choices for demand forecasting |
| Caching | `redis` | Good |
| Observability | `sentry-sdk` | Good |
| Testing | `pytest`, `pytest-asyncio` | Adequate for size |
| WS support | Custom `websockets.py` | Fine for current scale |

The backend is small, clean, and already using appropriate libraries. No major issues here. The venv is committed in git — **should be in `.gitignore`**.

---

## 5. Root-Level Files Concern

These `.ts` files in the project root look like ad-hoc scripts:

- `check_all_products.ts`
- `check_product.ts`
- `db-size.ts`
- `delete_cancelled_orders.ts`
- `inspect.ts`
- `scratch-add.ts`, `scratch-delete.ts`, `scratch-db-test.ts`
- `test_api_products.ts`, `test-compat-connect.ts`, `test-pg-connect.ts`, `test-pg.js`, `test-prisma-direct.ts`

**Recommendation**: Move to a `scripts/` or `tools/` directory. Some already exist under `src/scripts/`. Consolidate all scripts there and document what each does. Remove truly obsolete scratch scripts.

Also: `fastkirana_app_icon.png` (85KB) and `fastkirana_exact_logo_*.png` (85KB) are in the repo root, not in `public/`. Move to `public/`.

---

## 6. Top Priority Recommendations (Ranked)

1. **Split `admin-dashboard.tsx` (7,444 lines)** into sub-components. This is the biggest maintainability risk.
2. **Standardize date handling** — consolidate 20+ inline date formats into shared helpers using `date-fns`.
3. **Add a CSV library** (`papaparse`) and remove custom CSV parsing from `admin-csv-import.tsx`.
4. **Replace custom debounce** with `use-debounce` from a maintained library.
5. **Move all scripts** from root to `scripts/` directory and clean up scratch files.
6. **Consolidate map components** (3 files → 1 with a proper map library).
7. **Add `lru-cache`** to replace ad-hoc caching in `search-cache.ts` / `settings-cache.ts`.
8. **Replace custom Paytm checksum** with official SDK.
9. **Add `xlsx` (SheetJS)** for Excel export from admin.
10. **Migrate remaining server-state to React Query** — standardize all data fetching.

---

## 7. What the App Already Does Well

- Uses `zod` + `react-hook-form` for validation
- Has `@tanstack/react-query` for server state caching
- Uses `zustand` for client state
- Uses `shadcn/ui` + Tailwind CSS for consistent UI
- FastAPI backend is well-structured with proper separation
- Has real-time features (WebSockets, SSE)
- Has offline/PWA support (`web-push`, service worker)
- Uses proper auth (`next-auth` v5 beta with Prisma adapter)

The foundation is solid. The main issue is **scale debt** — the frontend grew large without component extraction or library consolidation.
