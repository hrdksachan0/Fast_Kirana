# FastKirana / FastMinute independent recheck — 19 October 2026, revision 3

**Both previously reported P2 cart cases are now fixed in execution. A new connectivity test-environment branch prevents the full Flutter suite from completing.**

Reviewed HEAD `66b1f4a9` plus current uncommitted fixes, including the new connectivity/payment changes and `debug_cancel_test.dart`. All 15 monitored source/test files remained unchanged during verification. Application source and existing tests were not edited by this review. [Verification summary](D:/Fastkirana/docs/verification/2026-10-19-r3-verification-summary.json).

## Fresh verification

| Check | Result |
| --- | --- |
| Isolated Python suite | **240 passed**, 0 failed/errors/skipped; 349 warnings |
| Actual full-app ASGI + SQLite cart controls | Ten observations; all eight explicit closure checks passed |
| Focused Flutter: 17 review assertions + 7 existing offline-cart tests | **23 passed, 1 failed**, exit 1; failure is the connectivity subscription control |
| Full Flutter suite, `--concurrency=1` | **Not completed.** Stalled after 99 completed tests on connectivity teardown; stopped after 114 seconds without progress |
| Dart analysis, seven changed/related files | Exit 0; **0 errors/warnings, 11 informational diagnostics**, including an async BuildContext diagnostic and debug-test style/print diagnostics |

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-19-r3-python-results.json), [ASGI observations](D:/Fastkirana/docs/verification/2026-10-19-r3-cart-security.json), [eight cart checks](D:/Fastkirana/docs/verification/2026-10-19-r3-cart-checks.json), [focused Flutter log](D:/Fastkirana/docs/verification/2026-10-19-r3-flutter-targeted.log), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-19-r3-flutter.log), [interruption record](D:/Fastkirana/docs/verification/2026-10-19-r3-flutter-interruption.json), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-19-r3-dart-analysis.log).

The full-suite interruption is not a completed test failure count or a green result. Only the owned verification process tree was stopped; the targeted reproduction then completed and failed the relevant acceptance assertion.

## Previous findings: verified closed

- **Mixed invalid replacement:** a valid quantity-1 line plus an unknown product now returns **400**, retaining the original quantity **3**. The new existing Python regression additionally covers blank IDs, all-invalid input and explicit empty-cart clearing.
- **Canonical IDs:** the actual mobile repository sends `prod_1`, `sku_cow_milk` and `item_123` unchanged, with no inferred variant. All three acceptance tests pass. The server exact-ID `item_123` control also passes.
- **Original phone-spoofing bypass:** anonymous phone requests do not return victim items or modify their cart/store assignment. JWT-authenticated-owner and guest/exact/encoded controls work.
- Completion replay, cart hydration, failed-write rollback and controlled checkout-provider disposal checks pass in the focused run.

## Remaining P2 — Test-environment gate disables connectivity subscription and hangs teardown

At [app_connectivity.dart:57](D:/Fastkirana/fastkirana_flutter/lib/core/utils/app_connectivity.dart:57), the constructor checks whether the binding runtime type contains `Test`. The entire event subscription is inside `if (!isTestEnv)`, including a caller-supplied `connectionChanges` stream.

The existing [app_connectivity_test.dart:80](D:/Fastkirana/fastkirana_flutter/test/unit/app_connectivity_test.dart:80) passes a `StreamController` and registers `events.close` for teardown. Because no listener is installed, that close future remains pending. The full serial suite stopped advancing on `Brief network drop does not flash offline or trigger recovery` after the preceding 99 completed tests.

A separate bounded probe reproduces the mechanism without hanging its own teardown:

```text
Injected stream has listener: false
Stream close completed before cleanup listener: false
After adding a temporary drain listener: close completes
Acceptance assertion requiring a subscription: FAILED
```

The temporary drain exists only in the review probe to clean up safely. It does not alter the application or the existing test. The demonstrated regression concerns execution under the test binding and the validity/completion of the test suite; it is not a demonstrated live-device connectivity outage.

**Fix:** preserve subscriptions to injected connectivity streams regardless of test binding. Replace runtime-type test special cases with explicit dependency/configuration control for startup probes, polling and lifecycle observation. In the debug cancellation test, override the connectivity provider or inject controlled dependencies instead of disabling application event handling for all tests. Do not skip the existing connectivity tests to get a green result.

**Acceptance:** the bounded subscription test passes, the existing connectivity unit file completes including brief-drop/stale-probe controls, and the complete serial Flutter suite finishes. Keep all three canonical-ID checks and invalid-cart-preservation controls passing.

## Scope

Python uses `tests/ --ignore=tests/test_migration_full.py`, dummy credentials, disabled dotenv and blocked external sockets. The excluded module is not sufficiently isolated from gateway/KOT actions. Database probes use isolated SQLite; Flutter HTTP/native/storage dependencies are mocked. The pending-payment cancellation debug test passed before the full-suite stall, but that does not certify every paid/failed/restart/device path. New runtime-test guards in payment code also limit what widget tests exercise compared with production.

No production database, gateway, Redis, notifications, printing, credential or deployment actions were performed. Real PostgreSQL concurrency/load and physical-device timing were not verified. Node/TypeScript and graph freshness were not rerun for this revision. The temporary Flutter review file was removed after execution.

Review sources: [ASGI probe](D:/Fastkirana/docs/verification/cart_security_recheck_2026_10_19_r3.py), [Flutter assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_19_r3_test.dart), [isolated suite runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_19_r3.py). Historical comparison: [revision 2](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-19_R2.md).
