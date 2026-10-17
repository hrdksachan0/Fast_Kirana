# FastKirana payment/cart recheck — 17 October 2026

Reviewed commit: `e64a096f`. This report rechecks the six payment/cart findings in the [16 October report](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_LATEST_2026-10-16.md). **Four issue groups remain in this scope: one P1 coupon/underpayment bypass and three P2 financial/cart consistency problems.**

Application code and existing tests were not changed. No commits, real SDK payments, external HTTP, production database/service writes or deployment actions were performed. Temporary review probes were removed from the repository and retained in the local Temp directory.

## Verification

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, dotenv disabled, external sockets/HTTP blocked | **235 passed, 0 failed**, 267 warnings |
| Next.js unit suite | **147 passed**, 21 suites, 0 failed |
| TypeScript `tsc --noEmit --incremental false` | **Exit 0**, no errors |
| Targeted Dart analysis of six checkout/cart files | **No issues**, exit 0 |
| Independent full Flutter suite: `flutter test --no-pub --no-enable-impeller --reporter expanded` | **300 passed, 0 failed**, exit 0 |
| Actual FastAPI quote → durable intent → recovery diagnostics | **11 completed**, exit 0 |
| Actual Flutter payment/controller diagnostics | **7 completed**, plus **1 fresh-process replay**, exit 0 |
| Actual cart notifier/repository diagnostics | **6 completed**, exit 0 |

A diagnostic that asserts the faulty outcome confirms the reproduction; it does not approve that behavior. Native channels and HTTP were mocked/intercepted. The restart probe restores exported actual mock-store preferences in a separate Dart process; it is not a physical-device termination test.

An initial independent full Flutter run was intentionally interrupted after detecting another full workspace run using the same asset directory. A fresh independent full run was then started after the other full run finished. The interrupted run is not counted as an application failure or a full pass. Targeted Dart analysis is not a newly executed full `flutter analyze`.

## Status of the previous six findings

| Previous finding | Current status |
|---|---|
| Negative/untrusted required fees and coupon eligibility | **Partial.** Negative/nonfinite inputs rejected; forged zero required fees overridden; simple wrong-category coupon denied. Scoped discount calculation still trusts client line prices, below. |
| Repricing accepted line prices after payment | **Partial.** A supplied correct line price survives catalog changes, but canonical server line prices are not persisted; omitted/forged prices still break the financial snapshot. |
| Missing intent fulfills a newer current basket | **Closed in the reproduced case.** Missing intent creates an `ADMIN_PENDING` placeholder, retains unrelated cart B and does not dispatch B. |
| Redundant second save destroys the committed draft | **Closed in the reviewed cases.** Post-launch controller save is removed; false/thrown replacement writes preserve the previously committed draft after reload. |
| Duplicate completion subtracts twice | **Partial.** Sequential/concurrent same-process calls subtract once; fresh-process replay and failed cart persistence remain incorrect. |
| Hydration loses the original cart or a newer revision | **Partial.** Distinct A+B merge and delayed server GET are correct. Same-product additions, clear semantics and the delayed pending-key boundary remain incorrect. |

## 1. [P1] Scoped coupon discount is computed from a forged client price

**Where:** [cashfree_router.py:403](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:403), [eligible amount and discount:420](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:420), [minimum amount:447](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:447).

An actual quote → durable intent → paid recovery sequence produced:

```text
Catalog product price = 100
Genuine category-scoped coupon = 50%
Submitted item.price = 1000
Computed discount = 500
Gateway amount = 1
Recovery = CONFIRMED
Order subtotal = 100, delivery = 25, misc = 5, total = 1
Recovered line price = 1000
```

The new fee validation closes the earlier negative-fee attack, but eligible coupon subtotal still uses raw `item.price`. Flooring the final amount at ₹1 then permits a massively inflated discount to authorize fulfillment.

**Implement:**

