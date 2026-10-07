# FastKirana App Review

Date: 2026-10-07. Scope: Next.js web storefront and API handlers, Flutter customer and staff app, active FastAPI backend, deployment configuration, and legacy Python backend.

Method: three independent source assessments (Flutter/UX, web/detector, backend), followed by parent verification of the principal findings and automated checks. Public deployed pages were inspected with headless Playwright at mobile and desktop sizes. No production authentication, order placement, payment, or administrative mutations were performed.

## Rating

Overall: **5/10**. Feature coverage is strong, but authentication and payment trust defects prevent a higher production-readiness score. These scores are engineering judgments, not benchmark results.

| Area | Score | Assessment |
| --- | --- | --- |
| Feature coverage | 8/10 | Grocery, restaurants, checkout, tracking, picker, rider, kitchen, inventory, and administration are substantially represented. |
| UI and customer UX | 6.5/10 | Recognizable branding and navigation; oversized promotions, small secondary text, and inaccessible custom controls weaken usability. Mobile native rendering was not inspected. |
| Architecture and maintainability | 6/10 | Useful service separation, but overlapping Next/Python implementations and legacy code create inconsistent enforcement. |
| Operational reliability | 4/10 | Offline queue loss, false sync success, account cache leakage, and hub-switch races are significant. |
| Security and payment integrity | 2/10 | Universal OTP bypass and client-controlled paid status are release blockers. |

## Release Blockers and High-Priority Findings

### 1. P0: Universal OTP bypass in Next.js

Evidence: `src/app/api/auth/otp/verify/route.ts:125` and `src/auth.ts:343`.

Both handlers accept a fixed master OTP without requiring an issued, unexpired OTP record. The bypass is not restricted to a test identity or development environment. Supplying an existing account identifier can authenticate that account, including staff/admin accounts. Blocked-account checks and rate limits do not remove the bypass. The FastAPI security tests cover its own auth implementation, not these Next handlers.

Fix: remove the bypass from both handlers; require a valid one-time token in every production sign-in path. Add behavioral regression tests across both auth stacks. If this code has been deployed, investigate misuse and revoke potentially affected sessions after closing the bypass.

### 2. P1: Client-supplied payment status is trusted

Evidence: `fastapi-backend/routers/orders.py:1440`.

For a non-COD order, `paymentStatus: PAID` or any nonempty payment ID makes the order paid without gateway verification. A customer can submit an otherwise valid checkout payload without completing payment and enter the paid/confirmed flow.

Fix: ignore client claims of settlement. Derive paid status from a server-verified payment bound to the customer, immutable checkout amount, currency, and order. Model legitimate zero-total promotional orders explicitly.

### 3. P1: Verification can apply an unrelated successful payment

Evidence: `fastapi-backend/routers/cashfree_router.py:256`, `:313`, and `:410`.

The verify endpoint has no authentication dependency. It accepts a local order identifier and a separate supplied Cashfree order ID, checks the supplied gateway ID first, and can mark the local order and companion orders paid. It does not bind the successful payment to the local order's customer, amount, currency, or stored payment reference. Signed webhooks do not protect this separate path.

Fix: bind gateway references at initiation; verify ownership, amount, currency, and reference before settlement; prevent payment reuse. Keep any public polling response free of privileged settlement behavior.

### 4. P1: Negative quantities lower totals and increase stock

Evidence: `fastapi-backend/routers/orders.py:607`, `:913`, and `:1655`.

Quantity normalization accepts negative integers. Stock validation checks only availability and upper limits. A positive line combined with a negative line can remain above the order minimum while reducing charges. Deducting a negative quantity increases global and hub inventory. The endpoint does not use the positive-quantity schema available elsewhere.

Fix: validate the complete checkout payload before calculation or database mutation; require bounded positive integer quantities for every item.

### 5. P1: Branch admins can escape hub isolation

Evidence: `fastapi-backend/routers/admin.py:1224`, `:764`, and `fastapi-backend/routers/orders.py:2678`.

The user-update endpoint lets any admin clear their own store assignment. After refreshing credentials, conditional store guards no longer constrain that account. Separately, the admin order listing accepts another store ID or no store filter without enforcing the caller's assignment.

Fix: reserve role/store-assignment changes for authorized root admins and enforce the authenticated hub in every branch-admin query. Authorization must not depend on client-selected filters.

### 6. P1: Restaurant staff can mutate other outlets' orders

Evidence: `fastapi-backend/routers/restaurant.py:605`.

