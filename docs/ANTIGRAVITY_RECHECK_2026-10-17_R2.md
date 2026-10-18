# FastKirana payment/cart recheck — 17 October 2026, revision 2

Reviewed HEAD: `f04f2a81`. Scope: the four open payment/cart findings in the [previous review](D:/Fastkirana/docs/ANTIGRAVITY_RECHECK_LATEST_2026-10-17.md).

**Two backend findings are closed in the executed cases. Two Flutter issue groups remain: completion acknowledgement and cart hydration.** Application source and existing tests were not edited. No commits, deployment, real gateway/SDK payments or production service writes were performed.

## Verification

| Check | Result |
|---|---|
| Full FastAPI `tests/`, isolated SQLite, dummy credentials, external sockets/HTTP blocked | **235 passed, 0 failed**, 259 warnings |
| Focused actual FastAPI quote/intent/recovery checks | **11 passed**, 107 warnings |
| Targeted Dart analysis of six checkout/cart files | **No issues**, exit 0 |
| Independent full Flutter suite: `flutter test --no-pub --no-enable-impeller --reporter expanded` | **299 passed, 1 failed**, exit 1 |
| Flutter payment phase 1: draft persistence, sequential/concurrent completion, cart storage failure | **5 passed, 2 failed** |
| Flutter payment replay in a separate Dart process with persisted preferences | **1 passed** |
| Actual cart notifier/repository checks | **4 passed, 2 failed** |
| Existing `test/unit/offline_cart_sync_test.dart` | **2 passed, 1 failed**: expected quantity2, actual4 |

Focused checks assert intended correct behavior, so the failures above are actual mismatches rather than deliberately passing bug assertions. Native channels and HTTP are mocked/intercepted. The separate-process replay uses exported actual mock-store preferences; this is not a physical-device termination test.

A concurrent full workspace Flutter run was already active. No duplicate full run was started alongside it. After it finished, an independent full run was launched. The full run excludes all temporary review probes.

Next.js unit tests/type checking were not rerun in this focused follow-up; do not present the previous147-pass result as a fresh run. The two snapshotted Next.js payment/order routes are unchanged from the prior reviewed snapshot.

## Verified closures

### Coupon price inflation

The former forged-price attack is closed for the executed catalog product/category-coupon path:

```text
Catalog price100; submitted item.price1000
Genuine scoped coupon50%
Actual accepted discount50, gateway amount80
Recovered line price100, subtotal100, total80
```

[Canonical accepted lines](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:278) now supply [scoped coupon calculations](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:425), and the discount is capped against the server subtotal. Negative/nonfinite fee controls still return400, forged zero required fees become25/5, and the simple wrong-category coupon control remains denied.

### Accepted financial lines

Both former line-price failures now recover100:

- Client price1 against catalog100: gateway130, recovered line100/subtotal100.
- Omitted client line price, then catalog100→120 after accepting100−20+30=110: recovered line100/subtotal100/total110.
- Correct supplied-price control also preserves100 after the catalog change.

The quote now includes canonical lines, and [recovery uses the accepted quote line](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1401).

Paid recoveries now use `ADMIN_PENDING` with “Awaiting Admin Confirmation” under the latest deliberate manual-confirmation policy. This status change is not treated as the former underpayment/repricing bug.

### Previous Flutter controls that remain correct

- False/thrown first draft writes abort native launch and leave no accepted draft.
- False/thrown replacement writes retain the original committed100 draft after reload.
- Sequential same-order completion remains3→2→2.
- Restart replay now consults the persisted acknowledgement and remains2→2.
- Distinct A+B hydration and delayed server GET remain correct.
- Saved A2 plus an early addA1 now becomes A3.
- Clear alone during a held old local read now remains empty.
- Missing-intent recovery remains an admin-reconciliation placeholder and preserves unrelated current cart B.

## Remaining 1. [P2] Completion cleanup still races and is not resumable after cart-save failure

**Where:** [checkout_controller.dart:1340](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1340), [subtraction:1356](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1356), [marker:1361](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1361), [cart mutation before persistence](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:491).

Reading durable acknowledgement fixes restart replay. Moving the marker after cart cleanup introduces a concurrent window: two callers can both pass the asynchronous lookup before either marks the order acknowledged.

Actual concurrent controller check:

```text
Accepted purchased quantity1; current cart quantity3
Two simultaneous completions wait for both POSTs
Both receive the same durable business order
Final cart quantity1; expected2
```

The failure/retry path is also incorrect:

```text
First completion updates in-memory cart3→2
Injected cart disk save fails; completion throws
No acknowledgement committed; durable cart remains3
Retry uses already-mutated in-memory cart2 and subtracts again
Final UI/durable cart1; expected2
```

The pending payment/draft is cleared before cart acknowledgement completes, so a failed cleanup also lacks the original local recovery record.

**Implement:**

