# FastKirana interim recheck — 14 October 2026

**Antigravity is still editing, as confirmed by the user. This document records an interim source snapshot and isolated probes, not a final release verdict.** Recheck these paths on a stable final tree. Earlier reports describe earlier implementations; several of their findings have now been fixed.

No application code, deployed services or database schemas were changed during this review. Security and duplicate-lock probes used fake credentials and mocked dependencies; no live payment or database calls were made.

## Improvements verified in the new implementation

- Ordinary FastAPI authentication now preserves credential-purpose claims, requires expiry and rejects socket tickets. Missing/expired encrypted JWE credentials are rejected too.
- Next campaign verification rejects socket tickets. Cookie/session lookup failures fail closed; cleared database assignments no longer restore old token assignments.
- Anonymous HTTP realtime broadcast is protected, and customer order sockets are restricted from publishing GPS/status.
- Negative/string/non-finite tips are rejected; FastAPI now includes tips in calculated totals.
- The missing Order restaurant relationship/load failure is corrected. The inspected FastAPI webhook publishes paid cache after its verified transaction commit.
- Redis idempotency acquisition now attempts SET first and mirrors successful acquisition locally. This closes the previously demonstrated same-worker outage case.
- Flutter has hub-suffixed cache keys and empty-cart tombstones. These additions still need integration with the actual selected hub and revision protocol.

## Confirmed gaps to include in the ongoing implementation

### 1. [P1] Refresh can exchange a socket ticket for REST credentials

`fastapi-backend/routers/auth.py:669` extracts a refresh credential with `verify_exp=False`. It does not reject socket purpose before minting ordinary access/refresh tokens at `:694`. Actual-code probes with a fake account/database exchanged both valid and expired socket tickets for new REST credentials. The ordinary request guard's new purpose check does not cover this route.

Require an explicit refresh-token purpose and expiry/revocation policy. Reject socket/access credentials as refresh tokens according to the agreed contract. Test the actual `/api/auth/refresh` route, including expired socket tickets and blocked accounts.

### 2. [P1] Socket single-use consumption remains process-local

`fastapi-backend/routers/websockets.py:193` imports `get_redis_client` from `utils.idempotency`, which does not define it. The exception is swallowed and consumption uses the local dictionary. The available shared helper is `utils.cache.get_redis_connection`. `:240` also makes `jti` optional.

Probes showed zero calls to a configured fake shared Redis, replay accepted after changing only worker-local state, and a ticket without `jti` accepted twice. Existing same-process replay tests pass without exercising distributed consumption.

Require `jti`, use the real atomic shared consumer, and define fail-closed behavior when shared replay protection is unavailable. Test the same ticket against independent workers, including Redis loss.

### 3. [P1] Next payment routes still allow unrelated or unsigned payment completion

`src/app/api/payment/cashfree/verify/route.ts:116` builds candidates from the selected business order, then adds the caller's arbitrary `cfOrderId` at `:118`. A paid session with the same amount is still sufficient without authenticated ownership or durable checkout binding.

`src/app/api/payment/cashfree/webhook/route.ts:25` verifies a signature only when both signature headers were supplied. Missing headers bypass verification. The route also writes paid cache at `:58` before validating the business order/payment amount.

Require gateway authentication for every nonempty payment event, validate before publishing trusted state, and resolve a persisted payment-to-checkout/buyer binding. Cover unsigned success events and unrelated same-amount sessions using the actual Next handlers. Amount comparison alone does not establish ownership.

### 4. [P1] Removing CF-note lookup needs a real payment mapping replacement

FastAPI order replay lookup at `routers/orders.py:1426` now matches only order ID/readable ID. New business orders use independently generated IDs and save the incoming CF reference in notes. The webhook lookup at `routers/cashfree_router.py:1048` likewise matches business IDs, then enters automatic recovery if none matches (`:1061`). Recovery allocates another independent order ID (`:818`).