1. Resolve canonical product/variant, quantity, unit price and eligibility from trusted server data once.
2. Calculate restricted eligible subtotal and discount from those resolved lines. Cap discount to the true eligible amount.
3. Persist those canonical lines and quote totals before issuing the payment session; reuse them for order placement and recovery.
4. Treat client prices/category metadata as untrusted input. A database field being null must not authorize a request-supplied eligibility override.
5. Keep the finite/nonnegative checks and server-derived required fees. Share configured delivery/packaging and coupon rules across the payment and normal-order paths.

**Acceptance:** With catalog100 and a genuine 50% coupon, forged price1000 must not produce discount500 or charge1. Test forged/omitted/zero/nonfinite prices, variant prices, scoped flat/percentage/free-delivery coupons, spoofed category/restaurant/menu metadata and customer usage restrictions. Verify exact quote/line/discount/fee/total consistency.

## 2. [P2] Accepted order lines are raw client values or current catalog values

**Where:** [intent items:524](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:524), [real gateway intent:624](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:624), [recovery prices:1331](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1331).

The stored totals are now retained, but stored item lines remain raw `effective_items`. Recovery trusts a supplied positive price or falls back to today's catalog.

Actual reproductions:

| Case | Result |
|---|---|
| Catalog100, client line price1, gateway130 | `CONFIRMED`, subtotal100, **OrderItem.price1** |
| Omit optional item.price; accept100 − coupon20 + fees30 =110; catalog becomes120 | `CONFIRMED`, total110/subtotal100, **OrderItem.price120** |
| Correct supplied line100; same catalog change | `CONFIRMED`, accepted line100/subtotal100/total110 — control passes |

Correct aggregate totals alone do not establish a complete accepted financial snapshot. Order-line values can disagree with subtotal, invoice calculations and the accepted transaction.

**Implement:** Persist the server-resolved accepted unit price for every line, including variants, independently of request shape. Recover only these canonical accepted values. Check current inventory separately. Validate line sums, discounts, fees and total under one rounding policy.

**Acceptance:** Omitted or forged client prices cannot become order prices. Catalog/variant/coupon/configuration changes after payment-session creation cannot reprice the accepted lines. Keep the passing correct-price control.

## 3. [P2] Durable cart acknowledgement is neither replayed nor committed with cart changes

**Where:** [checkout_controller.dart:1308](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1308), [persistent marker:1314](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1314), [subtraction:1323](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1323).

The static set suppresses duplicate cleanup in one process. Persistent membership only prevents appending another marker; it is not used to suppress cleanup after restart.

Actual fresh-process replay:

```text
Accepted ordered quantity = 1
Process 1: cart 3 → 2; acknowledgement persisted
Process 2: same persisted acknowledgement and cart2 restored
Replay same durable order: cart2 → 1
Expected = 2
```

The acknowledgement also precedes cart persistence. A separate storage-failure probe observed:

```text
Acknowledgement committed
Cart disk write fails; completion throws
UI = 2, durable cart = 3
Retry skips cleanup because static acknowledgement exists
Durable cart remains 3
```

**Implement:** Load durable owner/hub/order acknowledgements before cleanup. Commit the cart delta and its acknowledgement together, or use a resumable journal that can distinguish not-applied, applied and acknowledged state. Preserve recovery until acknowledgement succeeds. Moving the marker after subtraction alone leaves the opposite crash window.

**Acceptance:** Repeat/race callbacks in one process and in a fresh process. Inject failure before and after each acknowledgement/cart persistence boundary, then restart. Apply the purchased quantity once and retain newer quantities. A distinct real order must still apply its own delta.

## 4. [P2] Hydration union loses add intent and resurrects clear intent

**Where:** [cart_provider.dart:220](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:220), [matching row skipped:227](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:227), [unguarded key await:258](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:258).

Actual notifier/repository results:

| Operation while old local read is held | Final observed result | Required result |
|---|---|---|
| Saved A2; add distinct B1 | A2+B1 everywhere, pending=false | A2+B1 — **closed** |
| Saved A2; add A1 | A1 everywhere, pending=false | A3 |
| Saved A2; clear | DELETE succeeds, then stale hydration POST restores A2 | Empty |
| Saved A2; clear then add B1 | A2+B1 | B1 |
| Hold startup pending-key resolution; add B1 | Server A1, UI/local A1+B1; pending=false, version=ack2 | Matching synchronized latest state |
| Hold server GET; add B1 | B1, pending=false | B1 — **closed** |

The pending-key case deliberately delays that async seam; production frequency is unmeasured. The same-product and clear cases delay the initial local-storage read.

**Implement:** Gate mutations until hydration is ready, or replay ordered mutation intents against the loaded base. A union of final item lists cannot represent add deltas, remove or clear. Revalidate owner/hub/generation/revision after asynchronous reads, including pending-key resolution. Acknowledge only the synchronized snapshot.

**Acceptance:** Delay each hydration boundary and apply add/increment/decrement/remove/clear, including same SKU/variant, pending true/false and owner/hub changes. Assert correct quantities, tombstones, equal local/UI/server contents and pending revision. Keep the passing distinct-add and delayed-GET controls.

## Antigravity implementation order

1. Implement a canonical server line resolver and quote policy; use it for coupon eligibility, intent persistence and recovery (findings1–2).
2. Make Flutter cart-delta acknowledgement durable and resumable across callback races, storage failure and restart (finding3).
3. Replace hydration union with mutation replay or an explicit ready-state policy (finding4).
4. Add regression assertions for the intended behavior of every reproduction, then run the full suites.
5. Run isolated PostgreSQL worker contention and signed-device payment lifecycle checks before release approval. SQLite passing does not establish production worker isolation.

The [Next.js pre-order route](D:/Fastkirana/src/app/api/payment/cashfree/create-order/route.ts:58) remains unchanged and accepts client amount/raw Redis draft. This is a source-confirmed parity gap, not a newly demonstrated Next.js fulfillment exploit. Delegate active callers to the authoritative quote contract or implement equivalent trusted validation. Read the relevant installed Next.js documentation before changing Next.js code, as AGENTS.md requires.

## Broader backend findings are tracked separately

The concurrent workspace review produced a [combined backend/security handoff](D:/Fastkirana/docs/ANTIGRAVITY_COMBINED_HANDOFF_2026-10-17.md). It also records SSE identity/assignment authorization, backend cart-row cleanup, and Redis reservation/commit behavior, plus credential-revocation evidence still needed. Those additional scenarios were not independently rerun in this payment/cart recheck. This report closes no finding outside its six-entry status table.

The combined report's Python234 count excludes the migration smoke module; this recheck's Python235 count includes it under external network/HTTP blocking. They are different recorded scopes, not conflicting counts.

## Evidence and source stability

Diagnostic sources/logs are retained in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck9-backend-20261017.log`
- `fastkirana-recheck9-run-backend-20261017.py`
- `fastkirana-recheck9-node-20261017.log`
- `fastkirana-recheck9-tsc-20261017.log`
- `fastkirana-recheck9-analyze-20261017.log`
- `fastkirana-recheck9-flutter-final-20261017.log`
- `fastkirana-recheck9-backend-probe-20261017.py`
- `fastkirana-recheck9-quote-recovery-final-20261017.log`
- `fastkirana-recheck9-payment-probe-20261017.dart`
- `fastkirana-recheck9-payment-probes-phase1-20261017.log`
- `fastkirana-recheck9-payment-probes-phase2-20261017.log`
- `fastkirana-recheck9-payment-restart-prefs-20261017.json`
- `fastkirana-recheck9-cart-probe-20261017.dart`
- `fastkirana-recheck9-cart-20261017.log`
- `fastkirana-recheck9-snapshot-20261017.json`

The twelve snapshotted files retained the same SHA-256 hashes through the focused checks and final full Flutter run. Reviewed HEAD remained `e64a096f`. The fresh independent Flutter suite completed with 300 passing tests in 53 seconds, exit 0; no temporary review probes were included. This review does not test production services, live settlement, a signed native build or physical-device restart behavior.

