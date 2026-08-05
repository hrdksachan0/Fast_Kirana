# FastKirana Refactoring — Complete Status & Plan

> **Generated:** 2026-08-05
> **Stack:** Next.js 16, React 19, TypeScript, Prisma, FastAPI
> **Total frontend LOC:** ~79,000 across 270 files

---

## WHAT IS ALREADY DONE

| # | Task | Status | Commit |
|---|---|---|---|
| 1 | Move 13 root `.ts` scripts → `src/scripts/` | Done | `phase0` |
| 2 | Move 2 logo images → `public/brand/` + update references | Done | `phase0` |
| 3 | Add `fastapi-backend/venv/` to `.gitignore` | Done | `phase0` |
| 4 | Delete dead `src/hooks/use-debounce.ts` (no imports anywhere) | Done | `phase1` |
| 5 | Replace `src/lib/search-cache.ts` Map with `LRUCache` | Done | `phase1` |
| 6 | Replace `src/lib/settings-cache.ts` with `LRUCache` | Done | `phase1` |
| 7 | Create `src/lib/date-helpers.ts` with 5 shared helpers | Done | `phase1` |
| 8 | Add `src/types/papaparse.d.ts` type stub | Done | `phase1` |
| 9 | Add `src/types/lru-cache.d.ts` type stub | Done | `phase1` |

---

## WHAT ANTIGRAVITY NEEDS TO DO (6 sessions)

---

## SESSION 1 — Install Dependencies + CSV Migration

**Time:** 45 min

### Step 1.1 — Install packages

```bash
cd D:\Fastkirana
npm install papaparse lru-cache
```

Note: `lru-cache` may already be in `node_modules`. `papaparse` needs fresh install.

### Step 1.2 — Replace CSV parser in `admin-csv-import.tsx`

**File:** `src/components/admin/admin-csv-import.tsx`

The file already has `import Papa from 'papaparse'` at the top (added manually).

Find the `parseCSV` function (lines ~56-97). Replace it:

```ts
// DELETE this whole function:
function parseCSV(text: string): string[][] {
  const rows: string[][] = []
  let current = ''
  let inQuotes = false
  let row: string[] = []
  for (let i = 0; i < text.length; i++) { ... }
  return rows
}

// REPLACE with:
function parseCSV(text: string): string[][] {
  const result = Papa.parse(text, {
    skipEmptyLines: true,
    transform: (value: string) => value.trim(),
  })
  return result.data as string[][]
}
```

That's it. The rest of the file uses `rows` the same way.

### Step 1.3 — Verify

```bash
npm run build
```

Upload a CSV with commas inside quoted fields (e.g., `"Mumbai, Maharashtra"`) — should parse as single cell.

### Step 1.4 — Commit

```bash
git add -A
git commit -m "refactor(phase1): replace custom CSV parser with papaparse"
```

---

## SESSION 2 — Remove Type Stubs + Update package.json

**Time:** 15 min

Now that papaparse is installed, remove the type stub files:

```bash
del src/types/papaparse.d.ts
del src/types/lru-cache.d.ts
```

These were temporary stubs. The actual packages provide their own types.

### Update package.json

Add these lines to `dependencies` in `package.json`:

```json
"papaparse": "^5.4.1",
"lru-cache": "^10.0.0"
```

(If they were already added by npm install, verify versions match.)

### Verify

```bash
npm run build
npm run lint
```

### Commit

```bash
git add -A
git commit -m "chore: add papaparse and lru-cache to package.json, remove type stubs"
```

---

## SESSION 3 — Date Helpers Migration (20+ files)

**Time:** 2-3 hours

**Goal:** Replace inline date formatting with imports from `src/lib/date-helpers.ts`

### Step 3.1 — Add `format` helper

First, update `src/lib/date-helpers.ts` to also export a generic `format` wrapper:

```ts
export function formatDate(date: string | Date, pattern: string): string {
  return format(new Date(date), pattern)
}
```

### Step 3.2 — Update each file

For each file in the list below:
1. Add import: `import { formatOrderTime, formatDeliveryETA, formatRelativeTime, addMinutesTo, getTotalMinutes } from '@/lib/date-helpers'`
2. Replace inline date code with the appropriate helper
3. Remove any now-unused `date-fns` imports from that file

**Files to update (22 total):**

