# Graph Report - fastkirana_flutter  (2026-09-18)

## Corpus Check
- 251 files · ~728,401 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4327 nodes · 6886 edges · 189 communities (183 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f4bcd772`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- design_system.dart
- restaurant_dashboard.dart
- checkout_screen.dart
- home_screen.dart
- restaurant_provider.dart
- order.dart
- product.dart
- orders_screen.dart
- kitchen_order.dart
- secure_storage_service.dart
- product_card.dart
- add_item_search_sheet.dart
- notification_service.dart
- cafe_menu_screen.dart
- cart_screen.dart
- cart.dart
- restaurant.dart
- product_provider.dart
- cartProvider
- subscription_screen.dart
- user.dart
- app_router.dart
- main_shell.dart
- otp_screen.dart
- address_provider.dart
- ../core/routes/page_transitions.dart
- dynamic_hero_banner_carousel.dart
- checkout_delivery_instructions.dart
- brand_button.dart
- package:flutter/material.dart
- category_products_screen.dart
- profile_screen.dart
- StatelessWidget
- admin_orders_list.dart
- coupons_screen.dart
- add_address_screen.dart
- search_screen.dart
- product_detail_screen.dart
- cart_repository.dart
- category.dart
- coupon.dart
- login_screen.dart
- delivery_order.dart
- State
- splash/splash_screen.dart
- wishlist_screen.dart
- admin_authorization.dart
- restaurant_card.dart
- banner.dart
- order_success_screen.dart
- admin_products.dart
- manifest.json
- product_repository.dart
- auth_repository.dart
- ../data/models/product.dart
- order_repository.dart
- restaurant_repository.dart
- ../../core/services/logger_service.dart
- delivery_dashboard.dart
- FadeSlideRoute
- static const Color
- authProvider
- restaurant_login.dart
- rider_active_delivery_card.dart
- picker_order.dart
- delivery_mode_header.dart
- order_edit_modal.dart
- admin_dashboard.dart
- api_endpoints.dart
- rider_cart_modal.dart
- admin_login.dart
- checkout_bill_breakdown.dart
- contextual_brand_transition_screen.dart
- payment_failed_cod_sheet.dart
- package:shared_preferences/shared_preferences.dart
- order_tracking_screen.dart
- tracking_status_stepper.dart
- categoriesProvider
- responsive.dart
- store_settings.dart
- map_picker_screen.dart
- picker_dashboard.dart
- location_service.dart
- RecognitionListener
- restaurant_utils.dart
- FastKirana Flutter
- add_picker_product_modal.dart
- add_restaurant_product_modal.dart
- @fastkirana
- FastKirana Production Deployment Guide
- doorstep_details_screen.dart
- rider_location_service.dart
- cart_provider.dart
- app_config.dart
- dioProvider
- address.dart
- lib/widgets/empty_state.dart
- tracking_payment_card.dart
- delivery_header.dart
- coupon_provider.dart
- auth_provider.dart
- delivery_location_screen.dart
- variant_selector_sheet.dart
- delivery_theme.dart
- live_gps_route_card.dart
- restaurant_delivery_loading_screen.dart
- restaurant_sales_report_tab.dart
- grocery_delivery_loading_screen.dart
- brand_input.dart
- privacy_policy_screen.dart
- page_transitions.dart
- order_detail_screen.dart
- live_clock_badge.dart
- voice_search_sheet.dart
- ../core/theme/responsive.dart
- notifications_screen.dart
- app_connectivity.dart
- validators.dart
- kot_print_service.dart
- deep_link_service.dart
- ConsumerState
- tracking_map_view.dart
- package:dio/dio.dart
- address_selector_sheet.dart
- app_toast.dart
- banner_repository.dart
- retry_wrapper.dart
- location_drift_sheet.dart
- logger_service.dart
- restaurant_menu_catalog_tab.dart
- _CafeMenuScreenState
- admin_order_card.dart
- String?
- rider_pickup_card.dart
- package:fastkirana_flutter/core/services/logger_service.dart
- store_hub_provider.dart
- order_alarm_service.dart
- store_hub.dart
- offline_banner.dart
- package:flutter_riverpod/flutter_riverpod.dart
- restaurants_list_screen.dart
- unserviceable_location_banner.dart
- battery_optimization_service.dart
- _DeliveryDashboardState
- dart:async
- _CategoryChipsDelegate
- StatefulWidget
- grid_skeletons.dart
- @gmail
- app_flavor.dart
- supabase_service.dart
- map_marker_generator.dart
- VoidCallback?
- order_recipient_helper.dart
- dart:math
- main.dart
- delivery/delivery_login.dart
- cart_bill_summary_card.dart
- storeSettingsProvider
- auth/delivery_login.dart
- ../core/utils/restaurant_utils.dart
- restaurant_metrics_bar.dart
- Color
- restaurant_order_card_view.dart
- sponsored_ad_card.dart
- Map
- ../data/models/order.dart
- package:cached_network_image/cached_network_image.dart
- location_service_test.dart
- AsyncValue
- app_errors.dart
- package:flutter/services.dart
- _DeliveryPaymentSheet
- Order
- floating_order_tracking_bar.dart
- dart:convert
- admin_stat_card.dart
- package:flutter_bounceable/flutter_bounceable.dart
- core/widgets/empty_state.dart
- List
- about_screen.dart
- admin_reports.dart
- admin_settings.dart
- _DoorstepCashfreeQrSheetState
- _OrderTrackingScreenState

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 91 edges
2. `cartProvider` - 42 edges
3. `authProvider` - 35 edges
4. `FadeSlideRoute` - 34 edges
5. `selectedAddressProvider` - 33 edges
6. `categoriesProvider` - 29 edges
7. `storeSettingsProvider` - 28 edges
8. `addressesProvider` - 21 edges
9. `homeProductCatalogProvider` - 15 edges
10. `RecognitionListener` - 13 edges

## Surprising Connections (you probably didn't know these)
- `_updateMart` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_updateMaster` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_updateRestaurant` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_buildProductAdminCard` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_products.dart → lib/core/network/api_client.dart
- `_saveProduct` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_products.dart → lib/core/network/api_client.dart

## Import Cycles
- None detected.

## Communities (189 total, 6 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (202): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+194 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.03
Nodes (73): ../../core/network/network_retry_helper.dart, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, bgMain, brandAmber, brandGreen (+65 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.04
Nodes (54): CFPaymentGatewayService, ../checkout/order_success_screen.dart, _buildBottomProceedBar, _buildCartItemsReview, _buildPlacingOrderOverlay, _buildReviewItemRow, _cfService, _completeOrderPlacement (+46 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.04
Nodes (48): _buildActiveDeliveryTracker, _buildCategoryAvatarImage, _buildCategoryFallback, _buildCategoryToggle, _buildFoodGreetingBanner, _buildFooter, _buildHorizontalProductSection, _buildInfiniteFeedFooter (+40 more)

### Community 4 - "restaurant_provider.dart"
Cohesion: 0.09
Nodes (28): ../data/repositories/restaurant_repository.dart, build, _RestaurantsListScreenState, address, cuisine, distanceMeters, filteredRestaurantsProvider, getDarkstoreAddonRecommendations (+20 more)

### Community 5 - "order.dart"
Cohesion: 0.03
Nodes (59): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, addressRaw, cancelled, card, combinedId, confirmedAt (+51 more)

### Community 6 - "product.dart"
Cohesion: 0.02
Nodes (90): category.dart, aCreated, AddonGroup, AddonItem, addons, address, aName, aSort (+82 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.11
Nodes (19): _buildEmptyState, _buildSearchBox, _buildSegmentedTabs, _buildStatusFilterPills, createState, dispose, OrderCardSkeleton, OrdersScreen (+11 more)

### Community 8 - "kitchen_order.dart"
Cohesion: 0.05
Nodes (37): cookingInstruction, createdAt, customerAddress, customerName, customerPhone, deliveryMethod, elapsedMinutes, fromJson (+29 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.07
Nodes (27): _cachedRefreshToken, _cachedToken, _cachedUserData, _cachedUserEmail, _cachedUserId, _cachedUserName, _cachedUserPhone, _cachedUserRole (+19 more)

### Community 10 - "product_card.dart"
Cohesion: 0.04
Nodes (57): ../features/products/product_detail_screen.dart, Gradient, _addButton, bestseller, bogo, bogoBadgeText, child, createState (+49 more)

### Community 11 - "add_item_search_sheet.dart"
Cohesion: 0.09
Nodes (23): ../../../core/utils/app_toast.dart, AddItemSearchSheet, _AddItemSearchSheetState, _adminCatalogFilter, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, createState (+15 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.05
Nodes (38): AndroidFlutterLocalNotificationsPlugin, @pragma, dart:typed_data, _bgRecentMessageTimes, body, clearAllNotifications, data, firebaseMessagingBackgroundHandler (+30 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.03
Nodes (60): GlobalKey, _activeCategoryTag, _buildCategories, _buildCategoryThumbnail, _buildFallbackBanner, _buildFallbackLogo, _buildFallbackOfferTicket, _buildLocalAssetOrEmoji (+52 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.04
Nodes (45): ../checkout/checkout_screen.dart, coupons_screen.dart, _appliedCoupon, _applyCoupon, _bogoBadgeText, brandGreen, _buildBillDetailsCard, _buildBillRow (+37 more)

### Community 15 - "cart.dart"
Cohesion: 0.08
Nodes (23): double get, appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items (+15 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.07
Nodes (27): activeOrdersCount, address, bannerUrl, city, commissionRate, cuisineTags, deliveryTime, description (+19 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (19): ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds, filteredUpsells (+11 more)

### Community 18 - "cartProvider"
Cohesion: 0.12
Nodes (18): build, _buildCartErrorState, _buildCartItemCard, _buildCartScreenContent, CartScreen, _CartScreenState, _buildCompleteYourMealSection, _handleCashfreeError (+10 more)

### Community 19 - "subscription_screen.dart"
Cohesion: 0.15
Nodes (13): _availableCatalog, brandGreen, build, createState, primaryRed, _showNewSubscriptionModal, _skipTomorrow, slateDark (+5 more)

### Community 20 - "user.dart"
Cohesion: 0.08
Nodes (26): assignedRestaurantId, blockReason, createdAt, email, hashCode, id, image, isBlocked (+18 more)

### Community 21 - "app_router.dart"
Cohesion: 0.10
Nodes (20): ../../features/auth/admin_login.dart, ../../features/auth/delivery_login.dart, ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cafe/restaurant_dashboard.dart, ../../features/categories/categories_screen.dart, ../../features/checkout/checkout_screen.dart, ../../features/delivery/delivery_dashboard.dart (+12 more)

### Community 22 - "main_shell.dart"
Cohesion: 0.12
Nodes (16): ../categories/categories_screen.dart, ../delivery/picker_dashboard.dart, home_screen.dart, _autoShowTimer, createState, didChangeAppLifecycleState, dispose, initState (+8 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.07
Nodes (26): build, _checkClipboard, _clipboardOtp, _controllers, createState, _currentOtp, didChangeAppLifecycleState, dispose (+18 more)

### Community 24 - "address_provider.dart"
Cohesion: 0.10
Nodes (20): ../data/models/address.dart, ../data/repositories/address_repository.dart, AddressRepository, AddressesScreen, build, _buildAddressCard, _iconForLabel, addAddress (+12 more)

### Community 25 - "../core/routes/page_transitions.dart"
Cohesion: 0.10
Nodes (21): ../../categories/category_products_screen.dart, CategoriesScreen, category_products_screen.dart, ../core/routes/page_transitions.dart, ../data/models/category.dart, build, _categories, CategoriesScreen (+13 more)

### Community 26 - "dynamic_hero_banner_carousel.dart"
Cohesion: 0.09
Nodes (24): ../features/categories/category_products_screen.dart, build, bannersProvider, _advanceToNext, _autoSlideTimer, build, _buildBannerCard, _buildShimmerPlaceholder (+16 more)

### Community 27 - "checkout_delivery_instructions.dart"
Cohesion: 0.15
Nodes (12): build, CheckoutDeliveryInstructions, DeliveryInstructionPreset, icon, id, noteController, onToggleInstruction, presets (+4 more)

### Community 28 - "brand_button.dart"
Cohesion: 0.06
Nodes (32): BorderRadius?, BoxShape, double?, backgroundColor, borderRadius, BrandButton, build, fontSize (+24 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (54): ../core/theme/design_system.dart, AdminBannersScreen, build, AdminCustomersScreen, build, build, _miniCard, RestaurantAnalyticsScreen (+46 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.08
Nodes (23): FocusNode, _buildFilterPill, category, createState, dispose, emoji, id, imageUrl (+15 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.13
Nodes (14): address_book_screen.dart, ../auth/login_screen.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader, primaryRed (+6 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.07
Nodes (33): AppShimmer, build, child, count, OrderCardShimmer, ProductCardShimmer, ProductGridShimmer, build (+25 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.03
Nodes (67): ../common/widgets/battery_optimization_dialog.dart, ../../core/services/kot_print_service.dart, ../../core/services/offline_sync_service.dart, ../../core/services/order_alarm_service.dart, ../delivery/widgets/connectivity_banner.dart, AdminOrdersScreen, _AdminOrdersScreenState, _allOrders (+59 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.11
Nodes (18): _applyCode, _buildCouponCard, _buildLoadingShimmer, _buildManualInputCard, _buildZeroCouponState, CouponsScreen, _CouponsScreenState, createState (+10 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (40): AddAddressScreen, _AddAddressScreenState, _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField (+32 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.06
Nodes (37): empty_state.dart, widgets, _buildFoodRestaurantListing, build, _buildSearchResults, _buildShimmerGrid, _clearRecentSearches, _controller (+29 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.11
Nodes (18): ../cart/cart_screen.dart, ../core/utils/dish_timing.dart, ProductVariant, _addToCart, _buildCustomizedProduct, _buildQualityRow, createState, initState (+10 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.08
Nodes (27): @freezed, Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl (+19 more)

### Community 40 - "coupon.dart"
Cohesion: 0.11
Nodes (18): autoApply, badgeText, bogoType, categoryId, code, Coupon, DiscountType, expiresAt (+10 more)

### Community 41 - "login_screen.dart"
Cohesion: 0.11
Nodes (18): ../../data/repositories/auth_repository.dart, build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleSkipGuest (+10 more)

### Community 42 - "delivery_order.dart"
Cohesion: 0.05
Nodes (40): address, city, combinedId, createdAt, customerName, customerPhone, deliveryFee, DeliveryOrder (+32 more)

### Community 43 - "State"
Cohesion: 0.12
Nodes (17): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+9 more)

### Community 44 - "splash/splash_screen.dart"
Cohesion: 0.12
Nodes (16): ../data/models/store_hub.dart, build, _contentFade, createState, dispose, _hasNavigated, initState, _logoScale (+8 more)

### Community 45 - "wishlist_screen.dart"
Cohesion: 0.08
Nodes (25): ConsumerWidget, AdminOrderCard, HomeHeroBanner, WalletScreen, build, primaryRed, _shareApp, _shareWishlist (+17 more)

### Community 46 - "admin_authorization.dart"
Cohesion: 0.15
Nodes (12): AdminAuthorization, buildStaffHeaders, currentStaffHeaders, isAdmin, isStaff, options, optionsAsync, staffRoles (+4 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.14
Nodes (14): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, _bundledCategoryAssets (+6 more)

### Community 48 - "banner.dart"
Cohesion: 0.12
Nodes (16): Banner, code, description, fromJson, gradient, id, imageUrl, isActive (+8 more)

### Community 49 - "order_success_screen.dart"
Cohesion: 0.06
Nodes (36): ConfettiController, _animController, _buildDetailRow, _buildProgressLine, _buildProgressStep, _buttonsFadeAnim, _buttonsSlideAnim, _checkScaleAnim (+28 more)

### Community 50 - "admin_products.dart"
Cohesion: 0.04
Nodes (46): _addVariant, _buildCategoryChip, _buildGroceryCategoryChips, _buildMiniInput, _buildProductAdminCard, _buildRestaurantOutletChips, _buildSectionTitle, _buildSegmentButton (+38 more)

### Community 51 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "product_repository.dart"
Cohesion: 0.06
Nodes (32): _cachedCategories, _cachedProducts, _cacheKey, _cacheTTLMinutes, dio, _diskCategoriesKey, _diskCategoryTimestampKey, _diskFetchTimestampKey (+24 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.11
Nodes (17): AuthRepository, dio, getProfile, _handleError, login, _parseSessionResponse, sendEmailOtp, sendOtp (+9 more)

### Community 54 - "../data/models/product.dart"
Cohesion: 0.16
Nodes (11): ../../core/widgets/loading_widgets.dart, ../data/models/product.dart, ../data/repositories/product_repository.dart, build, ComboBuilderScreen, productsProvider, ProductsScreen, build (+3 more)

### Community 55 - "order_repository.dart"
Cohesion: 0.12
Nodes (16): ../../core/services/admin_authorization.dart, _cacheKey, cancelOrder, clearCache, dio, _getCacheKey, getOrder, getOrders (+8 more)

### Community 56 - "restaurant_repository.dart"
Cohesion: 0.11
Nodes (17): _cachedMenus, _cachedRestaurants, _dio, _fetchRestaurants, getDarkstoreAddonRecommendations, getRestaurantMenu, getRestaurantReviews, getRestaurants (+9 more)

### Community 57 - "../../core/services/logger_service.dart"
Cohesion: 0.13
Nodes (14): ../../core/services/logger_service.dart, clearCache, createAddress, defaultAddressWithPhone, defaultGhatampurAddress, deleteAddress, dio, getAddresses (+6 more)

### Community 58 - "delivery_dashboard.dart"
Cohesion: 0.02
Nodes (95): ../../core/services/rider_location_service.dart, _activeTab, _assignedStoreId, _assignedStoreName, _audioPlayer, _autoRefreshTimer, bgMain, borderCol (+87 more)

### Community 59 - "FadeSlideRoute"
Cohesion: 0.10
Nodes (23): FadeSlideRoute, _handleContinue, _buildMenuTab, _buildReviewsTab, build, build, _buildBuyAgainShelf, _buildCircularCategoryCarousel (+15 more)

### Community 60 - "static const Color"
Cohesion: 0.11
Nodes (28): bootstrapUserLocation, checkLocationDriftAndPrompt, LocationService, build, CheckoutScreen, _CheckoutScreenState, _handlePlaceOrder, _buildTopHeader (+20 more)

### Community 61 - "authProvider"
Cohesion: 0.12
Nodes (17): _handleLogout, _handleVerifyOtp, build, _initOutletDetails, _resolveOutletDetailsSync, _showKOTPrintModal, build, _showLogoutDialog (+9 more)

### Community 62 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "rider_active_delivery_card.dart"
Cohesion: 0.15
Nodes (12): brandGreen, build, emeraldGreen, EmptyOutForDeliveryCard, isUpdating, order, primaryRed, RiderActiveDeliveryCard (+4 more)

### Community 64 - "picker_order.dart"
Cohesion: 0.08
Nodes (24): createdAt, customerAddress, customerName, customerPhone, elapsedMinutes, fromJson, id, imageUrl (+16 more)

### Community 65 - "delivery_mode_header.dart"
Cohesion: 0.08
Nodes (23): , activeLocationSubtitle, activeLocationTitle, build, _buildSegmentedModeToggle, cafeSvg, currentSearchPlaceholder, d (+15 more)

### Community 66 - "order_edit_modal.dart"
Cohesion: 0.07
Nodes (27): ../../core/services/admin_notification_service.dart, brandAmber, brandGreen, _calculateSubtotal, createState, initState, isAdmin, isRestaurant (+19 more)

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.09
Nodes (22): admin_orders_list.dart, admin_products.dart, AdminDashboard, _AdminDashboardState, _buildDockItem, _buildOutletTile, createState, _currentIndex (+14 more)

### Community 68 - "api_endpoints.dart"
Cohesion: 0.10
Nodes (20): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+12 more)

### Community 69 - "rider_cart_modal.dart"
Cohesion: 0.13
Nodes (14): ../../../core/utils/validators.dart, badgeId, build, _buildStoreGroupCard, isRestaurant, items, onViewCart, order (+6 more)

### Community 70 - "admin_login.dart"
Cohesion: 0.14
Nodes (14): ../admin/admin_dashboard.dart, ../data/models/user.dart, AdminLoginScreen, _AdminLoginScreenState, build, createState, dispose, _emailController (+6 more)

### Community 71 - "checkout_bill_breakdown.dart"
Cohesion: 0.17
Nodes (11): DeliveryTierInfo, build, _buildRow, CheckoutBillBreakdown, deliveryFee, discountAmount, grandTotal, packagingFee (+3 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.06
Nodes (40): CustomPainter, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter, _CafeFrontPainter (+32 more)

### Community 73 - "payment_failed_cod_sheet.dart"
Cohesion: 0.10
Nodes (20): build, createState, dispose, grandTotal, _handleCancel, _handleConfirmCod, _handleRetryPayment, initState (+12 more)

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.08
Nodes (25): package:fastkirana_flutter/core/services/biometric_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/data/models/order.dart, package:fastkirana_flutter/data/models/restaurant.dart, package:fastkirana_flutter/data/models/user.dart, package:fastkirana_flutter/features/delivery/widgets/connectivity_banner.dart, package:fastkirana_flutter/features/orders/widgets/tracking_payment_card.dart (+17 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.02
Nodes (94): BitmapDescriptor?, GoogleMapController?, _audioPlayer, brandGreen, _calculateBearing, _calculateETA, _cfService, _checkAndRequestLocationPermission (+86 more)

### Community 76 - "tracking_status_stepper.dart"
Cohesion: 0.09
Nodes (22): activeColor, AnimatedStepNode, _AnimatedStepNodeState, build, cleanDisplayId, completedColor, createState, didUpdateWidget (+14 more)

### Community 77 - "categoriesProvider"
Cohesion: 0.10
Nodes (30): build, AdminProductsScreen, _AdminProductsScreenState, build, build, build, CategoryProductsScreen, _CategoryProductsScreenState (+22 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (38): BuildContext, EdgeInsetsGeometry, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+30 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.04
Nodes (48): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+40 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.05
Nodes (42): ../../core/services/map_tile_cache_service.dart, doorstep_details_screen.dart, _areaName, _AreaSearchModal, _AreaSearchModalState, build, _calculateDistance, createState (+34 more)

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.06
Nodes (32): ../common/order_edit_modal.dart, _autoRefreshTimer, bgMain, brandGreen, brandOrange, build, _buildEmptyState, _buildMetricStrip (+24 more)

### Community 82 - "location_service.dart"
Cohesion: 0.06
Nodes (35): area, baseFee, cart, city, deliveryFee, distanceKm, feeDescription, fetchCurrentLocationDetails (+27 more)

### Community 83 - "RecognitionListener"
Cohesion: 0.14
Nodes (9): MainActivity, RecognitionListener, Bundle, ByteArray, FlutterActivity, FlutterEngine, Intent, MethodChannel (+1 more)

### Community 84 - "restaurant_utils.dart"
Cohesion: 0.06
Nodes (33): address, _byKey, categorySlug, darkstoreLocation, _ensureInitialized, false, find, findByPhone (+25 more)

### Community 85 - "FastKirana Flutter"
Cohesion: 0.15
Nodes (12): Architecture, Backend, Development, FastKirana Flutter, Getting Started, License, Prerequisites, Project Context (+4 more)

### Community 86 - "add_picker_product_modal.dart"
Cohesion: 0.07
Nodes (29): class, AddPickerProductModal, _AddPickerProductModalState, _barcodeController, brandGreen, brandOrange, _commonUnits, createState (+21 more)

### Community 89 - "add_restaurant_product_modal.dart"
Cohesion: 0.06
Nodes (32): FormState, AddRestaurantProductModal, _AddRestaurantProductModalState, _buildFoodTypeOption, createState, _descriptionController, dispose, _fetchRestaurantSections (+24 more)

### Community 91 - "FastKirana Production Deployment Guide"
Cohesion: 0.07
Nodes (26): 1. Generate Release Keystore, 2. Configure Signing, 3. Verify Firebase Project, Build Commands, `Build failed: signing config not found`, Build-Time Variables, Common Issues, `Crashlytics couldn't find project` (+18 more)

### Community 92 - "doorstep_details_screen.dart"
Cohesion: 0.08
Nodes (25): areaName, _buildCategoryPill, _buildInputField, _buildInstructionChip, createState, _customLabelController, dispose, DoorstepDetailsScreen (+17 more)

### Community 93 - "rider_location_service.dart"
Cohesion: 0.08
Nodes (24): _activeChannels, _activeOrderId, _activeReadableId, _activeRelatedOrderIds, _dio, _getChannelKeys, _handleNewPosition, _instance (+16 more)

### Community 94 - "cart_provider.dart"
Cohesion: 0.08
Nodes (25): Cart? get, ../data/repositories/cart_repository.dart, addItem, addProduct, _buildCart, _cart, cartRepoProvider, checkRestaurantConflict (+17 more)

### Community 95 - "app_config.dart"
Cohesion: 0.07
Nodes (28): apiBaseUrl, AppConfig, appIconAsset, appName, appVersion, buildFlavor, buildNumber, cashfreeAppId (+20 more)

### Community 96 - "dioProvider"
Cohesion: 0.06
Nodes (36): dioProvider, _assignRider, _convertToCOD, _fetchAdminOrders, _fetchAdminProfile, _fetchDeliveryRiders, _flushOfflineAdminQueue, _initNotificationSubscriptions (+28 more)

### Community 97 - "address.dart"
Cohesion: 0.09
Nodes (21): area, city, hashCode, houseNo, id, isDefault, label, latitude (+13 more)

### Community 98 - "lib/widgets/empty_state.dart"
Cohesion: 0.09
Nodes (21): bgTint, build, ctaColor, ctaLabel, emoji, emptyCart, EmptyState, icon (+13 more)

### Community 99 - "tracking_payment_card.dart"
Cohesion: 0.25
Nodes (7): build, isProcessingPayment, onPayOnline, onSwitchToCOD, order, statusStep, TrackingPaymentCard

### Community 100 - "delivery_header.dart"
Cohesion: 0.10
Nodes (19): activeTab, build, DeliveryHeader, _greeting, _greetingText, isDarkMode, isOnline, onBack (+11 more)

### Community 101 - "coupon_provider.dart"
Cohesion: 0.16
Nodes (13): ../data/models/coupon.dart, ../data/repositories/coupon_repository.dart, CouponRepository, AdminCouponsScreen, build, _buildRestaurantOffersStrip, build, couponRepositoryProvider (+5 more)

### Community 102 - "auth_provider.dart"
Cohesion: 0.14
Nodes (13): address_provider.dart, cart_provider.dart, ../core/services/secure_storage_service.dart, auth, clear, _load, logout, maybeWhen (+5 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (19): ../home/main_shell.dart, autoFetchLocation, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose, _getAddressIcon (+11 more)

### Community 104 - "variant_selector_sheet.dart"
Cohesion: 0.10
Nodes (21): cart_conflict_dialog.dart, ProductRestaurantExtension, Product, _addFoodItemToCart, _buildFoodCustomizationSheet, _buildGroceryPackSizeSheet, _buildVariantProduct, color (+13 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.10
Nodes (20): build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, _GpsRoutePainter, initState (+12 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.10
Nodes (20): autoDismissDuration, build, _buildFoodIllustration, createState, _CuteFoodVectorPainter, dispose, _fadeAnim, _fadeController (+12 more)

### Community 108 - "restaurant_sales_report_tab.dart"
Cohesion: 0.11
Nodes (18): brandGreen, build, _buildSummaryRow, commissionRate, createState, _customEndDate, _customStartDate, _onPeriodTap (+10 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.10
Nodes (20): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+12 more)

### Community 110 - "brand_input.dart"
Cohesion: 0.15
Nodes (12): BrandInput, build, controller, hint, keyboardType, label, obscure, onSuffixTap (+4 more)

### Community 111 - "privacy_policy_screen.dart"
Cohesion: 0.12
Nodes (15): design_system.dart, AppTheme, _pageTransitionsTheme, build, _buildCard, _buildParagraph, _buildSection, _bullet (+7 more)

### Community 112 - "page_transitions.dart"
Cohesion: 0.18
Nodes (16): Duration?, FadeScaleRoute, FadeThroughRoute, FastKiranaPageTransitionsBuilder, page, SharedAxisRoute, SwiggyModalRoute, transitionDurationOverride (+8 more)

### Community 113 - "order_detail_screen.dart"
Cohesion: 0.09
Nodes (21): build, _buildBillRow, _buildPayOnlineCard, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor, _getStatusStepIndex (+13 more)

### Community 114 - "live_clock_badge.dart"
Cohesion: 0.13
Nodes (15): backgroundColor, borderColor, build, createState, dispose, fontSize, _formatTime, iconColor (+7 more)

### Community 115 - "voice_search_sheet.dart"
Cohesion: 0.12
Nodes (17): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+9 more)

### Community 116 - "../core/theme/responsive.dart"
Cohesion: 0.20
Nodes (8): ../core/theme/responsive.dart, build, ConnectivityBanner, isOffline, onRetry, pendingCount, build, TrackingCancelCard

### Community 117 - "notifications_screen.dart"
Cohesion: 0.18
Nodes (11): ../data/repositories/order_repository.dart, _buildNotificationTile, createState, _formatTimeAgo, initState, _isLoading, _loadData, NotificationsScreen (+3 more)

### Community 118 - "app_connectivity.dart"
Cohesion: 0.14
Nodes (13): bool get, ChangeNotifier, Connectivity, AppConnectivityObserver, _checkConnection, _connectivity, dispose, _init (+5 more)

### Community 119 - "validators.dart"
Cohesion: 0.15
Nodes (12): email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone, pincode (+4 more)

### Community 120 - "kot_print_service.dart"
Cohesion: 0.13
Nodes (14): DateTime?, extractRestaurantItems, formatKOTDate, generateKOTPdfDocument, KotPrintService, printKOTReceipt, _recentPrintTimestamps, sendRemoteKOTToKitchen (+6 more)

### Community 121 - "deep_link_service.dart"
Cohesion: 0.11
Nodes (18): AppLinks, _appLinks, DeepLinkService, dispose, _handleDeepLink, init, instance, _isInitialized (+10 more)

### Community 122 - "ConsumerState"
Cohesion: 0.17
Nodes (16): ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, DeliveryLoginScreen, _DeliveryLoginScreenState, OtpScreen, _OtpScreenState, RestaurantDashboard (+8 more)

### Community 123 - "tracking_map_view.dart"
Cohesion: 0.11
Nodes (17): LatLng, OutletLocation, build, _buildMapCircleBtn, initialTarget, isDelivered, markers, onFitBounds (+9 more)

### Community 124 - "package:dio/dio.dart"
Cohesion: 0.13
Nodes (18): CartRepository, package:dio/dio.dart, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/product.dart, package:fastkirana_flutter/data/repositories/cart_repository.dart, package:fastkirana_flutter/providers/cart_provider.dart, main, main (+10 more)

### Community 125 - "address_selector_sheet.dart"
Cohesion: 0.16
Nodes (13): ../features/location/map_picker_screen.dart, build, currentUserIdProvider, activeAddress, AddressSelectorSheet, _AddressSelectorSheetState, createState, _getAddressIcon (+5 more)

### Community 126 - "app_toast.dart"
Cohesion: 0.10
Nodes (21): AppToast, build, createState, _currentOverlay, _dismissTimer, _fallbackSnackBar, _GenZTopToastWidget, _GenZTopToastWidgetState (+13 more)

### Community 127 - "banner_repository.dart"
Cohesion: 0.17
Nodes (11): BannerRepository, defaultBanners, dio, _diskBannersKey, _fetchFromNetwork, getBanners, _inMemoryBanners, _loadBannersFromDisk (+3 more)

### Community 128 - "retry_wrapper.dart"
Cohesion: 0.22
Nodes (8): build, child, error, isLoading, onRetry, retryLabel, RetryWrapper, Object?

### Community 129 - "location_drift_sheet.dart"
Cohesion: 0.20
Nodes (9): Address?, LocationDetails, _Address, build, driftDistanceKm, LocationDriftSheet, newGpsDetails, previousAddress (+1 more)

### Community 130 - "logger_service.dart"
Cohesion: 0.22
Nodes (8): debug, error, info, _logger, LoggerService, warning, package:logger/logger.dart, static final Logger

### Community 131 - "restaurant_menu_catalog_tab.dart"
Cohesion: 0.11
Nodes (18): bgMain, brandGreen, build, _buildMenuFilterChip, createState, dispose, menuItems, _menuSearchController (+10 more)

### Community 132 - "_CafeMenuScreenState"
Cohesion: 0.29
Nodes (8): build, _buildDarkstoreRecommendationsSection, CafeMenuScreen, _CafeMenuScreenState, _centerCategoryInHorizontalBar, restaurantAddonsProvider, restaurantMenuProvider, restaurantReviewsProvider

### Community 133 - "admin_order_card.dart"
Cohesion: 0.11
Nodes (18): bool?, OrderStatus, availableRiders, color, formatOrderTime, getStatusColor, icon, isKOTPrinted (+10 more)

### Community 134 - "String?"
Cohesion: 0.25
Nodes (7): checkDishTimeAvailability, DishTimingStatus, formattedTimeSlot, formatTime12h, isAvailableNow, nextAvailableTimeStr, String?

### Community 135 - "rider_pickup_card.dart"
Cohesion: 0.15
Nodes (12): brandGreen, build, emeraldGreen, EmptyPendingPickupCard, isUpdating, order, primaryRed, RiderPickupCard (+4 more)

### Community 136 - "package:fastkirana_flutter/core/services/logger_service.dart"
Cohesion: 0.10
Nodes (18): ../data/repositories/wishlist_repository.dart, Dio, dio, getCoupons, addToWishlist, dio, getWishlist, _handleError (+10 more)

### Community 137 - "store_hub_provider.dart"
Cohesion: 0.13
Nodes (14): address, customerLat, customerLng, distanceKm, hub, hubs, hubsAsync, isServiceable (+6 more)

### Community 138 - "order_alarm_service.dart"
Cohesion: 0.12
Nodes (16): AudioPlayer, _activeOrderId, _alarmLoopTimer, _audioPlayer, instance, _isMuted, _isPlaying, OrderAlarmService (+8 more)

### Community 139 - "store_hub.dart"
Cohesion: 0.13
Nodes (14): city, defaultGhatampur, deliveryRadiusKm, fromJson, groceryOpen, id, isActive, latitude (+6 more)

### Community 140 - "offline_banner.dart"
Cohesion: 0.14
Nodes (15): ../core/utils/app_connectivity.dart, connectivityProvider, build, createState, dispose, OfflineBanner, _OfflineBannerState, offlineText (+7 more)

### Community 141 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.09
Nodes (20): ../core/network/api_client.dart, ../data/models/banner.dart, ../data/repositories/banner_repository.dart, AddReviewScreen, _AddReviewScreenState, build, createState, dispose (+12 more)

### Community 142 - "restaurants_list_screen.dart"
Cohesion: 0.22
Nodes (8): _buildFilterPill, createState, _cuisineCategories, dispose, RestaurantsListScreen, _searchController, static const List, ../../widgets/unserviceable_location_banner.dart

### Community 143 - "unserviceable_location_banner.dart"
Cohesion: 0.10
Nodes (22): ../core/services/location_service.dart, ../features/cart/cart_screen.dart, ../features/location/delivery_location_screen.dart, deliveryTierProvider, bottomOffset, build, createState, FloatingCartBar (+14 more)

### Community 144 - "battery_optimization_service.dart"
Cohesion: 0.11
Nodes (16): dart:io, BatteryOptimizationService, markDismissed, _prefKeyDismissed, requestExemption, shouldShowPrompt, _auth, authenticate (+8 more)

### Community 145 - "_DeliveryDashboardState"
Cohesion: 0.50
Nodes (4): DeliveryDashboard, _DeliveryDashboardState, _loadUserInfo, currentUserProvider

### Community 146 - "dart:async"
Cohesion: 0.12
Nodes (14): Completer, ../config/app_config.dart, dart:async, int?, dio, _isRefreshingToken, message, null (+6 more)

### Community 148 - "StatefulWidget"
Cohesion: 0.15
Nodes (12): Animation, AnimationController, build, _controller, createState, dispose, _fadeAnimation, initState (+4 more)

### Community 149 - "grid_skeletons.dart"
Cohesion: 0.09
Nodes (21): EdgeInsets, BrandCard, build, child, elevated, margin, onTap, padding (+13 more)

### Community 152 - "app_flavor.dart"
Cohesion: 0.15
Nodes (12): AppFlavor, appTitle, baseUrl, flavor, FlavorConfig, initialize, _instance, isCustomer (+4 more)

### Community 153 - "supabase_service.dart"
Cohesion: 0.17
Nodes (11): _activeBroadcastChannels, broadcastRiderLocation, _client, initialize, _isInitialized, subscribeToAllOrdersRealtime, subscribeToOrderLocation, SupabaseService (+3 more)

### Community 154 - "map_marker_generator.dart"
Cohesion: 0.20
Nodes (9): dart:ui, _cache, createCustomMarkerBitmap, createRiderMarkerBitmap, initCustomMarkers, MapMarkerGenerator, _renderCanvasToBitmap, package:google_maps_flutter/google_maps_flutter.dart (+1 more)

### Community 155 - "VoidCallback?"
Cohesion: 0.11
Nodes (16): AddressCard, build, fullAddress, isSelected, label, onTap, build, onSeeAll (+8 more)

### Community 156 - "order_recipient_helper.dart"
Cohesion: 0.18
Nodes (10): @immutable, buyerName, buyerPhone, deliveryInstructions, fromOrder, fullRecipientLabel, isOrderForSomeone, OrderRecipientDetails (+2 more)

### Community 157 - "dart:math"
Cohesion: 0.20
Nodes (9): dart:math, adaptiveJitterThreshold, calculateBearing, estimateEtaWeightedAverage, GeoMathUtils, getHaversineDistance, _gpsHistory, interpolateHeading (+1 more)

### Community 158 - "main.dart"
Cohesion: 0.11
Nodes (18): core/routes/app_router.dart, core/services/deep_link_service.dart, ../core/services/notification_service.dart, core/theme/app_theme.dart, firebase_options.dart, android, DefaultFirebaseOptions, ios (+10 more)

### Community 159 - "delivery/delivery_login.dart"
Cohesion: 0.08
Nodes (21): delivery_dashboard.dart, AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive (+13 more)

### Community 160 - "cart_bill_summary_card.dart"
Cohesion: 0.18
Nodes (10): build, _buildRow, CartBillSummaryCard, couponDiscount, deliveryFee, grandTotal, handlingFee, itemTotal (+2 more)

### Community 161 - "storeSettingsProvider"
Cohesion: 0.08
Nodes (26): ../data/models/store_settings.dart, _loadSettings, build, _buildBottomCheckoutBar, build, _fetchQrData, build, HomeTrustBadgeStrip (+18 more)

### Community 162 - "auth/delivery_login.dart"
Cohesion: 0.13
Nodes (14): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, dispose, _errorMessage, _handlePasswordLogin, _isLoading (+6 more)

### Community 163 - "../core/utils/restaurant_utils.dart"
Cohesion: 0.20
Nodes (9): ../core/utils/restaurant_utils.dart, build, CartConflictDialog, existingOutletName, groceryItemsCount, onCancel, onConfirm, product (+1 more)

### Community 164 - "restaurant_metrics_bar.dart"
Cohesion: 0.20
Nodes (9): activeOrders, build, _buildLiveClock, _buildMetricItem, isPlayingAlarm, onMuteAlarm, pendingCount, RestaurantMetricsBar (+1 more)

### Community 165 - "Color"
Cohesion: 0.10
Nodes (19): Color, appliedCoupon, build, CartSavingsBanner, couponDiscount, freeDeliveryThreshold, onApplyCouponTap, onRemoveCouponTap (+11 more)

### Community 166 - "restaurant_order_card_view.dart"
Cohesion: 0.20
Nodes (9): build, isUpdating, onAcceptAndCook, onEditOrder, onMarkReady, onPrintKot, onReject, order (+1 more)

### Community 167 - "sponsored_ad_card.dart"
Cohesion: 0.20
Nodes (9): actionText, build, discountText, imageUrl, onTap, promoCode, SponsoredAdCard, subtitle (+1 more)

### Community 169 - "Map"
Cohesion: 0.25
Nodes (7): CachedMapTileProvider, customHeaders, getImage, Map, package:flutter_map/flutter_map.dart, package:flutter/widgets.dart, TileProvider

### Community 170 - "../data/models/order.dart"
Cohesion: 0.12
Nodes (15): ../core/config/app_config.dart, ../data/models/order.dart, AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp, build (+7 more)

### Community 171 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.12
Nodes (15): ../data/models/cart.dart, CartItem, build, CartItemCard, item, onDecrement, onIncrement, build (+7 more)

### Community 172 - "location_service_test.dart"
Cohesion: 0.29
Nodes (5): package:fastkirana_flutter/core/config/app_config.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/data/models/store_settings.dart, main, main

### Community 173 - "AsyncValue"
Cohesion: 0.47
Nodes (6): AsyncValue, AddressesNotifier, AuthNotifier, CartNotifier, WishlistNotifier, StateNotifier

### Community 174 - "app_errors.dart"
Cohesion: 0.14
Nodes (13): Exception, ApiException, AppException, auth, code, color, isRetryable, message (+5 more)

### Community 175 - "package:flutter/services.dart"
Cohesion: 0.15
Nodes (12): build, CheckoutDeliveryAddressCard, onAddressChanged, selectedAddress, tier, build, CheckoutPackagingSelector, onPackagingChanged (+4 more)

### Community 177 - "Order"
Cohesion: 0.15
Nodes (12): @JsonSerializable, Cart, _, Order, OrderItem, AuthResponse, build, isCancelling (+4 more)

### Community 178 - "floating_order_tracking_bar.dart"
Cohesion: 0.17
Nodes (12): ../core/services/supabase_service.dart, ../features/orders/order_tracking_screen.dart, ../features/orders/orders_screen.dart, bottomOffset, createState, dispose, FloatingOrderTrackingBar, _FloatingOrderTrackingBarState (+4 more)

### Community 179 - "dart:convert"
Cohesion: 0.17
Nodes (11): dart:convert, clearQueue, enqueueAction, flushQueue, getPendingCount, hasPendingActions, OfflineSyncService, queueAdmin (+3 more)

### Community 180 - "admin_stat_card.dart"
Cohesion: 0.18
Nodes (10): IconData?, AdminStatCard, bgColor, borderColor, build, icon, iconColor, subtitle (+2 more)

### Community 181 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.25
Nodes (7): ../../../core/services/battery_optimization_service.dart, BatteryOptimizationDialog, build, _buildStepRow, onDismissed, showIfNecessary, package:flutter_bounceable/flutter_bounceable.dart

### Community 182 - "core/widgets/empty_state.dart"
Cohesion: 0.25
Nodes (7): actionLabel, build, EmptyState, icon, onAction, subtitle, title

### Community 183 - "List"
Cohesion: 0.33
Nodes (6): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState, List

### Community 184 - "about_screen.dart"
Cohesion: 0.33
Nodes (5): AboutScreen, build, _divider, _linkItem, _statBox

### Community 185 - "admin_reports.dart"
Cohesion: 0.33
Nodes (5): AdminReportsScreen, _breakdownRow, build, _reportStat, _topRow

### Community 186 - "admin_settings.dart"
Cohesion: 0.40
Nodes (4): AdminSettingsScreen, build, _divider, _switchTile

## Knowledge Gaps
- **3068 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+3063 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `StoreHub` connect `store_hub.dart` to `store_hub_provider.dart`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `dioProvider` connect `dioProvider` to `package:flutter_riverpod/flutter_riverpod.dart`, `cart_screen.dart`, `_DeliveryDashboardState`, `dart:async`, `cartProvider`, `main_shell.dart`, `otp_screen.dart`, `profile_screen.dart`, `admin_orders_list.dart`, `auth/delivery_login.dart`, `storeSettingsProvider`, `login_screen.dart`, `order_success_screen.dart`, `admin_products.dart`, `floating_order_tracking_bar.dart`, `FadeSlideRoute`, `static const Color`, `authProvider`, `_DoorstepCashfreeQrSheetState`, `_OrderTrackingScreenState`, `order_edit_modal.dart`, `admin_dashboard.dart`, `admin_login.dart`, `categoriesProvider`, `picker_dashboard.dart`, `add_picker_product_modal.dart`, `add_restaurant_product_modal.dart`, `notifications_screen.dart`, `ConsumerState`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `cartProvider` connect `cartProvider` to `storeSettingsProvider`, `search_screen.dart`, `product_detail_screen.dart`, `orders_screen.dart`, `variant_selector_sheet.dart`, `product_card.dart`, `categoriesProvider`, `wishlist_screen.dart`, `unserviceable_location_banner.dart`, `order_success_screen.dart`, `ConsumerState`, `FadeSlideRoute`, `static const Color`, `cart_provider.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _3068 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009852216748768473 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02702702702702703 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._