# FastKirana independent recheck — 17 October 2026, revision 5

**The R4 missing-variant inventory defect is fixed in the executed cases. No new blocking defect was reproduced within this review scope.** The earlier R3 fixes continue to pass their controls.

Reviewed HEAD `f04f2a81` plus the latest uncommitted Python/Dart changes. Ten monitored application/test files stayed unchanged during verification. Application source and existing tests were not edited by this review. [Verification summary and hashes](D:/Fastkirana/docs/verification/2026-10-17-r5-verification-summary.json).

## Fresh verification

| Check | Result |
| --- | --- |
| Isolated Python suite | **239 passed**, 0 failed/errors/skipped; 335 warnings |
| Full Flutter suite | **301 passed**, 0 failed |
| Focused Flutter: 12 review assertions + 4 existing offline-cart tests | **16 passed**, 0 failed |
| Dart analysis: eight checkout/cart/connectivity files | **No issues**, exit 0 |
| Backend probes | **34 recorded observations**, including expected rejection controls and explicit SQLite lifecycle assertions; exit 0 |

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-17-r5-python-results.json), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r5-flutter.log), [focused Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r5-flutter-targeted.log), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-17-r5-dart-analysis.log), [backend observations](D:/Fastkirana/docs/verification/2026-10-17-r5-probes.json).

## Missing-variant stock lifecycle: verified closed

Payment creation now resolves missing/blank variant selection to the first named catalog variant and stores the selection in the accepted canonical line. Admin approval also normalizes existing pending lines and rejects unknown selections before stock mutation.

The exact previous failing quote → recovery → approval path was repeated against **actual isolated in-memory SQLite**, with committed inventory reloaded:

| Step | Product stock | Small variant stock | Store stock |
| --- | --- | --- | --- |
| Initial | 2 | 2 | 2 |
| Confirm paid recovered order, initially submitted without a variant | 1 | 1 | 1 |
| Repeat confirmation | 1 | 1 | 1 |
| Pack | 1 | 1 | 1 |
| Cancel | 2 | 2 | 2 |
| Repeat cancellation | 2 | 2 | 2 |

The persisted line contains `selectedVariant=Small`. Additional controls establish:

- Default variant price ₹120 overrides base price ₹100 and client amount ₹1; accepted quote/line use ₹120.
- Blank selection resolves to `Small`; insufficient default-variant stock returns 400.
- Existing null/blank pending lines deduct and restore correctly; unknown legacy variants return 400 without a stock commit.
- Missing selection and explicit `Small` lines aggregate into one demand pool, rejecting combined demand 2 against variant stock 1.
- Prior duplicate-line, mixed-variant store-pool, admin status, encoded-ID and SSE controls retain their expected results.

Manual **PAID + ADMIN_PENDING** recovery remains intentional. Inventory is deducted at approval, not automatically on payment recovery.

## Flutter persistence and replay

The cart envelope now stores remaining items and the applied order ID in the same preference value. Executed failure controls confirmed:

- When the separate journal write returns false, the reloaded envelope retains both the order marker and correct remaining quantity: 3 → 2 and 1 → 0.
- When the cart envelope write returns false, `removeDraftItems` throws, UI/local quantity stays 3, and no applied-order marker is committed.
- Concurrent completion subtracts once, 3 → 2; persisted acknowledgement and journal-only replay leave 3 unchanged.
- Delayed hydration, clear, pending-key delay and clear-then-add retain the expected cart contents.

The existing offline-sync count assertion that intermittently failed in R4 passed in both current full and focused runs. **That failure was not reproduced this time; this is not proof that all timing-related flakiness is eliminated.** The existing test now also covers successful cart/delta persistence. The temporary review test was removed after execution.

## Scope and remaining validation boundaries

The Python command is `tests/ --ignore=tests/test_migration_full.py`, using SQLite, dummy credentials, disabled dotenv and blocked external sockets. The excluded migration module is not sufficiently isolated from gateway/KOT actions. Probes execute real application functions with fake ORM/cache/task dependencies, plus the real isolated SQLite lifecycle above. Flutter HTTP/native/storage dependencies are mocked. Failed-write tests cover returned failures, not an actual power loss or every possible storage/process failure.

This closes the reproduced findings in the reviewed snapshot; it does not certify production behavior outside these checks. Independent PostgreSQL concurrency/load tests and real gateway/device lifecycle were not performed. No production database, gateway, Redis, notifications, printing or deployment action was taken. Next.js unit/typecheck results remain historical R2 evidence, not fresh R5 runs. Historical credential revocation and older dormant cleanup observations retain their previous evidence limits.

Review sources: [backend probes](D:/Fastkirana/docs/verification/recheck_2026_10_17_r5.py), [isolated Python runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_17_r5.py), [Flutter assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_17_r5_test.dart). Historical comparison: [R4](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-17_R4.md).