| File | Pattern to replace | Use helper |
|---|---|---|
| `src/lib/dish-timing.ts` | `now.getHours() * 60 + now.getMinutes()` | `getTotalMinutes(now)` |
| `src/lib/restaurant-schedule.ts` | Same pattern at line 86 | `getTotalMinutes(now)` |
| `src/components/home/time-suggestions.tsx` | `new Date().getHours()` | `getTotalMinutes(new Date())` or `formatOrderTime` |
| `src/components/cart/cart-sticky-bar.tsx` | `toLocaleTimeString('en-US', ...)` | `formatOrderTime(now)` |
| `src/app/api/admin/orders/create-on-behalf/route.ts` | `toLocaleTimeString` calls | `formatOrderTime(date)` |
| `src/app/api/cafe/reports/route.ts` | Date formatting | `formatOrderTime` / `formatDeliveryETA` |
| `src/app/api/restaurant/reports/route.ts` | Date formatting | `formatOrderTime` / `formatDeliveryETA` |
| `src/app/cafe-kitchen/page.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/app/delivery/page.tsx` | `toLocaleTimeString`, `getHours()` | `formatOrderTime` |
| `src/app/order/[id]/page.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/app/picker/page.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/app/product/[slug]/page.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/app/restaurant-kitchen/page.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/components/admin/admin-alerts.tsx` | Date formatting | `formatRelativeTime` |
| `src/components/admin/admin-bulk-update.tsx` | Date formatting | `formatOrderTime` |
| `src/components/admin/admin-dashboard.tsx` | `toLocaleTimeString` calls | `formatOrderTime` |
| `src/components/admin/admin-inward.tsx` | Date formatting | `formatOrderTime` |
| `src/components/admin/admin-reports.tsx` | Date formatting | `formatOrderTime` / `formatDeliveryETA` |
| `src/components/admin/admin-rider-cash.tsx` | Date formatting | `formatOrderTime` |
| `src/components/admin/restaurant-payouts-ledger.tsx` | Date formatting | `formatOrderTime` |
| `src/components/cart/cart-sticky-bar.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/components/food/restaurant-storefront.tsx` | `toLocaleTimeString` | `formatOrderTime` |
| `src/components/order/order-tracker.tsx` | Date formatting | `formatRelativeTime` |

### Step 3.3 — Verify

```bash
npm run build
npm run lint
```

### Step 3.4 — Commit

```bash
git add -A
git commit -m "refactor(phase1): consolidate inline date formatting into src/lib/date-helpers.ts across 22 files"
```

---

## SESSION 4 — Admin Dashboard Split (6-8 hrs)

**Branch:** `git checkout -b phase2-dashboard`

### Goal
Split `src/components/admin/admin-dashboard.tsx` (7,444 lines) into sub-components.

### Files to extract (do NOT touch these — already separate):
```
admin-analytics.tsx, admin-alerts.tsx, admin-bulk-update.tsx,
admin-reports.tsx, admin-restaurant-report.tsx, admin-inventory-center.tsx,
admin-banners.tsx, admin-settings.tsx, admin-csv-import.tsx,
admin-push-notifications.tsx, admin-promotions.tsx, admin-forecast.tsx,
admin-restaurant-console.tsx, admin-rider-cash.tsx
```

### Pass 1 — Move constants out (30 min)

**From:** `admin-dashboard.tsx` lines 93-178

Move `PRODUCT_TEMPLATES` and `HUB_CONFIG` to `src/lib/constants.ts`.

Add import in `admin-dashboard.tsx`:
```ts
import { PRODUCT_TEMPLATES, HUB_CONFIG } from '@/lib/constants'
```

Commit:
```bash
git commit -m "refactor(dashboard): move PRODUCT_TEMPLATES and HUB_CONFIG to src/lib/constants.ts"
```

### Pass 2 — Extract hub navigation (1 hr)

Create `src/components/admin/dashboard/hub-nav.tsx`

**Props:** `activeHub`, `setActiveHub`, `activeTab`, `setActiveTab`

Copy the hub navigation JSX section (the 5 hub cards/buttons). Replace in `admin-dashboard.tsx` with:
```tsx
<DashboardHubNav activeHub={activeHub} setActiveHub={setActiveHub} activeTab={activeTab} setActiveTab={setActiveTab} />
```

Commit:
```bash
git commit -m "refactor(dashboard): extract hub navigation to dashboard/hub-nav.tsx"
```

### Pass 3 — Extract stats cards (30 min)

Create `src/components/admin/dashboard/stats-cards.tsx`

**Props:** `stats` object

Replace stats JSX with:
```tsx
<DashboardStatsCards stats={stats} />
```

Commit.

### Pass 4 — Extract orders tab (2-3 hrs)

Create `src/components/admin/dashboard/orders-tab.tsx`