Dashboard authorization prefers the request body's restaurant ID over the authenticated staff assignment. A chef/owner can name another restaurant and reject, accept, or pack its eligible order when its ID is known.

Fix: derive the outlet from the authenticated account for non-root staff and compare the target order against that assignment.

### 7. P1: Personalized purchase history is eligible for public caching

Evidence: `next.config.ts:479` and `fastapi-backend/routers/products.py:785`, `:871`.

Blanket public CDN headers for `/api/products/:path*` also cover `/api/products/buy-again`. That endpoint returns the current user's purchased products and order recency without overriding the response to private/no-store. On a deployment honoring the configured shared-cache directives, identical URLs can return one customer's history to another customer. Actual CDN reuse was not tested.

The service worker also classifies all `/api/products` GET routes as catalog data (`public/sw.js:159`), so personalized catalog routes need explicit exclusions there too.

Fix: exclude personalized paths from CDN and service-worker caching; return private/no-store headers for user-dependent responses.

### 8. P1: Rider cache and queued work survive logout

Evidence: `fastkirana_flutter/lib/providers/auth_provider.dart:137` and `lib/features/delivery/delivery_dashboard.dart:164`.

Logout omits `cached_delivery_orders_json` and `offline_delivery_queue`. A later account loads the same persisted order cache and may flush old queued actions using the new session. Backend authorization may reject those actions, but local information exposure and mixed-account work already occur.

Fix: scope cached orders and queues by authenticated user, clear private views on logout, and quarantine pending work belonging to a previous account.

### 9. P1: Credentials are duplicated in plaintext preferences

Evidence: `fastkirana_flutter/lib/core/services/secure_storage_service.dart:196`.

The write method persistently stores auth and refresh tokens in SharedPreferences before writing encrypted storage. Reads intentionally retain that backup. Encrypted storage therefore does not protect the credential copies in preferences.

Fix: keep credential material exclusively in secure storage, migrate and delete old copies, and handle secure-storage failure as an explicit session recovery condition.

### 10. P1: Rejected rider actions are reported as synced

Evidence: `fastkirana_flutter/lib/features/delivery/delivery_dashboard.dart:240`, `:267`.

All HTTP 4xx responses, including 401 and 429, count as success. The queue deletes those actions and the UI reports successful synchronization. Authentication expiry or rate limiting can therefore discard delivery updates.

Fix: distinguish acknowledged, permanently rejected, and retryable actions. Refresh authentication where appropriate, preserve retryable work, and show accurate outcomes.

### 11. P1: Queue flushing can erase new work

Evidence: `fastkirana_flutter/lib/core/services/offline_sync_service.dart:63`, `:98`.

Flush reads a snapshot, awaits network execution, then replaces or removes the entire queue. An action enqueued during that await is absent from the snapshot and can be overwritten or removed. This shared service affects multiple operational consoles.

Fix: serialize queue mutations or acknowledge/remove individual stable action IDs while preserving later additions. Test enqueue-during-flush and overlapping flushes.

### 12. P1: Store switching can leave an endless spinner

Evidence: `src/components/home/storefront-client.tsx:149`, `:188`.

Switching from a non-default hub back to the default hub cancels the old effect. Its completion then skips clearing loading, and the default branch does not reset loading. The UI can remain stuck checking inventory. Failed hub fetches are also recorded as fetched before success.

Fix: reset loading for every transition, abort stale requests, and record successful rather than attempted fetches.

### 13. P1: Reopening a hub refreshes with an unscoped catalog

Evidence: `src/components/home/storefront-client.tsx:128`.

The closed-to-open refresh omits the active store ID and has no stale-response guard. It can replace a selected hub's products with the backend default catalog or overwrite a later selection.

Fix: include the active hub and reject responses belonging to an earlier selection.

### 14. P1: Zero-total online checkout uses a positive fallback amount

Evidence: `src/hooks/checkout/use-checkout-payment.ts:317`.

A valid supplied grand total of zero enters the subtotal-plus-packaging fallback. The free-order branch is then skipped and a positive payment session is requested despite the discounted checkout total.

Fix: distinguish an omitted total from zero. Obtain the final payable amount from a server-authoritative checkout calculation.

## Other Confirmed Issues

