# FastKirana — Antigravity Implementation Plan

> **Date:** 2026-08-05
> **Stack:** Next.js 16 + React 19 + TS (~79K LOC, 270 files) | FastAPI backend (~1.4K LOC)
> **Biggest risk:** `src/components/admin/admin-dashboard.tsx` = 7,444 lines

---

## SESSION 1 — Cleanup & Safety (45 min)

**Goal:** Housekeeping only. Zero functional changes.

### Step 1.1 — Create Branch

```bash
git checkout main
git checkout -b phase0-prep
git status  # must be clean
```

### Step 1.2 — Move Root-Level Scripts

These files are in the project root but belong in `src/scripts/`:

| File (current) | Action |
|---|---|
| `check_all_products.ts` | Move to `src/scripts/` |
| `check_product.ts` | Move to `src/scripts/` |
| `db-size.ts` | Move to `src/scripts/` |
| `delete_cancelled_orders.ts` | Move to `src/scripts/` |
| `inspect.ts` | Move to `src/scripts/` |
| `scratch-add.ts` | Move to `src/scripts/` |
| `scratch-delete.ts` | Move to `src/scripts/` |
| `scratch-db-test.ts` | Move to `src/scripts/` |
| `test_api_products.ts` | Move to `src/scripts/` |
| `test-compat-connect.ts` | Move to `src/scripts/` |
| `test-pg-connect.ts` | Move to `src/scripts/` |
| `test-pg.js` | Move to `src/scripts/` |
| `test-prisma-direct.ts` | Move to `src/scripts/` |

After moving, check if any other file imports these. Run:
```bash
grep -rn "from.*check_all_products\|from.*check_product\|from.*db-size\|from.*delete_cancelled\|from.*inspect\|from.*scratch-add\|from.*scratch-delete\|from.*scratch-db-test\|from.*test_api_products\|from.*test-compat-connect\|from.*test-pg-connect\|from.*test-pg\|from.*test-prisma-direct" src/ --include='*.ts' --include='*.tsx'
```

If grep returns results, update those import paths to point to `src/scripts/`.

### Step 1.3 — Move Logo Images

| File (current) | Move to |
|---|---|
| `fastkirana_app_icon.png` | `public/brand/fastkirana_app_icon.png` |
| `fastkirana_exact_logo_1784209515140.png` | `public/brand/fastkirana_exact_logo.png` |

Check for references:
```bash
grep -rn "fastkirana_app_icon\|fastkirana_exact_logo" src/ --include='*.ts' --include='*.tsx' --include='*.tsx'
```

Update any `<Image src="/fastkirana_...">` to `<Image src="/brand/fastkirana_...">`.

### Step 1.4 — Ignore venv

Edit `.gitignore`, add this line at the bottom:
```
fastapi-backend/venv/
```

Then run:
```bash
git rm -r --cached fastapi-backend/venv/
```

Verify:
```bash
git ls-files | grep venv   # should return nothing
```

### Step 1.5 — Commit

```bash
git add -A
git commit -m "chore(phase0): move scripts to src/scripts/, logos to public/brand/, ignore venv"
```

---

## SESSION 2 — Utility Replacements (3–4 hrs)

**Branch:**
```bash
git checkout main
git checkout -b phase1-utilities
```

---

### 2.1 — Delete Dead Debounce Hook

**File to delete:** `src/hooks/use-debounce.ts` (17 lines)

**Facts:**
- This file exists but is NOT imported anywhere in the codebase.
- `grep -rn "from.*use-debounce" src/` returns zero results.
- No other file uses `useDebounce` from this hook.

**Action:** Delete the file. That's it. No other files need changes.

**Note:** There IS inline debounce logic inside `src/components/admin/admin-dashboard.tsx` at line 432 (`const debouncedRefresh = () => { ... }`). This is a one-off SSE refresh throttle, not a reusable hook. Leave it as-is. It's not a library candidate — it's a specific timing guard for SSE events.

**Verify:** `npm run build` passes.

**Commit:**
```bash
git rm src/hooks/use-debounce.ts
git commit -m "refactor: delete unused use-debounce hook (dead code, no imports)"
```

---

### 2.2 — Replace Custom CSV Parsing with papaparse

**File to edit:** `src/components/admin/admin-csv-import.tsx` (780 lines)

**Install:**
```bash
npm install papaparse
```

**What to change in `admin-csv-import.tsx`:**

1. Add import at top:
   ```ts
   import Papa from 'papaparse'
   ```

2. Find the custom CSV parsing section (likely a function that does manual `split(',')` or regex-based parsing). Replace it with:
   ```ts
   // BEFORE (custom logic, ~50-100 lines):
   // const rows = rawText.split('\n').map(row => row.split(','))
   
   // AFTER (papaparse):
   Papa.parse(rawText, {
     header: true,
     skipEmptyLines: true,
     complete: (results) => {
       const rows = results.data as Record<string, string>[]
       // process rows...
     }
   })
   ```

