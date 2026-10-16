# FastKirana independent Python backend recheck — 16 October 2026, revision 2

**Result: 234 tests passed, but payment and security release blockers remain.** The previous quantity, variant/hub, and basic coupon-recovery failures are corrected in the tested paths. New notification/realtime changes introduce credential and authorization problems. This report supersedes the earlier 16 October report for the reviewed snapshot.

Reviewed Git HEAD: `b136cedf`. Application source and existing tests were not edited during this review. Only review documents and isolated reproduction artifacts were created.

## Verification and evidence

- Python suite: **234 passed, zero failures/errors/skips, 262 warnings**. Pytest reports 148.68 seconds; the wrapper measured 259.93 seconds including collection/startup.
- Scope: `tests/`, excluding `tests/test_migration_full.py`, whose gateway/KOT operations are not completely isolated. In-memory SQLite, dummy credentials, disabled dotenv loading, and blocked external socket connections were used. No production SQL, Redis, gateway, notification, or print operations were performed.
- [Structured suite results and before/after hashes](D:/Fastkirana/docs/verification/2026-10-16-python-recheck-r2-results.json).
- [Isolated probe results](D:/Fastkirana/docs/verification/2026-10-16-r2-probes.json) and [reproduction harness](D:/Fastkirana/docs/verification/backend_recheck_2026_10_16_r2_probes.py).
- Probes execute current complete quote, intent-saving, recovery, FCM-registration, and SSE functions against fake ORM/cache objects. The Redis rollback probe executes the exact checkout inventory source block with fake Redis and a simulated SQL rollback. Neither establishes real PostgreSQL transaction/concurrency behavior or a live Cashfree transaction.

## Previous findings: current status

| Previous issue | Current execution result |
| --- | --- |
| Negative quantity increases stock | Corrected for the reviewed quote/recovery paths. Quantities -1, 0, 0.5, 1.5, NaN, infinity, and 1001 receive HTTP 400 during quote creation. A legacy intent containing -1 remains `ADMIN_PENDING`; product/hub stock stay 2. |
| Selected variants bypass hub availability | Corrected for cached/durable-intent item processing. Variant stock 2/hub stock 0 remains `ADMIN_PENDING`; Small + Large demanding 2 units against hub stock 1 also remains `ADMIN_PENDING`. No deduction occurs. |
| Valid ₹20 coupon on ₹100 item fails recovery | Corrected for an eligible simple flat coupon with unchanged catalog pricing: quote ₹80, persisted discount ₹20, recovered `CONFIRMED` total ₹80, product/hub stock 2 → 1. |
| Missing delivery fees / pickup packaging mismatch | Default delivery now quotes and recovers ₹130 on ₹100 goods (₹25 delivery + ₹5 packaging); pickup ignores a supplied ₹5 packaging fee and stays ₹100. Client-supplied overrides remain unsafe, below. |
| Default cleanup touches every variant | The old cross-variant example is corrected: default quantity 1 is removed while Small 3 and Large 4 remain unchanged. Replacement rows for the same variant are still deleted, below. |
| Retry suffix creates different consumed-payment keys | The prior canonical base-key fix remains present. The intent comparison now derives its alternate reference from the actual intent rather than the old tautological comparison. |

## P1 — Committed Firebase service-account private key

[firebase.py:73](D:/Fastkirana/fastapi-backend/utils/firebase.py:73) contains a fallback service-account credential dictionary with a private key starting at [line 77](D:/Fastkirana/fastapi-backend/utils/firebase.py:77). This is tracked in Git and is used to initialize Firebase when environment credentials are missing. Offline parsing confirms a structurally valid **2048-bit private key**, rather than a placeholder. Its live validity, revocation state, and account permissions were not checked.

Treat this as credential exposure: revoke/rotate the exposed key through the service account's owner, remove the hardcoded fallback, and load credentials only from the deployment secret mechanism. Removing the literal in a later commit does not revoke the historical key. Check authorized access/audit history as part of remediation. No key material is copied into these review artifacts.

Acceptance: no private key in tracked application code; missing credentials fail safely; the exposed key is confirmed revoked and the replacement is delivered through the configured secret mechanism.

## P1 — Anonymous FCM registration can replace another user's devices

