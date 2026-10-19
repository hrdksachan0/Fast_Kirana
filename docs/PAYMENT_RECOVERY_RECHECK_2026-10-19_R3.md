# Pending-payment recheck — 19 October 2026, revision 3

Reviewed HEAD `66b1f4a9` plus saved uncommitted changes. **The preceding P1 recovery-deletion defect is closed in the tested payment-status paths.** Verification now precedes dismissal; unresolved payments retain recovery, confirmed failed payments clear it, and the production PAID path reconciles the original order. A narrower P2 concurrent-call edge case remains when the pending ID has not yet entered controller state.

No application code, existing tests or commits were changed by this reviewer. Diagnostic tests live temporarily under `.dart_tool` and are archived after execution. Backend verification uses isolated in-memory SQLite, dummy credentials, disabled dotenv and blocked external HTTP/sockets. Mobile diagnostics intercept HTTP and mock native/storage dependencies; no real payment SDK launch or live settlement occurs.

## Results

| Check | Result |
|---|---|
| Original two cancellation regression assertions plus existing debug cancellation test | **3 passed**, exit 0 |
| Production-branch cancellation statuses and two concurrent-call controls | **11 passed, 1 failed**, exit 1; sole failure is disk-only pending-ID concurrency |
| Startup and retry unknown/timeout controls | **2 passed**, preserving recovery and blocking order placement |
| Injected connectivity stream subscription, after the live fix | **1 passed** |
| Full existing Flutter suite, one worker, after the live connectivity fix | **306 passed, 0 failed**, exit 0 |
| Full isolated backend suite | **241 passed**, 353 warnings, exit 0 |
| Final targeted Dart analysis: controller, payment handler, connectivity observer, debug cancellation test | **0 errors/warnings; 11 information-level lint issues**, exit 0 |

Focused/full counts overlap and must not be added. The existing Flutter suite does not include `.dart_tool` diagnostics. Next.js tests, TypeScript, prior 30-case cart completion/replay matrix and server cart-identity controls were not rerun in this revision. Their previously recorded scope remains separate; the relevant cart source hashes match the preceding final snapshot.

## Verified P1 closure

The actual controller and payment handler were exercised with intercepted responses. A test binding named `ReviewPaymentBinding` retains `AutomatedTestWidgetsFlutterBinding` mechanics while avoiding the application's string-based test detection. This makes the controller execute the same PAID reconciliation branch it uses in the app. Futures are run using `tester.runAsync`; a cart fixture starts at A×3, retaining real cart-delta mutation and persistence behavior.

| Verification result | Observed dismissal outcome |
|---|---|
| PENDING | One verification; ID/amount/draft retained; no order; cart3 |
| ACTIVE | Same preservation |
| UNKNOWN | Same preservation |
| Connection timeout | Same preservation; busy state restored |
| FAILED | One verification; recovery cleared; cancellation marker saved; no order; cart3 |
| CANCELLED | Same confirmed-unpaid cleanup |
| EXPIRED | Same confirmed-unpaid cleanup |
| USER_DROPPED | Same confirmed-unpaid cleanup |
| NOT_PAID | Same confirmed-unpaid cleanup |
| PAID | One verification followed by one order POST using original Cashfree ID and UPI; cart3→2; recovery cleared after success; no cancelled marker |

The PAID trace was `verify → order`; the server order response was controlled. This establishes the local reconciliation behavior for the fixture, not live settlement, automatic SDK callback delivery, physical-device process-kill recovery or real concurrent database workers.

The first expanded fixture lacked connectivity/cart initialization and failed during setup. It was corrected without changing app code. A later fixture mixed a fake-async-created hold gate with real async execution and stalled; only that owned diagnostic runner was stopped, and the gate was moved into its actual execution zone. Those attempts are excluded from application findings. The completed `production-paths-verified` run is the authoritative 12-case result.

The separate UNKNOWN/TIMEOUT startup controls each perform one startup verification and one retry verification, preserve the original ID and accepted draft, issue zero order requests and leave the busy flag clear.

## Remaining P2 — disk-only pending-ID lookup precedes the busy lock

At [checkout_controller.dart:1596](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1596), the method checks `isPlacingOrder`, then awaits persisted-ID lookup if `state.pendingCashfreeOrderId` is null. It sets the busy flag only after that await. Two simultaneous invocations can both pass the initial guard before either sets it.