3. papaparse automatically handles:
   - Quoted fields with commas inside: `"Mumbai, Maharashtra",500` → one cell
   - Multiline quoted values
   - Empty rows (with `skipEmptyLines: true`)
   - Different line endings (CRLF, LF)

**Verify:** Upload a CSV with this content:
```
name,price,city
"Amul Milk, 1L",45,"Mumbai, Maharashtra"
"Bread",30,Pune
```
Both "Mumbai, Maharashtra" and "Amul Milk, 1L" should parse as single cells.

**Expected result:** File goes from ~780 → ~450 lines.

**Commit:**
```bash
git add src/components/admin/admin-csv-import.tsx package.json package-lock.json
git commit -m "refactor: replace custom CSV parser with papaparse in admin-csv-import"
```

---

### 2.3 — Replace Cache Files with lru-cache

**File 1 to edit:** `src/lib/search-cache.ts` (45 lines)

**Current code:**
```ts
const cache = new Map<string, { data: SearchResult; expiresAt: number }>()

export function getCachedSearch(key: string): SearchResult | null {
  const cached = cache.get(key)
  if (!cached) return null
  if (Date.now() > cached.expiresAt) {
    cache.delete(key)
    return null
  }
  return cached.data
}

export function setCachedSearch(key: string, data: SearchResult, ttlMs = 300000) {
  cache.set(key, { data, expiresAt: Date.now() + ttlMs })
  if (cache.size > 200) {
    const now = Date.now()
    for (const [k, v] of cache.entries()) {
      if (now > v.expiresAt) cache.delete(k)
    }
    if (cache.size > 200) {
      const keys = Array.from(cache.keys())
      keys.slice(0, 50).forEach((k) => cache.delete(k))
    }
  }
}
```

**Replace entire file with:**
```ts
import { LRUCache } from 'lru-cache'

type SearchResult = {
  products: any[]
  pagination: {
    total: number | null
    page: number
    limit: number
    totalPages: number | null
    nextCursor?: string | null
  }
}

export const searchCache = new LRUCache<string, SearchResult>({
  max: 200,
  ttl: 5 * 60 * 1000, // 5 minutes
})

export function getCachedSearch(key: string): SearchResult | null {
  return searchCache.get(key) ?? null
}

export function setCachedSearch(key: string, data: SearchResult) {
  searchCache.set(key, data)
}
```

**File 2 to edit:** `src/lib/settings-cache.ts` (21 lines)

**Current code:**
```ts
let cachedSettings: any = null
let lastFetched: number = 0
const CACHE_TTL = 180000

export function getCachedSettings() {
  const now = Date.now()
  if (cachedSettings && (now - lastFetched < CACHE_TTL)) {
    return cachedSettings
  }
  return null
}

export function setCachedSettings(settings: any) {
  cachedSettings = settings
  lastFetched = Date.now()
}

export function clearSettingsCache() {
  cachedSettings = null
  lastFetched = 0
}
```

**Replace entire file with:**
```ts
import { LRUCache } from 'lru-cache'

export const settingsCache = new LRUCache<string, any>({
  max: 50,
  ttl: 3 * 60 * 1000, // 3 minutes
})

export function getCachedSettings() {
  return settingsCache.get('settings') ?? null
}

export function setCachedSettings(settings: any) {
  settingsCache.set('settings', settings)
}

export function clearSettingsCache() {
  settingsCache.delete('settings')
}
```

**Install:**
```bash
npm install lru-cache
```

**Then check all files that import from `search-cache.ts` or `settings-cache.ts`:**
```bash
grep -rn "from.*search-cache\|from.*settings-cache" src/ --include='*.ts' --include='*.tsx'
```

The exported function names (`getCachedSearch`, `setCachedSearch`, `getCachedSettings`, `setCachedSettings`, `clearSettingsCache`) stay the same, so callers should not need changes. But verify that `setCachedSearch` is called with only 2 arguments now (key + data), not 3 (the TTL parameter was removed).

If any caller passes a third argument (TTL), remove it:
```ts
// Before
setCachedSearch(key, data, 300000)

// After
setCachedSearch(key, data)
```

**Verify:** Run the app, do 500+ searches, check memory doesn't grow unbounded. Old entries auto-evict via LRU.

**Commit:**
```bash
git add src/lib/search-cache.ts src/lib/settings-cache.ts package.json package-lock.json
git commit -m "refactor: replace ad-hoc Map cache with lru-cache in search-cache and settings-cache"
```

---

### 2.4 — Consolidate Date/Time Formatting

**Step A: Create new file** `src/lib/date-helpers.ts`

Write this exact content:
```ts
import { format, formatDistanceToNow, isToday, isTomorrow, addMinutes, parseISO } from 'date-fns'

export function formatOrderTime(date: string | Date): string {
  return format(new Date(date), 'h:mm a')
}

export function formatDeliveryETA(date: string | Date): string {
  const d = new Date(date)
  if (isToday(d)) return `Today, ${format(d, 'h:mm a')}`
  if (isTomorrow(d)) return `Tomorrow, ${format(d, 'h:mm a')}`
  return format(d, 'MMM d, h:mm a')
}

export function formatRelativeTime(date: string | Date): string {
  return formatDistanceToNow(new Date(date), { addSuffix: true })
}

export function addMinutesTo(date: Date | string, mins: number): Date {
  return addMinutes(new Date(date), mins)
}

export function parseISODate(dateStr: string): Date {
  return parseISO(dateStr)
}
```

