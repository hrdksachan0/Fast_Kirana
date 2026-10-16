# FastKirana independent recheck and Antigravity plan — 16 October 2026

This recheck supersedes the previous findings in this file. **The test suites are green, but six payment/cart findings remain.** Four are P1 because they affect charged amounts, paid-order recovery, or the purchased basket; two are P2 cart correctness defects.

Reviewed the latest saved, uncommitted checkout/cart changes and the FastAPI payment boundary. No application fixes, commits, deployments, real payments, or production database changes were made. Review probes used isolated test data and mocked/intercepted native SDK/network calls.

## Fresh verification

| Check | Result |
|---|---|
| FastAPI full suite, isolated SQLite, external HTTP blocked | **235 passed, 0 failed**, 266 warnings |
| Flutter full suite: `flutter test --no-pub --no-enable-impeller --reporter expanded` | **300 passed, 0 failed** |
| Next.js unit suite | **147 passed**, 21 suites, 0 failed |
| TypeScript: `tsc --noEmit --incremental false` | **Exit 0, no errors** |
| Dart analysis of checkout controller, payment handler, draft, cart provider/repository, success screen | **No issues**, exit 0 |
| Actual FastAPI quote/recovery diagnostic cases | **5 completed**: closure control and reproduced faulty states |
| Actual Flutter diagnostic cases | **6 completed**, plus **1 concurrent completion** and **1 second-save** case |
| Actual cart notifier/repository diagnostic cases | **3 completed** |

Diagnostic cases deliberately assert the observed bug when reproducing it. A passing diagnostic establishes the reproduction; it does not approve that behavior. The full Flutter run used explicit Skia and did not include the temporary review probes. This is targeted Dart analysis, not a newly run full `flutter analyze`.

The ten files recorded in the initial recheck snapshot retained identical SHA-256 hashes through verification. The Next.js payment creation observations below are source findings; the FastAPI attack/recovery cases were executed against actual handlers.

## Previous fixes now verified

- Flutter now sends coupon, hub, discount and fee metadata when creating payment. A legitimate ₹100 item with a ₹20 coupon now creates an ₹80 gateway amount and persists quote totals, zero fees and hub.
- Recovered drafts retain UPI, accepted hub, zero delivery/packaging fees and positive fee snapshots. The earlier zero-as-missing fallback is closed in the tested cases.
- Both thrown and false first draft writes abort SDK launch and remove pending IDs and cached/durable phantom drafts. A successful first-write control launches and retains the accepted draft.
- The former `CartItem` import-shadowing and nonexistent `ci.price` recovery errors are closed. The fallback now runs; its basket-selection policy is still unsafe, as finding 3 shows.
- The success-screen unconditional cart clear is removed, background retry passes ordered items, and unit/variant matching works in the reviewed case.
- Delayed server GET and the previously identified stale startup POST overwrite are guarded. Early local hydration still loses data, as finding 6 shows.
- The previously failing backend concurrency test passed in this fresh full run. See the separate concurrency validation gap below.

## 1. [P1] Derive fees and validate coupon eligibility on the server

**Where:** [cashfree_router.py:341](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:341), [coupon evaluator:370](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:370), [recovery threshold:1392](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1392).

Payment creation treats client delivery/packaging fees as authoritative. Recovery then trusts the saved quote. Actual handler reproduction:

```text
Catalog subtotal = 100
Client deliveryFee = -99, packagingFee = 0
Gateway amount = 1
Recovered order = CONFIRMED, subtotal = 100, deliveryFee = -99, total = 1
```

A second probe used a ₹20 category-restricted coupon on a product from a different category. The gateway still charged ₹80. The payment coupon evaluator omits restrictions enforced by normal order placement, including category and other scope/usage rules.

**Implement:**

1. Use one canonical quote policy for payment creation, ordinary placement and recovery. Derive delivery/packaging from validated hub, address, fulfillment and packaging choices.
2. Reject negative/nonfinite monetary inputs and inconsistent quote data. Nonnegative checks alone do not prevent a client from spoofing zero fees.
3. Apply the complete coupon eligibility policy, including product/category/restaurant scope and customer usage restrictions.
4. Persist server-validated quote data before exposing a usable payment session. Bind it to owner, hub and payment attempt.
5. Bring the Next.js path to the same contract. Its [pre-order amount branch:58](D:/Fastkirana/src/app/api/payment/cashfree/create-order/route.ts:58) still uses client `amount`, and [lines 113–140](D:/Fastkirana/src/app/api/payment/cashfree/create-order/route.ts:113) store a raw draft in Redis. This is a source-confirmed parity gap; this recheck does not claim a demonstrated Next.js fulfillment exploit.

