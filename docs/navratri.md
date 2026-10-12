# Navratri template and shopping-section integration

The Navratri design is the bundled fallback and one of eight starting templates for the reusable Campaign Manager. Administrators can choose a template and layout, rename, recolour, rearrange, and publish the section without editing code. See [Campaign Manager](campaign-manager.md) for the complete template library and editing/publication workflow.

Both customer applications render **Classic**, **Banner**, **Split**, **Grid**, and **Deals** compositions from the published `layout` field. Classic retains the original tall rotating product card beside four stationary category cards; the other layouts use category spotlights, equal tiles, wide banners, or prominent promotional prices. All share the rotating header, sticky search, curved central tab, and filtered catalogue. The department row containing All, Fresh, Fashion, Mobiles, and Pharmacy has been removed from both customer interfaces. Existing grocery sections, serviceability rules, food mode, search, voice search, and cart behavior remain in place.

## Bundled template and demo prices

`public/navratri/navratri.json` is the canonical bundled example, mirrored at `fastkirana_flutter/assets/navratri/navratri.json`. It uses orange `#FF831F`, cream `#FFF8DF`, warm brown `#985F39`, a contrasting outline beneath cream headlines, and deeper brown for small text.

**All manually configured prices in this Navratri template are illustrative examples, not live FastKirana offers.** The template has `demo: true`, and customer screens identify demo pricing.

| Demo product | Example original price | Example sale price |
| --- | ---: | ---: |
| Dandiya Sticks | ₹149 | ₹99 |
| Mata Chunri | ₹129 | ₹89 |
| Garba Jacket | ₹599 | ₹449 |
| Vrat Chips | ₹60 | ₹45 |

Manual examples open existing search and never create cart items. Live template campaigns must link every rotating product slot to a catalogue `productId`; custom compositions require links for slots used by visible spotlight blocks. Both clients resolve linked names, images, prices, and availability from the current store's catalogue; unavailable and restaurant products are omitted. Collection blocks and the catalogue below the template tabs reuse existing live `ProductCard` components and real checkout behavior.

## Runtime configuration and fallback

Both clients request `GET /api/homepage-campaign?storeId=<hub-id>`. Only published configuration is public. A store-specific publication takes precedence over the global publication; absent store configuration inherits the global campaign. An explicit `enabled: false` publication hides the campaign for that scope.

When the endpoint returns no campaign or the request fails, the clients use the bundled Navratri example so campaign loading does not block the home screen. Web refreshes published data on visibility changes and every 60 seconds while visible. Flutter reloads when its selected hub changes, the app resumes, or the customer pulls to refresh. The new renderer and bundled template assets must first ship in an updated application. Thereafter, publishing supported layouts and content requires no app rebuild; new bundled files or renderer types require a release.

## Shared contract

The schema is version `1`. `src/lib/campaign-config.ts` supplies TypeScript validation and defaults; `fastapi-backend/services/campaign_config.py` supplies equivalent backend validation. Flutter models live in `fastkirana_flutter/lib/features/navratri/navratri_data.dart`.

| Field | Structure |
| --- | --- |
| `version`, `demo` | Required version `1` and boolean demo flag. |
| `layout` | Optional `classic`, `banner`, `split`, `grid`, or `deals`; older publications default to `classic`. |
| `composition` | Optional `template` or `blocks`; older publications default to `template`. |
| `blocks` | Optional ordered list of up to 16 blocks; defaults to `[]`. Custom composition requires at least one visible block. |
| `enabled`, `autoplay` | Optional booleans, both defaulting to `true`. |
| `searchPrefix` | Fixed search copy; defaults to `Search for`. |
| `decorationImage` | Local image name, absolute path, HTTPS URL, or `null` to hide decoration; defaults to `string-lights.svg`. |
| `labels` | Seven text fields: `sectionLabel`, `specialsHeading`, `curvedTabLabel`, `loadingText`, `emptyText`, `demoLabel`, `resultsDemoLabel`. |
| `appearance` | Eight six-digit hex colours: `background`, `card`, `text`, `smallText`, `headerText`, `headerOutline`, `underline`, `tabSurface`. |
| `timings` | Millisecond values: `headerMs`, `productMs`, `searchMs`, `crossfadeMs`. |
| `searchSuggestions` | 1–12 strings, with only the suggestion animated. |
| `navigation` | Compatibility array; the current bundled template uses `[]` and customer screens render no department row. |
| `headers` | 1–8 `{ id, kind, eyebrow, title, subtitle, image }` entries; kind is `illustration`, `title`, or `brand`; image may be `null`. |
| `products` | 1–12 `{ id, name, image, originalPrice, price, currency: "INR", categoryId, destinationId, productId? }` entries. |
| `categories` | Exactly four `{ id, label, image, destinationId, keywords }` cards. |
| `tabs` | 1–8 `{ id, label, image, keywords, productIds? }` entries; optional pinned catalogue IDs default to `[]`. |
| `destinations` | `{ id, kind: "search", query }` entries resolving through existing search. |

