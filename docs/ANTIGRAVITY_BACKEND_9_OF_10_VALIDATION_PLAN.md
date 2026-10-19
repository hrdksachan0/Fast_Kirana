# FastKirana Python backend — evidence plan for a 9/10 reassessment

Status: implementation and execution plan, not completed validation.

Goal: establish that concurrent checkout, payment recovery and peak traffic preserve financial/inventory correctness on a production-like PostgreSQL deployment. A rating increase depends on the results and remaining findings, not merely implementing these tests.

## Baseline and gaps found in this repository

- The independently executed R4 baseline is **240 Python tests passed**, using isolated SQLite. It does not prove PostgreSQL locking or durability across real worker crashes.
- [tests/conftest.py](D:/Fastkirana/fastapi-backend/tests/conftest.py) hardcodes SQLite and overrides `get_db`. Changing `DATABASE_URL` alone will not convert that suite into a PostgreSQL integration suite.
- [docker-compose.yml](D:/Fastkirana/docker-compose.yml) is a development starting point: no Redis service, placeholder configuration and different API port assumptions from the backend Dockerfile. Build a dedicated validation stack.
- [load_tests/locustfile.py](D:/Fastkirana/fastapi-backend/load_tests/locustfile.py) uses identity headers rather than real JWTs, unseeded sample IDs, and `/api/cart/items` rather than the current POST `/api/cart` or `/api/cart/add` contract. It counts several validation/not-found responses as successes. It also references `os.environ` without importing `os`. These issues must be fixed before its figures are accepted.
- [scripts/load_test_websockets.py](D:/Fastkirana/fastapi-backend/scripts/load_test_websockets.py) connects without the channel-bound tickets required by the current router. It needs authenticated riders/orders and delivery assertions.
- [cashfree_router.py](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:611) returns local mock sessions for `CASHFREE_ENV=TEST/MOCK`. Those results are not real Cashfree sandbox evidence. The current URL-selection logic routes `SANDBOX` to the sandbox host; verify configuration and actual outbound requests before collecting sandbox results.

## Phase 1 — Build an isolated, representative validation environment

Deliverables:

- Dedicated validation Compose configuration: PostgreSQL, Redis, API, controllable payment stub and notification/printing sinks. Use the deployed PostgreSQL major version, extensions, migrations, isolation level and connection-pool mode. Pin images/dependencies for replay.
- Run **four actual API worker processes**, then repeat critical tests across **two API containers**. Record container/worker IDs to demonstrate requests reached independent processes.
- Separate `fastapi-backend/integration_tests/` with its own fixtures, outside the existing SQLite `tests/conftest.py` tree. Drive the running API over HTTP. Fail setup unless the application and oracle connections both identify PostgreSQL and the expected validation database.
- Seed two stores, two restaurants, registered customers, staff, riders, addresses, variant products, canonical underscore IDs, coupons and finite inventory. Issue valid JWTs for seeded identities. Use fresh run IDs and idempotency keys per scenario.
- Apply migrations to an empty disposable database; compare resulting schema with ORM expectations. Do not substitute `create_all()` for migration validation.
- Match production auth and durable-ledger guards. Do not run the API inside pytest or enable `TESTING=1` globally to suppress behavior. Route external side effects to controlled sinks instead. Permit payment-provider egress only for the separate sandbox smoke stage.

Connection budget: record `instances × workers × (DB_POOL_SIZE + DB_MAX_OVERFLOW)` plus migration/monitoring connections; keep it within the database's usable connection budget with explicit reserve. Match the deployment's pooler if one exists. Do not raise connection limits to hide pool leaks.

Exit gate: seeded requests reach multiple workers, PostgreSQL is actually used, migrations succeed, roles/store boundaries work, side effects reach only test sinks, and the environment manifest is saved.

## Phase 2 — PostgreSQL concurrency and inventory correctness

Use barriers to release requests together. Give every request its own HTTP connection and transaction; do not simulate workers by calling router functions in one Python process. Repeat each race **at least 100 times**, with a recorded schedule/seed, in Redis-healthy and Redis-unavailable modes. Also test Redis recovery while traffic continues.

