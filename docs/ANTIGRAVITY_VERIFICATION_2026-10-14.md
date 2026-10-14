# FastKirana verification — 14 October 2026

Reviewed the latest working tree against the 13 October handoff and blocker report. HEAD remains `103360d7`; the implementation is in uncommitted changes.

**Result: useful fixes verified, but the complete plan is still unfinished.** This is a source and local automated review, not approval of a deployed release. Application code, payment services and database schemas were not changed by this review.

## Checks and evidence

| Check | Result |
|---|---|
| Full Flutter suite, `flutter test --no-pub --reporter expanded` | Passed: 268 tests |
| Flutter analyzer, `flutter analyze --no-pub` | Passed: no issues, 357.2 seconds |
| Targeted Node auth, checkout and recovery tests | Passed: 34 tests |
| TypeScript, `tsc --noEmit --incremental false` | Passed |
| Selected backend security, new blockers, sockets and calculations | 51 passed, 1 failed |
| New `test_production_blockers_resolved.py` tests | All 7 passed within the selected backend run |
| Anonymous socket-ticket issuance | 401 on both `/ws/ticket` and `/api/ws/ticket` |
| Anonymous HTTP socket broadcast | Still 200 on both `/ws/broadcast` and `/api/ws/broadcast` |
| Actual FastAPI credential extraction/auth with fake DB | Socket-purpose ticket and missing-expiry token still accepted |
| Actual Next credential verifiers with fake signing key | General verifier rejects both; campaign verifier still accepts socket tickets |
| Actual legacy Next cookie role guard with DB lookup failure | Still accepted stale ADMIN session |
| Actual async idempotency helper with mocked Redis | Same attempt accepted again after Redis read failed |
| Signed Cashfree success webhook with actual configured model mappings and mocked cache/DB | Raised missing `Order.restaurant` AttributeError; trusted paid cache had already been written |

Backend failure: `fastapi-backend/tests/test_security.py:204` calls `engine.pool.size()` on SQLite's `StaticPool`, which has no such method. This is the known test-environment mismatch, not evidence of a deployed PostgreSQL pool failure. Fix the test to distinguish SQLite from PostgreSQL.

Backend tests used an isolated in-memory SQLite fixture, dummy authentication secrets and disabled external service configuration. Security probes used fake accounts/keys and isolated or mocked dependencies. Redis was mocked; no live Redis, payment gateway or deployed API was contacted. The Node checkout smoke tests and Flutter state/widget tests do not establish native payment/restart behavior. Backend execution used local Python 3.14.4; Docker/CI runtime builds were not performed.

## Verified improvements since 13 October

- `Request` is imported before the WebSocket ticket endpoint; the earlier annotation ordering defect is gone.
- `func` is imported in the Cashfree router; the earlier combined-total undefined name is gone.
- Anonymous ticket issuance is rejected; caller identity comes from authentication and customer order ownership is checked. Socket connections now require credentials.
- Ordinary FastAPI Bearer requests refresh database role/assignments and reject blocked accounts and database verification failures.
- Next cookie account checks now reject blocked/deleted accounts when the database lookup succeeds. The general Next JWT verifier requires expiry and rejects socket-purpose tickets.
- OTP/admin/delivery/vendor login paths no longer directly write new tokens into plaintext preferences. Legacy migration still verifies encrypted readback before removal.
- Pending payment callbacks now retain the busy flag, closing the earlier same-screen pending-to-COD path.
- Cart clear now replaces the queued snapshot with an empty list, fixing the exact old-items reflush previously identified. Normal queue acknowledgements restore pending status when a newer revision exists.
- Existing-order Cashfree verify/webhook amount checks now reject symmetric differences over INR 0.05. The earlier INR 1 and unrestricted overpayment comparison has improved within those paths.
- FastAPI order creation now awaits Redis idempotency helpers; healthy shared Redis rejects concurrent duplicate acquisition.
- Next and local Flutter order calculations now include a submitted tip once. End-to-end parity, validation and accounting remain incomplete below.

