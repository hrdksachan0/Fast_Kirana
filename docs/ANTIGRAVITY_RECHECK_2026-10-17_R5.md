# FastKirana payment/cart recheck — 17 October 2026, revision 5

Reviewed saved working tree on HEAD `f04f2a81`, including uncommitted changes. Scope: the combined cart/applied-order save requested in [revision 4](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_2026-10-17_R4.md), plus cart/payment regression controls.

**The previous post-commit restart failure is closed in the executed case. One P2 retry defect remains when the combined persistence write itself is rejected: an uncommitted applied-order ID remains visible in the preferences cache.**

Application source and existing tests were not changed. No commits, real gateway/SDK payments, external HTTP or production writes were made.

## Fresh verification

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, external sockets/HTTP blocked | **240 passed, 0 failed**, 341 warnings |
| Server quote → durable intent → recovery controls | **11 passed**, 107 warnings |
| Dart analysis of six checkout/cart files | **No issues**, exit 0 |
| Independent full Flutter suite, explicit Skia, `--concurrency=1` | **301 passed, 0 failed**, exit 0 |
| Flutter phase1: cart, draft/payment, offline and storage-boundary checks | **19 passed, 2 failed** |
| Fresh Flutter process: normal restart, legacy-acknowledgement-only failure, storage cut after combined commit | **3 passed** |

The two focused failures assert intended correct behavior. Native channels and HTTP are mocked/intercepted. Fresh-process tests restore exported mock-store preferences in a new Flutter invocation; physical-device termination is not claimed. Full-suite counts exclude the temporary probes.

A separate full workspace Flutter run was already active, so the independent full run started after it ended. The first independent run stalled during compilation and was stopped; it is not counted as a test failure or a pass. The full suite then completed with one worker in 70 seconds. Next.js tests/type checking were not rerun in this Flutter follow-up.

## Verified fixes

- Cart items and the new applied-order ID now share the first saved envelope. [saveLocalCart](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:189) receives `appliedOrderId`, and [cleanup passes it](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:511).
- Allow the combined cart3→2 save, then reject every later storage write: the persisted envelope already contains the order ID. Fresh-process replay correctly remains2→2.
- Normal restart and failed legacy acknowledgement-only restart remain2→2.
- Clear→addB during held A2 hydration remains B1 only.
- Sequential/concurrent completion, thrown-before-save rollback/retry, same-product hydration, delayed pending-key resolution and existing offline tests remain passing.
- The new existing atomic-envelope regression passes.

## Remaining [P2] Rejected combined save leaves a phantom applied ID in cache

**Source:** [saveLocalCart rejected-write return](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:253), [getAppliedOrderDeltas reads cached envelope](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:170), [controller trusts returned IDs](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1366), [UI-only rollback](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:518).

The combined save checks the platform result, but it does not roll back or invalidate the preferences cache on false/throw. In the tested library, that cache already contains the attempted envelope before the platform rejects it. Restoring the notifier's UI list does not restore this cached envelope.

Two actual controller/repository/native-store cases were executed, one returning false and one throwing from the first combined cart persistence write. The store accepts subsequent writes:

```text
Initial UI/durable cart = quantity3
Accepted purchased quantity = 1
Attempt combined envelope: quantity2 + this order's applied ID
Native write rejects; completion throws
UI rollback = quantity3
getAppliedOrderDeltas BEFORE retry still returns the uncommitted order ID

Retry same durable business order, without restarting or manually reloading prefs
Controller treats it as already applied and skips subtraction
Final UI = quantity3
Reload preferences: durable cart = quantity3
Expected final quantity = 2
```

Observed output for both modes:

```json
{"mode":"false","completionThrew":true,"afterFailure":3,"cachedAppliedBeforeRetry":["atomic_reject_false"],"afterRetry":3,"diskAfterRetry":[3],"expected":2}
{"mode":"throw","completionThrew":true,"afterFailure":3,"cachedAppliedBeforeRetry":["atomic_reject_throw"],"afterRetry":3,"diskAfterRetry":[3],"expected":2}
```

The native failure is one-shot. This is a retry bug after storage becomes available, rather than an expectation that an ongoing outage should succeed.

## Exact Antigravity fix

1. Preserve the previous committed cart-envelope/cache state before attempting the combined write.
2. On a false return **or exception**, restore/invalidate the attempted preferences value from verified durable state before a later completion lookup can observe it. Preserve the preexisting cart; do not delete the entire cart as cleanup.
3. Keep the notifier rollback, but also remove the uncommitted applied-order ID from the state consulted by `getAppliedOrderDeltas`. If durable state cannot be read reliably, defer/fail the acknowledgement lookup instead of treating an optimistic cache entry as a committed marker.
4. Only add the order to in-memory acknowledged state after a committed combined envelope or a verified already-committed record is established.
5. Keep the atomic envelope, completion gate, clear generation and monotonic queue fixes. Serialize the scope's state transitions so rollback cannot overwrite a newer edit.

**Acceptance test to add:**

- Start cart3, purchase1.
- Fail the native combined cart write once with false, then repeat with a thrown exception.
- After failure, UI/disk remain3 and applied-order lookup must not report that attempt as committed.
- Retry the same order in the same process **without an explicit test-only preferences reload**.
- Require UI/disk2, then restart/replay and require2 again.
- Retain the passing “combined commit succeeds, all later writes fail” restart test and the clear→addB case.

This is the only new actionable finding from this follow-up's executed scope. It does not establish that unrelated backend/security/Redis reports, deployed services, PostgreSQL worker isolation, signed native lifecycle or live settlement are resolved.

## Evidence

Files retained under `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck13-snapshot-20261017.json`
- `fastkirana-recheck13-extra-snapshot-20261017.json`
- `fastkirana-recheck13-backend-20261017.log`
- `fastkirana-recheck13-quote-recovery-20261017.log`
- `fastkirana-recheck13-flutter-20261017.log`
- `fastkirana-recheck13-flutter-final-20261017.log`
- `fastkirana-recheck13-analyze-20261017.log`
- `fastkirana-recheck13-flutter-phase1-20261017.log`
- `fastkirana-recheck13-flutter-phase2-20261017.log`
- `fastkirana-recheck13-cart-probe-20261017.dart`
- `fastkirana-recheck13-payment-probe-20261017.dart`
- `fastkirana-recheck13-ack-failure-probe-20261017.dart`
- `fastkirana-recheck13-storage-cut-probe-20261017.dart`
- `fastkirana-recheck13-atomic-failure-probe-20261017.dart`
- The three `fastkirana-recheck13-*-prefs-20261017.json` restart snapshots.

Probes run from `.dart_tool` with `--no-pub --no-test-assets --no-enable-impeller`. Their archived sources can be restored under the original `review_recheck13_*_test.dart` names. Replay controls use a fresh invocation with `REVIEW_PHASE=two`, `ACK_PHASE=two`, and `CUT_PHASE=two` Dart defines.

All fifteen snapshotted source/test files retained identical hashes through final verification; HEAD remained `f04f2a81`. The final full Flutter command was `flutter test --no-pub --no-enable-impeller --concurrency=1 --reporter expanded`. Temporary probes were removed from the repository after execution. This review changed only its Markdown report in the repository.

