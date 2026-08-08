# Fastkirana Improvement Plan

**Created:** 2026-08-08
**Owner:** Developer
**Context:** Address low-scoring areas from self-assessment: Code Architecture (5/10), Security (6/10), Error Handling (5/10), Test Coverage (2/10), Developer Experience (6/10)
**Prerequisite:** Phase 1 (monster file extraction) is already 60% complete via existing refactoring work.

---

## Overall Strategy

Low scores fall into three buckets:
- **Structural debt** — monster files, weak types, duplication → addressed by continuing component extraction + adding proper types
- **Missing infrastructure** — auth guards, error handling, tests → addressed by targeted additions
- **Operational readiness** — performance, scalability → addressed by config and architecture upgrades

Phases are ordered by dependency and impact. Complete each phase before moving to the next.

---

## Phase 1: Complete the Admin Dashboard Refactor

**Timeline:** 2–3 days
**Goal:** Get `admin-dashboard.tsx` from ~5522 lines down to ~800–1000 lines as a clean orchestrator
**Impact:** Code Architecture +5, Developer Experience +3

### 1.1 Extract products-tab.tsx (~1000 lines)
- Product list with filtering, search, pagination
- Product create/edit form
- Template system
- Tags, variants, pricing
- Inventory management
- Product edit modal

### 1.2 Extract live-ops tab (~330 lines)
- SLA tracking
- Average delivery times
- Delayed orders list with FIFO queue
- Live carts panel (already extracted, just needs wiring)

### 1.3 Extract remaining simple tabs (~150 lines each)
- settings-tab.tsx
- inward-tab.tsx
- bulk-update-tab.tsx
- reports-tab.tsx
- restaurant-report-tab.tsx
- banners-tab.tsx
- push-notifications-tab.tsx
- flash-deals-tab.tsx
- rider-cash-tab.tsx
- csv-import-tab.tsx
- restaurant-console-tab.tsx

### 1.4 Clean up the orchestrator
- Remove all inline tab JSX, replace with component calls
- Add TypeScript interfaces for all prop objects
- Remove unused imports
- Target: ~800–1000 lines, all state declarations + tab routing + API calls

### Acceptance Criteria
- `admin-dashboard.tsx` < 1000 lines
- Every tab has its own file with typed props interface
- No `any` types remain in extracted components
- App builds and runs without visual regression

---

## Phase 2: TypeScript Cleanup & Shared Types

**Timeline:** 1–2 days
**Goal:** Eliminate `any` types, create shared type definitions
**Impact:** Code Architecture +2, Developer Experience +2

### 2.1 Audit remaining `any` types
- Grep for `: any` across `src/`
- Prioritize admin components, API route handlers, and shared utilities

### 2.2 Create shared type files
```
src/types/
├── index.ts              # Barrel export
├── product.ts            # Product, Variant, Template, Tag
├── order.ts              # Order, OrderItem, DeliveryAssignment
├── user.ts               # User, Role enum
├── category.ts           # Category tree types
├── coupon.ts             # Coupon, CouponValidation
├── common.ts             # ApiResponse, PaginatedResponse, ErrorResponse
```

### 2.3 Replace `any` with proper types in:
- All admin tab components
- All API route handlers (`src/app/api/**`)
- Utility functions in `src/lib/`

### Acceptance Criteria
- Zero `any` types in `src/components/admin/`
- Zero `any` types in API route handlers
- All shared types exported from `src/types/index.ts`

---

## Phase 3: Security Hardening

**Timeline:** 2–3 days
**Goal:** Close auth bypass risks, add proper guards, secure all admin routes
**Impact:** Security +4 (from 6/10 to ~10/10)

### 3.1 Audit admin API routes
- Read all files in `src/app/api/admin/`
- Identify routes missing auth checks, role checks, or both
- Document each gap

### 3.2 Create reusable auth middleware
```
src/middleware/
├── withAuth.ts           # Verifies session, returns user or 401
├── withRole.ts           # Checks user role, returns 403 if unauthorized
├── withAdmin.ts          # Combines both for admin-only routes
```

