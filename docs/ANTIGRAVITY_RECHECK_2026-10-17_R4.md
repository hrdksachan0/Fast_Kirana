# FastKirana payment/cart recheck — 17 October 2026, revision 4

Reviewed saved working tree on HEAD `f04f2a81`, including uncommitted changes. Scope: the two remaining cases in [revision 3](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_2026-10-17_R3.md) and their cart/payment regression controls.

**Both previous exact reproductions now pass. One P2 durability gap remains: cart contents and the newly applied order marker are still committed in separate writes.**

No application code or existing tests were edited. No commits, production service writes, real payments or external HTTP calls were made.

## Fresh results

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, external network/HTTP blocked | **238 passed, 0 failed**, 303 warnings |
| Full Flutter `flutter test --no-pub --no-enable-impeller --reporter expanded` | **300 passed, 0 failed** |
| Dart analysis of six checkout/cart files | **No issues**, exit 0 |
| Actual server quote → durable intent → recovery controls | **11 passed**, 107 warnings |
| Flutter phase1: cart, payment, offline controls and persisted-state capture | **18 passed** |
| Flutter phase2: three separate test isolates restoring persisted state | **2 passed, 1 failed** |

The failing focused test asserts correct behavior, rather than deliberately passing a bug observation. Native calls and HTTP are mocked/intercepted. Fresh-process replay restores exported actual mock-store preferences in a new Flutter process; physical-device termination is not claimed. Overlapping test counts must not be summed.

## Verified fixes

- **Clear then add during held hydration:** old A2 is not resurrected; server/UI/local contain B1 only. The [clear generation check](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:224) works in this case.
- **Legacy acknowledgement write alone returns false:** the new applied-delta record survives, so same-order restart replay remains quantity2→2.
- Successful acknowledgement restart, concurrent and sequential completion, and cart-save failure retry continue to preserve quantity2.
- Same-product hydration, clear alone, delayed pending-key resolution, delayed server GET and all three existing offline-cart tests pass.
- Draft-persistence controls and eleven server price/coupon/recovery controls continue to pass.

## Remaining [P2] Cart can commit before every applied-order marker fails

**Source:** [controller cleanup before marker](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1377), [later marker call](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1385), [repository marker writes](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:138), [separate cart write](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:225).

The new global record and envelope copy protect the previous failure of only `acknowledged_order_ids`. They are written after the cart quantity has already been persisted. The first cart write does not include this order's applied-delta marker.

Actual two-process fault sequence:

```text
Initial cart quantity3; accepted purchased quantity1
Allow cart3→2 to commit
Then make every subsequent storage write return false
Six later writes fail, including journal/envelope-marker/legacy acknowledgement
Reload storage: cart2 is durable, journal=null, legacy acknowledgement=null
Durable cart envelope has no appliedOrderDeltas marker

Restart with those exact durable preferences
Replay the same durable business order
Observed quantity2→1; expected2
```

This models one storage outage beginning immediately after the successful cart write. It also exposes the unrecorded interval between cart commit and marker commit. Duplicating a marker in multiple later writes does not make the earlier cart update and marker atomic.

## Exact Antigravity plan

1. Replace the controller's “remove items, then record applied delta” sequence with one repository operation that commits the updated cart and this order's ID together.
2. Pass `orderId` into the purchased-delta operation. Build one scoped cart envelope containing both the updated `items` and `appliedOrderDeltas + orderId` **before** its first persistence write.
3. Check the persistence result. On false/throw, retain or restore the previous cart state and allow a safe retry. Do not mark completion durable from an in-memory cache update.
4. On restart, read the applied ID from that same committed cart envelope before applying the delta. Separate legacy/global acknowledgement keys can remain compatibility data, but must not be necessary for correctness after a successful atomic envelope write.
5. Keep the in-flight completion gate, rollback behavior, clear generation and monotonic sync protections.
6. Do not merely move the independent marker write before subtraction: that creates the opposite partial state, with marker committed but old quantities still present.

**Required acceptance:**

- Cart commit succeeds, then all subsequent writes fail: restart/replay must remain2.
- Failure before the combined commit: retry must finish3→2 once.
- Process ends after the combined commit but before UI/legacy-marker updates: restart/replay must remain2.
- Legacy acknowledgement-only failure, normal restart, concurrent callbacks and cart-save retry must remain passing.
- Clear→addB under held A2 hydration must still finish B1 only.

Retain the current full-suite assertions and add the storage-cut reproduction as a regression; no weakening of existing quantity assertions is needed.

## Evidence

Files retained in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck12-snapshot-20261017.json`
- `fastkirana-recheck12-backend-20261017.log`
- `fastkirana-recheck12-flutter-20261017.log`
- `fastkirana-recheck12-analyze-20261017.log`
- `fastkirana-recheck12-quote-recovery-20261017.log`
- `fastkirana-recheck12-flutter-phase1-20261017.log`
- `fastkirana-recheck12-flutter-phase2-20261017.log`
- `fastkirana-recheck12-cart-probe-20261017.dart`
- `fastkirana-recheck12-payment-probe-20261017.dart`
- `fastkirana-recheck12-ack-failure-probe-20261017.dart`
- `fastkirana-recheck12-storage-cut-probe-20261017.dart`
- `fastkirana-recheck12-payment-restart-prefs-20261017.json`
- `fastkirana-recheck12-ack-failure-prefs-20261017.json`
- `fastkirana-recheck12-storage-cut-prefs-20261017.json`

To replay, restore the Dart probes to `.dart_tool` under their original `review_recheck12_*_test.dart` names. Run phase1 normally, then a fresh Flutter invocation with `--dart-define=REVIEW_PHASE=two --dart-define=ACK_PHASE=two --dart-define=CUT_PHASE=two`. Probes use `--no-pub --no-test-assets --no-enable-impeller`.

Temporary repository probes were removed. All twelve snapshotted source/test files retained identical hashes during this recheck; HEAD remained `f04f2a81`. Next.js tests/type checking were not rerun. This follow-up does not clear unrelated security/Redis findings or verify deployed services, PostgreSQL worker isolation, signed native builds or real gateway settlement.

