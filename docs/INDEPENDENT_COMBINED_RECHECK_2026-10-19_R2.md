# FastKirana / FastMinute independent recheck — 19 October 2026, revision 2

The original phone-ownership bypass and tested `prod_1` cart corruption are fixed. Replacement validation still silently accepts mixed valid/invalid requests, and mobile still rewrites canonical IDs beginning with `item_`. Passing the existing suites does not establish a bug-free production system.

Reviewed HEAD `66b1f4a9` plus the latest uncommitted fixes. Application source and existing tests were not edited by this review. [Verification summary](D:/Fastkirana/docs/verification/2026-10-19-r2-verification-summary.json).

## Fresh verification

| Check | Independently observed result |
| --- | --- |
| Isolated Python suite | **239 passed**, 0 failed/errors/skipped; 337 warnings |
| Full Flutter suite, `--concurrency=1` | **304 passed**, 0 failed, exit 0 |
| Dart analysis: cart repository, checkout controller and revised connectivity tests | **No issues**, exit 0 |
| Extra focused Flutter run: 16 review assertions + 6 existing offline-cart tests | **21 passed, 1 failed**, exit 1; failure is canonical `item_123` preservation |
| Actual full-app ASGI + SQLite cart probes | **10 observations**, including successful controls and the mixed-invalid finding below |

The existing-suite green counts in the supplied matrix are confirmed for these scopes. They do not include the additional edge-case acceptance assertions written for this independent review.

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-19-r2-python-results.json), [full Flutter serial log](D:/Fastkirana/docs/verification/2026-10-19-r2-flutter.log), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-19-r2-dart-analysis.log), [focused Flutter log](D:/Fastkirana/docs/verification/2026-10-19-r2-flutter-targeted.log).

## Verified closures

- An anonymous `x-user-phone` request returns no victim items. The previous phone-body POST no longer clears the victim's cart or changes their store assignment.
- A real JWT-authenticated owner can still read the seeded cart. No authentication dependency was replaced in the ASGI probe.
- Exact and encoded `prod_1` requests now retain `prod_1`; the previous shorter-product substitution is closed for that fixture.
- An entirely unknown replacement returns HTTP 400 and retains the existing quantity 3. An explicit authenticated empty replacement still clears the cart correctly.
- Both revised connectivity widget tests pass in the full suite: the offline case halts without an API order request, and the held in-flight order case ignores a duplicate tap and recovers its busy state after failure.

These observations use actual requests through the full FastAPI application against isolated SQLite, with broadcasts suppressed and external sockets blocked. [ASGI observations](D:/Fastkirana/docs/verification/2026-10-19-r2-cart-security.json).

## 1. P2 — Mixed invalid replacement still silently commits a partial cart

[cart.py:317](D:/Fastkirana/fastapi-backend/routers/cart.py:317) skips unresolved products. The new rejection at [line 332](D:/Fastkirana/fastapi-backend/routers/cart.py:332) only applies when **none** of the supplied items resolve. A partially valid payload therefore reaches the delete/insert transaction.

Actual authenticated ASGI + SQLite reproduction:

```text
Existing cart: prod_1, quantity 3
Replacement: prod_1 quantity 1 + nonexistent product quantity 1
Response: 200, success=true, itemCount=1
Committed cart: prod_1 quantity 1; invalid item silently omitted
All-invalid control: 400, original quantity 3 retained
```

The response does not identify the rejected line. Mobile treats a successful sync as acknowledged, so this does not provide an explicit partial-sync/reconciliation contract.

**Fix:** validate every submitted line before replacement and reject the whole request when any line is invalid, or implement an explicit partial-result contract that returns rejected items and reconciles the local cart. A plain successful acknowledgement with silently removed items is insufficient.

**Acceptance:** mixed known/unknown and blank-ID requests either preserve the original cart on rejection or return structured rejected-item results that the client actually handles. Retain authenticated valid replacement and explicit-clear controls.

## 2. P2 — `item_` is still stripped from a valid canonical catalog ID

[cart_repository.dart:76](D:/Fastkirana/fastkirana_flutter/lib/data/repositories/cart_repository.dart:76) replaces the old unconditional underscore split with `rawId.startsWith('item_') ? rawId.substring(5) : rawId`. This preserves `prod_1` and `sku_cow_milk`, but still changes a legitimate `productId=item_123` into `123`.

The isolated database includes a real catalog row with ID `item_123`. The server exact-ID control accepts it and returns `item_123`. A product identifier and a synthetic cart-row identifier must not be inferred from the same prefix alone. The finding is conditional on such catalog IDs; production catalog contents were not inspected.

The actual mobile repository acceptance tests confirm `prod_1` and `sku_cow_milk` are now unchanged. The additional `item_123` assertion fails: posted ID is `123`, selected variant is null, and the mocked successful response is treated as synced. A real backend without product `123` would reject it; one with that different ID could select the wrong SKU. This is not a claim that the production catalog contains either fixture product.

**Fix:** preserve `CartItem.productId` when it represents the canonical product, or resolve against the actual `Product.id`/an explicit legacy format. Do not strip a prefix solely because its spelling resembles a cart-row ID.

**Acceptance:** canonical `prod_1`, `sku_cow_milk` and `item_123` all survive mobile serialization unchanged. Test any supported synthetic-row-ID migration separately.

## Verification boundaries

The Python suite scope excludes `test_migration_full.py`, which is not sufficiently isolated from gateway/KOT operations. Database probes use SQLite, not production PostgreSQL. Device/native/network/storage dependencies in Flutter are mocked. No production database, gateway, Redis, notification, printing or deployment action was performed. No real concurrency/load, device timing or process-kill certification is implied. The revised offline widget test establishes behavior in a test pump, not a measured universal 0 ms or sub-300 ms device latency.

All 12 monitored application/test files stayed unchanged during verification. The temporary Flutter review test was removed. Existing offline-cart tests, failed-write controls, completion replay and the controlled provider-disposal cleanup case passed in the focused run.

Node/TypeScript and wider Dart results from the preceding review are historical unless explicitly rerun. Knowledge-graph artifacts were not independently rebuilt or certified for complete source coverage; graph generation is not functional/security verification.

Review sources: [ASGI probe](D:/Fastkirana/docs/verification/cart_security_recheck_2026_10_19_r2.py), [Flutter assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_19_r2_test.dart), [isolated suite runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_19_r2.py). Historical comparison: [previous review](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-19.md).
