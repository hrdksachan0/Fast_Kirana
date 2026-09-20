# Graph Report - fastkirana_flutter  (2026-09-19)

## Corpus Check
- 310 files · ~732,799 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4720 nodes · 7629 edges · 207 communities (203 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b9809c37`
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
- models/cart.dart
- restaurant.dart
- product_provider.dart
- cartProvider
- subscription_screen.dart
- user.dart
- app_router.dart
- main_shell.dart
- otp_screen.dart
- address_provider.dart
- payment_gateway_service.dart
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
- flash_deals_carousel.dart
- cafe_menu_section.dart
- package:fastkirana_flutter/core/services/logger_service.dart
- api_client.dart
- restaurant_card.dart
- banner.dart
- order_success_screen.dart
- admin_products.dart
- manifest.json
- product_repository.dart
- auth_repository.dart
- package:flutter_riverpod/flutter_riverpod.dart
- order_repository.dart
- restaurant_repository.dart
- address_repository.dart
- delivery_dashboard.dart
- ConsumerState
- selectedAddressProvider
- authProvider
- ../data/models/order.dart
- rider_active_delivery_card.dart
- picker_order.dart
- delivery_mode_header.dart
- order_edit_modal.dart
- admin_dashboard.dart
- api_endpoints.dart
- VoidCallback?
- auth_provider.dart
- ../core/services/location_service.dart
- contextual_brand_transition_screen.dart
- payment_failed_cod_sheet.dart
- package:shared_preferences/shared_preferences.dart
- order_tracking_screen.dart
- tracking_status_stepper.dart
- package:flutter/services.dart
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
- admin_filter_header.dart
- delivery_header.dart
- delivery_payment_sheet.dart
- storeSettingsProvider
- delivery_location_screen.dart
- variant_selector_sheet.dart
- delivery_theme.dart
- live_gps_route_card.dart
- restaurant_delivery_loading_screen.dart
- restaurant_sales_report_tab.dart
- grocery_delivery_loading_screen.dart
- app_errors.dart
- privacy_policy_screen.dart
- page_transitions.dart
- order_detail_screen.dart
- live_clock_badge.dart
- voice_search_sheet.dart
- onboarding_screen.dart
- ../providers/cart_provider.dart
- State
- validators.dart
- kot_print_service.dart
- deep_link_service.dart
- admin_login.dart
- tracking_map_view.dart
- package:dio/dio.dart
- ../providers/address_provider.dart
- app_toast.dart
- cart/cart.dart
- coupon_provider.dart
- Map
- logger_service.dart
- restaurant_menu_catalog_tab.dart
- categoriesProvider
- admin_order_card.dart
- doorstep_cashfree_qr_sheet.dart
- restaurantsProvider
- banner_repository.dart
- store_hub_provider.dart
- dart:async
- store_hub.dart
- offline_banner.dart
- package:flutter/services.dart
- supabase_service.dart
- brand_input.dart
- home_category_toggle.dart
- cart_bill_details_card.dart
- ../core/routes/page_transitions.dart
- splash/splash_screen.dart
- ../../core/services/logger_service.dart
- wishlist_screen.dart
- @gmail
- app_flavor.dart
- cafe_offers_strip.dart
- app_confirmation_dialog.dart
- grid_skeletons.dart
- order_recipient_helper.dart
- models.dart
- main.dart
- admin_coupon_detail.dart
- orders.dart
- app_update_dialog.dart
- auth/delivery_login.dart
- package:flutter_bounceable/flutter_bounceable.dart
- cart_coupon_card.dart
- cart_savings_banner.dart
- cart_bottom_checkout_bar.dart
- biometric_service.dart
- cafe_reviews_tab.dart
- cafe.dart
- checkout_payment_selector_sheet.dart
- tracking_widgets_test.dart
- List
- unserviceable_location_banner.dart
- rider_pickup_card.dart
- ../core/utils/restaurant_utils.dart
- ../core/theme/responsive.dart
- notifications_screen.dart
- dart:convert
- brand_logo.dart
- categories_screen.dart
- Color
- admin_stat_card.dart
- ../data/models/product.dart
- ../core/config/app_config.dart
- cart_bill_summary_card.dart
- battery_optimization_service.dart
- admin_stats_grid.dart
- map_marker_generator.dart
- sponsored_ad_card.dart
- delivery_orders_tab.dart
- restaurant_login.dart
- dart:math
- geo_math_utils.dart
- package:flutter/foundation.dart
- _RestaurantsListScreenState
- core_components_widget_test.dart
- checkout_bottom_bar.dart
- admin_notification_service.dart
- String?
- firebaseMessagingBackgroundHandler
- static const Color
- settings_screen.dart
- _CategoryChipsDelegate
- Order
- TickerProviderStateMixin

## God Nodes (most connected - your core abstractions)
1. `dioProvider` - 92 edges
2. `cartProvider` - 45 edges
3. `authProvider` - 35 edges
4. `selectedAddressProvider` - 33 edges
5. `FadeSlideRoute` - 32 edges
6. `storeSettingsProvider` - 30 edges
7. `categoriesProvider` - 29 edges
8. `addressesProvider` - 21 edges
9. `homeProductCatalogProvider` - 17 edges
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

## Communities (207 total, 4 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.01
Nodes (203): accent, accentDark, accentGradient, accentLight, amber400, amber50, amber600, amber700 (+195 more)

### Community 1 - "restaurant_dashboard.dart"
Cohesion: 0.03
Nodes (76): ../../core/network/network_retry_helper.dart, _activeTab, _assignedRestaurantId, _audioPlayer, _autoRefreshTimer, bgMain, brandAmber, brandGreen (+68 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.04
Nodes (55): CFPaymentGatewayService, ../checkout/order_success_screen.dart, checkout_screen.dart, _cfService, CheckoutScreen, _CheckoutScreenState, _completeOrderPlacement, cookingInstruction (+47 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.09
Nodes (23): build, createState, dispose, HomeScreen, _HomeScreenState, _homeScrollController, _isGrocerySelected, _isLoadingMoreGrid (+15 more)

### Community 4 - "restaurant_provider.dart"
Cohesion: 0.09
Nodes (21): ../data/repositories/restaurant_repository.dart, address, cuisine, distanceMeters, getDarkstoreAddonRecommendations, getRestaurantDistanceKm, getRestaurantMenu, getRestaurantReviews (+13 more)

### Community 5 - "order.dart"
Cohesion: 0.03
Nodes (59): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, addressRaw, cancelled, card, combinedId, confirmedAt (+51 more)

### Community 6 - "product.dart"
Cohesion: 0.02
Nodes (91): aCreated, AddonGroup, AddonItem, addons, address, aName, aSort, availableEndTime (+83 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.08
Nodes (26): FadeSlideRoute, _handleContinue, _buildMenuTab, _buildReferenceCategoryCard, build, _buildEmptyState, _buildOrderCard, _buildSearchBox (+18 more)

### Community 8 - "kitchen_order.dart"
Cohesion: 0.05
Nodes (37): cookingInstruction, createdAt, customerAddress, customerName, customerPhone, deliveryMethod, elapsedMinutes, fromJson (+29 more)

### Community 9 - "secure_storage_service.dart"
Cohesion: 0.07
Nodes (26): _cachedRefreshToken, _cachedToken, _cachedUserData, _cachedUserEmail, _cachedUserId, _cachedUserName, _cachedUserPhone, _cachedUserRole (+18 more)

### Community 10 - "product_card.dart"
Cohesion: 0.03
Nodes (63): ../features/products/product_detail_screen.dart, Gradient, _addButton, bestseller, bogo, bogoBadgeText, child, createState (+55 more)

### Community 11 - "add_item_search_sheet.dart"
Cohesion: 0.09
Nodes (22): AddItemSearchSheet, _AddItemSearchSheetState, _adminCatalogFilter, _buildAdminFilterChip, _buildCatalogSearchTab, _buildCustomItemTab, createState, _customNameController (+14 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.05
Nodes (36): AndroidFlutterLocalNotificationsPlugin, _bgRecentMessageTimes, body, clearAllNotifications, data, getFcmToken, getNotificationPreferences, _handleForegroundMessage (+28 more)

### Community 13 - "cafe_menu_screen.dart"
Cohesion: 0.04
Nodes (44): GlobalKey, _activeCategoryTag, _buildCategories, _buildCategoryThumbnail, _buildFallbackBanner, _buildFallbackLogo, _buildLocalAssetOrEmoji, _buildLogoWidget (+36 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.07
Nodes (30): ConfettiController, _appliedCoupon, _applyCoupon, _bogoBadgeText, _buildEmptyState, CartScreen, _CartScreenState, _checkAutoApplyCoupon (+22 more)

### Community 15 - "models/cart.dart"
Cohesion: 0.09
Nodes (22): double get, appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items (+14 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.06
Nodes (32): activeOrdersCount, address, bannerUrl, city, closeTime, commissionRate, cuisineTags, deliveryTime (+24 more)

### Community 17 - "product_provider.dart"
Cohesion: 0.10
Nodes (19): ProductRepository, activeOutlet, activeRestaurantId, all, cart, cartItems, cleanIds, filteredUpsells (+11 more)

### Community 18 - "cartProvider"
Cohesion: 0.09
Nodes (28): ConsumerWidget, ../data/models/cart.dart, AdminOrderCard, build, _buildCartErrorState, CartBottomCheckoutBar, CartItemRow, build (+20 more)

### Community 19 - "subscription_screen.dart"
Cohesion: 0.15
Nodes (13): _availableCatalog, brandGreen, build, createState, primaryRed, _showNewSubscriptionModal, _skipTomorrow, slateDark (+5 more)

### Community 20 - "user.dart"
Cohesion: 0.08
Nodes (26): assignedRestaurantId, blockReason, createdAt, email, hashCode, id, image, isBlocked (+18 more)

### Community 21 - "app_router.dart"
Cohesion: 0.06
Nodes (31): ../../features/auth/admin_login.dart, ../../features/auth/delivery_login.dart, ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cafe/restaurant_dashboard.dart, ../../features/categories/categories_screen.dart, ../../features/checkout/checkout_screen.dart, ../../features/delivery/delivery_dashboard.dart (+23 more)

### Community 22 - "main_shell.dart"
Cohesion: 0.13
Nodes (18): ../categories/categories_screen.dart, ../delivery/picker_dashboard.dart, home_screen.dart, build, _buildLiquidBottomNav, createState, didChangeAppLifecycleState, dispose (+10 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.07
Nodes (29): build, _checkClipboard, _clipboardOtp, _controllers, createState, _currentOtp, didChangeAppLifecycleState, dispose (+21 more)

### Community 24 - "address_provider.dart"
Cohesion: 0.17
Nodes (11): ../data/repositories/address_repository.dart, AddressRepository, addAddress, addressesAsync, clear, deleteAddress, loadAddresses, notifier (+3 more)

### Community 25 - "payment_gateway_service.dart"
Cohesion: 0.11
Nodes (18): dispose, ExternalWalletCallback, _handleError, _handleSuccess, _handleWallet, initialize, isSupported, _onError (+10 more)

### Community 26 - "dynamic_hero_banner_carousel.dart"
Cohesion: 0.07
Nodes (30): ../data/models/banner.dart, ../data/repositories/banner_repository.dart, ../features/categories/category_products_screen.dart, BannerRepository, build, bannerRepositoryProvider, bannersProvider, getBanners (+22 more)

### Community 27 - "checkout_delivery_instructions.dart"
Cohesion: 0.06
Nodes (34): build, isBusyMode, isStoreOpen, onToggleBusyMode, onToggleStoreOpen, RestaurantSettingsTab, build, CartCancellationPolicy (+26 more)

### Community 28 - "brand_button.dart"
Cohesion: 0.07
Nodes (26): BorderRadius?, double?, build, child, error, isLoading, onRetry, retryLabel (+18 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (61): ../core/theme/design_system.dart, AboutScreen, build, _divider, _linkItem, _statBox, AdminBannersScreen, build (+53 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.07
Nodes (28): ../../core/widgets/loading_widgets.dart, ../data/repositories/product_repository.dart, FocusNode, _buildFilterPill, category, createState, dispose, emoji (+20 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.15
Nodes (12): address_book_screen.dart, _buildMenuItem, _buildOperationBentoTile, _buildSectionHeader, _buildShortcutCard, _buildUserHeader, primaryRed, _promptOtpVerification (+4 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.06
Nodes (42): BoxShape, AppShimmer, build, child, count, OrderCardShimmer, ProductCardShimmer, ProductGridShimmer (+34 more)

### Community 33 - "admin_orders_list.dart"
Cohesion: 0.03
Nodes (77): admin_orders_list.dart, AutomaticKeepAliveClientMixin, ../../core/services/order_alarm_service.dart, ../delivery/widgets/connectivity_banner.dart, AdminOrdersScreen, _AdminOrdersScreenState, _allOrders, _assignedStoreId (+69 more)

### Community 34 - "coupons_screen.dart"
Cohesion: 0.11
Nodes (18): _applyCode, _buildCouponCard, _buildLoadingShimmer, _buildManualInputCard, _buildZeroCouponState, CouponsScreen, _CouponsScreenState, createState (+10 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.05
Nodes (40): AddAddressScreen, _AddAddressScreenState, _addressTypes, _areaController, brandGreen, build, _buildAddressTypeSelector, _buildInputField (+32 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.05
Nodes (46): empty_state.dart, widgets, _buildFilterPill, createState, _cuisineCategories, dispose, _searchController, build (+38 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.11
Nodes (18): ../cart/cart_screen.dart, ../core/utils/dish_timing.dart, ProductVariant, _addToCart, _buildCustomizedProduct, _buildQualityRow, createState, initState (+10 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.13
Nodes (14): applyCoupon, clearCart, dio, getCart, _getCartCacheKey, getLocalCart, _handleError, hasPendingSync (+6 more)

### Community 39 - "category.dart"
Cohesion: 0.09
Nodes (26): @freezed, Category, CategoryCount, CategoryCount? get, count, hashCode, id, imageUrl (+18 more)

### Community 40 - "coupon.dart"
Cohesion: 0.11
Nodes (18): autoApply, badgeText, bogoType, categoryId, code, Coupon, DiscountType, expiresAt (+10 more)

### Community 41 - "login_screen.dart"
Cohesion: 0.12
Nodes (16): ../../data/repositories/auth_repository.dart, build, _buildTncSection, createState, dispose, _errorMessage, _focusNode, _handleSkipGuest (+8 more)

### Community 42 - "delivery_order.dart"
Cohesion: 0.05
Nodes (40): address, city, combinedId, createdAt, customerName, customerPhone, deliveryFee, DeliveryOrder (+32 more)

### Community 43 - "flash_deals_carousel.dart"
Cohesion: 0.12
Nodes (13): badgeText, build, FlashDealsCarousel, onSeeAll, products, subtitle, title, build (+5 more)

### Community 44 - "cafe_menu_section.dart"
Cohesion: 0.12
Nodes (15): clean, description, emoji, getCategoryAssetImage, id, imageUrl, mapping, matchTags (+7 more)

### Community 45 - "package:fastkirana_flutter/core/services/logger_service.dart"
Cohesion: 0.10
Nodes (18): Dio, checkDishTimeAvailability, DishTimingStatus, formattedTimeSlot, formatTime12h, isAvailableNow, nextAvailableTimeStr, dio (+10 more)

### Community 46 - "api_client.dart"
Cohesion: 0.08
Nodes (22): Completer, int?, dio, _isRefreshingToken, message, null, _refreshCompleter, _refreshToken (+14 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.11
Nodes (18): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, _buildDefaultFallback, _buildImagePlaceholder, _buildLocalOrFallbackImage, _buildRestaurantImage, _bundledCategoryAssets, createState (+10 more)

### Community 48 - "banner.dart"
Cohesion: 0.12
Nodes (16): Banner, code, description, fromJson, gradient, id, imageUrl, isActive (+8 more)

### Community 49 - "order_success_screen.dart"
Cohesion: 0.06
Nodes (34): _animController, _buildDetailRow, _buildProgressLine, _buildProgressStep, _buttonsFadeAnim, _buttonsSlideAnim, _checkScaleAnim, _confettiController (+26 more)

### Community 50 - "admin_products.dart"
Cohesion: 0.04
Nodes (44): _addVariant, _buildCategoryChip, _buildGroceryCategoryChips, _buildMiniInput, _buildProductAdminCard, _buildRestaurantOutletChips, _buildSectionTitle, _buildSegmentButton (+36 more)

### Community 51 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "product_repository.dart"
Cohesion: 0.06
Nodes (32): _cachedCategories, _cachedProducts, _cacheKey, _cacheTTLMinutes, dio, _diskCategoriesKey, _diskCategoryTimestampKey, _diskFetchTimestampKey (+24 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.11
Nodes (17): AuthRepository, dio, getProfile, _handleError, login, _parseSessionResponse, sendEmailOtp, sendOtp (+9 more)

### Community 54 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.11
Nodes (16): ../core/network/api_client.dart, ../data/models/store_settings.dart, ../data/repositories/wishlist_repository.dart, AdminRefundSheet, show, build, dio, hub (+8 more)

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
Cohesion: 0.03
Nodes (65): ../common/widgets/battery_optimization_dialog.dart, ../../core/services/offline_sync_service.dart, ../../core/services/rider_location_service.dart, delivery_dashboard.dart, _activeTab, _assignedStoreId, _assignedStoreName, _audioPlayer (+57 more)

### Community 59 - "ConsumerState"
Cohesion: 0.10
Nodes (24): ConsumerState, ConsumerStatefulWidget, DeliveryLoginScreen, AdminProductsScreen, _AdminProductsScreenState, _ProductEditBottomSheet, _ProductEditBottomSheetState, _DeliveryLoginScreenState (+16 more)

### Community 60 - "selectedAddressProvider"
Cohesion: 0.12
Nodes (25): bootstrapUserLocation, checkLocationDriftAndPrompt, LocationService, build, _handlePlaceOrder, initState, build, _useCurrentLocation (+17 more)

### Community 61 - "authProvider"
Cohesion: 0.11
Nodes (18): _handleLogout, _handlePasswordLogin, _handleVerifyOtp, build, _initOutletDetails, _resolveOutletDetailsSync, _showKOTPrintModal, build (+10 more)

### Community 62 - "../data/models/order.dart"
Cohesion: 0.15
Nodes (12): ../../core/services/admin_notification_service.dart, ../data/models/order.dart, AdminShareSheet, _buildShareOptionTile, show, AdminSubstitutionSheet, show, build (+4 more)

### Community 63 - "rider_active_delivery_card.dart"
Cohesion: 0.15
Nodes (12): brandGreen, build, emeraldGreen, EmptyOutForDeliveryCard, isUpdating, order, primaryRed, RiderActiveDeliveryCard (+4 more)

### Community 64 - "picker_order.dart"
Cohesion: 0.08
Nodes (24): createdAt, customerAddress, customerName, customerPhone, elapsedMinutes, fromJson, id, imageUrl (+16 more)

### Community 65 - "delivery_mode_header.dart"
Cohesion: 0.09
Nodes (21): activeLocationSubtitle, activeLocationTitle, build, _buildSegmentedModeToggle, cafeSvg, currentSearchPlaceholder, d, DeliveryModeHeader (+13 more)

### Community 66 - "order_edit_modal.dart"
Cohesion: 0.08
Nodes (26): brandAmber, brandGreen, _calculateSubtotal, createState, initState, isAdmin, isRestaurant, _isSaving (+18 more)

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.10
Nodes (21): admin_products.dart, AdminDashboard, _AdminDashboardState, _buildDockItem, _buildOutletTile, createState, _currentIndex, _handleBackPress (+13 more)

### Community 68 - "api_endpoints.dart"
Cohesion: 0.10
Nodes (20): addresses, ApiEndpoints, banners, baseUrl, cart, categories, createOrder, emailCheck (+12 more)

### Community 69 - "VoidCallback?"
Cohesion: 0.05
Nodes (37): ../../../core/utils/validators.dart, AddressCard, build, fullAddress, isSelected, label, onTap, actionLabel (+29 more)

### Community 70 - "auth_provider.dart"
Cohesion: 0.14
Nodes (13): address_provider.dart, cart_provider.dart, ../core/services/secure_storage_service.dart, auth, clear, _load, logout, maybeWhen (+5 more)

### Community 71 - "../core/services/location_service.dart"
Cohesion: 0.08
Nodes (23): ../core/services/location_service.dart, ../data/models/address.dart, DeliveryTierInfo, build, CartFreeDeliveryBar, subtotal, tier, build (+15 more)

### Community 72 - "contextual_brand_transition_screen.dart"
Cohesion: 0.07
Nodes (37): CustomPainter, autoDismissDuration, build, _buildContextScene, _buildSpecificBackIllustration, _buildSpecificFrontIllustration, _CafeBackPainter, _CafeFrontPainter (+29 more)

### Community 73 - "payment_failed_cod_sheet.dart"
Cohesion: 0.10
Nodes (20): build, createState, dispose, grandTotal, _handleCancel, _handleConfirmCod, _handleRetryPayment, initState (+12 more)

### Community 74 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.09
Nodes (20): package:fastkirana_flutter/core/services/biometric_service.dart, package:fastkirana_flutter/core/services/offline_sync_service.dart, package:fastkirana_flutter/core/services/secure_storage_service.dart, package:fastkirana_flutter/data/models/restaurant.dart, package:fastkirana_flutter/data/models/user.dart, package:fastkirana_flutter/providers/auth_provider.dart, package:fastkirana_flutter/widgets/shimmer_loading.dart, package:flutter_secure_storage/flutter_secure_storage.dart (+12 more)

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.03
Nodes (79): BitmapDescriptor?, GoogleMapController?, _audioPlayer, brandGreen, _calculateBearing, _calculateETA, _cfService, _checkAndRequestLocationPermission (+71 more)

### Community 76 - "tracking_status_stepper.dart"
Cohesion: 0.10
Nodes (20): activeColor, build, cleanDisplayId, completedColor, createState, didUpdateWidget, dispose, distanceText (+12 more)

### Community 77 - "package:flutter/services.dart"
Cohesion: 0.16
Nodes (13): ../features/location/map_picker_screen.dart, build, currentUserIdProvider, activeAddress, AddressSelectorSheet, _AddressSelectorSheetState, createState, _getAddressIcon (+5 more)

### Community 78 - "responsive.dart"
Cohesion: 0.05
Nodes (39): BuildContext, EdgeInsetsGeometry, backgroundColor, bannerHeight, bottomPadding, build, categoryCardAspectRatio, child (+31 more)

### Community 79 - "store_settings.dart"
Cohesion: 0.04
Nodes (48): adminWhatsappPhone, avgDeliveryTime, cafeFreeDeliveryThreshold, cafeOpen, combinedFreeDeliveryThreshold, contactPhone, deliveryFee, deliveryRadiusKm (+40 more)

### Community 80 - "map_picker_screen.dart"
Cohesion: 0.05
Nodes (38): ../../core/services/map_tile_cache_service.dart, doorstep_details_screen.dart, _areaName, build, _calculateDistance, createState, currentArea, _currentLat (+30 more)

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.06
Nodes (34): ../common/order_edit_modal.dart, _autoRefreshTimer, bgMain, brandGreen, brandOrange, build, _buildEmptyState, _buildMetricStrip (+26 more)

### Community 82 - "location_service.dart"
Cohesion: 0.06
Nodes (35): area, baseFee, cart, city, deliveryFee, distanceKm, feeDescription, fetchCurrentLocationDetails (+27 more)

### Community 83 - "RecognitionListener"
Cohesion: 0.14
Nodes (9): MainActivity, RecognitionListener, Bundle, ByteArray, FlutterActivity, FlutterEngine, Intent, MethodChannel (+1 more)

### Community 84 - "restaurant_utils.dart"
Cohesion: 0.05
Nodes (41): address, _byKey, categorySlug, darkstoreLocation, _ensureInitialized, false, find, findByPhone (+33 more)

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
Cohesion: 0.07
Nodes (27): Cart? get, ChangeNotifier, ../data/repositories/cart_repository.dart, AppConnectivityObserver, addItem, addProduct, _buildCart, _cart (+19 more)

### Community 95 - "app_config.dart"
Cohesion: 0.07
Nodes (28): apiBaseUrl, AppConfig, appIconAsset, appName, appVersion, buildFlavor, buildNumber, cashfreeAppId (+20 more)

### Community 96 - "dioProvider"
Cohesion: 0.06
Nodes (35): dioProvider, _assignRider, _convertToCOD, _fetchAdminOrders, _fetchAdminProfile, _fetchDeliveryRiders, _flushOfflineAdminQueue, _initNotificationSubscriptions (+27 more)

### Community 97 - "address.dart"
Cohesion: 0.08
Nodes (24): Address?, area, city, hashCode, houseNo, id, isDefault, label (+16 more)

### Community 98 - "lib/widgets/empty_state.dart"
Cohesion: 0.09
Nodes (21): bgTint, build, ctaColor, ctaLabel, emoji, emptyCart, EmptyState, icon (+13 more)

### Community 99 - "admin_filter_header.dart"
Cohesion: 0.08
Nodes (25): AdminFilterHeader, _AdminFilterHeaderState, build, _buildMainTabButton, createState, currentSubFilter, didUpdateWidget, displayHistoryCount (+17 more)

### Community 100 - "delivery_header.dart"
Cohesion: 0.07
Nodes (28): activeOrders, build, _buildLiveClock, _buildMetricItem, isPlayingAlarm, onMuteAlarm, pendingCount, RestaurantMetricsBar (+20 more)

### Community 101 - "delivery_payment_sheet.dart"
Cohesion: 0.09
Nodes (23): build, _buildCodContent, _buildPrepaidContent, cashInHand, cashLimit, _cashPortionController, _cashReceivedController, createState (+15 more)

### Community 102 - "storeSettingsProvider"
Cohesion: 0.11
Nodes (20): _loadSettings, build, build, _fetchQrData, build, HomeBuyAgainShelf, isGrocerySelected, build (+12 more)

### Community 103 - "delivery_location_screen.dart"
Cohesion: 0.11
Nodes (19): ../home/main_shell.dart, autoFetchLocation, build, _checkAndAutoPromptLocation, createState, DeliveryLocationScreen, _DeliveryLocationScreenState, dispose (+11 more)

### Community 104 - "variant_selector_sheet.dart"
Cohesion: 0.11
Nodes (19): cart_conflict_dialog.dart, _buildFoodCustomizationSheet, _buildGroceryPackSizeSheet, _buildGroceryVariantCard, _buildVariantProduct, color, createState, _foodQuantity (+11 more)

### Community 105 - "delivery_theme.dart"
Cohesion: 0.11
Nodes (18): Color get, bgMain, borderCol, brandGreen, cardBg, cardSubtle, DeliveryTheme, emeraldDark (+10 more)

### Community 106 - "live_gps_route_card.dart"
Cohesion: 0.11
Nodes (18): build, _countdownTimer, createState, destinationAddress, dispose, _formatCountdown, _GpsRoutePainter, initState (+10 more)

### Community 107 - "restaurant_delivery_loading_screen.dart"
Cohesion: 0.10
Nodes (20): autoDismissDuration, build, _buildFoodIllustration, createState, dispose, _fadeAnim, _fadeController, _floatAnim (+12 more)

### Community 108 - "restaurant_sales_report_tab.dart"
Cohesion: 0.11
Nodes (18): brandGreen, build, _buildSummaryRow, commissionRate, createState, _customEndDate, _customStartDate, _onPeriodTap (+10 more)

### Community 109 - "grocery_delivery_loading_screen.dart"
Cohesion: 0.11
Nodes (19): autoDismissDuration, build, _buildGroceryIllustration, createState, _CuteGroceryVectorPainter, dispose, _fadeAnim, _fadeController (+11 more)

### Community 110 - "app_errors.dart"
Cohesion: 0.11
Nodes (17): Exception, ApiException, appError, AppException, auth, code, color, fromError (+9 more)

### Community 111 - "privacy_policy_screen.dart"
Cohesion: 0.18
Nodes (10): build, _buildCard, _buildParagraph, _buildSection, _bullet, _effectiveDate, _launchSupport, PrivacyPolicyScreen (+2 more)

### Community 112 - "page_transitions.dart"
Cohesion: 0.18
Nodes (16): Duration?, FadeScaleRoute, FadeThroughRoute, FastKiranaPageTransitionsBuilder, page, SharedAxisRoute, SwiggyModalRoute, transitionDurationOverride (+8 more)

### Community 113 - "order_detail_screen.dart"
Cohesion: 0.12
Nodes (15): build, _buildBillRow, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor, _getStatusStepIndex, _makeCall (+7 more)

### Community 114 - "live_clock_badge.dart"
Cohesion: 0.13
Nodes (15): backgroundColor, borderColor, build, createState, dispose, fontSize, _formatTime, iconColor (+7 more)

### Community 115 - "voice_search_sheet.dart"
Cohesion: 0.12
Nodes (15): build, createState, dispose, _finishWithResult, _initAndStartSpeech, initState, _isListening, _liveTranscript (+7 more)

### Community 116 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 117 - "../providers/cart_provider.dart"
Cohesion: 0.13
Nodes (14): ../features/cart/cart_screen.dart, AnimatedCartBadge, badgeColor, build, child, onTap, textColor, bottomOffset (+6 more)

### Community 118 - "State"
Cohesion: 0.14
Nodes (21): SplashScreen, PaymentFailedCodSheet, _PaymentFailedCodSheetState, HomeCategoryToggle, _HomeCategoryToggleState, _AreaSearchModal, _AreaSearchModalState, MapPickerScreen (+13 more)

### Community 119 - "validators.dart"
Cohesion: 0.15
Nodes (12): ../config/app_config.dart, email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone (+4 more)

### Community 120 - "kot_print_service.dart"
Cohesion: 0.12
Nodes (15): DateTime?, extractRestaurantItems, formatKOTDate, generateKOTPdfDocument, KotPrintService, printKOTReceipt, _recentPrintTimestamps, sendRemoteKOTToKitchen (+7 more)

### Community 121 - "deep_link_service.dart"
Cohesion: 0.11
Nodes (18): AppLinks, _appLinks, DeepLinkService, dispose, _handleDeepLink, init, instance, _isInitialized (+10 more)

### Community 122 - "admin_login.dart"
Cohesion: 0.14
Nodes (14): ../admin/admin_dashboard.dart, ../data/models/user.dart, AdminLoginScreen, _AdminLoginScreenState, build, createState, dispose, _emailController (+6 more)

### Community 123 - "tracking_map_view.dart"
Cohesion: 0.10
Nodes (20): LatLng, OutletLocation, build, _buildArrow, _buildRouteStep, _buildZoomBtn, initialTarget, isDelivered (+12 more)

### Community 124 - "package:dio/dio.dart"
Cohesion: 0.11
Nodes (20): CartRepository, package:dio/dio.dart, package:fastkirana_flutter/core/utils/restaurant_utils.dart, package:fastkirana_flutter/data/models/cart.dart, package:fastkirana_flutter/data/models/product.dart, package:fastkirana_flutter/data/repositories/cart_repository.dart, package:fastkirana_flutter/providers/cart_provider.dart, main (+12 more)

### Community 125 - "../providers/address_provider.dart"
Cohesion: 0.12
Nodes (15): LocationDetails, AddressesScreen, build, _buildAddressCard, _iconForLabel, addressRepositoryProvider, build, driftDistanceKm (+7 more)

### Community 126 - "app_toast.dart"
Cohesion: 0.10
Nodes (21): AppToast, build, createState, _currentOverlay, _dismissTimer, _fallbackSnackBar, _GenZTopToastWidget, _GenZTopToastWidgetState (+13 more)

### Community 127 - "cart/cart.dart"
Cohesion: 0.15
Nodes (12): cart_screen.dart, widgets/cart_bill_details_card.dart, widgets/cart_bill_summary_card.dart, widgets/cart_bogo_widgets.dart, widgets/cart_bottom_checkout_bar.dart, widgets/cart_coupon_card.dart, widgets/cart_free_delivery_bar.dart, widgets/cart_item_card.dart (+4 more)

### Community 128 - "coupon_provider.dart"
Cohesion: 0.18
Nodes (11): ../data/models/coupon.dart, ../data/repositories/coupon_repository.dart, CouponRepository, AdminCouponsScreen, build, build, couponRepositoryProvider, couponsProvider (+3 more)

### Community 129 - "Map"
Cohesion: 0.08
Nodes (23): donut_capacity_painter.dart, build, isUpdating, onAcceptAndCook, onEditOrder, onMarkReady, onPrintKot, onReject (+15 more)

### Community 130 - "logger_service.dart"
Cohesion: 0.22
Nodes (8): debug, error, info, _logger, LoggerService, warning, package:logger/logger.dart, static final Logger

### Community 131 - "restaurant_menu_catalog_tab.dart"
Cohesion: 0.11
Nodes (18): bgMain, brandGreen, build, _buildMenuFilterChip, createState, dispose, menuItems, _menuSearchController (+10 more)

### Community 132 - "categoriesProvider"
Cohesion: 0.12
Nodes (25): _SplashScreenState, build, build, CategoryProductsScreen, _CategoryProductsScreenState, build, SubcategoryScreen, _SubcategoryScreenState (+17 more)

### Community 133 - "admin_order_card.dart"
Cohesion: 0.11
Nodes (18): bool?, OrderStatus, availableRiders, color, formatOrderTime, getStatusColor, icon, isKOTPrinted (+10 more)

### Community 134 - "doorstep_cashfree_qr_sheet.dart"
Cohesion: 0.10
Nodes (20): build, _cashfreeQrUrl, createState, _directUpiQrUrl, dispose, DoorstepCashfreeQrSheet, _DoorstepCashfreeQrSheetState, initState (+12 more)

### Community 135 - "restaurantsProvider"
Cohesion: 0.21
Nodes (12): build, build, build, _buildDarkstoreRecommendationsSection, CafeMenuScreen, _CafeMenuScreenState, _centerCategoryInHorizontalBar, restaurantAddonsProvider (+4 more)

### Community 136 - "banner_repository.dart"
Cohesion: 0.12
Nodes (15): design_system.dart, AppTheme, _pageTransitionsTheme, defaultBanners, dio, _diskBannersKey, _fetchFromNetwork, getBanners (+7 more)

### Community 137 - "store_hub_provider.dart"
Cohesion: 0.13
Nodes (14): address, customerLat, customerLng, distanceKm, hub, hubs, hubsAsync, isServiceable (+6 more)

### Community 138 - "dart:async"
Cohesion: 0.06
Nodes (29): AudioPlayer, bool get, Connectivity, dart:async, NetworkRetryHelper, _activeOrderId, _alarmLoopTimer, _audioPlayer (+21 more)

### Community 139 - "store_hub.dart"
Cohesion: 0.13
Nodes (14): city, defaultGhatampur, deliveryRadiusKm, fromJson, groceryOpen, id, isActive, latitude (+6 more)

### Community 140 - "offline_banner.dart"
Cohesion: 0.14
Nodes (15): ../core/utils/app_connectivity.dart, connectivityProvider, build, createState, dispose, OfflineBanner, _OfflineBannerState, offlineText (+7 more)

### Community 141 - "package:flutter/services.dart"
Cohesion: 0.10
Nodes (19): CartCelebrationModal, show, build, HomeEndOfAisleSearchCard, scrollController, AddReviewScreen, _AddReviewScreenState, build (+11 more)

### Community 142 - "supabase_service.dart"
Cohesion: 0.17
Nodes (11): _activeBroadcastChannels, broadcastRiderLocation, _client, initialize, _isInitialized, subscribeToAllOrdersRealtime, subscribeToOrderLocation, SupabaseService (+3 more)

### Community 143 - "brand_input.dart"
Cohesion: 0.17
Nodes (11): BrandInput, build, controller, hint, keyboardType, label, obscure, onSuffixTap (+3 more)

### Community 144 - "home_category_toggle.dart"
Cohesion: 0.08
Nodes (25): , Animation, AnimationController, build, _controller, createState, dispose, _fadeAnimation (+17 more)

### Community 145 - "cart_bill_details_card.dart"
Cohesion: 0.11
Nodes (18): build, CartBillDetailsCard, CartBillRow, couponDiscount, deliveryFee, freeGiftDetails, grandTotal, isBold (+10 more)

### Community 146 - "../core/routes/page_transitions.dart"
Cohesion: 0.06
Nodes (34): ../../categories/category_products_screen.dart, category_products_screen.dart, ../core/routes/page_transitions.dart, ../data/models/category.dart, home_end_of_aisle_search_card.dart, build, _categories, CategoriesScreen (+26 more)

### Community 147 - "splash/splash_screen.dart"
Cohesion: 0.08
Nodes (24): ../data/models/store_hub.dart, createState, dispose, _dynamicPlaceholders, HomeTopHeader, _HomeTopHeaderState, initState, _searchPlaceholderIndex (+16 more)

### Community 148 - "../../core/services/logger_service.dart"
Cohesion: 0.20
Nodes (9): ../../../../core/services/kot_print_service.dart, ../../core/services/logger_service.dart, ../../../core/utils/app_toast.dart, formatKitchenWhatsAppMessage, generateKOTText, ITEM, RestaurantKotModal, show (+1 more)

### Community 149 - "wishlist_screen.dart"
Cohesion: 0.18
Nodes (11): build, primaryRed, _shareApp, _shareWishlist, slateDark, slateMuted, WishlistScreen, wishlistProvider (+3 more)

### Community 152 - "app_flavor.dart"
Cohesion: 0.15
Nodes (12): AppFlavor, appTitle, baseUrl, flavor, FlavorConfig, initialize, _instance, isCustomer (+4 more)

### Community 153 - "cafe_offers_strip.dart"
Cohesion: 0.20
Nodes (10): Restaurant, build, _buildFallbackOfferTicket, _buildOfferTicketCard, CafeOffersStrip, currentRestaurant, restaurantId, restaurantCouponsProvider (+2 more)

### Community 154 - "app_confirmation_dialog.dart"
Cohesion: 0.11
Nodes (18): AppConfirmationDialog, build, cancelLabel, ConfirmationDialogType, confirmIcon, confirmLabel, contentWidget, icon (+10 more)

### Community 155 - "grid_skeletons.dart"
Cohesion: 0.09
Nodes (20): EdgeInsets, BrandCard, build, child, elevated, margin, onTap, padding (+12 more)

### Community 156 - "order_recipient_helper.dart"
Cohesion: 0.18
Nodes (10): @immutable, buyerName, buyerPhone, deliveryInstructions, fromOrder, fullRecipientLabel, isOrderForSomeone, OrderRecipientDetails (+2 more)

### Community 157 - "models.dart"
Cohesion: 0.20
Nodes (9): address.dart, cart.dart, category.dart, order.dart, product.dart, restaurant.dart, store_hub.dart, store_settings.dart (+1 more)

### Community 158 - "main.dart"
Cohesion: 0.15
Nodes (12): core/routes/app_router.dart, core/services/deep_link_service.dart, ../core/services/notification_service.dart, ../core/services/supabase_service.dart, core/theme/app_theme.dart, firebase_options.dart, build, FastKiranaApp (+4 more)

### Community 159 - "admin_coupon_detail.dart"
Cohesion: 0.13
Nodes (13): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, build, couponId, createState, _infoRow, _isActive, build (+5 more)

### Community 160 - "orders.dart"
Cohesion: 0.20
Nodes (9): order_tracking_screen.dart, widgets/tracking_cancel_card.dart, widgets/tracking_map_view.dart, widgets/tracking_payment_card.dart, widgets/tracking_preparing_card.dart, widgets/tracking_receipt_card.dart, widgets/tracking_review_card.dart, widgets/tracking_rider_card.dart (+1 more)

### Community 161 - "app_update_dialog.dart"
Cohesion: 0.18
Nodes (10): AppUpdateDialog, build, checkAndShow, _handleUpdate, _hasPromptedThisSession, isForced, message, targetVersion (+2 more)

### Community 162 - "auth/delivery_login.dart"
Cohesion: 0.13
Nodes (14): ../delivery/delivery_dashboard.dart, brandGreen, build, createState, DeliveryLoginScreen, dispose, _errorMessage, _isLoading (+6 more)

### Community 163 - "package:flutter_bounceable/flutter_bounceable.dart"
Cohesion: 0.06
Nodes (28): ../../../core/services/battery_optimization_service.dart, CartItem, RestaurantPrepTimeModal, show, build, CartItemCard, item, onDecrement (+20 more)

### Community 164 - "cart_coupon_card.dart"
Cohesion: 0.12
Nodes (16): ../coupons_screen.dart, appliedCoupon, bogoBadgeText, build, CartCouponCard, _CartCouponCardState, controller, couponDiscount (+8 more)

### Community 165 - "cart_savings_banner.dart"
Cohesion: 0.20
Nodes (9): appliedCoupon, build, CartSavingsBanner, couponDiscount, freeDeliveryThreshold, onApplyCouponTap, onRemoveCouponTap, subtotal (+1 more)

### Community 166 - "cart_bottom_checkout_bar.dart"
Cohesion: 0.15
Nodes (12): ../auth/login_screen.dart, ../../checkout/checkout_screen.dart, appliedCoupon, build, cookingInstruction, couponDiscount, deliveryFee, grandTotal (+4 more)

### Community 167 - "biometric_service.dart"
Cohesion: 0.25
Nodes (7): _auth, authenticate, BiometricService, getAvailableBiometrics, isBiometricAvailable, package:local_auth/local_auth.dart, static final LocalAuthentication

### Community 169 - "cafe_reviews_tab.dart"
Cohesion: 0.15
Nodes (14): AsyncValue, build, CafeReviewsTab, _formatDate, restaurantId, restaurantName, reviewsAsync, AddressesNotifier (+6 more)

### Community 170 - "cafe.dart"
Cohesion: 0.25
Nodes (7): cafe_menu_screen.dart, models/cafe_menu_section.dart, restaurant_dashboard.dart, widgets/cafe_offers_strip.dart, widgets/cafe_reviews_tab.dart, widgets/restaurant_metrics_bar.dart, widgets/restaurant_order_card_view.dart

### Community 171 - "checkout_payment_selector_sheet.dart"
Cohesion: 0.14
Nodes (14): build, CheckoutPaymentSelectorSheet, _CheckoutPaymentSelectorSheetState, createState, grandTotal, initialPayment, initState, isPlacingOrder (+6 more)

### Community 172 - "tracking_widgets_test.dart"
Cohesion: 0.18
Nodes (8): package:fastkirana_flutter/data/models/order.dart, package:fastkirana_flutter/features/delivery/widgets/connectivity_banner.dart, package:fastkirana_flutter/features/orders/widgets/tracking_payment_card.dart, package:fastkirana_flutter/features/orders/widgets/tracking_receipt_card.dart, package:fastkirana_flutter/features/orders/widgets/tracking_status_stepper.dart, main, main, main

### Community 173 - "List"
Cohesion: 0.33
Nodes (6): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState, List

### Community 174 - "unserviceable_location_banner.dart"
Cohesion: 0.15
Nodes (14): ../features/location/delivery_location_screen.dart, deliveryTierProvider, _buildCartScreenContent, build, build, createState, dispose, distanceKm (+6 more)

### Community 175 - "rider_pickup_card.dart"
Cohesion: 0.15
Nodes (12): brandGreen, build, emeraldGreen, EmptyPendingPickupCard, isUpdating, order, primaryRed, RiderPickupCard (+4 more)

### Community 176 - "../core/utils/restaurant_utils.dart"
Cohesion: 0.08
Nodes (22): ../core/utils/restaurant_utils.dart, CachedMapTileProvider, customHeaders, getImage, build, _buildCookingInstructions, CartItemsSection, cookingInstructionsController (+14 more)

### Community 177 - "../core/theme/responsive.dart"
Cohesion: 0.11
Nodes (16): ../core/theme/responsive.dart, build, TrackingCancelCard, build, isProcessingPayment, onPayOnline, onSwitchToCOD, order (+8 more)

### Community 178 - "notifications_screen.dart"
Cohesion: 0.18
Nodes (11): ../data/repositories/order_repository.dart, _buildNotificationTile, createState, _formatTimeAgo, initState, _isLoading, _loadData, NotificationsScreen (+3 more)

### Community 179 - "dart:convert"
Cohesion: 0.17
Nodes (11): dart:convert, clearQueue, enqueueAction, flushQueue, getPendingCount, hasPendingActions, OfflineSyncService, queueAdmin (+3 more)

### Community 180 - "brand_logo.dart"
Cohesion: 0.20
Nodes (9): BrandLogo, build, FastKiranaLogoPainter, FastKiranaLogoWidget, paint, shouldRepaint, size, textColor (+1 more)

### Community 181 - "categories_screen.dart"
Cohesion: 0.22
Nodes (8): CategoriesScreen, build, _CategoriesScreenState, createState, dispose, _searchController, _searchQuery, TextEditingController

### Community 182 - "Color"
Cohesion: 0.22
Nodes (8): Color, DonutCapacityPainter, paint, percent, progressColor, shouldRepaint, strokeWidth, trackColor

### Community 183 - "admin_stat_card.dart"
Cohesion: 0.18
Nodes (10): IconData?, AdminStatCard, bgColor, borderColor, build, icon, iconColor, subtitle (+2 more)

### Community 184 - "../data/models/product.dart"
Cohesion: 0.13
Nodes (13): ../data/models/product.dart, ProductRestaurantExtension, Product, build, RecentlyViewedScreen, build, CartConflictDialog, existingOutletName (+5 more)

### Community 185 - "../core/config/app_config.dart"
Cohesion: 0.18
Nodes (10): ../core/config/app_config.dart, _buildPayOnlineCard, build, _navigateToReview, order, TrackingReviewCard, build, build (+2 more)

### Community 186 - "cart_bill_summary_card.dart"
Cohesion: 0.18
Nodes (10): build, _buildRow, CartBillSummaryCard, couponDiscount, deliveryFee, grandTotal, handlingFee, itemTotal (+2 more)

### Community 187 - "battery_optimization_service.dart"
Cohesion: 0.22
Nodes (8): dart:io, BatteryOptimizationService, markDismissed, _prefKeyDismissed, requestExemption, shouldShowPrompt, package:permission_handler/permission_handler.dart, static const String

### Community 188 - "admin_stats_grid.dart"
Cohesion: 0.20
Nodes (9): admin_stat_card.dart, AdminStatsGrid, build, displayActiveOrderCount, displayTodayDeliveryFee, displayTodayNetSales, displayTodayOrdersCount, displayTodayPackagingFee (+1 more)

### Community 189 - "map_marker_generator.dart"
Cohesion: 0.20
Nodes (9): dart:ui, _cache, createCustomMarkerBitmap, createRiderMarkerBitmap, initCustomMarkers, MapMarkerGenerator, _renderCanvasToBitmap, package:google_maps_flutter/google_maps_flutter.dart (+1 more)

### Community 190 - "sponsored_ad_card.dart"
Cohesion: 0.20
Nodes (9): actionText, build, discountText, imageUrl, onTap, promoCode, SponsoredAdCard, subtitle (+1 more)

### Community 191 - "delivery_orders_tab.dart"
Cohesion: 0.22
Nodes (8): activeDeliveries, build, DeliveryOrdersTab, pendingPickups, slateDark, updatingOrderId, rider_active_delivery_card.dart, rider_pickup_card.dart

### Community 192 - "restaurant_login.dart"
Cohesion: 0.29
Nodes (7): ../cafe/restaurant_dashboard.dart, build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 193 - "dart:math"
Cohesion: 0.25
Nodes (7): dart:math, build, completed, DeliveryHistoryTab, slateDark, slateMuted, package:intl/intl.dart

### Community 194 - "geo_math_utils.dart"
Cohesion: 0.22
Nodes (8): adaptiveJitterThreshold, calculateBearing, estimateEtaWeightedAverage, GeoMathUtils, getHaversineDistance, _gpsHistory, interpolateHeading, static final List

### Community 195 - "package:flutter/foundation.dart"
Cohesion: 0.25
Nodes (7): android, DefaultFirebaseOptions, ios, web, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 196 - "_RestaurantsListScreenState"
Cohesion: 0.43
Nodes (8): build, _RestaurantsListScreenState, filteredRestaurantsProvider, offersFilterProvider, pureVegFilterProvider, ratingFilterProvider, restaurantSearchQueryProvider, selectedCuisineProvider

### Community 197 - "core_components_widget_test.dart"
Cohesion: 0.12
Nodes (13): package:fastkirana_flutter/core/config/app_config.dart, package:fastkirana_flutter/core/services/location_service.dart, package:fastkirana_flutter/data/models/store_settings.dart, package:fastkirana_flutter/features/admin/widgets/admin_stats_grid.dart, package:fastkirana_flutter/features/cart/widgets/cart_bill_details_card.dart, package:fastkirana_flutter/features/cart/widgets/cart_free_delivery_bar.dart, package:fastkirana_flutter/features/checkout/widgets/checkout_bottom_bar.dart, package:fastkirana_flutter/features/checkout/widgets/checkout_savings_banner.dart (+5 more)

### Community 198 - "checkout_bottom_bar.dart"
Cohesion: 0.25
Nodes (7): build, CheckoutBottomBar, grandTotal, isPlacingOrder, onProceedToPay, slateDark, slateMuted

### Community 199 - "admin_notification_service.dart"
Cohesion: 0.29
Nodes (6): AdminNotificationService, fireAdminWhatsAppAlert, formatOrderWhatsAppMessage, formatRestaurantKOTMessage, sendSubstitutionWhatsApp, logger_service.dart

### Community 200 - "String?"
Cohesion: 0.29
Nodes (6): build, onSeeAll, SectionHeader, subtitle, title, String?

### Community 202 - "static const Color"
Cohesion: 0.29
Nodes (6): AdminOrdersEmptyView, build, isLive, onRefresh, primaryRed, static const Color

### Community 203 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile, privacy_policy_screen.dart

### Community 205 - "Order"
Cohesion: 0.33
Nodes (6): @JsonSerializable, Cart, _, Order, OrderItem, AuthResponse

### Community 206 - "TickerProviderStateMixin"
Cohesion: 0.67
Nodes (3): ContextualBrandTransitionScreen, _ContextualBrandTransitionScreenState, TickerProviderStateMixin

## Knowledge Gaps
- **3290 isolated node(s):** `AppConfig`, `primaryApiUrl`, `secondaryApiUrl`, `apiBaseUrl`, `webStorefrontUrl` (+3285 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dioProvider` connect `dioProvider` to `restaurant_dashboard.dart`, `checkout_screen.dart`, `doorstep_cashfree_qr_sheet.dart`, `orders_screen.dart`, `package:flutter/services.dart`, `cart_screen.dart`, `cartProvider`, `app_router.dart`, `main_shell.dart`, `otp_screen.dart`, `admin_orders_list.dart`, `api_client.dart`, `order_success_screen.dart`, `admin_products.dart`, `notifications_screen.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `delivery_dashboard.dart`, `ConsumerState`, `selectedAddressProvider`, `authProvider`, `order_edit_modal.dart`, `admin_dashboard.dart`, `picker_dashboard.dart`, `add_picker_product_modal.dart`, `add_restaurant_product_modal.dart`, `storeSettingsProvider`, `admin_login.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `Product` connect `../data/models/product.dart` to `product_detail_screen.dart`, `product.dart`, `variant_selector_sheet.dart`, `product_card.dart`, `models/cart.dart`, `admin_products.dart`, `cartProvider`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **Why does `StoreHub` connect `store_hub.dart` to `store_hub_provider.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `AppConfig`, `primaryApiUrl`, `secondaryApiUrl` to the rest of the system?**
  _3290 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.00980392156862745 - nodes in this community are weakly interconnected._
- **Should `restaurant_dashboard.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.040726817042606514 - nodes in this community are weakly interconnected._