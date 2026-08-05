# FastKirana Refactoring Plan

_Date: 2026-08-05_
_Approach: Branch-per-phase, with tests_
_Pace: 3–4 sessions_

---

## PHASE 0 — Pre-work (Pre-requisites)

**Goal**: Fix the small things first so the base is clean before big refactors.

### Git Setup

```
git checkout main
git checkout -b phase0-prep
git add -A
git commit -m "chore: snapshot before refactoring"
```

### Checklist

| # | Task | File(s) | Action |
|---|---|---|---|
| 1 | Move root-level scripts into `src/scripts/` | `check_all_products.ts`, `check_product.ts`, `db-size.ts`, `delete_cancelled_orders.ts`, `inspect.ts`, `scratch-add.ts`, `scratch-debate.ts`, `scratch-delete.ts`, `scratch-db-test.ts`, `test_api_products.ts`, `test-compat-connect.ts`, `test-pg-connect.ts`, `test-pg.js`, `test-prisma-direct.ts` | Move files; update any imports |
| 2 | Move logo images to `public/` | `fastkirana_app_icon.png`, `fastkirana_exact_logo_*.png` | Move to `public/brand/` |
| 3 | Add `venv/` to `.gitignore` | `.gitignore` | Add line |
| 4 | Remove `venv/` from git tracking | `.gitignore`, git | `git rm -r --cached fastapi-backend/venv/` |

**Estimated time**: 30–45 minutes
**Risk**: Low (no code changes, just file moves)

---

## PHASE 1 — Utility Libraries (Week 1, Session 1–2)

**Goal**: Replace custom implementations with battle-tested libraries. Quick wins that reduce code immediately.

### Git

```
git checkout main
git checkout -b phase1-utilities
git merge phase0-prep
```

### 1.1 Custom Debounce → `use-debounce`

**Before**: `src/hooks/use-debounce.ts` + custom inline debounce in 5 files
**After**: Install `use-debounce` package, delete custom hook, update 5 imports

**Files to change**: 6

**Dependencies**:
```bash
npm install use-debounce
npm test   # verify nothing broke
```

**Deliverable**: Custom hook deleted, all callers using library. Test: type in search bar, verify debounce still works (500ms delay).

### 1.2 CSV Parsing → `papaparse`

**Before**: `src/components/admin/admin-csv-import.tsx` (780 lines, custom CSV parser)
**After**: Install `papaparse`, replace custom parser with library calls

**Files to change**: 1

**Dependencies**:
```bash
npm install papaparse
```

**Deliverable**: CSV import component reduced from ~780 → ~450 lines. Test: upload CSV with commas inside quoted fields — should parse correctly now.

### 1.3 Custom In-memory Cache → `lru-cache`

**Before**: `src/lib/search-cache.ts`, `src/lib/settings-cache.ts` (ad-hoc Map + manual cleanup)
**After**: Install `lru-cache`, replace both with standard LRU

**Files to change**: 3 (2 cache files + 1 import test)

**Dependencies**:
```bash
npm install lru-cache
```

**Deliverable**: Cache auto-evicts old entries, no memory leak. Test: fill cache beyond max, verify old entries evicted.

### 1.4 Date/Time Utilities → Consolidate with `date-fns`

**Before**: 20+ files with inline `new Date().toLocaleTimeString()`, manual `getHours()/getMinutes()` arithmetic
**After**: Create `src/lib/date-helpers.ts` with shared helpers, update all callers

**Files to change**: ~20

**New file**: `src/lib/date-helpers.ts` (~80–120 lines)

**Deliverable**: All date formatting goes through one file. Test: verify timestamps display correctly across admin, checkout, delivery pages.

---

### Phase 1 Tests

```bash
# 1. Build passes
npm run build

# 2. Lint passes
npm run lint

# 3. Smoke tests
# - Homepage loads
# - Admin page loads
# - Checkout page loads
# - CSV upload works (test file in place)
# - Search debounce works
# - Cache works (reload page, settings load from cache)
# - Dates display correctly
```

**Estimated time**: 4–6 hours total
**Risk**: Low–Medium (date changes are most likely to break something — need thorough check)

---

