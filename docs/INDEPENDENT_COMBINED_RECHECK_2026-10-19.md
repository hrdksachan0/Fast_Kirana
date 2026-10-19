# FastKirana / FastMinute independent recheck — 19 October 2026

**The 17 October stock/payment fixes still pass, but the latest cart changes reintroduce an authentication bypass and product-ID corruption. The full Flutter suite is failing.**

Reviewed HEAD `66b1f4a9` plus current uncommitted Python, Dart and Next.js route changes. This report concerns payment, cart, authorization and checkout behavior; visual branding/assets and the generated graph were not audited. Application source and existing tests were not edited during this review. [Verification summary and source hashes](D:/Fastkirana/docs/verification/2026-10-19-verification-summary.json).

## Verified results

| Check | Result |
| --- | --- |
| Isolated Python suite | **239 passed**, 0 failed/errors/skipped; 337 warnings |
| Full Flutter suite | **302 passed, 1 failed**, exit 1 |
| Node unit suite | **147 passed**, 21 suites, exit 0 |
| TypeScript `--noEmit --incremental false` | **Exit 0**, no errors |
| Dart analysis, 13 changed/related files | **No issues**, exit 0 |
| Focused Flutter: 14 review assertions + 6 existing offline-cart tests | **19 passed, 1 failed**; failure is the new canonical-product-ID regression |
| Previous backend controls | **34 observations**, exit 0; includes real isolated SQLite missing-variant approval/replay/cancellation assertions |
| New cart security/product probes | Five observations using actual ASGI requests and isolated SQLite, reproduced through the full application and isolated cart-router app |

The Python scope is `tests/ --ignore=tests/test_migration_full.py`, with dummy credentials, disabled dotenv and external sockets blocked. The excluded migration module is not sufficiently isolated from gateway/KOT actions. Flutter HTTP/native/storage dependencies are mocked. No production database, gateway, Redis, notification, printing, deployment or credential action was performed. Real PostgreSQL concurrency and physical-device lifecycle were not tested.

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-19-python-results.json), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-19-flutter.log), [Node log](D:/Fastkirana/docs/verification/2026-10-19-node.log), [TypeScript output](D:/Fastkirana/docs/verification/2026-10-19-typecheck.log), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-19-dart-analysis.log), [stock/payment controls](D:/Fastkirana/docs/verification/2026-10-19-baseline-probes.json), [cart security observations](D:/Fastkirana/docs/verification/2026-10-19-cart-security.json). The TypeScript log is empty on success; exit 0 is recorded in the verification summary.

## 1. P1 — An unverified phone selects and modifies another user's cart

The new fallback at [cart.py:106](D:/Fastkirana/fastapi-backend/routers/cart.py:106) and [cart.py:258](D:/Fastkirana/fastapi-backend/routers/cart.py:258) queries an existing user by caller-supplied phone when authentication produced no user. It then treats the matched database ID as the caller. No token, session or internal secret is required. The sync path also changes that user's `assignedStoreId` at [line 274](D:/Fastkirana/fastapi-backend/routers/cart.py:274).

Actual full-app ASGI requests against a seeded, isolated SQLite database reproduced:

```text
Anonymous GET without phone:             200, empty cart (control)
Anonymous GET with victim x-user-phone:  200, victim cart + quantity 3
Anonymous POST with victim userPhone,
  items=[], storeId=review-other-store:  200, victim cart cleared,
                                        victim assignedStoreId changed
```

The probe sent no authentication or internal-service credential and did not override authentication. The tenant assignment result was demonstrated on a USER fixture; this is not a demonstrated admin-account takeover. The same behavior was confirmed in an isolated cart-router ASGI app.

**Fix first:** derive existing-account ownership exclusively from verified authentication or a verified internal caller acting on a separately authorized identity. A phone number is identification data, not proof of ownership. Retain device-scoped guest carts and merge into a registered user's cart only after authentication. Never change an existing user's store assignment from an unauthenticated cart payload.

**Acceptance:** arbitrary full/partial phones cannot read, clear or replace another user's cart or modify user assignment; blocked/demoted credentials cannot regain identity through this fallback. Authenticated-owner and authorized guest-merge controls must still work.

## 2. P2 — Cart sync truncates canonical product IDs and can select another SKU