Note: `date-fns` is already installed in `package.json`. No new install needed.

**Step B: Find all files with inline date formatting**

Run this:
```bash
grep -rln "toLocaleTimeString\|toLocaleDateString\|getHours()\|getMinutes()\|\.getTime()" src/ --include='*.ts' --include='*.tsx' | grep -v node_modules
```

This returns ~10-15 files. For each file:

1. Open the file.
2. Find the inline date formatting code.
3. Replace with the appropriate helper from `@/lib/date-helpers`.
4. Add import: `import { formatOrderTime, formatDeliveryETA, formatRelativeTime } from '@/lib/date-helpers'`

**Common patterns to replace:**

```ts
// Pattern 1: toLocaleTimeString
new Date(createdAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
// Replace with:
formatOrderTime(createdAt)

// Pattern 2: manual getHours/getMinutes
const d = new Date(date)
const hours = d.getHours()
const mins = d.getMinutes()
const ampm = hours >= 12 ? 'PM' : 'AM'
const display = `${hours % 12 || 12}:${mins.toString().padStart(2, '0')} ${ampm}`
// Replace with:
formatOrderTime(date)

// Pattern 3: isToday check
new Date(date).toDateString() === new Date().toDateString()
// Replace with:
isToday(new Date(date))
```

**Important files to check (already identified by audit):**
- `src/app/admin/page.tsx`
- `src/app/admin/restaurants/page.tsx`
- `src/app/api/admin/alerts/route.ts`
- `src/app/api/admin/coupons/route.ts`
- `src/app/api/admin/forecast/route.ts`
- `src/app/api/admin/inventory/forecast/route.ts`
- `src/app/api/admin/inventory/pos-checkout/route.ts`
- `src/app/api/admin/inward/route.ts`
- `src/app/api/admin/live-carts/route.ts`
- `src/app/api/admin/orders/create-on-behalf/route.ts`
- `src/app/delivery/page.tsx`
- `src/app/food/[slug]/page.tsx`
- `src/app/picker/page.tsx`
- `src/components/account/account-dashboard.tsx`
- `src/components/admin/admin-cafe-sections.tsx`
- `src/components/admin/admin-dashboard.tsx`
- `src/components/admin/admin-inventory-center.tsx`
- `src/components/admin/cafe-orders-console.tsx`
- `src/components/admin/create-order-modal.tsx`
- `src/components/admin/restaurant-catalog-manager.tsx`
- `src/components/admin/restaurant-menu-sections-editor.tsx`
- `src/components/admin/restaurant-orders-console.tsx`

**Verify:** Check admin dashboard, checkout page, delivery page, picker page — all dates/times display correctly.

**Commit:**
```bash
git add src/lib/date-helpers.ts
# + all files you modified
git commit -m "refactor(phase1): consolidate date formatting into src/lib/date-helpers.ts"
```

---

### Phase 1 Acceptance Criteria

- [ ] `npm run build` passes clean
- [ ] `npm run lint` passes with zero new warnings
- [ ] `src/hooks/use-debounce.ts` is deleted
- [ ] `admin-csv-import.tsx` uses `Papa.parse()` for CSV parsing
- [ ] `search-cache.ts` and `settings-cache.ts` use `LRUCache` from `lru-cache`
- [ ] `src/lib/date-helpers.ts` exists and is imported by 5+ files
- [ ] No inline `toLocaleTimeString` / `getHours()/getMinutes()` in date formatting (only in non-date contexts)
- [ ] CSV with quoted commas parses correctly
- [ ] Dates display correctly on admin, checkout, delivery pages

---

## SESSION 3 — Admin Dashboard Split (6–8 hrs)

**Branch:**
```bash
git checkout main
git checkout -b phase2-dashboard
```

### What NOT to Touch

These are already separate files, loaded via `dynamic()`:
- `admin-analytics.tsx`
- `admin-alerts.tsx`
- `admin-bulk-update.tsx`
- `admin-reports.tsx`
- `admin-restaurant-report.tsx`
- `admin-inventory-center.tsx`
- `admin-banners.tsx`
- `admin-settings.tsx`
- `admin-csv-import.tsx`
- `admin-push-notifications.tsx`
- `admin-promotions.tsx`
- `admin-forecast.tsx`
- `admin-restaurant-console.tsx`
- `admin-rider-cash.tsx`

**Do not modify any of these files.** They are already extracted.

### What TO Extract

The remaining 7,444 lines contain:
1. Inline constants
2. Hub navigation JSX
3. Stats cards JSX
4. Orders tab JSX (table, filters, actions)
5. Live carts panel JSX
6. WhatsApp alert modal JSX
7. ~80 state variables and event handlers

### Pass 1 — Move Constants Out