**Acceptance:** Reject the ₹100/−₹99 fee attack, forged zero fees, nonfinite values and out-of-scope coupons. Verify valid flat/percentage/free-delivery coupons and packaging choices use identical totals across Flutter, both backends, gateway and recovered order.

## 2. [P1] Preserve accepted line prices after payment

**Where:** [cashfree_router.py:1274](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1274), [total reconstruction:1392](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1392).

Recovery re-reads current product/variant prices despite having an accepted payment intent:

```text
Accepted: subtotal = 100, coupon discount = 20, paid = 80
Catalog changes: product price = 120
Recovery: subtotal = 120, discount = 20, total = 80
Status = ADMIN_PENDING; reason = Underpaid: paid 80 < expected 100
```

A valid paid purchase is incorrectly treated as underpaid when the catalog changes.

**Implement:** Persist canonical server-validated line prices, variants, quantities, discounts, fees, currency and total with the accepted quote. Recover those accepted values. Recheck current stock separately. If a quote expires, require re-acceptance before payment rather than repricing after payment.

**Acceptance:** Change product price, variant price, coupon and fee configuration after payment-session creation. Recovery must preserve the accepted financial snapshot and check inventory independently.

## 3. [P1] Do not fulfill the current cart when the paid intent is missing

**Where:** [cashfree_router.py:1311](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1311).

The repaired fallback uses the buyer's current cart as the paid basket. Actual reproduction deliberately removed the accepted intent and replaced the cart:

```text
Paid basket: product A, amount = 100
No cached/durable intent remains
Current cart: unrelated product B, price = 100
Recovered order: CONFIRMED, product = B
```

Matching amount and buyer identity do not establish which goods were purchased.

**Implement:** Recover only from an authoritative attempt-bound accepted snapshot. If that snapshot is unavailable, record the paid event for explicit reconciliation and prevent automatic dispatch or cleanup of the current cart. Preserve newer cart items.

**Acceptance:** Remove/cache-expire the original intent, add an unrelated equal-price basket and replay the paid event. It must not confirm or dispatch B. Also cover empty cart, higher/lower prices and legacy attempts with a trustworthy archived snapshot.

## 4. [P1] Preserve a committed draft if a redundant post-launch save fails

**Where:** [checkout_controller.dart:728](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:728), [checkout_draft.dart:180](D:/Fastkirana/fastkirana_flutter/lib/data/models/checkout_draft.dart:180).

The controller saves the accepted draft in `onBeforeLaunch`, then saves it again after the SDK launch returns. The persistence helper deletes the draft key when a write fails. Actual helper/handler sequence:

```text
First accepted-draft write = committed
Mocked SDK doUPIPaymentWithUI = launched
Second-only accepted-draft write = false / throws
Cached draft = null; durable draft after reload = null
Pending payment ID still exists
```

The first-write abort fix works, but the second write can erase recovery data while a payment is already active.

**Implement:** Remove the redundant post-launch persistence, or make replacement failure preserve the previously committed accepted record. Keep first-time write failure cleanup distinct from replacing a valid record. Completion callbacks must not recreate a finalized draft.

**Acceptance:** Let the first draft write succeed and the SDK launch, then fail only the second write. Restart/reload storage and verify the exact accepted snapshot remains recoverable. Retain the existing first-write failure controls.

## 5. [P2] Acknowledge cart cleanup once per durable order

**Where:** [checkout_controller.dart:1291](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1291), [quantity subtraction:1312](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1312).

Selective subtraction is repeatable without a completion marker. Sequential and concurrent actual controller probes both reproduced:

```text
Accepted ordered quantity = 1
Current cart quantity = 3
Two completion calls receive the same durable business order
After first completion = 2
After second completion = 1
```

The extra subtraction removes a newer, unpurchased quantity even though the server returned one idempotent order.

**Implement:** Make completion and cart acknowledgement idempotent per owner/hub/payment attempt/durable order. Coordinate concurrent callbacks and persist an acknowledgement that survives restart. Apply only the original attempt's cart delta once.

