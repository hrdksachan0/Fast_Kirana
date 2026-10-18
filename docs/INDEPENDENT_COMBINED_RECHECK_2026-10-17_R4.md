# FastKirana independent recheck — 17 October 2026, revision 4

**The three R3 cases now pass. One variant inventory defect remains: a paid order without a selected variant can be confirmed without deducting product/variant stock.**

Reviewed HEAD `f04f2a81` plus the current uncommitted Python/Dart fixes. Application source and existing tests were not edited. Source hashes and final verification counts are in the [verification summary](D:/Fastkirana/docs/verification/2026-10-17-r4-verification-summary.json).

## Fresh verification

| Check | Result |
| --- | --- |
| Isolated Python suite | **237 passed**, zero failures/errors/skips; 296 warnings |
| Full Flutter suite | **300 passed**, zero failures |
| Focused Flutter run: nine review checks + three existing offline tests | **11 passed, 1 failed**; all nine review checks passed |
| Standalone rerun of the existing offline-cart module | **3 passed**, zero failures |
| Targeted Dart analysis: eight checkout/cart/connectivity files | **No issues**, exit 0 |
| Backend probes | **26 recorded observations**, including the defect below; these are not all passing acceptance tests |

Python runs `tests/ --ignore=tests/test_migration_full.py`, with SQLite, dummy credentials, disabled dotenv and blocked external sockets. The excluded module is not sufficiently isolated from gateway/KOT operations. Backend probes use real application functions with fake ORM/cache/task dependencies, plus one **actual isolated in-memory SQLite quote → recovery → approval commit**. Flutter uses mocked HTTP/native/storage dependencies. PostgreSQL concurrency and real gateway/device behavior were not exercised. No production database, gateway, Redis, notification, printing or deployment action was performed.

Next.js unit/typecheck results remain historical R2 evidence, not fresh R4 runs. Current application edits are Python and Dart.

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-17-r4-python-results.json), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r4-flutter.log), [targeted Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r4-flutter-targeted.log), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-17-r4-dart-analysis.log), [backend results](D:/Fastkirana/docs/verification/2026-10-17-r4-probes.json).

The focused run failed the existing `Online Recovery: syncPendingCart flushes local cart to server and clears pending flag` assertion at [offline_cart_sync_test.dart:117](D:/Fastkirana/fastkirana_flutter/test/unit/offline_cart_sync_test.dart:117): expected one sync call, observed two. The same unchanged module then passed standalone, as did the full suite. Preserve this as an intermittent test/sync-count observation, not an established production data-loss defect. Investigate notifier disposal, outstanding debounce work and deterministic waiting rather than merely relaxing the assertion. [Standalone rerun evidence](D:/Fastkirana/docs/verification/2026-10-17-r4-flutter-offline-rerun.log).

The nine review checks verified concurrent completion subtracts once (3 → 2), persisted acknowledgement and journal-only replay skip subtraction (3 → 3), failed draft replacement retains the first draft, delayed hydration retains both items, clear remains empty, pending-key delay retains the new edit, and clear-then-add retains only the newly added item. The temporary review test was removed afterward.

## R3 findings: current status

| Previous finding | Executed result |
| --- | --- |
| Missing `OrderStatus.PREPARING` crashes admin updates | **Closed for tested paths.** Normal confirmation, repeated confirmation, packing, cancellation and repeated cancellation complete. `PREPARING` aliases to `CONFIRMED`. Product/store stock goes 2 → 1, remains 1 on repeat/pack, returns to 2 on cancellation and stays 2 on repeat cancellation. |
| Duplicate lines oversell during approval | **Old cases closed.** Two units against one product/store unit return 400 before commit. Separate controls check product shortage, mixed variants sharing one store unit, and case/whitespace-normalized duplicate variants. Valid selected-variant approval/pack/cancellation deducts/restores correctly. Order `FOR UPDATE` and sorted product locking are present; real concurrent PostgreSQL behavior remains untested. |
| Overlapping encoded IDs select the wrong product | **Closed for tested inputs.** `prod_1_Small` with selected `Small` now quotes ₹100 and recovers `prod_1`, matching the exact-ID control. A genuinely ambiguous input without disambiguating variant returns 400. Variant name `Small_Pack` resolves correctly. |

Other executed controls retain catalog pricing, eligible coupon ₹80, forged-category rejection, accepted line price after catalog change, and SSE owner/rider/admin access with blocked/demoted-token denial. Manual **PAID + ADMIN_PENDING** recovery remains intentional.

Three new existing-suite Python tests exercise admin stock lifecycle, duplicate-line rejection and encoded ID recovery. The encoded-ID test's short/long IDs are not actually prefixes of one another; the independent probe additionally uses the original truly overlapping `prod` / `prod_1` fixture.

## Remaining P1 — Missing variant permits approval without product deduction

The quote at [cashfree_router.py:329](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:329) accepts a catalog product with a nonempty variants list when `selectedVariant` is absent, using the base product price/stock. Recovery retains the null selection.

Approval groups that demand under `(productId, None)`. Its validation allows the product-stock fallback, but mutation at [admin_extended.py:903](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:903) always takes the variant-list branch. At [line 908](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:908), each named variant gets demand zero, so no variant stock is removed. Product stock is recomputed from unchanged variants, store inventory is deducted, and `[STOCK_DEDUCTED]` is recorded.

Reproduced through actual quote, recovery and admin functions against **real isolated SQLite**, then reloaded committed inventory:

```text
Catalog: base price ₹100, product stock 2, Small variant stock 2, store stock 2
Request: quantity 1, selectedVariant omitted
Quote: ₹100; recovered order: PAID + ADMIN_PENDING
Admin confirmation: succeeds, status CONFIRMED, marker STOCK_DEDUCTED
Committed product stock: 2  (unchanged)
Committed Small stock:   2  (unchanged)
Committed store stock:   1
```

This is an active inventory inconsistency, not the earlier unreachable code-body case. Store stock still limits the tested store pool; this probe does not establish unlimited sales or PostgreSQL race behavior. Repeated approval sees the marker and cannot repair the missed product deduction.

**Required fix:** define one policy for products with variants. Reject missing/unknown variants before creating a payment session, or resolve an explicit valid default and persist it canonically. Apply the same rule during approval of existing pending orders. If a separate base SKU is supported, give its stock a separate explicit representation and validate/deduct/restore that pool consistently. Do not mark stock deducted until every required pool was actually updated.

**Acceptance:** this exact missing-variant flow is rejected before payment or deducts a defined canonical variant exactly once. Add real ORM tests covering missing, blank and invalid selections, approval replay, cancellation, duplicate demand and valid selected-variant controls. Keep the three verified R3 fixes.

## Evidence limits carried forward

The new Flutter applied-delta journal needs crash/storage-failure coverage beyond successful replay; this review does not certify atomic cart/delta persistence. PostgreSQL locking and real device/payment lifecycle remain separate validation work. Earlier Redis/FCM changes are unchanged, and historical credential revocation remains externally unverified. Older dormant cart-cleanup observations are retained in [R2](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-17_R2.md), not promoted to newly reproduced defects here.

Review sources: [backend probes](D:/Fastkirana/docs/verification/recheck_2026_10_17_r4.py), [isolated Python runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_17_r4.py), [Flutter assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_17_r4_test.dart).
