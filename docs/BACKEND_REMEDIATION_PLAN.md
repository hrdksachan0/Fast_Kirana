# FastKirana backend remediation plan — revision 2

Updated: 14 October 2026. Workspace: `D:\Fastkirana`. Status: partially implemented; remaining work is listed below. Current production-readiness rating: 5/10.

This revision replaces the initial 13 October plan. Preserve the verified fixes and complete the eight remaining work items. Each item has a specific implementation boundary and acceptance gate. Planning updates do not count as implementation.

## 1. Evidence and verified progress

Latest targeted recheck: 17 Node authentication tests and 12 FastAPI regression/socket tests passed. The preceding broader run had 145 TypeScript passes, successful TypeScript compilation, and 187 Python passes with one known SQLite pool-test failure. The gateway-calling migration smoke was excluded. Reviews used local fixtures/mocks, not deployed services.

Existing tests pass while separate failure-case probes still demonstrate authorization, payment-binding, and channel-permission defects. New regression coverage must include those exact cases.

| Protection | Verified current status | Remaining boundary |
|---|---|---|
| Next session update | Client email/phone updates ignored; lookup anchored to user ID | Legacy API guard still has root-phone overrides |
| Primary session promotion | Database USER remains USER; blocked/deleted accounts rejected on successful lookup | Database-error handling must reject protected use |
| General Next JWT helper | Requires configured key and expiry; rejects socket tickets | Apply the same rules to every other verifier |
| Public address/cart identity headers | Cannot obtain private account data without the configured internal secret | Preserve legitimate browser/mobile transport |
| FastAPI bearer account lookup | Refreshes database role/scope; rejects blocked/deleted accounts and lookup failure | Token extraction still loses purpose claims; expiry/configuration gaps remain |
| Profile and Google entry points | Profile update requires authentication; email-only Google login rejected | Complete contact/provider verification and OTP lifecycle |
| Websocket entry points | Ticket creation requires login; anonymous sockets rejected | Wildcard tickets, broadcast publication, and staff channel scope remain unsafe |
| Cashfree direct verification | Direct unrelated-ID and symmetric amount-mismatch checks improved; `func` import fixed | Editable notes still determine payment identity; missing amounts can skip validation |
| Order idempotency | Healthy shared Redis uses atomic acquisition | Redis failure/restart must retain durable correctness |

These entries describe specific verified behavior, not completion of entire subsystems.

## 2. Remaining work register

| ID | Priority | Deliverable | Dependency | Completion evidence |
|---|---|---|---|---|
| R1 | P0 | Database-only role/scope authorization; reject verification outages | None | Bearer/cookie/bridge permission matrix |
| R2 | P0 | Verified picker, kitchen, KOT, and service actions | R1 principal contract | Staff/service negative and positive API tests |
| R3 | P0 | Exact-channel realtime access and authorized publication | R1-R2 principal contract | Ticket/handshake/publication tests on both aliases |
| R4 | P0 | Durable checkout/payment binding and faithful recovery | R1; reviewed additive persistence | Notes-edit/replay, webhook, and recovery tests |
| R5 | P1 | Database-derived fulfillment and atomic inventory | R4 checkout contract | PostgreSQL stock/concurrency tests |
| R6 | P1 | Durable idempotency independent of Redis | R4 persistence; integrate with R5 | Four-worker/restart/outage tests |
| R7 | P1 | Consistent credentials, OTP, provider checks, and production configuration | Coordinate with R1/R3 transport | Every issuer/verifier and production-mode tests |
| R8 | P1 | Migration, CI, client, reconciliation, and release validation | R1-R7 integrated | Staging evidence and tested recovery procedure |

Implementation order: land R1 first. R2, R3, and credential test work can proceed in parallel after the principal contract is agreed. Commerce follows the sequence: migration ownership and additive tables, validated checkout, protected payment binding, inventory/idempotency integration, then client activation. R4-R6 must pass together before enabling the complete new online-checkout flow.

Estimate: approximately 6-10 engineering days for remaining implementation, client integration, and staging. This is a planning estimate, not a delivery commitment. Admin/staff/realtime rejection fixes should ship once their own gates pass, without waiting for unrelated financial refactoring.

## 3. R1 — Make current database permissions authoritative