**Props:**
```ts
interface OrdersTabProps {
  orders: any[]
  orderCounts: Record<string, number>
  orderStatusFilter: string
  setOrderStatusFilter: (f: string) => void
  orderSearchQuery: string
  setOrderSearchQuery: (q: string) => void
  updatingOrderId: string | null
  onUpdateOrderStatus: (id: string, status: string) => void
  onDeleteOrder: (id: string) => void
}
```

Replace `{activeTab === 'orders' && (...)}` block with:
```tsx
<OrdersTab {...props} />
```

Commit.

### Pass 5 — Extract remaining panels (2-3 hrs)

| Component | File | Approx lines |
|---|---|---|
| Live carts panel | `dashboard/live-carts-panel.tsx` | ~150 |
| WhatsApp alert modal | `dashboard/whatsapp-alert-modal.tsx` | ~100 |

Commit each separately.

### Session 4 Acceptance

- [ ] `admin-dashboard.tsx` is under 500 lines
- [ ] `npm run build` passes
- [ ] All 20+ tabs render correctly
- [ ] Order status updates work
- [ ] Cart actions work
- [ ] KOT printing works

---

## SESSION 5 — Heavy Page Extraction (5-6 hrs)

**Branch:** `git checkout -b phase3-pages`

For each file, extract distinct sections into sub-components.

### 5.1 — `src/app/checkout/page.tsx` (1,918 → ~400 lines)

Create `src/app/checkout/components/`:

| New file | What |
|---|---|
| `order-summary.tsx` | Items list, subtotals, tax, total |
| `delivery-selector.tsx` | Address, slot, instructions |
| `coupon-input.tsx` | Coupon code + validation |
| `payment-section.tsx` | COD, online, Paytm button |

### 5.2 — `src/app/picker/page.tsx` (1,864 → ~400 lines)

Create `src/app/picker/components/`:

| New file | What |
|---|---|
| `order-list.tsx` | Scrollable order list |
| `filters.tsx` | Status tabs, search |
| `actions-bar.tsx` | Bulk actions, print |

### 5.3 — `src/app/delivery/page.tsx` (1,780 → ~400 lines)

Create `src/app/delivery/components/`:

| New file | What |
|---|---|
| `order-map.tsx` | Map view |
| `order-list.tsx` | Assigned orders |
| `wallet-card.tsx` | Earnings, balance |

### 5.4 — `src/components/admin/admin-inventory-center.tsx` (1,765 → ~500 lines)

Create `src/components/admin/inventory/`:

| New file | What |
|---|---|
| `stock-table.tsx` | Inventory table |
| `forecast-panel.tsx` | Forecast chart |
| `pos-checkout.tsx` | POS form |

### 5.5 — `src/components/admin/cafe-orders-console.tsx` (1,540 → ~400 lines)

Create `src/components/admin/cafe/`:

| New file | What |
|---|---|
| `order-cards.tsx` | Cafe order cards |
| `status-filters.tsx` | Filter tabs |

### 5.6 — `src/components/admin/restaurant-orders-console.tsx` (1,494 → ~400 lines)

Create `src/components/admin/restaurant/`:

| New file | What |
|---|---|
| `order-tabs.tsx` | Tab navigation |
| `order-details.tsx` | Order detail view |

### Session 5 Acceptance

- [ ] No file over 700 lines
- [ ] `npm run build` passes
- [ ] All 6 pages/consoles load and function

---

## SESSION 6 — Map, Phone, Excel, Paytm (4-5 hrs)

**Branch:** `git checkout -b phase4-upgrades`

### 6.1 — Merge 3 map files → 1 with `@react-google-maps/api`

**Files to delete:**
- `src/components/shared/map-picker.tsx` (415 lines)
- `src/components/shared/free-map-picker.tsx` (366 lines)
- `src/components/shared/location-picker.tsx` (628 lines)

**Install:**
```bash
npm install @react-google-maps/api
```

**Create:** `src/components/shared/map-picker.tsx` (~200 lines)

Use `GoogleMap`, `Marker`, `useJsApiLoader`, `Autocomplete`.

**Prerequisite:** `NEXT_PUBLIC_GOOGLE_MAPS_KEY` must exist in `.env`.

**Update all imports** across codebase that reference the 3 old files.

### 6.2 — Replace phone parsing with `libphonenumber-js`

**Files:**
- `src/lib/fast2sms.ts` — replace `phone.replace(/\D/g, '').slice(-10)`
- `src/lib/whatsapp.ts` — replace `phone.replace(/\D/g, '')` in both functions

**Install:**
```bash
npm install libphonenumber-js
```

Replace with:
```ts
import { parsePhoneNumberFromString } from 'libphonenumber-js'
const parsed = parsePhoneNumberFromString(phone, 'IN')
if (!parsed?.isValid()) { /* error */ }
const cleanPhone = parsed.nationalNumber  // Fast2SMS
// or parsed.number  // WhatsApp (E.164 format)
```