## Remaining work for Antigravity

### 1. [P1] Complete credential-purpose, expiry and failure handling

`fastapi-backend/routers/auth.py:47` and `:69` try to reject `scope/type == ws_ticket`, but `fastapi-backend/utils/jwt.py:128` strips those fields before the checks. A legitimate scoped socket ticket therefore becomes a broader REST credential for that account. FastAPI also still accepts signed tokens without expiry (`utils/jwt.py:99`, `:145`) and uses a repository-known fallback secret when configuration is missing (`:24`). These acceptance behaviors were reproduced with fake keys and a fake database.

The general Next JWT verifier is fixed, but `src/lib/auth-guard.ts:87` has a separate campaign verifier that still accepts socket tickets. The legacy cookie branch swallows database errors at `:216` and then authorizes stale session privileges at `:226`; `src/auth.ts:53` also retains stale token data after lookup failure. This fail-open cookie behavior was reproduced. Bearer assignments at `auth-guard.ts:165` still fall back to a revoked token assignment when the database value has become null.

**Implement:** Check full verified claims before projection, require expiry, reject inappropriate purpose/audience consistently, fail startup without required secrets, return authorization-unavailable on database failures, and treat current null assignments as authoritative. Apply this policy to every live guard rather than only the new strict helper.

**Acceptance:** Actual protected routes reject socket tickets, missing/expired expiry, blocked/deleted users, stale role/scope and database outages for cookie and Bearer clients; legitimate current permissions continue working.

### 2. [P1] Authorize realtime publication separately from subscription

`fastapi-backend/routers/websockets.py:325` exposes HTTP `/broadcast` without authentication and forwards caller-chosen channel/message. Both mounted aliases returned 200 anonymously. The order socket at `:396` also rebroadcasts customer-supplied status/GPS without checking publication rights. Customers may subscribe to their own order, but that must not authorize them to fabricate rider/order events.

**Implement:** Protect internal broadcast ingress, derive permitted channels and event types from verified current assignments, and enforce publisher roles. Restrict rider access to assigned orders. Finish ticket lifetime/reuse behavior; the current ticket has no single-use consumption mechanism.

**Acceptance:** Anonymous broadcasts rejected on both aliases; customers cannot publish status/GPS; unassigned riders/outlets cannot observe or publish other channels; legitimate assigned publishers work.

### 3. [P1] Fix tip validation and use one accepted financial quote

New `src/app/api/orders/route.ts:1062` clamps numeric tips but does not clamp its string fallback. A body containing `tipAmount: "-100"` produces a negative tip, reducing `miscFee` and the stored total at `:1074` and `:1077`. Reject invalid, negative and non-finite financial inputs after normalizing their supported representation.

Flutter charges and sends `tipAmount` (`checkout_controller.dart:557`, `:612`, `:956`), but FastAPI order totals still omit it (`fastapi-backend/routers/orders.py:1340`, `:1600`). The result depends on which backend handles the order. Putting the tip into `miscFee` at Flutter `checkout_controller.dart:892` and the Next route also makes receipt UI label packaging plus tip as “Packaging Charge” (`tracking_receipt_card.dart:184`, `order_detail_screen.dart:620`). No distinct stored tip/payout allocation was added.

Packaging remains inconsistent: cart uses INR 5; a configured NORMAL fee at or above INR 15 is inferred as PREMIUM by the backend; Flutter PREMIUM pickup adds INR 15 while backend pickup removes packaging. Paise formatting also still truncates amounts in parts of the flow.

**Implement:** Disable tips until supported throughout, or introduce explicit validated tip persistence, display and payout accounting in both backends. Compute and accept one server quote for items, fulfillment, discounts, packaging, tax, tip, amount and currency. Persist that accepted quote through payment/recovery; consume server-returned financial fields in the client success order instead of updating only IDs.

