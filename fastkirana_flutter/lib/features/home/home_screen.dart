import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/order.dart';
import '../../data/models/store_settings.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/brand_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../categories/category_products_screen.dart';
import '../search/search_screen.dart';
import '../profile/notifications_screen.dart';
import '../location/delivery_location_screen.dart';
import '../orders/orders_screen.dart';
import '../../widgets/voice_search_sheet.dart';
import '../../widgets/unserviceable_location_banner.dart';
import 'main_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGrocerySelected = true;
  int _selectedFilterIndex = 0;
  int _searchPlaceholderIndex = 0;
  Timer? _searchTimer;
  Timer? _orderSyncTimer;

  static const List<String> _searchPlaceholders = [
    'Search "atta"',
    'Search "milk"',
    'Search "maggi"',
    'Search "fortune oil"',
    'Search "dairy milk"',
    'Search "chips"',
  ];

  static const Map<String, dynamic> _heroPromoBanner = {
    'type': 'fast-delivery',
    'tag': 'FAST DELIVERY IN',
    'title': 'Ghatampur',
    'subtitle': 'Milk, Fruits, Vegetables, Snacks & more',
    'cta': 'Shop Now →',
    'bgColor': AppDesignSystem.slate50,
    'textColor': AppDesignSystem.primary,
    'imageAsset': 'assets/categories/fruits_vegetables_category.webp',
    'webFallback': 'https://www.fastkirana.in/grocery_bag_banner.png',
    'categorySlug': 'fruits-vegetables',
  };

  static const Map<String, String> _categoryAssetMap = {
    'fruits-vegetables': 'assets/categories/fruits_vegetables_category.webp',
    'fruits-and-vegetables': 'assets/categories/fruits_vegetables_category.webp',
    'dairy-breakfast': 'assets/categories/dairy_breakfast_category.webp',
    'dairy-bread-eggs': 'assets/categories/dairy_breakfast_category.webp',
    'snacks-munchies': 'assets/categories/snacks_munchies_category.webp',
    'snacks': 'assets/categories/snacks_munchies_category.webp',
    'beverages': 'assets/categories/beverages_category.webp',
    'personal-care': 'assets/categories/personal_care_category.webp',
    'household': 'assets/categories/household_category.webp',
    'home-cleaning': 'assets/categories/household_category.webp',
    'bakery-biscuits': 'assets/categories/bakery_biscuits_category.webp',
    'bakery': 'assets/categories/bakery_biscuits_category.webp',
    'atta-rice-dal': 'assets/categories/atta_rice_dal_category.webp',
    'kitchen-needs': 'assets/categories/atta_rice_dal_category.webp',
    'ice-cream': 'assets/categories/ice_cream_category.webp',
    'instant-foods': 'assets/categories/snacks_munchies_category.webp',
    'chocolates': 'assets/categories/bakery_biscuits_category.webp',
  };

  static const Map<String, String> _sectionCategorySlugs = {
    'Snacks & Munchies': 'snacks-munchies',
    'Chocolates & Sweets': 'chocolates',
    'Instant Foods': 'instant-foods',
    'Kitchen Needs': 'kitchen-needs',
    'Ice Cream': 'ice-cream',
  };

  @override
  void initState() {
    super.initState();
    // Rotate search placeholders every 3 seconds
    _searchTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _searchPlaceholderIndex = (_searchPlaceholderIndex + 1) % _searchPlaceholders.length;
        });
      }
    });

    // Live Order Sync with Admin Updates (15s — SSE handles real-time, this is fallback)
    _orderSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        ref.invalidate(ordersProvider(''));
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _orderSyncTimer?.cancel();
    super.dispose();
  }

  String _getTimeBasedTab() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 16) return 'Lunch';
    if (hour >= 16 && hour < 20) return 'Snacks';
    return 'Late Night';
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartCount = cartState.value?.items.fold<int>(0, (s, item) => s + item.quantity) ?? 0;
    final ordersAsync = ref.watch(ordersProvider(''));
    final activeOrders = ordersAsync.valueOrNull ?? [];
    final latestOrder = activeOrders.isNotEmpty ? activeOrders.first : null;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppDesignSystem.primary,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(cartProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(trendingProductsProvider);
                ref.invalidate(ordersProvider(''));
                for (final slug in _sectionCategorySlugs.values) {
                  ref.invalidate(productsProvider(slug));
                }
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Pinned Header & Search
                  SliverToBoxAdapter(child: _buildTopHeader()),

                  // 1b. Location Unserviceable Warning Banner (Swiggy / Zepto Style)
                  const SliverToBoxAdapter(child: UnserviceableLocationBanner()),

                  // 2. Mode Switcher (Grocery vs Food) - Placed directly above banner
                  SliverToBoxAdapter(child: _buildCategoryToggle()),

                  if (_isGrocerySelected) ...[
                    // 3. Single Hero Promo Banner (Ghatampur Express - Grocery Only)
                    SliverToBoxAdapter(child: _buildHeroPromoBanner()),

                    // 4. Sleek Trust Badge Strip (Grocery Only)
                    SliverToBoxAdapter(child: _buildTrustBadgeStrip()),

                    // 5. Circular Category Carousel (Web 1:1)
                    SliverToBoxAdapter(child: _buildCircularCategoryCarousel()),

                    // 6. Curated For You Filter Tabs
                    SliverToBoxAdapter(child: _buildCuratedForYouFilter()),

                    // 7. Dynamic Product Sections
                    ..._buildApiProductSections(),

                    // 8. Footer
                    SliverToBoxAdapter(child: _buildFooter()),
                  ] else ...[
                    // Food & Cafe Mode — directly show restaurants
                    ..._buildFoodRestaurantListing(),
                    SliverToBoxAdapter(child: _buildFooter()),
                  ],

                  SliverToBoxAdapter(child: SizedBox(height: 250 + MediaQuery.of(context).padding.bottom)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Top Bar (Logo, 10-15 Min Delivery Timing, Location Selector, Notifications)
  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        context.isCompact ? 10 : 16,
        10,
        context.isCompact ? 10 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + Clean Location Header + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: context.isCompact ? 32 : 38),
              SizedBox(width: context.isCompact ? 8 : 12),

              // Location Selector
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final selectedAddress = ref.watch(selectedAddressProvider);
                    final currentHub = ref.watch(currentStoreHubProvider);
                    final locationLabel = selectedAddress?.displayLabel ?? 'Home';
                    final shortLocation = selectedAddress?.shortAddress ?? currentHub.city;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const DeliveryLocationScreen()),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppDesignSystem.green600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Delivering to $locationLabel',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignSystem.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  shortLocation,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 14.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.textPrimary,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppDesignSystem.textPrimary),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Notification Icon with sleek border
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, FadeSlideRoute(page: const NotificationsScreen()));
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gray50,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppDesignSystem.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 20, color: AppDesignSystem.gray700),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppDesignSystem.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar (Exact Reference Match: Clean Rounded Pill)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppDesignSystem.border, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final restaurants = ref.watch(homeRestaurantsProvider).valueOrNull ?? [];
                        final restaurantNames = restaurants
                            .map((r) => r.name.trim())
                            .where((name) => name.isNotEmpty)
                            .take(5)
                            .toList();

                        final dynamicPlaceholders = [
                          'Search for milk',
                          if (restaurantNames.isNotEmpty) ...restaurantNames.map((name) => 'Search for "$name"'),
                          'Search "atta"',
                          'Search "maggi"',
                          'Search "dairy milk"',
                        ];

                        final placeholderText =
                            dynamicPlaceholders[_searchPlaceholderIndex % dynamicPlaceholders.length];

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: Align(
                            key: ValueKey<String>(placeholderText),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              placeholderText,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w400,
                                color: AppDesignSystem.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🎙️ Voice Search Mic Action Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      VoiceSearchSheet.show(context, onResult: (query) {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: SearchScreen(initialQuery: query)),
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppDesignSystem.rose50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded, size: 16, color: AppDesignSystem.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1.5 Track Your Delivery Card (Exact 1:1 Reference Match to media_1787685302881.png)
  Widget _buildActiveDeliveryTracker(Order latestOrder) {
    final orderId = latestOrder.readableId ?? (latestOrder.id.length > 8 ? latestOrder.id.substring(0, 8) : latestOrder.id);
    final status = latestOrder.status;
    final isDelivered = status == OrderStatus.delivered;
    final isShipped = status == OrderStatus.shipped;
    final isPacked = status == OrderStatus.packed;
    final isConfirmed = status == OrderStatus.confirmed;

    // Step index: 0 = Placed, 1 = Preparing, 2 = On The Way, 3 = Delivered
    int step = 0;
    if (isDelivered) {
      step = 3;
    } else if (isShipped) {
      step = 2;
    } else if (isPacked || isConfirmed) {
      step = 1;
    } else {
      step = 0;
    }

    // Dynamically resolve Fulfillment Store / Restaurant from actual Order data
    final itemsList = latestOrder.items ?? [];
    final foodKeywords = [
      'pizza', 'burger', 'chowmein', 'thali', 'paneer', 'biryani',
      'dosa', 'roll', 'momos', 'curry', 'roti', 'naan', 'sandwich',
      'pasta', 'shake', 'beverage', 'tea', 'coffee', 'fries', 'samosa', 'snack', 'restaurant'
    ];

    final foodItems = itemsList.where((item) {
      final n = item.name.toLowerCase();
      return foodKeywords.any((k) => n.contains(k));
    }).toList();

    final groceryItems = itemsList.where((item) => !foodItems.contains(item)).toList();

    // Check if order is combined multi-store order
    final bool isCombined = (foodItems.isNotEmpty && groceryItems.isNotEmpty) ||
        (latestOrder.shopName?.contains('Combined') == true) ||
        (latestOrder.shopName?.contains('+') == true) ||
        (latestOrder.restaurantId != null && latestOrder.restaurantId!.isNotEmpty);

    String restaurantName = 'A.S. Restaurant';
    if (latestOrder.shopName != null && latestOrder.shopName!.isNotEmpty && !latestOrder.shopName!.contains('Darkstore')) {
      restaurantName = latestOrder.shopName!;
    } else if (latestOrder.restaurantId != null && latestOrder.restaurantId!.isNotEmpty) {
      restaurantName = latestOrder.restaurantId!;
    }

    final int groceryCount = groceryItems.isNotEmpty ? groceryItems.length : 2;
    final int dishCount = foodItems.isNotEmpty ? foodItems.length : 1;

    final placedTimeStr = DateFormat('h:mm a').format(latestOrder.createdAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Track Your Delivery',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 18),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),

          // Main Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Chips Row: #ID • STATUS
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$orderId',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: AppDesignSystem.slate700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDelivered
                            ? AppDesignSystem.statusDelivered
                            : (isShipped ? AppDesignSystem.statusShipped : AppDesignSystem.statusPacked),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDelivered
                              ? AppDesignSystem.statusDeliveredText
                              : (isShipped ? AppDesignSystem.statusShippedText : AppDesignSystem.statusShippedText),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isDelivered && isShipped)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppDesignSystem.orange600,
                                shape: BoxShape.circle,
                              ),
                            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(
                              begin: 1.0, end: 1.8,
                              duration: 1200.ms, curve: Curves.easeInOutSine,
                            )
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDelivered
                                    ? AppDesignSystem.green600
                                    : (isShipped ? AppDesignSystem.orange600 : AppDesignSystem.violet600),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 5),
                          Text(
                            status.displayName.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w900,
                              color: isDelivered
                                  ? AppDesignSystem.green600
                                  : (isShipped ? AppDesignSystem.orange600 : AppDesignSystem.violet600),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Combined Order Badge (Exact Match with Reference Image)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusConfirmed,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.statusDeliveredText),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                      const SizedBox(width: 4),
                      Text(
                        'Grocery',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                      Text(
                        ' + ',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                      Text('🏬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                      const SizedBox(width: 4),
                      Text(
                        'Restaurant Combined',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.teal700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Order Heading & Subtitle
                Text(
                  isDelivered
                      ? 'Order Delivered! 🎉'
                      : (isShipped
                          ? 'Order on the Way! 🛵'
                          : (isPacked
                              ? 'Order Packed & Ready! 📦'
                              : 'Order Confirmed! 🎉')),
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDelivered
                      ? 'Thank you for ordering with FastKirana!'
                      : 'Your order has been received & is being prepared fresh.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.slate500,
                  ),
                ),
                const SizedBox(height: 14),

                // Placed Time Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.slate300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppDesignSystem.danger),
                      const SizedBox(width: 6),
                      Text(
                        'Placed at: $placedTimeStr',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4-Stage Stepper (Exact Match with Reference Image)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStepperNode('Placed', Icons.inventory_2_outlined, step >= 0, isCurrent: step == 0),
                    _buildStepperLine(step >= 1),
                    _buildStepperNode('Preparing', Icons.all_inbox_rounded, step >= 1, isCurrent: step == 1),
                    _buildStepperLine(step >= 2),
                    _buildStepperNode('On The Way', Icons.local_shipping_outlined, step >= 2, isCurrent: step == 2),
                    _buildStepperLine(step >= 3),
                    _buildStepperNode('Delivered', Icons.check_circle_rounded, step >= 3, isDeliveredNode: true, isCurrent: step == 3),
                  ],
                ),
                const SizedBox(height: 20),

                // Doorstep Fast Delivery Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.cyan100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppDesignSystem.cyan200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_rounded, size: 14, color: AppDesignSystem.cyan600),
                      const SizedBox(width: 6),
                      Text(
                        'DOORSTEP FAST DELIVERY',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.cyan700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 🌟 MULTI-STORE PREPARATION PROGRESS CARD (Exact Match with media_1787685566789.png)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.rose50.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppDesignSystem.rose200, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      // Header Row: MULTI-STORE PREPARATION PROGRESS + Purple Chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 18, color: AppDesignSystem.primary),
                              const SizedBox(width: 7),
                              Text(
                                'MULTI-STORE PREPARATION\nPROGRESS',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.slate900,
                                  letterSpacing: 0.2,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusConfirmed,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppDesignSystem.violet200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🔗', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                const SizedBox(width: 4),
                                Text(
                                  '1 DELIVERY • 2 STOPS',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.violet500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Store 1: FastKirana Darkstore (Grocery)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.slate50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shopping_cart_outlined, size: 18, color: AppDesignSystem.slate500),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FastKirana Darkstore',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12.5),
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.slate900,
                                    ),
                                  ),
                                  Text(
                                    '$groceryCount Grocery Items',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w500,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.statusDelivered,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppDesignSystem.statusDeliveredText),
                              ),
                              child: Text(
                                status.displayName.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.green600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Store 2: Restaurant (Dishes)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.slate50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.restaurant_rounded, size: 18, color: AppDesignSystem.slate500),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    restaurantName,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12.5),
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.slate900,
                                    ),
                                  ),
                                  Text(
                                    '$dishCount Dishes',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w500,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.statusDelivered,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppDesignSystem.statusDeliveredText),
                              ),
                              child: Text(
                                status.displayName.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.green600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Support Button
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final uri = Uri.parse('tel:8112849854');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.rose200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: AppDesignSystem.primary),
                        const SizedBox(width: 8),
                        Text(
                          'FastKirana Support (8112849854)',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperNode(String label, IconData icon, bool isCompleted, {bool isDeliveredNode = false, bool isCurrent = false}) {
    Color bg = isCompleted
        ? (isDeliveredNode ? AppDesignSystem.primary : AppDesignSystem.teal600)
        : AppDesignSystem.slate300;
    Color iconColor = isCompleted ? Colors.white : AppDesignSystem.slate400;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: isDeliveredNode && isCompleted
                ? [
                    BoxShadow(
                      color: AppDesignSystem.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11),
            fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w600,
            color: isDeliveredNode && isCompleted ? AppDesignSystem.primary : (isCompleted ? AppDesignSystem.slate900 : AppDesignSystem.slate400),
          ),
        ),
      ],
    );
  }

  Widget _buildStepperLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        decoration: BoxDecoration(
          color: isCompleted ? AppDesignSystem.teal600 : AppDesignSystem.slate300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // 2. Grocery / Food Mode Switcher (100% Exact Match to Reference Screenshot)
  Widget _buildCategoryToggle() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppDesignSystem.background,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppDesignSystem.border, width: 1),
          ),
          child: Row(
            children: [
              // Grocery Option (Active Red Gradient Pill)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_isGrocerySelected) return;
                    HapticFeedback.selectionClick();
                    setState(() => _isGrocerySelected = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: _isGrocerySelected
                          ? const LinearGradient(
                              colors: [AppDesignSystem.primary, AppDesignSystem.red300],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: _isGrocerySelected
                          ? [
                              BoxShadow(
                                color: AppDesignSystem.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return RotationTransition(
                              turns: Tween<double>(begin: -0.5, end: 0.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                              ),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: Icon(
                            _isGrocerySelected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                            key: ValueKey<bool>(_isGrocerySelected),
                            size: 20,
                            color: _isGrocerySelected ? Colors.white : AppDesignSystem.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Column(
                              key: ValueKey<bool>(_isGrocerySelected),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grocery',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: _isGrocerySelected ? Colors.white : AppDesignSystem.gray700,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'FAST DELIVERY',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 7.5),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _isGrocerySelected ? Colors.white.withValues(alpha: 0.95) : AppDesignSystem.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Food Option (Inactive / Active Switch)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!_isGrocerySelected) return;
                    HapticFeedback.selectionClick();
                    setState(() => _isGrocerySelected = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: !_isGrocerySelected
                          ? const LinearGradient(
                              colors: [AppDesignSystem.orange600, AppDesignSystem.orange500],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: !_isGrocerySelected
                          ? [
                              BoxShadow(
                                color: AppDesignSystem.orange600.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return RotationTransition(
                              turns: Tween<double>(begin: -0.5, end: 0.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                              ),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: Icon(
                            !_isGrocerySelected ? Icons.restaurant_rounded : Icons.restaurant_outlined,
                            key: ValueKey<bool>(!_isGrocerySelected),
                            size: 20,
                            color: !_isGrocerySelected ? Colors.white : AppDesignSystem.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Column(
                              key: ValueKey<bool>(!_isGrocerySelected),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Food',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: !_isGrocerySelected ? Colors.white : AppDesignSystem.gray700,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'FOOD & RESTAURANTS',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 7.5),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: !_isGrocerySelected ? Colors.white.withValues(alpha: 0.95) : AppDesignSystem.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Hero Promo Banner (Single Ghatampur Express Front Banner)
  Widget _buildHeroPromoBanner() {
    const slide = _heroPromoBanner;
    final bgColor = slide['bgColor'] as Color;
    final textColor = slide['textColor'] as Color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final slug = slide['categorySlug'] as String;
            final categoriesAsync = ref.read(categoriesProvider);
            final cat = categoriesAsync.valueOrNull?.firstWhere(
              (c) => c.slug == slug || c.id == slug,
              orElse: () => Category.fromJson({'id': slug, 'name': 'Vegetables & Fruits', 'slug': slug}),
            );
            if (cat != null) {
              Navigator.push(
                context,
                FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
              );
            }
          },
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDesignSystem.rose100, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: textColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background ambient circles
              Positioned(
                top: -15,
                left: -15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),

              Row(
                children: [
                  // Left Text Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide['tag'] as String,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9),
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            slide['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: context.isCompact ? 18 : 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          slide['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: context.isCompact ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.isCompact ? 6 : 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.isCompact ? 8 : 10,
                                vertical: context.isCompact ? 3.5 : 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: textColor.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                slide['cta'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: context.isCompact ? 8.5 : 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: textColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 10, color: textColor),
                                  Text(
                                    'FAST Delivery',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 8),
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right Visual
                  SizedBox(
                    width: context.isCompact ? 76 : 96,
                    height: context.isCompact ? 76 : 96,
                    child: Image.asset(
                      slide['imageAsset'] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => CachedNetworkImage(
                        imageUrl: slide['webFallback'] as String,
                        fit: BoxFit.contain,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // 5. Circular Category Carousel (Web 1:1 Parity)
  Widget _buildCircularCategoryCarousel() {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Categories',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedTabProvider.notifier).state = 2; // Switch to categories tab
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.rose100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'SEE ALL',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.pink600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          categoriesAsync.when(
            data: (categories) {
              final groceryCategories = categories.where((c) {
                final slug = c.slug.toLowerCase();
                final name = c.name.toLowerCase();
                if (slug.contains('restaurant') ||
                    slug.contains('kitchen') ||
                    slug.contains('fast-food') ||
                    slug.contains('fastfood') ||
                    slug.contains('cafe') ||
                    slug.contains('food-restaurant') ||
                    slug.contains('thali') ||
                    slug.contains('pizza') ||
                    slug.contains('burger') ||
                    slug == 'restaurant-food') {
                  return false;
                }
                if (name.contains('restaurant') ||
                    name.contains('kitchen') ||
                    name.contains('fast food') ||
                    name.contains('cafe') ||
                    name.contains('thali')) {
                  return false;
                }
                return true;
              }).toList();

              if (groceryCategories.isEmpty) return const SizedBox.shrink();
              return AnimationLimiter(
                child: SizedBox(
                  height: Responsive.isSmallMobile(context) ? 94 : 102,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: groceryCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = groceryCategories[index];

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: ScaleAnimation(
                          scale: 0.85,
                          child: FadeInAnimation(
                            child: Bounceable(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  FadeSlideRoute(
                                    page: CategoryProductsScreen(category: cat),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: context.isCompact ? 60 : 68,
                                child: Column(
                                  children: [
                                    Hero(
                                      tag: 'category_${cat.id}',
                                      child: Container(
                                        width: context.isCompact ? 56 : 64,
                                        height: context.isCompact ? 56 : 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppDesignSystem.gray50,
                                          border: Border.all(color: AppDesignSystem.border, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _buildCategoryAvatarImage(cat),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cat.name,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w700,
                                        color: AppDesignSystem.gray800,
                                        height: 1.15,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => SizedBox(
              height: Responsive.isSmallMobile(context) ? 94 : 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: AppDesignSystem.border,
                  highlightColor: AppDesignSystem.gray50,
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(width: 50, height: 10, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAvatarImage(Category cat) {
    final imgUrl = cat.imageUrl ?? '';

    // 1. If real Cloudinary / HTTP URL from Supabase is present, use it directly!
    if (imgUrl.isNotEmpty && imgUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => _buildCategoryFallback(cat),
      );
    }

    // 2. If relative URL from Supabase (e.g. /fruits_vegetables_category.png), load from live domain
    if (imgUrl.isNotEmpty && imgUrl.startsWith('/')) {
      return CachedNetworkImage(
        imageUrl: 'https://www.fastkirana.in$imgUrl',
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppDesignSystem.border,
          highlightColor: AppDesignSystem.gray50,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => _buildCategoryFallback(cat),
      );
    }

    // 3. Check exact slug mappings
    final slug = cat.slug.toLowerCase().trim();
    if (slug == 'fruits-vegetables' || slug.contains('fruit') || slug.contains('veg')) {
      return Image.asset('assets/categories/fruits_vegetables_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'dairy-breakfast' || slug.contains('dairy') || slug.contains('milk')) {
      return Image.asset('assets/categories/dairy_breakfast_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'snacks-munchies' || slug.contains('snack')) {
      return Image.asset('assets/categories/snacks_munchies_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'beverages' || slug.contains('drink') || slug.contains('cold')) {
      return Image.asset('assets/categories/beverages_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'ice-cream' || slug.contains('ice') || slug.contains('dessert')) {
      return Image.asset('assets/categories/ice_cream_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'atta-rice-dal' || slug.contains('atta') || slug.contains('rice') || slug.contains('kitchen')) {
      return Image.asset('assets/categories/atta_rice_dal_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'personal-care' || slug.contains('care') || slug.contains('hygiene')) {
      return Image.asset('assets/categories/personal_care_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'home-needs-and-cleaning' || slug == 'household' || slug.contains('clean')) {
      return Image.asset('assets/categories/household_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'bakery' || slug.contains('biscuit')) {
      return Image.asset('assets/categories/bakery_biscuits_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'restaurant-food' || slug.contains('cafe') || slug.contains('food')) {
      return Image.asset('assets/categories/cafe_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }

    return _buildCategoryFallback(cat);
  }

  Widget _buildCategoryFallback(Category cat) {
    return Container(
      color: AppDesignSystem.surfaceMuted,
      child: Center(
        child: Text(
          cat.name.isNotEmpty ? cat.name.characters.first.toUpperCase() : '🛍️',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 22),
            fontWeight: FontWeight.w900,
            color: AppDesignSystem.primary,
          ),
        ),
      ),
    );
  }

  // 4. Sleek Trust Badge Strip (Exact match to media_1787720540434.png + Synced with Admin Portal)
  Widget _buildTrustBadgeStrip() {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const StoreSettings();
    final selectedAddress = ref.watch(selectedAddressProvider);
    final rawCity = selectedAddress?.city.isNotEmpty == true
        ? selectedAddress!.city
        : settings.trustBadge1;
    final cityName = rawCity.split(',').first.trim();

    final badge2 = settings.trustBadge2;
    final badge3 = settings.trustBadge3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. 🟢 ⚡ Ghatampur
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.green600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.bolt_rounded, size: 16, color: AppDesignSystem.warning),
                const SizedBox(width: 4),
                Text(
                  cityName,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Divider
            Container(width: 1, height: 13, color: AppDesignSystem.slate300),

            // 2. 💠 50+ (Verified badge / Varieties)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: AppDesignSystem.info,
                ),
                const SizedBox(width: 5),
                Text(
                  badge2,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Divider
            Container(width: 1, height: 13, color: AppDesignSystem.slate300),

            // 3. 💖 1000+ (Happy Customers / Orders)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 15,
                  color: AppDesignSystem.pink500,
                ),
                const SizedBox(width: 5),
                Text(
                  badge3,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 6. Curated For You Filter Tabs (100% Exact Screenshot Match: Circular Icon Tabs + Underline)
  Widget _buildCuratedForYouFilter() {
    final curations = [
      {
        'title': 'All',
        'icon': Icons.storefront_rounded,
        'iconColor': AppDesignSystem.indigo500,
        'bg': AppDesignSystem.indigo50,
      },
      {
        'title': 'Flash Deals',
        'icon': Icons.bolt_rounded,
        'iconColor': AppDesignSystem.danger,
        'bg': AppDesignSystem.rose50,
      },
      {
        'title': 'Best Sellers',
        'icon': Icons.emoji_events_rounded,
        'iconColor': AppDesignSystem.warning,
        'bg': AppDesignSystem.yellow50,
      },
      {
        'title': 'Trending',
        'icon': Icons.local_fire_department_rounded,
        'iconColor': AppDesignSystem.orange500,
        'bg': AppDesignSystem.orange50,
      },
      {
        'title': 'Snacks',
        'icon': Icons.fastfood_rounded,
        'iconColor': AppDesignSystem.pink500,
        'bg': AppDesignSystem.rose50,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text(
            'Curated For You',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 19),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Handpicked collections for every mood',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Circular Tabs Row
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: curations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = curations[index];
                final isSelected = index == _selectedFilterIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                  },
                  child: Column(
                    children: [
                      // Circular Icon Avatar (Crisp Vector Graphic)
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item['bg'] as Color,
                          border: Border.all(
                            color: isSelected ? AppDesignSystem.indigo500 : AppDesignSystem.border,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppDesignSystem.indigo500.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['iconColor'] as Color,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Tab Title Text
                      Text(
                        item['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppDesignSystem.textPrimary : AppDesignSystem.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Active Purple Underline Indicator
                      if (isSelected)
                        Container(
                          width: 22,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.indigo500,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(height: 2.5),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 7. Dynamic Product Sections (All Categories 10+ Products like Webapp)
  List<Widget> _buildApiProductSections() {
    // Use shared catalog — single fetch, filter locally per section
    final catalogAsync = ref.watch(homeProductCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    if (categoriesAsync.valueOrNull == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final categories = categoriesAsync.valueOrNull!;

    final groceryCategories = categories.where((c) {
      final slug = c.slug.toLowerCase();
      final name = c.name.toLowerCase();
      if (slug.contains('restaurant') ||
          slug.contains('kitchen') ||
          slug.contains('fast-food') ||
          slug.contains('fastfood') ||
          slug.contains('cafe') ||
          slug.contains('food-restaurant') ||
          slug.contains('thali') ||
          slug.contains('pizza') ||
          slug.contains('burger') ||
          slug == 'restaurant-food') {
        return false;
      }
      if (name.contains('restaurant') ||
          name.contains('kitchen') ||
          name.contains('fast food') ||
          name.contains('cafe') ||
          name.contains('thali')) {
        return false;
      }
      return true;
    }).toList();

    if (groceryCategories.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

    return catalogAsync.when(
      loading: () => groceryCategories.map((cat) =>
        SliverToBoxAdapter(child: _buildHorizontalProductSection(cat, [], totalCount: 0))
      ).toList(),
      error: (_, __) => groceryCategories.map((cat) =>
        SliverToBoxAdapter(child: _buildHorizontalProductSection(cat, [], totalCount: 0))
      ).toList(),
      data: (allProducts) {
        return groceryCategories.map((cat) {
          // Filter locally from the shared catalog
          final categoryProducts = allProducts
              .where((p) => p.category?.slug == cat.slug || p.categoryId == cat.id || p.category?.id == cat.id)
              .where((p) => p.restaurantId == null && p.restaurant == null)
              .toList();
          final displayProducts = categoryProducts.take(6).toList();
          return SliverToBoxAdapter(
            child: _buildHorizontalProductSection(
              cat,
              displayProducts,
              totalCount: categoryProducts.length,
            ),
          );
        }).toList();
      },
    );
  }

  String _getCategorySubtitle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('snack') || lower.contains('munch')) return 'Crunchy chips, namkeen & snacks';
    if (lower.contains('choco') || lower.contains('sweet')) return 'Dairy Milk Silk, bars & confectionery';
    if (lower.contains('fruit') || lower.contains('veg')) return 'Farm fresh vegetables & fruits';
    if (lower.contains('atta') || lower.contains('rice') || lower.contains('dal') || lower.contains('oil') || lower.contains('grain') || lower.contains('pulse')) return 'Fortune oil, grains, atta & pulses';
    if (lower.contains('ice') || lower.contains('cream') || lower.contains('dessert')) return 'Cool tubs, cones, kulfi & desserts';
    if (lower.contains('beverage') || lower.contains('drink')) return 'Cold drinks, real juices & energy sodas';
    if (lower.contains('bakery') || lower.contains('biscuit')) return 'Fresh cookies, rusks & bakery bites';
    if (lower.contains('care') || lower.contains('hygiene')) return 'Soaps, shampoos, skincare & essentials';
    if (lower.contains('clean') || lower.contains('home')) return 'Detergents, cleaners & home supplies';
    if (lower.contains('health')) return 'Nutritious picks, dry fruits & oats';
    if (lower.contains('pack')) return 'Instant noodles, pasta & ready to eat';
    if (lower.contains('food') || lower.contains('rest') || lower.contains('cafe')) return 'Hot burgers, rolls, pizzas & meals';
    return 'Top quality grocery essentials';
  }

  Widget _buildProductSectionSkeleton(String title) {
    final cardWidth = Responsive.isSmallMobile(context)
        ? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 10) / 2
        : Responsive.isTablet(context)
            ? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 20) / 3
            : (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 10) / 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: AppDesignSystem.border,
            highlightColor: AppDesignSystem.gray50,
            child: Container(
              width: cardWidth * 0.6,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: Responsive.isSmallMobile(context) ? 232 : 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: Responsive.horizontalPadding(context)),
              itemCount: 4,
              separatorBuilder: (_, __) => SizedBox(width: Responsive.isSmallMobile(context) ? 8 : 10),
              itemBuilder: (_, __) => SizedBox(
                width: cardWidth,
                child: ProductCardSkeleton(width: cardWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Horizontal Product Track with Direct Category Navigation & View More Card
  Widget _buildHorizontalProductSection(Category cat, List<Product> products, {required int totalCount}) {
    final subtitle = _getCategorySubtitle(cat.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: CategoryProductsScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.red300, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL ($totalCount)',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.red600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.red600),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimationLimiter(
            child: SizedBox(
              height: Responsive.isSmallMobile(context) ? 232 : 252,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(right: Responsive.horizontalPadding(context)),
                itemCount: products.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: Responsive.isSmallMobile(context) ? 8 : 10),
                itemBuilder: (context, index) {
                  if (index < products.length) {
                    final product = products[index];
                    final cardWidth = Responsive.isSmallMobile(context)
                        ? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 10) / 2
                        : Responsive.isTablet(context)
                            ? (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 20) / 3
                            : (context.screenWidth - Responsive.horizontalPadding(context) * 2 - 10) / 2;
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        horizontalOffset: 40.0,
                        child: FadeInAnimation(
                          child: SizedBox(
                            width: cardWidth,
                            child: ProductCard(product: product, width: cardWidth),
                          ),
                        ),
                      ),
                    );
                  }

                // "Explore All" End Card
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: CategoryProductsScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.gray50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppDesignSystem.border, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppDesignSystem.statusCancelled,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: AppDesignSystem.red600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'See all\n$totalCount items',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  // 8. Footer
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          border: Border.all(color: AppDesignSystem.borderLight),
        ),
        child: Column(
          children: [
            Text(
              '© 2026 FastKirana. All rights reserved.',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaymentIcon('UPI', AppDesignSystem.amber600),
                const SizedBox(width: 12),
                _buildPaymentIcon('Card', AppDesignSystem.lime500),
                const SizedBox(width: 12),
                _buildPaymentIcon('COD', AppDesignSystem.primary),
                const SizedBox(width: 12),
                _buildPaymentIcon('Wallet', AppDesignSystem.info),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '+91 81128 49854 | fastkiranadelivery@gmail.com',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              '7 AM – 10 PM | NH34, Ghatampur, Kanpur Nagar',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), color: AppDesignSystem.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentIcon(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ==========================================
  // FOOD & CAFE STOREFRONT (1:1 Web App Parity)
  // ==========================================


  // 3. Time-Aware Greeting Card + Birthday Promo Banner (Matches 1_home_grocery.png 1:1)
  Widget _buildFoodGreetingBanner() {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;

    if (hour >= 5 && hour < 12) {
      greeting = "Good morning, let's get breakfast!";
      emoji = '🌅';
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good afternoon, time for fresh lunch!";
      emoji = '☀️';
    } else if (hour >= 17 && hour < 21) {
      greeting = "Good evening, snacks & chai time!";
      emoji = '☕';
    } else {
      greeting = 'Late night cravings? We got you!';
      emoji = '🌙';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignSystem.warmWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppDesignSystem.yellow300),
          boxShadow: [
            BoxShadow(
              color: AppDesignSystem.yellow700.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge: ☀️ ⚡ GROCERY MART • ONLINE
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.yellow200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('☀️ ⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                      const SizedBox(width: 4),
                      Text(
                        'GROCERY MART • ONLINE',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.amber700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Headline + Emoji
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$greeting $emoji',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 17),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fresh dairy, fruits & daily essentials — delivered fast',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            // Time range pill: 🛒 GROCERY MART: 7 AM – 10 PM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppDesignSystem.emerald200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                  const SizedBox(width: 4),
                  Text(
                    'GROCERY MART: 7 AM – 10 PM',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.emerald700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Purple Promo Card inside
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppDesignSystem.violet500, AppDesignSystem.fuchsia500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 9))),
                        const SizedBox(width: 3),
                        Text(
                          'Fast Delivery',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Make Your Moments Special ✨',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Freshly baked custom treats, party snacks & drinks',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  List<Widget> _buildFoodRestaurantListing() {
    final restaurantsAsync = ref.watch(homeRestaurantsProvider);

    final foodQuickCategories = [
      {'title': 'Burgers', 'emoji': '🍔', 'tag': 'burgers'},
      {'title': 'Pizzas', 'emoji': '🍕', 'tag': 'pizza'},
      {'title': 'Rolls', 'emoji': '🌯', 'tag': 'frankie-rolls'},
      {'title': 'Biryani', 'emoji': '🍚', 'tag': 'biryani-rice'},
      {'title': 'Curries', 'emoji': '🥘', 'tag': 'main-course'},
      {'title': 'Rotis', 'emoji': '🫓', 'tag': 'roti-naan-breads'},
      {'title': 'Chinese', 'emoji': '🥡', 'tag': 'chinese'},
      {'title': 'Brews & Tea', 'emoji': '☕', 'tag': 'hot-beverage'},
    ];

    return [
      // Top Restaurants & Cafes Simple Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Text('🍽️', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Restaurants & Cafes',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Order food from your favorite spots in Ghatampur',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 2),
                    Text(
                      'FAST FOOD',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 8.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 4. Restaurant Cards List
      restaurantsAsync.when(
        data: (restaurants) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => RestaurantCard(restaurant: restaurants[index]),
              childCount: restaurants.length,
            ),
          ),
        ),
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppDesignSystem.cafeAccent),
            ),
          ),
        ),
        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    ];
  }
}