Controlled reproduction using the actual method:

```text
Initial controller pending ID: null
Persisted pending ID: cf16_concurrent_false
Invoke dismissal twice; hold verifier until both calls have started
Verification requests: 2 (expected 1)
```

The normal initialized control passed: startup populated the pending ID, and two held dismissal calls produced one dismissal verification, in addition to the one startup verification. Both controls used a PENDING response. **No duplicate order or charge was demonstrated.** This is an overlapping-operation guard issue in the disk-fallback path, rather than the previous recovery-deletion defect. The reproduction directly invokes the public method before controller initialization; it does not establish that two taps on the normal initialized checkout banner reach that state.

**Antigravity action:** acquire a per-controller operation lock synchronously before the first asynchronous lookup, release it in `finally` for every exit/error, and keep the mounted/disposal guards. Preserve the confirmed PAID/PENDING/terminal behavior above.

**Acceptance:** the disk-only and initialized held-request controls both perform one dismissal verification; failures release the lock and retain recovery. Keep this regression alongside the original status-matrix tests.

## Test coverage and lint follow-ups

The new [runtime test gate](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1614) skips paid order completion under an ordinary Flutter test binding. Thus the previous PAID assertion passing only proves verification/reference retention in that environment. This review separately exercised the production branch successfully. Prefer injected HTTP/native/navigation fakes and assertions for the actual order POST/cart result, instead of excluding business logic based on a binding's type name.

Targeted analysis reports one controller `use_build_context_synchronously` information-level issue at [line 1627](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1627): the context is checked before awaiting draft loading, then passed onward without a fresh mounted check. The other ten information-level issues are debug-test `print`/`const` suggestions. No lifecycle crash was reproduced in this review; this is the actual analyzer output, not a claim of clean analysis or another demonstrated production failure.

The first full Flutter run stalled after 99 passing tests at the existing brief-network-drop connectivity test. At that point the connectivity constructor skipped all subscriptions under a test binding, including explicitly injected streams; the test's stream cleanup could not finish. Only this owned stalled runner was stopped. The connectivity source was then updated during review to honor injected streams and probes. The bounded subscription assertion passed on that new source (`hasListener=true`), and the new complete Flutter run finished with **306 passed**. The interrupted run is not counted as a completed or passing suite. An initial missing-import compile attempt in the new subscription diagnostic is also excluded from application results.

## Evidence

Retained under `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-matrix16-snapshot-20261019.json`
- `fastkirana-matrix16-prior-cancel-20261019.log`
- `fastkirana-matrix16-production-paths-verified-20261019.log`
- `fastkirana-matrix16-backend-20261019.log`
- `fastkirana-matrix16-analyze-20261019.log`
- `fastkirana-matrix16-analyze-final-20261019.log`
- `fastkirana-matrix16-flutter-20261019.log`
- `fastkirana-matrix16-flutter-final-20261019.log`
- `fastkirana-matrix16-final-controls-20261019.log` (subscription plus the two startup/retry controls: 3 passed)
- `fastkirana-matrix16-connectivity-snapshot-20261019.json`, `fastkirana-matrix16-final-run-snapshot-20261019.json`

The authoritative production-path command is `flutter test --no-pub --no-test-assets --no-enable-impeller --concurrency=1 --reporter expanded .dart_tool/review_matrix16_payment_paths_test.dart`. The original fixture version contained ten status cases and two concurrency cases; the retained source also includes separately selected startup/retry controls. These diagnostics assert correct outcomes and fail on the actual concurrency mismatch.

The original 21 monitored source/test/config files remained unchanged during this review. Connectivity source was added to monitoring with its test, changed during the review, and received the subscription control plus a full Flutter rerun. The final 23-file snapshot remained unchanged through the completed rerun and final comparison. The three temporary probes were archived to Temp as `fastkirana-matrix16-prior-cancel-probe-20261019.dart`, `fastkirana-matrix16-payment-paths-probe-20261019.dart` and `fastkirana-matrix16-connectivity-subscription-probe-20261019.dart`. Restore their original `.dart_tool/review_matrix16_*_test.dart` names when reproducing them. No application source, existing tests or commits were changed by this reviewer.
