# FastKirana — combined Antigravity handoff and independent recheck

**Updated: 17 October 2026 · Reviewed commit: `e64a096f`**

Use this as the current implementation checklist. It combines the supplied 16 October checkout/cart report with the independent Python security/payment report, then updates their findings against the latest code and fresh verification. FastAPI/Python is the primary backend; Flutter and the remaining Next.js payment route are included where they cross the same payment/cart boundary.

**Decision: fixes have progressed, but seven issue groups remain open or partial. Green suites do not yet establish release readiness.** Application source was not changed during this review. No production database, gateway, Redis, notification, printing, deployment, or credential-revocation action was performed.

## 1. Fresh verification

| Check | Current result | Evidence |
| --- | --- | --- |
| Python suite, isolated SQLite | **234 passed; 0 failed/errors/skipped**, 260 warnings | [Results and source hashes](D:/Fastkirana/docs/verification/2026-10-17-python-results.json), [log](D:/Fastkirana/docs/verification/2026-10-17-python-suite.log) |
| Flutter full suite, Skia | **300 passed; 0 failed** | [Log](D:/Fastkirana/docs/verification/2026-10-17-flutter-suite.log) |
| Next.js unit suite | **147 passed; 21 suites; 0 failed** | [Log](D:/Fastkirana/docs/verification/2026-10-17-node-suite.log) |
| TypeScript `tsc --noEmit --incremental false` | **Exit 0; no errors** | [Verification summary](D:/Fastkirana/docs/verification/2026-10-17-verification-summary.json) |
| Targeted Dart analysis, six checkout/cart files | **Exit 0; no issues** | [Log](D:/Fastkirana/docs/verification/2026-10-17-dart-analysis.log) |
| Backend/security diagnostic scenarios | **23 recorded** | [Structured results](D:/Fastkirana/docs/verification/2026-10-17-probes.json), [log](D:/Fastkirana/docs/verification/2026-10-17-backend-probes.log) |
| Flutter diagnostics | **7 completed: four controls and three fault reproductions** | [Log](D:/Fastkirana/docs/verification/2026-10-17-flutter-probes.log) |

The Python command covers `tests/` except `tests/test_migration_full.py`, which contains incompletely isolated gateway/KOT operations. It uses dummy credentials, disabled dotenv loading, and blocks external sockets. The supplied older report's 235-pass number is historical; this run collected 234 under the recorded scope. Do not combine counts across runs.

Backend probes execute current functions with fake ORM/cache objects; Redis probes execute exact source blocks with simulated transaction state. Flutter diagnostics mock/intercept storage, native channels, and HTTP. Some diagnostics intentionally assert the reproduced faulty result: a passing diagnostic establishes the reproduction, not acceptable behavior. Targeted analysis is not a new full `flutter analyze`. Live PostgreSQL concurrency and signed-device payment behavior remain unverified.

## 2. Consolidated status of previous findings

| ID | Area | Updated status |
| --- | --- | --- |
| A01 | Hardcoded Firebase private key | **Source fix verified; revocation evidence pending.** Literal fallback removed. Historical key revocation cannot be inferred from deleting code. |
| A02 | Anonymous FCM account binding | **Original attack closed.** Supplied victim ID/phone now registers a separate guest; victim device token remains and is not deleted. |
| A03 | Single-order SSE authorization | **Partial; P1 remains.** Anonymous 401, unrelated customer 403, owner 200. A blocked/demoted user's still-signed admin query token is accepted; assigned rider is incorrectly rejected. |
| A04 | Authoritative fees and coupon eligibility | **Partial; P1 remains.** Negative fee now 400; spoofed zero delivery/packaging becomes server default ₹130. Coupon calculation still trusts client line prices/category fallback. |
| A05 | Accepted financial snapshot | **Partial; P1 remains.** Accepted total/subtotal survive catalog changes, but order line prices remain raw client/current catalog values. |
| A06 | Missing-intent basket recovery | **Original attack closed.** Missing intent produces `ADMIN_PENDING`, leaves current cart and inventory unchanged, and does not fulfill a substitute live basket. |
| A07 | Destructive second draft save | **Reviewed cases closed.** Redundant post-launch save removed. Replacement writes returning false or throwing preserve the original durable draft. |
| A08 | Backend selective cart cleanup | **Partial; P2 remains.** Replacement row with a new ID survives. All captured cart IDs are deleted, including unpurchased items and newer quantities on the same row. |
| A09 | Flutter duplicate completion cleanup | **Partial; P2 remains.** Concurrent callbacks in one process subtract once. Persisted acknowledgement does not suppress cleanup after restart. |
| A10 | Cart hydration races | **Partial; P2 remains.** Delayed initial load plus adding a different product preserves both. Clear resurrects the old basket; delayed pending-key resolution loses a queued revision. |
| A11 | Redis inventory rollback | **Partial; P2 remains.** Rejected hub check releases reservation. Exception handling after SQL commit also releases a committed sale's reservation. |

