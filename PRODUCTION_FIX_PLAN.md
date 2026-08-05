# FastKirana - Production Fix Plan

## Overview
Post-cleanup code review se 3 critical areas identify huye hain jo production-ready banane ke liye fix karne hain.

## Priority Matrix

| Priority | Impact | Effort | Files Affected |
|----------|--------|--------|----------------|
| 🔴 HIGH | WCAG Violation + SSRF Risk | 15 min | 2 files |
| 🟠 MEDIUM | Data Integrity + Code Quality | 1 hour | 5+ files |
| 🟢 LOW | SEO + Future Scalability | 2 hours | 8+ files |

---

## Phase 11: Critical Fixes (15 min)

### 11.1 Accessibility - Remove userScalable: false

**Problem:** `src/app/layout.tsx` mein viewport meta tag `userScalable: false` aur `maximumScale: 1` set hai. Yeh WCAG 2.1 Level AA violation hai - visually impaired users can't zoom.

**Fix:**
```typescript
// Before (src/app/layout.tsx)
viewport: {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,        // ❌ Remove
  userScalable: false,    // ❌ Remove
}

// After
viewport: {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 3,        // ✅ Allow zoom up to 3x
}
```

**Impact:** WCAG 2.1 Level AA compliance, better accessibility for elderly/visually impaired users.

### 11.2 Security - Restrict Image Remote Patterns

**Problem:** `next.config.ts` mein `images.remotePatterns` allows `hostname: '**'` - any external image can be loaded. SSRF + malicious content risk.

**Fix:**
```typescript
// Before
images: {
  remotePatterns: [{ hostname: '**' }]  // ❌ Too permissive
}

// After
images: {
  remotePatterns: [
    { hostname: 'res.cloudinary.com' },
    { hostname: 'lh3.googleusercontent.com' },  // Google OAuth
    { hostname: 'avatars.githubusercontent.com' },
  ]
}
```

**Impact:** Prevents SSRF attacks, malicious content loading, reduces attack surface.

---

## Phase 12: Data Integrity + Code Quality (1 hour)

### 12.1 Order Transaction Wrapper

**Problem:** `src/app/api/orders/route.ts` mein order creation multiple Prisma calls karta hai (order create, items create, stock decrement, address update). Agar koi fail ho, orphaned data reh jaata hai.

**Fix:**
```typescript
// Before (5+ separate Prisma calls)
const order = await prisma.order.create(...)
const items = await prisma.orderItem.createMany(...)
await prisma.product.update(...)
await prisma.address.update(...)

// After (atomic transaction)
await prisma.$transaction(async (tx) => {
  const order = await tx.order.create(...)
  const items = await tx.orderItem.createMany(...)
  await tx.product.update(...)
  await tx.address.update(...)
})
```

**Impact:** No orphaned order items, atomic order placement, data consistency.

### 12.2 Extract Duplicate Utilities

**Duplicate 1: `getDistance()` in checkout**
- Location: `src/app/checkout/page.tsx`
- Already exists: `src/lib/distance.ts` (`getDistanceKm`)
- Action: Replace inline function with import

**Duplicate 2: `formatTime12h()` in checkout**
- Location: `src/app/checkout/page.tsx`
- Add to: `src/lib/date-helpers.ts`
- Action: Move to date-helpers, import in checkout

**Duplicate 3: `isNearClosing()` in checkout**
- Location: `src/app/checkout/page.tsx`
- Add to: `src/lib/date-helpers.ts` or `src/lib/restaurant-schedule.ts`
- Action: Move to shared utility

**Duplicate 4: `retryQuery()` pattern**
- Locations: `src/app/admin/page.tsx`, `src/app/order/[id]/page.tsx`
- Add to: `src/lib/utils.ts`
- Action: Extract to shared `withRetry()` function

**Impact:** ~50 lines of duplicate code removed, single source of truth.

---

## Phase 13: SEO + Schema Improvements (2 hours)

### 13.1 JSON-LD Structured Data

**Add to homepage (`src/app/page.tsx`):**
```typescript
// Organization schema
{
  "@context": "https://schema.org",
  "@type": "GroceryStore",
  "name": "FastKirana",
  "url": "https://www.fastkirana.in",
  "logo": "https://www.fastkirana.in/logo.png",
  "address": {
    "@type": "PostalAddress",
    "addressLocality": "Ghatampur",
    "addressRegion": "Kanpur"
  }
}
```

**Add to product pages (`src/app/product/[slug]/page.tsx`):**
```typescript
// Product schema
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": product.name,
  "image": product.imageUrl,
  "description": product.description,
  "offers": {
    "@type": "Offer",
    "price": product.price,
    "priceCurrency": "INR",
    "availability": product.stock > 0 ? "InStock" : "OutOfStock"
  }
}
```

**Impact:** Google rich results, better click-through rates, SEO boost.

### 13.2 Soft Delete Pattern

**Problem:** `prisma/schema.prisma` mein cascade deletes - user delete karne pe order history lost.

**Fix:**
```prisma
// Add to User model
model User {
  // ... existing fields
  deletedAt DateTime?  // ✅ Soft delete
}

// Prisma middleware
model Order {
  userId String
  user User @relation(fields: [userId], references: [id], onDelete: Restrict)  // ✅ Prevent cascade
}
```

**Impact:** Data preservation, GDPR compliance, audit trail.

### 13.3 Order.readableId Migration

**Problem:** `Order.readableId` is `Int?` - will overflow at 2 billion orders.

**Fix:**
```prisma
// Before
readableId Int? @unique

// After
readableId String? @unique  // ✅ No overflow
```

**Migration:**
```bash
npx prisma migrate dev --name change_readable_id_to_string
```

**Impact:** Future-proof, no overflow crash.

---

## Implementation Order

### **Immediate (Phase 11) - 15 min**
1. Fix viewport meta (5 min)
2. Restrict image domains (10 min)

### **Short-term (Phase 12) - 1 hour**
3. Wrap order creation in transaction (30 min)
4. Extract duplicate utilities (30 min)

### **Medium-term (Phase 13) - 2 hours**
5. Add JSON-LD structured data (45 min)
6. Add soft delete pattern (30 min)
7. Migrate Order.readableId to String (15 min + migration)

---

## Total Effort: ~3.5 hours

**Result:** App becomes:
- ✅ WCAG 2.1 Level AA compliant
- ✅ SSRF-protected
- ✅ Data-integrity safe
- ✅ SEO-optimized
- ✅ Future-proof schema

---

## Testing Checklist

After each phase:
- [ ] `npm run build` succeeds
- [ ] No TypeScript errors
- [ ] No console errors in browser
- [ ] Lighthouse score improves (target: 90+)
- [ ] Manual test: place order, checkout, search
- [ ] Mobile test: zoom works (accessibility)
- [ ] Image loading still works (security)
- [ ] Order rollback works (transaction)
