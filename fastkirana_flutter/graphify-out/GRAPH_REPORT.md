# Graph Report - fastkirana_flutter  (2026-09-05)

## Corpus Check
- 198 files · ~1,290,050 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3343 nodes · 5268 edges · 152 communities (146 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4d962a16`
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
- table_booking_screen.dart
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
- static const Color
- admin_login.dart
- login_screen.dart
- package:flutter_riverpod/flutter_riverpod.dart
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
- auth_provider.dart
- State
- onboarding_screen.dart
- splash/splash_screen.dart
- @JsonSerializable
- api_client.dart
- restaurant_card.dart
- banner.dart
- order_success_screen.dart
- admin_products.dart
- manifest.json
- product_repository.dart
- auth_repository.dart
- subcategory_screen.dart
- order_repository.dart
- restaurant_repository.dart
- ../../core/services/logger_service.dart
- delivery_dashboard.dart
- add_review_screen.dart
- addressesProvider
- auth/delivery_login.dart
- restaurant_login.dart
- delivery/delivery_login.dart
- settings_screen.dart
- about_screen.dart
- order_edit_modal.dart
- admin_dashboard.dart
- admin_reports.dart
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
- fastkirana_flutter
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
- restaurants_list_screen.dart
- delivery_header.dart
- ../core/network/api_client.dart
- main.dart
- delivery_location_screen.dart
- ../data/models/product.dart
- delivery_theme.dart
- live_gps_route_card.dart
- restaurant_delivery_loading_screen.dart
- floating_order_tracking_bar.dart
- grocery_delivery_loading_screen.dart
- package:dio/dio.dart
- privacy_policy_screen.dart
- page_transitions.dart
- order_detail_screen.dart
- live_clock_badge.dart
- voice_search_sheet.dart
- package:fastkirana_flutter/core/theme/design_system.dart
- notifications_screen.dart
- app_connectivity.dart
- validators.dart
- kot_print_service.dart
- supabase_service.dart
- authProvider
- tracking_map.dart
- sponsored_ad_card.dart
- package:flutter_bounceable/flutter_bounceable.dart
- floating_cart_bar.dart
- ../core/theme/responsive.dart
- brand_card.dart
- package:flutter/services.dart
- logger_service.dart
- retry_wrapper.dart
- categoriesProvider
- DateTime?
- String?
- core/widgets/empty_state.dart
- storeSettingsProvider
- animated_cart_badge.dart
- ../data/models/order.dart
- address_card.dart
- eta_widget.dart
- AsyncValue
- _CafeMenuScreenState
- @freezed
- battery_optimization_service.dart
- _DeliveryDashboardState
- _OrderTrackingScreenState
- _CategoryChipsDelegate
- _DeliveryPaymentSheet
- _PickerDashboardState
- @gmail

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 67 edges
2. `cartProvider` - 41 edges
3. `authProvider` - 35 edges
4. `FadeSlideRoute` - 28 edges
5. `addressesProvider` - 22 edges
6. `selectedAddressProvider` - 22 edges
7. `storeSettingsProvider` - 22 edges
8. `categoriesProvider` - 17 edges
9. `RecognitionListener` - 13 edges
10. `_HomeScreenState` - 11 edges

## Surprising Connections (you probably didn't know these)
- `_updateMart` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_updateMaster` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_updateRestaurant` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_dashboard.dart → lib/core/network/api_client.dart
- `_buildProductAdminCard` --references--> `dioProvider`  [EXTRACTED]
  lib/features/admin/admin_products.dart → lib/core/network/api_client.dart
- `_handleResend` --references--> `dioProvider`  [EXTRACTED]
  lib/features/auth/otp_screen.dart → lib/core/network/api_client.dart

## Import Cycles
- None detected.

## Communities (152 total, 6 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (192): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+184 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.02
Nodes (81): AudioPlayer, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, _availableOutlets, bgMain, brandAmber (+73 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.04
Nodes (53): ../checkout/order_success_screen.dart, brandGreen, _buildBillRow, _buildBillSummary, _buildBottomProceedBar, _buildCartItemsReview, _buildDeliveryMethodSwitcher, _buildGuaranteeBanner (+45 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.06
Nodes (39): ../categories/category_products_screen.dart, build, _buildActiveDeliveryTracker, _buildApiProductSections, _buildCategoryAvatarImage, _buildCategoryFallback, _buildCategoryToggle, _buildCuratedForYouFilter (+31 more)

### Community 4 - "restaurant_provider.dart"
Cohesion: 0.10
Nodes (28): ../data/repositories/restaurant_repository.dart, build, _RestaurantsListScreenState, address, cuisine, distanceMeters, filteredRestaurantsProvider, getRestaurantDistanceKm (+20 more)

### Community 5 - "order.dart"
Cohesion: 0.03
Nodes (58): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, addressRaw, cancelled, card, combinedId, confirmedAt (+50 more)

### Community 6 - "product.dart"
Cohesion: 0.04
Nodes (44): availableEndTime, availableStartTime, bannerUrl, barcode, category, categoryId, CategoryInfo, costPrice (+36 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.09
Nodes (23): ../cart/cart_screen.dart, build, _buildEmptyState, _buildSearchBox, _buildSegmentedTabs, _buildStatusFilterPills, createState, dispose (+15 more)

### Community 8 - "brand_input.dart"
Cohesion: 0.14
Nodes (13): IconData?, BrandInput, build, controller, hint, keyboardType, label, obscure (+5 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.04
Nodes (46): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+38 more)

### Community 10 - "product_card.dart"
Cohesion: 0.10
Nodes (20): ../features/products/product_detail_screen.dart, _badge, bs, _buildProductImage, createState, _getEmojiForProduct, isCompact, _isPressed (+12 more)

### Community 11 - "table_booking_screen.dart"
Cohesion: 0.12
Nodes (16): _bookTable, build, createState, dispose, _guests, _isLoading, restaurantId, restaurantName (+8 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.07
Nodes (29): AndroidFlutterLocalNotificationsPlugin, @pragma, body, data, firebaseMessagingBackgroundHandler, getFcmToken, getNotificationPreferences, _handleForegroundMessage (+21 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.04
Nodes (56): _activeCategoryTag, _buildBannerImage, _buildCategories, _buildCategoryThumbnail, _buildDishImage, _buildFallbackBanner, _buildFallbackLogo, _buildLocalAssetOrEmoji (+48 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.06
Nodes (34): ../checkout/checkout_screen.dart, coupons_screen.dart, _appliedCoupon, _applyCoupon, brandGreen, _buildBillDetailsCard, _buildBillRow, _buildCancellationPolicy (+26 more)

### Community 15 - "cart.dart"
Cohesion: 0.09
Nodes (22): appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items, lineTotal (+14 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.08
Nodes (24): address, bannerUrl, city, cuisineTags, deliveryTime, description, discountBadge, discountOffer (+16 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (19): cart_provider.dart, ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds (+11 more)

### Community 18 - "cartProvider"
Cohesion: 0.12
Nodes (20): deliveryTierProvider, _buildDishAddButton, _handleDishAddToCart, _handleDishIncrement, build, _buildCartErrorState, _buildCartItemCard, _buildCartScreenContent (+12 more)

### Community 19 - "subscription_screen.dart"
Cohesion: 0.15
Nodes (13): _availableCatalog, brandGreen, build, createState, primaryRed, _showNewSubscriptionModal, _skipTomorrow, slateDark (+5 more)

### Community 20 - "user.dart"
Cohesion: 0.08
Nodes (25): assignedRestaurantId, blockReason, createdAt, email, hashCode, id, image, isBlocked (+17 more)

### Community 21 - "app_router.dart"
Cohesion: 0.06
Nodes (34): Exception, ../../features/auth/admin_login.dart, ../../features/auth/delivery_login.dart, ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cafe/restaurant_dashboard.dart, ../../features/categories/categories_screen.dart, ../../features/checkout/checkout_screen.dart (+26 more)

### Community 22 - "main_shell.dart"
Cohesion: 0.10
Nodes (22): ../categories/categories_screen.dart, dart:io, home_screen.dart, _buildCircularCategoryCarousel, _autoShowTimer, build, _buildLiquidBottomNav, createState (+14 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.07
Nodes (28): build, _checkClipboard, _clipboardOtp, _controllers, createState, _currentOtp, didChangeAppLifecycleState, dispose (+20 more)

### Community 24 - "address_provider.dart"
Cohesion: 0.10
Nodes (19): ../data/models/address.dart, ../data/repositories/address_repository.dart, AddressRepository, AddressesScreen, build, _buildAddressCard, _iconForLabel, addAddress (+11 more)

### Community 25 - "static const Color"
Cohesion: 0.11
Nodes (19): ConsumerWidget, ProfileScreen, ReferEarnScreen, WalletScreen, build, primaryRed, _shareApp, _shareWishlist (+11 more)

### Community 26 - "admin_login.dart"
Cohesion: 0.14
Nodes (14): ../admin/admin_dashboard.dart, ../core/config/app_config.dart, AdminLoginScreen, _AdminLoginScreenState, build, createState, dispose, _emailController (+6 more)

### Community 27 - "login_screen.dart"
Cohesion: 0.09
Nodes (22): ../../data/repositories/auth_repository.dart, build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleSkipGuest (+14 more)

### Community 28 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.25
Nodes (6): build, _statItem, _stepCard, build, package:flutter_riverpod/flutter_riverpod.dart, ../../providers/auth_provider.dart

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (40): ../core/theme/design_system.dart, AdminBannersScreen, build, AdminCustomersScreen, build, build, _miniCard, RestaurantAnalyticsScreen (+32 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.07
Nodes (32): category_products_screen.dart, ../core/routes/page_transitions.dart, ../data/models/category.dart, FocusNode, _categories, CategoriesScreen, createState, dispose (+24 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.13
Nodes (14): address_book_screen.dart, ../auth/login_screen.dart, ../delivery/picker_dashboard.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader (+6 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.08
Nodes (30): BoxShape, ResponsiveContainer, _StatusDropdownItem, ProductCardSkeleton, BannerSkeleton, borderRadius, build, CategorySkeleton (+22 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.04
Nodes (54): ../../core/services/kot_print_service.dart, ../../core/services/offline_sync_service.dart, ../delivery/widgets/connectivity_banner.dart, AdminOrdersScreen, _AdminOrdersScreenState, _allOrders, build, _buildEmptyState (+46 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.08
Nodes (28): ../data/models/coupon.dart, ../data/repositories/coupon_repository.dart, CouponRepository, AdminCouponsScreen, build, _applyCode, build, _buildCouponCard (+20 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (38): _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField, _buildInteractiveMapPinboard, _buildStickyBottomBar (+30 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.10
Nodes (20): _buildShimmerGrid, _clearRecentSearches, _controller, createState, _debounce, dispose, initialQuery, initState (+12 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.13
Nodes (15): ../core/utils/dish_timing.dart, ProductVariant, _buildQualityRow, createState, initState, _isFavorite, _isNotified, primaryRed (+7 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.09
Nodes (25): Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl, name (+17 more)

### Community 40 - "coupon.dart"
Cohesion: 0.09
Nodes (23): Coupon, categoryId, code, expiresAt, hashCode, id, isActive, maxDiscount (+15 more)

### Community 41 - "auth_provider.dart"
Cohesion: 0.15
Nodes (12): ../core/services/secure_storage_service.dart, ../data/models/user.dart, auth, clear, _load, logout, maybeWhen, _ref (+4 more)

### Community 42 - "State"
Cohesion: 0.13
Nodes (23): ContextualBrandTransitionScreen, _ContextualBrandTransitionScreenState, AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, SplashScreen, _SplashScreenState, RestaurantDeliveryLoadingScreen, _RestaurantDeliveryLoadingScreenState (+15 more)

### Community 43 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 44 - "splash/splash_screen.dart"
Cohesion: 0.09
Nodes (22): Animation, AnimationController, build, _controller, createState, dispose, _fadeAnimation, initState (+14 more)

### Community 45 - "@JsonSerializable"
Cohesion: 0.25
Nodes (8): @JsonSerializable, _, Cart, CartItem, _, Order, OrderItem, AuthResponse

### Community 46 - "api_client.dart"
Cohesion: 0.15
Nodes (12): Completer, dart:async, int?, dio, _isRefreshingToken, message, null, _refreshCompleter (+4 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.14
Nodes (14): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, createState (+6 more)

### Community 48 - "banner.dart"
Cohesion: 0.11
Nodes (19): Banner, hashCode, id, imageUrl, isActive, link, operator, _privateConstructorUsedError (+11 more)

### Community 49 - "order_success_screen.dart"
Cohesion: 0.06
Nodes (36): ConfettiController, _animController, _buildDetailRow, _buildProgressLine, _buildProgressStep, _buttonsFadeAnim, _buttonsSlideAnim, _checkScaleAnim (+28 more)

### Community 50 - "admin_products.dart"
Cohesion: 0.05
Nodes (42): _addVariant, AdminProductsScreen, _AdminProductsScreenState, _buildCategoryChip, _buildGroceryCategoryChips, _buildMiniInput, _buildProductAdminCard, _buildRestaurantOutletChips (+34 more)

### Community 51 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "product_repository.dart"
Cohesion: 0.06
Nodes (31): _cachedCategories, _cachedProducts, _cacheKey, _cacheTTLMinutes, _categoryAliases, dio, _diskCategoriesKey, _diskCategoryTimestampKey (+23 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.11
Nodes (17): AuthRepository, dio, getProfile, _handleError, login, _parseSessionResponse, sendEmailOtp, sendOtp (+9 more)

### Community 54 - "subcategory_screen.dart"
Cohesion: 0.11
Nodes (19): ../data/repositories/product_repository.dart, build, build, build, category, createState, _selectedSubIdx, _subcategories (+11 more)

### Community 55 - "order_repository.dart"
Cohesion: 0.07
Nodes (26): dart:convert, clearQueue, enqueueAction, flushQueue, getPendingCount, hasPendingActions, OfflineSyncService, queueAdmin (+18 more)

### Community 56 - "restaurant_repository.dart"
Cohesion: 0.11
Nodes (17): _cachedMenus, _cachedRestaurants, _dio, _fetchRestaurants, getRestaurantMenu, getRestaurantReviews, getRestaurants, _getStaticFallbackRestaurants (+9 more)

### Community 57 - "../../core/services/logger_service.dart"
Cohesion: 0.13
Nodes (14): ../../core/services/logger_service.dart, _cacheKey, createAddress, defaultAddressWithPhone, defaultGhatampurAddress, deleteAddress, dio, getAddresses (+6 more)

### Community 58 - "delivery_dashboard.dart"
Cohesion: 0.02
Nodes (86): ../../core/services/rider_location_service.dart, _activeTab, _audioPlayer, _autoRefreshTimer, bgMain, borderCol, brandGreen, _buildActiveDeliveryCard (+78 more)

### Community 59 - "add_review_screen.dart"
Cohesion: 0.17
Nodes (12): AddReviewScreen, _AddReviewScreenState, build, createState, dispose, _isSubmitting, productName, _rating (+4 more)

### Community 60 - "addressesProvider"
Cohesion: 0.13
Nodes (24): build, _buildScrollableAddressSection, CheckoutScreen, _CheckoutScreenState, _fetchAndApplyCurrentLocation, _handlePlaceOrder, build, _handleSaveAddress (+16 more)

### Community 61 - "auth/delivery_login.dart"
Cohesion: 0.13
Nodes (14): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, dispose, _errorMessage, _isLoading, _masterRiderPassword (+6 more)

### Community 62 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "delivery/delivery_login.dart"
Cohesion: 0.09
Nodes (19): delivery_dashboard.dart, build, couponId, createState, _infoRow, _isActive, build, RestaurantOrderQueueScreen (+11 more)

### Community 64 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile, privacy_policy_screen.dart

### Community 65 - "about_screen.dart"
Cohesion: 0.33
Nodes (5): AboutScreen, build, _divider, _linkItem, _statBox

### Community 66 - "order_edit_modal.dart"
Cohesion: 0.05
Nodes (39): ../../core/services/admin_notification_service.dart, _adminCatalogFilter, brandAmber, brandGreen, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, _calculateSubtotal (+31 more)

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.09
Nodes (22): admin_orders_list.dart, admin_products.dart, AdminDashboard, _AdminDashboardState, _buildDockItem, _buildOutletTile, createState, _currentIndex (+14 more)

### Community 68 - "admin_reports.dart"
Cohesion: 0.33
Nodes (5): AdminReportsScreen, _breakdownRow, build, _reportStat, _topRow

### Community 69 - "List"
Cohesion: 0.33
Nodes (6): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState, List

### Community 70 - "brand_button.dart"
Cohesion: 0.07
Nodes (27): BorderRadius?, Color?, double?, backgroundColor, borderRadius, BrandButton, build, fontSize (+19 more)

### Community 71 - "FadeSlideRoute"
Cohesion: 0.17
Nodes (12): FadeSlideRoute, _buildAdminOrderCard, _handleContinue, _buildMenuTab, _buildRestaurantDishItem, _buildReviewsTab, build, _buildReferenceCategoryCard (+4 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.06
Nodes (39): CustomPainter, dart:math, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter (+31 more)

### Community 73 - "admin_settings.dart"
Cohesion: 0.40
Nodes (4): AdminSettingsScreen, build, _divider, _switchTile

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.07
Nodes (30): CartRepository, package:fastkirana_flutter/core/services/biometric_service.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/cart.dart, package:fastkirana_flutter/data/models/order.dart (+22 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.02
Nodes (82): BitmapDescriptor?, GoogleMapController?, brandGreen, _buildCancelledOrderCard, _buildDeliveryDestinationCard, _buildGoogleMapsCard, _buildMapCircleBtn, _buildOrderReceiptCard (+74 more)

### Community 76 - "rider_card.dart"
Cohesion: 0.14
Nodes (12): build, deliveryOtp, _makeCall, RiderCard, riderName, riderPhone, riderRating, vehicleNumber (+4 more)

### Community 77 - "ConsumerState"
Cohesion: 0.18
Nodes (13): CategoriesScreen, ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, DeliveryLoginScreen, _DeliveryLoginScreenState, CategoriesScreen, _CategoriesScreenState (+5 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (36): BuildContext, EdgeInsetsGeometry?, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+28 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.06
Nodes (30): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+22 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.07
Nodes (30): doorstep_details_screen.dart, _areaName, build, _calculateDistance, createState, _currentLat, _currentLng, dispose (+22 more)

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.06
Nodes (31): ../common/order_edit_modal.dart, _autoRefreshTimer, bgMain, brandGreen, brandOrange, _buildLiveClockMetric, _buildMetric, _buildPickerOrderCard (+23 more)

### Community 82 - "location_service.dart"
Cohesion: 0.07
Nodes (29): address, area, baseFee, cart, city, deliveryFee, DeliveryTierInfo, distanceKm (+21 more)

### Community 83 - "RecognitionListener"
Cohesion: 0.14
Nodes (9): MainActivity, RecognitionListener, Bundle, ByteArray, FlutterActivity, FlutterEngine, Intent, MethodChannel (+1 more)

### Community 84 - "restaurant_utils.dart"
Cohesion: 0.07
Nodes (29): address, asRestaurantLocation, balUdyanLocation, categorySlug, darkstoreLocation, false, getOutletLocation, getOutletName (+21 more)

### Community 86 - "add_picker_product_modal.dart"
Cohesion: 0.07
Nodes (27): class, _barcodeController, brandGreen, brandOrange, _commonUnits, createState, _descriptionController, dispose (+19 more)

### Community 89 - "add_restaurant_product_modal.dart"
Cohesion: 0.07
Nodes (27): ../../../core/utils/app_toast.dart, FormState, _buildFoodTypeOption, createState, _descriptionController, dispose, _formKey, _imageUrlController (+19 more)

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
Nodes (23): ChangeNotifier, ../core/utils/app_connectivity.dart, ../data/models/cart.dart, ../data/repositories/cart_repository.dart, AppConnectivityObserver, addItem, addProduct, _buildCartFromItems (+15 more)

### Community 95 - "app_config.dart"
Cohesion: 0.09
Nodes (22): apiBaseUrl, AppConfig, appIconAsset, appName, buildFlavor, darkstoreAddress, darkstoreLat, darkstoreLng (+14 more)

### Community 96 - "dioProvider"
Cohesion: 0.09
Nodes (23): dioProvider, _assignRider, _fetchAdminOrders, _flushOfflineAdminQueue, _sendRemoteKOT, _silentFetchAdminOrders, _updateOrderStatus, _updateSubOrderStatus (+15 more)

### Community 97 - "address.dart"
Cohesion: 0.09
Nodes (21): area, city, hashCode, houseNo, id, isDefault, label, latitude (+13 more)

### Community 98 - "lib/widgets/empty_state.dart"
Cohesion: 0.09
Nodes (21): bgTint, build, ctaColor, ctaLabel, emoji, emptyCart, EmptyState, icon (+13 more)

### Community 99 - "restaurants_list_screen.dart"
Cohesion: 0.10
Nodes (19): empty_state.dart, widgets, _buildFilterPill, createState, _cuisineCategories, dispose, RestaurantsListScreen, _searchController (+11 more)

### Community 100 - "delivery_header.dart"
Cohesion: 0.10
Nodes (20): activeTab, build, DeliveryHeader, _greeting, _greetingText, isDarkMode, isOnline, onBack (+12 more)

### Community 101 - "../core/network/api_client.dart"
Cohesion: 0.12
Nodes (17): ../core/network/api_client.dart, ../data/models/store_settings.dart, ../data/repositories/wishlist_repository.dart, addToWishlist, dio, getWishlist, _handleError, removeFromWishlist (+9 more)

### Community 102 - "main.dart"
Cohesion: 0.11
Nodes (18): core/routes/app_router.dart, ../core/services/notification_service.dart, ../core/services/supabase_service.dart, core/theme/app_theme.dart, firebase_options.dart, android, DefaultFirebaseOptions, ios (+10 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (19): ../home/main_shell.dart, autoFetchLocation, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose, _getAddressIcon (+11 more)

### Community 104 - "../data/models/product.dart"
Cohesion: 0.12
Nodes (17): cart_conflict_dialog.dart, ../core/utils/restaurant_utils.dart, ../data/models/product.dart, Product, build, CartConflictDialog, existingOutletName, groceryItemsCount (+9 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.11
Nodes (18): dart:ui, build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, initState (+10 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (18): autoDismissDuration, build, _buildFoodIllustration, createState, dispose, _fadeAnim, _fadeController, _floatAnim (+10 more)

### Community 108 - "floating_order_tracking_bar.dart"
Cohesion: 0.13
Nodes (17): ../data/repositories/order_repository.dart, ../features/orders/order_tracking_screen.dart, ../features/orders/orders_screen.dart, build, ordersProvider, build, bottomOffset, build (+9 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (17): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+9 more)

### Community 110 - "package:dio/dio.dart"
Cohesion: 0.12
Nodes (14): ../data/models/banner.dart, ../data/repositories/banner_repository.dart, Dio, BannerRepository, dio, getBanners, dio, getCoupons (+6 more)

### Community 111 - "privacy_policy_screen.dart"
Cohesion: 0.12
Nodes (15): design_system.dart, AppTheme, _pageTransitionsTheme, build, _buildCard, _buildParagraph, _buildSection, _bullet (+7 more)

### Community 112 - "page_transitions.dart"
Cohesion: 0.18
Nodes (16): Duration?, FadeScaleRoute, FadeThroughRoute, FastKiranaPageTransitionsBuilder, page, SharedAxisRoute, SwiggyModalRoute, transitionDurationOverride (+8 more)

### Community 113 - "order_detail_screen.dart"
Cohesion: 0.12
Nodes (16): build, _buildBillRow, _buildPayOnlineCard, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor, _getStatusStepIndex (+8 more)

### Community 114 - "live_clock_badge.dart"
Cohesion: 0.12
Nodes (16): backgroundColor, borderColor, build, createState, dispose, fontSize, _formatTime, iconColor (+8 more)

### Community 115 - "voice_search_sheet.dart"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+8 more)

### Community 116 - "package:fastkirana_flutter/core/theme/design_system.dart"
Cohesion: 0.13
Nodes (13): build, OrderCardShimmer, ProductCardShimmer, build, onSeeAll, SectionHeader, subtitle, title (+5 more)

### Community 117 - "notifications_screen.dart"
Cohesion: 0.13
Nodes (15): _buildReviewCard, build, _buildNotificationTile, createState, _formatTimeAgo, initState, _isLoading, _loadData (+7 more)

### Community 118 - "app_connectivity.dart"
Cohesion: 0.14
Nodes (13): bool get, Connectivity, _checkConnection, _connectivity, connectivityProvider, dispose, _init, _isOnline (+5 more)

### Community 119 - "validators.dart"
Cohesion: 0.14
Nodes (13): ../config/app_config.dart, email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone (+5 more)

### Community 120 - "kot_print_service.dart"
Cohesion: 0.14
Nodes (13): extractRestaurantItems, formatKOTDate, generateKOTPdfDocument, KotPrintService, printKOTReceipt, _recentPrintTimestamps, sendRemoteKOTToKitchen, shareKOTReceipt (+5 more)

### Community 121 - "supabase_service.dart"
Cohesion: 0.14
Nodes (13): _activeBroadcastChannels, broadcastRiderLocation, _client, initialize, _isInitialized, subscribeToAllOrdersRealtime, subscribeToOrderLocation, SupabaseService (+5 more)

### Community 122 - "authProvider"
Cohesion: 0.15
Nodes (13): _handleLogout, _handlePasswordLogin, _handleVerifyOtp, build, _initOutletDetails, _showKOTPrintModal, build, build (+5 more)

### Community 123 - "tracking_map.dart"
Cohesion: 0.17
Nodes (11): LatLng, build, initialPosition, markers, onRecenter, polylines, TrackingMap, OneSequenceGestureRecognizer (+3 more)

### Community 124 - "sponsored_ad_card.dart"
Cohesion: 0.20
Nodes (9): actionText, build, discountText, imageUrl, onTap, promoCode, SponsoredAdCard, subtitle (+1 more)

### Community 125 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.22
Nodes (8): Address?, ../features/location/map_picker_screen.dart, _Address, activeAddress, _getAddressIcon, onAddressSelected, show, package:flutter_bounceable/flutter_bounceable.dart

### Community 126 - "floating_cart_bar.dart"
Cohesion: 0.25
Nodes (8): ../core/services/location_service.dart, ../features/cart/cart_screen.dart, bottomOffset, createState, FloatingCartBar, _FloatingCartBarState, _isPressed, ../providers/cart_provider.dart

### Community 127 - "../core/theme/responsive.dart"
Cohesion: 0.22
Nodes (8): ../core/theme/responsive.dart, AppToast, _show, showError, showInfo, showSuccess, showWarning, ToastType

### Community 128 - "brand_card.dart"
Cohesion: 0.22
Nodes (8): EdgeInsets?, BrandCard, build, child, elevated, margin, onTap, padding

### Community 129 - "package:flutter/services.dart"
Cohesion: 0.22
Nodes (8): _auth, authenticate, BiometricService, getAvailableBiometrics, isBiometricAvailable, package:flutter/services.dart, package:local_auth/local_auth.dart, static final LocalAuthentication

### Community 130 - "logger_service.dart"
Cohesion: 0.22
Nodes (8): debug, error, info, _logger, LoggerService, warning, package:logger/logger.dart, static final Logger

### Community 131 - "retry_wrapper.dart"
Cohesion: 0.22
Nodes (8): build, child, error, isLoading, onRetry, retryLabel, RetryWrapper, Object?

### Community 132 - "categoriesProvider"
Cohesion: 0.22
Nodes (9): AddRestaurantProductModal, _AddRestaurantProductModalState, build, build, AddPickerProductModal, _AddPickerProductModalState, build, _buildHeroPromoBanner (+1 more)

### Community 133 - "DateTime?"
Cohesion: 0.25
Nodes (7): DateTime?, build, createdAt, currentStatus, estimatedDelivery, _getStepIndex, StepperCard

### Community 134 - "String?"
Cohesion: 0.25
Nodes (7): checkDishTimeAvailability, DishTimingStatus, formattedTimeSlot, formatTime12h, isAvailableNow, nextAvailableTimeStr, String?

### Community 135 - "core/widgets/empty_state.dart"
Cohesion: 0.25
Nodes (7): actionLabel, build, EmptyState, icon, onAction, subtitle, title

### Community 136 - "storeSettingsProvider"
Cohesion: 0.25
Nodes (8): build, _loadSettings, _sendWhatsAppKOT, _buildBottomCheckoutBar, _buildTrustBadgeStrip, build, storeSettingsProvider, build

### Community 137 - "animated_cart_badge.dart"
Cohesion: 0.25
Nodes (7): badgeColor, build, child, onTap, textColor, package:flutter_animate/flutter_animate.dart, Widget

### Community 138 - "../data/models/order.dart"
Cohesion: 0.29
Nodes (6): ../data/models/order.dart, AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp

### Community 139 - "address_card.dart"
Cohesion: 0.29
Nodes (6): AddressCard, build, fullAddress, isSelected, label, onTap

### Community 140 - "eta_widget.dart"
Cohesion: 0.29
Nodes (6): build, distanceText, etaText, EtaWidget, isRealtimeConnected, orderStatus

### Community 141 - "AsyncValue"
Cohesion: 0.47
Nodes (6): AsyncValue, AddressesNotifier, AuthNotifier, CartNotifier, WishlistNotifier, StateNotifier

### Community 142 - "_CafeMenuScreenState"
Cohesion: 0.40
Nodes (6): build, CafeMenuScreen, _CafeMenuScreenState, _centerCategoryInHorizontalBar, restaurantMenuProvider, restaurantReviewsProvider

### Community 143 - "@freezed"
Cohesion: 0.40
Nodes (5): @freezed, Address, StoreSettings, _StoreSettings, StoreSettings

### Community 144 - "battery_optimization_service.dart"
Cohesion: 0.40
Nodes (4): BatteryOptimizationService, ensureExempt, isIgnoringBatteryOptimizations, requestIgnoreBatteryOptimizations

### Community 145 - "_DeliveryDashboardState"
Cohesion: 0.50
Nodes (4): DeliveryDashboard, _DeliveryDashboardState, _loadUserInfo, currentUserProvider

### Community 146 - "_OrderTrackingScreenState"
Cohesion: 0.50
Nodes (4): build, OrderTrackingScreen, _OrderTrackingScreenState, bannersProvider

## Knowledge Gaps
- **2365 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+2360 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dioProvider` connect `dioProvider` to `categoriesProvider`, `cart_screen.dart`, `_DeliveryDashboardState`, `cartProvider`, `_OrderTrackingScreenState`, `_PickerDashboardState`, `main_shell.dart`, `otp_screen.dart`, `static const Color`, `admin_login.dart`, `login_screen.dart`, `admin_orders_list.dart`, `api_client.dart`, `order_success_screen.dart`, `admin_products.dart`, `add_review_screen.dart`, `addressesProvider`, `order_edit_modal.dart`, `admin_dashboard.dart`, `FadeSlideRoute`, `ConsumerState`, `picker_dashboard.dart`, `add_picker_product_modal.dart`, `add_restaurant_product_modal.dart`, `floating_order_tracking_bar.dart`, `notifications_screen.dart`, `authProvider`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `Product` connect `../data/models/product.dart` to `product_detail_screen.dart`, `product.dart`, `product_card.dart`, `cart.dart`, `admin_products.dart`, `restaurant_utils.dart`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **Why does `cartProvider` connect `cartProvider` to `home_screen.dart`, `orders_screen.dart`, `storeSettingsProvider`, `animated_cart_badge.dart`, `product_card.dart`, `_CafeMenuScreenState`, `main_shell.dart`, `static const Color`, `category_products_screen.dart`, `search_screen.dart`, `product_detail_screen.dart`, `order_success_screen.dart`, `subcategory_screen.dart`, `addressesProvider`, `FadeSlideRoute`, `cart_provider.dart`, `../data/models/product.dart`, `floating_order_tracking_bar.dart`, `floating_cart_bar.dart`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _2365 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.010362694300518135 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024390243902439025 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._