**File:** `src/components/admin/admin-dashboard.tsx`

**Lines 93–130:** `PRODUCT_TEMPLATES` array
**Lines 132–178:** `HUB_CONFIG` array

**Action:** Cut both constants. Paste into `src/lib/constants.ts`.

In `constants.ts`, add after existing exports:
```ts
export const PRODUCT_TEMPLATES = [
  {
    id: 'fresh_produce',
    label: '🥦 Fresh Produce (Fruits & Veggies)',
    description: 'Fresh fruits, vegetables',
    categoryName: 'Fresh Fruits & Vegetables',
    unit: '1 kg',
    minStock: 15,
    tags: 'fresh, produce'
  },
  {
    id: 'grocery_essential',
    label: '🥤 Grocery Essential',
    description: 'Packaged foods, staples',
    categoryName: 'Atta, Rice & Dal',
    unit: '1 pc',
    minStock: 10,
    tags: 'essential, grocery'
  },
  {
    id: 'cafe_snack',
    label: '☕ Cafe Snack',
    description: 'Fresh cafe items',
    categoryName: 'FastKirana Cafe',
    unit: '1 plate',
    minStock: 5,
    tags: 'cafe, freshlyprepared'
  },
  {
    id: 'household_personal',
    label: '🧴 Household Needs',
    description: 'Soaps, cleaners, detergents',
    categoryName: 'Household Needs',
    unit: '1 Pack',
    minStock: 5,
    tags: 'cleaning, household'
  }
] as const

export const HUB_CONFIG = [
  {
    key: 'orders_hub',
    label: 'Orders & Fulfillment',
    description: 'Live order queue, fulfillment dispatch, pickup & table orders, and historical orders',
    icon: ShoppingBag,
    color: 'from-amber-500/10 to-orange-500/10',
    activeBorder: 'border-amber-500/60 ring-2 ring-amber-500/20',
    tabs: ['orders'] as const
  },
  {
    key: 'grocery',
    label: 'Products & Inventory',
    description: 'Manage products, categories, inward stock, low stock alerts, and bulk pricing updates',
    icon: Package,
    color: 'from-emerald-500/10 to-teal-500/10',
    activeBorder: 'border-emerald-500/60 ring-2 ring-emerald-500/20',
    tabs: ['products', 'categories', 'alerts', 'inward', 'bulk-update'] as const
  },
  {
    key: 'insights',
    label: 'Business Intelligence',
    description: 'Analytics dashboards, sales velocity, reports, restaurant payouts, and AI stock forecasting',
    icon: TrendingUp,
    color: 'from-blue-500/10 to-cyan-500/10',
    activeBorder: 'border-blue-500/60 ring-2 ring-blue-500/20',
    tabs: ['analytics', 'forecast', 'reports', 'restaurant-report'] as const
  },
  {
    key: 'ops',
    label: 'Operations',
    description: 'Real-time liveops tracker, rider COD settlements, and reviews moderation',
    icon: Zap,
    color: 'from-indigo-500/10 to-purple-500/10',
    activeBorder: 'border-indigo-500/60 ring-2 ring-indigo-500/20',
    tabs: ['liveops', 'users', 'rider-cash', 'reviews'] as const
  },
  {
    key: 'marketing',
    label: 'Marketing & Config',
    description: 'Promo banners, campaign coupons, global settings, and push notifications',
    icon: Ticket,
    color: 'from-rose-500/10 to-pink-500/10',
    activeBorder: 'border-rose-500/60 ring-2 ring-rose-500/20',
    tabs: ['banners', 'flash-deals', 'coupons', 'push-notifications', 'settings'] as const
  }
] as const
```

In `admin-dashboard.tsx`, add import:
```ts
import { PRODUCT_TEMPLATES, HUB_CONFIG } from '@/lib/constants'
```

Remove the inline definitions (lines 93–178).

**Verify:** `npm run build` passes. Admin page loads.

**Commit:**
```bash
git commit -m "refactor(dashboard): move PRODUCT_TEMPLATES and HUB_CONFIG to src/lib/constants.ts"
```

---

### Pass 2 — Extract Hub Navigation

**Create folder:** `src/components/admin/dashboard/`

**Create file:** `src/components/admin/dashboard/hub-nav.tsx`

**Props this component needs** (from admin-dashboard.tsx):
- `activeHub: string`
- `setActiveHub: (hub: string) => void`
- `activeTab: TabType`
- `setActiveTab: (tab: TabType) => void`

**What to copy from admin-dashboard.tsx:**
1. The hub navigation JSX section (the 5 hub buttons/cards at the top of the dashboard).
2. Look for the JSX that renders `HUB_CONFIG.map(...)` — that's the hub nav.
3. Copy that entire JSX block + any handler functions it uses.

**In admin-dashboard.tsx, replace that JSX block with:**
```tsx
<DashboardHubNav
  activeHub={activeHub}
  setActiveHub={setActiveHub}
  activeTab={activeTab}
  setActiveTab={setActiveTab}
/>
```

**Verify:** Admin page loads. Hub navigation works (clicking hubs switches tabs).