1. Serialize/coalesce completion per owner/hub/payment attempt/business order before the first asynchronous acknowledgement lookup.
2. Use an atomic local cart-delta-plus-acknowledgement commit, or a resumable journal with explicit not-applied/applied/acknowledged states.
3. On persistence failure, roll back/reload optimistic state or resume the same delta; do not subtract from its already-applied in-memory result.
4. Keep recovery until local acknowledgement succeeds. Persisted membership must continue protecting restart replay.
5. Do not rely only on moving a boolean before/after subtraction; each ordering has a failure window.

**Acceptance:** All same-order sequential, concurrent, retry and fresh-process cases leave3→2 exactly once. Fail each persistence boundary and replay after restart. Distinct orders apply their own deltas. Newer cart quantities remain intact.

## Remaining 2. [P2] Hydration still resurrects cleared items, overwrites revisions and duplicates additions

**Where:** [cart_provider.dart:220](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:220), [empty-list clear guard:222](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:222), [quantity sum:239](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:239), [pending-key await:277](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:277).

The current guard recognizes clear only while the latest pending list is empty. An immediate subsequent add replaces that list and loses the clear intent:

```text
Old local read captured A2
User clears cart: DELETE succeeds
User adds B1 before old local read returns
Old read completes: UI/local/server become A2+B1
Expected B1
```

The earlier unguarded await remains:

```text
Hold getPendingSyncKeyForCurrentScope after the version guard
Add B1 while waiting; release old startup continuation
Server A1; UI/local A1+B1
pending=false, version=ack2
```

This second case deliberately delays the key seam; production frequency is unmeasured.

The new quantity-summing merge also fails the repository's existing offline test:

```text
Start with empty preferences
Create notifier; immediately add product quantity2 while offline
After350ms: expected2, actual4
test/unit/offline_cart_sync_test.dart:85
```

A local read can observe the same newly saved mutation and then add it to the already-updated UI again. Treating every read list as an older independent base cannot distinguish that case.

**Implement:**

1. Gate edits until hydration is ready, or replay ordered mutation intents against a known versioned base.
2. Preserve clear/remove generations across later additions. Empty/nonempty snapshot shape is not an operation history.
3. Track whether loaded quantities already include a mutation instead of blindly summing them.
4. Recheck owner/hub/generation/revision after asynchronous reads, including pending-key resolution.
5. Acknowledge only the snapshot actually synchronized; stale startup continuations must not replace the latest queue.

**Acceptance:** Restore the existing offline test without weakening its quantity assertion. Cover empty-cache immediate add, saved A2+addA1, clear, clear+add, remove/readd, normal cart refresh, delayed pending key, offline/reconnect and hub/owner changes. Assert identical local/UI/server quantities and accurate dirty/pending revision.

## Antigravity execution order

1. Fix completion serialization and durable/resumable acknowledgement together.
2. Replace hydration list merging with a versioned base plus operation replay, or a deliberate ready-state UI policy.
3. Add the exact concurrent, failed-write retry, clear+add and pending-key regressions. Keep the now-passing coupon/line/restart controls.
4. Run full backend/Flutter suites and targeted analysis; then test signed-device callback overlap, app termination and storage failure in a test environment.

This closes only the catalog cases explicitly executed here. Broader backend security/Redis, all SKU protocols, deployed services, independent PostgreSQL workers, live gateway settlement and signed native behavior are outside this follow-up; older reports must not be assumed closed without rechecking them.

## Retained evidence

All files below are in `C:/Users/Sooraj/AppData/Local/Temp`:

- `fastkirana-recheck10-snapshot-20261017.json`
- `fastkirana-recheck10-backend-20261017.log`
- `fastkirana-recheck10-run-backend-20261017.py`
- `fastkirana-recheck10-backend-probe-20261017.py`
- `fastkirana-recheck10-backend-launcher-20261017.py`
- `fastkirana-recheck10-quote-recovery-20261017.log`
- `fastkirana-recheck10-analyze-20261017.log`
- `fastkirana-recheck10-flutter-20261017.log`
- `fastkirana-recheck10-offline-cart-20261017.log`
- `fastkirana-recheck10-cart-probe-20261017.dart`
- `fastkirana-recheck10-cart-20261017.log`
- `fastkirana-recheck10-payment-probe-20261017.dart`
- `fastkirana-recheck10-payment-phase1-20261017.log`
- `fastkirana-recheck10-payment-phase2-20261017.log`
- `fastkirana-recheck10-payment-restart-prefs-20261017.json`

Temporary repository probes have been archived outside the repository. All twelve snapshotted source/test files retained identical SHA-256 hashes through final verification, and HEAD remained `f04f2a81`. The independent full Flutter suite completed in 80 seconds with 299 passing tests and one failing existing offline-cart test (quantity expected 2, actual 4). No temporary review probes were included. The full-suite failure matches the independently rerun existing offline-cart file.

