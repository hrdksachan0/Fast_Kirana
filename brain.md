# Fastkirana Admin Dashboard — Context File

**Last updated:** 2026-08-08
**Purpose:** Persistent memory across sessions for this codebase. Keeps track of current state, decisions made, and next steps so work can resume without re-reading everything.

---

## Project Overview

Fastkirana is a multi-service grocery/cafe/restaurant ordering platform (Next.js + Prisma + SQLite). The admin dashboard (`admin-dashboard.tsx`) is the central management panel for store owners.

**Key directories:**
- `src/components/admin/dashboard/` — extracted sub-components (hub-nav, stats-cards, orders-tab, live-carts-panel, whatsapp-alert-modal)
- `src/components/admin/admin-dashboard.tsx` — main dashboard (4334 lines, being refactored)
- `src/components/admin/categories-tab.tsx` — ✅ extracted categories management tab
- `src/components/admin/users-tab.tsx` — ✅ extracted users management tab
- `src/components/admin/coupons-tab.tsx` — ✅ extracted coupons management tab
- `src/components/admin/products-tab.tsx` — ✅ extracted products management tab (~1300 lines)
- `src/components/admin/live-ops-tab.tsx` — ✅ extracted live ops tab
- `src/components/admin/analytics-tab.tsx` — ✅ wrapper for AdminAnalytics
- `src/components/admin/forecast-tab.tsx` — ✅ wrapper for AdminForecast
- `src/components/admin/alerts-tab.tsx` — ✅ wrapper for AdminAlerts
- `src/components/admin/inward-tab.tsx` — ✅ wrapper for AdminInventoryCenter
- `src/components/admin/bulk-update-tab.tsx` — ✅ wrapper for AdminBulkUpdate
- `src/components/admin/reports-tab.tsx` — ✅ wrapper for AdminReports
- `src/components/admin/restaurant-report-tab.tsx` — ✅ wrapper for AdminRestaurantReport
- `src/components/admin/banners-tab.tsx` — ✅ wrapper for AdminBanners
- `src/components/admin/settings-tab.tsx` — ✅ wrapper for AdminSettings
- `src/components/admin/push-notifications-tab.tsx` — ✅ wrapper for AdminPushNotifications
- `src/components/admin/flash-deals-tab.tsx` — ✅ wrapper for AdminPromotions
- `src/components/admin/rider-cash-tab.tsx` — ✅ wrapper for AdminRiderCash
- `src/components/admin/csv-import-tab.tsx` — ✅ wrapper for AdminCsvImport
- `src/components/admin/restaurant-console-tab.tsx` — ✅ wrapper for AdminRestaurantConsole

---

## Current State

### admin-dashboard.tsx Refactoring (IN PROGRESS)

**Original file size:** 6597 lines
**Current size:** 4334 lines
**Reduction so far:** ~2263 lines (34%)

**What's been extracted:**
1. ✅ `categories-tab.tsx` — Full categories/subcategories CRUD with tree table, add form, edit modal, media library integration, parent/child hierarchy, sort order, delete with confirmation
2. ✅ `users-tab.tsx` — Customer management table with search/filter, inline phone editing, role changes, password resets, block/unblock with reason modal
3. ✅ `coupons-tab.tsx` — Coupon creation form with all fields (code, type, value, min order, max discount, expiry, category restriction, once-per-customer toggle), coupon list table with toggle/delete, edit coupon modal
4. ✅ `products-tab.tsx` — Full product CRUD (add form with templates, variants, tags, pricing, edit modal), product inventory table with search/filter/type/category, CSV import/export, sort manager, pagination
5. ✅ `live-ops-tab.tsx` — SLA tracking, avg times (picking/prep/delivery), delayed orders with FIFO ranking, live carts panel
6. ✅ 14 thin wrapper tabs — analytics, forecast, alerts, inward, bulk-update, reports, restaurant-report, banners, settings, push-notifications, flash-deals, rider-cash, csv-import, restaurant-console

