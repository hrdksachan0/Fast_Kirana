# Graph Report - Fastkirana  (2026-08-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 3229 nodes · 6509 edges · 184 communities (143 shown, 41 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 218 edges (avg confidence: 0.52)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `abb5b841`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- package:flutter/material.dart
- admin_extended.py
- requireAdmin
- auth
- utils.ts
- cn
- category_products_screen.dart
- home_screen.dart
- triggerHaptic
- restaurant-orders-console.tsx
- prisma.ts
- design_system.dart
- ConsumerState
- brand_design_system.dart
- formatPrice
- product_card.dart
- checkout_screen.dart
- getLast10Digits
- storefront-client.tsx
- schemas.py
- layout.tsx
- order.dart
- product.dart
- models.py
- jwt.py
- checkout/page.tsx
- verify_payment
- routers/auth.py
- Order
- store-config.ts
- orders_screen.dart
- constants.ts
- brand_input.dart
- compilerOptions
- cart_screen.dart
- admin-dashboard.tsx
- table_booking_screen.dart
- api/products/route.ts
- api/orders/route.ts
- dependencies
- app/page.tsx
- otp_screen.dart
- cart.dart
- restaurant.dart
- admin-csv-import.tsx
- components.json
- package:flutter_riverpod/flutter_riverpod.dart
- profile.py
- api_endpoints.dart
- formatDate
- List
- restaurant.py
- app_colors.dart
- address.dart
- product_repository.dart
- user.dart
- addresses.py
- app_router.dart
- lib/providers/cart_provider.dart
- skeletons.tsx
- usePushNotification
- auth_provider.dart
- ../core/network/api_client.dart
- delivery.py
- database.py
- paytm_callback
- products_helper.py
- public.py
- coupon.dart
- add_address_screen.dart
- splash/splash_screen.dart
- scripts
- admin-restaurant-console.tsx
- devDependencies
- ConnectionManager
- category.dart
- settings.py
- banner.dart
- cart_repository.dart
- onboarding_screen.dart
- kot-print.ts
- FastApiClient
- auth/splash_screen.dart
- @JsonSerializable
- State
- web/manifest.json
- PaytmChecksum
- admin-bulk-update.tsx
- deals-curation-hub.tsx
- location-picker.tsx
- main.py
- auth_repository.dart
- public/manifest.json
- login_screen.dart
- api_client.dart
- order_repository.dart
- restaurants/[id]/page.tsx
- api/settings/route.ts
- admin-analytics.tsx
- admin-reports.tsx
- formatDisplayEmail
- admin_coupon_detail.dart
- add_review_screen.dart
- admin-alerts.tsx
- admin-inventory-center.tsx
- admin-rider-cash.tsx
- live-carts-panel.tsx
- functions
- settings_screen.dart
- admin-forecast.tsx
- flash-deals-tab.tsx
- order-tracking-modal.tsx
- seed.ts
- send-email-otp/route.ts
- track/page.tsx
- push-notifications-tab.tsx
- admin-restaurant-report.tsx
- admin-sort-manager.tsx
- hub-nav.tsx
- next-auth.d.ts
- config.py
- master-lookup/route.ts
- hero-banner.tsx
- test_api.py
- widget_test.dart
- use-settings.ts
- MainActivity.kt
- payment-section.tsx
- actions-bar.tsx
- filters.tsx
- privacy-policy/page.tsx
- cart-fly-animation.tsx
- proxy.ts
- @base-ui/react
- bcryptjs
- class-variance-authority
- clsx
- date-fns
- eslint.config.mjs
- routers/__init__.py
- product_providers.dart
- framer-motion
- lru-cache
- lucide-react
- next.config.ts
- pg
- prisma
- @prisma/adapter-pg
- react
- react-dom
- shadcn
- sonner
- tailwind-merge
- @types/node
- @types/nodemailer
- @types/papaparse
- @types/pg
- @types/react
- zustand
- postcss.config.mjs
- prisma.config.ts
- nodemailer.d.ts
- web-push.d.ts
- Exception
- User?
- { GET, POST }

## God Nodes (most connected - your core abstractions)
1. `auth()` - 131 edges
2. `cn()` - 119 edges
3. `prisma` - 102 edges
4. `requireAdmin()` - 92 edges
5. `formatPrice()` - 80 edges
6. `triggerHaptic()` - 57 edges
7. `useUIStore` - 46 edges
8. `revalidateStorefront()` - 40 edges
9. `getLast10Digits()` - 38 edges
10. `Order` - 37 edges