Retain earlier protections for invalid quantities, aggregated hub/variant demand, canonical payment consumption, and legitimate ₹80 coupon recovery. The current variant-zero-hub probe remains quarantined with unchanged stock.

## 3. Open work for Antigravity

### A04 — P1: calculate coupons and fees entirely from server data

A real catalog item costs ₹100 and belongs to the coupon's eligible category. Sending line `price=1000` with its valid 20% category coupon produces:

```text
Authoritative subtotal: 100
Calculated discount: 200
Payment quote / mocked paid amount: 1
Recovered status: CONFIRMED
Product and hub stock: 2 -> 1
Recovered line price: 1000
```

Coupon evaluation takes client price at [cashfree_router.py:403](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:403). Category/restaurant/menu fallbacks also take request metadata when the database field is empty at [line 405](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:405). A second probe spoofed category and price together and obtained the same ₹1 confirmation. The simple wrong-category control without spoofing now receives the full ₹100 quote; that narrow fix is insufficient.

**Implement:** derive canonical SKU/variant/quantity, price and eligibility from trusted records. Calculate eligible subtotal from canonical prices and cap discount against the true eligible amount. Enforce full scope/usage rules. Share quote policy with ordinary placement and recovery, including configured hub/address delivery and packaging rules. Hardcoded ₹25/₹5 defaults do not establish settings parity. Preserve finite/nonnegative checks and prevention of forged zero required fees.

**Acceptance:** inflated/negative/nonfinite prices, forged category/menu/restaurant, zero-fee overrides, invalid quantities, exhausted usage and out-of-scope coupons cannot reduce the payable total or authorize dispatch. Valid flat/percentage/free-delivery coupons, variants, custom delivery settings, pickup, tips, premium packaging and hub prices must agree across paths.

**Next.js parity:** the pre-order branch at [route.ts:58](D:/Fastkirana/src/app/api/payment/cashfree/create-order/route.ts:58) still accepts client `amount`; [line 113](D:/Fastkirana/src/app/api/payment/cashfree/create-order/route.ts:113) builds a raw draft for Redis. Delegate active callers to the Python authoritative quote or enforce the same trusted contract. This is source-confirmed, not a demonstrated Next.js fulfillment exploit. Before changing Next.js code, follow `AGENTS.md` and the relevant installed Next.js guide.

### A05 — P1: persist canonical accepted lines, not just totals

Recovery trusts raw intent item price when a quote exists at [cashfree_router.py:1332](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1332), then overrides subtotal from the quote at [line 1407](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1407).

| Executed scenario | Current result |
| --- | --- |
| Catalog ₹100, client item price ₹1, paid ₹100 | `CONFIRMED`; subtotal/total ₹100; line price ₹1 |
| Accepted ₹100 without client price; catalog becomes ₹120 | `CONFIRMED`; subtotal/total ₹100; line price ₹120 |

The former false-underpayment quarantine is removed, but financial lines remain inconsistent and can be caller-controlled.

**Implement:** persist canonical server-validated line prices, variants, quantities, discounts, fees, currency, owner, hub and attempt reference before exposing the usable payment session. Restore those accepted lines; recheck stock independently. Expired quotes require re-acceptance before charging, not financial repricing afterward.