[fcm.py:97](D:/Fastkirana/fastapi-backend/routers/fcm.py:97) changes required authentication to optional identity. The body `userId` or phone can select an existing account at [line 120](D:/Fastkirana/fastapi-backend/routers/fcm.py:120), without proof that the caller owns it. The registration then deletes other tokens belonging to that selected account at [line 180](D:/Fastkirana/fastapi-backend/routers/fcm.py:180).

Executing the complete registration function with `current_user=None`, a victim user ID, an attacker device token, and an existing victim token returned success. The attacker's token became the victim's only remaining device token; the victim's existing token was deleted. No actual notification was sent. This can redirect device notifications and deny delivery to the legitimate device.

Require verified user identity for account binding and derive the user ID from it. Guest registration must remain separate until a verified login/account-link step; a supplied account ID or phone must not authorize deletion or attachment.

Acceptance: anonymous submissions cannot bind to an existing account or remove its devices; logged-in user A cannot affect user B through body fields; guest tokens can be linked only after verified ownership.

## P1 — Negative client fees allow ₹100 goods to recover as paid ₹1

Quote creation accepts client `deliveryFee` and `packagingFee` without a non-negative/server-policy check at [cashfree_router.py:341](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:341). The accepted values are persisted as `validated_quote`, then recovery uses them at [line 1199](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1199) and [line 1393](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1393).

The complete actual quote → intent saver → recovery sequence, with fake services, produced:

| Input / output | Result |
| --- | --- |
| Catalog item / quantity | ₹100 / 1 |
| Submitted delivery / packaging fees | -₹99 / ₹0 |
| Quote and mocked paid amount | ₹1 |
| Recovery | `CONFIRMED`, total ₹1, delivery fee -₹99 |
| Product/hub stock | 2 → 1 each |

Explicit zero delivery and packaging fees also suppress the default ₹30 and recover at ₹100. The recovered intent is durable, but its fee inputs are not authoritative. Ordinary checkout calculates delivery using server settings, rules, and thresholds; quote creation still uses client overrides or hardcoded defaults.

Compute required fees from server policy. Validate optional monetary inputs as finite, non-negative values, and never let caller-supplied required fees reduce the accepted total. Use one calculation across quote, checkout, and recovery.

Acceptance: negative, non-finite, and unauthorized zero overrides cannot reduce the amount or trigger fulfillment. Custom delivery settings and pickup rules agree across all three paths.

## P1 — Quote/recovery still honor ineligible category coupons

The quote coupon checks at [cashfree_router.py:369](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:369) validate activity, expiration, usage cap, and minimum subtotal, but do not enforce category/restaurant/menu/product eligibility or once-per-customer rules used elsewhere.

A full quote → intent → recovery probe applied a flat ₹20 coupon restricted to an unrelated category to a ₹100 product with no matching category. Quote was ₹80, and recovery confirmed the order with discount ₹20 and deducted inventory. Persistence now preserves this incorrectly accepted discount.

Share the complete eligibility and discount calculation with ordinary checkout, using authoritative product/account data. Recovery must use a valid accepted quote whose eligibility and usage handling were established by that shared path.

Acceptance: wrong-category/restaurant/menu/product coupons and exhausted once-per-customer coupons cannot authorize a discounted recovery. Eligible variants and existing coupon regression cases must retain their intended discounts.

## P1 — New single-order SSE stream has no authentication or ownership check

[websockets.py:698](D:/Fastkirana/fastapi-backend/routers/websockets.py:698) exposes `/api/sse/orders/{order_id}` with a database dependency but no identity/ticket dependency. It selects only by supplied order ID and emits order/readable IDs, status, payment status, and delivery method. The router is mounted without an additional authorization dependency at [main.py:389](D:/Fastkirana/fastapi-backend/main.py:389).

Executing the complete endpoint and consuming its first two events with an anonymous request and another customer's mocked order emitted `CONNECTED` and `STATUS_CHANGED`, including that order's payment status. Existing WebSocket ticket restrictions do not protect this separate route. The test did not emit GPS coordinates; the exposed payload is limited to the fields above.

Require verified identity or a purpose-bound tracking ticket, then apply the same customer, assigned-rider, and staff/store ownership policy before returning a stream. Close/reject unauthorized streams before emitting order metadata.

Acceptance: missing/invalid identity and unrelated customers receive an authorization error; only authorized parties can consume the requested order's events.

## P2 — Redis inventory reservation survives SQL rejection/rollback

