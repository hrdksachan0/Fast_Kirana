# FastKirana Antigravity implementation verification

Reviewed on 13 October 2026 against the complete Flutter/backend remediation handoff. Baseline HEAD: `103360d7`. This review covers the current uncommitted implementation; it does not approve a deployed environment.

**Result: partially implemented. Do not mark the handoff complete or approve release yet.** Several useful changes are present, but runtime, authentication, payment, cart and amount-consistency blockers remain. No application fixes or database migrations were performed during this review.

## Verification performed

| Check | Result |
|---|---|
| Flutter analyzer, `flutter analyze --no-pub` | Passed, no issues; 404.3 seconds |
| Full Flutter suite, `flutter test --no-pub --reporter expanded` | Passed, 268 tests |
| Node JWT hardening and campaign-auth tests | Passed, 15 tests |
| Local production-mode ticket endpoint, no credentials | Returned HTTP 200 and issued a signed ticket |
| Local production-mode order socket, no credentials | Accepted connection and rebroadcast an untrusted location event |
| General Next JWT verifier given a socket-purpose ticket | Accepted as a REST credential |
| General Next JWT verifier given a signed token without expiry | Accepted |
| New combined-order SQL expression in Cashfree module globals | Raised `NameError: name 'func' is not defined` |
| Ticket endpoint annotation on declared Python 3.11 | Raised `NameError: name 'Request' is not defined` |
| Entire WebSocket router import on local Python 3.14.4 | Passed; this does not validate Docker's Python 3.11 or CI's Python 3.12 |

The local socket probes used an isolated FastAPI app with the actual router, fake review-only identifiers and test signing secrets. They did not contact the deployed service, a payment gateway or a database. The Python 3.11 check evaluated the actual endpoint signature without its decorator/body; it is not a full Docker build. Node credential probes used the actual verifier and fake locally signed tokens. Existing tests do not exercise all failure paths below.

## Priority fixes and required regressions

### 1. [P0] Ticket endpoint annotation breaks the declared backend runtimes

`fastapi-backend/routers/websockets.py:213` annotates `request: Request` before importing `Request` at line 368. There is no postponed-annotation import. Docker declares Python 3.11 (`fastapi-backend/Dockerfile:1`), and CI declares Python 3.12 (`.github/workflows/ci.yml:26`). The actual signature fails under installed Python 3.11. The local Python 3.14 import succeeds because its annotation behavior differs.

