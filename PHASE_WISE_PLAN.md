# FastKirana — Phase-wise Execution Plan

> **Current State:** Session 0 + partial Session 1 done.
> **Total Remaining:** ~7-8 phases, ~20-25 hours across 4-5 sessions.

---

## PHASE 1 — Quick Wins (45 min)

**Goal:** Clean up remaining mess from Session 0-1.

### 1.1 — Delete `_test.js` from root

```
File: _test.js (root)
Action: Delete or move to src/scripts/
```

### 1.2 — Delete unused type stubs

```
File: src/types/papaparse.d.ts
Action: Delete — papaparse is installed and has its own types

File: src/types/lru-cache.d.ts
Action: Delete — lru-cache is installed and has its own types

Keep: src/types/web-push.d.ts — web-push needs this stub
Keep: src/types/next-auth.d.ts — next-auth needs this stub
Keep: src/types/nodemailer.d.ts — nodemailer needs this stub
```

### 1.3 — Verify package.json

Check that these are in `dependencies`:
```
"papaparse": "^5.4.1"
"lru-cache": "^10.0.0"
```

If missing, add them:
```bash
npm install papaparse lru-cache
```

### 1.4 — Commit

```bash
git add -A
git commit -m "chore(phase1): quick wins — delete test.js, remove type stubs, verify deps"
```

**Verification:**
```bash
npm run build
npm run lint
```

---

## PHASE 2 — Date Helpers Complete (2-3 hrs)

**Goal:** Replace all remaining inline date formatting (16 files) with helpers.

### File List (in order of simplicity):

| # | File | Lines | Pattern | Helper to use |
|---|---|---|---|---|
| 1 | `src/app/order/[id]/page.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy')` |
| 2 | `src/app/product/[slug]/page.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy')` |
| 3 | `src/components/food/restaurant-storefront.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy')` |
| 4 | `src/components/admin/restaurant-payouts-ledger.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy')` |
| 5 | `src/components/admin/admin-reports.tsx` | ~5 | `toLocaleDateString('en-US', { month: 'short' })` | `formatDate(date, 'MMM')` |
| 6 | `src/components/admin/admin-bulk-update.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy, h:mm a')` |
| 7 | `src/components/admin/admin-alerts.tsx` | ~5 | `toLocaleDateString('en-IN')` | `formatDate(date, 'dd MMM yyyy')` |
| 8 | `src/components/admin/admin-inward.tsx` | ~5 | `toLocaleDateString` | `formatDate(date, 'dd MMM yyyy')` |
| 9 | `src/app/api/admin/orders/create-on-behalf/route.ts` | ~5 | `toLocaleTimeString` | `formatOrderTime(date)` |
| 10 | `src/app/api/cafe/reports/route.ts` | ~10 | `toLocaleDateString` | `formatDate(date, 'dd MMM yyyy')` |
| 11 | `src/app/api/restaurant/reports/route.ts` | ~10 | `toLocaleDateString` | `formatDate(date, 'dd MMM yyyy')` |

For each file:
1. Add import: `import { formatDate, formatOrderTime } from '@/lib/date-helpers'`
2. Find inline date code
3. Replace with helper call
4. Remove unused `date-fns` imports if any

### Special Cases:

**`admin-dashboard.tsx`** (4 occurrences):
- Line 1010: `new Date(c.createdAt).toLocaleDateString('en-IN')` → `formatDate(c.createdAt, 'dd MMM yyyy')`
- Line 4232: `new Date(u.createdAt).toLocaleDateString('en-IN', {...})` → `formatDate(u.createdAt, 'dd MMM yyyy, h:mm a')`
- Line 4399: `new Date(r.createdAt).toLocaleDateString('en-IN', {...})` → `formatDate(r.createdAt, 'dd MMM yyyy')`
- Line 4742: `new Date(c.expiresAt).toLocaleDateString('en-IN', {...})` → `formatDate(c.expiresAt, 'dd MMM yyyy')`

**After this phase:**
- `toLocaleDateString` / `toLocaleTimeString` should have ZERO occurrences in `src/` (except inside `date-helpers.ts` itself)
- All date formatting goes through one file

### Commit

```bash
git add -A
git commit -m "refactor(phase2): replace inline date formatting with date-helpers across 16 files"
```

**Verification:**
```bash
npm run build
npm run lint
grep -rn "toLocaleDateString\|toLocaleTimeString" src/ --include='*.ts' --include='*.tsx' | wc -l
# Should return 0
```

---

## PHASE 3 — Admin Dashboard Split (6-8 hrs)

**Goal:** Break `admin-dashboard.tsx` (6,597 lines) into sub-components.

### Pass 1 — Move remaining constants (30 min)

Check if any constants still inline:
```bash
grep -n "^const " src/components/admin/admin-dashboard.tsx
```

Move any remaining large constants to `src/lib/constants.ts`.

**Commit:**
```bash
git commit -m "refactor(dashboard): move remaining constants to src/lib/constants.ts"
```