**Commit:**
```bash
git commit -m "refactor(dashboard): extract hub navigation to dashboard/hub-nav.tsx"
```

---

### Pass 3 — Extract Stats Cards

**Create file:** `src/components/admin/dashboard/stats-cards.tsx`

**Props:**
- `stats: { revenue: number; orderCount: number; userCount: number; lowStockCount: number }`

**What to extract:** The stats cards section at the top showing Revenue, Orders, Users, Low Stock numbers.

**In admin-dashboard.tsx, replace with:**
```tsx
<DashboardStatsCards stats={stats} />
```

**Commit:**
```bash
git commit -m "refactor(dashboard): extract stats cards to dashboard/stats-cards.tsx"
```

---

### Pass 4 — Extract Orders Tab

**Create file:** `src/components/admin/dashboard/orders-tab.tsx`

**This is the biggest extraction.** The orders tab contains:
- Order status filter buttons (ALL, PENDING, CONFIRMED, etc.)
- Search input for orders
- Orders table with rows
- Order action buttons (view, delete, status update)

**Props to pass:**
```ts
interface OrdersTabProps {
  orders: any[]
  orderCounts: Record<string, number>
  orderStatusFilter: string
  setOrderStatusFilter: (filter: string) => void
  orderSearchQuery: string
  setOrderSearchQuery: (query: string) => void
  updatingOrderId: string | null
  onUpdateOrderStatus: (orderId: string, status: string) => void
  onDeleteOrder: (orderId: string) => void
}
```

**In admin-dashboard.tsx, find the orders tab JSX** (the `{activeTab === 'orders' && (...)}` block) and replace with:
```tsx
{activeTab === 'orders' && (
  <OrdersTab
    orders={orders}
    orderCounts={orderCounts}
    orderStatusFilter={orderStatusFilter}
    setOrderStatusFilter={setOrderStatusFilter}
    orderSearchQuery={orderSearchQuery}
    setOrderSearchQuery={setOrderSearchQuery}
    updatingOrderId={updatingOrderId}
    onUpdateOrderStatus={handleUpdateOrderStatus}
    onDeleteOrder={handleDeleteOrder}
  />
)}
```

**Commit:**
```bash
git commit -m "refactor(dashboard): extract orders tab to dashboard/orders-tab.tsx"
```

---

### Pass 5 — Extract Remaining Panels

Extract in this order:

1. **Live carts panel** → `dashboard/live-carts-panel.tsx`
   - Props: `activeCarts`, `activeCartsCount`, `isLoadingCarts`, `cartsRefreshKey`, `setCartsRefreshKey`
   - Replace JSX block where live carts are rendered

2. **WhatsApp alert modal** → `dashboard/whatsapp-alert-modal.tsx`
   - Props: `isOpen`, `onClose`, `targetUser`, `message`, `selectedTemplateIdx`
   - Replace the WhatsApp modal JSX

3. **Any other inline sections** → extract to their own files in `dashboard/`

**Commit each separately.**

---

### Pass 6 — State Reduction (Optional, if time permits)

If the dashboard still feels heavy after Pass 5, consider:

- Group order-related state into a `useReducer`:
  ```ts
  type OrderState = {
    orders: any[]
    orderCounts: Record<string, number>
    orderStatusFilter: string
    orderSearchQuery: string
    updatingOrderId: string | null
  }
  ```
- Move SSE/EventSource logic into a `useSSEOrders()` custom hook.

**This pass is optional.** The main goal (7,444 → under 500 lines) is achieved by Pass 5.

---

### Session 3 Acceptance Criteria

- [ ] `admin-dashboard.tsx` is under 500 lines
- [ ] `src/components/admin/dashboard/` has 5+ extracted files
- [ ] `npm run build` passes
- [ ] Admin page loads in browser, no console errors
- [ ] All tabs render: Orders, Products, Categories, Users, Reviews, Coupons, Analytics, Alerts, Bulk Update, Reports, Restaurant Report, Inward, Banners, Settings, Liveops, Push Notifications, Flash Deals, Forecast, Rider Cash, Restaurant Console
- [ ] Order status updates still work
- [ ] Cart actions still work
- [ ] KOT printing still works

---

## SESSION 4 — Heavy Page Extraction (5–6 hrs)

**Branch:**
```bash
git checkout main
git checkout -b phase3-pages
```

### Rule for All Files Below

For each file:
1. Open the file.
2. Identify the **main return() block** — this is the page-level JSX.
3. Inside it, find **distinct sections** separated by comments or blank lines.
4. Each section becomes a new component file.
5. Extract the section + its related state/handlers into the new file.
6. Replace the original JSX with `<NewComponent {...props} />`.
7. Run `npm run build`.
8. Commit.

---

### 4.1 — `src/app/checkout/page.tsx` (1,918 → ~400 lines)

**Create folder:** `src/app/checkout/components/`

**Sections to extract:**