### 6.3 — Add Excel export with `xlsx`

**Install:**
```bash
npm install xlsx
```

Find CSV export code in admin reports. Add second button:
```tsx
import * as XLSX from 'xlsx'
const handleExportXLSX = () => {
  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Report')
  XLSX.writeFile(wb, `report-${Date.now()}.xlsx`)
}
```

### 6.4 — Replace Paytm checksum with official SDK

**File:** `src/lib/paytm-checksum.ts` (80 lines)

**Install:**
```bash
npm install paytm-pg-node-sdk
```

Replace custom `PaytmChecksum.generateSignature()` / `.verifySignature()` with SDK's built-in methods. Verify output matches pre-refactor values.

### Session 6 Acceptance

- [ ] Map picker loads with markers, search, geolocation
- [ ] Phone `+91 98765 43210` parses correctly
- [ ] Excel `.xlsx` export works
- [ ] Paytm checksum output matches old values

---

## SESSION 7 — Final Polish (2 hrs)

**Branch:** `git checkout -b phase5-polish`

### Steps

| # | Action |
|---|---|
| 1 | `npm run build` — zero errors |
| 2 | `npm run lint -- --max-warnings=0` — zero warnings |
| 3 | Verify no file over 700 lines |
| 4 | Verify `src/hooks/use-debounce.ts` is gone |
| 5 | Verify all CSV uses papaparse |
| 6 | Verify all cache uses lru-cache |
| 7 | Verify all dates go through date-helpers |
| 8 | Verify all phone parsing uses libphonenumber-js |
| 9 | Smoke test: homepage → product → cart → checkout → admin → all tabs |

### Commit

```bash
git commit -m "chore(phase5): final polish - build, lint, verification"
```

---

## WHAT NOT TO TOUCH

| Item | Reason |
|---|---|
| `fastapi-backend/routers/` | Clean, 1.4K LOC |
| `prisma/schema.prisma` | Database is live |
| `src/lib/auth.ts` | Complex auth logic |
| `src/components/ui/` | shadcn components |
| `.env` / `.env.example` | Config files |
| `src/app/api/` route handlers | Stable |

---

## GIT BRANCH STRUCTURE

```
main
├── phase0-prep        ✅ DONE (cleanup)
├── phase1-utilities   ✅ PARTIALLY DONE (cache + date-helpers; papaparse pending)
├── phase2-dashboard   ⬜ TODO (admin-dashboard split)
├── phase3-pages       ⬜ TODO (checkout, picker, delivery, inventory, cafe, restaurant)
├── phase4-upgrades    ⬜ TODO (maps, phone, excel, paytm)
└── phase5-polish      ⬜ TODO (final checks)
```

Each branch from `main`. Never merge backward.

**Rollback:** `git revert <commit-hash>` per commit. Full rollback: `git checkout main`.

---

## COMPLETED DELIVERABLES

| File | Change |
|---|---|
| `src/lib/search-cache.ts` | Map → LRUCache (max 200, 5min TTL) |
| `src/lib/settings-cache.ts` | bare vars → LRUCache (max 50, 3min TTL) |
| `src/lib/date-helpers.ts` | NEW — 6 shared date functions |
| `src/hooks/use-debounce.ts` | DELETED (dead code, no imports) |
| `src/types/papaparse.d.ts` | NEW — type stub (remove after install) |
| `src/types/lru-cache.d.ts` | NEW — type stub (remove after install) |
| `src/scripts/` | 19 files moved from root |
| `public/brand/` | 2 logo images moved from root |
| `.gitignore` | Added `fastapi-backend/venv/` |
| `src/app/layout.tsx` | Updated icon path `/brand/...` |
| `src/app/page.tsx` | Updated schema.org image URL |

---

## REMAINING WORK SUMMARY

| Session | Focus | Files Changed | Time | Risk |
|---|---|---|---|---|
| 1 | Install deps + CSV papaparse | 1 | 45 min | Low |
| 2 | Remove type stubs + package.json | 2 | 15 min | Low |
| 3 | Date helpers across 22 files | 22 | 2-3 hrs | Low-Medium |
| 4 | Dashboard 7444 → 500 lines | 8 | 6-8 hrs | Medium |
| 5 | Extract 6 heavy pages | 15 | 5-6 hrs | Medium |
| 6 | Maps + phone + Excel + Paytm | 8 | 4-5 hrs | Medium |
| 7 | Build + lint + smoke test | — | 2 hrs | Low |
