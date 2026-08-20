# Graph Report - fastkirana_flutter  (2026-08-20)

## Corpus Check
- 126 files · ~897,657 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1336 nodes · 1954 edges · 91 communities (86 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `691de082`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- design_system.dart
- brand_design_system.dart
- checkout_screen.dart
- home_screen.dart
- cafe_menu_screen.dart
- order.dart
- product.dart
- orders_screen.dart
- brand_input.dart
- api_endpoints.dart
- product_card.dart
- table_booking_screen.dart
- notification_service.dart
- app_colors.dart
- cart_screen.dart
- cart.dart
- restaurant.dart
- categories_screen.dart
- cartProvider
- List
- user.dart
- app_router.dart
- package:flutter/services.dart
- otp_screen.dart
- ../core/network/api_client.dart
- ../data/models/product.dart
- admin_login.dart
- login_screen.dart
- ../core/theme/design_system.dart
- package:flutter/material.dart
- category_products_screen.dart
- profile_screen.dart
- StatelessWidget
- package:google_fonts/google_fonts.dart
- ../../widgets/brand_button.dart
- add_address_screen.dart
- search_screen.dart
- product_detail_screen.dart
- cart_repository.dart
- category.dart
- coupon.dart
- auth_provider.dart
- State
- onboarding_screen.dart
- auth/splash_screen.dart
- @JsonSerializable
- api_client.dart
- restaurant_card.dart
- banner.dart
- order_success_screen.dart
- splash/splash_screen.dart
- manifest.json
- product_repository.dart
- auth_repository.dart
- subcategory_screen.dart
- order_repository.dart
- restaurant_repository.dart
- address_repository.dart
- delivery_dashboard.dart
- add_review_screen.dart
- address_book_screen.dart
- auth/delivery_login.dart
- restaurant_login.dart
- delivery/delivery_login.dart
- settings_screen.dart
- about_screen.dart
- admin_coupon_detail.dart
- admin_dashboard.dart
- admin_reports.dart
- subscriptions_screen.dart
- brand_logo.dart
- categories_list_screen.dart
- ConsumerStatefulWidget
- admin_settings.dart
- delivery_profile.dart
- order_tracking_screen.dart
- help_support_screen.dart
- ConsumerState
- restaurant_analytics.dart
- delivery_earnings_screen.dart
- delivery_order_detail.dart
- picker_dashboard.dart
- wallet/wallet_screen.dart
- MainActivity.kt
- package:flutter_riverpod/flutter_riverpod.dart
- fastkirana_flutter
- product_providers.dart
- @fastkirana

## God Nodes (most connected - your core abstractions)
1. `cartProvider` - 25 edges
2. `_HomeScreenState` - 8 edges
3. `selectedTabProvider` - 7 edges
4. `dioProvider` - 6 edges
5. `_OrdersScreenState` - 6 edges
6. `_OtpScreenState` - 5 edges
7. `_CafeMenuScreenState` - 5 edges
8. `_CategoryProductsScreenState` - 5 edges
9. `_SearchScreenState` - 5 edges
10. `authProvider` - 5 edges

## Surprising Connections (you probably didn't know these)
- `_handleResend` --references--> `dioProvider`  [EXTRACTED]
  lib/features/auth/otp_screen.dart → lib/core/network/api_client.dart
- `_handleVerifyOtp` --references--> `dioProvider`  [EXTRACTED]
  lib/features/auth/otp_screen.dart → lib/core/network/api_client.dart
- `_OtpScreenState` --references--> `dioProvider`  [EXTRACTED]
  lib/features/auth/otp_screen.dart → lib/core/network/api_client.dart
- `_OtpScreenState` --references--> `authProvider`  [EXTRACTED]
  lib/features/auth/otp_screen.dart → lib/providers/auth_provider.dart
- `_CafeMenuScreenState` --references--> `cartProvider`  [EXTRACTED]
  lib/features/cafe/cafe_menu_screen.dart → lib/providers/cart_provider.dart

## Import Cycles
- None detected.

## Communities (91 total, 5 thin omitted)

### Community 0 - "design_system.dart"
Cohesion: 0.03
Nodes (68): accent, accentDark, accentGradient, accentLight, AppDesignSystem, background, border, borderLight (+60 more)

### Community 1 - "brand_design_system.dart"
Cohesion: 0.04
Nodes (53): accent, accentDark, accentLight, background, border, borderLight, BrandColors, BrandShadows (+45 more)

### Community 2 - "checkout_screen.dart"
Cohesion: 0.05
Nodes (42): AsyncValue, auth_provider.dart, ../data/models/cart.dart, ../data/repositories/cart_repository.dart, _addresses, _buildBillSummary, _buildBottomSliderBar, _buildDeliveryAddressSection (+34 more)

### Community 3 - "home_screen.dart"
Cohesion: 0.05
Nodes (42): ../cafe/cafe_menu_screen.dart, dart:async, _bannerController, _bannerTimer, _buildCategoryToggle, _buildCuratedForYouFilter, _buildFoodBanner, _buildFoodCuisineCategories (+34 more)

### Community 4 - "cafe_menu_screen.dart"
Cohesion: 0.05
Nodes (41): ../data/repositories/restaurant_repository.dart, build, CafeCategorySection, CafeMenuScreen, _CafeMenuScreenState, _categories, createState, dispose (+33 more)

### Community 5 - "order.dart"
Cohesion: 0.05
Nodes (41): cod,
  upi,, confirmed,
  packed,
  shipped,
  delivered,, addressId, cancelled, card, confirmedAt, couponCode, createdAt (+33 more)

### Community 6 - "product.dart"
Cohesion: 0.05
Nodes (41): availableEndTime, availableStartTime, bannerUrl, barcode, category, categoryId, CategoryInfo, costPrice (+33 more)

### Community 7 - "orders_screen.dart"
Cohesion: 0.06
Nodes (37): ../../core/utils/validators.dart, ../../data/models/order.dart, build, _buildBillRow, _buildStatusHeaderCard, _buildTimelineStep, _getStatusBg, _getStatusColor (+29 more)

### Community 8 - "brand_input.dart"
Cohesion: 0.06
Nodes (33): Color?, EdgeInsets?, IconData, backgroundColor, BrandButton, build, fullWidth, gradientEnd (+25 more)

### Community 9 - "api_endpoints.dart"
Cohesion: 0.06
Nodes (33): apiBaseUrl, AppConfig, appIconAsset, darkstoreAddress, darkstoreLat, darkstoreLng, defaultAdminEmail, defaultAdminPassword (+25 more)

### Community 10 - "product_card.dart"
Cohesion: 0.06
Nodes (32): double?, ../features/products/product_detail_screen.dart, area, city, fromJson, fullAddress, houseNo, id (+24 more)

### Community 11 - "table_booking_screen.dart"
Cohesion: 0.07
Nodes (29): ../../data/repositories/order_repository.dart, email, formatDate, formatPrice, getImageUrl, Helpers, otp, phone (+21 more)

### Community 12 - "notification_service.dart"
Cohesion: 0.07
Nodes (27): AndroidFlutterLocalNotificationsPlugin, @pragma, core/routes/app_router.dart, ../core/services/notification_service.dart, core/theme/app_theme.dart, dart:io, FirebaseMessaging, FlutterLocalNotificationsPlugin (+19 more)

### Community 13 - "app_colors.dart"
Cohesion: 0.08
Nodes (23): accent, accentLight, accentOrange, AppColors, background, border, borderLight, card (+15 more)

### Community 14 - "cart_screen.dart"
Cohesion: 0.09
Nodes (21): ../checkout/checkout_screen.dart, ../data/repositories/product_repository.dart, _appliedCoupon, _applyCoupon, _buildBillRow, _buildEmptyState, CartScreen, _CartScreenState (+13 more)

### Community 15 - "cart.dart"
Cohesion: 0.09
Nodes (22): double get, appliedCouponCode, cartId, couponDiscount, createdAt, fromJson, id, items (+14 more)

### Community 16 - "restaurant.dart"
Cohesion: 0.09
Nodes (21): address, bannerUrl, city, cuisineTags, deliveryTime, description, discountBadge, discountOffer (+13 more)

### Community 17 - "categories_screen.dart"
Cohesion: 0.11
Nodes (18): CategoriesScreen, ../data/models/category.dart, ProductRepository, build, _buildCategoryCard, _CategoriesScreenState, createState, dispose (+10 more)

### Community 18 - "cartProvider"
Cohesion: 0.13
Nodes (20): _buildFoodItemCard, build, _buildCartContent, _buildCartItemRow, build, build, build, _handlePlaceOrder (+12 more)

### Community 19 - "List"
Cohesion: 0.11
Nodes (15): build, _restaurants, RestaurantsListScreen, build, _coupons, CouponsScreen, build, _notifications (+7 more)

### Community 20 - "user.dart"
Cohesion: 0.12
Nodes (16): bool get, blockReason, createdAt, email, fromJson, id, image, isAdmin (+8 more)

### Community 21 - "app_router.dart"
Cohesion: 0.12
Nodes (16): ../../features/auth/login_screen.dart, ../../features/auth/otp_screen.dart, ../../features/cart/cart_screen.dart, ../../features/categories/categories_screen.dart, ../../features/categories/category_products_screen.dart, ../../features/checkout/checkout_screen.dart, ../../features/home/main_shell.dart, ../../features/orders/order_detail_screen.dart (+8 more)

### Community 22 - "package:flutter/services.dart"
Cohesion: 0.15
Nodes (15): ../categories/categories_screen.dart, ConsumerWidget, dart:ui, home_screen.dart, _buildHeader, build, _buildLiquidBottomNav, MainShell (+7 more)

### Community 23 - "otp_screen.dart"
Cohesion: 0.13
Nodes (15): ../../core/constants/app_colors.dart, build, createState, dispose, _focusNodes, identifier, initState, _isLoading (+7 more)

### Community 24 - "../core/network/api_client.dart"
Cohesion: 0.16
Nodes (14): ../core/network/api_client.dart, ../data/models/address.dart, ../data/repositories/address_repository.dart, AddressRepository, AddressesScreen, build, _buildAddressCard, _iconForLabel (+6 more)

### Community 25 - "../data/models/product.dart"
Cohesion: 0.17
Nodes (12): ../data/models/product.dart, build, ComboBuilderScreen, build, RecentlyViewedScreen, build, wishlistProvider, WishlistScreen (+4 more)

### Community 26 - "admin_login.dart"
Cohesion: 0.14
Nodes (14): ../admin/admin_dashboard.dart, ../../core/config/app_config.dart, AdminLoginScreen, _AdminLoginScreenState, build, createState, dispose, _emailController (+6 more)

### Community 27 - "login_screen.dart"
Cohesion: 0.15
Nodes (14): admin_login.dart, ../../data/repositories/auth_repository.dart, dioProvider, build, createState, dispose, _isLoading, LoginScreen (+6 more)

### Community 28 - "../core/theme/design_system.dart"
Cohesion: 0.13
Nodes (11): ../core/theme/design_system.dart, AdminCustomersScreen, build, build, RestaurantTableBookingListScreen, build, DeliveryHistoryScreen, build (+3 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (11): build, EmptyCartScreen, build, _corner, PickerScanScreen, build, EmptyWishlistScreen, package:fastkirana_flutter/main.dart (+3 more)

### Community 30 - "category_products_screen.dart"
Cohesion: 0.14
Nodes (14): _buildFilterPill, category, CategoryProductsScreen, _CategoryProductsScreenState, createState, dispose, primaryRed, _searchController (+6 more)

### Community 31 - "profile_screen.dart"
Cohesion: 0.15
Nodes (13): address_book_screen.dart, _handleVerifyOtp, build, _buildMenuItem, primaryRed, ProfileScreen, authProvider, notifications_screen.dart (+5 more)

### Community 32 - "StatelessWidget"
Cohesion: 0.16
Nodes (13): BorderRadius?, BannerSkeleton, borderRadius, build, CategorySkeleton, _controller, createState, dispose (+5 more)

### Community 33 - "package:google_fonts/google_fonts.dart"
Cohesion: 0.14
Nodes (10): ../constants/app_colors.dart, design_system.dart, AppTheme, AdminBannersScreen, build, AdminOrdersScreen, build, build (+2 more)

### Community 34 - "../../widgets/brand_button.dart"
Cohesion: 0.14
Nodes (10): AdminCouponsScreen, build, AdminProductsScreen, build, build, RestaurantDashboard, _rStat, build (+2 more)

### Community 35 - "add_address_screen.dart"
Cohesion: 0.15
Nodes (13): AddAddressScreen, _AddAddressScreenState, _areaController, build, _buildField, _cityController, createState, _houseController (+5 more)

### Community 36 - "search_screen.dart"
Cohesion: 0.16
Nodes (13): _buildSearchResults, _buildTrendingAndRecent, _controller, createState, dispose, _onSearchTermSelected, _query, _recentSearches (+5 more)

### Community 37 - "product_detail_screen.dart"
Cohesion: 0.17
Nodes (11): ../cart/cart_screen.dart, Product, _buildQualityRow, createState, _isFavorite, primaryRed, product, ProductDetailScreen (+3 more)

### Community 38 - "cart_repository.dart"
Cohesion: 0.15
Nodes (12): dart:convert, addItem, applyCoupon, CartRepository, dio, getCart, getLocalCart, _handleError (+4 more)

### Community 39 - "category.dart"
Cohesion: 0.15
Nodes (12): int get, count, fromJson, id, imageUrl, name, parentId, productCount (+4 more)

### Community 40 - "coupon.dart"
Cohesion: 0.15
Nodes (12): categoryId, code, DiscountType, expiresAt, fromJson, id, isActive, maxDiscount (+4 more)

### Community 41 - "auth_provider.dart"
Cohesion: 0.17
Nodes (11): ../data/models/user.dart, auth, clear, currentUserProvider, _load, maybeWhen, _ref, setUser (+3 more)

### Community 42 - "State"
Cohesion: 0.20
Nodes (12): AdminCouponsDetailScreen, _AdminCouponsDetailScreenState, SplashScreen, _SplashScreenState, _SplashScreenState, ShimmerBox, _ShimmerBoxState, SingleTickerProviderStateMixin (+4 more)

### Community 43 - "onboarding_screen.dart"
Cohesion: 0.18
Nodes (11): build, createState, _currentPage, dispose, _navigateToLogin, OnboardingScreen, _OnboardingScreenState, _pageController (+3 more)

### Community 44 - "auth/splash_screen.dart"
Cohesion: 0.18
Nodes (10): Animation, AnimationController, ../auth/otp_screen.dart, build, _controller, createState, dispose, _fadeAnimation (+2 more)

### Community 45 - "@JsonSerializable"
Cohesion: 0.18
Nodes (11): @JsonSerializable, Address, Banner, Cart, CartItem, CategoryCount, Coupon, Order (+3 more)

### Community 46 - "api_client.dart"
Cohesion: 0.18
Nodes (10): ../config/app_config.dart, Exception, int?, ApiException, dio, message, statusCode, toString (+2 more)

### Community 47 - "restaurant_card.dart"
Cohesion: 0.20
Nodes (10): ../data/models/restaurant.dart, ../features/cafe/cafe_menu_screen.dart, Restaurant, build, createState, _isFavorite, onTap, restaurant (+2 more)

### Community 48 - "banner.dart"
Cohesion: 0.18
Nodes (10): fromJson, id, imageUrl, isActive, link, sortOrder, subtitle, title (+2 more)

### Community 49 - "order_success_screen.dart"
Cohesion: 0.18
Nodes (10): build, _buildDetailRow, deliveryAddress, orderId, OrderSuccessScreen, paymentMethod, primaryRed, successGreen (+2 more)

### Community 50 - "splash/splash_screen.dart"
Cohesion: 0.18
Nodes (10): build, createState, dispose, initState, _logoController, _logoScale, _navigateToNextScreen, _textController (+2 more)

### Community 51 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 52 - "product_repository.dart"
Cohesion: 0.20
Nodes (9): DateTime, _cachedProducts, dio, _filterProducts, getCategories, getProduct, getProducts, _lastFetchTime (+1 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.20
Nodes (9): AuthRepository, dio, getProfile, _handleError, login, sendOtp, signup, verifyOtp (+1 more)

### Community 54 - "subcategory_screen.dart"
Cohesion: 0.25
Nodes (8): Category, category, createState, _selectedSubIdx, _subcategories, SubcategoryScreen, _SubcategoryScreenState, ../../providers/product_provider.dart

### Community 55 - "order_repository.dart"
Cohesion: 0.22
Nodes (8): cancelOrder, dio, getOrder, getOrders, _handleError, OrderRepository, placeOrder, ../models/order.dart

### Community 56 - "restaurant_repository.dart"
Cohesion: 0.25
Nodes (7): Dio, _dio, getRestaurantMenu, getRestaurants, RestaurantRepository, ../models/product.dart, ../models/restaurant.dart

### Community 57 - "address_repository.dart"
Cohesion: 0.25
Nodes (7): createAddress, deleteAddress, dio, getAddresses, _handleError, ../models/address.dart, package:dio/dio.dart

### Community 58 - "delivery_dashboard.dart"
Cohesion: 0.29
Nodes (7): build, createState, DeliveryDashboard, _DeliveryDashboardState, _isOnline, _orderCard, _statCard

### Community 59 - "add_review_screen.dart"
Cohesion: 0.29
Nodes (7): AddReviewScreen, _AddReviewScreenState, build, createState, productName, _rating, _reviewController

### Community 60 - "address_book_screen.dart"
Cohesion: 0.29
Nodes (7): AddressBookScreen, _AddressBookScreenState, _addresses, build, _buildEmptyState, createState, ../../widgets/brand_input.dart

### Community 61 - "auth/delivery_login.dart"
Cohesion: 0.29
Nodes (6): build, createState, _isLoading, _otpController, _phoneController, _showOtp

### Community 62 - "restaurant_login.dart"
Cohesion: 0.33
Nodes (6): build, createState, _emailController, _passwordController, RestaurantLoginScreen, _RestaurantLoginScreenState

### Community 63 - "delivery/delivery_login.dart"
Cohesion: 0.29
Nodes (6): build, createState, _isLoading, _otpController, _phoneController, _showOtp

### Community 64 - "settings_screen.dart"
Cohesion: 0.29
Nodes (6): build, _divider, _navTile, _sectionHeader, SettingsScreen, _switchTile

### Community 65 - "about_screen.dart"
Cohesion: 0.33
Nodes (5): AboutScreen, build, _divider, _linkItem, _statBox

### Community 66 - "admin_coupon_detail.dart"
Cohesion: 0.33
Nodes (5): build, couponId, createState, _infoRow, _isActive

### Community 67 - "admin_dashboard.dart"
Cohesion: 0.33
Nodes (5): _actionBtn, AdminDashboard, build, _orderCard, _statCard

### Community 68 - "admin_reports.dart"
Cohesion: 0.33
Nodes (5): AdminReportsScreen, _breakdownRow, build, _reportStat, _topRow

### Community 69 - "subscriptions_screen.dart"
Cohesion: 0.40
Nodes (5): build, createState, _subscriptions, SubscriptionsScreen, _SubscriptionsScreenState

### Community 70 - "brand_logo.dart"
Cohesion: 0.33
Nodes (5): BrandLogo, build, size, variant, withText

### Community 71 - "categories_list_screen.dart"
Cohesion: 0.40
Nodes (4): category_products_screen.dart, build, _categories, CategoriesScreen

### Community 72 - "ConsumerStatefulWidget"
Cohesion: 0.40
Nodes (5): ConsumerStatefulWidget, DeliveryLoginScreen, CategoriesScreen, DeliveryLoginScreen, SplashScreen

### Community 73 - "admin_settings.dart"
Cohesion: 0.40
Nodes (4): AdminSettingsScreen, build, _divider, _switchTile

### Community 74 - "delivery_profile.dart"
Cohesion: 0.40
Nodes (4): build, DeliveryProfileScreen, _divider, _menuTile

### Community 75 - "order_tracking_screen.dart"
Cohesion: 0.40
Nodes (4): build, orderId, OrderTrackingScreen, _statusRow

### Community 76 - "help_support_screen.dart"
Cohesion: 0.40
Nodes (4): build, _faqItem, HelpSupportScreen, package:url_launcher/url_launcher.dart

### Community 77 - "ConsumerState"
Cohesion: 0.67
Nodes (4): ConsumerState, DeliveryLoginScreen, _DeliveryLoginScreenState, _DeliveryLoginScreenState

### Community 78 - "restaurant_analytics.dart"
Cohesion: 0.50
Nodes (3): build, _miniCard, RestaurantAnalyticsScreen

### Community 79 - "delivery_earnings_screen.dart"
Cohesion: 0.50
Nodes (3): build, DeliveryEarningsScreen, _earnStat

### Community 80 - "delivery_order_detail.dart"
Cohesion: 0.50
Nodes (3): build, DeliveryOrderDetailScreen, orderId

### Community 81 - "picker_dashboard.dart"
Cohesion: 0.50
Nodes (3): build, PickerDashboard, _statCard

### Community 82 - "wallet/wallet_screen.dart"
Cohesion: 0.50
Nodes (3): _action, build, WalletScreen

## Knowledge Gaps
- **871 isolated node(s):** `AppConfig`, `apiBaseUrl`, `webStorefrontUrl`, `appIconAsset`, `exactLogoAsset` (+866 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Category` connect `subcategory_screen.dart` to `@JsonSerializable`, `category_products_screen.dart`, `category.dart`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `Product` connect `product_detail_screen.dart` to `product_card.dart`, `product.dart`, `cart.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `cartProvider` connect `cartProvider` to `checkout_screen.dart`, `home_screen.dart`, `cafe_menu_screen.dart`, `product_detail_screen.dart`, `search_screen.dart`, `orders_screen.dart`, `product_card.dart`, `cart_screen.dart`, `package:flutter/services.dart`, `category_products_screen.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `AppConfig`, `apiBaseUrl`, `webStorefrontUrl` to the rest of the system?**
  _871 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.028985507246376812 - nodes in this community are weakly interconnected._
- **Should `brand_design_system.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Should `checkout_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04756871035940803 - nodes in this community are weakly interconnected._