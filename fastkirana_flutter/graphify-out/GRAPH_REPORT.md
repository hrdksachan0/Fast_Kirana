# Graph Report - fastkirana_flutter  (2026-09-13)

## Corpus Check
- 216 files · ~701,343 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3783 nodes · 6012 edges · 164 communities (156 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `85de9299`
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
- brand_input.dart
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
- floating_order_tracking_bar.dart
- main_shell.dart
- otp_screen.dart
- address_provider.dart
- ConsumerWidget
- dynamic_hero_banner_carousel.dart
- login_screen.dart
- categories_screen.dart
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
- package:flutter_riverpod/flutter_riverpod.dart
- State
- onboarding_screen.dart
- splash/splash_screen.dart
- @JsonSerializable
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
- add_review_screen.dart
- selectedAddressProvider
- auth/delivery_login.dart
- restaurant_login.dart
- delivery/delivery_login.dart
- settings_screen.dart
- about_screen.dart
- order_edit_modal.dart
- admin_dashboard.dart
- api_endpoints.dart
- List
- brand_button.dart
- FadeSlideRoute
- contextual_brand_transition_screen.dart
- admin_settings.dart
- package:shared_preferences/shared_preferences.dart
- order_tracking_screen.dart
- rider_card.dart
- ConsumerState
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
- widgets.dart
- delivery_header.dart
- package:dio/dio.dart
- main.dart
- delivery_location_screen.dart
- cart_conflict_dialog.dart
- delivery_theme.dart
- live_gps_route_card.dart
- restaurant_delivery_loading_screen.dart
- restaurant_sales_report_tab.dart
- grocery_delivery_loading_screen.dart
- banner_provider.dart
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
- authProvider
- tracking_map.dart
- offline_cart_sync_test.dart
- address_selector_sheet.dart
- ../core/routes/page_transitions.dart
- app_toast.dart
- brand_card.dart
- package:flutter/services.dart
- logger_service.dart
- restaurant_menu_catalog_tab.dart
- ConsumerStatefulWidget
- DateTime?
- String?
- shimmer_box.dart
- storeSettingsProvider
- store_hub_provider.dart
- order_alarm_service.dart
- store_hub.dart
- offline_banner.dart
- AsyncValue
- _RestaurantsListScreenState
- unserviceable_location_banner.dart
- dart:convert
- currentUserProvider
- banner_repository.dart
- _CategoryChipsDelegate
- Color?
- restaurants_list_screen.dart
- @gmail
- variant_selector_sheet.dart
- package:flutter_bounceable/flutter_bounceable.dart
- ../providers/address_provider.dart
- admin_coupon_detail.dart
- package:flutter/foundation.dart
- dart:async
- delivery_profile.dart
- MaterialPageRoute
- firebaseMessagingBackgroundHandler
- Product
- _ProductEditBottomSheetState
- _DoorstepCashfreeQrSheetState

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 83 edges
2. `cartProvider` - 45 edges
3. `authProvider` - 36 edges
4. `FadeSlideRoute` - 34 edges
5. `selectedAddressProvider` - 27 edges
6. `categoriesProvider` - 27 edges
7. `storeSettingsProvider` - 24 edges
8. `addressesProvider` - 22 edges
9. `RecognitionListener` - 13 edges
10. `_HomeScreenState` - 13 edges

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

## Communities (164 total, 8 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (192): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+184 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.03
Nodes (75): ../../core/network/network_retry_helper.dart, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, _availableOutlets, bgMain, brandAmber (+67 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.03
Nodes (60): CFPaymentGatewayService, ../checkout/order_success_screen.dart, ../../core/services/kot_print_service.dart, brandGreen, _buildBillRow, _buildBillSummary, _buildBottomProceedBar, _buildCartItemsReview (+52 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.04
Nodes (51): , ../categories/category_products_screen.dart, _buildActiveDeliveryTracker, _buildCategoryAvatarImage, _buildCategoryFallback, _buildCategoryToggle, _buildFoodGreetingBanner, _buildFooter (+43 more)

### Community 4 - "restaurant_provider.dart"
Cohesion: 0.09
Nodes (22): ../data/repositories/restaurant_repository.dart, _buildDarkstoreRecommendationsSection, address, cuisine, distanceMeters, getDarkstoreAddonRecommendations, getRestaurantDistanceKm, getRestaurantMenu (+14 more)

### Community 5 - "order.dart"
Cohesion: 0.03
Nodes (60): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, addressRaw, cancelled, card, combinedId, confirmedAt (+52 more)

### Community 6 - "product.dart"
Cohesion: 0.04
Nodes (51): address, availableEndTime, availableStartTime, bannerUrl, barcode, category, categoryId, CategoryInfo (+43 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.11
Nodes (18): ../cart/cart_screen.dart, _buildEmptyState, _buildSearchBox, _buildSegmentedTabs, _buildStatusFilterPills, createState, dispose, OrderCardSkeleton (+10 more)

### Community 8 - "brand_input.dart"
Cohesion: 0.14
Nodes (13): IconData?, BrandInput, build, controller, hint, keyboardType, label, obscure (+5 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.07
Nodes (28): _cachedRefreshToken, _cachedToken, _cachedUserData, _cachedUserEmail, _cachedUserId, _cachedUserName, _cachedUserPhone, _cachedUserRole (+20 more)

### Community 10 - "product_card.dart"
Cohesion: 0.04
Nodes (55): ../features/products/product_detail_screen.dart, Gradient, _addButton, bestseller, child, createState, discount, _emoji (+47 more)

### Community 11 - "add_item_search_sheet.dart"
Cohesion: 0.09
Nodes (23): ../../../core/utils/app_toast.dart, AddItemSearchSheet, _AddItemSearchSheetState, _adminCatalogFilter, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, createState (+15 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.06
Nodes (34): AndroidFlutterLocalNotificationsPlugin, dart:typed_data, body, clearAllNotifications, data, getFcmToken, getNotificationPreferences, _handleForegroundMessage (+26 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.03
Nodes (57): _activeCategoryTag, _buildCategories, _buildCategoryThumbnail, _buildDishImage, _buildFallbackBanner, _buildFallbackLogo, _buildLocalAssetOrEmoji, _buildLogoWidget (+49 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.06
Nodes (32): ../checkout/checkout_screen.dart, coupons_screen.dart, _appliedCoupon, _applyCoupon, brandGreen, _buildBillDetailsCard, _buildBillRow, _buildCancellationPolicy (+24 more)

### Community 15 - "cart.dart"
Cohesion: 0.09
Nodes (22): appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items, lineTotal (+14 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.08
Nodes (25): activeOrdersCount, address, bannerUrl, city, cuisineTags, deliveryTime, description, discountBadge (+17 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (20): ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds, filteredUpsells (+12 more)

### Community 18 - "cartProvider"
Cohesion: 0.12
Nodes (19): _buildDishAddButton, _handleDishAddToCart, _handleDishIncrement, build, _buildCartErrorState, _buildCartItemCard, _buildCartScreenContent, CartScreen (+11 more)

### Community 19 - "subscription_screen.dart"
Cohesion: 0.15
Nodes (13): _availableCatalog, brandGreen, build, createState, primaryRed, _showNewSubscriptionModal, _skipTomorrow, slateDark (+5 more)

### Community 20 - "user.dart"
Cohesion: 0.08
Nodes (25): assignedRestaurantId, blockReason, createdAt, email, hashCode, id, image, isBlocked (+17 more)

### Community 21 - "floating_order_tracking_bar.dart"
Cohesion: 0.04
Nodes (45): Exception, ../../features/auth/admin_login.dart, ../../features/auth/delivery_login.dart, ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cafe/restaurant_dashboard.dart, ../../features/categories/categories_screen.dart, ../../features/checkout/checkout_screen.dart (+37 more)

### Community 22 - "main_shell.dart"
Cohesion: 0.10
Nodes (23): ../categories/categories_screen.dart, ../delivery/picker_dashboard.dart, home_screen.dart, _buildCircularCategoryCarousel, _buildTopCategoriesGrid, _autoShowTimer, build, _buildLiquidBottomNav (+15 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.07
Nodes (26): build, _checkClipboard, _clipboardOtp, _controllers, createState, _currentOtp, didChangeAppLifecycleState, dispose (+18 more)

### Community 24 - "address_provider.dart"
Cohesion: 0.15
Nodes (12): ../data/repositories/address_repository.dart, AddressRepository, addAddress, addressesAsync, clear, deleteAddress, loadAddresses, notifier (+4 more)

### Community 25 - "ConsumerWidget"
Cohesion: 0.12
Nodes (20): ConsumerWidget, build, ordersProvider, OrdersScreen, _OrdersScreenState, ProductsScreen, build, ProfileScreen (+12 more)

### Community 26 - "dynamic_hero_banner_carousel.dart"
Cohesion: 0.09
Nodes (21): ../features/categories/category_products_screen.dart, _autoSlideTimer, _buildBannerCard, _buildShimmerPlaceholder, createState, _currentPage, dispose, DynamicHeroBannerCarousel (+13 more)

### Community 27 - "login_screen.dart"
Cohesion: 0.10
Nodes (19): build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleSkipGuest, initState (+11 more)

### Community 28 - "categories_screen.dart"
Cohesion: 0.10
Nodes (18): category_products_screen.dart, ../data/models/category.dart, build, _categories, CategoriesScreen, build, _buildReferenceCategoryCard, CategoriesScreen (+10 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.07
Nodes (33): ../core/theme/design_system.dart, AdminBannersScreen, build, AdminCustomersScreen, build, AdminReportsScreen, _breakdownRow, build (+25 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.08
Nodes (24): FocusNode, _buildFilterPill, category, CategoryProductsScreen, createState, dispose, emoji, id (+16 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.09
Nodes (23): address_book_screen.dart, ../auth/login_screen.dart, ../../data/repositories/auth_repository.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader (+15 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.07
Nodes (31): ResponsiveContainer, AppShimmer, build, child, count, OrderCardShimmer, ProductCardShimmer, ProductGridShimmer (+23 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.03
Nodes (67): ../common/widgets/battery_optimization_dialog.dart, ../../core/services/offline_sync_service.dart, ../../core/services/order_alarm_service.dart, ../delivery/widgets/connectivity_banner.dart, AdminOrdersScreen, _AdminOrdersScreenState, _allOrders, _assignedStoreId (+59 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.08
Nodes (28): ../data/models/coupon.dart, ../data/repositories/coupon_repository.dart, CouponRepository, AdminCouponsScreen, build, _applyCode, build, _buildCouponCard (+20 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (38): _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField, _buildInteractiveMapPinboard, _buildStickyBottomBar (+30 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.08
Nodes (24): _buildFoodRestaurantListing, build, _buildSearchResults, _buildShimmerGrid, _clearRecentSearches, _controller, createState, _debounce (+16 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.10
Nodes (19): ../core/utils/dish_timing.dart, ProductVariant, _buildQualityRow, createState, initState, _isFavorite, _isNotified, primaryRed (+11 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.08
Nodes (27): @freezed, Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl (+19 more)

### Community 40 - "coupon.dart"
Cohesion: 0.08
Nodes (24): Coupon, categoryId, code, expiresAt, hashCode, id, isActive, maxDiscount (+16 more)

### Community 41 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (29): address_provider.dart, ../admin/admin_dashboard.dart, cart_provider.dart, ../core/network/api_client.dart, ../core/services/secure_storage_service.dart, ../data/models/user.dart, build, createState (+21 more)

### Community 42 - "State"
Cohesion: 0.14
Nodes (20): ContextualBrandTransitionScreen, _ContextualBrandTransitionScreenState, SplashScreen, _SplashScreenState, RestaurantDeliveryLoadingScreen, _RestaurantDeliveryLoadingScreenState, _DeliveryPaymentSheet, _DeliveryPaymentSheetState (+12 more)

### Community 43 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 44 - "splash/splash_screen.dart"
Cohesion: 0.08
Nodes (23): Animation, AnimationController, ../core/services/notification_service.dart, build, _controller, createState, dispose, _fadeAnimation (+15 more)

### Community 45 - "@JsonSerializable"
Cohesion: 0.25
Nodes (8): @JsonSerializable, _, Cart, CartItem, _, Order, OrderItem, AuthResponse

### Community 46 - "admin_authorization.dart"
Cohesion: 0.17
Nodes (11): AdminAuthorization, buildStaffHeaders, currentStaffHeaders, isAdmin, isStaff, options, staffRoles, withStaffAuth (+3 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.14
Nodes (14): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, _bundledCategoryAssets (+6 more)

### Community 48 - "banner.dart"
Cohesion: 0.06
Nodes (30): Banner, hashCode, operator, _privateConstructorUsedError, toString, code, Banner, fromJson (+22 more)

### Community 49 - "order_success_screen.dart"
Cohesion: 0.06
Nodes (34): ConfettiController, _animController, _buildDetailRow, _buildProgressLine, _buildProgressStep, _buttonsFadeAnim, _buttonsSlideAnim, _checkScaleAnim (+26 more)

### Community 50 - "admin_products.dart"
Cohesion: 0.04
Nodes (45): _addVariant, _buildCategoryChip, _buildGroceryCategoryChips, _buildMiniInput, _buildProductAdminCard, _buildRestaurantOutletChips, _buildSectionTitle, _buildSegmentButton (+37 more)

### Community 51 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "product_repository.dart"
Cohesion: 0.06
Nodes (31): _cachedCategories, _cachedProducts, _cacheKey, _cacheTTLMinutes, _categoryAliases, dio, _diskCategoriesKey, _diskCategoryTimestampKey (+23 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.11
Nodes (17): AuthRepository, dio, getProfile, _handleError, login, _parseSessionResponse, sendEmailOtp, sendOtp (+9 more)

### Community 54 - "../data/models/product.dart"
Cohesion: 0.13
Nodes (14): ../../core/widgets/loading_widgets.dart, ../data/models/product.dart, ../data/repositories/product_repository.dart, build, ComboBuilderScreen, build, productsProvider, build (+6 more)

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
Nodes (97): ../../core/services/rider_location_service.dart, _activeTab, _assignedStoreId, _assignedStoreName, _audioPlayer, _autoRefreshTimer, bgMain, borderCol (+89 more)

### Community 59 - "add_review_screen.dart"
Cohesion: 0.17
Nodes (12): AddReviewScreen, _AddReviewScreenState, build, createState, dispose, _isSubmitting, productName, _rating (+4 more)

### Community 60 - "selectedAddressProvider"
Cohesion: 0.12
Nodes (28): bootstrapUserLocation, LocationService, build, _buildScrollableAddressSection, CheckoutScreen, _CheckoutScreenState, _fetchAndApplyCurrentLocation, _handlePlaceOrder (+20 more)

### Community 61 - "auth/delivery_login.dart"
Cohesion: 0.12
Nodes (15): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, DeliveryLoginScreen, dispose, _errorMessage, _handlePasswordLogin (+7 more)

### Community 62 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "delivery/delivery_login.dart"
Cohesion: 0.12
Nodes (14): delivery_dashboard.dart, build, RestaurantOrderQueueScreen, build, createState, DeliveryLoginScreen, _isLoading, _otpController (+6 more)

### Community 64 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile, privacy_policy_screen.dart

### Community 65 - "about_screen.dart"
Cohesion: 0.33
Nodes (5): AboutScreen, build, _divider, _linkItem, _statBox

### Community 66 - "order_edit_modal.dart"
Cohesion: 0.07
Nodes (28): ../../core/services/admin_notification_service.dart, brandAmber, brandGreen, build, _calculateSubtotal, createState, initState, isAdmin (+20 more)

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.09
Nodes (23): admin_orders_list.dart, admin_products.dart, AdminDashboard, _AdminDashboardState, _buildDockItem, _buildOutletTile, createState, _currentIndex (+15 more)

### Community 68 - "api_endpoints.dart"
Cohesion: 0.10
Nodes (20): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+12 more)

### Community 69 - "List"
Cohesion: 0.33
Nodes (6): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState, List

### Community 70 - "brand_button.dart"
Cohesion: 0.12
Nodes (16): double?, backgroundColor, borderRadius, BrandButton, build, fontSize, fullWidth, gradientEnd (+8 more)

### Community 71 - "FadeSlideRoute"
Cohesion: 0.12
Nodes (17): FadeSlideRoute, deliveryTierProvider, _handleContinue, _buildMenuTab, _buildRestaurantDishItem, _buildReviewsTab, build, _buildEndOfAisleSearchCard (+9 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.06
Nodes (39): CustomPainter, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter, _CafeFrontPainter (+31 more)

### Community 73 - "admin_settings.dart"
Cohesion: 0.40
Nodes (4): AdminSettingsScreen, build, _divider, _switchTile

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.08
Nodes (24): package:fastkirana_flutter/core/config/app_config.dart, package:fastkirana_flutter/core/services/biometric_service.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/data/models/order.dart, package:fastkirana_flutter/data/models/restaurant.dart, package:fastkirana_flutter/data/models/user.dart (+16 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.02
Nodes (96): BitmapDescriptor?, GoogleMapController?, activeColor, _audioPlayer, brandGreen, _buildCancelledOrderCard, _buildDeliveryDestinationCard, _buildGoogleMapsCard (+88 more)

### Community 76 - "rider_card.dart"
Cohesion: 0.22
Nodes (8): build, deliveryOtp, _makeCall, RiderCard, riderName, riderPhone, riderRating, vehicleNumber

### Community 77 - "ConsumerState"
Cohesion: 0.15
Nodes (25): CategoriesScreen, ConsumerState, _AdminProductsScreenState, build, _AddRestaurantProductModalState, _CategoriesScreenState, build, _CategoryProductsScreenState (+17 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (36): BuildContext, EdgeInsetsGeometry, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+28 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.05
Nodes (39): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+31 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.07
Nodes (29): doorstep_details_screen.dart, _areaName, build, _calculateDistance, createState, _currentLat, _currentLng, dispose (+21 more)

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.06
Nodes (34): ../common/order_edit_modal.dart, _autoRefreshTimer, bgMain, brandGreen, brandOrange, build, _buildEmptyState, _buildMetricStrip (+26 more)

### Community 82 - "location_service.dart"
Cohesion: 0.06
Nodes (32): area, baseFee, cart, city, deliveryFee, DeliveryTierInfo, distanceKm, feeDescription (+24 more)

### Community 83 - "RecognitionListener"
Cohesion: 0.14
Nodes (9): MainActivity, RecognitionListener, Bundle, ByteArray, FlutterActivity, FlutterEngine, Intent, MethodChannel (+1 more)

### Community 84 - "restaurant_utils.dart"
Cohesion: 0.06
Nodes (34): address, asRestaurantLocation, balUdyanLocation, categorySlug, darkstoreLocation, false, getOutletLocation, getOutletName (+26 more)

### Community 85 - "FastKirana Flutter"
Cohesion: 0.15
Nodes (12): Architecture, Backend, Development, FastKirana Flutter, Getting Started, License, Prerequisites, Project Context (+4 more)

### Community 86 - "add_picker_product_modal.dart"
Cohesion: 0.07
Nodes (29): class, FormState, _barcodeController, brandGreen, brandOrange, build, _commonUnits, createState (+21 more)

### Community 89 - "add_restaurant_product_modal.dart"
Cohesion: 0.06
Nodes (30): build, _buildFoodTypeOption, createState, _descriptionController, dispose, _fetchRestaurantSections, _formKey, _imageUrlController (+22 more)

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
Cohesion: 0.07
Nodes (26): Cart? get, ../data/models/cart.dart, ../data/repositories/cart_repository.dart, addItem, addProduct, _buildCart, _cart, cartRepoProvider (+18 more)

### Community 95 - "app_config.dart"
Cohesion: 0.07
Nodes (29): apiBaseUrl, AppConfig, appIconAsset, appName, appVersion, buildFlavor, buildNumber, cashfreeAppId (+21 more)

### Community 96 - "dioProvider"
Cohesion: 0.07
Nodes (28): dioProvider, _assignRider, _fetchAdminOrders, _fetchAdminProfile, _fetchDeliveryRiders, _flushOfflineAdminQueue, _initNotificationSubscriptions, _sendRemoteKOT (+20 more)

### Community 97 - "address.dart"
Cohesion: 0.09
Nodes (21): area, city, hashCode, houseNo, id, isDefault, label, latitude (+13 more)

### Community 98 - "lib/widgets/empty_state.dart"
Cohesion: 0.09
Nodes (21): bgTint, build, ctaColor, ctaLabel, emoji, emptyCart, EmptyState, icon (+13 more)

### Community 99 - "widgets.dart"
Cohesion: 0.17
Nodes (11): empty_state.dart, widgets, library, loading_widgets.dart, retry_wrapper.dart, section_header.dart, ../../widgets/brand_card.dart, ../../widgets/brand_input.dart (+3 more)

### Community 100 - "delivery_header.dart"
Cohesion: 0.10
Nodes (20): activeTab, build, DeliveryHeader, _greeting, _greetingText, isDarkMode, isOnline, onBack (+12 more)

### Community 101 - "package:dio/dio.dart"
Cohesion: 0.07
Nodes (30): Completer, ../config/app_config.dart, ../data/repositories/wishlist_repository.dart, Dio, int?, dio, _isRefreshingToken, message (+22 more)

### Community 102 - "main.dart"
Cohesion: 0.17
Nodes (11): core/routes/app_router.dart, core/services/deep_link_service.dart, ../core/services/supabase_service.dart, core/theme/app_theme.dart, firebase_options.dart, build, FastKiranaApp, main (+3 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (19): ../home/main_shell.dart, autoFetchLocation, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose, _getAddressIcon (+11 more)

### Community 104 - "cart_conflict_dialog.dart"
Cohesion: 0.10
Nodes (18): build, CartConflictDialog, existingOutletName, groceryItemsCount, onCancel, onConfirm, product, show (+10 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.11
Nodes (19): build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, initState, isDelivered (+11 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (18): dart:ui, autoDismissDuration, build, _buildFoodIllustration, createState, dispose, _fadeAnim, _fadeController (+10 more)

### Community 108 - "restaurant_sales_report_tab.dart"
Cohesion: 0.11
Nodes (19): brandGreen, build, _buildSummaryRow, commissionRate, createState, _customEndDate, _customStartDate, _onPeriodTap (+11 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (17): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+9 more)

### Community 110 - "banner_provider.dart"
Cohesion: 0.17
Nodes (11): ../data/models/banner.dart, ../data/repositories/banner_repository.dart, BannerRepository, build, bannerRepositoryProvider, bannersProvider, getBanners, repo (+3 more)

### Community 111 - "privacy_policy_screen.dart"
Cohesion: 0.09
Nodes (19): design_system.dart, AppTheme, _pageTransitionsTheme, build, _buildCard, _buildParagraph, _buildSection, _bullet (+11 more)

### Community 112 - "page_transitions.dart"
Cohesion: 0.17
Nodes (17): Duration?, FadeScaleRoute, FadeThroughRoute, FastKiranaPageTransitionsBuilder, page, SharedAxisRoute, SwiggyModalRoute, transitionDurationOverride (+9 more)

### Community 113 - "order_detail_screen.dart"
Cohesion: 0.12
Nodes (16): build, _buildBillRow, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor, _getStatusStepIndex, _makeCall (+8 more)

### Community 114 - "live_clock_badge.dart"
Cohesion: 0.12
Nodes (16): backgroundColor, borderColor, build, createState, dispose, fontSize, _formatTime, iconColor (+8 more)

### Community 115 - "voice_search_sheet.dart"
Cohesion: 0.12
Nodes (17): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+9 more)

### Community 116 - "../core/theme/responsive.dart"
Cohesion: 0.07
Nodes (31): ../core/theme/responsive.dart, AddressCard, build, fullAddress, isSelected, label, onTap, build (+23 more)

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
Cohesion: 0.07
Nodes (26): extractRestaurantItems, formatKOTDate, generateKOTPdfDocument, KotPrintService, printKOTReceipt, _recentPrintTimestamps, sendRemoteKOTToKitchen, shareKOTReceipt (+18 more)

### Community 121 - "deep_link_service.dart"
Cohesion: 0.11
Nodes (18): AppLinks, _appLinks, DeepLinkService, dispose, _handleDeepLink, init, instance, _isInitialized (+10 more)

### Community 122 - "authProvider"
Cohesion: 0.10
Nodes (22): DeliveryLoginScreen, _handleLogout, AdminLoginScreen, _AdminLoginScreenState, _DeliveryLoginScreenState, _handleVerifyOtp, OtpScreen, _OtpScreenState (+14 more)

### Community 123 - "tracking_map.dart"
Cohesion: 0.17
Nodes (11): LatLng, build, initialPosition, markers, onRecenter, polylines, TrackingMap, OneSequenceGestureRecognizer (+3 more)

### Community 124 - "offline_cart_sync_test.dart"
Cohesion: 0.13
Nodes (16): CartRepository, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/cart.dart, package:fastkirana_flutter/data/models/product.dart, package:fastkirana_flutter/data/repositories/cart_repository.dart, package:fastkirana_flutter/providers/cart_provider.dart, main, main (+8 more)

### Community 125 - "address_selector_sheet.dart"
Cohesion: 0.12
Nodes (15): Address?, ../core/config/app_config.dart, _Address, build, currentUserIdProvider, activeAddress, AddressSelectorSheet, createState (+7 more)

### Community 126 - "../core/routes/page_transitions.dart"
Cohesion: 0.33
Nodes (5): ../core/routes/page_transitions.dart, ../features/cart/cart_screen.dart, bottomOffset, createState, _isPressed

### Community 127 - "app_toast.dart"
Cohesion: 0.25
Nodes (7): AppToast, _show, showError, showInfo, showSuccess, showWarning, ToastType

### Community 128 - "brand_card.dart"
Cohesion: 0.20
Nodes (9): EdgeInsets?, BrandCard, build, child, elevated, margin, onTap, padding (+1 more)

### Community 129 - "package:flutter/services.dart"
Cohesion: 0.14
Nodes (12): _auth, authenticate, BiometricService, getAvailableBiometrics, isBiometricAvailable, build, _statItem, _stepCard (+4 more)

### Community 130 - "logger_service.dart"
Cohesion: 0.22
Nodes (8): debug, error, info, _logger, LoggerService, warning, package:logger/logger.dart, static final Logger

### Community 131 - "restaurant_menu_catalog_tab.dart"
Cohesion: 0.11
Nodes (18): bgMain, brandGreen, build, _buildMenuFilterChip, createState, dispose, menuItems, _menuSearchController (+10 more)

### Community 132 - "ConsumerStatefulWidget"
Cohesion: 0.12
Nodes (21): ConsumerStatefulWidget, AdminProductsScreen, LoginScreen, _LoginScreenState, CafeMenuScreen, _CafeMenuScreenState, AddRestaurantProductModal, OrderSuccessScreen (+13 more)

### Community 133 - "DateTime?"
Cohesion: 0.25
Nodes (7): DateTime?, build, createdAt, currentStatus, estimatedDelivery, _getStepIndex, StepperCard

### Community 134 - "String?"
Cohesion: 0.12
Nodes (14): checkDishTimeAvailability, DishTimingStatus, formattedTimeSlot, formatTime12h, isAvailableNow, nextAvailableTimeStr, actionLabel, build (+6 more)

### Community 135 - "shimmer_box.dart"
Cohesion: 0.12
Nodes (16): BorderRadius?, BoxShape, BannerSkeleton, borderRadius, build, CategorySkeleton, _controller, createState (+8 more)

### Community 136 - "storeSettingsProvider"
Cohesion: 0.11
Nodes (19): ../data/models/store_settings.dart, _loadSettings, _buildAdminOrderCard, _buildBottomCheckoutBar, _fetchQrData, _buildTrustBadgeStrip, build, ProductDetailScreen (+11 more)

### Community 137 - "store_hub_provider.dart"
Cohesion: 0.12
Nodes (16): ../data/models/store_hub.dart, activeStoreHubsProvider, address, customerLat, customerLng, distanceKm, hub, hubs (+8 more)

### Community 138 - "order_alarm_service.dart"
Cohesion: 0.08
Nodes (24): AudioPlayer, ../data/models/order.dart, AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp, _activeOrderId (+16 more)

### Community 139 - "store_hub.dart"
Cohesion: 0.13
Nodes (14): city, defaultGhatampur, deliveryRadiusKm, fromJson, groceryOpen, id, isActive, latitude (+6 more)

### Community 140 - "offline_banner.dart"
Cohesion: 0.16
Nodes (13): ../core/utils/app_connectivity.dart, connectivityProvider, build, createState, dispose, OfflineBanner, _OfflineBannerState, offlineText (+5 more)

### Community 141 - "AsyncValue"
Cohesion: 0.47
Nodes (6): AsyncValue, AddressesNotifier, AuthNotifier, CartNotifier, WishlistNotifier, StateNotifier

### Community 142 - "_RestaurantsListScreenState"
Cohesion: 0.22
Nodes (14): build, build, _centerCategoryInHorizontalBar, build, _RestaurantsListScreenState, filteredRestaurantsProvider, offersFilterProvider, pureVegFilterProvider (+6 more)

### Community 143 - "unserviceable_location_banner.dart"
Cohesion: 0.18
Nodes (11): ../core/services/location_service.dart, ../features/location/delivery_location_screen.dart, createState, dispose, distanceKm, _isNotified, _phoneController, showUnserviceableModal (+3 more)

### Community 144 - "dart:convert"
Cohesion: 0.10
Nodes (19): dart:convert, dart:io, BatteryOptimizationService, markDismissed, _prefKeyDismissed, requestExemption, shouldShowPrompt, clearQueue (+11 more)

### Community 146 - "banner_repository.dart"
Cohesion: 0.17
Nodes (11): defaultBanners, dio, _diskBannersKey, _fetchFromNetwork, getBanners, _inMemoryBanners, _loadBannersFromDisk, _saveBannersToDisk (+3 more)

### Community 148 - "Color?"
Cohesion: 0.18
Nodes (10): Color?, BrandLogo, build, FastKiranaLogoPainter, FastKiranaLogoWidget, paint, shouldRepaint, size (+2 more)

### Community 149 - "restaurants_list_screen.dart"
Cohesion: 0.18
Nodes (10): _buildFilterPill, createState, _cuisineCategories, dispose, RestaurantsListScreen, _searchController, static const List, ../../widgets/floating_cart_bar.dart (+2 more)

### Community 152 - "variant_selector_sheet.dart"
Cohesion: 0.25
Nodes (7): cart_conflict_dialog.dart, ../core/utils/restaurant_utils.dart, build, _buildVariantRow, product, show, ../providers/store_settings_provider.dart

### Community 153 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.25
Nodes (7): ../../../core/services/battery_optimization_service.dart, BatteryOptimizationDialog, build, _buildStepRow, onDismissed, showIfNecessary, package:flutter_bounceable/flutter_bounceable.dart

### Community 154 - "../providers/address_provider.dart"
Cohesion: 0.29
Nodes (7): ../data/models/address.dart, AddressesScreen, build, _buildAddressCard, _iconForLabel, addressRepositoryProvider, ../providers/address_provider.dart

### Community 155 - "admin_coupon_detail.dart"
Cohesion: 0.29
Nodes (7): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive

### Community 156 - "package:flutter/foundation.dart"
Cohesion: 0.25
Nodes (7): android, DefaultFirebaseOptions, ios, web, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 157 - "dart:async"
Cohesion: 0.40
Nodes (4): dart:async, dart:math, NetworkRetryHelper, ../services/logger_service.dart

### Community 158 - "delivery_profile.dart"
Cohesion: 0.40
Nodes (4): build, DeliveryProfileScreen, _divider, _menuTile

### Community 159 - "MaterialPageRoute"
Cohesion: 0.40
Nodes (5): _buildPayOnlineCard, _buildReviewCard, build, build, MaterialPageRoute

## Knowledge Gaps
- **2665 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+2660 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `StoreHub` connect `store_hub.dart` to `store_hub_provider.dart`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `_CategoryChipsDelegate` connect `_CategoryChipsDelegate` to `cafe_menu_screen.dart`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _2665 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.010362694300518135 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03278688524590164 - nodes in this community are weakly interconnected._
- **Should `home_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._