### 3.3 Apply auth guards to all admin routes
- Systematic pass: every route in `src/app/api/admin/**` gets wrapped
- Verify: admin routes reject non-admin users
- Verify: user routes reject users accessing other users' data

### 3.4 Eliminate dev bypass mechanisms
- Search for `process.env.NODE_ENV`, `__DEV__`, hardcoded credentials, bypass flags
- Remove or gate behind feature flags with environment variable control
- Ensure no path allows admin access without auth in production build

### 3.5 Add rate limiting
- Install `@upstash/ratelimit` or similar lightweight solution
- Apply to: login, OTP, password reset, file upload endpoints
- Document limits per endpoint

### 3.6 Input validation
- Add Zod schemas for all API route inputs
- Validate before processing, return clear error messages
- Especially critical for: product creation, order status changes, user role changes

### Acceptance Criteria
- Every admin API route has auth + role check
- No dev bypass code remains
- Rate limiting active on sensitive endpoints
- All inputs validated with Zod
- Manual penetration test passes

---

## Phase 4: Error Handling & Resilience

**Timeline:** 2–3 days
**Goal:** Consistent error handling, user-friendly error states, no silent failures
**Impact:** Error Handling +4 (from 5/10 to ~9/10)

### 4.1 Create shared error handling utilities
```
src/lib/errors/
├── api-error.ts          # ApiError class with status codes
├── error-handler.ts      # Global error handler for API routes
└── error-messages.ts     # User-friendly error message mapping
```

### 4.2 Add error boundary component
```
src/components/error-boundary.tsx
```
- Wrap admin dashboard
- Wrap checkout flow
- Wrap customer-facing pages
- Show graceful fallback with retry option

### 4.3 Standardize API error responses
- All API routes return `{ error: string, code?: string, details?: any }`
- Consistent HTTP status codes
- No unhandled promise rejections

### 4.4 Add toast/notification system for failures
- Already have `sonner` — standardize usage
- Every API call has error toast
- Retry mechanism for transient failures

### 4.5 Add loading and empty states
- Every data-fetching component has: loading, error, empty, success states
- Skeleton loaders for admin dashboard

### Acceptance Criteria
- Every API call has try/catch with user feedback
- Error boundaries catch React crashes
- No unhandled promise rejections in console
- Consistent error response format across all routes

---

## Phase 5: Test Coverage

**Timeline:** 3–5 days
**Goal:** Meaningful tests for critical paths, establish testing conventions
**Impact:** Test Coverage +5 (from 2/10 to ~7/10)

### 5.1 Set up testing infrastructure
- Install: `vitest`, `@testing-library/react`, `@testing-library/jest-dom`
- Configure vitest config with path aliases
- Add test scripts to package.json

### 5.2 Write tests for critical business logic
Priority order:
1. Coupon validation logic (discount calculations, expiry, usage limits)
2. Cart/checkout calculations (totals, discounts, delivery fees)
3. Order status transitions (valid state changes)
4. Product availability checks
5. User role/permission checks

```
src/__tests__/
├── lib/
│   ├── coupon-validation.test.ts
│   ├── cart-calculations.test.ts
│   └── order-transitions.test.ts
```

### 5.3 Write tests for API routes
- Test happy path, validation errors, auth failures
- Use supertest or similar for route testing

### 5.4 Write tests for critical UI components
- Coupon creation form validation
- Order placement flow
- Product search/filter

### 5.5 Set up CI test runner
- Add test step to deployment pipeline
- Gate deploys on test pass

### Acceptance Criteria
- 50+ meaningful tests passing
- Critical business logic fully covered
- Every API route has at least smoke tests
- Tests run in CI

---

## Phase 6: Performance & Scalability

**Timeline:** 3–4 days
**Goal:** Faster response times, reduced CSS bloat, prepared for scale
**Impact:** Performance +2 (7→9), Scalability +3 (5→8)

### 6.1 CSS/Tailwind audit and cleanup
- Audit global CSS file for unused rules
- Remove duplicate Tailwind classes
- Use `@apply` strategically for repeated patterns
- Consider purging unused Tailwind utilities
- Target: reduce CSS bundle by 30–40%

