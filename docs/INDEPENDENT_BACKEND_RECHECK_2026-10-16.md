# FastKirana independent Python backend recheck — 16 October 2026

The latest changes close the previous retry-ledger duplication case and several recovery inventory cases. Four actionable issues remain in quantity validation, variant inventory, quote/recovery pricing, and cart cleanup. A production-ready rating is not supported by the current evidence.

This report supersedes the open/closed status of the payment and inventory findings in the 15 October revision-2 report for the source snapshot below. Application source and existing tests were not edited during this review.

## Test result and scope

**228 passed, 0 failures, 0 errors, 0 skipped**, in 139.28 seconds; 250 warnings. The Redis-down concurrency regression passed. Structured results, including source hashes before and after the run, are in [2026-10-16-python-results.json](D:/Fastkirana/docs/verification/2026-10-16-python-results.json).

The run covered `tests/` except `tests/test_migration_full.py`. That file was excluded because its gateway/KOT operations are not completely isolated. The run used in-memory SQLite, dummy credentials, disabled dotenv loading, and blocked non-loopback socket connections. No live PostgreSQL, gateway, Redis, printing, notifications, or deployment was used. No Next.js, TypeScript, or Flutter checks were repeated in this Python-focused pass.

Additional probes executed current application functions or exact source blocks with fake ORM/cache/gateway/task implementations. Their results establish the code paths described below; they do not establish real PostgreSQL locking behavior or a successful live gateway transaction.

## Verified progress

| Claimed change | Current assessment |
| --- | --- |
| Canonical payment consumption key | The previous `_r123` / `_r456` separate-ledger bypass is closed. Checkout normalizes the base reference for existing-order lookup, consumption, and stored `cfOrderId`; recovery uses the same base consumption identity. |
| Recovery row locking | Product and selected-hub inventory SELECTs now use `FOR UPDATE`. Real independent-worker PostgreSQL contention remains untested. |
| Duplicate-line stock validation | Complete recovery-function mocks now quarantine two plain-product lines against stock 1, and two identical variant lines against variant stock 1. Stock remains unchanged. |
| Selected-hub inventory | A plain product with global stock 2 and hub stock 0 now remains `ADMIN_PENDING`. The variant path still has a gap described below. |
| Selective cart cleanup | Unrelated products and other explicitly selected variants remain; current quantity 5 minus ordered quantity 2 leaves 3. Default-variant and replacement-row cases still fail. |
| SQLite concurrency fix | The current local regression passes. The SQLite branch bypasses the nested savepoint; PostgreSQL retains it. The existing test and fixture were not skipped or weakened. |

Canonical references: [orders.py:1592](D:/Fastkirana/fastapi-backend/routers/orders.py:1592), [orders.py:1811](D:/Fastkirana/fastapi-backend/routers/orders.py:1811), and [cashfree_router.py:978](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:978). SQLite branch: [idempotency.py:367](D:/Fastkirana/fastapi-backend/utils/idempotency.py:367).

## P1 — Negative quantities create confirmed orders and increase inventory

Quantity parsing uses `int(value or 1)` without requiring a positive integer at [cashfree_router.py:218](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:218), [line 1142](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1142), and [line 1155](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1155). A negative subtotal also skips the positive-subtotal quote-validation block.

Executing the complete current payment-session and recovery functions with isolated mocks produced:

| Input / outcome | Value |
| --- | --- |
| Product and hub initial stock | 2 each |
| Catalog price / submitted quantity | ₹100 / -1 |
| Requested and accepted payment quote | ₹1 |
| Recovery status / persisted item quantity | `CONFIRMED` / -1 |
| Product and hub stock after recovery | 3 each |
| Persisted subtotal / miscellaneous fee | ₹1 / ₹101 |

The stock deductions subtract the negative quantity at [line 1363](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1363) and [line 1375](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1375). Clamping with `max(0, ...)` does not prevent this increase.

**Required fix:** validate and normalize every line before quote calculation, intent persistence, aggregation, recovery, or inventory mutation. Reject zero, negative, fractional, non-finite, malformed, and out-of-range quantities rather than silently defaulting them. Apply the same validation to cached and durable recovery input.

**Acceptance:** invalid quantities produce a validation error or reconciliation outcome with no order fulfillment, inventory change, or cart mutation; mixed positive/negative duplicate lines cannot cancel demand.

## P1 — Variant recovery bypasses selected-hub stock

The variant branch at [cashfree_router.py:1165](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1165) validates global variant stock. The selected-hub check is inside the alternative plain-product branch, so it is skipped for selected variants. Loading and locking the hub row does not make that check run.

Complete current recovery-function mocks reproduced:

| Input | Actual result |
| --- | --- |
| Variant stock 2; selected-hub stock 0; quantity 1 | `CONFIRMED`; global variant stock becomes 1; hub stays 0 |
| Small variant stock 1 and Large stock 1; hub stock 1; quantity 1 of each | `CONFIRMED` for 2 units; hub stock is clamped to 0 |

Hub deduction at [line 1375](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1375) hides the deficit after approval. Ordinary checkout already checks hub insufficiency at [orders.py:1989](D:/Fastkirana/fastapi-backend/routers/orders.py:1989).

**Required fix:** independently validate aggregate demand per product against the selected hub and per product/variant against variant availability, using the locked rows before approval. Define and enforce the policy for a missing hub inventory row rather than implicitly falling back to global availability.