| New File | What It Contains | Approx Lines |
|---|---|---|
| `order-summary.tsx` | Order items list, subtotals, tax, total | ~200 |
| `delivery-selector.tsx` | Address selection, delivery slot, instructions | ~150 |
| `coupon-input.tsx` | Coupon code input + apply button + validation message | ~100 |
| `payment-section.tsx` | Payment method selection (COD, online), Paytm button | ~200 |

**Pattern:**
```tsx
// In checkout/page.tsx, replace a section with:
<OrderSummary items={cartItems} onQuantityChange={handleQuantityChange} />

// In checkout/components/order-summary.tsx:
export function OrderSummary({ items, onQuantityChange }) {
  return (
    <div>
      {items.map(item => (
        <div key={item.id}>...</div>
      ))}
    </div>
  )
}
```

---

### 4.2 — `src/app/picker/page.tsx` (1,864 → ~400 lines)

**Create folder:** `src/app/picker/components/`

| New File | What It Contains | Approx Lines |
|---|---|---|
| `order-list.tsx` | The scrollable list of orders | ~200 |
| `filters.tsx` | Status filter tabs, search bar | ~100 |
| `actions-bar.tsx` | Bulk actions, print buttons | ~100 |

---

### 4.3 — `src/app/delivery/page.tsx` (1,780 → ~400 lines)

**Create folder:** `src/app/delivery/components/`

| New File | What It Contains | Approx Lines |
|---|---|---|
| `order-map.tsx` | Map view showing delivery route/location | ~200 |
| `order-list.tsx` | Assigned orders list for delivery person | ~150 |
| `wallet-card.tsx` | Earnings, balance, today's stats | ~150 |

---

### 4.4 — `src/components/admin/admin-inventory-center.tsx` (1,765 → ~500 lines)

**Create folder:** `src/components/admin/inventory/`

| New File | What It Contains | Approx Lines |
|---|---|---|
| `stock-table.tsx` | Product inventory table with stock levels | ~250 |
| `forecast-panel.tsx` | Demand forecast chart/table | ~150 |
| `pos-checkout.tsx` | POS checkout form | ~200 |

---

### 4.5 — `src/components/admin/cafe-orders-console.tsx` (1,540 → ~400 lines)

**Create folder:** `src/components/admin/cafe/`

| New File | What It Contains | Approx Lines |
|---|---|---|
| `order-cards.tsx` | Cafe order cards with items | ~200 |
| `status-filters.tsx` | Filter tabs (pending, preparing, ready) | ~100 |

---

### 4.6 — `src/components/admin/restaurant-orders-console.tsx` (1,494 → ~400 lines)

**Create folder:** `src/components/admin/restaurant/`

| New File | What It Contains | Approx Lines |
|---|---|---|
| `order-tabs.tsx` | Tab navigation for orders | ~100 |
| `order-details.tsx` | Individual order detail view | ~250 |

---

### Session 4 Acceptance Criteria

- [ ] No file over 700 lines
- [ ] `npm run build` passes
- [ ] Checkout flow works end-to-end
- [ ] Picker page loads and functions
- [ ] Delivery page loads with map
- [ ] Cafe orders console works
- [ ] Restaurant orders console works
- [ ] Inventory center loads

---

## SESSION 5 — Map, Phone, Export, Paytm (4–5 hrs)

**Branch:**
```bash
git checkout main
git checkout -b phase4-upgrades
```

---

### 5.1 — Merge 3 Map Files → 1 with `@react-google-maps/api`

**Current files (to be removed):**
| File | Lines |
|---|---|
| `src/components/shared/map-picker.tsx` | 415 |
| `src/components/shared/free-map-picker.tsx` | 366 |
| `src/components/shared/location-picker.tsx` | 628 |

**Install:**
```bash
npm install @react-google-maps/api
```

**Create one new file:** `src/components/shared/map-picker.tsx` (~200 lines)

```tsx
'use client'

import { useJsApiLoader, GoogleMap, Marker, Autocomplete } from '@react-google-maps/api'
import { useState, useCallback } from 'react'

const libraries: ('places')[] = ['places']

interface MapPickerProps {
  onLocationSelect: (lat: number, lng: number, address: string) => void
  defaultCenter?: { lat: number; lng: number }
}

export function MapPicker({ onLocationSelect, defaultCenter }: MapPickerProps) {
  const [marker, setMarker] = useState(defaultCenter || null)
  const [address, setAddress] = useState('')
  const autocompleteRef = useRef<google.maps.places.Autocomplete | null>(null)

  const { isLoaded } = useJsApiLoader({
    googleMapsApiKey: process.env.NEXT_PUBLIC_GOOGLE_MAPS_KEY || '',
    libraries,
  })

  const onMapClick = useCallback((e: google.maps.MapMouseEvent) => {
    const lat = e.latLng?.lat()
    const lng = e.latLng?.lng()
    if (lat && lng) {
      setMarker({ lat, lng })
      // Reverse geocode
      geocodeLatLng(lat, lng).then(setAddress)
    }
  }, [])

  const onPlaceChanged = () => {
    const place = autocompleteRef.current?.getPlace()
    if (place?.geometry?.location) {
      const lat = place.geometry.location.lat()
      const lng = place.geometry.location.lng()
      setMarker({ lat, lng })
      setAddress(place.formatted_address || '')
      onLocationSelect(lat, lng, place.formatted_address || '')
    }
  }

  if (!isLoaded) return <div className="h-64 bg-gray-100 animate-pulse rounded-lg" />

  return (
    <div>
      <Autocomplete onLoad={(ref) => (autocompleteRef.current = ref)} onPlaceChanged={onPlaceChanged}>
        <input type="text" placeholder="Search location..." className="w-full p-2 border rounded mb-2" />
      </Autocomplete>
      <GoogleMap
        mapContainerStyle={{ width: '100%', height: '300px' }}
        center={marker || { lat: 20.5937, lng: 78.9629 }} // India center
        zoom={marker ? 15 : 5}
        onClick={onMapClick}
      >
        {marker && <Marker position={marker} />}
      </GoogleMap>
      {address && <p className="mt-2 text-sm text-gray-600">{address}</p>}
    </div>
  )
}
```

