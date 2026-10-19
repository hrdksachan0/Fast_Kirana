# FastKirana / FastMinute independent recheck — 19 October 2026, revision 4

**The connectivity subscription hang is fixed. The final full Flutter run completed with 306 passing tests, and the isolated Python suite passed all 240 tests. One intermittent offline-cart test failure was observed earlier and remains recorded below.**

Reviewed HEAD `66b1f4a9` plus uncommitted changes. Application source and existing tests were not edited by this review. A checkout-controller change was saved externally during the first full Flutter attempt; that owned run was stopped and replaced with a fresh run. All **379 Flutter source/test files** and the **15 core monitored files** stayed unchanged across the final runs. The temporary review test was removed.

## Fresh results

| Check | Observed result |
| --- | --- |
| Isolated Python suite | **240 passed**, 0 failed/errors/skipped; exit 0; 349 warnings |
| Full Flutter suite, serial execution | **306 passed**, 0 failed; exit 0 |
| Final focused run: 17 independent checks, 7 existing offline-cart tests, 10 existing connectivity tests | **34 passed**, 0 failed; exit 0 |
| Existing offline-cart file, two further isolated reruns | **7 passed** in each run; both exit 0 |
| Actual full-app ASGI + isolated SQLite cart probes | Ten observations; **all eight explicit acceptance checks passed** |
| Dart analysis, seven related files | Exit 0; **0 errors/warnings, 10 informational diagnostics**, all in the debug test |

Evidence: [machine-readable summary](D:/Fastkirana/docs/verification/2026-10-19-r4-verification-summary.json), [Python results](D:/Fastkirana/docs/verification/2026-10-19-r4-python-results.json), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-19-r4-flutter-final.log), [focused log](D:/Fastkirana/docs/verification/2026-10-19-r4-flutter-focused-final.log), [offline rerun 1](D:/Fastkirana/docs/verification/2026-10-19-r4-offline-rerun-1.log), [offline rerun 2](D:/Fastkirana/docs/verification/2026-10-19-r4-offline-rerun-2.log), [cart observations](D:/Fastkirana/docs/verification/2026-10-19-r4-cart-security.json), [cart acceptance checks](D:/Fastkirana/docs/verification/2026-10-19-r4-cart-checks.json), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-19-r4-dart-analysis-final.log).

## Verified closures

- **Connectivity teardown:** [app_connectivity.dart:61](D:/Fastkirana/fastkirana_flutter/lib/core/utils/app_connectivity.dart:61) now subscribes to an explicitly injected stream under the test binding. The bounded probe reports `subscribed: true` and `closeStalledWithoutDrain: false`. All ten existing connectivity tests finish, including brief network drops, stale successful probes, timeouts and shared manual retries. The full suite completes past the former hang point.
- **Cart authorization:** anonymous requests using a victim phone do not expose their cart or alter their cart/store assignment. Authenticated-owner and guest controls succeed.
- **Replacement validation:** a mixed valid/unknown-product request returns **400** and retains the original quantity **3**. All-invalid input is rejected; an explicit empty owner cart still clears successfully.
- **Canonical SKU preservation:** the mobile repository sends `prod_1`, `sku_cow_milk` and `item_123` unchanged. The backend exact-ID `item_123` control also passes.
- **Recovery and persistence controls:** draft replacement failures, completion replay, cart hydration, failed-write rollback and checkout-provider disposal checks pass. The existing pending-payment cancellation test retains the pending reference and accepted draft without adding a cancellation marker.

## Open test reliability note

The [first focused run](D:/Fastkirana/docs/verification/2026-10-19-r4-flutter-focused.log) completed **33 passed, 1 failed**. At [offline_cart_sync_test.dart:119](D:/Fastkirana/fastkirana_flutter/test/unit/offline_cart_sync_test.dart:119), `Online Recovery` expected one successful cart POST but observed two. This same test subsequently passed in the full suite, the final focused run and both isolated reruns, without changes to the cart implementation or this test file.

This is an observed intermittent verification failure; a production duplicate-order defect was not demonstrated. The fixture uses a shared request counter/network flag, fixed 350 ms waits and notifiers without registered disposal. Those are plausible sources of asynchronous overlap, but the exact cause of the extra POST has not been isolated.

**Antigravity follow-up:** record request payloads/instance ownership to distinguish a repeated current-cart sync from a late previous-test callback; dispose each notifier and close each mock client; synchronize on explicit completion instead of elapsed time. Preserve the one-request assertion while investigating. A later passing run does not erase the earlier failure.

## Verification limits

Python ran with isolated SQLite, dummy credentials, dotenv disabled and external networking blocked. The unmocked `test_migration_full.py` gateway/KOT suite was excluded. SQLite execution does not establish PostgreSQL row-lock behavior. Flutter tests exercise mocked/test-binding paths; several production branches are explicitly disabled under that binding. Live payment settlement, notifications, printing, deployment, Next.js/TypeScript checks and graph rebuilding were not performed in this revision.

The [earlier interrupted full run](D:/Fastkirana/docs/verification/2026-10-19-r4-flutter-source-change-interruption.json) is excluded from completed-suite counts. The final green results verify the reviewed fixes within the stated scope; they do not establish that the entire deployed system is bug-free.