IDs stay stable when copy changes, are unique within each collection, and contain only letters, numbers, underscores, and hyphens. Every destination and category reference must resolve. Intervals are integers from 1,500 to 60,000 ms; crossfade is 0–1,200 ms. Prices must be finite and nonnegative, and sale price cannot exceed original price. With `demo: false`, template compositions require every promotional slot's catalogue reference; block compositions require references for slots used in visible spotlight blocks. Unused source slots may remain unlinked.

The default timing remains a 4-second header interval, 2.5-second product interval, 3-second search suggestion interval, and 400 ms crossfade. Header and product rotation are independent; headings, category cards, and card surfaces remain stationary. Changing the layout affects placement and emphasis rather than the animation clocks or inventory behaviour.

## Assets

The original Navratri template includes 15 local SVG illustrations. The seven additional templates contribute 35 occasion-specific SVGs, giving 50 shared illustrations across the library. Artwork has transparent backgrounds and no embedded labels, prices, external resources, or animation. A diya and rangoli form the respectful Navratri header.

| Purpose | Files under `public/navratri/` |
| --- | --- |
| Header artwork | `navratri-festive.svg`, `fastkirana-basket.svg` |
| Rotating products | `dandiya.svg`, `chunri.svg`, `garba-jacket.svg`, `vrat-chips.svg` |
| Category cards | `puja-thali.svg`, `fasting-food.svg`, `dandiya-ready.svg`, `vrat-snacks.svg` |
| Tabs | `top-picks.svg`, `pooja-decor.svg`, `flowers-leaves.svg`, `chunri-idols.svg` |
| Decoration | `string-lights.svg` |

`public/navratri/templates/index.json` lists each template's ID, name, type, description, manifest path, and thumbnail. The original configuration remains `navratri.json`; Diwali, Holi, Ramadan, Daily Essentials, Value Picks, Summer, and Monsoon configurations live in `templates/<id>.json`. The TypeScript registry parses every configuration against the same publication schema and returns a deep copy when starting a draft. All eight configurations, the index, and their referenced artwork are mirrored into Flutter assets by the sync script; `assets/navratri/templates/` is registered explicitly in `pubspec.yaml`.

For bundled artwork changes, replace the local file, preserve its `viewBox`, edit the canonical JSON if its name changes, then run:

```powershell
node scripts/sync-navratri-assets.mjs
```

The supplied fallback uses local SVG names, copied into Flutter's asset bundle. Runtime images uploaded through Campaign Manager use their returned live URLs and need no mirroring or app rebuild. Both renderers support local names, absolute image paths, and HTTPS image URLs, with raster or SVG artwork. Local names resolve under `/navratri/` on web and `assets/navratri/` in Flutter. Do not put labels or prices inside images.

## Web implementation

Custom compositions use `src/lib/campaign-blocks.ts`, `campaign-block-canvas.tsx`, and `campaign-blocks.module.css`. The editor is `src/components/admin/campaign-block-editor.tsx`, embedded in the existing manager. Both publication validators check block IDs, type/presentation compatibility, source references, images, visibility, and motion. Flutter uses `campaign_block.dart` and `campaign_block_section.dart`, and the shopping section selects the renderer from `composition`. Older JSON remains valid without either new field. No database migration is required.

Each block contains `{ id, type, enabled, title, body, image, destinationId, itemIds, tabId, presentation, motion }`. Types are `banner`, `categories`, `spotlight`, `collection`, `image`, and `text`. `itemIds` selects header/category/promotion IDs in the specified order; an empty array uses the whole corresponding source pool. Collection blocks require a valid `tabId`; other types cannot use it. Presentations are `wide` for banners/images, `grid`/`row` for categories/collections, `wide`/`offer` for spotlights, and `plain` for text. Image banners require artwork; text messages require copy.

Motion is `{ preset, speed }`, defaulting to `fade` and `normal`. Presets are `none`, `fade`, `slide`, `float`, `zoom`, and `sparkle`; text supports `none`, `fade`, and `slide`. Speed is `slow`, `normal`, or `fast`. The UI guide documents intervals and playback behavior. Effects use CSS on web and lifecycle-aware switchers/controllers on Flutter; no new animation dependency or generated raster artwork is required. Native collection cards receive block-specific hero tags so repeated shelves do not collide during product navigation.

`src/components/home/navratri/` contains `data.ts`, `use-campaign.ts`, `use-rotation.ts`, `navratri-search.tsx`, `navratri-section.tsx`, and `navratri.module.css`. `StorefrontClient` mounts the configured section before the existing hero in grocery mode, with live products scoped to store and serviceability; the navbar uses the campaign's sticky search. The configuration hook cancels outstanding requests, listeners, and refresh intervals when inactive or unmounted.

`NavratriSection` accepts `data`, `products`, and `loading`; supplied products remain scoped to the active store. Header and product timers stay in small client components. Images preload, hidden slides are `inert` and `aria-hidden`, and rotating product links leave the focus order when hidden. Keyboard focus within the grid pauses rotation; Pause/Play, browser visibility, `autoplay`, and `prefers-reduced-motion` also control playback. Timers are cleared on unmount, and initial state stays consistent for hydration.

