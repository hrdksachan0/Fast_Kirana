# Independent FastKirana backend verification — 15 October 2026

This review checks the implementation report claiming all blockers resolved and a 10/10 production-readiness rating. It is independent of the edited 14 October report. Application code and tests were not changed.

## Verification

The full offline Python rerun finished with **223 passed, 1 failed** out of 224 tests in 201.46 seconds. It used in-memory SQLite, dummy keys, dotenv loading disabled, and external socket connections blocked. `tests/test_migration_full.py` was excluded because it invokes payment gateway and KOT operations without complete mocks. Focused adversarial probes used actual recovery functions or unchanged source blocks with fake ORM, gateway, cache, and notification/task dependencies. No deployed database, gateway, print, notification, or broadcast was executed.

The failure is `tests/test_production_blockers_resolved.py::test_concurrent_workers_idempotency_with_redis_down`, line 1004: all four requests returned 409 and none succeeded. Consequently, the pasted report's 224 passed / zero failures was not reproduced. The SQLite/thread acceptance failure should be investigated separately from PostgreSQL behavior; it alone does not establish a production concurrency failure.

The final source hashes matched the snapshot used for the full run and focused proofs. Next.js, TypeScript, Flutter, deployment, and real gateway checks were not repeated in this Python-focused review.

## Confirmed improvements

- Ordinary checkout and recovery now insert the same consumed-payment key for the same literal provider reference. Completed ownership is staged with the order transaction.
- The Python request accepts nested `orderPayload` and store information; durable intent failure raises HTTP 503.
- Recovery restores saved pickup/delivery mode and store, and looks up database product details.
- Socket consumption rejects database ledger failure under APP_ENV=production and NODE_ENV=production.
- Unscoped KOT Supabase topics have been removed from the inspected broadcast function.
- Earlier staff scope, protected payment mapping, scoped idempotency release, and response JSON changes remain present.

## Remaining release blockers

### P1 — Recovery can confirm an underpaid order without stock enforcement

Pay-first creation accepts the client amount at `fastapi-backend/routers/cashfree_router.py:235`. Recovery computes the catalog subtotal at line 1108, but assigns `total=order_amount` and PAID at line 1129 without enforcing a validated checkout total. Its recovery function has no stock validation or deduction.

Fresh execution of the complete actual recovery function with fake dependencies produced:

| Input/output | Observed value |
| --- | --- |
| Database product unit price | ₹500 |
| Database product stock | 0 |
| Requested quantity | 2 |
| Gateway paid amount | ₹1 |
| Recovered subtotal | ₹1,000 |
| Recovered total | ₹1 |
| Recovered status | CONFIRMED / PAID |
| Mock commit | Invoked |
| Product stock afterward | Still 0 |

Catalog lookup alone does not validate payment adequacy or inventory. Recover only from an accepted checkout priced and validated on the server; enforce its complete amount, quantities, variants/addons, and stock effects in the same transaction as fulfillment. Conflicts should enter reconciliation rather than becoming a confirmed fulfillment.

### P1 — Payment-reference aliases bypass consumption uniqueness

`fastapi-backend/routers/orders.py:1645` sanitizes the caller's reference for gateway lookup. Line 1780 only strips whitespace before building the consumed-payment key at line 1784; the stored provider field at line 1837 also retains that raw reference.

Executing the unchanged payment-verification and consumption-claim source blocks with a fake gateway/database showed:

| Caller reference | Gateway lookup | Consumption key |
| --- | --- | --- |
| cf_paid!123 | cf_paid_123 | consumed_payment:cf_paid!123 |
| cf_paid?123 | cf_paid_123 | consumed_payment:cf_paid?123 |

Both lookups became paid and both distinct keys were acquired. The new unique ledger protects identical raw strings, but those strings are not the identity used for payment verification. Reject malformed references or use one canonical, server-verified payment identity for lookup, ownership, storage, and every fulfillment claim. Test sequential and concurrent aliases as well as ordinary checkout racing recovery.

### P1/P2 — Recovery can spoof grocery-to-restaurant routing

At `fastapi-backend/routers/cashfree_router.py:1033`, a null database `restaurantId` falls through to the caller's cached restaurant ID because the expression uses `or`. A legitimate grocery product's null assignment is therefore not authoritative.

The complete actual recovery-function probe with database restaurantId=None and client restaurantId=REST-SPOOF returned a restaurant order routed to REST-SPOOF. When a database product exists, its null assignment must remain null. Missing products and invalid variants should be reconciled rather than accepted through client metadata.

## Additional environment handling gap

At `fastapi-backend/routers/websockets.py:201`, `settings.APP_ENV` occurs before the ENVIRONMENT/PRODUCTION fallbacks. Its default value is the nonempty string development, so those later variables cannot select production when APP_ENV/NODE_ENV are absent.

Actual-function probes with a failing fake database and healthy fake Redis observed:

| Only production variable set | Ticket accepted |
| --- | --- |
| APP_ENV | false |
| NODE_ENV | false |
| ENVIRONMENT | true |
| PRODUCTION | true |

The checked-in Render configuration uses NODE_ENV, so the original Render-variable bug is fixed. The broader report claim covering all four environment mechanisms remains incomplete. Normalize deployment environment configuration and add ledger-failure tests with Redis healthy, not only both stores unavailable.

## Coverage and readiness

The new recovery test verifies the happy path where paid amount equals catalog price. It does not reject underpayment, enforce stock, reject a forged restaurant, or exercise variant/store-specific pricing. The payment-lock test seeds one literal consumed key; it does not exercise aliases accepted by gateway sanitization. The KOT-topic test constructs a separate local topic list rather than executing the production function.

These findings do not require real payment or printing operations to establish the inconsistent validation. They prevent accepting the report's 10/10/immediate-release conclusion. Multi-process PostgreSQL transactions, migration application, and native gateway lifecycle were not verified in this review.

Source hashes for the focused proofs:

- cashfree_router.py: 4ABC5E980285EBCA48B0DB89F122D0E96AFA9E462A16C825173C6BF32CE35BC6
- orders.py: 42E39816DB214A29160D6BDC0DA330D59CBA8E4C477CEF1F651C48AAE0604553
- websockets.py: 24FA266F237D231FFC0087BD8D12A5C85FD0BA714B431B9E3335CBCD9B515D96
