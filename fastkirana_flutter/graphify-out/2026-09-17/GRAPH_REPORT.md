# Graph Report - fastkirana_flutter  (2026-09-17)

## Corpus Check
- 235 files · ~711,572 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4031 nodes · 6401 edges · 175 communities (170 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `89581fa0`
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
- SingleTickerProviderStateMixin
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
- address_repository.dart
- delivery_dashboard.dart
- FadeSlideRoute
- static const Color
- auth/delivery_login.dart
- restaurant_login.dart
- delivery/delivery_login.dart
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
- rider_card.dart
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
- widgets.dart
- package:flutter_bounceable/flutter_bounceable.dart
- package:fastkirana_flutter/core/services/logger_service.dart
- main.dart
- delivery_location_screen.dart
- cart_conflict_dialog.dart
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
- ../../core/services/logger_service.dart
- app_connectivity.dart
- validators.dart
- kot_print_service.dart
- deep_link_service.dart
- ConsumerState
- tracking_map.dart
- package:dio/dio.dart
- address_selector_sheet.dart
- floating_cart_bar.dart
- banner_repository.dart
- grid_skeletons.dart
- biometric_service.dart
- logger_service.dart
- restaurant_menu_catalog_tab.dart
- _CafeMenuScreenState
- DateTime?
- String?
- app_errors.dart
- package:flutter_riverpod/flutter_riverpod.dart
- store_hub_provider.dart
- order_alarm_service.dart
- store_hub.dart
- offline_banner.dart
- AsyncValue
- restaurants_list_screen.dart
- unserviceable_location_banner.dart
- dart:convert
- _DeliveryDashboardState
- supabase_service.dart
- _CategoryChipsDelegate
- auth_provider.dart
- floating_order_tracking_bar.dart
- @gmail
- app_flavor.dart
- brand_logo.dart
- location_drift_sheet.dart
- api_client.dart
- wishlist_screen.dart
- dart:async
- core/widgets/empty_state.dart
- admin_coupon_detail.dart
- cart_bill_summary_card.dart
- package:flutter/services.dart
- settings_screen.dart
- about_screen.dart
- restaurant_order_card_view.dart
- Color?
- sponsored_ad_card.dart
- battery_optimization_service.dart
- retry_wrapper.dart
- cart_item_card.dart
- ../data/models/order.dart
- package:cached_network_image/cached_network_image.dart
- _DoorstepCashfreeQrSheetState
- _DeliveryPaymentSheet
- State

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 91 edges
2. `cartProvider` - 40 edges
3. `authProvider` - 35 edges
4. `FadeSlideRoute` - 33 edges
5. `selectedAddressProvider` - 28 edges
6. `categoriesProvider` - 27 edges
7. `storeSettingsProvider` - 23 edges
8. `addressesProvider` - 21 edges
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

## Communities (175 total, 5 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (202): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+194 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.03
Nodes (74): ../../core/network/network_retry_helper.dart, ../../core/services/kot_print_service.dart, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, bgMain, brandAmber (+66 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.04
Nodes (51): CFPaymentGatewayService, ../checkout/order_success_screen.dart, _buildBottomProceedBar, _buildCartItemsReview, _buildPlacingOrderOverlay, _buildReviewItemRow, _cfService, _completeOrderPlacement (+43 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.04
Nodes (51): ../categories/category_products_screen.dart, _buildActiveDeliveryTracker, _buildCategoryAvatarImage, _buildCategoryFallback, _buildCategoryToggle, _buildFoodGreetingBanner, _buildFooter, _buildHorizontalProductSection (+43 more)

### Community 4 - "restaurant_provider.dart"
Cohesion: 0.09
Nodes (28): ../data/repositories/restaurant_repository.dart, build, _RestaurantsListScreenState, address, cuisine, distanceMeters, filteredRestaurantsProvider, getDarkstoreAddonRecommendations (+20 more)

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
Cohesion: 0.09
Nodes (22): build, _buildEmptyState, _buildSearchBox, _buildSegmentedTabs, _buildStatusFilterPills, createState, dispose, OrderCardSkeleton (+14 more)

### Community 8 - "kitchen_order.dart"
Cohesion: 0.05
Nodes (37): cookingInstruction, createdAt, customerAddress, customerName, customerPhone, deliveryMethod, elapsedMinutes, fromJson (+29 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.07
Nodes (27): _cachedRefreshToken, _cachedToken, _cachedUserData, _cachedUserEmail, _cachedUserId, _cachedUserName, _cachedUserPhone, _cachedUserRole (+19 more)

### Community 10 - "product_card.dart"
Cohesion: 0.04
Nodes (52): ../features/products/product_detail_screen.dart, Gradient, _addButton, bestseller, child, createState, discount, _emoji (+44 more)

### Community 11 - "add_item_search_sheet.dart"
Cohesion: 0.09
Nodes (23): ../../../core/utils/app_toast.dart, AddItemSearchSheet, _AddItemSearchSheetState, _adminCatalogFilter, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, createState (+15 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.05
Nodes (43): AndroidFlutterLocalNotificationsPlugin, @pragma, dart:typed_data, body, clearAllNotifications, data, firebaseMessagingBackgroundHandler, getFcmToken (+35 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.04
Nodes (54): _activeCategoryTag, _buildCategories, _buildCategoryThumbnail, _buildFallbackBanner, _buildFallbackLogo, _buildLocalAssetOrEmoji, _buildLogoWidget, _buildRestaurantBanner (+46 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.06
Nodes (34): ../checkout/checkout_screen.dart, coupons_screen.dart, _appliedCoupon, _applyCoupon, brandGreen, _buildBillDetailsCard, _buildBillRow, _buildCancellationPolicy (+26 more)

### Community 15 - "cart.dart"
Cohesion: 0.09
Nodes (22): appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items, lineTotal (+14 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.07
Nodes (27): activeOrdersCount, address, bannerUrl, city, commissionRate, cuisineTags, deliveryTime, description (+19 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (20): ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds, filteredUpsells (+12 more)

### Community 18 - "cartProvider"
Cohesion: 0.11
Nodes (21): deliveryTierProvider, build, _buildCartErrorState, _buildCartItemCard, _buildCartScreenContent, CartScreen, _CartScreenState, _buildCompleteYourMealSection (+13 more)

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
Cohesion: 0.17
Nodes (11): ../data/repositories/address_repository.dart, AddressRepository, addAddress, addressesAsync, clear, deleteAddress, loadAddresses, notifier (+3 more)

### Community 25 - "storeSettingsProvider"
Cohesion: 0.12
Nodes (20): ConsumerWidget, _loadSettings, _buildAdminOrderCard, _buildBottomCheckoutBar, _handlePlaceOrder, _fetchQrData, build, ProfileScreen (+12 more)

### Community 26 - "dynamic_hero_banner_carousel.dart"
Cohesion: 0.05
Nodes (45): ../data/models/banner.dart, ../data/repositories/banner_repository.dart, ../features/categories/category_products_screen.dart, BannerRepository, build, AddReviewScreen, _AddReviewScreenState, build (+37 more)

### Community 27 - "login_screen.dart"
Cohesion: 0.12
Nodes (16): ../../data/repositories/auth_repository.dart, build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleSkipGuest (+8 more)

### Community 28 - "../core/routes/page_transitions.dart"
Cohesion: 0.12
Nodes (16): CategoriesScreen, category_products_screen.dart, ../core/routes/page_transitions.dart, ../data/models/category.dart, build, _categories, CategoriesScreen, build (+8 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (53): ../core/theme/design_system.dart, AdminBannersScreen, build, AdminCustomersScreen, build, AdminReportsScreen, _breakdownRow, build (+45 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.08
Nodes (23): FocusNode, _buildFilterPill, category, createState, dispose, emoji, id, imageUrl (+15 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.13
Nodes (14): address_book_screen.dart, ../auth/login_screen.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader, primaryRed (+6 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.08
Nodes (30): ResponsiveContainer, AppShimmer, build, child, count, OrderCardShimmer, ProductCardShimmer, ProductGridShimmer (+22 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.03
Nodes (70): ../common/widgets/battery_optimization_dialog.dart, ../../core/services/offline_sync_service.dart, ../../core/services/order_alarm_service.dart, ../delivery/widgets/connectivity_banner.dart, AdminOrdersScreen, _AdminOrdersScreenState, _allOrders, _assignedStoreId (+62 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.08
Nodes (28): ../data/models/coupon.dart, ../data/repositories/coupon_repository.dart, CouponRepository, AdminCouponsScreen, build, _applyCode, build, _buildCouponCard (+20 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (40): AddAddressScreen, _AddAddressScreenState, _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField (+32 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.08
Nodes (27): _buildFoodRestaurantListing, build, _buildSearchResults, _buildShimmerGrid, _clearRecentSearches, _controller, createState, _debounce (+19 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.13
Nodes (15): ../cart/cart_screen.dart, ../core/utils/dish_timing.dart, ProductVariant, _buildQualityRow, createState, initState, _isFavorite, _isNotified (+7 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.08
Nodes (27): @freezed, Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl (+19 more)

### Community 40 - "coupon.dart"
Cohesion: 0.08
Nodes (24): Coupon, categoryId, code, expiresAt, hashCode, id, isActive, maxDiscount (+16 more)

### Community 41 - "admin_login.dart"
Cohesion: 0.15
Nodes (12): ../admin/admin_dashboard.dart, ../data/models/user.dart, build, createState, dispose, _emailController, _errorMessage, _handleAdminLogin (+4 more)

### Community 42 - "SingleTickerProviderStateMixin"
Cohesion: 0.29
Nodes (7): _AnimatedStepNode, _AnimatedStepNodeState, OrderTrackingScreen, _OrderTrackingScreenState, _ShimmerBoxState, ShimmerBox, SingleTickerProviderStateMixin

### Community 43 - "onboarding_screen.dart"
Cohesion: 0.20
Nodes (9): build, createState, _currentPage, dispose, _navigateToLogin, _pageController, _pages, login_screen.dart (+1 more)

### Community 44 - "splash/splash_screen.dart"
Cohesion: 0.08
Nodes (25): Animation, AnimationController, build, _controller, createState, dispose, _fadeAnimation, initState (+17 more)

### Community 45 - "@JsonSerializable"
Cohesion: 0.25
Nodes (8): @JsonSerializable, _, Cart, CartItem, _, Order, OrderItem, AuthResponse

### Community 46 - "admin_authorization.dart"
Cohesion: 0.15
Nodes (12): AdminAuthorization, buildStaffHeaders, currentStaffHeaders, isAdmin, isStaff, options, optionsAsync, staffRoles (+4 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.13
Nodes (15): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, _bundledCategoryAssets (+7 more)

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
Cohesion: 0.12
Nodes (16): ../../core/widgets/loading_widgets.dart, ../data/models/product.dart, ../data/repositories/product_repository.dart, category, createState, _selectedSubIdx, build, ComboBuilderScreen (+8 more)

### Community 55 - "order_repository.dart"
Cohesion: 0.12
Nodes (16): ../../core/services/admin_authorization.dart, _cacheKey, cancelOrder, clearCache, dio, _getCacheKey, getOrder, getOrders (+8 more)

### Community 56 - "restaurant_repository.dart"
Cohesion: 0.11
Nodes (17): _cachedMenus, _cachedRestaurants, _dio, _fetchRestaurants, getDarkstoreAddonRecommendations, getRestaurantMenu, getRestaurantReviews, getRestaurants (+9 more)

### Community 57 - "address_repository.dart"
Cohesion: 0.14
Nodes (13): clearCache, createAddress, defaultAddressWithPhone, defaultGhatampurAddress, deleteAddress, dio, getAddresses, _getCacheKey (+5 more)

### Community 58 - "delivery_dashboard.dart"
Cohesion: 0.02
Nodes (97): ../../core/services/rider_location_service.dart, _activeTab, _assignedStoreId, _assignedStoreName, _audioPlayer, _autoRefreshTimer, bgMain, borderCol (+89 more)

### Community 59 - "FadeSlideRoute"
Cohesion: 0.14
Nodes (15): FadeSlideRoute, _handleContinue, _buildMenuTab, _buildReviewsTab, build, _buildCircularCategoryCarousel, _buildEndOfAisleSearchCard, _buildHeroPromoBanner (+7 more)

### Community 60 - "static const Color"
Cohesion: 0.11
Nodes (26): bootstrapUserLocation, checkLocationDriftAndPrompt, LocationService, build, _buildTopHeader, _buildTrustBadgeStrip, build, _useCurrentLocation (+18 more)

### Community 61 - "auth/delivery_login.dart"
Cohesion: 0.13
Nodes (14): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, dispose, _errorMessage, _handlePasswordLogin, _isLoading (+6 more)

### Community 62 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "delivery/delivery_login.dart"
Cohesion: 0.22
Nodes (8): delivery_dashboard.dart, build, createState, DeliveryLoginScreen, _isLoading, _otpController, _phoneController, _showOtp

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
Cohesion: 0.09
Nodes (22): admin_orders_list.dart, admin_products.dart, AdminDashboard, _AdminDashboardState, _buildDockItem, _buildOutletTile, createState, _currentIndex (+14 more)

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
Cohesion: 0.10
Nodes (19): ../core/services/location_service.dart, DeliveryTierInfo, build, _buildRow, CheckoutBillBreakdown, deliveryFee, discountAmount, grandTotal (+11 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.06
Nodes (42): CustomPainter, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter, _CafeFrontPainter (+34 more)

### Community 73 - "payment_failed_cod_sheet.dart"
Cohesion: 0.12
Nodes (16): build, createState, dispose, grandTotal, _handleCancel, _handleConfirmCod, initState, _isActionTaken (+8 more)

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.08
Nodes (21): package:fastkirana_flutter/core/config/app_config.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/data/models/order.dart, package:fastkirana_flutter/data/models/restaurant.dart, package:fastkirana_flutter/data/models/user.dart, package:fastkirana_flutter/providers/auth_provider.dart (+13 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.02
Nodes (97): BitmapDescriptor?, GoogleMapController?, activeColor, _audioPlayer, brandGreen, _buildCancelledOrderCard, _buildCancelOrderCard, _buildDeliveryDestinationCard (+89 more)

### Community 76 - "rider_card.dart"
Cohesion: 0.22
Nodes (8): build, deliveryOtp, _makeCall, RiderCard, riderName, riderPhone, riderRating, vehicleNumber

### Community 77 - "categoriesProvider"
Cohesion: 0.11
Nodes (27): build, AdminProductsScreen, _AdminProductsScreenState, build, build, build, CategoryProductsScreen, _CategoryProductsScreenState (+19 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (37): BuildContext, EdgeInsetsGeometry, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+29 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.05
Nodes (39): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+31 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.05
Nodes (40): ../../core/services/map_tile_cache_service.dart, doorstep_details_screen.dart, _areaName, build, _calculateDistance, createState, currentArea, _currentLat (+32 more)

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
Cohesion: 0.07
Nodes (27): Cart? get, ChangeNotifier, ../data/repositories/cart_repository.dart, AppConnectivityObserver, addItem, addProduct, _buildCart, _cart (+19 more)

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

### Community 99 - "widgets.dart"
Cohesion: 0.18
Nodes (10): empty_state.dart, widgets, library, loading_widgets.dart, retry_wrapper.dart, section_header.dart, ../../widgets/brand_input.dart, ../../widgets/cart_conflict_dialog.dart (+2 more)

### Community 100 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.05
Nodes (35): ../../../core/services/battery_optimization_service.dart, activeOrders, build, _buildLiveClock, _buildMetricItem, isPlayingAlarm, onMuteAlarm, pendingCount (+27 more)

### Community 101 - "package:fastkirana_flutter/core/services/logger_service.dart"
Cohesion: 0.10
Nodes (18): ../data/repositories/wishlist_repository.dart, Dio, dio, getCoupons, addToWishlist, dio, getWishlist, _handleError (+10 more)

### Community 102 - "main.dart"
Cohesion: 0.15
Nodes (12): core/routes/app_router.dart, core/services/deep_link_service.dart, ../core/services/notification_service.dart, ../core/services/secure_storage_service.dart, core/theme/app_theme.dart, firebase_options.dart, build, FastKiranaApp (+4 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (18): ../home/main_shell.dart, autoFetchLocation, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose, _getAddressIcon (+10 more)

### Community 104 - "cart_conflict_dialog.dart"
Cohesion: 0.11
Nodes (17): cart_conflict_dialog.dart, ../core/utils/restaurant_utils.dart, ProductRestaurantExtension, Product, build, CartConflictDialog, existingOutletName, groceryItemsCount (+9 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.10
Nodes (20): dart:ui, build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, initState (+12 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (19): autoDismissDuration, build, _buildFoodIllustration, createState, dispose, _fadeAnim, _fadeController, _floatAnim (+11 more)

### Community 108 - "restaurant_sales_report_tab.dart"
Cohesion: 0.12
Nodes (16): brandGreen, build, _buildSummaryRow, commissionRate, createState, _customEndDate, _customStartDate, _onPeriodTap (+8 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (19): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+11 more)

### Community 110 - "brand_input.dart"
Cohesion: 0.14
Nodes (13): IconData?, BrandInput, build, controller, hint, keyboardType, label, obscure (+5 more)

### Community 111 - "privacy_policy_screen.dart"
Cohesion: 0.09
Nodes (19): design_system.dart, AppTheme, _pageTransitionsTheme, build, _buildCard, _buildParagraph, _buildSection, _bullet (+11 more)

### Community 112 - "page_transitions.dart"
Cohesion: 0.18
Nodes (16): Duration?, FadeScaleRoute, FadeThroughRoute, FastKiranaPageTransitionsBuilder, page, SharedAxisRoute, SwiggyModalRoute, transitionDurationOverride (+8 more)

### Community 113 - "order_detail_screen.dart"
Cohesion: 0.12
Nodes (16): build, _buildBillRow, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor, _getStatusStepIndex, _makeCall (+8 more)

### Community 114 - "live_clock_badge.dart"
Cohesion: 0.13
Nodes (15): backgroundColor, borderColor, build, createState, dispose, fontSize, _formatTime, iconColor (+7 more)

### Community 115 - "voice_search_sheet.dart"
Cohesion: 0.12
Nodes (17): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+9 more)

### Community 116 - "../core/theme/responsive.dart"
Cohesion: 0.07
Nodes (30): ../core/theme/responsive.dart, AppToast, _show, showError, showInfo, showSuccess, showWarning, ToastType (+22 more)

### Community 117 - "../../core/services/logger_service.dart"
Cohesion: 0.12
Nodes (16): ../../core/services/logger_service.dart, _buildPayOnlineCard, _buildReviewCard, build, _buildNotificationTile, createState, _formatTimeAgo, initState (+8 more)

### Community 118 - "app_connectivity.dart"
Cohesion: 0.17
Nodes (11): bool get, Connectivity, _checkConnection, _connectivity, dispose, _init, _isOnline, observer (+3 more)

### Community 119 - "validators.dart"
Cohesion: 0.14
Nodes (13): ../config/app_config.dart, email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone (+5 more)

### Community 120 - "kot_print_service.dart"
Cohesion: 0.14
Nodes (13): extractRestaurantItems, formatKOTDate, generateKOTPdfDocument, KotPrintService, printKOTReceipt, _recentPrintTimestamps, sendRemoteKOTToKitchen, shareKOTReceipt (+5 more)

### Community 121 - "deep_link_service.dart"
Cohesion: 0.11
Nodes (18): AppLinks, _appLinks, DeepLinkService, dispose, _handleDeepLink, init, instance, _isInitialized (+10 more)

### Community 122 - "ConsumerState"
Cohesion: 0.08
Nodes (37): ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, _handleLogout, AdminLoginScreen, _AdminLoginScreenState, DeliveryLoginScreen, _DeliveryLoginScreenState (+29 more)

### Community 123 - "tracking_map.dart"
Cohesion: 0.17
Nodes (11): LatLng, build, initialPosition, markers, onRecenter, polylines, TrackingMap, OneSequenceGestureRecognizer (+3 more)

### Community 124 - "package:dio/dio.dart"
Cohesion: 0.11
Nodes (20): CartRepository, package:dio/dio.dart, package:fastkirana_flutter/core/services/biometric_service.dart, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/cart.dart, package:fastkirana_flutter/data/models/product.dart, package:fastkirana_flutter/data/repositories/cart_repository.dart, package:fastkirana_flutter/providers/cart_provider.dart (+12 more)

### Community 125 - "address_selector_sheet.dart"
Cohesion: 0.18
Nodes (11): ../features/location/map_picker_screen.dart, activeAddress, AddressSelectorSheet, _AddressSelectorSheetState, createState, _getAddressIcon, _isLocatingGps, onAddressSelected (+3 more)

### Community 126 - "floating_cart_bar.dart"
Cohesion: 0.29
Nodes (7): ../features/cart/cart_screen.dart, bottomOffset, createState, FloatingCartBar, _FloatingCartBarState, _isPressed, ../providers/cart_provider.dart

### Community 127 - "banner_repository.dart"
Cohesion: 0.17
Nodes (11): defaultBanners, dio, _diskBannersKey, _fetchFromNetwork, getBanners, _inMemoryBanners, _loadBannersFromDisk, _saveBannersToDisk (+3 more)

### Community 128 - "grid_skeletons.dart"
Cohesion: 0.09
Nodes (20): EdgeInsets, BrandCard, build, child, elevated, margin, onTap, padding (+12 more)

### Community 129 - "biometric_service.dart"
Cohesion: 0.22
Nodes (8): _auth, authenticate, BiometricService, getAvailableBiometrics, isBiometricAvailable, logger_service.dart, package:local_auth/local_auth.dart, static final LocalAuthentication

### Community 130 - "logger_service.dart"
Cohesion: 0.22
Nodes (8): debug, error, info, _logger, LoggerService, warning, package:logger/logger.dart, static final Logger

### Community 131 - "restaurant_menu_catalog_tab.dart"
Cohesion: 0.11
Nodes (18): bgMain, brandGreen, build, _buildMenuFilterChip, createState, dispose, menuItems, _menuSearchController (+10 more)

### Community 132 - "_CafeMenuScreenState"
Cohesion: 0.29
Nodes (8): build, _buildDarkstoreRecommendationsSection, CafeMenuScreen, _CafeMenuScreenState, _centerCategoryInHorizontalBar, restaurantAddonsProvider, restaurantMenuProvider, restaurantReviewsProvider

### Community 133 - "DateTime?"
Cohesion: 0.25
Nodes (7): DateTime?, build, createdAt, currentStatus, estimatedDelivery, _getStepIndex, StepperCard

### Community 134 - "String?"
Cohesion: 0.12
Nodes (14): checkDishTimeAvailability, DishTimingStatus, formattedTimeSlot, formatTime12h, isAvailableNow, nextAvailableTimeStr, badgeText, build (+6 more)

### Community 135 - "app_errors.dart"
Cohesion: 0.14
Nodes (13): Exception, ApiException, AppException, auth, code, color, isRetryable, message (+5 more)

### Community 136 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.12
Nodes (14): ../core/config/app_config.dart, ../core/network/api_client.dart, ../data/models/store_settings.dart, build, dio, AppUpdateDialog, build, _handleUpdate (+6 more)

### Community 137 - "store_hub_provider.dart"
Cohesion: 0.12
Nodes (16): ../core/services/supabase_service.dart, ../data/models/store_hub.dart, activeStoreHubsProvider, address, customerLat, customerLng, distanceKm, hub (+8 more)

### Community 138 - "order_alarm_service.dart"
Cohesion: 0.12
Nodes (16): AudioPlayer, _activeOrderId, _alarmLoopTimer, _audioPlayer, instance, _isMuted, _isPlaying, OrderAlarmService (+8 more)

### Community 139 - "store_hub.dart"
Cohesion: 0.13
Nodes (14): city, defaultGhatampur, deliveryRadiusKm, fromJson, groceryOpen, id, isActive, latitude (+6 more)

### Community 140 - "offline_banner.dart"
Cohesion: 0.14
Nodes (15): ../core/utils/app_connectivity.dart, connectivityProvider, build, createState, dispose, OfflineBanner, _OfflineBannerState, offlineText (+7 more)

### Community 141 - "AsyncValue"
Cohesion: 0.47
Nodes (6): AsyncValue, AddressesNotifier, AuthNotifier, CartNotifier, WishlistNotifier, StateNotifier

### Community 142 - "restaurants_list_screen.dart"
Cohesion: 0.20
Nodes (9): _buildFilterPill, createState, _cuisineCategories, dispose, RestaurantsListScreen, _searchController, static const List, ../../widgets/floating_cart_bar.dart (+1 more)

### Community 143 - "unserviceable_location_banner.dart"
Cohesion: 0.13
Nodes (15): ../data/models/address.dart, ../features/location/delivery_location_screen.dart, AddressesScreen, build, _buildAddressCard, _iconForLabel, addressRepositoryProvider, createState (+7 more)

### Community 144 - "dart:convert"
Cohesion: 0.17
Nodes (11): dart:convert, clearQueue, enqueueAction, flushQueue, getPendingCount, hasPendingActions, OfflineSyncService, queueAdmin (+3 more)

### Community 145 - "_DeliveryDashboardState"
Cohesion: 0.50
Nodes (4): DeliveryDashboard, _DeliveryDashboardState, _loadUserInfo, currentUserProvider

### Community 146 - "supabase_service.dart"
Cohesion: 0.14
Nodes (13): _activeBroadcastChannels, broadcastRiderLocation, _client, initialize, _isInitialized, subscribeToAllOrdersRealtime, subscribeToOrderLocation, SupabaseService (+5 more)

### Community 148 - "auth_provider.dart"
Cohesion: 0.14
Nodes (13): address_provider.dart, cart_provider.dart, ../features/orders/orders_screen.dart, auth, clear, _load, logout, maybeWhen (+5 more)

### Community 149 - "floating_order_tracking_bar.dart"
Cohesion: 0.14
Nodes (16): ../data/repositories/order_repository.dart, ../features/orders/order_tracking_screen.dart, build, ordersProvider, build, bottomOffset, build, createState (+8 more)

### Community 152 - "app_flavor.dart"
Cohesion: 0.15
Nodes (12): AppFlavor, appTitle, baseUrl, flavor, FlavorConfig, initialize, _instance, isCustomer (+4 more)

### Community 153 - "brand_logo.dart"
Cohesion: 0.20
Nodes (9): BrandLogo, build, FastKiranaLogoPainter, FastKiranaLogoWidget, paint, shouldRepaint, size, textColor (+1 more)

### Community 154 - "location_drift_sheet.dart"
Cohesion: 0.20
Nodes (9): Address?, LocationDetails, _Address, build, driftDistanceKm, LocationDriftSheet, newGpsDetails, previousAddress (+1 more)

### Community 155 - "api_client.dart"
Cohesion: 0.17
Nodes (11): Completer, int?, dio, _isRefreshingToken, message, null, _refreshCompleter, _refreshToken (+3 more)

### Community 156 - "wishlist_screen.dart"
Cohesion: 0.22
Nodes (8): primaryRed, _shareApp, _shareWishlist, slateDark, slateMuted, package:flutter_animate/flutter_animate.dart, package:share_plus/share_plus.dart, ../providers/wishlist_provider.dart

### Community 157 - "dart:async"
Cohesion: 0.40
Nodes (4): dart:async, dart:math, NetworkRetryHelper, ../services/logger_service.dart

### Community 158 - "core/widgets/empty_state.dart"
Cohesion: 0.25
Nodes (7): actionLabel, build, EmptyState, icon, onAction, subtitle, title

### Community 159 - "admin_coupon_detail.dart"
Cohesion: 0.29
Nodes (7): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive

### Community 160 - "cart_bill_summary_card.dart"
Cohesion: 0.18
Nodes (10): build, _buildRow, CartBillSummaryCard, couponDiscount, deliveryFee, grandTotal, handlingFee, itemTotal (+2 more)

### Community 161 - "package:flutter/services.dart"
Cohesion: 0.18
Nodes (9): build, CheckoutPackagingSelector, onPackagingChanged, selectedPackaging, build, _statItem, _stepCard, package:flutter/services.dart (+1 more)

### Community 162 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile, privacy_policy_screen.dart

### Community 163 - "about_screen.dart"
Cohesion: 0.33
Nodes (5): AboutScreen, build, _divider, _linkItem, _statBox

### Community 164 - "restaurant_order_card_view.dart"
Cohesion: 0.20
Nodes (9): build, isUpdating, onAcceptAndCook, onEditOrder, onMarkReady, onPrintKot, onReject, order (+1 more)

### Community 165 - "Color?"
Cohesion: 0.11
Nodes (16): Color?, appliedCoupon, build, CartSavingsBanner, couponDiscount, freeDeliveryThreshold, onApplyCouponTap, onRemoveCouponTap (+8 more)

### Community 166 - "sponsored_ad_card.dart"
Cohesion: 0.20
Nodes (9): actionText, build, discountText, imageUrl, onTap, promoCode, SponsoredAdCard, subtitle (+1 more)

### Community 167 - "battery_optimization_service.dart"
Cohesion: 0.22
Nodes (8): dart:io, BatteryOptimizationService, markDismissed, _prefKeyDismissed, requestExemption, shouldShowPrompt, package:permission_handler/permission_handler.dart, static const String

### Community 168 - "retry_wrapper.dart"
Cohesion: 0.22
Nodes (8): build, child, error, isLoading, onRetry, retryLabel, RetryWrapper, Object?

### Community 169 - "cart_item_card.dart"
Cohesion: 0.25
Nodes (7): ../data/models/cart.dart, build, CartItemCard, item, onDecrement, onIncrement, ../../../widgets/shimmer_box.dart

### Community 170 - "../data/models/order.dart"
Cohesion: 0.29
Nodes (6): ../data/models/order.dart, AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp

### Community 171 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.13
Nodes (14): CachedMapTileProvider, customHeaders, getImage, build, _buildNetworkFallback, categories, categoryAssetMap, CategoryBentoGrid (+6 more)

### Community 174 - "State"
Cohesion: 0.21
Nodes (12): OnboardingScreen, _OnboardingScreenState, SplashScreen, RestaurantSalesReportTab, _RestaurantSalesReportTabState, PaymentFailedCodSheet, _PaymentFailedCodSheetState, _AreaSearchModal (+4 more)

## Knowledge Gaps
- **2846 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+2841 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dioProvider` connect `dioProvider` to `cart_screen.dart`, `_DeliveryDashboardState`, `cartProvider`, `floating_order_tracking_bar.dart`, `main_shell.dart`, `otp_screen.dart`, `storeSettingsProvider`, `dynamic_hero_banner_carousel.dart`, `api_client.dart`, `profile_screen.dart`, `admin_orders_list.dart`, `admin_login.dart`, `SingleTickerProviderStateMixin`, `_DoorstepCashfreeQrSheetState`, `order_success_screen.dart`, `admin_products.dart`, `FadeSlideRoute`, `auth/delivery_login.dart`, `order_edit_modal.dart`, `admin_dashboard.dart`, `categoriesProvider`, `picker_dashboard.dart`, `add_picker_product_modal.dart`, `add_restaurant_product_modal.dart`, `../../core/services/logger_service.dart`, `ConsumerState`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `StoreHub` connect `store_hub.dart` to `store_hub_provider.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **Why does `Product` connect `cart_conflict_dialog.dart` to `product_detail_screen.dart`, `product.dart`, `product_card.dart`, `cart.dart`, `admin_products.dart`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _2846 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009852216748768473 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._