Supply `storeId` for linked live products. `use-promotion-products.ts` resolves missing selected IDs with scoped product-detail reads, cancels superseded requests, and excludes failed/unavailable results. `resolveLinkedProducts` can disable those reads outside a serviceable location. The shared home feed remains unchanged. Non-image catalogue values use the configured campaign artwork.

Both platforms filter live catalogue names, slugs, descriptions, category names/slugs, and tags. Pinned product IDs appear in the administrator's order, followed by explicit keyword matches. A pinned tab with empty keywords shows only its selected products. An unpinned tab with empty keywords uses the union of category and tab keywords; other tabs use their own terms. Matching uses word prefixes, so `flower` finds `flowers` while `diya` cannot match `dandiya`. Restaurant items are excluded. Loading suppresses previous-store products during a hub change.

Tab IDs do not give a collection special filtering behaviour. Empty-keyword tabs show every configured demo example, while a tab named `top-picks` with explicit keywords obeys those keywords on both platforms.

## Flutter implementation

The feature lives in `fastkirana_flutter/lib/features/navratri/`: typed data/loading in `navratri_data.dart`, lifecycle and switcher behavior in `navratri_animation.dart`, and reusable section/search/card/tab widgets in `navratri_shopping_section.dart`.

`home_screen.dart` watches the campaign provider for the selected hub, mounts search in a pinned `SliverPersistentHeader`, and mounts the section before the existing hero. Existing `SearchScreen` and voice-search flows handle search queries; linked products reuse the existing product-detail flow. Results use the existing `ProductCard`. The bundle directory is registered in `pubspec.yaml`.

`AnimatedSwitcher` uses stable keys and transitions product artwork, prices, and name as one unit. SVG/raster loading preloads the next illustration. Lifecycle observation and TickerMode pause inactive UI; disposal cancels timers and removes observers. `MediaQuery.disableAnimations` and `MediaQuery.accessibleNavigation` stop autoplay and remove transition duration. Outgoing slides retain their pixels during crossfade while losing semantics, focus, and pointer targets. Heights account for text scaling and the tallest configured header so the grid stays still.

## Confirmed checks and reruns

Confirmed for the expanded implementation: 96 campaign backend tests, 52 Node tests, 84 Flutter tests, and 22 browser scenarios pass across targeted batches. Coverage includes the eight templates, five fixed layouts, six custom block types, all artwork presets, source order/visibility, draft/reload/publication, live-slot validation, pinned-collection parity, scoped detail hydration, and existing auth/hide flows. Flutter checks cover 320 px at 2× text, finite entrance intermediate states, artwork-only motion for actual inventory, stable geometry, lifecycle cleanup and ticker disposal. Targeted lint and the Flutter analyzer passed. Existing SVG assets and their platform mirrors remain shared. Native visual evidence can be regenerated with `flutter test --no-pub --dart-define=CAMPAIGN_CAPTURE=true test/widgets/campaign_block_builder_test.dart`; its captures preload bundled fonts and product artwork. Final review/build validation is recorded in the Campaign Manager guide.

Useful targeted reruns from the repository root:

```powershell
npx tsc --noEmit
npx tsx --test src/lib/__tests__/navratri.test.ts
npx tsx --test src/lib/__tests__/campaign-templates.test.ts
npx tsx --test src/lib/__tests__/campaign-blocks.test.ts
npx tsx --test src/lib/__tests__/campaign-auth.test.ts src/lib/__tests__/campaign-routing.test.ts
npx tsx --test src/lib/__tests__/campaign-products.test.ts src/lib/__tests__/product-detail-scope.test.ts
npx playwright test e2e/navratri.spec.ts --project="Desktop Chrome" --workers=1
npm run build -- --webpack
```

From `fastapi-backend`:

```powershell
.\venv\Scripts\python.exe -m pytest tests/test_campaign_config.py -q
```

From `fastkirana_flutter`:

```powershell
C:\src\flutter\bin\flutter.bat analyze --no-pub lib/features/navratri lib/features/home/home_screen.dart lib/features/home/widgets/home_top_header.dart lib/features/home/main_shell.dart test/widgets/navratri_shopping_section_test.dart
C:\src\flutter\bin\flutter.bat test --no-pub test/widgets/navratri_shopping_section_test.dart
C:\src\flutter\bin\flutter.bat test --no-pub test/unit/navratri_linked_products_test.dart
C:\src\flutter\bin\flutter.bat test --no-pub test/unit/campaign_templates_test.dart
C:\src\flutter\bin\flutter.bat test --no-pub test/widgets/campaign_block_builder_test.dart
```

Review 320 px, approximately 390 px, desktop widths, and enlarged text; verify steady grid geometry, category destinations, filtered tabs, Pause/Play, reduced motion, lifecycle cleanup, hidden campaigns, and store switching. Backend campaign tests use isolated or mocked persistence and do not alter live settings. No deployment or live campaign publication was performed during implementation.