### 6.2 Add Redis caching layer
- Install Redis (Upstash or self-hosted)
- Cache: product listings, category trees, user sessions, rate limit counters
- Invalidate on data changes
- Expected: 50–70% reduction in database queries for read-heavy pages

### 6.3 Database query optimization
- Review Prisma queries for N+1 problems
- Add indexes for frequently queried fields
- Use `select` to fetch only needed fields
- Consider connection pooling for production

### 6.4 Image optimization
- Add Next.js Image component with proper sizing
- Lazy load below-fold images
- Use responsive images with `srcset`
- Compress and serve WebP/AVIF

### 6.5 Bundle size optimization
- Analyze bundle with `@next/bundle-analyzer`
- Lazy load heavy components (charts, maps)
- Split admin and customer bundles
- Remove unused dependencies

### Acceptance Criteria
- CSS bundle reduced by 30%+
- Redis caching active for top 5 read endpoints
- No N+1 queries in critical paths
- Lighthouse performance score > 85
- Bundle size analyzed and optimized

---

## Phase 7: Developer Experience Improvements

**Timeline:** 1–2 days
**Goal:** Better tooling, conventions, and documentation
**Impact:** Developer Experience +3 (6→9)

### 7.1 Standardize code formatting
- Ensure Prettier config is consistent
- Add pre-commit hooks (husky + lint-staged)
- Enforce import sorting

### 7.2 Add development tooling
- Install `@tanstack/react-query` for better data fetching (optional but recommended)
- Add React DevTools support
- Add environment variable validation (zod for env vars)

### 7.3 Documentation
- README with setup instructions, architecture overview, deployment guide
- API route documentation
- Component library docs (if building shared components)
- Contributing guide

### 7.4 Scripts and automation
- `npm run typecheck` — TypeScript check
- `npm run test` — Run tests
- `npm run lint:fix` — Auto-fix lint issues
- `npm run db:seed` — Seed database with test data
- `npm run db:reset` — Fresh database for development

### 7.5 Consistent error messages
- All user-facing errors have helpful messages
- Error codes for support lookup
- Logging format standardized

### Acceptance Criteria
- Pre-commit hooks active
- README complete and accurate
- Development setup takes < 15 minutes for new developer
- Consistent error handling across all user-facing areas

---

## Score Projection After All Phases

| Area | Before | After | Change |
|------|--------|-------|--------|
| Feature completeness | 9/10 | 9/10 | — |
| UI/UX design | 8/10 | 8/10 | — |
| Code architecture | 5/10 | 8/10 | +3 |
| Performance | 7/10 | 9/10 | +2 |
| Security | 6/10 | 9/10 | +3 |
| Error handling | 5/10 | 9/10 | +4 |
| Test coverage | 2/10 | 7/10 | +5 |
| Scalability | 5/10 | 8/10 | +3 |
| Developer experience | 6/10 | 9/10 | +3 |

**Estimated total effort:** 15–22 working days
**Highest ROI phases:** Phase 1 (already started), Phase 3 (security), Phase 5 (tests)

---

## Quick Reference: What to Tackle First

If you have 1 hour right now:
1. Extract one simple tab from admin-dashboard.tsx (e.g., reports or banners)

If you have 1 day:
1. Complete Phase 1 — finish products-tab.tsx extraction, that's the biggest single win

If you have 1 week:
1. Complete Phase 1 fully
2. Start Phase 3 (security audit + middleware)

If you have 2+ weeks:
1. Complete Phases 1–3 (structure + security)
2. Start Phase 4 (error handling)

---

## File Locations Reference

| File | Purpose |
|------|---------|
| `brain.md` | Project context, current state, decisions |
| `src/components/admin/admin-dashboard.tsx` | Main dashboard orchestrator |
| `src/components/admin/*-tab.tsx` | Extracted tab components |
| `src/types/` | Shared TypeScript types (to be created) |
| `src/lib/errors/` | Error handling utilities (to be created) |
| `src/middleware/` | Auth middleware (to be created) |
| `src/__tests__/` | Test files (to be created) |
