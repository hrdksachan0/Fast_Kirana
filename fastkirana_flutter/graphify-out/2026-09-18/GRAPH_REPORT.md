# Graph Report - fastkirana_flutter  (2026-09-17)

## Corpus Check
- 250 files · ~720,798 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4247 nodes · 6744 edges · 173 communities (167 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `73420b08`
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
- storeSettingsProvider
- dynamic_hero_banner_carousel.dart
- login_screen.dart
- ../core/routes/page_transitions.dart
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
- admin_login.dart
- delivery_order.dart
- onboarding_screen.dart
- splash/splash_screen.dart
- Order
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
- auth/delivery_login.dart
- restaurant_login.dart
- rider_active_delivery_card.dart
- picker_order.dart
- delivery_mode_header.dart
- order_edit_modal.dart
- admin_dashboard.dart
- api_endpoints.dart
- List
- brand_button.dart
- checkout_delivery_address_card.dart
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
- ../data/models/order.dart
- delivery_header.dart
- package:dio/dio.dart
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
- offline_cart_sync_test.dart
- address_selector_sheet.dart
- app_toast.dart
- banner_repository.dart
- animated_cart_badge.dart
- package:flutter/services.dart
- logger_service.dart
- restaurant_menu_catalog_tab.dart
- _CafeMenuScreenState
- admin_order_card.dart
- String?
- app_errors.dart
- package:flutter_riverpod/flutter_riverpod.dart
- store_hub_provider.dart
- order_alarm_service.dart
- store_hub.dart
- offline_banner.dart
- add_review_screen.dart
- restaurants_list_screen.dart
- unserviceable_location_banner.dart
- dart:convert
- _DeliveryDashboardState
- dart:async
- _CategoryChipsDelegate
- AnimationController
- floating_order_tracking_bar.dart
- @gmail
- app_flavor.dart
- admin_stat_card.dart
- map_marker_generator.dart
- ../data/models/address.dart
- banner_provider.dart
- dart:math
- firebase_options.dart
- admin_coupon_detail.dart
- cart_bill_summary_card.dart
- firebaseMessagingBackgroundHandler
- settings_screen.dart
- _AreaSearchModal
- package:flutter_bounceable/flutter_bounceable.dart
- Color
- _MapPickerScreenState
- battery_optimization_service.dart
- cart_item_card.dart
- package:flutter/foundation.dart
- Map
- State

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 91 edges
2. `cartProvider` - 42 edges
3. `authProvider` - 35 edges
4. `FadeSlideRoute` - 34 edges
5. `selectedAddressProvider` - 30 edges
6. `categoriesProvider` - 27 edges
7. `storeSettingsProvider` - 25 edges
8. `addressesProvider` - 21 edges
9. `RecognitionListener` - 13 edges
10. `Order` - 13 edges

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

## Communities (173 total, 6 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (202): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+194 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.03
Nodes (73): ../../core/network/network_retry_helper.dart, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, bgMain, brandAmber, brandGreen (+65 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.04
Nodes (51): CFPaymentGatewayService, ../checkout/order_success_screen.dart, _buildBottomProceedBar, _buildCartItemsReview, _buildPlacingOrderOverlay, _buildReviewItemRow, _cfService, _completeOrderPlacement (+43 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.04
Nodes (50): _buildActiveDeliveryTracker, _buildCategoryAvatarImage, _buildCategoryFallback, _buildCategoryToggle, _buildFoodGreetingBanner, _buildFooter, _buildHorizontalProductSection, _buildInfiniteFeedFooter (+42 more)

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
Cohesion: 0.03
Nodes (64): AddonGroup, AddonItem, addons, address, availableEndTime, availableStartTime, bannerUrl, barcode (+56 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.08
Nodes (27): build, build, _buildEmptyState, _buildSearchBox, _buildSegmentedTabs, _buildStatusFilterPills, createState, dispose (+19 more)

### Community 8 - "kitchen_order.dart"
Cohesion: 0.05
Nodes (37): cookingInstruction, createdAt, customerAddress, customerName, customerPhone, deliveryMethod, elapsedMinutes, fromJson (+29 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.07
Nodes (27): _cachedRefreshToken, _cachedToken, _cachedUserData, _cachedUserEmail, _cachedUserId, _cachedUserName, _cachedUserPhone, _cachedUserRole (+19 more)

### Community 10 - "product_card.dart"
Cohesion: 0.04
Nodes (55): ../features/products/product_detail_screen.dart, Gradient, _addButton, bestseller, bogo, bogoBadgeText, child, createState (+47 more)

### Community 11 - "add_item_search_sheet.dart"
Cohesion: 0.09
Nodes (23): ../../../core/utils/app_toast.dart, AddItemSearchSheet, _AddItemSearchSheetState, _adminCatalogFilter, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, createState (+15 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.06
Nodes (35): AndroidFlutterLocalNotificationsPlugin, dart:typed_data, _bgRecentMessageTimes, body, clearAllNotifications, data, getFcmToken, getNotificationPreferences (+27 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.03
Nodes (60): GlobalKey, _activeCategoryTag, _buildCategories, _buildCategoryThumbnail, _buildFallbackBanner, _buildFallbackLogo, _buildFallbackOfferTicket, _buildLocalAssetOrEmoji (+52 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.04
Nodes (45): ../checkout/checkout_screen.dart, coupons_screen.dart, _appliedCoupon, _applyCoupon, _bogoBadgeText, brandGreen, _buildBillDetailsCard, _buildBillRow (+37 more)

### Community 15 - "cart.dart"
Cohesion: 0.08
Nodes (23): int get, appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items (+15 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.07
Nodes (27): activeOrdersCount, address, bannerUrl, city, commissionRate, cuisineTags, deliveryTime, description (+19 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (20): ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds, filteredUpsells (+12 more)

### Community 18 - "cartProvider"
Cohesion: 0.13
Nodes (17): build, _buildCartErrorState, _buildCartItemCard, _buildCartScreenContent, CartScreen, _CartScreenState, _buildCompleteYourMealSection, _handleCashfreeError (+9 more)

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
Nodes (15): ../categories/categories_screen.dart, home_screen.dart, _autoShowTimer, createState, didChangeAppLifecycleState, dispose, initState, _isBottomNavVisible (+7 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.07
Nodes (26): build, _checkClipboard, _clipboardOtp, _controllers, createState, _currentOtp, didChangeAppLifecycleState, dispose (+18 more)

### Community 24 - "address_provider.dart"
Cohesion: 0.12
Nodes (18): AsyncValue, ../data/repositories/address_repository.dart, AddressRepository, addAddress, addressesAsync, AddressesNotifier, clear, deleteAddress (+10 more)

### Community 25 - "storeSettingsProvider"
Cohesion: 0.07
Nodes (34): ConsumerWidget, _loadSettings, AdminOrderCard, build, _handlePlaceOrder, _fetchQrData, _buildTrustBadgeStrip, HomeHeroBanner (+26 more)

### Community 26 - "dynamic_hero_banner_carousel.dart"
Cohesion: 0.09
Nodes (25): ../features/categories/category_products_screen.dart, build, bannersProvider, _advanceToNext, _autoSlideTimer, build, _buildBannerCard, _buildShimmerPlaceholder (+17 more)

### Community 27 - "login_screen.dart"
Cohesion: 0.11
Nodes (19): ../../data/repositories/auth_repository.dart, build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleContinue (+11 more)

### Community 28 - "../core/routes/page_transitions.dart"
Cohesion: 0.10
Nodes (20): ../../categories/category_products_screen.dart, category_products_screen.dart, ../core/routes/page_transitions.dart, ../data/models/category.dart, _categories, CategoriesScreen, build, CategoriesScreen (+12 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.03
Nodes (66): ../core/theme/design_system.dart, delivery_dashboard.dart, AboutScreen, build, _divider, _linkItem, _statBox, AdminBannersScreen (+58 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.08
Nodes (24): FocusNode, _buildFilterPill, category, CategoryProductsScreen, createState, dispose, emoji, id (+16 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.09
Nodes (22): address_book_screen.dart, ../auth/login_screen.dart, ../delivery/picker_dashboard.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader (+14 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.06
Nodes (40): AppShimmer, build, child, count, OrderCardShimmer, ProductCardShimmer, ProductGridShimmer, build (+32 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.03
Nodes (65): ../common/widgets/battery_optimization_dialog.dart, ../../core/services/kot_print_service.dart, ../../core/services/offline_sync_service.dart, ../../core/services/order_alarm_service.dart, ../delivery/widgets/connectivity_banner.dart, _allOrders, _assignedStoreId, _audioPlayer (+57 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.09
Nodes (26): ../data/models/coupon.dart, AdminCouponsScreen, build, _buildRestaurantOffersStrip, _applyCode, build, _buildCouponCard, _buildLoadingShimmer (+18 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (40): AddAddressScreen, _AddAddressScreenState, _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField (+32 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.06
Nodes (36): empty_state.dart, widgets, _buildFoodRestaurantListing, build, _buildSearchResults, _buildShimmerGrid, _clearRecentSearches, _controller (+28 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.11
Nodes (19): ../cart/cart_screen.dart, ../core/utils/dish_timing.dart, ProductVariant, _addToCart, _buildCustomizedProduct, _buildQualityRow, createState, initState (+11 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.08
Nodes (27): @freezed, Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl (+19 more)

### Community 40 - "coupon.dart"
Cohesion: 0.11
Nodes (18): autoApply, badgeText, bogoType, categoryId, code, Coupon, DiscountType, expiresAt (+10 more)

### Community 41 - "admin_login.dart"
Cohesion: 0.11
Nodes (16): ../admin/admin_dashboard.dart, ../data/models/user.dart, build, createState, dispose, _emailController, _errorMessage, _handleAdminLogin (+8 more)

### Community 42 - "delivery_order.dart"
Cohesion: 0.05
Nodes (40): address, city, combinedId, createdAt, customerName, customerPhone, deliveryFee, DeliveryOrder (+32 more)

### Community 43 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 44 - "splash/splash_screen.dart"
Cohesion: 0.12
Nodes (15): build, _contentFade, createState, dispose, _hasNavigated, initState, _logoScale, _mainController (+7 more)

### Community 45 - "Order"
Cohesion: 0.29
Nodes (7): @JsonSerializable, _, Cart, _, Order, OrderItem, AuthResponse

### Community 46 - "admin_authorization.dart"
Cohesion: 0.15
Nodes (12): AdminAuthorization, buildStaffHeaders, currentStaffHeaders, isAdmin, isStaff, options, optionsAsync, staffRoles (+4 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.14
Nodes (14): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, _bundledCategoryAssets (+6 more)

### Community 48 - "banner.dart"
Cohesion: 0.06
Nodes (30): Banner, hashCode, operator, _privateConstructorUsedError, toString, code, Banner, fromJson (+22 more)

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
Nodes (30): _cachedCategories, _cachedProducts, _cacheKey, _cacheTTLMinutes, _categoryAliases, dio, _diskCategoriesKey, _diskCategoryTimestampKey (+22 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.11
Nodes (17): AuthRepository, dio, getProfile, _handleError, login, _parseSessionResponse, sendEmailOtp, sendOtp (+9 more)

### Community 54 - "../data/models/product.dart"
Cohesion: 0.09
Nodes (21): ../../core/widgets/loading_widgets.dart, ../data/models/product.dart, ../data/repositories/product_repository.dart, badgeText, build, FlashDealsCarousel, onSeeAll, products (+13 more)

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
Cohesion: 0.12
Nodes (17): FadeSlideRoute, _buildMenuTab, _buildReviewsTab, _buildBottomCheckoutBar, build, _buildReferenceCategoryCard, build, _buildCircularCategoryCarousel (+9 more)

### Community 60 - "static const Color"
Cohesion: 0.11
Nodes (29): bootstrapUserLocation, checkLocationDriftAndPrompt, LocationService, build, CheckoutScreen, _CheckoutScreenState, _buildTopHeader, build (+21 more)

### Community 61 - "auth/delivery_login.dart"
Cohesion: 0.12
Nodes (15): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, DeliveryLoginScreen, dispose, _errorMessage, _handlePasswordLogin (+7 more)

### Community 62 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "rider_active_delivery_card.dart"
Cohesion: 0.06
Nodes (31): ../core/config/app_config.dart, brandGreen, build, emeraldGreen, EmptyOutForDeliveryCard, isUpdating, order, primaryRed (+23 more)

### Community 64 - "picker_order.dart"
Cohesion: 0.08
Nodes (24): createdAt, customerAddress, customerName, customerPhone, elapsedMinutes, fromJson, id, imageUrl (+16 more)

### Community 65 - "delivery_mode_header.dart"
Cohesion: 0.08
Nodes (23): , activeLocationSubtitle, activeLocationTitle, build, _buildSegmentedModeToggle, cafeSvg, currentSearchPlaceholder, d (+15 more)

### Community 66 - "order_edit_modal.dart"
Cohesion: 0.07
Nodes (28): ../../core/services/admin_notification_service.dart, brandAmber, brandGreen, build, _calculateSubtotal, createState, initState, isAdmin (+20 more)

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.10
Nodes (20): admin_orders_list.dart, admin_products.dart, _buildDockItem, _buildOutletTile, createState, _currentIndex, _handleBackPress, initState (+12 more)

### Community 68 - "api_endpoints.dart"
Cohesion: 0.10
Nodes (20): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+12 more)

### Community 69 - "List"
Cohesion: 0.33
Nodes (6): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState, List

### Community 70 - "brand_button.dart"
Cohesion: 0.06
Nodes (32): BorderRadius?, BoxShape, double?, backgroundColor, borderRadius, BrandButton, build, fontSize (+24 more)

### Community 71 - "checkout_delivery_address_card.dart"
Cohesion: 0.08
Nodes (24): ../core/services/location_service.dart, ../features/cart/cart_screen.dart, DeliveryTierInfo, build, _buildRow, CheckoutBillBreakdown, deliveryFee, discountAmount (+16 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.06
Nodes (41): CustomPainter, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter, _CafeFrontPainter (+33 more)

### Community 73 - "payment_failed_cod_sheet.dart"
Cohesion: 0.10
Nodes (20): build, createState, dispose, grandTotal, _handleCancel, _handleConfirmCod, _handleRetryPayment, initState (+12 more)

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.07
Nodes (26): package:fastkirana_flutter/core/config/app_config.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/data/models/order.dart, package:fastkirana_flutter/data/models/restaurant.dart, package:fastkirana_flutter/data/models/user.dart, package:fastkirana_flutter/features/delivery/widgets/connectivity_banner.dart (+18 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.02
Nodes (85): BitmapDescriptor?, GoogleMapController?, _audioPlayer, brandGreen, _calculateBearing, _calculateETA, _cfService, _checkAndRequestLocationPermission (+77 more)

### Community 76 - "tracking_status_stepper.dart"
Cohesion: 0.09
Nodes (22): activeColor, AnimatedStepNode, _AnimatedStepNodeState, build, cleanDisplayId, completedColor, createState, didUpdateWidget (+14 more)

### Community 77 - "categoriesProvider"
Cohesion: 0.12
Nodes (26): build, AdminProductsScreen, _AdminProductsScreenState, build, build, build, _CategoryProductsScreenState, build (+18 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (38): BuildContext, EdgeInsetsGeometry, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+30 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.05
Nodes (39): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+31 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.05
Nodes (38): ../../core/services/map_tile_cache_service.dart, doorstep_details_screen.dart, _areaName, build, _calculateDistance, createState, currentArea, _currentLat (+30 more)

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.06
Nodes (31): ../common/order_edit_modal.dart, _autoRefreshTimer, bgMain, brandGreen, brandOrange, build, _buildEmptyState, _buildMetricStrip (+23 more)

### Community 82 - "location_service.dart"
Cohesion: 0.06
Nodes (33): area, baseFee, cart, city, deliveryFee, distanceKm, feeDescription, fetchCurrentLocationDetails (+25 more)

### Community 83 - "RecognitionListener"
Cohesion: 0.14
Nodes (9): MainActivity, RecognitionListener, Bundle, ByteArray, FlutterActivity, FlutterEngine, Intent, MethodChannel (+1 more)

### Community 84 - "restaurant_utils.dart"
Cohesion: 0.06
Nodes (32): address, _byKey, categorySlug, darkstoreLocation, _ensureInitialized, false, find, findByPhone (+24 more)

### Community 85 - "FastKirana Flutter"
Cohesion: 0.15
Nodes (12): Architecture, Backend, Development, FastKirana Flutter, Getting Started, License, Prerequisites, Project Context (+4 more)

### Community 86 - "add_picker_product_modal.dart"
Cohesion: 0.07
Nodes (30): class, FormState, AddPickerProductModal, _AddPickerProductModalState, _barcodeController, brandGreen, brandOrange, _commonUnits (+22 more)

### Community 89 - "add_restaurant_product_modal.dart"
Cohesion: 0.06
Nodes (31): AddRestaurantProductModal, _AddRestaurantProductModalState, _buildFoodTypeOption, createState, _descriptionController, dispose, _fetchRestaurantSections, _formKey (+23 more)

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

### Community 99 - "../data/models/order.dart"
Cohesion: 0.09
Nodes (19): ../data/models/order.dart, build, isProcessingPayment, onPayOnline, onSwitchToCOD, order, statusStep, TrackingPaymentCard (+11 more)

### Community 100 - "delivery_header.dart"
Cohesion: 0.08
Nodes (24): build, CheckoutPackagingSelector, onPackagingChanged, selectedPackaging, activeTab, build, DeliveryHeader, _greeting (+16 more)

### Community 101 - "package:dio/dio.dart"
Cohesion: 0.12
Nodes (15): Dio, CouponRepository, dio, getCoupons, addToWishlist, dio, getWishlist, _handleError (+7 more)

### Community 102 - "auth_provider.dart"
Cohesion: 0.08
Nodes (24): cart_provider.dart, core/routes/app_router.dart, core/services/deep_link_service.dart, ../core/services/notification_service.dart, ../core/services/secure_storage_service.dart, core/theme/app_theme.dart, ../features/orders/orders_screen.dart, firebase_options.dart (+16 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (18): ../home/main_shell.dart, autoFetchLocation, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose, _getAddressIcon (+10 more)

### Community 104 - "variant_selector_sheet.dart"
Cohesion: 0.07
Nodes (29): cart_conflict_dialog.dart, ../core/utils/restaurant_utils.dart, ProductRestaurantExtension, Product, build, CartConflictDialog, existingOutletName, groceryItemsCount (+21 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.11
Nodes (18): build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, _GpsRoutePainter, initState (+10 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (19): autoDismissDuration, build, _buildFoodIllustration, createState, dispose, _fadeAnim, _fadeController, _floatAnim (+11 more)

### Community 108 - "restaurant_sales_report_tab.dart"
Cohesion: 0.11
Nodes (18): brandGreen, build, _buildSummaryRow, commissionRate, createState, _customEndDate, _customStartDate, _onPeriodTap (+10 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (19): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+11 more)

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
Nodes (15): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+7 more)

### Community 116 - "../core/theme/responsive.dart"
Cohesion: 0.04
Nodes (48): ../core/theme/responsive.dart, AddressCard, build, fullAddress, isSelected, label, onTap, actionLabel (+40 more)

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
Cohesion: 0.07
Nodes (43): CategoriesScreen, ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, AdminDashboard, _AdminDashboardState, _handleLogout, AdminOrdersScreen (+35 more)

### Community 123 - "tracking_map_view.dart"
Cohesion: 0.11
Nodes (18): LatLng, OutletLocation, build, _buildMapCircleBtn, initialTarget, isDelivered, markers, onFitBounds (+10 more)

### Community 124 - "offline_cart_sync_test.dart"
Cohesion: 0.12
Nodes (18): CartRepository, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/cart.dart, package:fastkirana_flutter/data/models/product.dart, package:fastkirana_flutter/data/repositories/cart_repository.dart, package:fastkirana_flutter/providers/cart_provider.dart, main, main (+10 more)

### Community 125 - "address_selector_sheet.dart"
Cohesion: 0.18
Nodes (10): Address?, ../features/location/map_picker_screen.dart, _Address, activeAddress, createState, _getAddressIcon, _isLocatingGps, onAddressSelected (+2 more)

### Community 126 - "app_toast.dart"
Cohesion: 0.10
Nodes (21): AppToast, build, createState, _currentOverlay, _dismissTimer, _fallbackSnackBar, _GenZTopToastWidget, _GenZTopToastWidgetState (+13 more)

### Community 127 - "banner_repository.dart"
Cohesion: 0.18
Nodes (10): defaultBanners, dio, _diskBannersKey, _fetchFromNetwork, getBanners, _inMemoryBanners, _loadBannersFromDisk, _saveBannersToDisk (+2 more)

### Community 128 - "animated_cart_badge.dart"
Cohesion: 0.12
Nodes (15): EdgeInsets, badgeColor, build, child, onTap, textColor, BrandCard, build (+7 more)

### Community 129 - "package:flutter/services.dart"
Cohesion: 0.12
Nodes (15): _auth, authenticate, BiometricService, getAvailableBiometrics, isBiometricAvailable, LocationDetails, build, driftDistanceKm (+7 more)

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

### Community 135 - "app_errors.dart"
Cohesion: 0.14
Nodes (13): Exception, ApiException, AppException, auth, code, color, isRetryable, message (+5 more)

### Community 136 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.11
Nodes (17): ../core/network/api_client.dart, ../data/models/store_settings.dart, ../data/repositories/coupon_repository.dart, ../data/repositories/wishlist_repository.dart, WishlistRepository, build, couponRepositoryProvider, getCoupons (+9 more)

### Community 137 - "store_hub_provider.dart"
Cohesion: 0.11
Nodes (17): address_provider.dart, ../data/models/store_hub.dart, activeStoreHubsProvider, address, customerLat, customerLng, distanceKm, hub (+9 more)

### Community 138 - "order_alarm_service.dart"
Cohesion: 0.11
Nodes (17): AudioPlayer, _activeOrderId, _alarmLoopTimer, _audioPlayer, instance, _isMuted, _isPlaying, OrderAlarmService (+9 more)

### Community 139 - "store_hub.dart"
Cohesion: 0.13
Nodes (14): city, defaultGhatampur, deliveryRadiusKm, fromJson, groceryOpen, id, isActive, latitude (+6 more)

### Community 140 - "offline_banner.dart"
Cohesion: 0.14
Nodes (15): ../core/utils/app_connectivity.dart, connectivityProvider, build, createState, dispose, OfflineBanner, _OfflineBannerState, offlineText (+7 more)

### Community 141 - "add_review_screen.dart"
Cohesion: 0.17
Nodes (12): AddReviewScreen, _AddReviewScreenState, build, createState, dispose, _isSubmitting, productName, _rating (+4 more)

### Community 142 - "restaurants_list_screen.dart"
Cohesion: 0.20
Nodes (9): _buildFilterPill, createState, _cuisineCategories, dispose, RestaurantsListScreen, _searchController, static const List, ../../widgets/floating_cart_bar.dart (+1 more)

### Community 143 - "unserviceable_location_banner.dart"
Cohesion: 0.15
Nodes (14): ../features/location/delivery_location_screen.dart, deliveryTierProvider, build, build, createState, dispose, distanceKm, _isNotified (+6 more)

### Community 144 - "dart:convert"
Cohesion: 0.17
Nodes (11): dart:convert, clearQueue, enqueueAction, flushQueue, getPendingCount, hasPendingActions, OfflineSyncService, queueAdmin (+3 more)

### Community 145 - "_DeliveryDashboardState"
Cohesion: 0.50
Nodes (4): DeliveryDashboard, _DeliveryDashboardState, _loadUserInfo, currentUserProvider

### Community 146 - "dart:async"
Cohesion: 0.07
Nodes (26): Completer, ../config/app_config.dart, dart:async, int?, dio, _isRefreshingToken, message, null (+18 more)

### Community 148 - "AnimationController"
Cohesion: 0.17
Nodes (11): Animation, AnimationController, build, _controller, createState, dispose, _fadeAnimation, initState (+3 more)

### Community 149 - "floating_order_tracking_bar.dart"
Cohesion: 0.18
Nodes (11): ../core/services/supabase_service.dart, ../features/orders/order_tracking_screen.dart, bottomOffset, createState, dispose, FloatingOrderTrackingBar, _FloatingOrderTrackingBarState, initState (+3 more)

### Community 152 - "app_flavor.dart"
Cohesion: 0.15
Nodes (12): AppFlavor, appTitle, baseUrl, flavor, FlavorConfig, initialize, _instance, isCustomer (+4 more)

### Community 153 - "admin_stat_card.dart"
Cohesion: 0.18
Nodes (10): IconData?, AdminStatCard, bgColor, borderColor, build, icon, iconColor, subtitle (+2 more)

### Community 154 - "map_marker_generator.dart"
Cohesion: 0.20
Nodes (9): dart:ui, _cache, createCustomMarkerBitmap, createRiderMarkerBitmap, initCustomMarkers, MapMarkerGenerator, _renderCanvasToBitmap, package:google_maps_flutter/google_maps_flutter.dart (+1 more)

### Community 155 - "../data/models/address.dart"
Cohesion: 0.29
Nodes (7): ../data/models/address.dart, AddressesScreen, build, _buildAddressCard, _iconForLabel, addressRepositoryProvider, ../../widgets/brand_card.dart

### Community 156 - "banner_provider.dart"
Cohesion: 0.29
Nodes (6): ../data/models/banner.dart, ../data/repositories/banner_repository.dart, BannerRepository, bannerRepositoryProvider, getBanners, repo

### Community 157 - "dart:math"
Cohesion: 0.20
Nodes (9): dart:math, adaptiveJitterThreshold, calculateBearing, estimateEtaWeightedAverage, GeoMathUtils, getHaversineDistance, _gpsHistory, interpolateHeading (+1 more)

### Community 158 - "firebase_options.dart"
Cohesion: 0.29
Nodes (6): android, DefaultFirebaseOptions, ios, web, package:firebase_core/firebase_core.dart, static const FirebaseOptions

### Community 159 - "admin_coupon_detail.dart"
Cohesion: 0.29
Nodes (7): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive

### Community 160 - "cart_bill_summary_card.dart"
Cohesion: 0.18
Nodes (10): build, _buildRow, CartBillSummaryCard, couponDiscount, deliveryFee, grandTotal, handlingFee, itemTotal (+2 more)

### Community 162 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile, privacy_policy_screen.dart

### Community 164 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.07
Nodes (25): ../../../core/services/battery_optimization_service.dart, activeOrders, build, _buildLiveClock, _buildMetricItem, isPlayingAlarm, onMuteAlarm, pendingCount (+17 more)

### Community 165 - "Color"
Cohesion: 0.10
Nodes (19): Color, appliedCoupon, build, CartSavingsBanner, couponDiscount, freeDeliveryThreshold, onApplyCouponTap, onRemoveCouponTap (+11 more)

### Community 167 - "battery_optimization_service.dart"
Cohesion: 0.22
Nodes (8): dart:io, BatteryOptimizationService, markDismissed, _prefKeyDismissed, requestExemption, shouldShowPrompt, package:permission_handler/permission_handler.dart, static const String

### Community 169 - "cart_item_card.dart"
Cohesion: 0.25
Nodes (7): ../data/models/cart.dart, CartItem, build, CartItemCard, item, onDecrement, onIncrement

### Community 170 - "package:flutter/foundation.dart"
Cohesion: 0.25
Nodes (7): AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp, logger_service.dart, package:flutter/foundation.dart

### Community 171 - "Map"
Cohesion: 0.12
Nodes (15): CachedMapTileProvider, customHeaders, getImage, build, _buildNetworkFallback, categories, categoryAssetMap, CategoryBentoGrid (+7 more)

### Community 174 - "State"
Cohesion: 0.21
Nodes (13): SplashScreen, _DeliveryPaymentSheet, _DeliveryPaymentSheetState, LiveGpsRouteCard, _LiveGpsRouteCardState, ShimmerBox, _ShimmerBoxState, VoiceSearchSheet (+5 more)

## Knowledge Gaps
- **3004 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+2999 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `StoreHub` connect `store_hub.dart` to `store_hub_provider.dart`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `dioProvider` connect `dioProvider` to `orders_screen.dart`, `add_review_screen.dart`, `cart_screen.dart`, `_DeliveryDashboardState`, `dart:async`, `cartProvider`, `floating_order_tracking_bar.dart`, `main_shell.dart`, `otp_screen.dart`, `storeSettingsProvider`, `login_screen.dart`, `admin_login.dart`, `order_success_screen.dart`, `admin_products.dart`, `static const Color`, `auth/delivery_login.dart`, `order_edit_modal.dart`, `admin_dashboard.dart`, `categoriesProvider`, `picker_dashboard.dart`, `add_picker_product_modal.dart`, `add_restaurant_product_modal.dart`, `notifications_screen.dart`, `ConsumerState`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `authProvider` connect `ConsumerState` to `auth_provider.dart`, `orders_screen.dart`, `admin_login.dart`, `doorstep_details_screen.dart`, `_DeliveryDashboardState`, `cartProvider`, `storeSettingsProvider`, `FadeSlideRoute`, `static const Color`, `auth/delivery_login.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _3004 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009852216748768473 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02702702702702703 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._