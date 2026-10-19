# Payment/cart verification — 19 October 2026

Reviewed saved working tree on HEAD `66b1f4a9`, including uncommitted changes. This closes the pending cart-cache retry case from [17 October revision5](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_2026-10-17_R5.md) against one fixed local acceptance matrix.

**Agreed fault/retry/replay matrix: 30/30 case executions passed. No remaining failure was reproduced in that defined matrix.** Application source and existing tests were not edited; no commits, real gateway/SDK payments or production service writes were performed.

**The full Flutter suite is not green: 302 passed, 1 failed.** The checkout connectivity regression test also fails when run alone. Its pending-API-check expectation no longer matches the controller's immediate transport guard; this result does not demonstrate a payment/cart corruption defect.

## Fresh results

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, external network/HTTP blocked | **240 passed, 0 failed**, 342 warnings |
| Server quote → durable intent → recovery controls | **11 passed**, 107 warnings |
| Next.js unit tests | **147 passed**, 21 suites, 0 failed |
| TypeScript `tsc --noEmit --incremental false` | **Exit 0**, no errors |
| Targeted Dart analysis: six checkout/cart files | **No issues**, exit 0 |
| Matrix phase1: success, persistence failures/retry, concurrency, hydration and existing offline tests | **23 passed** |
| Matrix phase2: fresh-process normal/acknowledgement/storage-cut replay and restart before rejected-write retry | **5 passed** |
| Matrix phase3: fresh-process replay after successful retry for false/throwing native writes | **2 passed** |
| Independent full Flutter suite, Skia, one worker | **302 passed, 1 failed**, exit 1 |
| Isolated checkout connectivity regression test | **0 passed, 1 failed**, same assertion, exit 1 |

The matrix includes the six existing offline-cart tests. Counts overlap with the full suites and must not be added to them. Focused assertions check intended correct outcomes, rather than intentionally passing bug observations.

## Remaining verification issue — P2

The existing [checkout connectivity test](D:/Fastkirana/fastkirana_flutter/test/widgets/checkout_connectivity_guard_test.dart:53) fails at `expect(isPlacingOrder, isTrue)`. Its fake connection starts with `isOnline=false` and transport `none`, but expects checkout to await its pending `checkConnection()` Future, keep the busy flag set and call that probe once.

The saved [controller](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:514) deliberately removed the awaited probe. For this fake's already-offline state it immediately displays the offline message and resets the busy flag. Both the full suite and an isolated rerun reproduce the same mismatch. This is a verified source/test contract inconsistency, not evidence that offline checkout launches payment or that the fixed cart-cache defect remains.

Antigravity follow-up:

1. Keep the intended connectivity behavior explicit. If the current fast transport guard is intended, update this regression to assert immediate offline rejection and zero payment/order requests; do not retain expectations for a removed awaited probe.
2. Preserve duplicate-tap coverage as a separate realistic fixture: a valid cart/address and a held real quote/order request. Assert one in-flight operation and proper busy-state reset after failure. The current empty-cart/offline fixture cannot test that contract after immediate rejection.
3. Cover active Wi-Fi with unreachable API through the actual request-error path. Assert no SDK launch/order success and a recoverable error state. If API preflight is instead a product requirement, restore that behavior and retain the pending-probe test.
4. Rerun this test file and then the full Flutter suite serially. Until then, report **302/303**, not an all-passing Flutter suite.

Exact isolated reproduction: `flutter test --no-pub --no-test-assets --no-enable-impeller --concurrency=1 --reporter expanded test/widgets/checkout_connectivity_guard_test.dart` from `D:/Fastkirana/fastkirana_flutter`.

## Fixed acceptance matrix

