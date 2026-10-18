# FastKirana independent combined recheck — 17 October 2026, revision 2

**Reviewed HEAD: `f04f2a81`. Several previous cases are closed, but five active issue groups remain. The Flutter suite is currently failing.**

This updates the statuses in the earlier combined handoff for the current snapshot. Application source and existing tests were not changed. Probes used fake ORM/cache/native/HTTP dependencies, plus one isolated SQLite role round trip. No live database, Redis, gateway, notification, print, credential-revocation, or deployment action was performed.

## Fresh verification

| Check | Result |
| --- | --- |
| Python suite, excluding incompletely isolated migration gateway/KOT module | **234 passed, 0 failed/errors/skipped**, 254 warnings |
| Flutter full suite | **299 passed, 1 failed**, exit 1 |
| Next.js unit suite | **147 passed**, 21 suites, 0 failed |
| TypeScript typecheck | **Exit 0, no errors** |
| Targeted Dart analysis, eight changed/related files | **Exit 0, no issues** |
| Targeted Flutter run: seven review observations plus existing offline-cart module | **9 passed, 1 failed**; same existing offline-cart failure reproduced |

The failing test is [offline_cart_sync_test.dart:85](D:/Fastkirana/fastkirana_flutter/test/unit/offline_cart_sync_test.dart:85), `Offline Mode: saves cart locally and marks pending sync flag when network is down`: **expected quantity 2, actual 4**. This is an actual existing-suite failure, not a test demanding the old automatic-confirmation policy.

Evidence: [verification summary and hashes](D:/Fastkirana/docs/verification/2026-10-17-r2-verification-summary.json), [Python results](D:/Fastkirana/docs/verification/2026-10-17-r2-python-results.json), [full Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r2-flutter-suite.log), [targeted Flutter log](D:/Fastkirana/docs/verification/2026-10-17-r2-flutter-probes.log), [backend results](D:/Fastkirana/docs/verification/2026-10-17-r2-probes.json).

Python uses in-memory SQLite, dummy credentials, disabled dotenv loading and blocked external sockets. Its 234-test scope excludes `test_migration_full.py`; do not confuse it with other reports' 235-test scopes. The seven Flutter review observations capture actual outcomes; their diagnostic assertions are not all release acceptance assertions. Real PostgreSQL concurrency and physical-device/gateway lifecycle were not verified.

## Important intentional policy change

Online payment now leaves the recovered order **PAID + ADMIN_PENDING**, awaiting manual approval. Recovery does not automatically confirm, deduct inventory, clear cart or enqueue KOT while pending. This change is treated as intentional, rather than reported as a status regression. Its inventory consequences are tested separately below.

## Previous seven issue groups: current status

| Previous group | Updated result |
| --- | --- |
| Coupon inflation / forged category on an exact catalog SKU | **Executed old attacks closed.** Catalog ₹100 plus client price ₹1,000 and eligible 20% coupon now quotes ₹80, discount ₹20 and line price ₹100. Forged category receives full ₹100. Encoded variant IDs still escape the resolver, below. |
| Accepted financial lines | **Known exact SKU cases closed.** Client price ₹1 no longer becomes order price; accepted ₹100 line stays ₹100 after catalog rises to ₹120. |
| SSE blocked/demoted tokens and rider assignment | **Old cases closed:** blocked token 401, demoted token 403, owner/rider 200. Actual ORM enum roles cause a new admin denial, below. |
| Backend cart cleanup | All-cart-ID deletion was removed. In the exact confirmed-branch probe, other variants remain and quantity 3 minus 1 leaves 2. Replacement fallback remains unsafe, but this branch is currently inactive during paid recovery; see the separate note below. |
| Flutter completion acknowledgement | **Restart case closed:** existing persisted acknowledgement leaves quantity 3 unchanged. **Concurrent case regressed:** two callbacks subtract twice, 3 -> 1. |
| Cart hydration | Distinct-item merge and tested clear-during-load case pass. Existing offline test doubles quantity 2 -> 4; delayed pending-key resolution still acknowledges a stale snapshot. |
| Redis post-commit compensation | **Executed case closed.** Injected post-commit error returns the committed order and performs zero inventory-release calls. |

Failed replacement draft writes still preserve the original draft in both false-return and thrown-error controls. Earlier FCM binding/key-source fixes were not modified by these commits; historical key revocation remains unverified.

## 1. P1 — Encoded variant IDs still accept client price

Creation loads only the supplied product IDs. When an ID such as `review-product_Small` is not itself a catalog row, the fallback at [cashfree_router.py:291](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:291) accepts client price and builds a supposedly canonical line. Recovery subsequently resolves its real base product, retaining the accepted raw price.

The full quote → intent → recovery probe used an existing ₹100 Small variant, quantity 1, submitted encoded ID and client price ₹1. Quote was **₹1**. Recovery persisted the real base `productId`, selected Small, line/subtotal/total **₹1**, and `ADMIN_PENDING`. Inventory remained unchanged under the new manual policy. This is an underpriced paid intent; it is **not** a claim of automatic fulfillment under the new policy.

**Fix:** resolve exact IDs and supported encoded variant IDs through the same server catalog/variant resolver before computing or saving any quote. Preserve real IDs containing underscores. Reject unknown products/variants rather than accepting raw client financial data. Use the resulting canonical lines in every creation/retry branch.

**Acceptance:** exact and encoded IDs for the same variant produce the same server price/discount/total; forged client price/category cannot alter them; unknown IDs/variants fail before exposing a usable payment session.

## 2. P1 — Recovered paid order can be approved without inventory deduction

