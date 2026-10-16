# FastKirana recheck and Antigravity handoff — 16 October 2026

This report supersedes the remaining-findings status in the 15 October report. Reviewed the latest saved, uncommitted Flutter changes and their FastAPI payment boundary. No application fixes, commits, deployments, real payments or production database changes were performed.

## Independent verification

| Check | Result |
|---|---|
| Full Flutter suite, explicit Skia: `flutter test --no-pub --no-enable-impeller` | **268 passed, 0 failed** |
| Dart analysis of checkout controller, payment handler, draft, cart provider/repository and success screen | **No issues**, exit 0 |
| Full FastAPI suite, isolated SQLite, external HTTP blocked | **228 passed, 1 failed**, 255 warnings |
| Failing backend case | `test_concurrent_workers_idempotency_with_redis_down`, line 1012: successful response observed, but the test database contained zero orders |
| Focused actual Flutter handler/controller/notifier/repository probes | **8 diagnostic cases completed** |
| Focused actual FastAPI quote/recovery probes, isolated SQLite | **2 diagnostic cases completed** |
| Next.js unit tests / TypeScript | Previously passed; not rerun in this Flutter follow-up |

Several diagnostic probes deliberately assert the observed faulty state. Their completion confirms the reproduction, not correctness of those paths. Native SDK and HTTP calls were mocked/intercepted. The main Flutter suite passed with explicit Skia; a default-renderer run is not claimed.

## Fixes verified closed or substantially corrected

- **SDK launch is aborted on both thrown and false accepted-draft writes.** Both probes returned null, made no native payment call, and removed the pending Cashfree ID. A successful-write control launched normally and retained the durable draft. The earlier SDK-launch-after-write-failure defect is closed; the cache-state issue below remains.
- **Online mode and accepted hub now survive recovery.** The actual controller submitted UPI and the accepted hub while its current state/hub differed.
- **Positive accepted fees survive recovery.** Accepted delivery 12 and packaging 9 were submitted as 12 and 9, with accepted total 121.
- **Success-screen whole-cart clear has been removed.** Background retry now passes its ordered items to selective completion.
- **Unit-bearing and explicit variants now subtract correctly in the tested Flutter case.** Ordering one default-unit item and one explicit variant retained the remaining quantities and unrelated B.
- **The old delayed startup POST race is closed.** The actual queue produced old-A POST completion followed by new-B POST completion; server/UI both ended at B with pending=false.

## Remaining findings and implementation plan

### 1. [P1] Connect Flutter payment creation to the complete validated quote

**Where:** [payment_gateway_handler.dart:54](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/payment_gateway_handler.dart:54), [checkout_controller.dart:683](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:683), [cashfree_router.py:294](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:294).

The backend now understands coupon information in `orderPayload` / `cartPayload`, but Flutter sends only amount, identity/address, items and delivery method. Its saved coupon/discount/fees/hub snapshot is not included in the create-payment request.

The native handler probe captured no coupon or orderPayload in the request. An actual FastAPI handler probe seeded a real active flat ₹20 coupon and a ₹100 product in isolated SQLite:

```text
accepted amount = 80
actual Flutter-shaped request -> gateway orderAmount = 100
same request + coupon metadata -> gateway orderAmount = 80
```

The control's durable intent still stored amount/items/scope but omitted the validated coupon and full fee breakdown. This is an incomplete contract across payment creation, persistence and recovery.

**Implement:**
1. Submit the accepted checkout data, or a server quote ID, from Flutter before payment-session creation.
2. Validate coupon eligibility and all quote components on the server. Persist the complete validated quote and bind it to the attempt/payment.
3. Use that same quote for Cashfree amount, mobile acknowledgement, normal order placement and webhook recovery.
4. Reject an inconsistent request or request explicit re-acceptance of a changed quote; do not silently charge a higher amount.
5. Keep the same contract on both backends.

**Acceptance:** Seed a valid ₹20 coupon against a ₹100 product and submit the actual Flutter request. Gateway, durable intent, client display and final business order must all use ₹80. Include valid percentage/free-delivery coupons, invalid coupons, tips, packaging, hub changes and response-loss recovery.

### 2. [P1] Preserve accepted zero fees instead of recalculating them

**Where:** [checkout_controller.dart:888](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:888).

Recovery uses saved delivery/packaging fees only when greater than zero. A valid zero therefore falls through to current settings/tier fees, even though the saved grand total is retained.

Actual controller probe:

```text
accepted delivery=0, packaging=0, total=100
submitted delivery=25, packaging=7, total=100
payment=UPI, store=accepted hub
```

The submitted breakdown disagrees with the accepted transaction and its own total.

**Implement:**
1. Distinguish an absent legacy field from a valid zero using field presence/schema version.
2. For a complete accepted draft, use the saved fee values including zero.
3. Preserve the accepted quote's fulfillment origin and validation context too; current cart/settings must not rebuild an already-paid quote.
4. Handle incomplete legacy drafts through deterministic server reconciliation rather than a silent current-settings fallback.

**Acceptance:** Recover paid drafts with zero delivery, zero packaging, free delivery, pickup and positive fees after settings change. Every quote component and total must remain consistent.

### 3. [P1] Repair the backend cart-fallback recovery branch

