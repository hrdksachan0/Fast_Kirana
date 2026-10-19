# Payment/cart recheck — 19 October 2026, revision 2

Reviewed saved working tree at HEAD `66b1f4a9`, including uncommitted changes. The previously failing connectivity regression is resolved. Two cart fixes arrived during verification and passed focused reruns. **One verified payment-recovery blocker remains in this recheck: dismissal deletes an unverified pending payment's recovery data.**

This review did not edit application code or existing tests, create commits or invoke a real payment SDK/gateway. Backend diagnostics use isolated in-memory SQLite with dummy credentials, dotenv disabled and external HTTP/sockets blocked. Mobile review diagnostics intercept HTTP and mock native/storage dependencies.

## Current results

| Check | Result |
|---|---|
| Existing full Flutter suite, one worker, before the two live cart fixes | **304 passed, 0 failed**, exit 0 |
| Updated connectivity regression file, run separately | **2 passed**, exit 0 |
| Full isolated FastAPI suite, before the live cart validation fix | **240 passed, 0 failed**, 344 warnings |
| Quote → accepted intent → payment recovery controls | **11 passed**, 107 warnings |
| Targeted Dart analysis, six checkout/cart source files plus connectivity test | **No issues**, exit 0 |
| Initial review-only mobile identity/cancellation assertions | **1 passed, 3 failed**: one ID failure subsequently fixed; two unverified-cancellation failures remain |
| Latest mobile identity controls after the live fix | **2 passed**: `prod_1` and `item_special` preserved |
| Latest actual ASGI cart-route/SQLite controls after the live fix | **8 observations**: mixed-invalid replacement now rejects with 400 and preserves quantity3 |
| Original fault/retry/replay matrix | **30/30 executions passed**: phase1 23, fresh-process before-retry 5, after-retry 2 |

Review-only failures are separate from the existing 304-test Flutter suite. Counts overlap across focused/full suites and must not be added together. Next.js unit tests (147 passed) and TypeScript (exit 0) retain the preceding review's results; they were not rerun in this revision.

The full-suite and analysis results precede the late serializer/validation edits. Those edits received the focused identity and actual ASGI controls above; the full suites were not repeated after them. The final phase3 invocation contains two after-retry matrix tests plus two identity controls, **4 passed** in total. The cancellation source stayed unchanged throughout all reproductions and final comparison.

## P1 — Dismissing pending payment deletes recovery before verification

At [checkout_controller.dart:1564](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1564), `cancelPendingPaymentSession` deletes the pending Cashfree ID/amount and accepted draft, adds the attempt to `cancelled_payment_attempts`, then invites a new order. It never asks the gateway/backend whether the payment is paid, pending or unavailable. The checkout screen exposes this path through “Dismiss & Pay Now”.

The actual controller was invoked with a mounted widget context, persisted pending ID/amount and accepted draft. An intercepted verifier was configured once for PENDING and once for PAID. In **both** executions:

```text
verificationRequests = 0
pendingId = null
draftPresent = false
cancelled = [the original attempt ID]
```

The configured statuses were deliberately never consumed: the demonstrated defect is deletion without verification, not a claim that a live gateway reported a paid transaction during testing. For an unresolved or recently paid attempt, this loses the client recovery snapshot and permits another payment attempt. Real duplicate charging was not performed or demonstrated.

**Antigravity action:** guard the operation against duplicate taps, verify the original payment first, complete/reconcile a verified paid attempt using its accepted draft, retain recovery for pending/unavailable/unknown results, and clear/mark cancelled only for a confirmed terminal unpaid result. Retain the original context checks and recover busy state on errors. Apply the same pending/unavailable policy consistently to startup recovery and retry entry points; those source paths also clear recovery for non-paid results.

**Acceptance:** PENDING, ACTIVE, timeout and unknown results preserve ID/amount/draft and prevent a replacement payment; PAID reconciles the original attempt without marking it cancelled; only confirmed FAILED/CANCELLED/EXPIRED unpaid attempts can be cleared. Concurrent dismiss taps must not race verification or completion.

## Closed during review — mixed invalid cart replacement

The initial route skipped unresolved products and rejected only when none of the requested items resolved. A valid plus unknown replacement returned 200 and reduced a saved quantity3 to quantity1. The live fix now raises on each unresolved ID before deleting cart items.

Actual ASGI requests against seeded SQLite reproduced:

```text
Before: prod_1 / Small ×3
POST replacement: prod_1 / Small ×1 + missing-product ×2
Latest response: HTTP 400, missing-product could not be resolved
Latest after: prod_1 / Small ×3 (unchanged)
```