| ID | Scenario | Required result, checked directly in PostgreSQL |
| --- | --- | --- |
| PG1 | 50 simultaneous requests with the same idempotency key/payload | One logical order/fulfillment set; retries return that set or a documented retryable in-progress result. No additional stock effect. |
| PG2 | Same key with a changed payload or another buyer | Conflict/rejection; no cross-buyer response or extra fulfillment. |
| PG3 | 50 buyers compete for 10 units in one store | At the actual stock-consuming transition, at most 10 units allocated; no negative stock. Pending orders must not be mistaken for allocated inventory. |
| PG4 | Duplicate product/variant lines and reversed multi-product ordering | Quantities aggregate correctly; no oversell; normal-operation deadlocks do not escape as unhandled failures. |
| PG5 | Same SKU in two stores; different variants | No cross-store or cross-variant inventory borrowing. Verify global, variant and store pools according to the business model. |
| PG6 | Client order POST, verification and success webhook race | One logical fulfillment set for the canonical payment ID, including validated `_r123` aliases; no double deduction. |
| PG7 | Concurrent approve, cancel and repeated transitions | Stock deduction/restoration occurs once at the defined lifecycle point; invalid transitions leave state unchanged. Cover normal checkout and recovered `ADMIN_PENDING` orders separately. |
| PG8 | Kill a worker before commit, after commit/before response, or during lock ownership | No partial committed order. After-commit retry finds the original result. Abandoned ownership recovers within the documented lease/retry bound. |
| PG9 | Redis fails during reserve/commit or returns with stale reservation state | PostgreSQL remains authoritative; failed attempts leave no leaked reservation; restored Redis converges without reopening stock or consuming it twice. |
| PG10 | Lock timeout/deadlock injection and database connection interruption | Bounded rollback/retry or explicit retryable failure; no partial fulfillment, stale completed marker or leaked DB session. |

Define a stock oracle before execution: initial stock minus committed allocations plus valid restorations equals final stock, per relevant pool. Compare order items, stock markers/logs, idempotency ledger and canonical payment identity from a **fresh connection after commit**. A split grocery/restaurant checkout may legitimately contain several child orders: count one fulfillment group, not blindly one `orders` row.

Capture lock waits, transaction age, deadlock deltas and connection usage. Keep lock acquisition order consistent; keep gateway/notification waits outside stock-holding transactions where correctness allows. Optimize only demonstrated contention, with before/after query plans and correctness reruns.

Exit gate: **zero oversells, duplicate fulfillment groups, cross-store mutations or unexplained stock deltas** across all repetitions. A process-local lock or a Redis-only success result is insufficient.

## Phase 3 — Payment/webhook recovery and failure injection

First use a programmable gateway stub for deterministic latency, errors and event ordering. Then run a small separate Cashfree sandbox smoke set using sandbox credentials and actual provider requests/webhook delivery. Confirm the provider's current signature, payload and acknowledgement contracts before implementing provider-facing cases. Never stress the real gateway with the bulk load suite.

| ID | Scenario | Required result |
| --- | --- | --- |
| PAY1 | Repeated signed success webhooks, sequential and concurrent | Same canonical fulfillment group; unchanged stock after the first valid effect. |
| PAY2 | Success before client completion; success after app closure | Durable intent reconstructs the correct buyer, items, store and authoritative quote. |
| PAY3 | Pending/active/timeout/unavailable, then eventual success | Recovery retained; no replacement-payment escape or false paid status; eventual verified success reconciles once. |
| PAY4 | Failed/expired/drop events arrive around verified success | No downgrade of a confirmed paid state; distinguish individual payment attempts from the logical checkout. |
| PAY5 | Missing/wrong signature, modified raw body, wrong buyer, amount mismatch, unvalidated retry suffix | Reject without payment/order/stock mutation. Missing webhook verification configuration must not permit unverified production-mode processing. |
| PAY6 | Worker crash, DB rollback or provider timeout during webhook processing | Acknowledgement/retry behavior does not lose an unresolved payment; replay converges after recovery. Capture the commit/ack boundary. |
| PAY7 | Paid transaction cannot be fulfilled, such as insufficient stock or missing intent | Durable unresolved/orphan record and reconciliation path; never silently report fulfillment or discard the payment reference. |
| PAY8 | Valid coupons, pickup, tip/misc fees, variants and split checkout | Gateway amount equals the accepted authoritative quote and reconciled order totals; newer unrelated cart edits survive recovery. |

Replay a valid signed payload as an idempotency test. Any timestamp-age policy must support legitimate provider retries; do not invent a cutoff that drops delayed valid payments.

Record notification/printing intents and attempts in the sinks. Keep financial/inventory effects idempotent even if notifications retry. State the actual notification delivery guarantee; add durable intent/outbox behavior if guaranteed delivery is a product requirement.

Proposed recovery bound: after dependencies are restored and a valid retry/reconciliation trigger occurs, resolve within **60 seconds** in the controlled environment. No claim of automatic background recovery without proving the mechanism exists. Every seeded successful sandbox payment must map to either its correct fulfillment group or an explicitly unresolved reconciliation record; none may disappear.

Exit gate: all deterministic scenarios pass and the small real sandbox set has matching provider IDs, webhook traces, DB outcomes and reconciliation results.

