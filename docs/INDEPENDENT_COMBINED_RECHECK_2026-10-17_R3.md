# FastKirana independent combined recheck — 17 October 2026, revision 3

**Decision: the tested Flutter failures are fixed, but admin order status updates currently crash. Two additional backend defects need correction.**

Reviewed `f04f2a81` **plus the current uncommitted Python/Dart changes**. This is a review of that working snapshot, not of the commit alone. The seven monitored source/test files stayed unchanged during verification; hashes are retained in the [verification summary](D:/Fastkirana/docs/verification/2026-10-17-r3-verification-summary.json). Application source and existing tests were not edited during this review.

## Fresh verification

| Check | Result |
| --- | --- |
| Isolated Python suite | **234 passed**, 0 failed/errors/skipped; 258 warnings |
| Full Flutter suite | **300 passed**, 0 failed; previously 299 passed / 1 failed |
| Targeted Flutter checks | **10 passed**: seven review assertions plus three existing offline-cart tests |
| Dart analysis: eight checkout/cart/connectivity files | **No issues**, exit 0 |
| Backend review probes | **21 recorded observations**, including reproduced defects; these are not 21 passing acceptance tests |

Python scope is `tests/ --ignore=tests/test_migration_full.py`: in-memory SQLite, dummy credentials, dotenv disabled, external sockets blocked. The excluded migration module is not sufficiently isolated from gateway/KOT operations. Backend probes execute real router functions with fake ORM/cache/task dependencies. Two inventory probes execute the exact currently unreachable approval body separately and are explicitly labelled below. Flutter review HTTP/native/storage dependencies are mocked. Real PostgreSQL locking, production gateway/device lifecycle and deployment were not verified.

Next.js unit tests (**147 passed**) and TypeScript (**exit 0**) are the preceding R2 results, **not fresh R3 runs**; current application changes affect Python and Dart. No production database, Redis, gateway, notification, print or deployment action was performed.

Evidence: [Python results](D:/Fastkirana/docs/verification/2026-10-17-r3-python-results.json), [Flutter full log](D:/Fastkirana/docs/verification/2026-10-17-r3-flutter.log), [targeted Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r3-flutter-targeted.log), [Dart analysis](D:/Fastkirana/docs/verification/2026-10-17-r3-dart-analysis.log), [backend observations](D:/Fastkirana/docs/verification/2026-10-17-r3-probes.json).

## What is now verified fixed

| Previous issue | Current execution result |
| --- | --- |
| Encoded variant accepted raw client price | The previous `review-product_Small` / client ₹1 case now quotes and recovers the catalog ₹100 line. Unknown product and nonexistent variant controls return 400. A different resolver ambiguity remains below. |
| Coupon/category and accepted-line integrity | Eligible 20% coupon gives ₹80 on a ₹100 line; forged category gives ₹100. Client price ₹1 cannot replace a known ₹100 line. Accepted ₹100 survives a later catalog change to ₹120. |
| Concurrent Flutter completion | Two callbacks for one order subtract once: quantity **3 → 2**. Persisted acknowledgement control remains **3 → 3**. Assertions check the intended quantities. |
| Offline hydration | Previously failing quantity-2 existing test passes. Delayed hydration retains old A + new B; clear stays empty in UI/local/server. Delayed pending-key resolution now synchronizes both items with `version=ack=1`. |
| Legitimate admin SSE | ORM enum `Role.ADMIN` is accepted: **200**. Owner/rider controls remain 200; blocked token is 401 and demoted token is 403. |
| Replacement draft failure controls | Both false-return and thrown-error second writes retain the first accepted draft. |

Manual approval is intentional: online recovery remains **PAID + ADMIN_PENDING**, with no automatic KOT or inventory deduction. Pending status itself is not a defect. The transition to an approved order must perform correct inventory accounting.

## 1. P1 — Every valid admin status update evaluates a missing enum member

[admin_extended.py:793](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:793) evaluates `OrderStatus.PREPARING` while constructing the active-status list. [models.py:28](D:/Fastkirana/fastapi-backend/models.py:28) has no such member. Python evaluates the list before checking membership or the stock marker, so this also breaks cancellation and already-deducted orders.

Executing actual paid recovery followed by the actual authorized admin handler reproduced:

```text
ADMIN_PENDING -> CONFIRMED: AttributeError, no stock deduction
ADMIN_PENDING -> PACKED:    AttributeError, no stock deduction
ADMIN_PENDING -> CANCELLED: AttributeError, no stock restoration
Error: type object 'OrderStatus' has no attribute 'PREPARING'
```

These are handler exceptions; the probe did not measure an HTTP response through the full ASGI stack. The exception occurs before the handler's commit. Green existing tests do not exercise this new path sufficiently.

**Fix first:** align the status list with the supported state model. Add actual admin-route regression tests for supported transitions, including normal already-deducted orders, recovered pending orders and cancellation. Do not add an enum value solely to silence this error unless the whole workflow supports it.

## 2. P1 — Approval validates duplicate lines separately, allowing overselling after issue 1 is fixed

At [admin_extended.py:804](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:804), each item checks the same pre-deduction product/store stock. Actual deductions start only at [line 861](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:861). Stock is then clamped to zero, concealing excess demand.

The actual quote → intent → recovery flow accepts two quantity-1 lines when product/store stock is 1, producing a paid `ADMIN_PENDING` order for two units. Executing the **exact approval inventory body separately** records two `-1` stock logs and a success marker with stock ending at zero. Correct behavior is rejection of total demand 2 against stock 1. Single-line control correctly reduces stock 2 → 1.

**Scope distinction:** the full admin endpoint cannot reach this body today because of issue 1. This is a demonstrated latent inventory defect, not a claim that the currently crashing endpoint successfully oversells.

**Fix:** aggregate all demand by product and normalized variant, plus total demand per product/store pool, before validating and mutating locked inventory. Reject insufficient stock rather than hiding it with `max(0, ...)`. Preserve exactly-once deduction/restoration across approvals and cancellations. Lock the order before checking its deduction state; the initial order select currently has no row lock.

**Acceptance:** duplicate SKU lines and different variants sharing the last store unit cannot exceed stock; repeated/concurrent approval deducts once; cancellation restores only a committed deduction. Verify competing approvals using independent PostgreSQL transactions.

## 3. P2 — Encoded IDs can resolve to a different catalog product

[cashfree_router.py:265](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:265) tries the prefix before the first underscore before the longer base before the last underscore. When catalog IDs overlap, it silently chooses the shorter product.

Reproduced fixture:

```text
Catalog prod_1 / Small: ₹100
Catalog prod   / Small: ₹1
Request prod_1_Small, selectedVariant=Small
Actual canonical/recovered product: prod, quote and total ₹1
Exact-ID control prod_1 + Small: product prod_1, total ₹100
```

This is a **wrong-product resolution**: the probe persisted the cheap product, not the expensive product at a discounted price. It requires overlapping IDs and the encoded-ID input. Exact IDs work in the control.

**Fix:** use the exact canonical product ID plus a separate variant everywhere possible. For supported legacy encoded inputs, resolve against valid complete product/variant combinations and reject ambiguous inputs; a first-underscore split is unsafe. Add regression fixtures with overlapping IDs and underscores in variant names.

## Antigravity implementation order

1. Fix the missing enum reference and cover actual admin status transitions.
2. Correct approval demand aggregation, order locking and deduction/restoration idempotency; test insufficient stock and retries.
3. Replace ambiguous legacy product-ID resolution and verify quote/intent/recovery preserve the same canonical SKU.
4. Rerun the isolated Python and Flutter suites, then the new route-level regressions and PostgreSQL concurrency checks.

Retain the verified Flutter, quote and SSE fixes. The old stock-deduction issue is **not yet closed end to end**: inventory logic now exists, but crashes before it runs and contains the aggregation defect above. This review closes the executed old Flutter cases, not every possible storage-failure or process-crash scenario.

Historical carry-forward: the R2 backend replacement-cart fallback concerned a currently inactive recovery cleanup branch; it was not retested or promoted to a current active defect here. Earlier Redis/FCM fixes are unchanged; historical credential revocation remains externally unverified. See [R2](D:/Fastkirana/docs/INDEPENDENT_COMBINED_RECHECK_2026-10-17_R2.md) for those older evidence boundaries.

Reproducible review sources: [backend probes](D:/Fastkirana/docs/verification/recheck_2026_10_17_r3.py), [offline suite runner](D:/Fastkirana/docs/verification/run_python_recheck_2026_10_17_r3.py), [Flutter review assertions](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_17_r3_test.dart). The temporary Flutter test copy was removed after its successful run.