**Where:** [cashfree_router.py:1201](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1201), [local import at line 1399](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1399).

The new selective cleanup includes `from models import CartItem` inside the recovery function. Python consequently treats CartItem as a local variable throughout that function. The earlier cart fallback reads it before that import executes.

An actual recovery probe seeded a buyer, product and cart, removed cached/durable intent, and supplied a paid gateway event:

```text
result=None
Auto-Recovery FATAL:
cannot access local variable 'CartItem' where it is not associated with a value
```

This prevents the fallback from recovering the paid order.

The same fallback also reads `ci.price` at lines 1212/1217, while the actual [CartItem model](D:/Fastkirana/fastapi-backend/models.py:201) has no price attribute. That is a source-confirmed follow-on error to fix in the same branch.

**Implement:**
1. Remove the function-local shadowing and use the intended module-level model.
2. Align fallback reads with the actual CartItem schema and authoritative product/variant pricing.
3. Define safe reconciliation when the original accepted snapshot is unavailable. Do not silently equate an unrelated current cart with the paid basket.
4. Test the no-intent fallback and selective cleanup together, including null/unit/explicit variants and newer quantities.

**Acceptance:** A paid event without cached/durable intent but with an existing buyer/cart must reach the defined recovery/manual-reconciliation outcome without a scope/attribute exception. Normal durable-intent recovery must continue to work and preserve unrelated cart additions.

### 4. [P2] Protect mutations made before local cart hydration completes

**Where:** [cart_provider.dart:217](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:217), [lines 228–231](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:228).

The queued startup POST is fixed, and server GET hydration has a version guard. An earlier window remains: local storage is read asynchronously, then its old items are published and assigned to the queue without checking whether a user edited the cart while that read was pending.

The actual notifier/repository probe delayed the first local read, added new-B, then completed the old-A read:

```text
server=[old_A]
UI=[old_A]
local storage=[new_B]
pending=false
```

The new edit disappears from the visible/server cart and its retry signal is cleared.

**Implement:**
1. Capture the owner/hub/generation before the first asynchronous hydration read.
2. Preserve and replay edits made during loading against the loaded base, or block mutation until hydration completes with a clear UI policy.
3. Do not overwrite the latest queued revision with the stale read.
4. Make a clear intent win over an older nonempty cache and preserve dirty/tombstone metadata across restart.

**Acceptance:** Delay local storage, then add, increment, remove and clear before loading finishes. Include pending=true/false and scope changes. Keep the already-passing delayed startup POST regression.

### 5. [P2] Remove the phantom accepted draft from cache after failed persistence

**Where:** [checkout_draft.dart:174](D:/Fastkirana/fastkirana_flutter/lib/data/models/checkout_draft.dart:174), [payment_gateway_handler.dart:85](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/payment_gateway_handler.dart:85), [controller restoration at line 153](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:153).

SDK abort and pending-ID cleanup now work. However, legacy SharedPreferences updates its cache before the platform write. Both failure probes observed:

```text
SDK calls=[]
pending ID=null
cached accepted draft=cf_review_failed_attempt
after preferences reload: durable accepted draft=null
```

Controller initialization falls back from a missing pending ID to `draft.cfOrderId`. Navigating away and reopening checkout in the same process can therefore restore an uncommitted attempt as pending, despite no payment SDK having launched.

**Implement:** Roll back/restore or explicitly invalidate the accepted-draft cache on failure. Recovery must admit only committed accepted transactions. Keep a safe server intent reference where needed, but do not present a failed local preparation as a launched payment.

**Acceptance:** Throwing and false writes must abort SDK launch and leave no recoverable phantom attempt both before and after storage reload. Recreate the controller in the same process, then simulate a process restart. The next legitimate purchase must remain usable.

## Backend full-suite failure still requires resolution

The current full suite failed `test_concurrent_workers_idempotency_with_redis_down` at line 1012. This run observed a successful response but then zero durable orders in the test database. Earlier full runs failed the same case with no successful response.

The fixture uses concurrent requests backed by one SQLite StaticPool connection. Shared rollback/transaction behavior remains a plausible cause; this review does not establish it as the sole cause or claim the same failure occurred against PostgreSQL.

Capture transaction ownership and conflict reasons, isolate the fixture correctly, and verify one durable accepted order with independent PostgreSQL sessions/workers and Redis unavailable. Do not weaken the durability assertion or treat a historical isolated pass as a green full run.

## Evidence retained

Files are in `C:/Users/Sooraj/AppData/Local/Temp`:
- `fastkirana-recheck7-flutter-20261016.log`
- `fastkirana-recheck7-analyze-20261016.log`
- `fastkirana-recheck7-backend-20261016.log`
- `fastkirana-recheck7-probes-final-20261016.log`
- `fastkirana-recheck7-quote-recovery-final-20261016.log`
- `fastkirana-recheck7-flutter-probe-20261016.dart`
- `fastkirana-recheck7-backend-probe-20261016.py`
- `fastkirana-recheck7-source-snapshot-20261016.json`

Temporary repository probes were removed after execution. Reviewed source hashes remained stable through verification. These local checks do not verify a signed native release, physical-device payment lifecycle, deployed environment or complete production acceptance.