- P2: Clearing receiver fields keeps the old recipient. The editor emits null, while state copyWith treats null as retain-existing. Evidence: `fastkirana_flutter/lib/features/checkout/widgets/checkout_receiver_card.dart:196` and `lib/features/checkout/controllers/checkout_controller.dart:94`, `:181`.
- P2: The custom cart drawer has no modal semantics, focus trap/restoration, background inertness, or Escape handling. Evidence: `src/components/cart/cart-drawer.tsx:663`.
- P2: Cart quantity icon buttons lack accessible names and use 32-pixel hit areas. Evidence: `src/app/cart/page.tsx:572`, `:579`.
- P2: Several E2E tests conditionally skip search, add-to-cart, coupon, and scanner interactions. They can pass without exercising the named behavior. Evidence: `e2e/search-and-cart.spec.ts:22`, `:55`, `:68`; `e2e/checkout-flow.spec.ts:52`; `e2e/picker-flow.spec.ts:19`.
- P2: The Flutter app smoke test mounts a synthetic text-only MaterialApp rather than the application. Evidence: `fastkirana_flutter/test/widget_test.dart:7`.

## UX and Visual Review

The deployed site's red branding, labeled bottom navigation, straightforward empty-cart action, and WhatsApp login are recognizable. Source shows sensible checkout grouping, persistent payment actions, dedicated staff consoles, cart conflict handling, availability states, and payment recovery flows.

The mobile home gives substantial first-screen space to large promotional images containing miniature app screenshots and text. That content is difficult to read and pushes actual categories/products down. Reduce the promotional height, prioritize shoppable categories, and retain a clear product entry point in the first viewport. Login secondary copy and staff login links also deserve stronger contrast and readability. Apply keyboard support to custom drawers before cosmetic refinement.

No horizontal overflow was detected on the inspected public home, cart, and login pages at 390 pixels. The settled public home produced no pageerror events in the bounded check. Initial captures showed incomplete content before hydration settled; these are not a measured production-performance result. Local startup and machine filesystem delays prevented a reliable local visual assessment.

Provisional source-based heuristic score: 23/40. System status 2, real-world match 3, user control 2, consistency 3, error prevention 2, recognition 3, efficiency 3, minimalist design 2, error recovery 1, help 2 (each out of 4). This is not a fully tested native usability score.

The web detector reported 31 heuristic matches in 15 files: 30 warnings and 1 advisory. Breakdown: bounce easing 13, palette 7, gradient text 4, gray-on-color 3, layout transition 2, rounded border accent 1, grid background 1. These are design signals, not 31 verified bugs. Loading-spinner borders, hover/dark color combinations, and radial dot texture produced false positives; duplicate variant matches inflate counts. The indigo payment overlay is inconsistent with the documented brand palette.

## Verification and Limits

- Web unit tests: 69 passed, 0 failed.
- TypeScript: `npx tsc --noEmit` passed.
- Selected active backend suites: security, order calculations, probes; 46 passed, 0 failed, using test fixtures.
- Full Flutter tests: 172 passed. Firebase-not-initialized logs and mocked network-error logs occurred without failing the suite.
- Flutter static analysis was started but produced no findings beyond its startup message and was cancelled after the extended wait. No clean-analysis claim is made.
- Web ESLint was started over src, but did not produce its JSON report during the extended wait and was cancelled. No clean-lint claim is made.
- Local Next dev server started, but the requested pages repeatedly exceeded 60-second navigation timeouts during slow compilation. It was stopped.
- Native browser tooling failed with a Windows helper error; headless Playwright provided public-page screenshots instead. No detector overlay was injected.
- Public deployed UI may differ from the current dirty working tree. Screenshots are `audit-live-*.png` in the project root.
- No real payments, OTP messages, orders, admin changes, or exploit requests were executed. Backend findings are confirmed code paths, not demonstrations against production.
- No full production build, authenticated role-by-role browser journey, native device run, load test, or physical printer verification was completed.

Legacy risk: `fastkirana_fastapi/app/core/security.py` defaults to an admin identity without authentication. Railway configuration builds `fastapi-backend/Dockerfile`, so this is a dormant risk if the legacy service is exposed, not an established vulnerability in the configured active deployment. Remove or clearly isolate the unused service.

## Recommended Order

1. Close the OTP bypass and payment-trust paths.
2. Validate checkout quantities and enforce hub/outlet authorization consistently.
3. Exclude personalized responses from public caching.
4. Repair offline queue correctness, logout isolation, and credential storage.
5. Fix store-refresh races and zero-total checkout.
6. Replace conditional E2E smoke checks with mandatory behavioral assertions for these exact failures.
7. Improve mobile shopping hierarchy, drawer accessibility, and control labels.

The app has useful product depth. The next investment should be correctness and authorization across its existing workflows before adding more features.