## Surprising Connections (you probably didn't know these)
- `get_public_banners()` --uses--> `Banner`  [INFERRED]
  fastapi-backend/routers/public.py → fastapi-backend/models.py
- `list_categories()` --uses--> `Category`  [INFERRED]
  fastapi-backend/routers/products.py → fastapi-backend/models.py
- `settle_rider_cash()` --uses--> `CashDepositRequest`  [INFERRED]
  fastapi-backend/routers/admin.py → fastapi-backend/schemas.py
- `admin_create_product()` --uses--> `ProductOut`  [INFERRED]
  fastapi-backend/routers/admin_extended.py → fastapi-backend/schemas.py
- `admin_get_products()` --uses--> `ProductOut`  [INFERRED]
  fastapi-backend/routers/admin_extended.py → fastapi-backend/schemas.py

## Import Cycles
- None detected.

## Communities (184 total, 41 thin omitted)

### Community 0 - "package:flutter/material.dart"
Cohesion: 0.02
Nodes (108): BorderRadius?, ../constants/app_colors.dart, core/theme/design_system.dart, AppTheme, AboutScreen, build, _divider, _linkItem (+100 more)

### Community 1 - "admin_extended.py"
Cohesion: 0.05
Nodes (87): Banner, Category, admin_block_user(), admin_bulk_import_products(), admin_bulk_sort_products(), admin_bulk_update(), admin_create_banner(), admin_create_category() (+79 more)

### Community 2 - "requireAdmin"
Cohesion: 0.05
Nodes (54): GET(), PATCH(), POST(), PUT(), DELETE(), GET(), POST(), PUT() (+46 more)

### Community 3 - "auth"
Cohesion: 0.04
Nodes (57): WishlistPage(), AdminPage(), revalidate, AdminRestaurantsPage(), revalidate, DELETE(), GET(), PATCH() (+49 more)

### Community 4 - "utils.ts"
Cohesion: 0.04
Nodes (61): CategoryPage(), CategoryPageProps, revalidate, CheckoutDeliverySelector(), DeliverySelectorProps, CheckoutOrderSummary(), OrderSummaryProps, iconMap (+53 more)

### Community 5 - "cn"
Cohesion: 0.05
Nodes (53): SlideToOrder(), AccountDashboardProps, WishlistClient(), WishlistItem, WishlistProduct, RestaurantManager(), RestaurantManagerProps, OrderConfirmationStatus() (+45 more)

### Community 6 - "category_products_screen.dart"
Cohesion: 0.04
Nodes (58): CategoriesScreen, Category, ../data/models/category.dart, ../data/models/product.dart, ../data/repositories/product_repository.dart, build, _CategoriesScreenState, createState (+50 more)

### Community 7 - "home_screen.dart"
Cohesion: 0.04
Nodes (60): ../cafe/cafe_menu_screen.dart, ../data/repositories/restaurant_repository.dart, accentGreen, accentOrange, accentOrangeDark, bgLight, _buildCategoryToggle, _buildCuratedForYouFilter (+52 more)

### Community 8 - "triggerHaptic"
Cohesion: 0.12
Nodes (44): CartPage(), Error(), CartConflictDialog(), CartDrawer(), BuyAgainItem, BuyAgainSection(), CafeSection(), CafeSectionProps (+36 more)

### Community 9 - "restaurant-orders-console.tsx"
Cohesion: 0.05
Nodes (48): CodPaymentModal(), CodPaymentModalProps, RiderWalletView(), RiderWalletViewProps, DeliveryDashboard(), optimizeRoute(), triggerConfetti(), BIN_CONFIGS (+40 more)

### Community 10 - "prisma.ts"
Cohesion: 0.06
Nodes (32): POST(), GET(), POST(), dynamic, GET(), revalidate, dynamic, GET() (+24 more)

### Community 11 - "design_system.dart"
Cohesion: 0.03
Nodes (57): accent, accentDark, accentGradient, AppDesignSystem, background, border, borderLight, cafeAccent (+49 more)

### Community 12 - "ConsumerState"
Cohesion: 0.04
Nodes (50): ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, AdminLoginScreen, _AdminLoginScreenState, build, createState, _emailController (+42 more)

