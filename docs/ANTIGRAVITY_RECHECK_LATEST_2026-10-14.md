# FastKirana latest saved-worktree verification — 14 October 2026

This report supersedes the open/closed status in the older reports. Reviewed the saved, uncommitted worktree; a Git commit is not required. No application fixes, deployments, real payment operations or production database changes were performed. Temporary probes used mocked dependencies or isolated SQLite.

## Independently verified in this follow-up

| Check | Result |
|---|---|
| Full FastAPI suite, isolated SQLite with external HTTP disabled | **218 passed, 0 failed**, 75.27 s; 187 warnings |
| Full Flutter test suite | **268 passed, 0 failed**, approximately 81 s |
| Dart analysis: checkout controller, checkout screen, cart provider, cart repository, checkout draft | **No issues** |
| Actual idempotency acquire → release → retry helper probe | Correct scoped Redis key removed; immediate retry admitted |
| WebSocket consumption probes, independent worker memory | Both Redis availability-transition directions reject replay |
| WebSocket DB + Redis outage, APP_ENV=production | **Replay accepted across workers: True, True** |
| Actual CartNotifier + CartRepository, mocked delayed DELETE and newer POST | **Local item present, server empty, pending=false** |
| Next.js unit tests / full TypeScript compilation | Previously passed; not rerun in this follow-up |
| Full Flutter analyzer / native release artifact / live payment lifecycle | Not rerun or verified in this follow-up |

Passing test suites do not cover every failure path below. The cart probe deliberately asserted the observed faulty state; its successful run is evidence of the race, not a passing correctness regression. Reviewed source files were unchanged between the final focused probes and report completion.

## Findings closed by the latest saved changes

- **Customer notes no longer select the payment recovery target.** The recovery query in `fastapi-backend/routers/cashfree_router.py:776`–785 uses explicit identifiers; the previous notes-marker binding exploit is closed. Buyer-phone checking and a durable consumed-payment record are now present.
- **Rejected-checkout release now removes the scoped lock.** `fastapi-backend/utils/idempotency.py` uses the matching scoped Redis key and database key. Actual helper output: first_duplicate=false; remaining_after_release=[]; retry_duplicate=false.
- **Successful Flutter background order retry now invokes completion.** `checkout_controller.dart:1266` calls the shared `_finishOrderPlacement` path, which clears recovery and refreshes order/cart state. The payment-order ID mix-up is also corrected.
- **Redis availability transitions no longer split successful WebSocket consumption.** The database ledger is now written on the normal path as well as during outage. Healthy → outage and outage → healthy probes both returned first-use=true, replay=false.
- **Provider acknowledgements now retain the captured owner/hub key.** The previous duplicate acknowledgement against the newly selected hub is closed.
- **Pending-payment status action and accepted-draft persistence now exist.** The older report's claim that no reconciliation action exists is obsolete. Full transaction restoration remains incomplete as detailed below.

## Remaining actionable findings and Antigravity implementation plan

### 1. [P1] Keep unresolved payments guarded when “Cancel & New Order” is pressed

**Where:** [checkout_controller.dart:1346](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1346), reached by [checkout_screen.dart:264](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/checkout_screen.dart:264).

**Observed path:** The button calls `cancelPendingPaymentSession`, which deletes both persisted recovery records and clears `pendingCashfreeOrderId`. It does not verify payment status, obtain a terminal cancellation acknowledgement, or retain a record for later reconciliation. The placement guard at controller line 437 therefore permits a new online/COD order even while the original gateway payment remains unresolved.

**Trigger and impact:** Original UPI payment remains pending/unavailable → user selects Cancel & New Order → places COD or starts another payment → original payment succeeds late. The original payment can still create an order through webhook recovery, producing duplicate fulfilment/payment obligations while the device has discarded the original recovery state.

**Implement:**
1. Treat closing the pending UI separately from cancelling the gateway/business transaction.
2. Keep the original attempt ID and accepted transaction durably tracked until the backend confirms a terminal outcome.
3. Offer fresh checkout only after a reconciled terminal failure/cancellation, or an explicit backend-managed replacement policy that handles any late success.
4. Reuse the original attempt on status checks and retry; do not implement cancellation by deleting local keys.

**Required regression:** Pending and verification-unavailable results → press the button → late paid webhook/callback. Confirm that one accepted transaction is fulfilled, the old payment remains recoverable, and a fresh order cannot bypass unresolved-payment policy. Also verify confirmed terminal failure permits a legitimate new purchase.

### 2. [P1] Reject WebSocket tickets whenever shared consumption cannot be recorded

**Where:** [websockets.py:198](D:/Fastkirana/fastapi-backend/routers/websockets.py:198), failure handling at lines 276–280; canonical environment setting at [config.py:10](D:/Fastkirana/fastapi-backend/config.py:10).

