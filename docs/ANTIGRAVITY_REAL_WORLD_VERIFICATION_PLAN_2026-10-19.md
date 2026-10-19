# Antigravity handoff: real-world release verification

**Purpose:** verify physical-device UX, real Cashfree integration, app termination/restart recovery and backend capacity. This is an execution plan; none of these device, gateway or load runs was performed while preparing it.

**Order:** prepare reliable staging/harnesses → physical-device UX → Cashfree sandbox → interruption recovery and staging load → regression/fix loop → approved, low-volume live-payment smoke → final reconciliation/report. A failed correctness gate blocks advancement.

**Current baseline:** the preceding local recheck recorded 306 existing Flutter tests and 17 focused payment/concurrency checks passing, with clean targeted analysis. These are local results, not proof of real SDK interaction, device lifecycle recovery or deployed capacity. See [revision 4](D:/Fastkirana/docs/PAYMENT_RECOVERY_RECHECK_2026-10-19_R4.md).

## 1. Prerequisites and build freeze

Antigravity should record these inputs before execution. Missing access/device coverage must be marked BLOCKED, never PASS:

| Input | Required record |
|---|---|
| Candidate | Git commit plus hashes of uncommitted source, dependency locks, build version and APK/AAB checksum |
| Devices | Model, RAM, OS/API level, screen resolution/refresh rate, app build, UPI apps installed |
| Environment | Explicit mobile API URL, actual Next.js/FastAPI routing, application ID, SDK mode, backend gateway mode, webhook URL; secrets redacted |
| Accounts/data | Dedicated verified customer A/B, admin/store/rider accounts, hubs A/B, known catalogue and addresses |
| Access | Physical Android devices, staging logs/metrics, Cashfree sandbox dashboard/webhooks; separate production access for the eventual live smoke |
| Capacity target | Expected peak simultaneous shoppers, order attempts/minute and connected riders; use the provisional workload below until measured business targets replace it |
| Live smoke | Named operator, test account, allowed payment method, maximum amount/attempt count and total budget agreed before any real charge/refund |

Use isolated staging with the actual database engine and shared Redis, intended worker count and deployment/proxy topology. Use test fulfilment, notification and printing sinks so synthetic orders do not dispatch real deliveries, messages or KOTs. Configure a separate staging app identity if installing alongside production.

The app defaults to public production API/payment settings. Explicitly set the staging API and `CASHFREE_ENV=SANDBOX` for the mobile build; verify the resolved configuration in redacted startup diagnostics. Confirm the backend uses the real Cashfree sandbox URL/credentials, not just a variable named "test". Inspect every API fallback URL: staging requests must never fail over into production.

**Repository-specific prerequisites:**

1. [Existing integration file](D:/Fastkirana/fastkirana_flutter/integration_test/checkout_e2e_integration_test.dart) currently constructs fixture state/widgets and a simulated payment result. Add a separate real-app entry point that initializes `IntegrationTestWidgetsFlutterBinding`, launches the actual application and operates against staging with real persistent storage. Keep the existing fixture tests as useful local coverage, but do not count them as physical-device payment evidence.
2. Remove or redesign business-flow shortcuts based on a binding's type-name containing `Test`. They occur in checkout completion, payment handling and connectivity. A real device running an integration-test binding must still execute paid reconciliation, persistence, retries and the intended lifecycle logic. Substitute external dependencies explicitly when a test calls for a fake; do not skip application work. Re-run the existing regression suite after this harness change.
3. Flutter's integration package cannot drive native permission dialogs/UPI UI directly. Use it for Flutter screens; use a recorded manual/native driver for permission sheets, external payment apps, OS actions and relaunch. A host-side controller must survive the app process being killed. [Flutter integration-test capabilities](https://docs.flutter.dev/cookbook/testing/integration/introduction).
4. FastAPI's [Cashfree router](D:/Fastkirana/fastapi-backend/routers/cashfree_router.py) returns locally generated sessions/statuses for `TEST`/`MOCK`. These runs must be labelled STUB, not provider-sandbox evidence. Verify real sandbox requests in the merchant dashboard and actual signed webhook deliveries.
5. The present checkout calls can reach either backend depending on routing. Record which one serves each endpoint; exercise the deployed path end to end. If Next.js and FastAPI independently serve payment/order routes in supported deployments, give both a contract smoke rather than assuming one validates the other.

**Gate 0:** one physical-device launch reaches staging; one valid authenticated cart round-trip persists the expected SKU/variant; real sandbox session creation appears in Cashfree; logs correlate the app attempt to the server intent. No secrets, OTPs or payment PINs appear in evidence.

## 2. Physical-device UX and performance