## PHASE 2 — Component Refactoring (Week 1–2, Session 3–5)

**Goal**: Split the largest files into maintainable components.

### Git

```
git checkout main
git checkout -b phase2-refactor
git merge phase1-utilities
```

### 2.1 Split `admin-dashboard.tsx` (7,444 lines → ~10 files)

This is the **biggest win**. Current file is a monolith containing:
- Stats cards
- Charts (sales, orders, forecasts)
- Recent orders table
- Alerts panel
- Promotions manager
- Cafe console
- Restaurant console
- Rider cash section
- Bulk actions
- Sort manager
- Settings panels

**Target structure**:
```
src/components/admin/
├── admin-dashboard.tsx          (~200 lines, orchestrator)
├── dashboard/
│   ├── stats-cards.tsx          (~100 lines)
│   ├── sales-chart.tsx          (~150 lines)
│   ├── orders-table.tsx         (~200 lines)
│   ├── alerts-panel.tsx         (~150 lines)
│   ├── promotions-card.tsx      (~150 lines)
│   ├── cafe-console-card.tsx    (~200 lines)
│   ├── restaurant-console-card.tsx (~200 lines)
│   ├── rider-cash-card.tsx      (~150 lines)
│   ├── bulk-actions-card.tsx    (~150 lines)
│   └── sort-manager-card.tsx    (~150 lines)
```

**Approach**:
1. First pass: Identify logical sections (grep for comments, divs with distinct sections)
2. Second pass: Extract each section into its own file, one at a time
3. Third pass: Verify nothing broke
4. Fourth pass: Extract shared UI into `src/components/admin/dashboard/`

**Files changed**: 1 → 12

**Deliverable**: `admin-dashboard.tsx` reduced to ~200-line orchestrator. Each sub-component is independently testable and readable.

### 2.2 Extract Sub-components from Heavy Pages

| Page | Current | Target | Sub-components |
|---|---|---|---|
| `checkout/page.tsx` | 1,918 lines | ~400 lines | `checkout/order-summary.tsx`, `checkout/payment-section.tsx`, `checkout/delivery-selector.tsx`, `checkout/coupon-input.tsx` |
| `picker/page.tsx` | 1,864 lines | ~400 lines | `picker/order-list.tsx`, `picker/filters.tsx`, `picker/actions-bar.tsx` |
| `delivery/page.tsx` | 1,780 lines | ~400 lines | `delivery/order-map.tsx`, `delivery/order-list.tsx`, `delivery/wallet-card.tsx` |
| `admin-inventory-center.tsx` | 1,765 lines | ~500 lines | `inventory/stock-table.tsx`, `inventory/forecast-panel.tsx`, `inventory/pos-checkout.tsx` |
| `cafe-orders-console.tsx` | 1,540 lines | ~400 lines | `cafe/order-cards.tsx`, `cafe/status-filters.tsx` |
| `restaurant-orders-console.tsx` | 1,494 lines | ~400 lines | `restaurant/order-tabs.tsx`, `restaurant/order-details.tsx` |

**Approach**: Same as dashboard — identify logical sections, extract one at a time, verify.

**Deliverable**: No file over 500 lines after this phase.

---

### Phase 2 Tests

```bash
npm run build
npm run lint
# For each extracted component:
# - Visual check on admin dashboard
# - Navigate through checkout flow
# - Check picker page
# - Check delivery page
# - Check cafe orders console
# - Check restaurant orders console
# - Check inventory center
```

**Estimated time**: 8–12 hours total
**Risk**: Medium–High (biggest risk is breaking imports during extraction)

---

## PHASE 3 — Feature Upgrades (Week 2–3, Session 6–8)

**Goal**: Add missing libraries and upgrade remaining custom code.

### Git

```
git checkout main
git checkout -b phase3-upgrades
git merge phase2-refactor
```

### 3.1 Map Components → `@react-google-maps/api`

**Before**: 3 custom map files (~1,400 lines combined)
- `map-picker.tsx` (415 lines)
- `free-map-picker.tsx` (366 lines)
- `location-picker.tsx` (628 lines)

**After**: 1 standard component using Google Maps library

**Files changed**: 3 → 1

**Dependencies**:
```bash
npm install @react-google-maps/api
```