**Acceptance:** Race SDK callback, status recovery and retry completion for the same durable order; repeat after restart. Cart quantity must finish at 2. A different real order must still perform its own cleanup.

## 6. [P2] Replay edits made during cart hydration against the saved base

**Where:** [cart_provider.dart:214](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:214), [pending key await:236](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:236), [add during loading:264](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:264).

The new local-load guard preserves a newer in-memory edit by returning, but the edit started from an empty cart and the previously saved basket is discarded:

```text
Saved cart = oldA; first local read is held
User adds newB before hydration finishes
Final server/UI/local = [newB], pending = false
Expected add semantics = [oldA, newB]
```

A second controlled async probe holds `getPendingSyncKeyForCurrentScope()` after the version guard, then adds B. The old snapshot subsequently replaces the newest queued revision:

```text
Server = [oldA]
UI/local = [oldA, newB]
pending = false, version = ack = 2
```

The second case uses a delayed-key test seam; it demonstrates an unguarded await boundary without estimating how often production scheduling exposes it.

**Implement:** Either gate mutations until hydration completes or record ordered mutation intents and replay them against the loaded base. Capture scope/generation and validate after asynchronous reads, including pending-key resolution. Only acknowledge the snapshot actually synchronized. Clear/tombstone intent must win over an older cache.

**Acceptance:** Delay each hydration boundary, then add/increment/remove/clear. Test pending true/false and owner/hub changes. Assert equal local/UI/server contents and correct pending revision. Keep the now-passing delayed-server-GET and delayed-startup-POST regressions.

## Concurrency validation still needed

The full backend suite is green this time. The former failure should not be reported as a current failing test or as a proven PostgreSQL defect.

However, [the fixture](D:/Fastkirana/fastapi-backend/tests/conftest.py:24) uses SQLite StaticPool, and the [four-worker test](D:/Fastkirana/fastapi-backend/tests/test_production_blockers_resolved.py:935) uses four threads in one process. A standalone same-pool diagnostic observed another session reading an uncommitted row and its rollback undoing the winner's write despite the winner's later successful commit. This explains why the fixture cannot establish production transaction isolation.

Add an isolated PostgreSQL test with independent connections/processes and Redis unavailable. Assert exactly one durable order, one completed idempotency record, one stock decrement and successful replay after cache loss. Also exercise rollback/commit failure before publication. Do not weaken the durability assertions.

## Antigravity execution order

1. Implement the shared server quote/accepted snapshot contract and full eligibility rules (findings 1–2).
2. Make missing-intent handling safe and remove destructive post-launch draft persistence (findings 3–4).
3. Make cart completion idempotent and hydration mutations lossless (findings 5–6).
4. Add behavior-based regression tests for every reproduction, run the full suites and independent PostgreSQL concurrency checks.
5. Verify signed native builds and real-device payment lifecycle in a test environment: callback/status overlap, app termination, restart, cancellation, network loss and storage failure. Record exact commands/results and the tested source revision before requesting final release approval.

## Retained evidence

All diagnostic sources and logs are under `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck8-backend-20261016.log`
- `fastkirana-recheck8-flutter-20261016.log`
- `fastkirana-recheck8-node-20261016.log`
- `fastkirana-recheck8-tsc-20261016.log`
- `fastkirana-recheck8-analyze-20261016.log`
- `fastkirana-recheck8-backend-probe-20261016.py`
- `fastkirana-recheck8-quote-recovery-final-20261016.log`
- `fastkirana-recheck8-flutter-probe-20261016.dart`
- `fastkirana-recheck8-flutter-probes-20261016.log`
- `fastkirana-recheck8-flutter-concurrent-probe-20261016.dart`
- `fastkirana-recheck8-flutter-concurrent-probe-final-20261016.log`
- `fastkirana-recheck8-flutter-second-save-probe-20261016.dart`
- `fastkirana-recheck8-flutter-second-save-probe-20261016.log`
- `fastkirana-recheck8-cart-probe-20261016.dart`
- `fastkirana-recheck8-cart-20261016.log`
- `fastkirana-recheck8-snapshot-20261016.json`

Temporary repository probes were removed after execution. This review does not verify deployed services, a signed native release, production credentials, or real gateway settlement. Knowledge-graph synchronization was not rerun.