**Minimum Android matrix:** a low-memory/older supported device, an ordinary current midrange device and a recent higher-refresh device. Include a widely used OEM with background/battery restrictions. Android currently declares minimum API 24; identify the actual installable minimum after plugin/build constraints and cover it where supported.

Use a profile build for frame/performance traces and the signed release candidate for final functional/payment smoke. Record the exact build for each result. Debug-mode speed is not the performance baseline. [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance).

This checkout contains no `ios/` runner directory in the inspected workspace. Android is the executable primary scope. If iOS is intended for this release, first provision its runner, signing/capabilities, callback URL handling and a macOS/Xcode host; test at least one smaller/older supported and one current physical iPhone. Otherwise mark iOS NOT IN RELEASE SCOPE, not verified.

Run these journeys on the device matrix:

| Journey | Required checks |
|---|---|
| Install/login/guest | Permission allow/deny, location disabled, manual address fallback, login failure/retry, logout and account switch |
| Home/catalogue/search | Long titles, real images/failed images, empty results, out-of-stock/variant choices, fast scrolling |
| Cart | Add/change/remove, rapid taps, canonical IDs/variants, coupon/tip/packaging totals, hub switch A→B→A, new items after an accepted payment draft |
| Checkout | Address/serviceability, delivery/pickup, COD/online, disabled duplicate taps, pending recovery banner, keyboard/back navigation |
| Order/tracking | Success/details agree, correct customer/order, rider updates/reconnect, notification/deep-link into the correct order |
| Network | Wi-Fi, mobile data, throttled/latent connection, offline start, captive/no-internet Wi-Fi and Wi-Fi↔mobile transitions |
| Layout/accessibility | Small display, text scale 1.0/1.3/2.0, screen reader labels/focus, contrast, touch targets, keyboard obscuring buttons |

Have five people unfamiliar with the implementation independently find a product, change a variant, add an address and complete a sandbox checkout. Record assistance needed, wrong turns and task completion; do not coach them through unclear copy.

**Proposed acceptance targets, to be frozen before measurement:** zero crashes/ANRs or blocked primary actions; no overflow/unreachable pay controls at supported text scales; local tap feedback p95 ≤150 ms; first usable screen ≤3 s on the midrange device and ≤5 s on the low-end device under the stated healthy network. Measure at least ten cold and ten warm starts per main device. For scrolling, use the actual display frame budget and target <5% missed frames on repeatable catalogue/cart sequences. These are project targets, not claims about currently measured performance.

**Evidence:** device/run manifest, annotated screenshots and recordings, cold/warm timings, profile frame traces, memory samples before/after repeated navigation, crash/ANR logs and an issue list with reproduction steps. Mask account/payment details.

## 3. Cashfree sandbox, followed later by controlled live smoke

Use valid staging users, actual sandbox credentials, the native SDK and publicly reachable staging webhooks. Confirm accepted draft totals against gateway order/payment amount and currency, backend order totals and the eventual UI receipt.

| Case | Required outcome |
|---|---|
| UPI success; each other payment method actually advertised | Backend confirms payment; one logical checkout is fulfilled; UI/receipt shows the correct amount |
| User backs out/cancels before authorising | No paid state; current verified attempt status determines recovery/retry |
| Bank/gateway pending or unknown | Recovery remains; no replacement charge starts as if the result were a failure |
| Timeout/lost callback | Check Status/reopen reconciles from the provider/backend, not from the callback alone |
| Failed attempt followed by successful retry | Attempt IDs remain distinct; eventual success is retained; stale failure does not downgrade paid state |
| Callback before webhook / webhook before callback | Both orders of arrival converge to the same result |
| Repeated callback and duplicate signed webhook | No repeated inventory/cart/fulfilment side effect |
| Invalid signature, wrong amount/currency, unrelated order ID | Rejected without marking paid or changing another order |
| Success followed by an old FAILED/PENDING event | Paid state does not regress |
| Order accepted server-side but client acknowledgement lost | Recovery returns the same logical checkout and correct remainder cart |
| New cart edits during an outstanding accepted draft | Original accepted snapshot is used; only purchased items are removed |