Evidence: [Bearer guard](D:/Fastkirana/src/lib/auth-guard.ts:168), [cookie guard](D:/Fastkirana/src/lib/auth-guard.ts:224), and [cookie verification catch](D:/Fastkirana/src/lib/auth-guard.ts:216).

Implementation:

1. Remove direct `isSuperadminPhone` privilege overrides from Bearer, cookie, effective-store, and other authorization helpers. Contacts may locate an account or display metadata; they cannot grant permissions.
2. Use the verified account ID, current database role, active status, and explicit store/restaurant assignment for every protected operation. Missing/null database assignment must replace stale token assignment, not fall back to it.
3. Reuse the verified guard principles across legacy routes. Preserve intentional role permissions per operation; do not make every staff role globally administrative.
4. Reject missing/blocked/deleted accounts. API authorization outages return a retryable 503 instead of continuing with cached permissions. Session callbacks must not issue privileged bridge credentials after verification fails.
5. Require an explicit persisted admin role before root/global-scope recognition. Helpers given no authoritative role must not promote contact details into authority.
6. Audit caller paths in `src/auth.ts`, `src/auth.config.ts`, `src/lib/auth-guard.ts`, `src/lib/superadmin-config.ts`, and `src/proxy.ts`. Keep the existing session-update and identity-header protections.

Acceptance gate:

- USER plus root phone, root email, or stale ADMIN claims cannot pass ADMIN-only access through cookies, Bearer, or bridge tokens.
- Missing/deleted/blocked accounts are denied; database outage returns an unavailable response and produces no new privileged bridge token.
- An existing assigned admin/staff account succeeds within its scope and fails outside it.
- Reassignment or role revocation takes effect on the next protected operation, including when the new assignment is null.
- Ordinary login, customer account access, and staff re-login still work.

## 4. R2 — Remove independent staff authorization shortcuts

Evidence: [picker identity fallback](D:/Fastkirana/fastapi-backend/routers/picker.py:31) and [KOT authorization](D:/Fastkirana/fastapi-backend/routers/kot.py:194).

Implementation:

1. Remove fabricated picker identity from role/email/store headers. Call the shared verified-account dependency, then check operation-specific role and assignment.
2. Authenticate KOT/restaurant operations before interpreting `manual`, `source`, phone, outlet, or print options. These fields describe an action, not its authorization.
3. Resolve the affected order/product/store/restaurant from the database and check staff assignment against it.
4. Give necessary background/service calls a separate authenticated service principal with explicit operations and scope. A shared internal secret does not authorize arbitrary caller-supplied user identities or roles.
5. Update web/Flutter picker and kitchen callers to send verifiable credentials. Check restaurant section mutations and related staff routes for the same standalone shortcuts.

Acceptance gate:

- Header-only ADMIN/PICKER/CHEF, `manual=true`, claimed source, and claimed staff phone cannot mutate inventory or enqueue kitchen printing.
- Customer and wrong-outlet staff requests fail without side effects.
- Assigned picker/chef/admin and narrowly scoped service jobs succeed for permitted operations.
- Duplicate authenticated printing/service requests follow the operation's deduplication rules.

## 5. R3 — Close realtime permissions completely

Evidence: [wildcard acceptance](D:/Fastkirana/fastapi-backend/routers/websockets.py:208), [ticket issuance](D:/Fastkirana/fastapi-backend/routers/websockets.py:244), and [unrestricted broadcast](D:/Fastkirana/fastapi-backend/routers/websockets.py:326).

Implementation:

1. Introduce one resource/channel authorization function used for issuance, handshake, and publication. Allow only supported channel kinds and exact canonical resource IDs. Reject wildcard `*`, empty, malformed, and unknown channels.
2. Derive the ticket subject and channel from the authenticated account and authorized resource. Check customer ownership, rider assignment, and staff store/restaurant assignment. A DELIVERY role alone must not grant every order's location stream.
3. Reject wildcard tickets in the verifier even if already signed. Keep REST credentials and socket tickets distinct in every verifier; use explicit purpose/audience rules and a coordinated issuer/verifier rollout.
4. Make the promised single-use behavior real: issue a unique ticket ID and consume it atomically through shared persistence. Reconnection obtains a new ticket. Expiry and account/assignment revocation remain enforced.
5. Separate read subscription from publication capability. Customers may receive their own order updates; they cannot inject delivery status/GPS. Assigned riders/services publish only permitted validated events. Financial/fulfillment state changes use authorized server operations.
6. Authenticate HTTP broadcast and restrict target channel and event type. Apply identical rules to `/ws`, `/api/ws`, and other mounted aliases.
7. Verify long-lived connection revocation, reconnect behavior, and browser/Flutter compatibility. Avoid exposing long-lived bearer credentials in URLs/logs.

