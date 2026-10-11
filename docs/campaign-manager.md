# Campaign Manager

Open **Admin → Marketing → Campaign Manager** to edit the shopping section shown on the grocery home screen in both the website and Flutter app. Choose an occasion, everyday collection, value collection, or seasonal template, then edit its layout, copy, artwork, and products before publishing. The department row containing Fresh, Fashion, Mobiles, and Pharmacy is removed from customer screens.

## Choose a template and layout

The template library provides eight starting points with distinct artwork, collection filters, search suggestions, and copy. Templates start in demo mode with clearly labelled illustrative prices; they do not create an offer or catalogue inventory.

| Template | Type | Starting layout |
| --- | --- | --- |
| Navratri | Festival | Classic: tall rotating product card beside four category cards. |
| Diwali | Festival | Classic: festive lamps, sweets, and home decorations. |
| Holi | Festival | Split: two large category spotlights, two compact cards, and a product strip. |
| Ramadan | Festival | Banner: wide header artwork, a product strip, and a scrolling category row. |
| Daily Essentials | Everyday | Grid: four equal category tiles above a product strip. |
| Value Picks | Value | Deals: prominent rotating product and price above compact category cards. |
| Summer | Seasonal | Banner: seasonal fruit and drinks. |
| Monsoon | Seasonal | Split: tea, cooking ingredients, warm meals, and home care. |

Choose **Campaign template**, then click **Load template**. Options are grouped by Festival, Everyday, Value, and Seasonal, with an artwork thumbnail for the selection. Loading replaces the current editor content with a fresh editable copy. If you have unsaved changes, the editor offers **Replace current draft** or **Cancel template change** before replacing them. Saved drafts and the customer publication stay unchanged until you save or publish. Save work you want to retain before loading another template.

Use **Campaign layout** to choose **Classic**, **Banner**, **Split**, **Grid**, or **Deals** independently of the occasion. All five retain four category cards, editable collection tabs, linked catalogue products, independent animation clocks, and the existing search destinations. Category rows scroll horizontally on narrow screens. Changing a layout changes the composition in both customer applications when published; it requires no app release.

## Choose the store

Use the dashboard's existing store selection before editing. A selected store saves its own draft and publication. All stores edits the global campaign. A store-specific publication overrides the global one; stores without a publication inherit the global campaign. A hidden store campaign stays hidden even when the global campaign is enabled.

Branch admins are restricted to their assigned store. The APIs reject requests for another store or global scope; root admins can choose a store or all stores. Switching stores reloads that scope's saved draft or publication, so save any changes you want to retain before switching.

The editor loads only the selected scope's own saved content. If that store has no saved configuration, editing starts with the bundled template, even if its customers currently inherit the global publication. Publishing then creates that store's override.

## Edit and preview

The editor has ordinary fields, image uploads, selectors, and reorder buttons. No JSON editing is required.

| Editor section | Controls |
| --- | --- |
| Campaign & labels | Layout, show campaign, autoplay, demo mode, campaign name, promotional heading, curved-tab label, loading/empty copy, and demo labels. |
| Header slides | Add, remove, or reorder 1–8 slides; choose illustration, large title, or brand style; edit the title, top line, subtitle, and image. |
| Rotating product card | Add, remove, or reorder 1–12 slots; link a catalogue product or choose a manual demo; set its card category and search phrase. |
| Four category cards | Edit each heading, image, search query, and filter keywords. Exactly four stationary cards are arranged by the chosen layout. |
| Collection tabs & product filters | Add, remove, or reorder 1–8 illustrated tabs, and edit their labels and keywords. |
| Colours, artwork & motion | Eight colour roles, header/product/search intervals, crossfade duration, and decoration artwork. Leave the decoration image blank to hide it. |
| Search suggestions | Fixed prefix and one rotating suggestion per line. |

The mobile preview shows the edited section, catalogue results, and search. It is read-only: its links and cart controls cannot navigate or modify a cart. Use **Play preview** and **Pause preview** outside the preview to inspect motion. Playback also respects the campaign's autoplay setting and the browser's reduced-motion preference. Invalid configuration shows validation errors and uses the template in preview until fixed.