Cashfree can have multiple payment attempts for one order, with distinct `cf_payment_id` values. Deduplicate both provider attempts/events and logical fulfilment; a failed attempt is not proof that every attempt for the order is terminal. Verify webhook signatures on the original request body. [Cashfree idempotency](https://www.cashfree.com/docs/payments/online/webhooks/webhook-indempotency), [signature verification](https://www.cashfree.com/docs/payments/online/webhooks/signature-verification).

**Gate 1:** every advertised method has sandbox evidence, amount/currency and all per-attempt statuses reconcile, and no duplicate effect occurs. A split grocery/restaurant checkout may intentionally create several fulfilment orders; compare against its expected order set, not an unconditional "one database row" rule.

**Live smoke is the last operational step:** after the sandbox/recovery/load gates pass and the owner has agreed the spending limit, use a dedicated account and a few provider-permitted small real payments. Cover ordinary UPI success, one external-app return path and one paid interruption/reopen; optionally validate refund completion if refunds are in release scope and separately authorised. Keep synthetic fault injection and high-volume load out of live payment rails. Record provider payment, bank/reference evidence, backend order and cart result. Never record the PIN/OTP entry. Refund initiation is not refund completion; record its final status later if required.

## 4. App termination and restart recovery

Keep app data installed. Clearing data or uninstalling is a different test and cannot establish persistence recovery. Swipe-away is not proof of process death; record the process ID before/after and the actual termination method.

For Android, separate normal background/resume, background process termination, Settings/ADB force-stop and reboot. `am kill` and `am force-stop` have different semantics; after force-stop, explicitly launch from the icon and check recovery rather than assuming callback redelivery. Use only the selected test device and verified staging application ID. [Android adb process controls](https://developer.android.com/tools/adb).

Use external host/native controls to terminate and relaunch. Add staging-only checkpoint breadcrumbs/controllable pauses where necessary, without changing transaction semantics. If a boundary cannot be reached deterministically, mark it NOT VERIFIED; do not replace it with a mocked-state test and call it device recovery.

| Checkpoint | Expected result after relaunch |
|---|---|
| K1: accepted draft durably saved, before SDK launch | Original snapshot retained; query the original session if present; no invented paid state |
| K2: external UPI app open, before authorisation | Resolve current attempt status; safe wait/retry, no automatic second payment |
| K3: payment succeeds, app receives no callback | Provider/backend confirms original payment; reconcile its exact accepted draft |
| K4: callback handled, order POST not acknowledged | Retain recovery and complete/reconcile without duplicate fulfilment |
| K5: backend committed order, response was lost | Find/replay the original logical checkout; inventory deducted once |
| K6: combined cart/applied-order marker committed, later acknowledgement not saved | Reopening/replay does not subtract items again |

On two primary Android devices, cover K1–K6 with network available on reopen and with offline reopen followed by restoration. Repeat K3/K5/K6 three times. Add force-stop and reboot variants for paid/lost-ack checkpoints. Include normal background return from the UPI app and notification/deep-link re-entry. If iOS ships, run its own termination/relaunch matrix rather than treating Android evidence as iOS coverage.

Use the concrete cart oracle: A×3, accepted purchase A×1, later add B×1. Final durable/UI/server cart must be A×2+B×1, including repeated callbacks/restarts. Repeat for a hub switch, account switch and a unit/variant-bearing item. Unresolved payment keeps recovery; confirmed paid recovery does not launch another SDK session. Intent cleanup occurs only at its correct completion/terminal boundary.

**Proposed timing gates:** show a meaningful recovery/pending state within 5 s of opening; when gateway status and backend are healthy, reconcile a confirmed paid order within 30 s. Record actual provider delays separately; exceeding a timing target must not cause recovery deletion. Zero wrong-user drafts, lost paid intents, duplicate fulfilment, repeated stock deductions or unrelated cart loss is mandatory.

**Evidence:** checkpoint/run ID, old/new PID, termination method, network timeline, recording, masked attempt/order IDs, accepted-draft checksum, safe presence-only persistence diagnostics, before/after stock/cart/order records and provider/webhook timestamps.

## 5. Staging load and capacity

Use real verified customer/rider credentials and valid seeded records. Run the generator on another machine/process pool, measure its CPU/network too, and record app-server/DB/Redis resources and topology. On Windows, use explicit Locust master/worker processes if distribution is necessary; its `--processes` shortcut relies on fork and is unavailable there. [Locust distributed operation](https://docs.locust.io/en/stable/running-distributed.html).

**Fix the existing harness before trusting numbers:**

- [Locust file](D:/Fastkirana/fastapi-backend/load_tests/locustfile.py) references `os.environ` without importing `os`; it uses identity headers instead of verified user sessions, generated product/address IDs, a cart path that must be checked against actual routing, and counts several 400/404/409 responses as success. Replace this with valid journeys and explicit semantic assertions. Expected negative-case rejections belong in a separate test, not the successful-shopper numerator.
- Replace the single-domain production substring check with an exact allowlist of staging origins, including redirect/fallback checks. Both application brands have production domains. No production load override in the normal runner.
- [Database simulator](D:/Fastkirana/fastapi-backend/load_tests/run_simulation.py) mainly executes `SELECT 1`; it is a pool probe, not checkout capacity evidence.
- [WebSocket script](D:/Fastkirana/fastapi-backend/scripts/load_test_websockets.py) opens a rider URL without the current ticket/auth flow and sends an assumed telemetry protocol. Update it to current authenticated, channel-bound tickets and accepted event schemas. An HTTP 101, idle connection or timeout is not proof of valid order updates reaching subscribers.

**Dataset:** separate account per simulated shopper, known hub/address, sufficient positive-path inventory, canonical underscore/prefix IDs, variants, valid coupons and captured quotes. Tag records with a run ID for reconciliation/cleanup. Test scarcity separately: many buyers compete for the final unit, with no oversell or duplicate deduction.

**Provisional workload:** 55% catalogue/search, 20% cart reads/writes, 10% address/quote, 5% checkout writes, 10% order/tracking reads. Add a separately measured authenticated rider/subscriber WebSocket workload. Use realistic pacing (initially 3–8 s) and valid user sequences. Report achieved endpoint RPS and completed checkouts/minute: virtual-user count is not throughput or supported daily users.

| Stage | Initial proposal |
|---|---|
| Smoke | 5 shoppers, 5 min; every route/auth/assertion works |
| Ramp | 25 for 10 min → 50 for 15 min → 100 for 15 min; gradual spawning |
| Spike | 150 for 2 min, then 25 for 10 min recovery |
| Soak | Highest sustainable target level for 60 min |
| Correctness burst | Final-unit race; simultaneous same-order retries/callbacks; shared Redis across multiple backend workers |

These counts are experiment steps, not a capacity promise. Freeze a business peak target after the baseline; increase only while service health and provider limits permit it. Exercise the deployed Next.js/proxy→FastAPI path. Test independently supported direct routes separately so double-testing does not hide bottlenecks.

Keep high-volume gateway traffic behind a staging adapter with realistic latency/failure fixtures; actual Cashfree sandbox verification remains a separate low-volume suite. Do not flood OTP, maps, SMS, printing or payment providers to manufacture backend load.

**Proposed target-load gates:** valid business journeys ≥99% successful; no correctness failures; p95 catalogue/search <800 ms, cart/quote <1 s, internal order handling <1.5 s, ordinary API p99 <3 s. Measure upstream gateway time separately rather than hiding it in exclusions. For tracking, target p95 update delivery ≤2 s and <1% unexpected disconnects; unauthorised subscribers receive zero protected events.

Collect per-route p50/p95/p99/RPS, business success/rejection/timeout rates, order counts, stock reconciliation, DB pool waits/locks/connections, Redis availability/latency, queue lag, worker CPU/memory and WebSocket delivery/reconnect metrics. Return-to-baseline resource use after the spike is required; investigate sustained memory growth during soak.

Stop escalation on any duplicate/wrong-user/amount/stock corruption, unintended production traffic, persistent pool exhaustion, >5% unexpected request failures for 60 s, or resource saturation near configured limits. Preserve the run evidence. Classify the failure, fix it and rerun the affected stage; do not weaken assertions to obtain a green chart.

## 6. Deliverables, gates and schedule

Create one evidence folder per candidate/run, for example `docs/verification/real-world/<run-id>/`, containing a manifest, case matrix CSV, redacted screenshots/recordings, device performance traces, provider/webhook evidence, API/load CSV/HTML reports and final order/cart/stock reconciliation. Each case must show PASS, FAIL, BLOCKED, NOT RUN or explicitly justified OUT OF SCOPE. Aggregate counts cannot replace these statuses.

| Completion gate | Required evidence |
|---|---|
| Harness/environment | Correct environment and real app/provider path proven; no skipped business logic or fake success accounting |
| Device UX | Required Android coverage and unassisted tasks pass; declared iOS scope honoured |
| Payment/recovery | Supported methods, all valid interruption boundaries and correct state/amount reconciliation; no duplicate/lost paid outcomes |
| Capacity | Chosen target sustained with the actual topology and semantic assertions; scarcity/idempotency controls pass |
| Release candidate | Affected defects fixed; local regression suites and required device cases repeated on the final signed artifact |
| Live smoke | Owner-approved bounded transactions reconcile; remaining delayed settlement/refund results tracked explicitly |

Allow roughly **4–6 engineering/QA days plus device/access and provider delays**: day 1 staging/harness/data, day 2 device UX and sandbox, day 3 interruption matrix, day 4 load/soak and fixes, days 5–6 regression plus controlled live smoke/report. This is a planning estimate, not a deadline; iOS setup, missing devices or reproduced defects extend it.

**Final handoff must state:** what was actually tested, exact artifact/environment/devices, measured capacity, remaining failures/coverage gaps, and any live transaction still awaiting its final status. A test name, an SDK callback, a 200 response, an open WebSocket or a successful `SELECT 1` does not independently establish release readiness.