**What remains to extract (still inside admin-dashboard.tsx):**
- Product Edit Modal (~300+ lines) — could move into products-tab.tsx
- Block Customer Reason Modal — could move into users-tab.tsx
- Review Edit Modal — could become a shared modal or go into a reviews-tab
- Order Details & Live Tracking Modal — could go into a new orders-detail-tab or stay
- Media Library Modal — could become standalone
- Remaining: type cleanup (remove `any`), extract shared validation/utility functions

---

## Architecture Decisions

### Component Extraction Strategy
- Each tab or self-contained section becomes its own file in `src/components/admin/`
- Props are passed explicitly (no context/state sharing between components yet)
- The parent `admin-dashboard.tsx` owns ALL state and passes it down
- Event handlers (create, update, delete) are defined in parent and passed as props
- Thin wrapper tabs just forward props to existing child components

### Why This Approach
- Minimal risk of breaking existing functionality
- Easy to incrementally extract one tab at a time
- No need to refactor state management first
- Each extracted component is independently testable

---

## Key State in admin-dashboard.tsx (that components depend on)

### Products-related (now in products-tab.tsx props)
- `products`, `allProducts`, `filteredProducts`, `productPage`, `productTotal`
- `searchQuery`, `selectedTypeFilter`, `selectedCategoryFilter`
- `newProduct`, `newProductType`, `newProductVariants`, `hasVariantsNew`, `newCustomTag`
- `editProductType`, `editProductVariants`, `hasVariantsEdit`, `editCustomTag`
- `showAddProduct`, `showSortManager`, `showCsvImport`, `showExportModal`
- `isExporting`, `isCreatingProduct`, `isUploading`
- `categories`, `restaurantsList`, `settingsMap`
- `editingProduct`, `savingProductId`, `productEditForm`
- `editingCategory`, `categoryEditForm`, `savingCategoryId`, `deletingCategoryId`
- `mediaTarget`, `showMediaLibrary`, `mediaSearchQuery`, `filteredMediaImages`

### Orders-related (now in orders-tab.tsx props)
- `orders`, `orderPage`, `orderTotal`, `orderStatusFilter`, `orderSearchQuery`
- `editingOrder`, `orderEditForm`, `savingOrderId`
- `selectedOrderForTracking`, `isLoadingOrderItems`
- `liveOrders`, `livePendingOrders`, `delayedOrders`, `pickerDelays`, `chefDelays`, `riderDelays`
- `activeCarts`, `activeCartsCount`, `isLoadingCarts`, `cartsRefreshKey`
- `isChimeMuted`, SSE connection handlers

### Other major state (still in dashboard)
- `stats` (revenue, orderCount, lowStockCount, etc.)
- `coupons`, `newCoupon`, `editingCoupon`
- `users`, `userPage`, `userSearch`, `userRoleFilter`, `userStatusFilter`
- `blockingUser`, `blockReasonInput`, `isUpdatingBlockStatus`
- `reviewEditForm`, `editingReview`, `savingReviewId`
- `whatsappModalOpen`, `whatsappTargetUser`, `whatsappSelectedTemplateIdx`, `whatsappCustomMessage`

---

## File Structure After Full Phase 1

