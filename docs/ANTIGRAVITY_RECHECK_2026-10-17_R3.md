# FastKirana payment/cart recheck — 17 October 2026, revision 3

Reviewed the saved working tree on HEAD `f04f2a81`, including uncommitted changes. Scope: the two Flutter issue groups in [revision 2](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_2026-10-17_R2.md), plus payment quote/recovery regression controls.

**Full suites are green. Two narrower P2 cases still fail: clear-then-add during hydration, and restart replay after acknowledgement persistence fails.** Application code and existing tests were not changed; no commits, real SDK payments, external HTTP or production writes were performed.

## Fresh verification

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, external sockets/HTTP blocked | **235 passed, 0 failed**, 267 warnings |
| Full Flutter: `flutter test --no-pub --no-enable-impeller --reporter expanded` | **300 passed, 0 failed**, exit 0 |
| Targeted Dart analysis of six checkout/cart files | **No issues**, exit 0 |
| Actual FastAPI quote → intent → recovery controls | **11 passed**, 107 warnings |
| Payment/draft controls including sequential/concurrent completion and cart-save failure retry | **7 passed** |
| Fresh-process replay after successfully persisted acknowledgement | **1 passed** |
| Focused cart checks plus existing offline-cart test file | **8 passed, 1 failed** |
| Failed acknowledgement write: capture phase | **1 passed**, confirms absent durable acknowledgement |
| Fresh-process replay after that failed acknowledgement write | **1 failed**: quantity expected2, actual1 |

These focused tests assert correct behavior; their failures are genuine mismatches. Native channels and HTTP are mocked/intercepted. Fresh-process cases restore exported mock-store preferences in a separate Dart process, not on a physical device. Full-suite counts exclude the temporary probes; counts from overlapping runs should not be added together.

## Verified improvements

- Same-order concurrent completion now coalesces: starting quantity3, purchased1, two POST acknowledgements for the same durable order leave quantity2.
- A failed cart disk save now restores the in-memory base. Retrying finishes with quantity2 on disk, rather than subtracting twice.
- Sequential completion remains3→2→2, and normal restart replay remains2→2 when acknowledgement was durably saved.
- Existing offline-cart quantity-doubling regression is closed: immediate add2 now remains2. All three tests in that file pass.
- Held startup pending-key resolution no longer replaces a newer queue: server/UI/local all retain A1+B1, pending=false, version=ack1.
- Same-product addition during loading preserves A2+1=A3. Distinct A+B, clear alone and delayed server GET controls remain correct.
- Accepted-draft write failure/replacement controls and the eleven server price/coupon/missing-intent controls remain passing.

## 1. [P2] Clear followed by add still resurrects the previous basket

**Source:** [cart_provider.dart:220](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:220), especially the [empty-list clear guard](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:222).

Actual notifier/repository sequence:

1. Persist A quantity2 and hold the initial local-storage read.
2. Clear the cart; the intercepted server DELETE succeeds.
3. Add B quantity1 before the held read completes.
4. Complete the old A read and let synchronization settle.

```text
Expected UI/local/server: B1
Observed UI/local/server: B1 + A2
pending=false
```

The guard treats an empty pending list as clear intent. Adding B makes that list nonempty, so the same old hydration data becomes eligible for merging again. The item-ID equality fix cannot protect an unrelated cleared item.

**Antigravity fix:** preserve a clear generation/operation independently of the latest item-list shape. An older hydration read must not restore rows that precede that clear, even after subsequent adds. Ordered mutation replay against a versioned base is also valid; keep the now-passing same-product and pending-key protections.

**Acceptance:** With held old A2 hydration, both clear and clear+addB must respectively finish empty and B1 across UI, local storage and server. Also cover clear+addA, repeated clear, offline/reconnect and owner/hub changes.

## 2. [P2] Failed acknowledgement persistence permits a second subtraction after restart

**Source:** [checkout_controller.dart:1373](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1373), including the [unchecked SharedPreferences write](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1380).

The new in-flight gate fixes concurrency, and the cart rollback fixes the tested cart-save exception. Cart cleanup and durable acknowledgement are still separate operations.

Actual two-process reproduction:

```text
Process1: cart3, accepted purchase1
Cart cleanup succeeds: cart2 durably saved
Inject false return only for acknowledged_order_ids write
Completion returns; cached acknowledgement exists
Reload preferences: durable acknowledgement=null
Export durable preferences

Process2: restore those preferences and replay same durable order
Before=2, after=1, expected=2
```

The static set protects only the original process. Returning false is ignored, and caught acknowledgement exceptions are swallowed. A process termination between the cart write and marker write has the same unrecorded-delta boundary.

**Antigravity fix:** commit the purchased cart delta and durable acknowledgement in one atomic record, or use a resumable local journal that records whether that specific delta was applied. Validate false/throwing acknowledgement writes and retain recoverable state until completion is durable. Keep the in-flight gate and rollback protections. Checking the boolean alone does not close the crash window.

**Acceptance:** Fail acknowledgement persistence with both false and thrown writes after successful cart persistence; restart and replay. Quantity must remain2. Test termination around each journal/cart/acknowledgement boundary, normal successful restart, concurrent callbacks and distinct orders.

## Handoff order

1. Make clear intent survive subsequent additions during hydration.
2. Make cart-delta acknowledgement durable and resumable across acknowledgement-write failure/restart.
3. Add both failing scenarios as regression tests, retaining all now-passing controls.
4. Rerun the full suites and verify the native payment lifecycle in a test environment.

This review does not clear unrelated backend/security/Redis findings or verify production services, independent PostgreSQL worker isolation, signed native builds or real payment settlement. Next.js tests/type checking were not rerun in this Flutter follow-up.

## Evidence and source stability

Evidence is retained in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck11-snapshot-20261017.json`
- `fastkirana-recheck11-backend-20261017.log`
- `fastkirana-recheck11-flutter-20261017.log`
- `fastkirana-recheck11-analyze-20261017.log`
- `fastkirana-recheck11-backend-probe-20261017.py`
- `fastkirana-recheck11-quote-recovery-20261017.log`
- `fastkirana-recheck11-cart-probe-20261017.dart`
- `fastkirana-recheck11-cart-20261017.log`
- `fastkirana-recheck11-payment-probe-20261017.dart`
- `fastkirana-recheck11-payment-phase1-20261017.log`
- `fastkirana-recheck11-payment-phase2-20261017.log`
- `fastkirana-recheck11-payment-restart-prefs-20261017.json`
- `fastkirana-recheck11-ack-failure-probe-20261017.dart`
- `fastkirana-recheck11-ack-failure-phase1-20261017.log`
- `fastkirana-recheck11-ack-failure-phase2-20261017.log`
- `fastkirana-recheck11-ack-failure-prefs-20261017.json`

Temporary Dart probes run from `.dart_tool` with `--no-test-assets --no-enable-impeller`; none were added to the application test suite. To reproduce the acknowledgement case, restore the payment and acknowledgement probe files there using their original `review_recheck11_*_test.dart` filenames and run the latter first normally, then in a fresh Flutter process with `--dart-define=ACK_PHASE=two`.

The twelve snapshotted source/test files retained identical hashes through verification. Review artifacts are the only repository changes made by this review.