Acceptance gate:

- A USER requesting `*` receives a validation error and no ticket. A signed wildcard ticket is rejected for another customer's order, outlet, or rider.
- Anonymous/customer/wrong-scope HTTP publication fails without delivery to any subscriber.
- Missing, expired, reused, wrong-purpose, and wrong-channel tickets cannot connect. Assert the intended rejection/code; an arbitrary exception is not proof of secure rejection.
- Customer read-only, assigned rider publication, and authorized kitchen streams succeed.
- Blocking/reassignment invalidates relevant existing access across workers.

## 6. R4 — Persist checkout and payment identity before gateway initiation

Evidence: [notes-based candidate selection](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:329), [owner-editable notes](D:/Fastkirana/fastapi-backend/routers/orders_helper.py:89), [web request](D:/Fastkirana/src/hooks/checkout/use-checkout-payment.ts:371), and [FastAPI request model](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:57).

Implementation, in dependency order:

1. Establish the authoritative migration workflow and add protected checkout/payment-attempt records. Mirror the changes in SQLAlchemy. Final table/constraint definitions require comparing deployed schema history with the current Prisma schema.
2. Store the authenticated buyer, authorized address snapshot, effective store, canonical selections/quantities, fulfillment groups, accepted server-calculated totals, currency, and checkout version before contacting the gateway.
3. Create a server-owned binding from each provider order/attempt to exactly one checkout and buyer. Enforce unique provider transaction identity and one fulfillment completion per checkout. Compare exact minor units or decimal amounts; reject missing, malformed, mismatched amount/currency, and wrong state.
4. Remove notes, readable-ID prefix/suffix guesses, and customer-submitted metadata as payment authority across verification, webhook lookup, order deduplication, and checkout payment checks. Order notes remain customer instructions only. Cache entries must reference a validated persisted payment record rather than act as independent paid booleans.
5. Authenticate customer verification/status calls and enforce ownership. Authenticate provider callbacks through required signature verification. Internal sync/reconciliation paths use restricted service authorization.
6. Standardize web and Flutter on one validated checkout contract. Temporarily adapt supported `orderPayload` and `cartPayload` shapes explicitly; silently ignored financial fields must fail validation. Updated clients initiate/check payment through the saved checkout ID.
7. Unify polling, webhook, and reconciliation completion. Verify remote status outside long database locks; durably accept callbacks, then perform allowed payment/order/inventory transitions atomically. Deduplicate callback retries and multiple successful attempts.
8. Recover only from the stored checkout. Do not read the current cart/default address or fabricate placeholder merchandise. Ambiguous legacy sessions become durable reconciliation cases.
9. Exercise the signed callback with real ORM mappings. Repair nonexistent relationship references such as `Order.restaurant` and prevent trusted paid-cache writes from preceding validated durable payment state.
10. Keep existing callbacks operational during transition. Migrate historical bindings only when supported by trusted evidence; user notes alone are insufficient. Never auto-fulfill ambiguous already-paid records.