**Deliverable**: Single map component, proper markers, geolocation, touch support.

### 3.2 Phone Number Parsing → `libphonenumber-js`

**Before**: Custom phone formatting in `fast2sms.ts`, `whatsapp.ts`, OTP routes
**After**: Standard library for all phone operations

**Files changed**: 3–4

**Dependencies**:
```bash
npm install libphonenumber-js
```

**Deliverable**: Indian + international phone formats handled correctly.

### 3.3 Excel Export → `xlsx` (SheetJS)

**Before**: CSV-only export from admin reports
**After**: CSV + Excel (.xlsx) export option

**Files changed**: 2–3 (admin reports, CSV import file)

**Dependencies**:
```bash
npm install xlsx
```

**Deliverable**: Admin can export reports as Excel files.

### 3.4 Paytm Checksum → Official SDK

**Before**: `src/lib/paytm-checksum.ts` (custom implementation)
**After**: Official Paytm SDK

**Dependencies**:
```bash
npm install paytm-pg-node-sdk
```

**Deliverable**: Paytm checksum generated by official, maintained code.

### 3.5 Server-State → React Query (Partial Migration)

**Before**: Some pages use `useState` + manual fetch for server data
**After**: Migrate those pages to `@tanstack/react-query` (already installed)

**Files changed**: ~5–8 pages that still use manual fetching

**Deliverable**: All server data goes through React Query with caching, refetching, stale-while-revalidate.

---

### Phase 3 Tests

```bash
npm run build
npm run lint
# Map picker: tap on map, marker appears
# Phone validation: try +91, +1, invalid numbers
# Excel export: download .xlsx, open in Excel, verify data
# Paytm: check checksum output matches previous values
# React Query: verify data persists on navigation and refetches on focus
```

**Estimated time**: 6–8 hours total
**Risk**: Medium (Paytm integration needs careful testing)

---

## PHASE 4 — Backend Cleanup & Polish (Week 3, Session 9)

**Goal**: Minor backend improvements and cross-cutting concerns.

### Git

```
git checkout main
git checkout -b phase4-backend
git merge phase3-upgrades
```

### 4.1 Add Missing JWT Library

```bash
pip install python-jose[cryptography]
```

### 4.2 Add Type Checking

```bash
npm install --save-dev ts-prune
npx ts-prune   # find unused exports
```

### 4.3 Bundle Size Audit

```bash
npm install --save-dev @next/bundle-analyzer
# Add bundle analyzer to next.config.ts
```

### 4.4 Final Lint + Build

```bash
npm run lint -- --max-warnings=0
npm run build
```

---

## ROLLBACK STRATEGY

Each phase has its own branch. If something breaks:

```
# Go back to main
git checkout main

# Or go back to a specific phase
git checkout phase1-utilities
```

Each phase branch is independently mergeable. If Phase 2 breaks something, only Phase 1 changes are in Phase 2 branch — easy to isolate.

---

## EXECUTION ORDER SUMMARY

```
Phase 0  (30-45 min)  → File cleanup, git hygiene
Phase 1  (4-6 hrs)    → Utilities: debounce, CSV, cache, dates
Phase 2  (8-12 hrs)   → Refactor: dashboard + heavy pages
Phase 3  (6-8 hrs)    → Upgrades: maps, phone, Excel, Paytm, React Query
Phase 4  (2-3 hrs)    → Polish: backend, bundle, final checks
─────────────────────────
Total:  ~20-30 hours across 3-4 sessions
```

---

## WHAT NOT TO TOUCH

- `fastapi-backend/routers/` — already clean, no major issues
- `prisma/schema.prisma` — database is working, don't touch unless needed
- `src/lib/auth.ts` — auth logic is complex, leave alone
- `src/components/ui/` — shadcn components, leave alone
- `.env` files — never touch config files

---

## SUCCESS METRICS

After all phases:
- No file over 500 lines
- All dates go through `src/lib/date-helpers.ts`
- All debounce through library
- CSV through `papaparse`
- Cache through `lru-cache`
- Build passes clean
- Lint passes clean
- Admin dashboard loads in <2 seconds (was likely slower with 7K line component)