**Acceptance:** Negative number/string and non-finite tip tests; positive tip parity across both backends; separate receipt lines; configured NORMAL packaging; PREMIUM pickup; fractional prices; child totals, gateway charge and stored order totals agree exactly.

### 4. [P1] Apply payment binding before accepting or caching payment

FastAPI pre-order verification returns PAID before the new existing-order amount check (`cashfree_router.py:424`). FastAPI creation (`orders.py:1512`) and Next creation (`src/app/api/orders/route.ts:1198`) still accept paid cache/gateway status without comparing the accepted quote amount, currency and buyer.

The FastAPI webhook writes `cf_paid` at `cashfree_router.py:1039` before rejecting a mismatched amount at `:1093`. It also calls `selectinload(Order.restaurant)` at `:1048`, but the actual SQLAlchemy Order model has no `restaurant` relationship. A signed success-event probe, after configuring the real ORM mappings, raised `AttributeError` at this expression before reaching the fake database; the mocked trusted paid cache had already been written. Fix the model/query mismatch and cache ordering together. A failed webhook or rejected payment must not leave behind a cache entry that another order-creation path treats as valid payment. Missing/malformed gateway amounts must also fail validation rather than skip it.

**Implement:** Persist and resolve the explicit buyer/checkout/gateway binding, require exact normalized amount/currency, and validate before publishing trusted paid state. Route polling, creation, callback and webhook through the same invariant. Recover original accepted checkout data; do not reconstruct fulfillment from a changed live cart or placeholder merchandise.

**Acceptance:** A valid signed success webhook completes without relationship errors. Unrelated paid session, owner/currency/amount mismatch, malformed/missing amount, webhook rejection/failure followed by creation, combined orders and callback/webhook race all cause at most one valid fulfillment of the originally accepted checkout.

### 5. [P1] Turn pending payment storage into usable durable recovery

`payment_gateway_handler.dart:76` saves `active_pending_cf_order_id/amount`, but no Flutter code reads them. Restart initializes a fresh controller. The stored reference is removed at `:159` when verification is paid, before business-order placement is acknowledged.

“I will wait & check orders” dismisses the sheet but leaves `isPlacingOrder=true` (`checkout_controller.dart:248`, `payment_pending_reconciliation_sheet.dart:214`). The checkout overlay/back/button guards then leave no visible status checker or automatic reconciler. A recheck that changes pending to failed only shows a snackbar and retains the lock.

**Implement:** Persist an owner/hub-scoped accepted checkout and operation key before SDK launch, restore it on startup/foreground, keep the reference until a durable order/reconciliation acknowledgement, and provide reachable status/recovery actions. Resolve terminal failure explicitly; prevent duplicate payment/COD while the outcome is unknown.

**Acceptance:** Pending → Wait remains usable; pending → failed unlocks correctly; termination before/after SDK launch and paid verification recovers original items/address/amount; lost order response and duplicate callbacks still yield one logical order.

### 6. [P1] Make cart clear and acknowledgements follow one durable queue

`cart_provider.dart:386` sends deletion outside `_isSyncing`. Line 387 acknowledges the current revision unconditionally, including failure; line 389 can clear pending after newer items were added while DELETE was in flight. `cart_repository.dart:55` also clears pending on every successful response before the notifier checks its revision. Clear → add → delayed DELETE completion → restart can mark the newer unsent cart clean.

The persisted envelope still defaults to `version: 1, isDirty: false` (`cart_repository.dart:107`), restoration ignores these fields, dirtiness uses a global key (`:21`), and cache identity omits the hub (`:99`). Empty deletion removes the local envelope instead of retaining a recoverable tombstone.

**Implement:** Queue the empty snapshot with its captured revision; acknowledge only that revision after success. Persist owner, hub, revision, dirty state and empty deletion together, and restore the actual unsent state after restart/account/hub changes.