**Acceptance:** catalog/variant, coupon or fee changes after acceptance do not change accepted lines. Raw client prices never become authoritative order prices. Line sums, subtotal, discounts, fees and total remain consistent under the rounding policy.

### A03 — P1: use database-backed identity and correct scope for SSE

The query/header fallback at [websockets.py:727](D:/Fastkirana/fastapi-backend/routers/websockets.py:727) decodes a signed token without reloading active database identity/role. A probe supplied a still-signed ADMIN query token for a database user who is now USER and blocked. It streamed another customer's order with HTTP 200. A signature does not establish current privileges or active status.

The rider check at [line 751](D:/Fastkirana/fastapi-backend/routers/websockets.py:751) reads `deliveryPartnerId`; the model uses `deliveryUserId`. The assigned-rider control received 403. The staff branch also lacks a store/restaurant scope check.

**Implement:** use the same verified database identity and scope policy as protected order/WebSocket paths, including query-token access if retained. Reject blocked/revoked identities, purpose-limited WebSocket tickets used as REST credentials, and unrelated tenant access. Resolve assigned rider through the actual model relation. Authorize before emitting data and define revalidation/stream-close behavior when assignment/status changes.

**Acceptance:** missing identity 401; unrelated customer and wrong-store staff denied; blocked/demoted token denied; owner and assigned rider allowed; unassigned rider denied; purpose-limited tickets cannot become general order credentials.

### A08 — P2: clean only the purchased cart delta

Quote creation captures **all** cart row IDs at [cashfree_router.py:442](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:442). Recovery deletes every captured row at [line 1560](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1560), without checking ordered SKU or accepted quantity.

Executed cases:

- Buy A only while cart contains A and unpaid B: both are deleted.
- Buy default while cart also contains Small 3 and Large 4: all three rows are deleted.
- Accept quantity 1, then increase the same row to 3: all 3 are deleted instead of leaving 2.
- Remove old row and add a replacement with a new ID: replacement now survives; retain this control.

**Implement:** bind each ordered line to accepted cart identity, variant, quantity and revision. Apply only its purchased delta, once, with concurrency-safe conditions. Presence in the cart at payment-session creation does not mean an item was purchased. Distinguish an explicitly empty accepted cart set from legacy missing metadata. Verify the legacy fallback independently.

**Acceptance:** unpaid B/other variants remain; current 3 minus accepted 1 leaves 2; replacement rows survive; buy-now and legacy attempts preserve unrelated rows; repeated recovery/concurrent edits do not subtract twice or fail on an empty match.

### A09 — P2: honor durable completion acknowledgements after restart

At [checkout_controller.dart:1308](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1308), only the static in-memory set prevents subtraction. The saved `acknowledged_order_ids` list is read at [line 1314](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1314), but finding an existing ID does not skip cart mutation.

Two concurrent callbacks for a fresh order change quantity 3 -> 2 once. With that order ID already persisted and fresh in-memory state, replay still changes 3 -> 2; correct result is 3 because this order was already acknowledged.

**Implement:** coordinate durable acknowledgement and the original cart delta across restarts/concurrent completion paths, scoped to owner/hub/attempt/order identity. Failed cleanup or failed marker persistence must remain recoverable rather than silently marking work finished. Late callbacks must not recreate finalized drafts.

**Acceptance:** sequential/concurrent SDK, retry and status callbacks subtract once; restart replay subtracts zero additional units; a different order applies its own delta; storage failures and restart between mutation/acknowledgement cannot cause lost or repeated cleanup.

### A10 — P2: preserve hydration mutations, tombstones and generations

The merge at [cart_provider.dart:219](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:219) fixes the simple add-during-load example but performs an additive union. Delayed load followed by `clearCart()` restores saved `oldA` to UI/local/server and clears pending status. Correct clear intent leaves all three empty.

The await at [line 258](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:258) still follows the previous generation guard. Holding it, then adding B, produced server `[oldA]`, UI `[oldA, newB]`, `pending=false`, `version=ack=2`. This is a controlled async seam; no production-frequency estimate is claimed.