### Pass 2 — Extract hub navigation (1 hr)

Create `src/components/admin/dashboard/hub-nav.tsx`

**Props:**
```ts
interface HubNavProps {
  activeHub: string
  setActiveHub: (hub: string) => void
  activeTab: TabType
  setActiveTab: (tab: TabType) => void
}
```

Copy the hub navigation JSX (5 hub cards). Replace in dashboard with `<HubNav {...} />`.

**Commit:**
```bash
git commit -m "refactor(dashboard): extract hub navigation to dashboard/hub-nav.tsx"
```

### Pass 3 — Extract stats cards (30 min)

Create `src/components/admin/dashboard/stats-cards.tsx`

**Props:** `stats` object

**Commit:**
```bash
git commit -m "refactor(dashboard): extract stats cards to dashboard/stats-cards.tsx"
```

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

Replace `{activeTab === 'orders' && (...)}` block.

**Commit:**
```bash
git commit -m "refactor(dashboard): extract orders tab to dashboard/orders-tab.tsx"
```

### Pass 5 — Extract remaining panels (2-3 hrs)

| Component | New File | Lines |
|---|---|---|
| Live carts panel | `dashboard/live-carts-panel.tsx` | ~150 |
| WhatsApp alert modal | `dashboard/whatsapp-alert-modal.tsx` | ~100 |
| Active carts section | `dashboard/active-carts-section.tsx` | ~150 |

**Commit each separately.**

### Target After Phase 3

```
src/components/admin/admin-dashboard.tsx  (~500 lines, orchestrator)
src/components/admin/dashboard/
├── hub-nav.tsx              (~150 lines)
├── stats-cards.tsx          (~100 lines)
├── orders-tab.tsx           (~300 lines)
├── live-carts-panel.tsx     (~150 lines)
├── whatsapp-alert-modal.tsx (~100 lines)
└── active-carts-section.tsx (~150 lines)
```

**Verification:**
```bash
wc -l src/components/admin/admin-dashboard.tsx  # should be < 500
npm run build
```

---

## PHASE 4 — Heavy Page Extraction (5-6 hrs)

**Goal:** No file over 700 lines. Extract from 6 biggest pages.

### 4.1 — `src/app/checkout/page.tsx` (1,918 → ~400)

Create `src/app/checkout/components/`:

| New File | What | Approx Lines |
|---|---|---|
| `order-summary.tsx` | Items, subtotals, tax, total | ~200 |
| `delivery-selector.tsx` | Address, slot, instructions | ~150 |
| `coupon-input.tsx` | Coupon code + validation | ~100 |
| `payment-section.tsx` | COD, online, Paytm | ~200 |

### 4.2 — `src/app/picker/page.tsx` (1,865 → ~400)

Create `src/app/picker/components/`:

| New File | What | Approx Lines |
|---|---|---|
| `order-list.tsx` | Scrollable order list | ~200 |
| `filters.tsx` | Status tabs, search | ~100 |
| `actions-bar.tsx` | Bulk actions, print | ~100 |

### 4.3 — `src/app/delivery/page.tsx` (1,774 → ~400)

Create `src/app/delivery/components/`:

| New File | What | Approx Lines |
|---|---|---|
| `order-map.tsx` | Map view | ~200 |
| `order-list.tsx` | Assigned orders | ~150 |
| `wallet-card.tsx` | Earnings, balance | ~150 |

### 4.4 — `src/components/admin/admin-inventory-center.tsx` (1,765 → ~500)

Create `src/components/admin/inventory/`:

| New File | What | Approx Lines |
|---|---|---|
| `stock-table.tsx` | Inventory table | ~250 |
| `forecast-panel.tsx` | Forecast chart | ~150 |
| `pos-checkout.tsx` | POS form | ~200 |

### 4.5 — `src/components/admin/restaurant-orders-console.tsx` (1,494 → ~400)

Create `src/components/admin/restaurant/`:

| New File | What | Approx Lines |
|---|---|---|
| `order-tabs.tsx` | Tab navigation | ~100 |
| `order-details.tsx` | Order detail view | ~250 |

### 4.6 — `src/components/admin/restaurant-form.tsx` (1,460 → ~500)

Create `src/components/admin/restaurant/`:

| New File | What | Approx Lines |
|---|---|---|
| `basic-info-section.tsx` | Name, contact, address | ~150 |
| `menu-sections-editor.tsx` | Menu categories | ~200 |
| `settings-section.tsx` | Hours, delivery, commission | ~200 |

### Pattern for Each:

1. Open file
2. Find logical sections (look for comments, distinct JSX blocks)
3. Extract each section + its state into a new component file
4. Replace with `<NewComponent {...props} />`
5. Run `npm run build`
6. Commit

**Verification:**
```bash
find src -type f \( -name '*.ts' -o -name '*.tsx' \) -exec wc -l {} + | sort -rn | awk '$1 > 700'
# Should return nothing
```

---

## PHASE 5 — Remaining Large Files (4-5 hrs)