Mobile now unconditionally uses `rawId.split('_').first` at [cart_repository.dart:75](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:75). A legitimate catalog ID `prod_1` is therefore sent as product `prod`, with the remainder inferred as a variant. Supplying a separate explicit variant still does not preserve the complete product ID.

The Python cart resolver independently takes the first underscore prefix at [cart.py:341](D:/Fastkirana/fastapi-backend/routers/cart.py:341). Real ASGI + SQLite controls show:

```text
Catalog contains prod_1 / Small and a different prod / Small
POST encoded prod_1_Small + selectedVariant Small
GET cart: productId prod, variant Small       (wrong SKU)
POST exact prod_1 + selectedVariant Small
GET cart: productId prod_1, variant Small     (server exact-ID control)
```

This is separate from the payment quote resolver: its overlapping-ID and underscore-variant controls still pass. A successful cart-sync response can acknowledge the wrong item or discard an unresolvable item after the old cart has been deleted.

The actual mobile repository probe also reproduces the corruption: input canonical `prod_1` posts `productId=prod`, `selectedVariant=1`, and reports sync success. Its acceptance assertion fails. This is the sole failing test in the corrected focused Flutter run; all six existing offline-cart tests pass.

**Fix:** send the complete canonical ID and the separate variant from mobile. Reuse one catalog-backed legacy resolver on the server, preserving exact IDs and rejecting ambiguity. Validate the complete replacement before deleting existing items; reject invalid input instead of silently acknowledging a reduced/empty cart.

**Acceptance:** exact IDs containing underscores survive mobile → cart → quote unchanged; encoded legacy IDs resolve consistently with payment creation; ambiguous/unknown inputs cannot erase or silently substitute the cart.

## Existing Flutter suite failure

The existing `Checkout waits for API verification, ignores duplicate taps, and stops before payment when unreachable` test fails at [checkout_connectivity_guard_test.dart:53](D:/Fastkirana/fastkirana_flutter/test/widgets/checkout_connectivity_guard_test.dart:53): expected placing-order state `true`, actual `false`.

The new checkout path skips `checkConnection()` and permits unknown transport state to proceed. This conflicts with the existing test contract. Confirm the intended offline/captive-network behavior and align implementation plus meaningful tests; do not claim a clean Flutter suite or simply delete the assertion. The independent cart/security findings above do not depend on this policy choice.

## Background checkout control

The new completion method intentionally returns before its background cleanup finishes. Old concurrent-completion assertions were adapted to wait for the expected outcome while retaining the provider subscription. They pass, as do persisted acknowledgement, journal replay, hydration and failed-write controls.

A separate controlled test delayed local order persistence, disposed the auto-disposed checkout provider, then released the write. Product A correctly changed 3 → 2, the applied marker was written and the accepted draft was cleared. **Cleanup loss was not reproduced in this provider-disposal test**, so it is not reported as another defect. This does not certify every process-kill/device failure path.

The first review-test run contained a syntax error in the newly written fixture, which was corrected. The reported focused counts refer to the compiled rerun, not that fixture error. The temporary test was removed after execution. [Focused log](D:/Fastkirana/docs/verification/2026-10-19-flutter-targeted.log).

## Retained closures and scope

The previous missing/default-variant flow still selects `Small`, deducts product/variant/store stock 2 → 1 exactly once, and restores each pool to 2 exactly once on cancellation. Prior duplicate-demand, unknown-variant, encoded-payment-ID, coupon/accepted-price and SSE controls continue to pass. Manual PAID + ADMIN_PENDING recovery remains intentional.

The 22 monitored source/test files stayed unchanged during verification, and the temporary review test was removed. The review does not certify the new geocoding fallback, rider financial reports, notification background lifecycle, real device rendering or branding. Historical credential revocation and older dormant-cleanup observations retain their previous evidence limits. See [17 October R5](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-17_R5.md) for that baseline.

Review sources: [stock/payment baseline](D:/Fastkirana/docs/verification/recheck_2026_10_19_baseline.py), [ASGI security probe](D:/Fastkirana/docs/verification/cart_security_recheck_2026_10_19.py), [Flutter review assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_19_test.dart), [offline Python suite runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_19.py).
