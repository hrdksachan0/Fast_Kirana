# FastKirana latest saved-code recheck — 14 October 2026

This follow-up reviews the saved code after the interim report. Antigravity was previously confirmed to be editing; this is a current-source review, not certification of a final deployed release. No application fixes, migrations, deployments or external-service calls were performed.

## Current outcome

Durable idempotency models and integration have been added, and account-blocking checks have improved. The earlier security/payment/mobile gaps are not all closed. The new idempotency path also introduces two directly reproduced failures.

### 1. [P1] First checkout is rejected when Redis is healthy

`fastapi-backend/utils/idempotency.py:128` acquires a process-local lock after successfully acquiring Redis. Line 134 immediately acquires that same local key again, sees its own PROCESSING record and returns duplicate. `fastapi-backend/routers/orders.py:535` turns the result into HTTP 409 before placing the order.

An isolated probe of the actual helper, with fake Redis/database dependencies, returned:

```text
brand_new_key_result=(True, True, None)
redis_lock_created=True
database_calls=0
```

Acquire each layer once and distinguish ownership from duplicate acquisition. Add a happy-path test with configured, healthy Redis and an entirely new key. The current outage-only tests do not cover this path.

### 2. [P1] A shared explicit key can replay another buyer's order

The durable lookup at `fastapi-backend/utils/idempotency.py:143` uses only `key`, and the completed branch at `:149` returns the saved response without checking `user_id`, operation or request fingerprint. An isolated probe with stored owner Alice and caller Bob returned Alice's order response. `src/lib/idempotency.ts:115` has the same key-only durable replay policy. Both order routes accept client-supplied keys.

Scope keys by the verified buyer and operation, persist a canonical request fingerprint, and reject key reuse with another payload. Check ownership before replaying cached results in every storage layer. Define expiry/new-purchase semantics; completed records currently replay without expiry checks, including keys derived from identical cart contents.

### 3. [P1] Durable order and result are not committed atomically

FastAPI commits business orders at `routers/orders.py:1920`, then saves the completed idempotency result at `:2215`. A worker failure between those steps leaves a committed order and an expiring PROCESSING record; a later takeover can place the order again. Next returns immediately after healthy Redis acquisition (`src/lib/idempotency.ts:106`), so that path does not acquire a durable PROCESSING record at all. Expired-record takeover also needs an atomic ownership claim.

Persist the result/uniqueness boundary in the business transaction, replay the committed outcome after a lost response, and keep Redis as an acceleration layer. Coordinate a real schema migration and the shared Prisma/SQLAlchemy response representation; model declarations and SQLite `create_all` are not deployment evidence.

The added “concurrent workers” test at `fastapi-backend/tests/test_production_blockers_resolved.py:995` actually runs four threads sharing a module and memory lock. Test independent worker state and PostgreSQL transactions, plus process failure after business commit.

### 4. [P1] Refresh-token and distributed socket-replay gaps remain

- `fastapi-backend/routers/auth.py:669` still extracts a refresh credential with `verify_exp=False` and does not reject socket purpose before minting ordinary access/refresh credentials. The previously reproduced valid/expired socket-ticket exchange remains possible in this unchanged path.
- `fastapi-backend/routers/websockets.py:193` still imports nonexistent `get_redis_client` from `utils.idempotency`. Its swallowed ImportError sends replay tracking to a process-local dictionary. The actual helper is `utils.cache.get_redis_connection`. At `:240`, `jti` remains optional.

Reject socket tickets at refresh, require the agreed refresh credential purpose/expiry policy, require ticket IDs, and enforce shared atomic consumption across independent workers. Keep the already corrected normal REST purpose rejection, current-account guards and protected broadcast behavior.

### 5. [P1] Payment binding and mobile recovery still need completion

- Next verification still trusts arbitrary caller `cfOrderId` as a candidate (`src/app/api/payment/cashfree/verify/route.ts:118`); equal amount does not prove the selected checkout/buyer owns that payment.
- Next webhook verification remains conditional on signature headers being present (`src/app/api/payment/cashfree/webhook/route.ts:25`), and paid cache is still published before validation (`:58`). Missing headers must reject nonempty payment events.
- FastAPI callback/retry/webhook lookup still needs a dedicated persisted CF-to-checkout/order mapping after removal of free-text notes matching. A new client key or webhook must find the same accepted checkout and child orders.
- Flutter still has no reader for `active_pending_cf_order_id/amount`. The Wait action still leaves checkout locked without a recovery action, and paid verification removes recovery data before durable order acknowledgement. `checkoutDraftProvider` still has no flow consumers.
- Cart clear/reconnect still bypass the normal sync queue; the pending flag is global, and `selected_hub_id` has no writer in the inspected Flutter source. A hub-suffixed string and tombstone alone do not complete revision-aware recovery.

See the preceding interim report for the exact mobile paths and acceptance scenarios. These critical Flutter files have not changed since the prior passing Flutter run; the suite/analyzer were not repeated for this follow-up.

## Improvements retained and newly present

- Public signup forces USER; password/OTP/Google login reject blocked/deleted accounts before issuing credentials.
- Normal REST purpose/expiry checks, Next cookie/session outage rejection and cleared-assignment handling remain corrected.
- Negative/non-finite tip validation, FastAPI tip totals, the restaurant relationship/load correction and FastAPI webhook post-commit cache ordering remain corrected.
- Prisma/SQLAlchemy idempotency record models and route integration now exist. They are useful progress, but the failures above must be addressed before calling deduplication complete.

## Checks for this follow-up

- Node unit suite: **147 passed**, 21 suites.
- Full isolated backend suite: **209 passed**, 55.88 seconds. The two stock tests that failed in the prior interim run now pass.
- TypeScript `tsc --noEmit --incremental false`: **passed**.
- Isolated actual-helper probes: healthy-Redis first-acquisition failure and cross-owner durable replay reproduced using fake dependencies.
- Previous Flutter run: 268 tests passed and analyzer clean; these are previous results, not a new run in this follow-up.

The backend run used dummy secrets, isolated SQLite fixtures and disabled external HTTP transports. It therefore does not establish deployed schema, healthy Redis or independent PostgreSQL worker behavior. Those are the uncovered paths highlighted above.

Implementation priority: repair the new first-request lock failure and owner/fingerprint scope, make durable completion atomic, close refresh/socket and Next payment authentication/binding, then complete mobile/cart recovery and the original native release gates.