**Evidence:** `is_prod` checks only `ENVIRONMENT` / `PRODUCTION`, while application configuration declares `APP_ENV`. With only `APP_ENV=production` and both database and Redis unavailable, the actual consumption function accepted the same unexpired ticket twice with independent worker-local memory:

```text
APP_ENV=production, DB unavailable, Redis unavailable:
worker A acceptance=True
worker B acceptance=True
ENVIRONMENT=production control: acceptance=False
```

**Implement:**
1. Require a successful authoritative consumption-ledger transaction before returning true in every environment that promises single-use tickets.
2. Handle uniqueness conflicts as already-consumed tickets; handle ledger unavailability as rejection.
3. Use the shared application environment configuration consistently. Do not leave replay protection dependent on an additional environment variable that production may not set.

**Required regressions:** APP_ENV=production with DB unavailable and Redis available/unavailable; uniqueness conflict; independent workers; both Redis availability-transition directions. No accepted ticket may lack a durable authoritative consumption record.

### 3. [P1] Recover the accepted checkout rather than submitting the current cart

**Where:** [checkout_controller.dart:153](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:153), [line 1289](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1289), [payment_gateway_handler.dart:109](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/payment_gateway_handler.dart:109).

**Observed path:** The draft now contains items/address/options, but startup reads only its Cashfree ID and total. A successful manual status check calls placement with `state.pendingCart ?? currentCart`; placement reads the currently selected address/options/settings and recalculates the amount at controller lines 763–839. It never reconstructs the saved accepted transaction.

**Trigger and impact:** Pay for basket A/address A → process restarts → current basket/address is B → Check Status reports paid. The app submits B or an empty cart instead of the accepted A transaction; amount parity alone cannot distinguish equal-price baskets. Backend/webhook recovery may independently create A, making reconciliation outcome depend on timing.

The complete draft is also saved at controller line 677 **after** `launchPayment` has already invoked the external SDK. A process interruption during launch can leave only ID/amount persisted.

**Implement:**
1. Separate payment-session creation from SDK launch so the complete accepted transaction is durably saved before launch.
2. Restore the full owner/hub/attempt transaction and use it for callback, startup/foreground, status-check and retry reconciliation.
3. Prefer a backend acknowledgement of the original business order; do not rebuild it from the current cart or current address/settings.
4. Ensure completion only clears the submitted basket revision, retaining unrelated newer cart edits.

**Required regressions:** Restart after launch with a changed equal-price basket, changed address/hub/options, missing current cart, and changed pricing settings. Each path must resolve the original accepted transaction exactly once. Include interruption before SDK launch and response loss after server commit.

### 4. [P1] Serialize clear/reconnect with normal cart writes and acknowledge the sent revision

**Where:** [cart_provider.dart:382](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:382); direct reconnect at line 416 and startup reconciliation at line 219.

**Reproduced with actual notifier/repository and mocked HTTP, without external network:**
1. Start `clearCart()` and hold its DELETE response.
2. Add a new item; allow the newer debounced POST to complete.
3. Finish the old DELETE after the POST.

```text
REVIEW_CART_RACE localQuantity=1 serverProducts=[] pending=false version=2 acknowledged=2
```

`clearCart` bypasses `_isSyncing` and then assigns `_lastAcknowledgedVersion = _cartVersion` after its await, so the old clear claims acknowledgement of the newer edit. No pending retry remains to restore the new item. Capturing the hub key fixes the earlier scope issue but does not fix this revision race.

**Implement:**
1. Route clear, startup, reconnect and normal edits through one serialized owner/hub/revision writer.
2. Capture the submitted revision before awaiting; acknowledge only that revision.
3. Clear dirty/pending state only if the current durable revision matches the acknowledged submission.
4. Persist empty tombstones and dirty revision before network submission, and restore these metadata on restart.

**Required regressions:** Delayed clear → newer successful add → clear finishes last; delayed reconnect → newer edit; old in-flight POST → clear; process interruption with dirty empty tombstone; scope/owner change while a request is in flight.

## Evidence and limits

Current full-run logs are in the review machine's temporary directory:
- `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-recheck5-backend-20261014.log`
- `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-recheck5-flutter-20261014.log`
- `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-recheck5-analyze-20261014.log`
- `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-recheck5-cart-race-20261014.log`
- Cart probe source: `C:/Users/Sooraj/AppData/Local/Temp/fastkirana-recheck5-cart-probe-20261014.dart`

The original real PostgreSQL independent-worker concurrency, native payment lifecycle, tracked schema/money migration, signed release artifact/certificate, whole-app accessibility and 2x text acceptance gates still require their own evidence. Graph synchronization and green local suites do not verify those release gates.

**Current conclusion:** The latest changes close the earlier five concrete implementation defects, but the four remaining failure paths above prevent an “all production blockers resolved” conclusion. Implement these narrowly, add behavioral regressions against the real handlers/controllers, then rerun affected suites.