The new checkout path reserves Redis stock at [orders.py:2030](D:/Fastkirana/fastapi-backend/routers/orders.py:2030), before product/hub validation and the SQL commit. Later validation can reject the order. `release_reserved_inventory` exists at [cache.py:287](D:/Fastkirana/fastapi-backend/utils/cache.py:287), but there is no call to it anywhere in `orders.py`, including the exception handlers.

Executing the exact inventory source block with product stock 2, hub stock 0, quantity 1, and fake Redis seeded from product stock rejected with HTTP 400. After simulating SQL rollback, database stock was restored to 2 while Redis remained 1. The Redis key can retain this false deduction for its configured lifetime. Failed orders/retries can therefore exhaust cache availability while physical/database inventory remains available. Redis-enabled behavior is not covered by a Redis-down concurrency test.

Track every successful reservation and compensate on all failure/cancellation paths before commit. Define how committed orders, restocks, cancellations, key expiration, and seeding synchronize the cache with the database. An alternative is to keep database inventory authoritative and treat the cache as an advisory optimization.

Acceptance: failure after any reserved line restores all reservations exactly once; retry succeeds when database stock exists; Redis-up tests cover multi-line failure and restocking in addition to Redis-down fallback.

## P2 — Cart cleanup deletes a newer replacement row

Cleanup at [cashfree_router.py:1543](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1543) matches product/variant, without preserving the accepted cart-item ID or revision. The decrement/delete loop starts at [line 1561](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py:1561).

The full quote/recovery probe began with default row `old-default` quantity 1. After quote creation, it removed that row and inserted `new-default` quantity 1 for the same product/default variant. Recovery deleted `new-default`. The old cross-variant bug is fixed, but the claim that newer cart edits are preserved remains incomplete.

Persist the accepted cart-row identity/revision and make cleanup conditional on that identity/version, with concurrency-safe quantity handling.

Acceptance: removing/readding the same SKU preserves the replacement row; quantity increases retain the intended remainder; default cleanup continues to preserve Small/Large rows; concurrent edits are not overwritten.

## Additional limits and observations

- Recovery still reprices from the current catalog instead of accepted per-line prices: an accepted ₹100 quote followed by a catalog increase to ₹120 became `ADMIN_PENDING`. Define the quote-expiry/price-change policy explicitly before claiming exact accepted-quote restoration.
- The no-intent cart fallback uses a separate availability path and does not share the new locked/aggregated hub checks. The fixed cached/durable-intent cases should not be generalized to every fallback path without dedicated verification.
- The existing production-blocker regression file has the same hash as the earlier 228-test review. The six newly collected tests are in the coupon menu-section suite; the new failures above are demonstrated by separate review probes.
- Independent PostgreSQL worker contention, live Cashfree behavior, deployment configuration, and Next.js/Flutter clients were not verified here.

## Remediation order

1. Revoke/rotate the committed Firebase credential and remove its fallback from source.
2. Restore verified ownership for FCM account binding and the new SSE route.
3. Reject fee tampering and share complete server quote/coupon eligibility across payment, checkout, and recovery.
4. Compensate Redis reservations on rollback and synchronize inventory cache lifecycle.
5. Preserve cart-item identities/revisions during cleanup.
6. Add focused regressions for these cases and verify isolated PostgreSQL concurrency with independent sessions/workers.

## Source snapshot

The suite's initial/final hashes match; final reviewed hashes include:

| File | SHA-256 |
| --- | --- |
| routers/cashfree_router.py | `EC3FA87E76D6172237808196CCDC829393A5B0F02D089AFBF13DFC63107A02D7` |
| routers/orders.py | `E62AC8A300F35BDDC5F8A2242F7BAE49B6A09B4005189D7451E26394E8E66F0B` |
| routers/fcm.py | `ECACA493ED0BFEF92C0251E0926B6B1C2A855C7D5F99125AA1929ACE602CC6D9` |
| routers/websockets.py | `F6F46BC852CA080FC444E7BF4893374ED420D0D35835FBDC230A0A8D5356E463` |
| utils/firebase.py | `600689C6B15AADCF33B3D2AC9994B7ADC18453FB055A6229595A4388E6CF2842` |
| utils/cache.py | `49A88BAA4F6EE13BC4AD40073A074B380894A8DD04CDCE8FA734B68EFE3B1DF8` |