**Implement:** gate mutations until the base is known, or replay ordered mutation intents against that base, including clear/remove tombstones and quantity deltas. Revalidate owner/hub/generation after every async boundary. Acknowledge only the exact synchronized revision.

**Acceptance:** hold local read, pending-state read, pending-key resolution, server GET and startup POST; then add/increment/remove/clear or switch owner/hub. Local/UI/server agree; pending remains true until the newest revision is acknowledged. Preserve simple additive merge and earlier delayed-GET/POST controls.

### A11 — P2: do not compensate inventory after successful SQL commit

The rejected-hub probe now restores Redis stock 2 -> 2; retain that improvement. However, reservation tracking remains populated after [orders.py:2237](D:/Fastkirana/fastapi-backend/routers/orders.py:2237). The broad exception handler at [line 2478](D:/Fastkirana/fastapi-backend/routers/orders.py:2478) refunds tracked reservations even if publication fails after commit.

Executing that exact handler with a simulated committed sale produced database stock 1 and Redis stock 2. This is an exact-handler/simulated-transaction probe, not live Redis/PostgreSQL testing.

**Implement:** make the commit boundary explicit. Compensate only reservations whose business transaction did not commit. Preserve sold inventory after commit; retry post-commit publication separately. Define cancellation, restock, expiration and reseeding behavior.

**Acceptance:** pre-commit failures and commit failure restore every reservation exactly once; publication failure after successful commit never refunds sold stock; replay returns the same durable order; Redis-up/down paths retain stock correctness.

## 4. External and integration verification still required

**A01 credential exposure:** current source contains no embedded private-key literal. Confirm the previously committed key was revoked/rotated and the replacement uses deployment secrets. Removing source text does not revoke historical credentials. Key material is deliberately absent here; no live validity/revocation check was attempted.

**PostgreSQL concurrency:** the green SQLite StaticPool/four-thread fixture does not establish independent-worker PostgreSQL isolation. Use independent connections/processes in a dedicated test database, with Redis available and unavailable. Assert one durable order, one completed consumption/idempotency result, one stock decrement, correct rollback, and replay after cache loss. Inject pre-commit and post-commit publication failures. Do not weaken durability assertions or call the passing SQLite test a current production failure.

**Native payment lifecycle:** verify signed test builds on real devices using the gateway test environment: callback/status overlap, cancellation, app termination, restart, network loss and first/replacement storage failure. Mocked probes do not establish gateway settlement or native release behavior. Production credentials, deployed services and knowledge-graph freshness were not verified.

## 5. Execution order and completion contract

1. Confirm A01 key revocation; preserve A02 guest binding.
2. Fix A03 database identity/scope and rider authorization.
3. Implement A04/A05 canonical server quote and accepted line snapshot; align every active payment-creation route.
4. Fix A08 purchased-delta cleanup and A09 durable completion acknowledgement together.
5. Fix A10 hydration mutations/generations and A11 commit-aware reservations.
6. Add behavior-based regressions for every reproduction, then run relevant suites and isolated PostgreSQL/native checks.

Return a closure table keyed by A01–A11 with changed files, reproduction before/after, exact commands/results, source commit/hashes and remaining external verification. Preserve the closed negative-quantity, hub/variant, valid-coupon, missing-intent, first-save and replacement-save controls. Aggregate green counts alone do not close these findings.

## 6. Evidence and scope

- [Verification summary and source snapshot](D:/Fastkirana/docs/verification/2026-10-17-verification-summary.json).
- [Backend probe source](D:/Fastkirana/docs/verification/recheck_2026_10_17.py), reusing retained fake ORM/cache definitions without running the old harness main routine.
- [Flutter diagnostic source](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_17_test.dart). Its temporary copy inside the Flutter test directory was removed after execution.
- [Earlier Python/security report](D:/Fastkirana/docs/INDEPENDENT_BACKEND_RECHECK_2026-10-16_R2.md) and [supplied checkout/cart report](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_LATEST_2026-10-16.md) remain historical references. The status table above governs this snapshot.

This handoff records review evidence and required work. It does not claim the reviewer implemented application fixes or verified a production release.