**Prerequisite:** Check `.env` has `NEXT_PUBLIC_GOOGLE_MAPS_KEY`. If not, this step cannot be completed — ask user.

**Delete the 3 old files after the new one works.**

**Update all imports across the codebase:**
```bash
grep -rn "from.*map-picker\|from.*free-map-picker\|from.*location-picker" src/ --include='*.ts' --include='*.tsx'
```

Change imports to point to the new `map-picker.tsx`. Adjust props if the new component's API differs from the old ones.

**Commit:**
```bash
git commit -m "refactor: merge 3 map components into one using @react-google-maps/api"
```

---

### 5.2 — Replace Phone Number Parsing with `libphonenumber-js`

**Files to edit:**
- `src/lib/fast2sms.ts` (43 lines) — line 10: `phone.replace(/\D/g, '').slice(-10)`
- `src/lib/whatsapp.ts` (152 lines) — line 12: `phone.replace(/\D/g, '')`

**Install:**
```bash
npm install libphonenumber-js
```

**In `fast2sms.ts`, replace line 10:**

Before:
```ts
const cleanPhone = phone.replace(/\D/g, '').slice(-10)
```

After:
```ts
import { parsePhoneNumberFromString } from 'libphonenumber-js'

const parsed = parsePhoneNumberFromString(phone, 'IN')
if (!parsed || !parsed.isValid()) {
  console.error('[Fast2SMS Error] Invalid phone number:', phone)
  return false
}
const cleanPhone = parsed.nationalNumber
```

**In `whatsapp.ts`, replace lines 12-15 (in both functions):**

Before:
```ts
let cleanPhone = phone.replace(/\D/g, '')
if (cleanPhone.length === 10) {
  cleanPhone = '91' + cleanPhone
}
```

After:
```ts
import { parsePhoneNumberFromString } from 'libphonenumber-js'

const parsed = parsePhoneNumberFromString(phone, 'IN')
if (!parsed || !parsed.isValid()) {
  console.error('[WhatsApp Error] Invalid phone number:', phone)
  return false
}
const cleanPhone = parsed.number // includes country code, e.g. "919876543210"
```

**Note:** `parsed.number` returns the full E.164 number (e.g., `919876543210`). This matches what the WhatsApp API expects. For Fast2SMS, use `parsed.nationalNumber` (10 digits without country code).

**Verify:** Test with these numbers:
- `+91 98765 43210` → should parse correctly
- `9876543210` → should parse as Indian number
- `+1 555 123 4567` → should parse as US number (or reject if India-only)

**Commit:**
```bash
git commit -m "refactor: replace manual phone parsing with libphonenumber-js in fast2sms and whatsapp"
```

---

### 5.3 — Add Excel Export with `xlsx`

**Current:** Admin reports export as CSV only.

**Install:**
```bash
npm install xlsx
```

**Find the CSV export code in admin reports.** Likely in:
- `src/components/admin/admin-reports.tsx`
- `src/components/admin/admin-csv-import.tsx`

**Add a second export button alongside the CSV one:**

```tsx
// Add import
import * as XLSX from 'xlsx'

// In the export function, add:
const handleExportXLSX = () => {
  const ws = XLSX.utils.json_to_sheet(reportData)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Report')
  XLSX.writeFile(wb, `fastkirana-report-${Date.now()}.xlsx`)
}

// In JSX, add button:
<Button onClick={handleExportXLSX}>
  <Download className="w-4 h-4 mr-2" />
  Export Excel
</Button>
```

**Verify:** Click "Export Excel", download `.xlsx`, open in Excel/LibreOffice — data should be correct.

**Commit:**
```bash
git commit -m "feat: add xlsx export option to admin reports"
```

---

### 5.4 — Replace Custom Paytm Checksum with Official SDK

**File to edit:** `src/lib/paytm-checksum.ts` (80 lines)

**Current:** Custom implementation of Paytm's checksum algorithm (AES-128-CBC encrypt + SHA256 + salt).

**Install:**
```bash
npm install paytm-pg-node-sdk
```

