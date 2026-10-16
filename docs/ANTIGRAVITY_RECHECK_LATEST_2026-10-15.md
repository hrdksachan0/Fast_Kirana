# FastKirana verification and Antigravity handoff — 15 October 2026

This report supersedes the remaining-findings status in the 14 October reports. Review covered saved, uncommitted source. No application fixes, commits, deployments, real payments or production database changes were made. Probes used intercepted HTTP, mocked native channels, isolated SQLite or extracted current handler functions with mocked dependencies.

**Result: partially fixed.** WebSocket production fail-closed behavior and the pending/unavailable cancellation guard are corrected. Five concrete pricing, recovery and cart issues remain below. The latest backend full suite also has one unresolved concurrency-test failure.

## Verification results

| Check | Independently observed result |
|---|---|
| Latest full FastAPI suite, isolated SQLite and external HTTP blocked | **228 passed, 1 failed**, 246 warnings; 48.84 s |
| Failing backend case | `test_concurrent_workers_idempotency_with_redis_down`, line 1004: all four requests returned 409; no request created the order |
| Earlier isolated rerun of that case, before the later backend edits | **1 passed**; one 201 and three 409 responses |
| Next.js unit suite | **147 passed**, 21 suites, 0 failed |
| TypeScript, `tsc --noEmit --incremental false` | **Exit 0**, no errors |
| Flutter full suite with `--no-enable-impeller` | **268 passed, 0 failed** |
| Dart analysis of checkout controller, payment handler, cart provider/repository and checkout draft | **No issues found** |
| Actual notifier/repository startup-race probe | Reproduced stale server cart with pending=false |
| Previous delayed-clear race probe | Closed: newer POST waits for DELETE and wins |
| Actual payment-handler prelaunch persistence-failure probe | SDK launched despite missing durable accepted draft |
| Actual checkout-controller recovered-draft probe | Accepted online payment submitted as COD/current hub; accepted items were retained in the payload |
| Current Cashfree-create handler pricing probe | Accepted amount 80 and catalog subtotal 100 produced gateway amount 100 and persisted intent amount 100 |

The initial default-renderer Flutter run had 262 passes and six shader failures after concurrent test asset generation collided. Failures reported Vulkan shader data where SkSL was required. The subsequent serial run explicitly selected Skia and passed all 268 tests. No Flutter configuration or application source was changed to obtain that result. A default-renderer green result is not claimed here.

The backend changed after the earlier 225-test run, so the table uses the later 229-test run. The isolated pass does **not** erase either full-suite failure or establish PostgreSQL multi-worker correctness.

## Verified closures

- Latest WebSocket code recognizes APP_ENV, NODE_ENV, ENVIRONMENT and PRODUCTION, plus the application settings fallback. Production requires successful authoritative database consumption; database uniqueness conflicts reject replay. Existing production ledger tests passed in the latest full run.
- “Cancel & New Order” now verifies status first. Recognized pending/unavailable responses retain recovery state and the placement guard. Paid completion is attempted rather than blindly discarding tracking.
- The accepted-draft callback runs before SDK launch on the normal successful-storage path.
- Recovery now uses accepted items, address, coupon, instructions and several other saved fields. The old claim that it simply ignores all saved draft contents is obsolete.
- Normal clear and reconnect now enter the provider queue. The previous delayed-DELETE/newer-POST race is closed.
- Payment recovery uses explicit mappings rather than customer notes, and normal/recovered checkout use the matching consumed-payment namespace.

## Remaining implementation plan

### 1. [P1] Use the same validated quote for Cashfree creation and order fulfillment

**Source:** [cashfree_router.py:291](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:291), amount comparison in [orders.py:1674](D:/Fastkirana/fastapi-backend/routers/orders.py:1674).

The new anti-underpayment check replaces any amount below the raw catalog subtotal with that subtotal. It does not apply a validated coupon or the complete accepted quote.

**Trigger:** A catalog item costs ₹100 and a legitimate ₹20 coupon produces an accepted pickup total of ₹80. Payment creation raises that to ₹100. Normal order creation still calculates the discounted total and compares payment against ₹80, producing a payment/order mismatch.

