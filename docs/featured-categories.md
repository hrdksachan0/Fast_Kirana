# Flutter featured categories

The home screen now has a short, editable category rail above Explore Categories. It uses existing category photos on flat pastel surfaces, readable two-line names, a 48px View all target and a small press response. Reduced motion disables the press transition and category route animation. Hardcoded order ranks, LIVE badges, delivery times, prices and offers have been removed from this rail.

## Admin workflow

Open **Admin → Products & Inventory → Categories → Featured categories**. Choose the store before editing, then save before switching stores.

- Edit the heading and show/hide the whole section.
- Select up to six existing grocery parent categories and move them up/down.
- Change a display name without changing its catalogue destination.
- Upload artwork or use an HTTPS URL/absolute public image path. Choose Fill for photos and Fit for cutouts.
- Choose a pastel background and one optional editorial badge: Featured, Seasonal or Everyday.
- Preview the layout before saving. Empty and unavailable categories are omitted by the app.

The editor refreshes category metadata for the selected store and prevents saving when settings/catalogue loading fails. Upload/save completion from an unmounted editor cannot overwrite the next store's edit session.

## Data and behaviour

Existing `StoreSetting` storage holds a JSON string under `featured_categories`, or `store:<storeId>:featured_categories` for a store override. No migration is required. Global settings are inherited until a store override is saved. Missing/malformed config falls back to up to six grocery roots in catalogue order. A saved empty selection, all hidden items or a disabled section stays hidden.

Both Next and FastAPI expose verified-admin GET/PUT `/api/admin/featured-categories`. Writes validate image paths, unique IDs, a six-item limit and real grocery parent references in one batched query. Assigned admins stay within their store. Browser saves use the same-origin Next route; API clients use a verified Bearer token. Compatibility identity headers do not authorize these endpoints.

Flutter reads the config from the existing store-scoped settings feed, refreshes it through Home's existing polling and on app resume, and waits for settings during a store change. Save invalidates existing settings caches. Deploy the web/admin and backend changes, then release the Flutter app to deliver this feature to customers.

This is manual editorial curation. Automatic ranking from orders, pricing, campaign schedules and experiments are future scope. No production settings were written during local validation.

## Local verification

Validation covers API permissions, store inheritance/isolation, invalid artwork and unsupported badges; native category identity/navigation, empty settings, reduced motion and 320/390/672px layouts including 2× text; and real admin editor upload, reorder, save, reload, failure recovery and visibility controls using isolated browser fixtures.

Captures are saved in `artifacts/featured-categories/`. They show the actual Flutter widget and admin component with synthetic catalogue entries and the project's existing category photos.

Verified locally: 27 Node tests (including strict auth), 113 backend tests (including campaign regressions), 11 Flutter tests, 4 browser tests on the production standalone server, targeted Flutter analyzer and ESLint, and the Next production build with TypeScript and 90 generated pages. The build used an intentionally offline database and its existing homepage/sitemap fallbacks; database-backed API/browser mutations used isolated fixtures.