Consequently, normal pre-order payment followed by client creation, a lost-response retry with a new request key, or a later webhook can miss the previously created order and create another fulfillment. Removing unsafe free-text identity matching is useful, but requires an explicit persisted mapping and uniqueness guarantee.

The current order replay ownership rejection also raises HTTP 403 inside a broad exception handler that logs and continues (`orders.py:1439`, `:1533` in the inspected snapshot). Preserve authorization exceptions. Optional/expiring intent cache must not be the sole ownership boundary.

Test valid preflight → business order → webhook, repeated webhook, callback-before-webhook, response loss and cross-owner reuse. Each payment/accepted checkout must yield one intended set of child orders.

### 5. [P1] Independent workers can still accept the same attempt during Redis failure

`fastapi-backend/utils/idempotency.py:120` still falls back to independent process memory after a Redis error. Two separately loaded worker helpers sharing one fake Redis produced:

```text
first_accepted=True
healthy_other_worker_rejected=True
same_worker_outage_rejected=True
other_worker_outage_accepted_again=True
```

Use durable buyer/operation/key/fingerprint/result persistence with an atomic uniqueness boundary, or reject temporarily when shared correctness is unavailable. Preserve one logical client attempt key across retries. Test separate workers and restart rather than only the process that acquired the original lock.

### 6. [P1] Payment recovery and cart durability are still incomplete

Flutter `payment_gateway_handler.dart:73` writes pending ID/amount, but `lib` contains no readers for those keys. Paid verification removes them before backend order acknowledgement. `checkout_controller.dart:248` keeps the busy flag after the Wait action dismisses the reconciliation sheet; Back, payment and checkout remain blocked without a status action or reconciler.

Restore an owner-scoped accepted checkout on startup/foreground, retain recovery data through durable business-order acknowledgement, and make pending/terminal outcomes reachable without another charge. Integrate the otherwise unused `checkoutDraftProvider` into the actual cart/login/checkout flow.

Cart clear, reconnect and startup reconciliation still bypass the normal serialized queue (`cart_provider.dart:380`, `:413`, `:438`). Repository success clears the global pending flag independently of revision acknowledgement (`cart_repository.dart:55`). The hub key uses `selected_hub_id`, which has no writer in the inspected `lib`; version/dirty arguments remain defaults and are discarded on restoration.

Connect actual owner/hub state, persisted revision/dirty/tombstone data and every writer to one acknowledgement protocol. Test delayed reconnect/clear writes followed by newer edits and restart.

### 7. [P2] Storage and release acceptance still require completion

`secure_storage_service.dart:236` still updates token caches before its secure write/readback. `saveUserSession` ordering alone cannot make this lower-level write fail closed. Test secure-write/readback failure and publish cached authentication only after successful persistence.

Tracking marker generation still begins in `initState` with painters that read inherited MediaQuery; mounted checks in later animations do not address that initialization dependency. Whole-app 2× text, native payment lifecycle, accessibility, signed artifact and coordinated decimal migration evidence remain outside the passing unit-suite results.

## Local checks in this interim run

- Node unit suite independently passed: **147 tests, 21 suites**.
- Flutter suite independently passed: **268 tests**.
- TypeScript `tsc --noEmit --incremental false` independently passed.
- The isolated backend suite completed with **202 passed, 2 failed**. The two newly added stock tests both received HTTP 400 with “Product … is no longer available” instead of the expected “insufficient stock.” They therefore do not establish that the intended aggregation/stock branch was exercised. Repair their fixtures/behavioral assertions and rerun. The counts differ from the supplied earlier summary because source and tests continued changing. External HTTP transports were disabled during this run; database fixtures were isolated SQLite.
- Flutter analyzer independently passed: **no issues, 361.5 seconds**. Because source edits continued during execution, these results belong to this interim run and must be repeated as appropriate on the final stable tree.

Final verification should begin after edits and saves finish. Reproduce the actual failure paths above and record which are closed, rather than treating the previous summary or a graph rebuild as a release certificate.