Template loading does not publish by itself. The editor's current preview always uses its selected layout.

## Draft, publish, and hide

- **Save Draft** saves private work for the selected scope. Customers continue to see the existing publication.
- **Publish** validates the editor content and atomically saves the same configuration as both draft and publication. Both customer platforms then load it from the public API.
- **Hide Campaign** writes `enabled: false` to the publication while retaining the saved draft. The existing grocery and food features remain available.

To show a hidden campaign again, select **Show campaign** in the draft and publish it. Saving a draft alone does not change customer visibility.

Web reloads the published configuration when the page becomes visible and every 60 seconds while visible. Flutter reloads on app resume, hub change, and pull-to-refresh. A customer can refresh to see a recent publication sooner. Publishing changes stored content; it does not deploy website code or release an app binary.

When there is no published campaign, or a campaign request fails, customers see the bundled Navratri example. A successful response with `enabled: false` hides the campaign. This is why Hide Campaign persists a disabled publication rather than deleting the row.

## Real products and demo examples

Choose **Manual demo product** only when the campaign's **Demo campaign (illustrative prices)** setting is enabled. Manual names, images, and prices are examples; they cannot add an invented product to the cart. All eight starting templates use demo mode. The new templates use equal original and example prices, so they do not imply a discount. The original Navratri example prices are documented in [the template guide](navratri.md).

For a live campaign, link every rotating slot using its catalogue selector, then turn demo mode off. Validation requires a `productId` for every slot before the campaign can be saved as live. Current store catalogue data supplies the customer's product name, image, prices, stock, and availability; the demo price fields do not change catalogue pricing. Both renderers fetch selected IDs that are absent from the bounded home feed through the existing scoped product-detail API, so a valid selection does not depend on the first 500/1,000 home items. These lookups never substitute another store's cache after failure. Missing, unavailable, out-of-stock, and restaurant products are omitted from the promotional rotation. Emoji or invalid catalogue image values retain the configured campaign artwork.

Collection tabs filter existing live products by names, slugs, descriptions, categories, and tags. A tab with empty keywords uses all configured category and tab keywords. Matching uses word prefixes, allowing `flower` to find `flowers` while keeping `diya` separate from `dandiya`. Category cards open the existing search with their configured queries; a query may have no available results. Editing a campaign does not create inventory, a discount rule, or a checkout offer.

## Images and colours

Use **Upload image** to reuse the dashboard's existing upload flow, or enter a local file name, absolute image path, or HTTPS image URL. Examples are `dandiya.svg`, `/campaigns/diwali.webp`, and `https://cdn.example.com/diwali.png`. Upload previews report an image that cannot load.

Uploaded runtime images remain at their returned live URLs, so they do not need copying into Flutter assets. The bundled fallback's local SVG files are mirrored between the platforms using the repository's sync script. SVG, PNG, JPEG, WebP, and AVIF inputs are supported; use transparent artwork where it should sit directly on the campaign background. Labels and prices remain editable text rather than part of an image.

Image validation rejects unsafe schemes, protocol-relative URLs, path traversal, and embedded credentials. Colours require six-digit hex values. The eight roles are background, cards, primary text, small text, header text, header outline, selected underline, and tab illustration surface. Keep text and outlines readable against the colours you choose and inspect the mobile preview.

Header, product, and suggestion intervals accept 1,500–60,000 milliseconds. Crossfade accepts 0–1,200 milliseconds. The template uses 4,000 / 2,500 / 3,000 ms intervals and a 400 ms fade. Turning autoplay off leaves content stationary.

## API contracts

Both Next.js and FastAPI provide these endpoints. Web campaign administration stays on the local Next.js route so verified NextAuth cookies are preserved, including when other admin routes proxy to FastAPI. The direct FastAPI admin endpoint requires a signed HS256 Bearer token with an expiry and a configured signing secret. Both backends load the current user from the database and reject blocked, deleted, demoted, or unauthorized accounts; token role/store claims and identity headers cannot grant campaign access. Every successful response is `no-store`.