**Fix:** Move the `Request` import above the endpoint definition. Keep a startup/import check on the declared Docker/CI versions. Do not treat the successful Python 3.14 smoke as sufficient. Python 3.11 evaluates function annotations when defining the function: [official reference](https://docs.python.org/3.11/reference/compound_stmts.html#function-definitions).

### 2. [P1] WebSocket tickets do not authenticate callers or authorize channels

`fastapi-backend/routers/websockets.py:210` issues tickets without an authentication dependency and accepts the caller's `userId` and channel. Order/rider/restaurant sockets verify credentials only when `APP_ENV == production AND auth_ticket` (lines 276, 313 and 342), so omitting the ticket bypasses validation. Both `/ws` and `/api/ws` aliases are mounted.

Tickets use the shared authentication key. `src/lib/jwt.ts:49` accepts their `sub` without checking token purpose/audience. A socket ticket was accepted by the actual REST verifier in a local probe. With the intended shared key and a real account ID, this creates a cross-protocol impersonation risk; no real account was probed.

**Fix:** Authenticate issuance, derive the owner from verified credentials, authorize the exact channel, require socket credentials, separate ticket purpose/audience from REST access tokens, enforce expiry and single-use policy, and constrain publication by role/assignment.

**Tests:** Anonymous issuance/subscription/publication rejection; cross-owner and cross-outlet rejection; REST rejection of socket tickets; expiry/reuse rejection; legitimate assigned-user connection. Test all mounted aliases.

### 3. [P1] Bearer and cookie authorization still bypass current account state

`fastapi-backend/routers/auth.py:46` immediately returns a valid Bearer payload before the new database checks. Flutter's Bearer requests therefore retain stale privileges after blocking, deletion, demotion or assignment changes.

The Next cookie session callback in `src/auth.ts:38` rereads role/assignments without selecting/checking block/deletion. It can restore ADMIN after the auth-config callback downgrades a blocked user. The cookie branch of `src/lib/auth-guard.ts:203` also omits those account states. The general verifier still accepts a missing expiry; the stricter campaign verifier is not proof that all routes are protected.

**Fix:** Run every accepted credential through one authoritative current-account policy, fail closed on verification outages, require expiry, and remove stale scope fallback when database assignments have been cleared.

**Tests:** Actual legacy/central route behavior after blocking, deletion, demotion and hub reassignment for both cookie and Bearer clients; missing expiry; legitimate login. Review remaining header-based identity shortcuts outside the central guard and the FastAPI JWT missing-secret fallback.

### 4. [P1] Combined paid-order verification raises an undefined-name error

`fastapi-backend/routers/cashfree_router.py:433` newly calls `func.sum(Order.total)` but never imports `func`. Existing unpaid combined orders with confirmed gateway payment can fail before updating payment state. Evaluating the exact new expression against the real module globals raised `NameError` locally.

**Fix:** Add the missing import and test the paid combined-order path, including idempotent repeated verification and the expected total across child orders.

### 5. [P1] Pending-payment UI does not lock checkout or persist recovery

`checkout_controller.dart:219` clears the busy flag for pending/unavailable verification. The sheet's Wait action dismisses it; `onWait` at line 248 does nothing. Checkout can then switch to COD and enter its placement path while UPI remains unresolved.

The controller is auto-disposed (`:108`), and its Cashfree ID is installed only after SDK launch (`:620`). The new checkout-draft provider has no live consumers or durable attempt storage. App termination/navigation therefore still loses client recovery state. Address, packaging and accepted amounts remain mutable and recomputed.

**Fix:** Persist a bound immutable attempt before launch; reconcile at startup/foreground; prohibit new payment/COD conversion until terminal resolution; use confirmed business-order acknowledgement for success.

**Tests:** Pending -> Wait -> COD; process termination before/after launch; duplicate callbacks plus webhook; callback after navigation; changed settings/address during pending payment; one logical order after recovery.

### 6. [P1] Cart clearing can repost the previous basket

`cart_provider.dart:378` increments the revision and sends deletion outside the sync queue, but does not replace `_latestPendingItems` with an empty snapshot. When an older request completes, the queue's finally branch at line 112 sees a newer revision and reposts the stale items.

**Fix:** Put the empty snapshot through the same queue; invalidate stale work and acknowledge the actual revision. Await the appropriate repository operation.

**Test:** Delay a nonempty POST, clear the cart, then complete the old POST. Local and server carts must both remain empty.

### 7. [P1] Older cart acknowledgements clear newer dirty state

`cart_repository.dart:55` clears the shared pending flag for every successful request before the notifier checks its revision. A newer unsent/in-flight edit can consequently appear clean. Current persistence defaults to `version: 1, isDirty: false`, restoration ignores those fields, dirty state is global, and cache identity omits the hub.

**Fix:** Persist owner, hub, revision and dirtiness together; clear only a matching acknowledgement; make account/hub switching and empty deletion follow the same durable protocol.

**Tests:** A succeeds while B remains pending followed by restart; offline account/hub change; guest merge; deletion retry; server revision conflict.

### 8. [P1] Tips are charged without order/accounting support; no common quote exists

Flutter now includes `tipAmount` in checkout/payment totals (`checkout_controller.dart:552`) and sends it in the order payload (`:951`). The inspected Next/FastAPI order paths and current order models do not process/store a dedicated tip. A selected tip can increase the gateway charge without the corresponding server order total or payout record.

Cart standard packaging remains hardcoded while checkout uses configured fees. Premium pickup also differs from the backend rule, and bill formatting continues to truncate paise. There is no accepted server quote shared by all paths.

**Fix:** Keep tips unavailable until supported end-to-end, or implement the explicit contract first. Use one server-validated quote/amount and preserve it through recovery. Make delivery/pickup and packaging calculations identical across cart, checkout, gateway and stored order.

**Tests:** Selected tip; configured standard fee; premium pickup; combined order; coupon removal; fractional prices; returned order amount equals charged amount.

### 9. [P1] Amount binding and durable deduplication are still incomplete

The new Cashfree amount comparison is bypassed by the no-business-order preflight return (`cashfree_router.py:396`). Subsequent order paths consume paid cache/status without proving the accepted amount. The added comparison tolerates underpayment up to INR 1 and all overpayment; it does not establish buyer/currency/checkout binding.

Existing CF-tag lookups help sequential replay, but are not an atomic shared uniqueness boundary. Flutter still creates new request keys, FastAPI deduplication remains process-local, and Next Redis has a memory fallback.

**Fix:** Bind buyer, gateway order, immutable quote, currency and exact amount. Persist operation-specific attempt keys and results with a durable shared uniqueness guarantee. Apply the invariant to preflight, submission, callback and webhook paths.

**Tests:** Unrelated paid session; amount/currency/owner mismatch; missing response; restart; backend failover; concurrent callbacks/webhooks; combined children created once.

### 10. [P2] Secure migration improved, but failed new-login persistence remains unsafe

OTP still writes a new token to plaintext preferences first (`otp_screen.dart:225`); staff login paths retain that sequence. If encrypted write/readback fails, the new plaintext credential remains. `secure_storage_service.dart:236` updates the in-memory token before persistence succeeds.

**Fix:** Eliminate direct credential preference writes and publish cached/authenticated state only after successful secure persistence. Test all staff/customer and background readers.

### 11. [P2] Shared draft, accessibility and tracking lifecycle are unfinished

`checkoutDraftProvider` is referenced only in its own definition. Cart instructions therefore still do not feed the default `ring_bell` checkout selection, and draft freeze/reset methods are unused.

App text scaling is capped at 1.5 (`main.dart:255`), common targets remain approximately 28x31/32x32, and inactive navigation remains small/faint. Campaign large-text tests do not certify the whole app builder. Progress still advances by timers, and final checkout still contains upsell.

The tracking refactor calls a MediaQuery-dependent marker helper from `initState`; debug dependency assertions can leave the custom icons uninitialized. Move dependency access to a safe lifecycle or pass resolved sizes.

**Tests:** Actual cart/login/checkout/back route continuity; 320/360/390 widths at 2x text; screen-reader activation; reduced motion; full tracking-screen first entry, not only individual tracking widgets.

### 12. [P2] Release-signing and financial migration gates are not complete

Release signing now logs missing configuration (`build.gradle:79`) instead of failing. An unsigned artifact is still not the required fail-closed release behavior. Validate every required signing field and certificate.

The decimal conversion is a standalone staged SQL file and documentation. Local Prisma (`schema.prisma:319`) and SQLAlchemy monetary fields remain Float. There is no staging/deployment evidence. Coordinate migration history, ORM mappings, amount arithmetic and JSON contracts before execution. A raw `.sql` directly in the migration root does not substitute for the normal Prisma migration-directory history: [Prisma reference](https://www.prisma.io/docs/orm/v7/prisma-migrate/understanding-prisma-migrate/migration-histories).

The staged single transaction alters multiple tables and can hold strong locks; rehearse on realistic staging data and establish timeout/rollback behavior. Do not infer safe locking from its use of `BEGIN/COMMIT`: [PostgreSQL ALTER TABLE reference](https://www.postgresql.org/docs/current/sql-altertable.html).

## Improvements verified

- Missing delivery addresses are blocked; fabricated Home/market copy was removed.
- The main location-tier path no longer assumes a serviceable 1 km distance for missing coordinates.
- Verification distinguishes paid/pending/failed/unavailable and offers a pending-state UI.
- Normal debounced cart writes are serialized and pending local recovery has improved.
- Secure migration verifies encrypted readback before deleting legacy credentials.
- Next JWT operations require a configured key and restrict the algorithm.
- Next Bearer role checks now load current account metadata.
- Semantic labels, address-book layout and production error presentation improved.

## Plan completion status

| Work packet | Status |
|---|---|
| Baseline/tests | Automated Flutter and targeted Node checks passed; missing behavioral cases listed above |
| Backend authentication | Partial; Bearer/cookie/ticket/expiry blockers remain |
| Credential migration | Partial; login failure and cache publication remain |
| Cart recovery | Partial; clear/ack/scope races remain |
| Shared checkout draft | Model/provider created; live flow not integrated |
| Address/serviceability | Improved; loading/error/unknown coverage and alternate tier paths remain |
| Quote and tips | Incomplete; charged/stored amount mismatch risk |
| Durable payment/idempotency | Incomplete; unresolved attempts remain escapable and non-durable |
| Accessibility/status | Partial; whole-flow acceptance matrix not verified |
| Signing/migration/native release | Not demonstrated complete |

## Next handoff to Antigravity

Fix the declared-runtime startup import and ticket/REST authorization first, then account-state authorization and combined verification. Implement the durable checkout/quote/attempt and exact payment binding before activating another payment path. Repair cart clear/ack/scoping with actual delayed-request tests, integrate the shared draft, finish storage/accessibility/signing gates, then repeat the relevant checks.

Keep the passing suite, but add regression tests exercising the actual controllers/routes. A green existing suite cannot close the demonstrated security and payment gaps. Native Cashfree, TalkBack, release certificates, PostgreSQL concurrency/migration and deployed configuration were not verified in this review.