| Scenario | Verified outcome |
|---|---|
| Successful purchased-delta commit: cart3, purchase1 | Cart and applied ID commit together; remaining quantity2 |
| Sequential same-order duplicate | Quantity3→2→2 |
| Concurrent same-order callbacks, both POSTs held until present | One purchased delta; final quantity2 |
| Native combined write returns false once | UI/disk stay3; applied lookup excludes the rejected ID; same-process retry finishes2 |
| Native combined write throws once | Same correct rollback/lookup/retry result |
| Restart from durable state before retry after native false | Fresh-process cart3→2 |
| Restart from durable state before retry after native throw | Fresh-process cart3→2 |
| Restart after successful same-process retry, false case | Fresh-process cart2→2 |
| Restart after successful same-process retry, throw case | Fresh-process cart2→2 |
| Combined cart/ID save commits, all later storage writes fail | Fresh-process replay remains2→2 |
| Only legacy acknowledgement write fails | Applied ID in committed envelope suppresses repeated subtraction;2→2 |
| Earlier cart-save exception before native commit | UI rollback and retry preserve the intended remainder2 |
| Accepted-draft initial write returns false/throws | SDK launch aborted; no phantom accepted draft |
| Replacing accepted draft returns false/throws | Previous committed100 draft preserved |
| Saved A2 plus new B1 during held hydration | A2+B1 |
| Saved A2 plus addA1 during held hydration | A3 |
| Clear during held A2 hydration | Empty |
| Clear then addB during held A2 hydration | B1 only; A is not resurrected |
| Hold pending-key lookup, then edit | Latest server/UI/local state retained; pending/version acknowledgement correct |
| Hold server GET, then edit | Stale server response does not overwrite the edit |
| Existing offline/reconnect/restart and atomic-envelope regressions | Passing |

## Last blocker: verified closed

The old failure was: a rejected preferences write left its attempted applied-order ID in cache, so same-process retry skipped cart cleanup and left quantity3.

The current [rollback path](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:186) restores/reloads attempted state and excludes failed IDs until a successful commit. Both native-store failure modes now produce:

```text
After rejected write: quantity3
Applied-order lookup before retry: []
Same-process retry: quantity2
Durable cart after reload: quantity2
```

Separate Flutter invocations then restored actual exported mock-store preferences from both checkpoints:

```text
Before retry snapshot: quantity3 → replay → quantity2
After successful retry snapshot: quantity2 → replay → quantity2
```

This was verified independently for false and thrown native writes, without inserting a test-only preferences reload before the same-process retry.

## Scope and test execution notes

- The Dart package has been renamed to `fastminute_flutter`. Temporary probe imports were updated to match it; an initial outdated-import compile attempt is excluded from application results.
- Checkout completion now schedules local cleanup in the background. The probes drain queued asynchronous work before asserting cart/cache/disk outcomes. Background cleanup exceptions are observed through injected failures and final state, rather than requiring the public completion Future to throw.
- An initial parallel full/focused Flutter attempt collided in generated `build/test_cache`. It was stopped. Final Flutter invocations run sequentially; the cache error is not counted as an application failure.
- Native payment, storage and Dio behavior are controlled/mocked in the diagnostics. Fresh-process tests restore exported durable mock-store preferences and explicitly replay the same durable order.
- This verifies the stated local replay matrix. It does not establish real-device process-kill recovery/callback redelivery, live Cashfree settlement, deployed configuration or independent PostgreSQL worker contention. It does not clear unrelated security/Redis reports.

## Retained evidence

Evidence is in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-matrix14-snapshot-20261019.json`
- `fastkirana-matrix14-backend-20261019.log`
- `fastkirana-matrix14-quote-recovery-20261019.log`
- `fastkirana-matrix14-node-20261019.log`
- `fastkirana-matrix14-tsc-20261019.log`
- `fastkirana-matrix14-analyze-20261019.log`
- `fastkirana-matrix14-phase1-final-20261019.log`
- `fastkirana-matrix14-phase2-before-20261019.log`
- `fastkirana-matrix14-phase3-after-20261019.log`
- `fastkirana-matrix14-flutter-final-20261019.log`
- `fastkirana-matrix14-connectivity-isolated-20261019.log`
- Archived `fastkirana-matrix14-*-probe-20261019.dart` sources.
- `fastkirana-matrix14-reject-false-before-20261019.json`, `reject-throw-before`, `reject-false-after` and `reject-throw-after` checkpoint exports, with the same full filename prefix/date.
- The normal payment, legacy-acknowledgement and storage-cut persisted-preference exports.

Probe phase1 captures the durable checkpoints. Phase2 uses a fresh invocation with `REVIEW_PHASE=two`, `ACK_PHASE=two`, `CUT_PHASE=two`, `MATRIX_REPLAY=before`. Phase3 uses another fresh invocation with `MATRIX_REPLAY=after`. Temporary files use the original `review_matrix14_*_test.dart` names under `.dart_tool` and `--no-pub --no-test-assets --no-enable-impeller`.

The 19 recorded application/test/configuration hashes remained unchanged through the final full run and isolated failure reproduction. The five temporary `.dart_tool/review_matrix14_*_test.dart` probes were archived to the Temp evidence directory after testing. No application source, existing tests or commits were changed by this review.