| Endpoint | Result |
| --- | --- |
| `GET /api/admin/campaign?storeId=<id>` | `{ "draft": object \| null, "published": object \| null }` for the exact authorized scope. |
| `PUT /api/admin/campaign` | Validates and saves the requested action; returns `{ "success": true, "draft": object \| null, "published": object \| null }`. |
| `GET /api/homepage-campaign?storeId=<id>` | `{ "campaign": object \| null }`, selecting the published store campaign or global fallback. Never returns a draft. |

A request to hide an existing publication can be:

```json
{
  "action": "disable",
  "storeId": "hub-209206"
}
```

For `action: "save-draft"` or `action: "publish"`, also include `campaign` with the complete validated configuration. The bundled `public/navratri/navratri.json` supplies a complete example. Publish saves draft and publication together. Omit `storeId` for global scope when authorized.

For `action: "disable"`, the server disables the existing scoped publication, or creates a disabled scoped copy of the inherited global publication. If neither exists, include the complete current configuration so the server can persist a valid disabled publication. Campaign Manager includes its current configuration with every action.

Malformed JSON returns 400; invalid configuration returns 422 with field details; missing authentication returns 401; unauthorized roles or store selection return 403; an unknown selected store returns 404. Loading failures disable editor save actions and expose Retry, preventing an unseen configuration from being overwritten.

## Storage and source locations

Existing `store_settings` / Prisma `StoreSetting` rows hold JSON values; no new table or migration is required.

| Scope | Draft key | Published key |
| --- | --- | --- |
| Global | `homepage_campaign_draft` | `homepage_campaign` |
| One store | `store:<id>:homepage_campaign_draft` | `store:<id>:homepage_campaign` |

Publication writes draft and published values in one database transaction. Hide changes the published key and preserves the draft. Public settings endpoints exclude draft keys. Publish/hide clear settings and homepage caches; the campaign public endpoint is uncached.

The editor is `src/components/admin/campaign-manager.tsx`, integrated into `src/components/admin/admin-dashboard.tsx`. The template registry is `src/lib/campaign-templates.ts`; shared metadata and new configurations live under `public/navratri/templates/`. Shared TypeScript validation is `src/lib/campaign-config.ts`. The Next.js API routes are under `src/app/api/admin/campaign/` and `src/app/api/homepage-campaign/`. FastAPI uses `routers/campaigns.py` and `services/campaign_config.py`. Customer integration and local artwork paths are documented in [the Navratri template guide](navratri.md).

## Verification status

Confirmed: 48 backend campaign tests, 28 Node tests, 37 Flutter tests, and 16 browser scenarios pass. The Node checks cover shared data/rendering, authorization, proxy routing, scoped detail hydration, and store price overrides. Browser scenarios passed across targeted batches and include admin editing, private drafts, publication/hiding, catalogue linking, typed keywords/suggestions, saved-content reload, responsive layout, independent rotation, reduced motion, and timer cleanup. Selected products outside the home feed, stale/failed store reads, and invalid artwork fallbacks have dedicated regressions. Targeted ESLint, Python compilation, and the Flutter analyzer passed.

The final production build, `npm run build -- --webpack`, passed, including TypeScript validation and generation of 90 static pages. It ran with a process-only offline database URL; homepage and sitemap reads produced their expected fallback logs. This verifies compilation and fallback behavior, not publication against the live database.

Graphify was used to locate configuration/authentication relationships, followed by direct source review. Its incremental AST update includes the new editor, APIs, and customer integration. SQL graph extraction remains incomplete because `tree_sitter_sql` is absent, and three existing Android Gradle files were only partially extracted; the graph is a navigation aid rather than runtime proof.

No live settings rows were changed by backend tests, and no live campaign was published or application deployed during implementation. Use the targeted commands and manual checks in [the template guide](navratri.md) when changing the feature.