### Community 13 - "brand_design_system.dart"
Cohesion: 0.04
Nodes (53): accent, accentDark, accentLight, background, border, borderLight, BrandColors, BrandShadows (+45 more)

### Community 14 - "formatPrice"
Cohesion: 0.07
Nodes (35): CheckoutCouponInput(), CouponInputProps, ActiveDeliveryCard(), ActiveDeliveryCardProps, itemVariants, DeliveryHistoryView(), DeliveryHistoryViewProps, itemVariants (+27 more)

### Community 15 - "product_card.dart"
Cohesion: 0.04
Nodes (46): address_book_screen.dart, core/routes/app_router.dart, core/theme/app_theme.dart, build, _buildDetailRow, deliveryAddress, orderId, OrderSuccessScreen (+38 more)

### Community 16 - "checkout_screen.dart"
Cohesion: 0.05
Nodes (48): build, _buildFoodItemCard, CafeMenuScreen, _CafeMenuScreenState, _categories, createState, dispose, restaurantId (+40 more)

### Community 17 - "getLast10Digits"
Cohesion: 0.11
Nodes (29): AccountPage(), revalidate, GET(), POST(), GET(), PATCH(), POST(), POST() (+21 more)

### Community 18 - "storefront-client.tsx"
Cohesion: 0.06
Nodes (35): CUISINES, FoodMarketplace(), FoodMarketplaceProps, SortOption, DeliveryBanner(), EDITORIAL_BANNERS, FoodEditorialCuration(), GOURMET_CATEGORIES (+27 more)

### Community 19 - "schemas.py"
Cohesion: 0.08
Nodes (39): get_product(), list_categories(), list_products(), AsyncSession, get, Search products catalog by query string., Autocomplete search suggestions for products and categories., Get single product by ID or Slug (+31 more)

### Community 20 - "layout.tsx"
Cohesion: 0.08
Nodes (31): jakarta, metadata, RootLayout(), viewport, CartStickyBar(), Footer(), Logo(), LogoProps (+23 more)

### Community 21 - "order.dart"
Cohesion: 0.05
Nodes (43): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, cancelled, card, confirmedAt, couponCode, createdAt (+35 more)

### Community 22 - "product.dart"
Cohesion: 0.05
Nodes (42): availableEndTime, availableStartTime, bannerUrl, barcode, category, categoryId, CategoryInfo, costPrice (+34 more)

### Community 23 - "models.py"
Cohesion: 0.11
Nodes (40): Base, Cart, CartItem, CashDepositTransaction, Coupon, InventoryLog, OrderItem, PayoutRequest (+32 more)

