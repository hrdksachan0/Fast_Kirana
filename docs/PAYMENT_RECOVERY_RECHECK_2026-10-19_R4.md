# Payment recovery recheck — 19 October 2026, revision 4

Reviewed HEAD `66b1f4a9` plus the saved uncommitted checkout-controller fix. **The disk-only concurrent-dismissal issue from revision 3 is closed in the reproduced case. All 17 focused production-path assertions pass; no remaining defect was reproduced in this defined recheck.**

Only the checkout controller changed among the 23 files monitored in the preceding final snapshot. No application source, existing tests or commits were changed by this reviewer. The temporary diagnostic uses intercepted HTTP, in-memory preferences and controlled native dependencies; it does not launch a real gateway SDK or contact production.

## Verification

| Check | Result |
|---|---|
| Focused payment recovery, concurrency and lock-release tests | **17 passed, 0 failed**, exit 0 |
| Targeted analysis: checkout controller, payment handler, connectivity observer | **No issues**, exit 0 |
| Full existing Flutter suite, one worker | **306 passed, 0 failed**, exit 0 |
| Backend, Next.js and prior cart replay checks | Not rerun in this revision; previous results retain their original scope |

The latest completed backend suite from revision 3 was 241 passed. This revision does not count that as a fresh execution. Focused tests are separate from the existing full Flutter suite; counts should not be added together. Targeted analysis is not a whole-project analysis, and it does not clear the unchanged debug-test print/const suggestions discussed in revision 3.

## Last finding: verified closed

The [dismissal operation](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1597) now acquires `_isHandlingPaymentDismissal` and sets the busy state before the first persisted-ID lookup. `finally` releases the lock on return/error paths. The PAID path also checks `context.mounted` again after loading the accepted draft.

The exact previously failing control now produces:

```text
Controller pending ID: null; original attempt exists on disk
Two simultaneous dismissal calls; verifier held in flight
Actual verification count: 1 (previously 2)
Pending recovery retained; no replacement order
```

The initialized control also passes: one startup verification plus one dismissal verification, with the second concurrent dismissal ignored.

## Fixed acceptance checks

| Scenario | Verified result |
|---|---|
| PENDING, ACTIVE, UNKNOWN, connection timeout | One verification; original pending ID/amount/draft retained; no order; busy state restored |
| FAILED, CANCELLED, EXPIRED, USER_DROPPED, NOT_PAID | One verification; confirmed unpaid recovery cleared; cancelled marker saved; no order |
| PAID | Verification precedes one order POST using original Cashfree ID/UPI; cart3→2; successful cleanup; no cancelled marker |
| UNKNOWN/TIMEOUT at startup and subsequent retry | Recovery preserved; no order POST; busy state clear |
| Two held calls with disk-only ID | One dismissal verification |
| Two held calls with initialized controller ID | One dismissal verification in addition to startup verification |
| Sequential retries after PENDING and timeout | Later operation runs, proving the lock was released; recovery retained |
| Empty-session return followed by a new pending session | Early return releases the lock and the later session verifies normally |

There are ten status cases, two startup/retry cases, two held-call controls and three lock-release cases: **17 total**.

The diagnostic retains Flutter's widget-test mechanics using a binding named `ReviewPaymentBinding`. This avoids the application's string-based test shortcut and exercises actual PAID order reconciliation, rather than only the ordinary test-binding branch. Cart initialization is a fixture; the cart-delta mutation and preferences persistence remain real application code. Logged caught audio/storage-plugin fallbacks are not evidence of physical-device behavior.

## Evidence and limits

Evidence is retained in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-matrix17-snapshot-20261019.json`
- `fastkirana-matrix17-payment-paths-20261019.log`
- `fastkirana-matrix17-analyze-20261019.log`
- `fastkirana-matrix17-flutter-20261019.log`
- Archived `fastkirana-matrix17-payment-paths-probe-20261019.dart`

Reproduction: restore the probe as `D:/Fastkirana/fastkirana_flutter/.dart_tool/review_matrix17_payment_paths_test.dart`, then run `flutter test --no-pub --no-test-assets --no-enable-impeller --concurrency=1 --reporter expanded .dart_tool/review_matrix17_payment_paths_test.dart` from the Flutter directory. Assertions require the correct behavior; none deliberately passes by asserting the old defect.

This closes the reviewed local payment-recovery/concurrency finding. It does not certify live payment settlement, actual device process-kill/callback delivery, deployed configuration or unrelated reports. The application still contains test-binding shortcuts discussed in revision 3; the production branch was deliberately exercised here despite them.

All 23 monitored source/test/config files remained unchanged through the focused checks, full Flutter run and final comparison. The temporary probe was archived to `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-matrix17-payment-paths-probe-20261019.dart`. No application source, existing tests or commits were changed by this reviewer. No further actionable defect was reproduced in this defined recheck.