Recovery now always chooses `ADMIN_PENDING` at [cashfree_router.py:1515](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1515), while stock deduction requires `CONFIRMED` at [line 1576](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1576). The authorized admin status handler at [admin_extended.py:785](D:/Fastkirana/fastapi-backend/routers/admin_extended.py:785) changes status and commits without reserving/deducting inventory. The ordinary workflow also still assumes inventory was deducted during creation at [orders.py:3194](D:/Fastkirana/fastapi-backend/routers/orders.py:3194).

Executing complete current paid recovery followed by the actual authorized admin status handler, with fake ORM/task/broadcast dependencies, produced:

```text
Product/hub initial stock: 2 / 2
Paid recovered quantity: 1
Recovery: ADMIN_PENDING, stock 2 / 2
Admin approves: CONFIRMED, stock still 2 / 2
```

This establishes a missing deduction in the application path. Deployed database-side behavior was not tested.

**Fix:** define one durable inventory reservation/deduction point for the manual workflow. Perform it atomically exactly once, including stock revalidation and failure handling. Distinguish stock actually deducted from pending/unreserved orders so cancellation does not restore inventory that was never removed. Preserve normal checkout's existing deduction path without double deduction.

**Acceptance:** recovered paid purchase + approval deducts once; repeated approval/replay deducts zero additional units; insufficient stock prevents approval/dispatch; cancellation restores only recorded deductions. Verify independent PostgreSQL transactions competing for the last unit.

## 3. P2 — Concurrent Flutter completion subtracts twice again

At [checkout_controller.dart:1340](D:/Fastkirana/fastkirana_flutter/lib/features/checkout/controllers/checkout_controller.dart:1340), both callbacks can observe no acknowledgement, await storage, then both execute `removeDraftItems` before either records the in-memory completion marker.

Current actual-controller probe: same durable order, accepted quantity 1, current quantity 3, two concurrent completions → **final quantity 1; expected 2**. The persisted acknowledgement/restart control now correctly stays at 3.

**Fix:** serialize the per-order acknowledgement and cart-delta operation across the asynchronous check/apply/persist boundaries. Keep crash/storage-failure recovery; merely setting a success marker early can lose unfinished cleanup.

**Acceptance:** concurrent and sequential callbacks subtract once; restart replay subtracts zero additional units; failed cart persistence/acknowledgement remains resumable; unrelated orders apply their own delta.

## 4. P2 — Hydration doubles an offline edit and still acknowledges stale state

The new addition at [cart_provider.dart:239](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:239) assumes hydrated quantity and current quantity are independent. The existing offline test now reads back its own recent local edit and adds it again: **expected 2, actual 4**. It fails in both the full suite and the focused rerun.

The await at [line 277](D:/Fastkirana/fastkirana_flutter/lib/providers/cart_provider.dart:277) still lacks a post-await generation check. Holding it while adding B reproduced server `[oldA]`, UI/local `[oldA,newB]`, `pending=false`, `version=ack=2`. The controlled clear-during-load case now remains empty everywhere; retain that fix.

**Fix:** hydrate a defined base and replay identified ordered mutations exactly once, or gate mutations until hydration is ready. A final list union/addition cannot distinguish preexisting quantity from a snapshot already containing the mutation. Revalidate scope/revision after every asynchronous boundary and acknowledge only the synchronized revision.

**Acceptance:** the existing offline test passes with quantity 2; same-SKU add applies only its delta; clear/remove tombstones survive; pending-key delay cannot lose or falsely acknowledge edits; local/UI/server contents agree after synchronization and owner/hub changes.

## 5. P2 — Legitimate ORM ADMIN role receives SSE 403

[websockets.py:764](D:/Fastkirana/fastapi-backend/routers/websockets.py:764) uses `str(db_user.role).upper()`. The real ORM round trip returns enum `Role.ADMIN`; its string becomes `ROLE.ADMIN`, which does not match the accepted `ADMIN` string. A probe using that ORM role representation receives **403** for a legitimate administrator. Owner/rider controls pass because they use identity rather than this role string.

**Fix:** normalize enum values before comparing roles, then retain database-backed active-user, purpose and tenant-scope checks.

**Acceptance:** a database-loaded authorized admin can stream the permitted order; blocked/demoted and unrelated identities remain rejected; assigned rider and owner retain access. Verify scope against actual model role values, not only string-valued fake users.

## Remaining notes and release gates

- **Dormant backend cleanup:** an exact cleanup-source probe with accepted old row ID missing still falls back to matching the new same-SKU replacement and deletes it. Current `ADMIN_PENDING` recovery does not enter this branch, so this is not reported as an active automatic deletion. Before using this branch for confirmed orders, missing accepted identity must preserve the replacement row rather than fall back destructively.
- **Firebase:** source literal removal is not proof of historical credential revocation; that external evidence is still needed.
- **Payment lifecycle:** cancellation/late-success and signed-device restart behavior were not exercised here. Clearing a local pending banner does not itself establish that a bank/gateway attempt was cancelled. Preserve/reconcile in-flight attempts and test late success before release.
- **Legacy Next.js creation:** the prior raw amount/draft parity finding remains source-level; no new live fulfillment claim is made.
- **Production validation:** SQLite/fake-ORM checks do not replace isolated PostgreSQL concurrency, real Redis lifecycle or signed-device gateway test-environment checks.

Fix order: canonical variant resolver; manual-approval inventory accounting; Flutter completion serialization and hydration; enum-role normalization; then focused regressions and integration checks. Preserve the verified closures above.

Artifacts: [backend probe source](D:/Fastkirana/docs/verification/recheck_2026_10_17_r2.py), [Flutter observation source](D:/Fastkirana/docs/verification/flutter_recheck_2026_10_17_r2_test.dart), [backend log](D:/Fastkirana/docs/verification/2026-10-17-r2-backend-probes.log). Temporary repository probe copies were removed. Source hashes were checked against the fresh suite snapshot; see the verification summary.