A direct execution of the current create-payment handler body, mocking catalog results and intent persistence, observed:

```text
requested/accepted amount=80
catalog subtotal=100
gateway amount=100
persisted intent amount=100
```

The probe supplied the discounted-checkout scenario; it did not independently exercise coupon eligibility. The defect is that this handler never validates/applies that discount before flooring the amount.

**Antigravity work:**
1. Compute a server-validated checkout quote containing item/variant prices, coupon eligibility/discount, delivery, packaging, tip, currency and total.
2. Persist the accepted quote and bind the payment session and business-order attempt to it.
3. Use the identical quote for gateway creation, order placement and recovery. Reject inconsistent client input; do not silently turn a discounted accepted total into an undiscounted charge.
4. Keep both backends and Flutter on the same quote contract.

**Acceptance tests:** Valid flat and percentage coupons; invalid/expired coupon; pickup and delivery; mixed baskets; packaging/tip; changed catalog/settings after acceptance; forged underpayment. A valid ₹80 accepted quote must charge and reconcile ₹80 exactly once.

### 2. [P1] Recover payment method and store from the accepted transaction

**Source:** [checkout_controller.dart:1046](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1046), [line 1106](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1106).

Recovery now passes the draft, but the order model and API payload still use `state.selectedPayment`, whose fresh-controller default is COD. The store payload still uses the current hub rather than `draft.hubId`. Current settings/cart origin also still participate in the fee/serviceability calculation.

The actual controller probe supplied a paid online accepted draft and captured the intercepted POST:

```text
acceptedPayment=online submittedPayment=COD
acceptedHub=review_accepted_hub submittedHub=review_current_hub
submittedItems=[review_product]
```

The probe stopped the POST before acknowledgement and allowed all three intercepted background retries to drain. It does not claim a live server created the wrong order.

**Antigravity work:**
1. Resolve payment mode, owner, hub, address, receiver, item variants, fulfillment mode and quote from one accepted attempt.
2. Use that resolved transaction consistently in the local model, API payload, retry, status reconciliation and success display.
3. Do not fall back to the current mutable checkout when an accepted paid transaction exists. Reconcile through its server mapping when local data is unavailable.
4. Restore the accepted fee breakdown and origin, not just the grand-total number.

**Acceptance tests:** Restart into default COD state after paying online; changed current hub/address/cart; changed serviceability/pricing settings; callback and manual status action; a missing local draft with an existing backend intent. The submitted/reconciled order must retain the accepted payment mode and scope.

### 3. [P1] Abort SDK launch when the accepted draft cannot be saved durably

**Source:** [payment_gateway_handler.dart:82](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/payment_gateway_handler.dart:82), [checkout_draft.dart:165](D:/Fastkirana/fastkirana_flutter/lib/data/models/checkout_draft.dart:165).

The prelaunch callback is awaited, but its exception is caught and only logged. SDK launch continues. The draft saver also ignores a false return from `SharedPreferences.setString`.

An actual PaymentGatewayHandler/CheckoutDraft probe made the draft's platform write throw, intercepted create-order HTTP and mocked the Cashfree native channel. After reloading preferences:

```text
nativeMethods=[response, doUPIPaymentWithUI]
draftPersisted=false
sdkLaunchedDespitePersistenceFailure=true
```

**Antigravity work:**
1. Check the persistence return value and propagate write failures.
2. Require a durably stored accepted snapshot and payment binding before launching the external SDK.
3. Keep any already-created gateway intent recoverable if launch is withheld; expose a retryable local-storage failure.
4. Avoid validating durability only against an in-memory preferences cache.

**Acceptance tests:** Successful save; thrown write; false write result; simulated restart/reload after failure; interruption between session creation and launch. No native payment launch is allowed without its required durable accepted record.

### 4. [P1] Preserve later cart edits across every completion and recovery path

**Sources:**
- [order_success_screen.dart:181](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/order_success_screen.dart:181)
- [checkout_controller.dart:1357](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1357)
- [cart_provider.dart:414](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:414)
- [cashfree_router.py:1330](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1330)

Selective removal in the immediate controller acknowledgement is insufficient:

- The success screen unconditionally calls `clearCart()` in its first-frame callback, deleting the items the controller preserved.
- Background retry omits `orderedItems` when calling completion, selecting the full-cart-clear fallback.
- Checkout serializes an absent variant as `product.unit`, while the cart retains a null variant. Cleanup requires equality with the serialized variant, so ordinary unit-bearing groceries may fail to match.
- Backend payment recovery deletes all rows from the buyer's cart without an accepted-item, quantity, scope or revision condition.

**Antigravity work:**
1. Make completion cleanup belong to one acknowledged accepted attempt.
2. Carry accepted item identities/quantities through initial POST, callback, retry and recovery; remove redundant whole-cart clears.
3. Use one canonical product/variant identity in the cart, draft, order payload and subtraction.
4. Make backend recovery preserve newer rows/quantities and the corresponding hub/owner scope too.
5. Ensure repeated acknowledgements/replayed callbacks do not subtract the purchased quantity again.

**Acceptance tests:** Purchase A, add B while payment/POST is pending, then complete via initial acknowledgement, background retry, manual reconciliation and webhook recovery. B must survive local and server cleanup and success navigation. Include repeated acknowledgement, no explicit variant with a nonempty unit, multiple explicit variants and newer quantities of the same product.

### 5. [P2] Route startup cart reconciliation through the same queue

**Source:** [cart_provider.dart:228](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:228).

Startup still calls `repository.syncCart(localItems)` directly. It bypasses the provider's version queue and uses the repository's default success acknowledgement.

The actual notifier/repository probe observed:

```text
start POST old-A
DELETE completes
POST new-B completes
POST old-A completes
server=[old-A], local/UI=[new-B], pending=false
cartVersion=2, lastAcknowledgedVersion=2
```

The old startup response overwrites the newer cart and clears its retry signal.

**Antigravity work:**
1. Admit startup reconciliation as a captured owner/hub/revision operation in the same writer as clear, edit and reconnect.
2. Acknowledge only the submitted revision; do not let repository-level unversioned success clear a newer dirty state.
3. Persist and restore the revision, dirty flag and empty tombstone before network submission.

**Acceptance tests:** Reproduce the exact delayed-startup sequence above; repeat with restart, scope change and an empty dirty tombstone. Keep the already-passing delayed-clear regression.

## Resolve the backend concurrency verification gap

The latest full suite still fails `test_concurrent_workers_idempotency_with_redis_down`. Earlier isolated execution passed, whereas both observed full runs returned four conflicts with no successful order. This cannot be labelled a fully green backend.

The fixture uses concurrent TestClient requests and async sessions backed by one SQLite StaticPool connection. Shared transaction/rollback behavior is a plausible fixture cause; the current evidence does not establish it as the sole cause or demonstrate a production PostgreSQL defect.

**Antigravity work:** Capture conflict reasons and transaction ownership, isolate the concurrency fixture correctly, check for leaked process state/background tasks, and verify liveness and uniqueness with independent sessions/workers against an isolated PostgreSQL test database. Require one durable accepted order and safe duplicate responses, including response-loss/retry. Do not replace this test with assertions that all conflicts are acceptable or remove it to obtain a green count.

## Evidence and scope limits

Logs/probes retained in `C:/Users/Sooraj/AppData/Local/Temp`:
- `fastkirana-recheck6-backend-latest-20261015.log`
- `fastkirana-recheck6-backend-concurrency-isolated-20261015.log`
- `fastkirana-recheck6-node-20261015.log`
- `fastkirana-recheck6-tsc-20261015.log`
- `fastkirana-recheck6-analyze-20261015.log`
- `fastkirana-recheck6-flutter-20261015.log`
- `fastkirana-recheck6-flutter-skia-20261015.log`
- `fastkirana-cart-startup-probe-20261015.dart` and matching `.log`
- `fastkirana_payment_prelaunch_review_test.dart`
- `fastkirana-recheck6-draft-probe-20261015.dart`
- `fastkirana-recheck6-draft-20261015-retry.log`

Temporary repository probe files were removed. No real gateway, deployed backend, database migration, signed native release, physical-device lifecycle, or complete accessibility release acceptance was verified. This is a review and handoff plan, not a production-release approval.