**Check what's calling this file:**
```bash
grep -rn "paytm-checksum\|PaytmChecksum\|generateSignature\|verifySignature" src/ --include='*.ts' --include='*.tsx'
```

**Replace `src/lib/paytm-checksum.ts` with:**

```ts
// Before replacing, read the exact API of paytm-pg-node-sdk's checksum module.
// The SDK provides its own checksum generation. Map the calls:

// BEFORE:
// import { PaytmChecksum } from './paytm-checksum'
// const checksum = await PaytmChecksum.generateSignature(params, merchantKey)

// AFTER:
import PaytmChecksum from 'paytm-pg-node-sdk/lib/checksum'

// The API may differ. Follow the SDK's documentation.
// Typically:
// const checksum = PaytmChecksum.generateSignature(params, merchantKey)
// const isValid = PaytmChecksum.verifySignature(params, merchantKey, receivedChecksum)
```

**Important:** Before deleting the custom implementation, check the SDK's exact API by looking at its types/docs. The function signatures may differ.

**Verify:** Generate a checksum with both old and new code for the same input params + key. Outputs must match exactly.

**Commit:**
```bash
git commit -m "refactor: replace custom Paytm checksum with official paytm-pg-node-sdk"
```

---

### Session 5 Acceptance Criteria

- [ ] `npm run build` passes
- [ ] Map picker loads, shows markers, accepts clicks, has search
- [ ] Phone `+91 98765 43210` parses correctly in Fast2SMS and WhatsApp
- [ ] Admin can export reports as `.xlsx` and open in Excel
- [ ] Paytm checksum output matches pre-refactor values

---

## SESSION 6 — Polish & Verification (2 hrs)

**Branch:**
```bash
git checkout main
git checkout -b phase5-polish
```

### Steps

| # | Action | Command |
|---|---|---|
| 1 | Full build | `npm run build` |
| 2 | Full lint | `npm run lint -- --max-warnings=0` |
| 3 | Unused exports | `npx ts-prune` (install first: `npm install -D ts-prune`) |
| 4 | Bundle size check | `npm install -D @next/bundle-analyzer` and add to `next.config.ts` |
| 5 | Smoke test | Homepage → product → cart → checkout → admin → all tabs |
| 6 | Verify venv ignored | `git ls-files \| grep venv` → nothing |

### Final Checklist

- [ ] No file over 700 lines
- [ ] `src/hooks/use-debounce.ts` is deleted
- [ ] All CSV parsing uses `papaparse`
- [ ] All caching uses `lru-cache`
- [ ] `src/lib/date-helpers.ts` exists and is used
- [ ] All phone parsing uses `libphonenumber-js`
- [ ] Paytm checksum uses official SDK
- [ ] 3 map files merged into 1
- [ ] Build passes, lint passes with zero warnings
- [ ] Admin dashboard loads, all tabs work
- [ ] Git has clean history (one commit per logical change)

### Commit
```bash
git commit -m "chore(phase5): final polish - build, lint, ts-prune, bundle audit"
```

---

## GIT WORKFLOW SUMMARY

```
main
├── phase0-prep        (cleanup)
├── phase1-utilities   (debounce, csv, cache, dates)
├── phase2-dashboard   (admin-dashboard split)
├── phase3-pages       (checkout, picker, delivery, inventory, cafe, restaurant)
├── phase4-upgrades    (maps, phone, excel, paytm)
└── phase5-polish      (final checks)
```

Each phase branches from `main`. Never merge backward.

**Rollback one phase:**
```bash
git revert --no-commit <from-commit>..<to-commit>
git commit -m "revert: rollback phase X"
```

**Rollback everything:**
```bash
git checkout main
git branch -D phase0-prep phase1-utilities phase2-dashboard phase3-pages phase4-upgrades phase5-polish
```

---

## WHAT NOT TO TOUCH

| Item | Reason |
|---|---|
| `fastapi-backend/routers/` | Already clean, 1.4K LOC, well-structured |
| `prisma/schema.prisma` | Database is live |
| `src/lib/auth.ts` | Auth logic is complex |
| `src/components/ui/` | shadcn components, auto-generated |
| `.env` / `.env.example` | Config files |
| `src/app/api/` route handlers | Functional, stable |

---

## NOTES

1. **Do not change business logic.** Only restructure code and swap implementations.
2. **Keep the same UI/UX.** All visual output must remain identical.
3. **Commit after each logical unit.** Not optional — enables rollback.
4. **Test after every commit.** `npm run build` + `npm run lint` before committing.
5. **If a page breaks, revert only that commit.** `git revert <hash>`.
6. **The `dynamic()` imports in admin-dashboard.tsx are already separate files** — do not modify them.
7. **Google Maps API key required for Session 5.** Confirm `NEXT_PUBLIC_GOOGLE_MAPS_KEY` exists in `.env` before starting.
8. **`src/hooks/use-debounce.ts` is dead code** — no imports anywhere. Just delete it. The inline `debouncedRefresh()` in admin-dashboard.tsx (line 432) is SSE-specific logic, not a debounce hook. Leave it alone.