### Community 24 - "jwt.py"
Cohesion: 0.07
Nodes (37): get_current_user(), Any, HTTPAuthorizationCredentials, JWT authentication middleware for FastAPI. Validates NextAuth.js JWT tokens and…, Create a dependency that requires specific role(s). Usage:…, Require access to a specific order (owner or staff). Usage: await…, Extract and validate current user from JWT token. Returns: User dict with {id,…, Require authenticated user. Raises: HTTPException 401 if not authenticated (+29 more)

### Community 25 - "checkout/page.tsx"
Cohesion: 0.09
Nodes (33): CheckoutPage(), SlideToOrderProps, LocationData, MapPicker(), MapPickerProps, Address, buildOrderPayload(), CartItemInput (+25 more)

### Community 26 - "verify_payment"
Cohesion: 0.22
Nodes (8): get_payment_methods(), Any, AsyncSession, get, post, Get supported payment methods., Verify payment signature and update order status. Expected payload: {"orderId":…, verify_payment()

### Community 27 - "routers/auth.py"
Cohesion: 0.10
Nodes (38): check_email(), generate_otp(), get_me(), hash_password(), login(), LoginRequest, MessageResponse, normalize_phone() (+30 more)

### Community 28 - "Order"
Cohesion: 0.06
Nodes (53): DateTime, Order, OrderStatus, OrderType, PaymentMethod, PaymentStatus, Role, get_admin_all_orders() (+45 more)

### Community 29 - "store-config.ts"
Cohesion: 0.06
Nodes (25): AdminBanners(), AdminBannersProps, FESTIVAL_TEMPLATES, GRADIENT_PRESETS, PromoBanner, AdminSettings(), AdminSettingsProps, BannersTab() (+17 more)

### Community 30 - "orders_screen.dart"
Cohesion: 0.06
Nodes (34): ../../core/utils/validators.dart, ../data/models/address.dart, ../../data/models/order.dart, ../../data/repositories/order_repository.dart, build, _buildBillRow, _buildBillSummary, _buildItemsSection (+26 more)

### Community 31 - "constants.ts"
Cohesion: 0.08
Nodes (26): Address, CreateOrderModalProps, CustomerUser, Product, SelectedItem, Category, Product, RestaurantCatalogManager() (+18 more)

### Community 32 - "brand_input.dart"
Cohesion: 0.06
Nodes (30): ../data/models/restaurant.dart, EdgeInsets?, BrandCard, build, child, elevated, margin, onTap (+22 more)

### Community 33 - "compilerOptions"
Cohesion: 0.06
Nodes (32): check_all_products.ts, dom, dom.iterable, esnext, **/*.mts, .next/dev/types/**/*.ts, next-env.d.ts, .next/types/**/*.ts (+24 more)

### Community 34 - "cart_screen.dart"
Cohesion: 0.07
Nodes (29): ../checkout/checkout_screen.dart, Color, _appliedCoupon, _applyCoupon, _buildBillRow, _buildEmptyState, CartScreen, _CartScreenState (+21 more)

### Community 35 - "admin-dashboard.tsx"
Cohesion: 0.08
Nodes (24): AdminDashboardProps, TabType, CategoriesTab(), CategoriesTabProps, CategoryWithCount, DashboardStats, DashboardStatsCards(), DashboardStatsCardsProps (+16 more)

### Community 36 - "table_booking_screen.dart"
Cohesion: 0.07
Nodes (28): email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone, pincode (+20 more)

### Community 37 - "api/products/route.ts"
Cohesion: 0.09
Nodes (18): POST(), GET(), getFuzzyScore(), getLevenshteinDistance(), SYNONYM_DICTIONARY, POST(), DELETE(), POST() (+10 more)

### Community 38 - "api/orders/route.ts"
Cohesion: 0.16
Nodes (21): POST(), GET(), GET(), POST(), validateAddress(), CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, GROCERY_FREE_DELIVERY_THRESHOLD (+13 more)

### Community 39 - "dependencies"
Cohesion: 0.07
Nodes (27): @auth/prisma-adapter, next, next-auth, nodemailer, dependencies, @auth/prisma-adapter, next, next-auth (+19 more)

### Community 40 - "app/page.tsx"
Cohesion: 0.12
Nodes (21): revalidate, getCachedBanners, getCachedBestSellers, getCachedBreakfastDeals, getCachedCategories, getCachedCategorySortRules, getCachedFlashDeals, getCachedLunchDeals (+13 more)

### Community 41 - "otp_screen.dart"
Cohesion: 0.10
Nodes (22): ../../core/constants/app_colors.dart, dioProvider, _sendOtp, build, createState, dispose, _focusNodes, _handleResend (+14 more)

### Community 42 - "cart.dart"
Cohesion: 0.09
Nodes (22): double get, appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items (+14 more)

### Community 43 - "restaurant.dart"
Cohesion: 0.09
Nodes (22): address, bannerUrl, city, cuisineTags, deliveryTime, description, discountBadge, discountOffer (+14 more)

### Community 44 - "admin-csv-import.tsx"
Cohesion: 0.10
Nodes (20): AdminCsvImport(), AdminCsvImportProps, CAFE_TEMPLATE_HEADERS, CAFE_TEMPLATE_ROWS, GROCERY_TEMPLATE_HEADERS, GROCERY_TEMPLATE_ROWS, ImportResult, parseCSV() (+12 more)

### Community 45 - "components.json"
Cohesion: 0.09
Nodes (21): aliases, components, hooks, lib, ui, utils, iconLibrary, menuAccent (+13 more)

### Community 46 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.13
Nodes (18): ../cart/cart_screen.dart, ../categories/categories_screen.dart, ConsumerWidget, dart:ui, _buildHeader, build, _buildBottomNav, MainShell (+10 more)

### Community 47 - "profile.py"
Cohesion: 0.20
Nodes (20): delete_account(), _generate_otp(), profile_setup(), Any, AsyncSession, post, Profile Routes Migrated from Next.js API routes to FastAPI., Update user phone after OTP verification. (+12 more)

### Community 48 - "api_endpoints.dart"
Cohesion: 0.10
Nodes (20): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+12 more)

### Community 49 - "formatDate"
Cohesion: 0.11
Nodes (17): DeliveryHeader(), DeliveryHeaderProps, LiveClock(), ProductPage(), AdminInward(), AdminInwardProps, Product, Category (+9 more)

### Community 50 - "List"
Cohesion: 0.10
Nodes (16): category_products_screen.dart, build, _restaurants, RestaurantsListScreen, build, _categories, CategoriesScreen, build (+8 more)

### Community 51 - "restaurant.py"
Cohesion: 0.17
Nodes (19): cafe_reports(), get_restaurant(), get_restaurants(), AsyncSession, get, Restaurant & Cafe Routes Migrated from Next.js API routes to FastAPI., Stats for restaurant owner dashboard., Restaurant owner view of orders. (+11 more)

### Community 52 - "app_colors.dart"
Cohesion: 0.11
Nodes (18): accent, accentDark, AppColors, background, border, borderLight, card, danger (+10 more)

### Community 53 - "address.dart"
Cohesion: 0.11
Nodes (17): double?, area, city, fromJson, fullAddress, houseNo, id, isDefault (+9 more)

### Community 54 - "product_repository.dart"
Cohesion: 0.12
Nodes (16): _cachedProducts, dio, _filterProducts, getCategories, getProduct, getProducts, _lastFetchTime, ProductRepository (+8 more)

### Community 55 - "user.dart"
Cohesion: 0.12
Nodes (16): bool get, blockReason, createdAt, email, fromJson, id, image, isAdmin (+8 more)

### Community 56 - "addresses.py"
Cohesion: 0.21
Nodes (16): Address, create_address(), delete_address(), generate_id(), get_user_addresses(), get_user_id(), Any, AsyncSession (+8 more)

### Community 57 - "app_router.dart"
Cohesion: 0.12
Nodes (16): AppRouter, generateRoute, ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cart/cart_screen.dart, ../../features/categories/categories_screen.dart, ../../features/categories/category_products_screen.dart, ../../features/checkout/checkout_screen.dart (+8 more)

### Community 58 - "lib/providers/cart_provider.dart"
Cohesion: 0.12
Nodes (15): auth_provider.dart, ../data/models/cart.dart, ../data/repositories/cart_repository.dart, addItem, applyCoupon, cartRepoProvider, clearCart, _createMockCart (+7 more)

### Community 59 - "skeletons.tsx"
Cohesion: 0.22
Nodes (11): AccountSkeleton(), AdminSkeleton(), CafeSkeleton(), CartSkeleton(), CategorySkeleton(), CheckoutSkeleton(), HomepageSkeleton(), OperationalSkeleton() (+3 more)

### Community 60 - "usePushNotification"
Cohesion: 0.20
Nodes (11): FlashDealsBanner(), LockscreenAlertMockup(), LockscreenAlertMockupProps, PushNotificationConsent(), SoftPromptDialog(), usePushNotification(), PushNotificationContext, PushNotificationContextType (+3 more)

### Community 61 - "auth_provider.dart"
Cohesion: 0.14
Nodes (14): AsyncValue, dart:convert, ../data/models/user.dart, auth, AuthNotifier, clear, currentUserProvider, _load (+6 more)

### Community 62 - "../core/network/api_client.dart"
Cohesion: 0.15
Nodes (12): ../core/network/api_client.dart, ../data/repositories/address_repository.dart, Dio, AddressRepository, createAddress, deleteAddress, dio, getAddresses (+4 more)

### Community 63 - "delivery.py"
Cohesion: 0.22
Nodes (13): get_delivery_orders(), get_doorstep_qr(), get_rider_location(), get_rider_wallet(), Any, AsyncSession, get, post (+5 more)

### Community 64 - "database.py"
Cohesion: 0.10
Nodes (18): get_db(), AsyncSession, Database initialization script. Run with: python init_db.py, edit_order(), get_order_items(), get_order_live_status(), get_recent_orders(), Any (+10 more)

### Community 65 - "paytm_callback"
Cohesion: 0.22
Nodes (13): _generate_signature(), paytm_callback(), paytm_initiate(), paytm_mock_success(), Any, AsyncSession, post, Request (+5 more)

### Community 66 - "products_helper.py"
Cohesion: 0.20
Nodes (13): get_buy_again_products(), get_live_stock(), get_upsell_products(), Any, AsyncSession, get, post, Products Helper Routes Migrated from Next.js API routes to FastAPI. (+5 more)

### Community 67 - "public.py"
Cohesion: 0.20
Nodes (13): geocode_address(), get_geocode_key(), get_public_banners(), Any, AsyncSession, get, post, Public Routes (no auth required) Banners, coupons/validate, public settings,… (+5 more)

### Community 68 - "coupon.dart"
Cohesion: 0.14
Nodes (13): categoryId, code, DiscountType, expiresAt, fromJson, id, isActive, maxDiscount (+5 more)

### Community 69 - "add_address_screen.dart"
Cohesion: 0.15
Nodes (13): AddAddressScreen, _AddAddressScreenState, _areaController, build, _buildField, _cityController, createState, _houseController (+5 more)

### Community 70 - "splash/splash_screen.dart"
Cohesion: 0.14
Nodes (13): build, createState, dispose, initState, _logoController, _logoScale, _navigateToNextScreen, _SplashScreenState (+5 more)

### Community 71 - "scripts"
Cohesion: 0.14
Nodes (13): name, prisma, seed, private, scripts, build, dev, flutter (+5 more)

### Community 72 - "admin-restaurant-console.tsx"
Cohesion: 0.18
Nodes (10): AdminRestaurantConsole(), AdminRestaurantConsoleProps, Product, RestaurantConsoleTab(), RestaurantConsoleTabProps, Payout, RestaurantPayoutsLedger(), RestaurantPayoutsLedgerProps (+2 more)

### Community 73 - "devDependencies"
Cohesion: 0.15
Nodes (13): eslint, eslint-config-next, devDependencies, eslint, eslint-config-next, prettier, prettier-plugin-tailwindcss, tsx (+5 more)

### Community 74 - "ConnectionManager"
Cohesion: 0.22
Nodes (8): ConnectionManager, order_tracking_websocket(), General WebSocket connection endpoint for real-time broadcasts, Live real-time order tracking WebSocket for customers & delivery riders, Real-time rider GPS stream for admin live operations tracking, rider_location_websocket(), root_websocket(), WebSocket

### Community 75 - "category.dart"
Cohesion: 0.15
Nodes (12): count, fromJson, id, imageUrl, name, parentId, productCount, products (+4 more)

### Community 76 - "settings.py"
Cohesion: 0.21
Nodes (11): check_nearest_store(), get_public_settings(), Any, AsyncSession, get, patch, Settings & Location Routes Migrated from Next.js API routes to FastAPI., Get public app settings (delivery zones, payment config, etc.). (+3 more)

### Community 77 - "banner.dart"
Cohesion: 0.17
Nodes (11): Banner, fromJson, id, imageUrl, isActive, link, sortOrder, subtitle (+3 more)

### Community 78 - "cart_repository.dart"
Cohesion: 0.17
Nodes (11): addItem, applyCoupon, CartRepository, dio, getCart, getLocalCart, _handleError, removeItem (+3 more)

### Community 79 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 80 - "kot-print.ts"
Cohesion: 0.30
Nodes (10): OrdersTab(), OrdersTabProps, generateInvoiceHtml(), generateKOTHtml(), getHiddenIframe(), printCustomerInvoice(), printKOTReceipt(), printQueue (+2 more)

### Community 81 - "FastApiClient"
Cohesion: 0.24
Nodes (3): fastApi, FastApiClient, FastApiOptions

### Community 82 - "auth/splash_screen.dart"
Cohesion: 0.18
Nodes (10): Animation, AnimationController, ../auth/otp_screen.dart, build, _controller, createState, dispose, _fadeAnimation (+2 more)

### Community 83 - "@JsonSerializable"
Cohesion: 0.18
Nodes (11): @JsonSerializable, Address, Cart, CartItem, Category, CategoryCount, Coupon, Order (+3 more)

### Community 84 - "State"
Cohesion: 0.24
Nodes (11): SplashScreen, _SplashScreenState, SubscriptionsScreen, _SubscriptionsScreenState, RestaurantCard, _RestaurantCardState, ShimmerBox, _ShimmerBoxState (+3 more)

### Community 85 - "web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 86 - "PaytmChecksum"
Cohesion: 0.31
Nodes (3): POST(), POST(), PaytmChecksum

### Community 87 - "admin-bulk-update.tsx"
Cohesion: 0.22
Nodes (9): AdminBulkUpdate(), AdminBulkUpdateProps, BatchHistory, Category, ChangePreview, Product, BulkUpdateTab(), BulkUpdateTabProps (+1 more)

### Community 88 - "deals-curation-hub.tsx"
Cohesion: 0.33
Nodes (10): DealsCurationHub(), DealsCurationHubProps, PremiumBreakfastIcon(), PremiumEssentialsIcon(), PremiumLateNightIcon(), PremiumLightningDealsIcon(), PremiumLunchIcon(), PremiumSnacksIcon() (+2 more)

### Community 89 - "location-picker.tsx"
Cohesion: 0.25
Nodes (9): LocationPicker, FreeMapPicker(), FreeMapPickerProps, loadLeaflet(), LocationData, getDistance(), loadGoogleMapsScript(), LocationPicker() (+1 more)

### Community 90 - "main.py"
Cohesion: 0.24
Nodes (9): exception_handler, add_process_time_header(), global_exception_handler(), health_check(), Exception, get, Request, root() (+1 more)

### Community 91 - "auth_repository.dart"
Cohesion: 0.20
Nodes (9): AuthRepository, dio, getProfile, _handleError, login, sendOtp, signup, verifyOtp (+1 more)

### Community 92 - "public/manifest.json"
Cohesion: 0.20
Nodes (9): background_color, description, display, icons, name, orientation, short_name, start_url (+1 more)

### Community 93 - "login_screen.dart"
Cohesion: 0.25
Nodes (8): ../../data/repositories/auth_repository.dart, build, createState, _isLoading, LoginScreen, _LoginScreenState, _phoneController, otp_screen.dart

### Community 94 - "api_client.dart"
Cohesion: 0.22
Nodes (8): ApiException, dio, message, statusCode, toString, int?, package:shared_preferences/shared_preferences.dart, return

### Community 95 - "order_repository.dart"
Cohesion: 0.22
Nodes (8): cancelOrder, dio, getOrder, getOrders, _handleError, OrderRepository, placeOrder, ../models/order.dart

### Community 96 - "restaurants/[id]/page.tsx"
Cohesion: 0.28
Nodes (4): EditRestaurantPage(), NewRestaurantPage(), RestaurantForm(), RestaurantFormProps

### Community 97 - "api/settings/route.ts"
Cohesion: 0.36
Nodes (7): checkIsStoreOpen(), DEFAULT_SETTINGS, dynamic, GET(), getCachedSettings(), setCachedSettings(), settingsCache

### Community 98 - "admin-analytics.tsx"
Cohesion: 0.25
Nodes (7): AdminAnalytics(), AdminAnalyticsProps, Category, Order, Product, AnalyticsTab(), AnalyticsTabProps

### Community 99 - "admin-reports.tsx"
Cohesion: 0.25
Nodes (7): AdminReports(), CategorySale, DailySale, ReportSummary, TopProduct, ReportsTab(), ReportsTabProps

### Community 100 - "formatDisplayEmail"
Cohesion: 0.25
Nodes (7): BlockCustomerModal(), BlockCustomerModalProps, Category, CategoryEditModal(), CategoryEditModalProps, formatDisplayEmail(), isDummyEmail()

### Community 101 - "admin_coupon_detail.dart"
Cohesion: 0.29
Nodes (7): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive

### Community 102 - "add_review_screen.dart"
Cohesion: 0.29
Nodes (7): AddReviewScreen, _AddReviewScreenState, build, createState, productName, _rating, _reviewController

### Community 103 - "admin-alerts.tsx"
Cohesion: 0.29
Nodes (6): AdminAlerts(), AdminAlertsProps, AlertItem, Counts, AlertsTab(), AlertsTabProps

### Community 104 - "admin-inventory-center.tsx"
Cohesion: 0.29
Nodes (6): AdminInventoryCenter(), CartItem, Product, StockHistoryLog, InwardTab(), InwardTabProps

### Community 105 - "admin-rider-cash.tsx"
Cohesion: 0.29
Nodes (6): AdminRiderCash(), DepositLog, RiderCashInfo, SummaryInfo, RiderCashTab(), RiderCashTabProps

### Community 106 - "live-carts-panel.tsx"
Cohesion: 0.29
Nodes (6): LiveCart, LiveCartItem, LiveCartsPanel(), LiveCartsPanelProps, LiveOpsTab(), LiveOpsTabProps

### Community 107 - "functions"
Cohesion: 0.25
Nodes (7): functions, src/app/**/*, src/app/api/**/*, maxDuration, memory, maxDuration, memory

### Community 108 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): build, _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile

### Community 109 - "admin-forecast.tsx"
Cohesion: 0.33
Nodes (5): AdminForecast(), AdminForecastProps, ForecastItem, ForecastTab(), ForecastTabProps

### Community 110 - "flash-deals-tab.tsx"
Cohesion: 0.33
Nodes (5): AdminPromotions(), HighlightType, Product, FlashDealsTab(), FlashDealsTabProps

### Community 111 - "order-tracking-modal.tsx"
Cohesion: 0.29
Nodes (6): Address, AssignedUser, Order, OrderItem, OrderTrackingModal(), OrderTrackingModalProps

### Community 112 - "seed.ts"
Cohesion: 0.33
Nodes (4): adapter, pool, prisma, NOTE: We do NOT delete any products, categories, or orders.

### Community 113 - "send-email-otp/route.ts"
Cohesion: 0.47
Nodes (3): POST(), resendApiKey, sendOtpEmail()

### Community 114 - "track/page.tsx"
Cohesion: 0.33
Nodes (3): dynamic, OrderTrackingPageProps, TrackingPageClient()

### Community 115 - "push-notifications-tab.tsx"
Cohesion: 0.40
Nodes (4): AdminPushNotifications(), PushNotificationHistory, PushNotificationsTab(), PushNotificationsTabProps

### Community 116 - "admin-restaurant-report.tsx"
Cohesion: 0.40
Nodes (4): AdminRestaurantReport(), RestaurantSalesData, RestaurantReportTab(), RestaurantReportTabProps

### Community 117 - "admin-sort-manager.tsx"
Cohesion: 0.47
Nodes (5): AdminSortManager(), loadCategoryData(), AdminSortManagerProps, getSortedProducts(), ProductItem

### Community 118 - "hub-nav.tsx"
Cohesion: 0.33
Nodes (5): DashboardHubNav(), DashboardHubNavProps, HUB_ICONS, HubNavItem, HubNavTab

### Community 119 - "next-auth.d.ts"
Cohesion: 0.33
Nodes (5): JWT, next-auth, next-auth/jwt, Session, User

### Community 120 - "config.py"
Cohesion: 0.40
Nodes (4): BaseSettings, dotenv, Settings, dotenv

### Community 121 - "master-lookup/route.ts"
Cohesion: 0.50
Nodes (3): GET(), MASTER_CATALOG, MasterProduct

### Community 122 - "hero-banner.tsx"
Cohesion: 0.40
Nodes (3): BannerItem, DEFAULT_BANNERS, HeroBanner()

### Community 123 - "test_api.py"
Cohesion: 0.67
Nodes (3): asyncio, test_health_endpoint(), test_root_endpoint()

### Community 124 - "widget_test.dart"
Cohesion: 0.50
Nodes (3): main, package:fastkirana_flutter/main.dart, package:flutter_test/flutter_test.dart

## Knowledge Gaps
- **1225 isolated node(s):** `PushPayload`, `BlockCustomerModalProps`, `Category`, `CategoryEditModalProps`, `AdminAlertsProps` (+1220 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **41 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dependencies` connect `dependencies` to `@base-ui/react`, `bcryptjs`, `class-variance-authority`, `clsx`, `date-fns`, `framer-motion`, `lru-cache`, `lucide-react`, `pg`, `prisma`, `@prisma/adapter-pg`, `react`, `react-dom`, `shadcn`, `sonner`, `tailwind-merge`, `@types/node`, `@types/nodemailer`, `@types/papaparse`, `@types/pg`, `@types/react`, `zustand`, `scripts`, `config.py`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `dotenv` connect `config.py` to `dependencies`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **What connects `PushPayload`, `BlockCustomerModalProps`, `Category` to the rest of the system?**
  _1225 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `package:flutter/material.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02429360859138776 - nodes in this community are weakly interconnected._
- **Should `admin_extended.py` be split into smaller, more focused modules?**
  _Cohesion score 0.054336468129571575 - nodes in this community are weakly interconnected._
- **Should `requireAdmin` be split into smaller, more focused modules?**
  _Cohesion score 0.05459770114942529 - nodes in this community are weakly interconnected._
- **Should `auth` be split into smaller, more focused modules?**
  _Cohesion score 0.0426812585499316 - nodes in this community are weakly interconnected._