```
src/components/admin/
├── admin-dashboard.tsx          # Orchestrator only (~400 lines goal)
├── categories-tab.tsx           # ✅ DONE (~500 lines)
├── users-tab.tsx                # ✅ DONE (~330 lines)
├── coupons-tab.tsx              # ✅ DONE (~600 lines)
├── products-tab.tsx             # ✅ DONE (~1300 lines)
├── live-ops-tab.tsx             # ✅ DONE (~200 lines)
├── analytics-tab.tsx            # ✅ DONE (wrapper)
├── forecast-tab.tsx             # ✅ DONE (wrapper)
├── alerts-tab.tsx               # ✅ DONE (wrapper)
├── inward-tab.tsx               # ✅ DONE (wrapper)
├── bulk-update-tab.tsx          # ✅ DONE (wrapper)
├── reports-tab.tsx              # ✅ DONE (wrapper)
├── restaurant-report-tab.tsx    # ✅ DONE (wrapper)
├── banners-tab.tsx              # ✅ DONE (wrapper)
├── settings-tab.tsx             # ✅ DONE (wrapper)
├── push-notifications-tab.tsx   # ✅ DONE (wrapper)
├── flash-deals-tab.tsx          # ✅ DONE (wrapper)
├── rider-cash-tab.tsx           # ✅ DONE (wrapper)
├── csv-import-tab.tsx           # ✅ DONE (wrapper)
├── restaurant-console-tab.tsx   # ✅ DONE (wrapper)
└── dashboard/
    ├── hub-nav.tsx              # ✅ Already exists
    ├── stats-cards.tsx          # ✅ Already exists
    ├── orders-tab.tsx           # ✅ Already exists
    ├── live-carts-panel.tsx     # ✅ Already exists
    └── whatsapp-alert-modal.tsx # ✅ Already exists
```

---

## Important Patterns

### Lucide Icons
All icons are imported at the top of admin-dashboard.tsx and passed to components. Extracted components import their own icons directly.

### Animations
Uses `framer-motion` — `AnimatePresence` for conditional rendering, `motion.div` for transitions. Extracted components import their own `AnimatePresence`/`motion`.

### Styling
Tailwind utility classes throughout. No CSS modules or styled-components. Extracted components keep their own className strings.

### Data Fetching
Parent component fetches data, passes it as props. Extracted components render only — they don't fetch directly (except media library which needs its own fetch).

### API Routes (key endpoints)
- `POST /api/categories` — create category
- `PATCH /api/categories/[id]` — update category
- `DELETE /api/categories/[id]` — delete category
- `POST /api/admin/upload-image` — upload product/category image
- `GET /api/admin/media-library` — list media library images

---

## Plan & Progress

Full improvement plan: `docs/improvement-plan.md`

| Phase | Focus | Status | Target |
|-------|-------|--------|--------|
| 1 | Complete admin dashboard refactor | **~80% done** | ~400–500 line orchestrator |
| 2 | TypeScript cleanup & shared types | Pending | Zero `any` types in admin + API |
| 3 | Security hardening | Pending | Auth guards on all routes |
| 4 | Error handling & resilience | Pending | Consistent errors, error boundaries |
| 5 | Test coverage | Pending | 50+ meaningful tests |
| 6 | Performance & scalability | Pending | Redis, CSS optimization, bundle size |
| 7 | Developer experience | Pending | Tooling, docs, conventions |

**Remaining Phase 1 work:** ~400 lines in dashboard (product edit modal, review edit modal, block customer modal, order tracking modal, media library modal)

---

## Known Issues / Technical Debt

See `docs/improvement-plan.md` for the complete 7-phase plan addressing all of these.

1. **TypeScript types** — some places use `any` (e.g., `editingCategory: any`). Phase 2 addresses this.
2. **Duplicate form logic** — category add form and edit modal share similar image upload logic. Phase 1 will extract shared components.
3. **Media library coupling** — media library state is owned by parent but used by both categories and products tabs. Phase 1 handles this during products extraction.
4. **SSE/EventSource cleanup** — the SSE connection in orders needs to be properly cleaned up when orders-tab is extracted. Phase 1.
5. **Hardcoded store values** — some config values are hardcoded (mentioned in existing task list). Phase 1/7.
6. **Security gaps** — missing auth guards on admin routes, dev bypass risk. Phase 3.
7. **Error handling** — inconsistent, no error boundaries. Phase 4.
8. **Test coverage** — tests folder exists but meaningful tests nahi. Phase 5.
9. **CSS bloat** — Tailwind classes everywhere, no optimization. Phase 6.
10. **No Redis** — caching only in-memory, won't scale. Phase 6.

---

## Git Info

- Check current branch: `git branch --show-current`
- Uncommitted changes: admin-dashboard.tsx modified (4334 lines), +17 new tab files created, docs/improvement-plan.md created

---

*This file should be updated after each extraction step.*