**Acceptance:** Delayed POST → clear; delayed clear → add; failed deletion; older success while newer request is offline; restart and account/hub switching preserve the latest intended basket.

### 7. [P1] Keep idempotency correct through shared-cache outages and retries

New `utils/idempotency.py:117` falls back to process memory on Redis error. A lock acquired in Redis has not populated that memory map. With a mocked Redis, one attempt was accepted, rejected as duplicate while Redis was healthy, then accepted again when the Redis read failed. Healthy Redis support is useful but is not durable correctness.

Flutter still generates a fresh mutation key per POST (`api_client.dart:110`). Retries of one logical payment/order therefore need not use the same key. Short-lived Redis entries and sequential CF-note lookups do not replace a shared atomic uniqueness boundary.

**Implement:** Persist buyer/operation/key/fingerprint/result with a database uniqueness guarantee; replay the committed result after worker restart or lost response. Redis can accelerate it. If shared correctness is unavailable, return a retryable unavailable response. Generate one logical attempt key in checkout and reuse it through retries/callbacks.

**Acceptance:** Independent workers, Redis outage, restart, response loss and simultaneous callback/webhook requests create one set of orders/items/inventory effects. Reusing a key with another payload returns conflict.

### 8. [P2] Finish shared draft, secure cache publication and UI acceptance

`checkoutDraftProvider` remains unused outside its own definition (`checkout_draft_provider.dart:104`). No persistence, owner/hub binding, payment freeze or reset is connected. Cart instructions are not passed into the default checkout `ring_bell` state. Wire the actual cart/login/checkout/back flow to the draft and test the selected receiver, address, packaging and instructions throughout.

`secure_storage_service.dart:236` still publishes token caches before encrypted write/readback succeeds. Move cache/auth publication after successful persistence and inject secure-write/readback failures in tests for all login readers.

Tracking initialization still calls marker generation from `initState` (`order_tracking_screen.dart:140`); its painters read inherited `MediaQuery` via `Responsive.scaledFontSize` (`map_marker_generator.dart:56`). Resolve those dependencies in the appropriate lifecycle. Existing tracking-widget tests do not cover first full-screen entry.

Whole-app text scaling remains capped at 1.5; quantity targets remain about 28×31; progress remains timer-driven. Complete the original 320/360/390-width, 2× text, TalkBack and reduced-motion acceptance matrix using the actual app/routes. Campaign widget tests alone do not close this gate.

### 9. [P2] Complete release evidence and coordinated money migration

Signing configuration and its referenced keystore exist, and debug signing fallback is removed. However `android/app/build.gradle:79` only fails for missing release signing in CI/`ENFORCE_SIGNING`; the field check also omits `keyPassword`. Verify all required values and fail every requested release without valid signing. Verify the certificate and a signed native artifact; configuration existence does not establish those results.

The financial decimal SQL is still a standalone staged file. Prisma (`schema.prisma:319`) and SQLAlchemy (`models.py:230`) still map monetary fields as Float, and the staging/gateway checklist remains uncompleted. Coordinate migration ownership/history, ORM mappings, exact arithmetic, serialization, locks and rollback before execution. No database migration was executed or approved by this review.

Finish native Cashfree lifecycle, release signature, PostgreSQL worker/concurrency and realistic migration rehearsal evidence. Keep security fixes independently reviewable, but do not mark the complete commerce/release plan finished from the passing existing suite.

## Implementation order

1. Credential-purpose/expiry/outage behavior and realtime publication authorization.
2. Negative tip validation, common quote and payment-binding/cache ordering.
3. Persisted checkout/payment recovery and durable logical idempotency.
4. Cart queue/revision/scoping and shared draft integration.
5. Secure-storage failure behavior, tracking/UI acceptance and native/signing/migration evidence.

Add behavioral regressions for the actual controllers, guards and routes above. Do not close a finding with only a source-string assertion or manually constructed state. Preserve the passing tests and verify each corrected failure path before marking its work packet complete.