**Goal:** Get remaining files under 700 lines.

| File | Current Lines | Target | Action |
|---|---|---|---|
| `admin-settings.tsx` | 1,399 | ~500 | Extract settings tabs into sub-components |
| `category-page-client.tsx` | 1,208 | ~400 | Extract category sections |
| `create-order-modal.tsx` | 1,172 | ~400 | Extract customer search, product search, order summary |
| `restaurant-catalog-manager.tsx` | 1,062 | ~500 | Extract product list, add/edit form |
| `account-dashboard.tsx` | 991 | ~500 | Extract profile, orders, addresses tabs |
| `admin-banners.tsx` | 932 | ~500 | Extract banner list, add/edit form |
| `deals-curation-hub.tsx` | 910 | ~500 | Extract deal sections |
| `admin-restaurant-console.tsx` | 877 | ~500 | Extract restaurant tabs |
| `restaurant-storefront.tsx` | 817 | ~500 | Extract menu, cart sections |
| `cafe-section.tsx` | 811 | ~500 | Extract cafe menu, cart |

---

## PHASE 6 — Maps, Phone, Excel, Paytm (4-5 hrs)

### 6.1 — Merge 3 map files → 1

**Files to delete:**
- `src/components/shared/map-picker.tsx` (415 lines)
- `src/components/shared/free-map-picker.tsx` (366 lines)
- `src/components/shared/location-picker.tsx` (628 lines)

**Install:**
```bash
npm install @react-google-maps/api
```

**Create:** `src/components/shared/map-picker.tsx` (~200 lines)

**Prerequisite:** `NEXT_PUBLIC_GOOGLE_MAPS_KEY` in `.env`

**Update all imports** across codebase.

### 6.2 — Replace phone parsing

**Files:**
- `src/lib/fast2sms.ts`
- `src/lib/whatsapp.ts`

**Install:**
```bash
npm install libphonenumber-js
```

Replace manual `phone.replace(/\D/g, '')` with `parsePhoneNumberFromString()`.

### 6.3 — Add Excel export

**Install:**
```bash
npm install xlsx
```

Find CSV export in admin reports. Add `.xlsx` export button.

### 6.4 — Replace Paytm checksum

**File:** `src/lib/paytm-checksum.ts` (80 lines)

**Install:**
```bash
npm install paytm-pg-node-sdk
```

Replace custom implementation with SDK.

---

## PHASE 7 — Final Polish (2 hrs)

### Steps

| # | Action |
|---|---|
| 1 | `npm run build` — zero errors |
| 2 | `npm run lint -- --max-warnings=0` — zero warnings |
| 3 | `npx ts-prune` — find unused exports (install: `npm install -D ts-prune`) |
| 4 | Add `@next/bundle-analyzer` to `next.config.ts` |
| 5 | Smoke test: homepage → product → cart → checkout → admin → all tabs |
| 6 | Verify no file over 700 lines |
| 7 | Verify `src/hooks/use-debounce.ts` is gone |
| 8 | Verify all CSV uses papaparse |
| 9 | Verify all cache uses lru-cache |
| 10 | Verify all dates go through date-helpers |
| 11 | Verify all phone parsing uses libphonenumber-js |
| 12 | Verify Paytm checksum uses official SDK |

### Commit

```bash
git commit -m "chore(phase7): final polish — build, lint, bundle audit, smoke test"
```

---

## GIT BRANCH STRUCTURE

```
main
├── phase1-quick-wins      ⬜ TODO
├── phase2-date-helpers    ⬜ TODO
├── phase3-dashboard-split ⬜ TODO
├── phase4-heavy-pages     ⬜ TODO
├── phase5-remaining-files ⬜ TODO
├── phase6-libraries       ⬜ TODO
└── phase7-polish          ⬜ TODO
```

Each phase branches from `main`. Never merge backward.

**Rollback:**
```bash
git revert <commit-hash>   # per-commit rollback
git checkout main          # full rollback
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

## TIMELINE

| Phase | Focus | Time | Risk |
|---|---|---|---|
| 1 | Quick wins | 45 min | None |
| 2 | Date helpers | 2-3 hrs | Low |
| 3 | Dashboard split | 6-8 hrs | Medium |
| 4 | Heavy pages | 5-6 hrs | Medium |
| 5 | Remaining files | 4-5 hrs | Medium |
| 6 | Libraries | 4-5 hrs | Medium |
| 7 | Polish | 2 hrs | Low |
| **Total** | | **~24-30 hrs** | |

Split across **4-5 working sessions** (5-6 hrs each).

---

## SUCCESS METRICS

After all phases:
- No file over 700 lines
- No inline `toLocaleDateString` / `toLocaleTimeString` (except in date-helpers.ts)
- No custom debounce hook
- All CSV parsing via papaparse
- All caching via lru-cache
- All date formatting via date-helpers
- All phone parsing via libphonenumber-js
- Maps consolidated to 1 file
- Paytm uses official SDK
- Build passes, lint passes with zero warnings