**Acceptance:** zero-hub variant orders and combined variant demand above hub availability remain unfulfilled with unchanged inventory. Verify competing last-unit transactions using independent PostgreSQL sessions.

## P1 — Accepted quote is not preserved through recovery, and fees differ from checkout

The actual quote function accepts an active flat ₹20 coupon on a ₹100 item and returns ₹80. Executing the actual durable-intent saver confirms that it stores neither the accepted discount nor coupon/fee breakdown. The saver begins at [cashfree_router.py:68](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:68); the quote calculation is at [line 322](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:322).

Recovery recomputes the full catalog subtotal, treats paid ₹80 as underpaid at [line 1266](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1266), chooses `ADMIN_PENDING`, and constructs the order with `discount=0.0` at [line 1295](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1295). The quote and persistence results were executed with mocks; this recovery outcome is established from source inspection, not a completed runtime recovery probe for the coupon case.

There is also fee disagreement. The actual quote function and the exact ordinary-checkout fee-calculation source block produced these results under the same mocked default settings:

| ₹100 catalog subtotal | Cashfree quote | Ordinary checkout calculation |
| --- | ---: | ---: |
| DELIVERY; client omits fee fields | ₹100 | ₹130 |
| PICKUP; client supplies packaging fee ₹5 | ₹105 | ₹100 |
| PICKUP; valid flat coupon ₹20 | ₹80 | ₹80 |

Quote reads client fee values at [cashfree_router.py:295](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:295). Ordinary checkout uses server settings and pickup rules at [orders.py:1495](D:/Fastkirana/fastapi-backend/routers/orders.py:1495) and [line 1517](D:/Fastkirana/fastapi-backend/routers/orders.py:1517). Source review also found that quote coupon eligibility omits ordinary-checkout restrictions such as once-per-customer and restaurant/category/product scope. Hub price overrides are not applied by the quote/recovery catalog-price reads.

**Required fix:** use a shared server-side quote calculation, including coupon eligibility, hub prices, delivery, pickup, tip, and fees. Persist its accepted line prices and monetary breakdown in a trusted checkout intent. Checkout and recovery must validate against that accepted quote, with an explicit policy for expired quotes and later price changes.

**Acceptance:** a valid ₹80 discounted payment recovers with the correct discount and status. Delivery defaults, pickup fees, hub price overrides, coupon restrictions, and totals agree across payment creation, checkout, and recovery.

## P2 — Default-item cleanup also subtracts other cart variants

When the paid item has no selected variant, the query at [cashfree_router.py:1413](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1413) filters only by cart and product. It matches every variant of that product. The loop at [line 1418](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1418) then decrements or deletes every matching row.

Executing the exact current cleanup source block with fake rows reproduced:

- Paid default product quantity 1; current cart default 1, small 3, large 4: default is deleted, small becomes 2, and large becomes 3.
- Customer removes default and adds large quantity 1 while payment is pending: cleanup deletes the new large row.
- Removing and readding the same product/variant is also indistinguishable from the original row because no cart-item identity or revision is recorded.

Cart reads in this block are not locked. Concurrent lost updates are an additional source-level risk, not a runtime PostgreSQL reproduction in this review.

**Required fix:** require an exact normalized variant match, including the default/null variant. Tie cleanup to the accepted cart-item identity or revision, and perform the intended decrement safely against concurrent cart changes.

**Acceptance:** default purchases preserve all other variants; removing/readding an item preserves the replacement row; quantity increases preserve only the remaining quantity; concurrent edits are not overwritten.

## Additional validation limits

The suffix-intent check still contains `p_clean == clean_check` at [orders.py:1657](D:/Fastkirana/fastapi-backend/routers/orders.py:1657), where the compared values are derived identically. This does not establish the claimed strict retry-intent binding. It is not evidence that the old duplicate-consumption bypass survives: base-reference lookup and consumption now address that previous case.

The four-thread regression at [test_production_blockers_resolved.py:999](D:/Fastkirana/fastapi-backend/tests/test_production_blockers_resolved.py:999) uses shared-process synchronization and SQLite StaticPool. Its pass is useful local evidence; independent PostgreSQL worker races still require separate verification.

## Next implementation order

1. Enforce positive integer quantities at every intake and recovery boundary.
2. Check both per-variant and aggregate per-hub demand before approval or deduction.
3. Share and persist the complete accepted server quote across payment, checkout, and recovery.
4. Make cart cleanup match exact variants and accepted cart identities/revisions.
5. Add focused regression cases for the failures above, then verify last-unit and same-payment concurrency with independent PostgreSQL transactions in an isolated test database.

## Reviewed snapshot

Git HEAD at review: `b74be8ce`; working-tree Python changes were included. Source hashes remained stable through the test run and final review:

| File | SHA-256 |
| --- | --- |
| routers/cashfree_router.py | `FB3912ECEAAD63375E5A1B8134616B7FCE8E47C4BDF1217B81BC308E7DC3DE00` |
| routers/orders.py | `64075036D6E094C66939FA807656178A93EC34A9315327208CC1FEAD3F5BEE3D` |
| utils/idempotency.py | `62271CA7CD1C2158DE0FE78BD44EC52CB0C2A9B177B4D66E8150DDFFC9083897` |
| tests/test_production_blockers_resolved.py | `E9279FD5C8A5A13D25F957182F346F7862FD51DF9296FC4757E0F73FF17C60EE` |
| tests/conftest.py | `363579E20A5D0D2728B76452F890591A24D76BFCD269A9F16064233C0C402EAB` |