## Phase 4 — Load, spike and soak testing

Repair the existing Locust/WebSocket tools rather than treating their present success counts as evidence. Pin load-tool dependencies separately. Use seeded, valid data and JWTs; validate response bodies and committed orders. Report expected business rejections, authentication failures, unexpected errors and successful business operations separately. Never count unseeded-product 404s or invalid checkout 400s as successful purchases.

Initial workload assumptions, to freeze before execution:

- HTTP mix: 60% catalog/category reads, 25% cart reads/writes, 10% valid checkout, 5% order-status/payment verification. Separate negative/race tests from this happy-path mix.
- Warm up 5 minutes; ramp through 10 users/5 minutes, 50/10 minutes and 100/15 minutes. Then spike to 200 users for 2 minutes and observe recovery for 5 minutes. Soak at the agreed target for **60 minutes**.
- Run a separate authenticated WebSocket profile at 100, 250 and 500 connected clients, sending one update/second. Use fresh channel-bound tickets on reconnect, assigned riders and authorized subscribers. Assert receipt by the correct subscriber, replay denial and no cross-order delivery. Do not assume a rider's socket echoes every message to itself.
- These are starting profiles, not a traffic forecast. Record the expected peak request rate and active sockets. The target must cover **2× forecast peak** on documented deployment-sized hardware. Report achieved requests/second; virtual-user count is not requests/second.

Proposed acceptance targets, measured per route and successful-operation class at the target load:

| Metric | Target |
| --- | --- |
| Catalog/cart HTTP | p95 ≤ 500 ms; p99 ≤ 1.5 s |
| Checkout with controlled gateway stub | p95 ≤ 1 s; p99 ≤ 2.5 s |
| Unexpected HTTP failures | < 0.5%; no hidden 401/404/validation-only workload |
| Financial/inventory invariants | Zero violations at every load level |
| Authorized WebSocket delivery | p95 ≤ 500 ms; ≥ 99.5% eligible messages delivered within 2 s during healthy steady state |
| Spike recovery | Within 60 s, latency/error rates return to the accepted steady-state envelope |
| Pool/resource stability | No connection exhaustion at target, no sustained idle-in-transaction sessions, connections return to baseline after drain |
| Soak behavior | No sustained unbounded memory/session/queue growth; investigate > 10% growth between comparable post-warmup 15-minute windows |

These are proposed project SLOs, not existing measurements or industry guarantees. Report real sandbox/provider latency separately from stub-based application latency. Document overload behavior above target, including explicit throttling and bounded failures. Measure load-generator capacity so its CPU/network ceiling cannot create a false application result.

## Phase 5 — CI gates and the evidence package

Implementation order for Antigravity:

1. **Harness PR:** validation stack, migrations, seeds/JWTs, independent PostgreSQL fixtures, repaired load scenarios and side-effect sinks.
2. **Correctness PR:** PG1–PG10 and PAY1–PAY8 with DB oracles, synchronized schedules, crash/fault injection and failing exit codes. Fix any demonstrated application defects with regression coverage.
3. **Evidence PR:** metrics capture, load profiles, staging/CI jobs, sandbox smoke runbook and final report.

Keep fast unit tests in normal PR CI. Add an explicit PostgreSQL/multi-worker correctness job; its fixtures must not inherit SQLite overrides. Isolate the currently unmocked gateway/KOT migration test into a properly controlled integration stage. Run longer load/soak/fault stages in the isolated validation environment and a short regression profile before releases. Archive artifacts for failed runs as well as successful ones.

Save under a run-specific validation evidence directory:

- Commit SHA **and dirty diff/hash**, dependency/image versions, seed, timestamps and exact invocations.
- Redacted environment manifest, worker/instance count, CPU/RAM, DB/pool configuration, gateway mode and Redis state.
- JUnit/JSON results; raw Locust CSV/HTML; WebSocket message/connection metrics; DB oracle snapshots; lock/pool statistics; process-fault timeline; sandbox correlation IDs.
- Findings, fixes, reproducible failing cases, fresh rerun results and remaining limitations. No credentials, JWTs, customer data or unredacted provider payloads in published artifacts.

Reassessment gate: PG and PAY scenarios all pass; target load and soak meet the agreed SLOs; every seeded financial/inventory invariant reconciles; no unresolved P0/P1 correctness/security finding remains; and results reproduce from a fresh environment. A faster response time cannot compensate for duplicate fulfillment or overselling.

Estimated effort after validation-environment access: **4–6 working days** for setup, harnesses and initial evidence, plus time for defects discovered. No implementation, service startup, infrastructure change, payment transaction or load run has been performed while writing this plan.