The all-unknown control also returns 400 and preserves quantity3. Exact/legacy ID and verified internal-owner controls still succeed. This closes the reproduced mixed-invalid replacement defect; it does not certify all malformed payload types or ambiguous legacy variants.

## Closed during review — mobile canonical IDs beginning with `item_`

The initial serializer stripped `item_` from the canonical `CartItem.productId`, although [CartNotifier](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:64) already keeps the synthetic row ID in a separate field. The latest [serializer](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:74) preserves the canonical field and falls back to the product's ID only if it is empty.

The actual mobile repository sync was intercepted before HTTP:

```text
Canonical prod_1       → posted prod_1       (pass)
Canonical item_special → posted item_special (latest pass; initially posted special)
syncCart returns true in both cases
```

Both actual mobile serializer assertions pass in the latest fresh invocation. The server's exact-ID controls also preserve `item_special`, with both `special` and `item_special` present in the seeded catalog. This closes the reproduced prefix-stripping defect.

## Verified closures and boundaries

- The old pending-API connectivity expectation has been replaced with immediate offline rejection and held-request duplicate-tap coverage. Both pass, and the complete existing Flutter suite is now green. The duplicate-tap fixture uses an empty pickup cart; it is not a live gateway or realistic valid-cart integration test.
- Unauthenticated victim-phone GET returned no victim cart. An unauthenticated phone-only replacement left the victim's quantity3 and store assignment unchanged. A verified internal-owner control succeeded. The prior phone-ownership bypass was not reproduced in these controls.
- Server exact ID `prod_1`, encoded legacy `prod_1_Small`, and exact `item_special` all resolved correctly in the seeded catalog.
- Native false/throw, same-process retry, concurrency, hydration and fresh-process snapshot replay are checked separately below. Passing these completion controls does not cover user cancellation before completion.
- SQLite/mocked-native tests do not establish physical-device process-kill callback delivery, live settlement, deployed secrets/configuration or multi-worker PostgreSQL contention. Unrelated reports retain their own scope.

## Evidence

Logs and temporary diagnostic sources are retained under `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-matrix15-snapshot-20261019.json`
- `fastkirana-matrix15-connectivity-20261019.log`
- `fastkirana-matrix15-flutter-20261019.log`
- `fastkirana-matrix15-backend-20261019.log`
- `fastkirana-matrix15-quote-20261019.log`
- `fastkirana-matrix15-analyze-20261019.log`
- `fastkirana-matrix15-edge-cases-20261019.log`
- `fastkirana-matrix15-cart-probe-20261019.py`, `.json`, `.log`
- `fastkirana-matrix15-cart-probe-followup-20261019.log` (latest server controls; the JSON file contains this follow-up state)
- `fastkirana-matrix15-phase1-20261019.log`
- `fastkirana-matrix15-phase2-before-20261019.log`
- `fastkirana-matrix15-phase3-after-and-identity-20261019.log`
- `fastkirana-matrix15-followup-snapshot-20261019.json`, `fastkirana-matrix15-final-snapshot-20261019.json`
- `fastkirana-matrix15-quote-launcher-20261019.py`; quote controls use the retained `fastkirana-matrix14-backend-probe-20261019.py` source.

The mobile edge-case command is `flutter test --no-pub --no-test-assets --no-enable-impeller --concurrency=1 --reporter expanded .dart_tool/review_matrix15_identity_test.dart .dart_tool/review_matrix15_cancel_test.dart`, from `D:/Fastkirana/fastkirana_flutter`. The tests assert correct behavior and fail on the observations above; they do not intentionally pass by asserting defective behavior.

Phase1 exports durable mock-store snapshots. Phase2 starts a fresh Flutter invocation with `REVIEW_PHASE=two`, `ACK_PHASE=two`, `CUT_PHASE=two`, `MATRIX_REPLAY=before`. Phase3 starts another invocation with `MATRIX_REPLAY=after`, and runs the two mobile ID controls alongside the two after-retry replays. The matrix again verifies false/throw rollback, retry, concurrency, hydration and commit-boundary replay; see the preceding [matrix report](D:/Fastkirana/docs/PAYMENT_CART_MATRIX_RECHECK_2026-10-19.md) for its scenario definitions.

Of the 20 monitored source/test/config files, 18 stayed unchanged. `cart_repository.dart` and backend `cart.py` changed during this review and received the focused reruns documented above. Final hashes are retained separately. Seven temporary `.dart_tool/review_matrix15_*_test.dart` files were archived under Temp as `fastkirana-matrix15-*-probe-20261019.dart`; restore their original import filenames to reproduce the matrix. Application code, existing tests and commits were not changed by this reviewer.