Follow [Cashfree raw-body signature verification](https://www.cashfree.com/docs/payments/online/webhooks/signature-verification) and [payment-attempt idempotency guidance](https://www.cashfree.com/docs/payments/online/webhooks/webhook-indempotency). These guide provider behavior; the local durable binding determines which checkout may change.

Acceptance gate:

- Execute the full owner-edit-notes then verify chain: adding `[CF_ORDER:another_payment]` cannot pay or disclose another checkout.
- An old successful payment, another buyer's reference, missing amount, wrong currency, and altered signature produce no financial/fulfillment mutation.
- Direct ID and amount checks that already pass remain passing, including combined checkout.
- A signed callback tested against actual model mappings succeeds once without relationship errors or premature trusted cache writes.
- Browser closure, webhook-before-client completion, cart/address changes after initiation, Redis loss, duplicate polling/callbacks, and process restart recover the exact saved checkout.
- Sum of child totals equals checkout total and gateway charge for grocery, food, mixed, pickup, variants, add-ons, coupons, and supported fees/tips.

## 7. R5 — Derive fulfillment and stock from database records

Evidence: [client restaurant fallback](D:/Fastkirana/fastapi-backend/routers/orders.py:940).

Implementation:

1. Remove customer restaurant/store classification from stock validation and order grouping. Resolve these from authorized catalog and hub records, and reject contradictory client fields.
2. Aggregate duplicate product/variant lines before checking limits and stock. Validate canonical variants/add-ons and current availability.
3. Decide inventory authority across hub inventory, variant stock, and batches. Reuse/adapt existing reservations only after binding them to immutable checkout identity and expiry.
4. Reserve, consume, and release finite stock transactionally with order/item writes, coupon use, and immutable stock history. Lock rows in deterministic order and keep transactions short.
5. Define late payment after reservation expiry/cancellation: fulfill only after safe stock validation or create an explicit refund/reconciliation obligation.

Acceptance gate, using PostgreSQL:

- Grocery stock 1 plus quantity 2 and a forged restaurant ID is rejected; it cannot obtain unlimited restaurant stock or skip grocery deduction.
- Duplicate lines cannot evade quantity/stock limits.
- Parallel buyers of the last unit produce one successful sale and no negative availability.
- Failure midway rolls back all effects; cancellation/expiry restores stock once; completion consumes it once.

## 8. R6 — Preserve correctness when Redis fails

Evidence: [process-memory fallback](D:/Fastkirana/fastapi-backend/utils/idempotency.py:120). Keep the verified healthy-Redis atomic path as acceleration.

Implementation:

1. Add a PostgreSQL uniqueness boundary scoped to buyer/checkout, operation, and explicit client idempotency key. Persist normalized request fingerprint, processing/result state, and committed result identity.
2. Identical retries replay the committed result. Changed payload with the same key returns a conflict. A fresh intended purchase uses a fresh key.
3. Protect COD creation, payment completion, coupon consumption, inventory consumption, and fulfillment creation in the same database transaction as their result record.
4. Redis absence, timeout, read/write error, lock expiry, or restart cannot bypass database uniqueness. Remove process-only fallback as the authority for production writes; if the database is unavailable, reject/retry safely.
5. Persist retryable fulfillment/notification work with the commit. Redelivery may occur, but consumers must not duplicate financial, inventory, or printing effects.

Acceptance gate, using independent workers:

- Four concurrent identical COD/online requests produce one committed checkout/order group.
- Repeat with Redis absent, throwing on read/write, restarting, and losing locks.
- Crash after database commit but before HTTP response: retry returns the original result.
- Same key/different payload fails; different buyers cannot collide or retrieve each other's result.

## 9. R7 — Finish credential and production configuration consistency

The general Next verifier is fixed; the remaining FastAPI and campaign verifiers must obey the same contract.

Implementation:

1. Preserve or validate purpose claims before extracting account identity. FastAPI currently drops `scope/type`, making later socket-ticket checks ineffective. Reject socket tickets as REST credentials across every helper, including campaign authorization.
2. Require valid identity and expiry in every accepted token format. Remove known fallback signing secrets and fail production initialization when required configuration is missing.
3. Enforce OTP cache/database expiry, bounded attempts, and atomic shared single-use consumption. Reject blocked/deleted accounts before issuance. Gate review/test shortcuts to controlled non-production configuration.
4. Finish Google issuer/audience/expiry and provider-identity checks, including web/mobile client IDs and safe account linking, using [Google server verification guidance](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token).
5. Preserve verified browser cookies, signed bridge tokens, Flutter login/refresh, and authenticated server jobs. Coordinate any key/version change across issuers and readers; handle required re-login without restoring unsafe fallbacks.
6. Invalidate the compromised credential generation/version during release. Accept supported older request shapes only with newly verified credentials.

Acceptance gate:

- Socket-purpose tokens, absent/invalid expiry, invalid signature/algorithm/identity, and missing signing configuration are rejected by every verifier.
- Expired/reused OTPs and blocked/deleted identities receive no new access token.
- Wrong-audience/issuer Google credentials and unsafe account linking fail; legitimate web/mobile login succeeds.
- Database/configuration outage cannot generate privileged sessions or silently initialize production SQLite.

## 10. R8 — Integrate, validate, and release

1. Confirm migration ownership/history. Use reviewed additive migrations and synchronized Prisma/SQLAlchemy models. Exclude the destructive Alembic baseline from rollout.
2. The current decimal SQL is a loose file, and application schemas still use Float. If decimal conversion is included, package it as a versioned `migration.sql`, update both schemas/calculations/serialization, cover every active monetary field, and rehearse with populated data. A document or unexecuted SQL file is not a completed conversion.
3. Fix the SQLite pool-test assumption and validate PostgreSQL pool settings separately. Keep ordinary CI hermetic; move the gateway-calling smoke to explicit sandbox testing.
4. Run relevant unit/API tests, typecheck/lint/build, PostgreSQL race tests, migration replay/upgrade, and production-mode startup on declared Docker/CI Python versions.
5. Verify browser and Flutter login/re-login, customer account isolation, staff scope, tickets/reconnect, COD, UPI, mixed checkout, pickup, pending payment, cancellation, and recovery. Cover both Next rewrite settings and direct FastAPI.
6. Rehearse callback replay, inventory/Redis outage, process restart, backup restoration, and legacy-payment reconciliation on staging. Establish measured error/latency/queue budgets for expected load.
7. Deploy additive schema first, compatible server logic next, then clients and feature activation. Preserve valid callbacks and drain/reconcile legacy sessions before removing their adapter.
8. Roll back to a secure compatible build or suspend affected writes; retain payment records and additive schema. Never restore known unsafe authorization or notes-based payment acceptance.
9. Update security/access documentation to match implemented guards and measured evidence. Record any consciously deferred financial migration work as deferred, not complete.

Release gate: R1-R7 passing evidence, compatible migrations, functional web/mobile checks, recoverable accepted payments, and rehearsed operational recovery. No release approval is implied by local unit tests.

## 11. Reviewable implementation slices

1. R1 role/scope authority and database-error handling, with failing/passing behavioral tests.
2. R2 operational/service permissions and compatible staff callers.
3. R3 exact-channel tickets and publication permissions, with web/Flutter reconnect support.
4. Additive checkout/payment/idempotency persistence and synchronized ORM mappings.
5. R4 completion/recovery service and compatible checkout clients.
6. R5-R6 transactional stock/idempotency/outbox integration.
7. R7 issuer/verifier/configuration/OTP/provider consistency.
8. R8 migrations, CI, staging, reconciliation, and release runbook.

Auth/realtime work can proceed alongside commerce after shared contracts are agreed. Each shared file/schema has one editing owner at a time. Preserve existing user changes. Broad router cleanup, cosmetic work, and a full backend migration are outside this remediation unless necessary to enforce one of the listed invariants.

## 12. Fixed completion ledger

| Item | Status | Required evidence before changing to complete |
|---|---|---|
| R1 Authorization | OPEN | USER/root-contact denial, fresh scope, outage rejection, legitimate staff success |
| R2 Staff/service actions | OPEN | Header/manual/source denial and scoped operational success |
| R3 Realtime | OPEN | Wildcard/anonymous publication denial, ticket consumption, scoped reconnect/publication |
| R4 Payments/recovery | OPEN | Owner-note-edit replay denial, protected binding, faithful callback/recovery |
| R5 Inventory | OPEN | Forged routing/duplicate-line denial and PostgreSQL concurrency |
| R6 Idempotency | OPEN | Four-worker, Redis failure, crash/restart, response replay |
| R7 Credentials/configuration | OPEN | Every verifier/issuer and production-mode failure matrix |
| R8 Integration/release | OPEN | Passing checks, migration/client/staging/reconciliation/rollback evidence |

A work item is complete only when its real handler/service tests cover both rejected and legitimate behavior, old verified protections stay intact, and dependencies are integrated. The next review should report this ledger as complete/partial/open with evidence. Any genuinely new finding must be identified separately; existing failures must not be hidden by increasing test counts or a revised plan.
