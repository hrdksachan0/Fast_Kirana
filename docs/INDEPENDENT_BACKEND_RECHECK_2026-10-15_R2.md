# FastKirana independent backend recheck — 15 October 2026, revision 2

This review supersedes the open/closed findings in `INDEPENDENT_BACKEND_RECHECK_2026-10-15.md` for the current source snapshot. Application code and tests were not changed.

## Verification result

**228 Python tests passed, zero failures**, in 43.49 seconds. The earlier Redis-down concurrency test passed in this run. The suite used in-memory SQLite, dummy credentials, disabled dotenv loading, and blocked external network connections. `tests/test_migration_full.py` was excluded because it exercises payment gateway and KOT side effects without complete external mocks. No live database, gateway, printing, notifications, or deployment was used.

## Verified closures

- The previous ₹1 payment / ₹1,000 catalog subtotal case now remains ADMIN_PENDING with reconciliation notes. Fresh execution of the actual recovery, webhook, and verification functions preserved that quarantine; no automatic promotion to CONFIRMED occurred.
- Database grocery assignment remains null despite a client restaurant spoof.
- Punctuation aliases such as `cf_paid!123` and `cf_paid?123` now receive HTTP 400 before database access.
- Socket ledger failure rejects tickets under each independently isolated APP_ENV, NODE_ENV, ENVIRONMENT, and PRODUCTION setting, even with Redis healthy.
- Durable checkout intent, pickup/store restoration, ordinary checkout/recovery consumption rows, and scoped KOT broadcasts remain present.

## P1 — Recovery inventory validation is incomplete

The new checks validate each submitted line independently rather than aggregating demand by product/variant. Product loading at `fastapi-backend/routers/cashfree_router.py:1082` has no row lock. Availability checks at lines 1095–1114 compare each line with the original product/variant stock.

Fresh executions of the complete actual recovery function with fake ORM/cache/task implementations committed these results:

| Case | Actual result |
| --- | --- |
| Product stock 1; two duplicate lines, each quantity 1 | CONFIRMED order for 2 units; stock clamped to 0 |
| Variant stock 1; two lines selecting that same variant | CONFIRMED order for 2 units |
| Global stock 2; chosen hub stock 0; quantity 1 | CONFIRMED order; hub stock remained 0 |

Stock deduction at lines 1293/1300 clamps subtraction, which does not prevent overselling. Hub inventory is loaded only during deduction at lines 1305–1312 and its availability is not checked. There is also a read/check/write race between different payments for the same SKU; real PostgreSQL concurrency was not executed.

Aggregate demand by canonical product and variant, validate against the selected hub, and reserve/decrement inventory atomically. Apply the same validated calculation/reservation behavior to ordinary checkout, payment-session creation, and recovery. Acceptance should cover duplicate standard/variant lines, zero or missing hub inventory, and two independent transactions competing for the last unit.

## P1 — Retry suffixes still reuse one paid payment across different consumption keys

The special-character fix does not cover valid retry-shaped references. `fastapi-backend/routers/orders.py:1648` falls back from `cf_paid_r123` to the paid cache for `cf_paid`. The consumption record at line 1807 uses the complete suffix reference, and existing-order lookup at lines 1597–1599 also searches that separate reference.

Executing the current, unchanged canonicalization, payment-cache, and consumption-key source blocks with only `cf_pending:cf_paid` for the same buyer and `cf_paid:cf_paid` containing a paid ₹100 amount produced:

```text
cf_paid_r123 -> paid=True -> consumed_payment:cf_paid_r123
cf_paid_r456 -> paid=True -> consumed_payment:cf_paid_r456
```

Both references used the base payment cache; neither queried the gateway. They passed format validation and generated different consumption identities for the same cached payment. This is a source-block reproduction, not a full checkout insertion, but it leaves the shared-ledger uniqueness boundary inconsistent with payment authorization.

Resolve retries through a protected accepted-checkout/payment binding. Payment authorization, ownership checks, existing-order lookup, and fulfillment consumption must use one identity. A base paid-cache entry must not authorize an otherwise unverified retry reference. Test completed base orders, fabricated valid retry suffixes, legitimate retries, and concurrent checkout/recovery.

## Practical conclusion

The newly added regression tests pass and the previous specific underpayment, routing, punctuation, and environment cases are closed. The two invariants above remain release blockers. SQLite/thread checks and source-block mocks do not replace multi-process PostgreSQL transaction verification. No Next.js, TypeScript, Flutter, or live gateway verification was repeated in this Python-focused pass.

Final source hashes matched the initial review snapshot:

- orders.py: 5B2DDD8D5858404E67FA2F1F139B90D5B1B44B9D5A66FB0751AED27A1F8A4C84
- cashfree_router.py: 0A3E0F12433C31C122DE40A5DC6DF43FBCFBE5FB07A4E81EDFACA7D4B91638C7
- websockets.py: 9C1279F9D0D30B3A6B7E820CF94CBC2E428333844EBE73E257BF2818548718A5
- test_production_blockers_resolved.py: E9279FD5C8A5A13D25F957182F346F7862FD51DF9296FC4757E0F73FF17C60EE
