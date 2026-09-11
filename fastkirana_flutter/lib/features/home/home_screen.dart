import 'dart:async';
import 'dart:math' as math;
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
import 'package:flutter_svg/flutter_svg.dart';
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
import '../orders/orders_screen.dart';
import '../../widgets/voice_search_sheet.dart';
import '../../widgets/unserviceable_location_banner.dart';
import '../../widgets/address_selector_sheet.dart';
import '../../core/services/location_service.dart';
import '../../widgets/app_update_dialog.dart';
import 'main_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isGrocerySelected = true;
  int _selectedFilterIndex = 0;
  final Map<String, String> _selectedCategorySubcat = {};
  int _searchPlaceholderIndex = 0;
  Timer? _searchTimer;
  Timer? _orderSyncTimer;

  // Infinite Product Feed Scroll & Pagination State (Zepto/Blinkit architecture)
  final ScrollController _homeScrollController = ScrollController();
  int _visibleGridCount = 20;
  bool _isLoadingMoreGrid = false;

  // High-contrast vector SVG emojis (Twemoji-style crisp vector paths with clean shadows)
  static const String _grocerySvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <!-- Background Bag (Purple / Teal accent) -->
  <g filter="url(#shadow)">
    <!-- Back shopping bag -->
    <path d="M22 24c0-5.5 4.5-10 10-10s10 4.5 10 10" fill="none" stroke="#FBBF24" stroke-width="4" stroke-linecap="round"/>
    <path d="M16 26h32l-3 34H19L16 26z" fill="#8B5CF6"/>
    <path d="M19 26l3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4" stroke="#7C3AED" stroke-width="1.5" fill="none"/>
    <!-- Front Bright Red/Orange bag -->
    <path d="M34 20c0-6 5-11 11-11s11 5 11 11" fill="none" stroke="#FDE047" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M28 22h34l-3 38H31L28 22z" fill="#EF4444"/>
    <path d="M31 22l3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4" stroke="#DC2626" stroke-width="1.5" fill="none"/>
    <!-- Fresh greens sticking out -->
    <path d="M42 12c-2-4 1-8 6-7 4 1 5 6 2 9-2 2-6 1-8-2z" fill="#22C55E"/>
    <path d="M48 9c1-3 5-4 7-1 2 2 1 6-2 7-3 1-5-3-5-6z" fill="#4ADE80"/>
    <!-- White contrast badge/sparkle -->
    <circle cx="58" cy="18" r="3" fill="#FFFFFF"/>
    <circle cx="26" cy="36" r="2.5" fill="#F87171"/>
  </g>
</svg>
''';

  static const String _burgerSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="burgerShadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2.5" stdDeviation="2.5" flood-color="#000000" flood-opacity="0.25"/>
    </filter>
  </defs>
  <g filter="url(#burgerShadow)">
    <!-- Top Bun -->
    <path d="M12 36c0-13.25 10.75-24 24-24s24 10.75 24 24H12z" fill="#F59E0B"/>
    <path d="M16 34c2-9 10-17 20-17s18 8 20 17H16z" fill="#FBBF24" opacity="0.35"/>
    <!-- Sesame Seeds (High Contrast White) -->
    <ellipse cx="26" cy="23" rx="1.8" ry="2.8" transform="rotate(-25 26 23)" fill="#FEF3C7"/>
    <ellipse cx="36" cy="19" rx="1.8" ry="2.8" fill="#FEF3C7"/>
    <ellipse cx="46" cy="24" rx="1.8" ry="2.8" transform="rotate(25 46 24)" fill="#FEF3C7"/>
    <ellipse cx="31" cy="28" rx="1.5" ry="2.5" transform="rotate(15 31 28)" fill="#FEF3C7"/>
    <ellipse cx="41" cy="29" rx="1.5" ry="2.5" transform="rotate(-15 41 29)" fill="#FEF3C7"/>
    <!-- Lettuce (Vibrant Green Wavy) -->
    <path d="M10 37c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0 4 1.5 6 0 4-1.5 6 0 4 1.5 6 0 4-1.5 6 0 4 1.5 6 0v4H10v-4z" fill="#10B981"/>
    <!-- Tomato Slices (Vibrant Red) -->
    <rect x="13" y="40" width="22" height="4.5" rx="2.2" fill="#EF4444"/>
    <rect x="37" y="40" width="22" height="4.5" rx="2.2" fill="#EF4444"/>
    <!-- Cheese (Melted Golden Yellow) -->
    <path d="M12 43.5h48l-6 7-18-2-18 2-6-7z" fill="#FACC15"/>
    <!-- Patty (Rich Savory Brown) -->
    <rect x="11" y="48" width="50" height="9" rx="4.5" fill="#78350F"/>
    <rect x="14" y="50" width="44" height="2" rx="1" fill="#92400E" opacity="0.6"/>
    <!-- Bottom Bun -->
    <path d="M13 56h46c0 4.5-3.5 8-8 8H21c-4.5 0-8-3.5-8-8z" fill="#F59E0B"/>
    <path d="M16 57h40c0 2-2 4-5 4H21c-3 0-5-2-5-4z" fill="#D97706" opacity="0.3"/>
  </g>
</svg>
''';

  // Pulse & shimmer controller to attract attention to the switchable tab
  late final AnimationController _toggleNudgeController;
  late final Animation<double> _toggleNudgeAnim;
  late final Animation<double> _toggleGlowAnim;

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
    'tag': '⚡ FAST DELIVERY',
    'title': 'Ghatampur Darkstore',
    'subtitle': 'Farm-Fresh Veggies, Milk, Snacks & Daily Staples',
    'cta': 'Order Now →',
    'bgColor': Color(0xFFFFF7ED),
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

    // Rhythmic subtle bounce/glow every 2.4s to guide the customer that this is interactive
    _toggleNudgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _toggleNudgeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 0.96).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.04).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 48, // Resting pause between cycles
      ),
    ]).animate(_toggleNudgeController);

    _toggleGlowAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 50,
      ),
    ]).animate(_toggleNudgeController);

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
    // Infinite scroll listener for seamless product pagination (Blinkit / Zepto)
    _homeScrollController.addListener(_onHomeScroll);

    // Check for app version updates from Admin Settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateDialog.checkAndShow(context, ref);
      }
    });
  }

  @override
  void dispose() {
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    _toggleNudgeController.dispose();
    _searchTimer?.cancel();
    _orderSyncTimer?.cancel();
    super.dispose();
  }

  void _onHomeScroll() {
    if (!_homeScrollController.hasClients || _isLoadingMoreGrid) return;
    final pos = _homeScrollController.position;
    // Auto-fetch next 20 products seamlessly when user is 450px from bottom
    if (pos.pixels >= pos.maxScrollExtent - 450) {
      _loadMoreGridProducts();
    }
  }

  void _loadMoreGridProducts() {
    if (_isLoadingMoreGrid) return;
    final catalog = ref.read(homeProductCatalogProvider).valueOrNull ?? [];
    final filtered = _getFilteredGridProducts(catalog);
    if (_visibleGridCount >= filtered.length) return;

    setState(() {
      _isLoadingMoreGrid = true;
    });

    // Buttery-smooth micro-delay before revealing next 20 items
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() {
          _visibleGridCount = math.min(_visibleGridCount + 20, filtered.length);
          _isLoadingMoreGrid = false;
        });
      }
    });
  }

  List<Product> _getFilteredGridProducts(List<Product> all) {
    // Strictly isolate grocery items (exclude restaurant dishes)
    final groceryItems = all.where((p) => p.restaurantId == null && p.restaurant == null).toList();

    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) return false;
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood') ||
          name.contains('restaurant') ||
          name.contains('cafe')) {
        return false;
      }
      return true;
    }).toList();

    if (_selectedFilterIndex > 0 && _selectedFilterIndex <= groceryCategories.length) {
      final selectedCat = groceryCategories[_selectedFilterIndex - 1];
      return groceryItems.where((p) => _isProductInCategory(p, selectedCat)).toList();
    }

    return groceryItems;
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
                ref.invalidate(homeProductCatalogProvider);
                if (mounted) {
                  setState(() {
                    _visibleGridCount = 20;
                    _isLoadingMoreGrid = false;
                  });
                }
              },
              child: CustomScrollView(
                controller: _homeScrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Pinned Header & Search
                  SliverToBoxAdapter(child: _buildTopHeader()),

                  // 1b. Location Unserviceable Warning Banner (Swiggy / Zepto Style)
                  const SliverToBoxAdapter(child: UnserviceableLocationBanner()),

                  // 2. Mode Switcher (Grocery vs Food) - Placed directly above banner
                  SliverToBoxAdapter(child: _buildCategoryToggle()),

                  if (_isGrocerySelected) ...[
                    // 2.5 Hero Promotional Banner (10-15 Min Fast Delivery Spotlight)
                    SliverToBoxAdapter(child: _buildHeroPromoBanner()),

                    // 3. Top 8 Categories (2 rows) - Premium squircle tiles
                    SliverToBoxAdapter(child: _buildTopCategoriesGrid()),

                    // 4. Product Shelves (Category title + Subcategory chips + Products with + ADD)
                    ..._buildApiProductSections(),

                    // 5. Infinite Scroll Product Feed (Batch-loaded 20 items at a time, Blinkit/Zepto style)
                    ..._buildInfiniteProductFeed(),

                    // Footer
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

  // 1. Top Bar (Logo, 10-15 Min Delivery Speed Header, Location Selector, Ambient Search Pill)
  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        context.isCompact ? 10 : 16,
        8,
        context.isCompact ? 10 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + 10-15 MIN Delivery Speed Header + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: context.isCompact ? 34 : 40),
              SizedBox(width: context.isCompact ? 8 : 12),

              // 10-15 Min Fast Delivery Header & Location Selector
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
                        AddressSelectorSheet.show(
                          context,
                          activeAddress: selectedAddress,
                          onAddressSelected: (addr) {
                            final distKm = (addr.latitude != null && addr.longitude != null)
                                ? LocationService.getDistanceKm(addr.latitude!, addr.longitude!)
                                : 0.0;
                            if (distKm > LocationService.maxDeliveryRadiusKm) {
                              UnserviceableLocationBanner.showUnserviceableModal(context, ref, distKm);
                            }
                          },
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Delivering to $locationLabel',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Location title + dropdown arrow
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  shortLocation,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 14.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.textPrimary,
                                    height: 1.15,
                                    letterSpacing: -0.3,
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

              // Notification Icon with sleek double-bezel ambient container
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, FadeSlideRoute(page: const NotificationsScreen()));
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF334155)),
                      Positioned(
                        top: 9,
                        right: 9,
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

          // 2. Ambient Search Pill (Floating glow & soft ambient depth)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppDesignSystem.primary.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ambient Lens Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 0.8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dynamicPlaceholders = [
                          'Search for "milk"',
                          'Search for "atta"',
                          'Search for "chips"',
                          'Search for "maggi"',
                          'Search fresh fruits & veggies',
                          'Search for "dairy milk"',
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
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
                  // Ambient Voice Mic Action Button
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
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

  // 2. Reference Match Mode Switcher (Exact 1:1 Design from media_1788694883819.png)
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: AnimatedBuilder(
        animation: _toggleNudgeController,
        builder: (context, child) {
          final glowVal = _toggleGlowAnim.value;
          final nudgeScale = _toggleNudgeAnim.value;

          return LayoutBuilder(
            builder: (context, constraints) {
              final outerWidth = constraints.maxWidth;
              const outerHeight = 60.0;
              const innerPadding = 4.0;
              final pillWidth = (outerWidth - (innerPadding * 2)) / 2;

              return Container(
                height: outerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: (_isGrocerySelected ? const Color(0xFFE20A22) : const Color(0xFFEA580C))
                          .withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Active Sliding Pill with Glowing Ambient Light ──
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: const Cubic(0.25, 1.0, 0.4, 1.0), // Smooth Apple-like spring
                      left: _isGrocerySelected ? innerPadding : (innerPadding + pillWidth),
                      top: innerPadding,
                      bottom: innerPadding,
                      width: pillWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isGrocerySelected
                                ? const [Color(0xFFE20A22), Color(0xFFF43F5E)]
                                : const [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            // Vibrant Ambient Glow matching reference
                            BoxShadow(
                              color: (_isGrocerySelected ? const Color(0xFFE20A22) : const Color(0xFFEA580C))
                                  .withValues(alpha: 0.45 + (glowVal * 0.1)),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // Subtle specular top highlight
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 1.5,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Two Tap Targets (Grocery vs Food & Cafe) ──
                    Row(
                      children: [
                        // 1. Grocery Tab Target
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_isGrocerySelected) return;
                              HapticFeedback.mediumImpact();
                              setState(() => _isGrocerySelected = true);
                            },
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 3D Grocery Basket with gentle float animation when inactive
                                      Transform.scale(
                                        scale: !_isGrocerySelected ? nudgeScale : 1.0,
                                        child: Transform.translate(
                                          offset: Offset(0, !_isGrocerySelected ? (-2 * glowVal) : 0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.12),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.string(
                                              _grocerySvg,
                                              width: 32,
                                              height: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      // 2-Line Typography
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: _isGrocerySelected
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                            child: const Text('Grocery'),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: _isGrocerySelected
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : const Color(0xFF94A3B8),
                                              letterSpacing: 1.4,
                                            ),
                                            child: const Text('FAST DELIVERY'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. Food Tab Target
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!_isGrocerySelected) return;
                              HapticFeedback.mediumImpact();
                              setState(() => _isGrocerySelected = false);
                            },
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 3D Burger with gentle float animation when inactive
                                      Transform.scale(
                                        scale: _isGrocerySelected ? nudgeScale : 1.0,
                                        child: Transform.translate(
                                          offset: Offset(0, _isGrocerySelected ? (-2 * glowVal) : 0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.12),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.string(
                                              _burgerSvg,
                                              width: 32,
                                              height: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      // 2-Line Typography
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: !_isGrocerySelected
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                            child: const Text('Food'),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: !_isGrocerySelected
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : const Color(0xFF94A3B8),
                                              letterSpacing: 1.4,
                                            ),
                                            child: const Text('RESTAURANTS'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
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
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1F2), Color(0xFFFFFBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE20A22).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    // Left Content Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ⚡ Fast Delivery Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE20A22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFFDE047)),
                                const SizedBox(width: 3),
                                Text(
                                  'FAST DELIVERY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Ghatampur Darkstore',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: context.isCompact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Farm-Fresh Veggies, Milk, Snacks & Staples',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: context.isCompact ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Order Now Action Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE20A22), Color(0xFFFF2D55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ORDER NOW',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: context.isCompact ? 9 : 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Visual Showcase
                    SizedBox(
                      width: context.isCompact ? 78 : 96,
                      height: context.isCompact ? 78 : 96,
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

  Color _getCategorySoftColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFF0FDF4);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFFFBEB);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || n.contains('dal')) {
      return const Color(0xFFFEF3C7);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch')) {
      return const Color(0xFFFFF7ED);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink')) {
      return const Color(0xFFEFF6FF);
    }
    if (s.contains('ice-cream') || n.contains('ice cream')) {
      return const Color(0xFFFDF2F8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet')) {
      return const Color(0xFFFAF5FF);
    }
    if (s.contains('bakery') || n.contains('bakery') || s.contains('biscuit')) {
      return const Color(0xFFFFFBEB);
    }
    return const Color(0xFFF8FAFC);
  }

  Color _getCategoryBorderColor(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('fruit') || s.contains('veg') || n.contains('fruit') || n.contains('veg')) {
      return const Color(0xFFDCFCE7);
    }
    if (s.contains('dairy') || n.contains('dairy') || s.contains('milk') || n.contains('milk')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('atta') || s.contains('rice') || s.contains('kitchen') || n.contains('dal')) {
      return const Color(0xFFFDE68A);
    }
    if (s.contains('snack') || n.contains('snack') || s.contains('munch')) {
      return const Color(0xFFFED7AA);
    }
    if (s.contains('beverage') || n.contains('beverage') || s.contains('drink')) {
      return const Color(0xFFBFDBFE);
    }
    if (s.contains('ice-cream') || n.contains('ice cream')) {
      return const Color(0xFFFBCFE8);
    }
    if (s.contains('choco') || n.contains('choco') || s.contains('sweet')) {
      return const Color(0xFFE9D5FF);
    }
    return const Color(0xFFE2E8F0);
  }

  // 3. Top 8 Categories Grid (2 rows x 4 columns - Luxury Squircle Style)
  Widget _buildTopCategoriesGrid() {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore Categories',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 16.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 10, color: AppDesignSystem.primary),
                        Text(
                          'FAST',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedTabProvider.notifier).state = 2; // Categories tab
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) {
              final groceryCategories = categories.where((c) {
                if (c.parentId != null && c.parentId!.isNotEmpty) return false;
                final slug = c.slug.toLowerCase().trim();
                final name = c.name.toLowerCase().trim();
                if (slug == 'restaurant-food' ||
                    slug == 'restaurant' ||
                    slug == 'cafe' ||
                    slug == 'fast-food-kitchen' ||
                    slug.contains('restaurant') ||
                    slug.contains('fastfood')) {
                  return false;
                }
                if (name.contains('restaurant kitchen') ||
                    name.contains('restaurant') ||
                    name.contains('cafe') ||
                    name.startsWith('fast food')) {
                  return false;
                }
                return true;
              }).take(8).toList();

              if (groceryCategories.isEmpty) return const SizedBox.shrink();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groceryCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                ),
                itemBuilder: (context, index) {
                  final cat = groceryCategories[index];
                  final bgTint = _getCategorySoftColor(cat.slug, cat.name);
                  final borderTint = _getCategoryBorderColor(cat.slug, cat.name);

                  return Bounceable(
                    scaleFactor: 0.93,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgTint,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderTint, width: 1.1),
                              boxShadow: [
                                BoxShadow(
                                  color: borderTint.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(7),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _buildCategoryAvatarImage(cat),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          cat.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: AppDesignSystem.border,
                highlightColor: AppDesignSystem.gray50,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(height: 10, width: 50, color: Colors.white),
                  ],
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
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
                final slug = c.slug.toLowerCase().trim();
                final name = c.name.toLowerCase().trim();
                if (slug == 'restaurant-food' ||
                    slug == 'restaurant' ||
                    slug == 'cafe' ||
                    slug == 'fast-food-kitchen' ||
                    slug.contains('restaurant') ||
                    slug.contains('fastfood')) {
                  return false;
                }
                if (name.contains('restaurant kitchen') ||
                    name.contains('restaurant') ||
                    name.contains('cafe') ||
                    name.startsWith('fast food')) {
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
    final name = cat.name.toLowerCase().trim();
    if (slug == 'fruits-vegetables' || slug.contains('fruit') || slug.contains('veg') || name.contains('fruit') || name.contains('veg')) {
      return Image.asset('assets/categories/fruits_vegetables_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug.contains('dry-fruit') || slug.contains('super') || name.contains('dry fruit') || name.contains('nuts')) {
      return Image.asset('assets/categories/fruits_vegetables_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'dairy-breakfast' || slug.contains('dairy') || slug.contains('milk') || name.contains('milk') || name.contains('dairy')) {
      return Image.asset('assets/categories/dairy_breakfast_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'snacks-munchies' || slug.contains('snack') || slug.contains('munch') || name.contains('snack') || name.contains('munch')) {
      return Image.asset('assets/categories/snacks_munchies_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'beverages' || slug.contains('drink') || slug.contains('cold') || name.contains('beverage') || name.contains('drink')) {
      return Image.asset('assets/categories/beverages_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'ice-cream' || slug.contains('ice') || slug.contains('dessert') || name.contains('ice cream')) {
      return Image.asset('assets/categories/ice_cream_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'atta-rice-dal' || slug.contains('atta') || slug.contains('rice') || slug.contains('kitchen') || slug.contains('ration') || name.contains('kitchen') || name.contains('ration')) {
      return Image.asset('assets/categories/atta_rice_dal_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug.contains('packaged') || name.contains('packaged')) {
      return Image.asset('assets/categories/snacks_munchies_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'personal-care' || slug.contains('care') || slug.contains('hygiene') || name.contains('personal care')) {
      return Image.asset('assets/categories/personal_care_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'home-needs-and-cleaning' || slug == 'household' || slug.contains('clean') || slug.contains('home') || name.contains('cleaning') || name.contains('home needs')) {
      return Image.asset('assets/categories/household_category.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'bakery' || slug.contains('biscuit') || name.contains('bakery')) {
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

  // 6. Curated For You Filter Tabs (100% Real Grocery Categories ONLY)
  Widget _buildCuratedForYouFilter() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) return false;
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood') ||
          name.contains('restaurant') ||
          name.contains('cafe')) {
        return false;
      }
      return true;
    }).toList();

    final curations = <Map<String, dynamic>>[
      {
        'title': 'All',
        'isAll': true,
        'icon': Icons.storefront_rounded,
        'iconColor': AppDesignSystem.indigo500,
        'bg': AppDesignSystem.indigo50,
      },
      ...groceryCategories.map((cat) {
        final slug = cat.slug.toLowerCase().trim();
        final asset = _categoryAssetMap[slug];
        final imageUrl = (cat.imageUrl != null && cat.imageUrl!.startsWith('http')) ? cat.imageUrl : null;
        return {
          'title': cat.name,
          'isAll': false,
          'category': cat,
          'imageUrl': imageUrl,
          'asset': asset,
          'icon': Icons.shopping_basket_rounded,
          'iconColor': AppDesignSystem.primary,
          'bg': AppDesignSystem.slate50,
        };
      }),
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
            'Handpicked collections by category',
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
                    setState(() {
                      _selectedFilterIndex = index;
                      _visibleGridCount = 20;
                    });
                  },
                  child: Column(
                    children: [
                      // Circular Icon Avatar (Crisp Category Image or Vector Graphic)
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
                          child: (item['isAll'] == true)
                              ? Icon(
                                  item['icon'] as IconData,
                                  color: item['iconColor'] as Color,
                                  size: 26,
                                )
                              : (item['imageUrl'] != null)
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: item['imageUrl'] as String,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => (item['asset'] != null)
                                            ? Image.asset(item['asset'] as String, width: 48, height: 48, fit: BoxFit.cover)
                                            : Icon(item['icon'] as IconData, color: item['iconColor'] as Color, size: 24),
                                      ),
                                    )
                                  : (item['asset'] != null)
                                      ? ClipOval(
                                          child: Image.asset(
                                            item['asset'] as String,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(item['icon'] as IconData, color: item['iconColor'] as Color, size: 24),
                                          ),
                                        )
                                      : Icon(item['icon'] as IconData, color: item['iconColor'] as Color, size: 24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Tab Title Text
                      SizedBox(
                        width: 70,
                        child: Text(
                          item['title'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.textPrimary : AppDesignSystem.textSecondary,
                          ),
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

  // 7. Dynamic Product Sections (All Categories 10+ Products like Blinkit/Zepto)
  List<Widget> _buildApiProductSections() {
    // Use shared catalog — single fetch, filter locally per section
    final catalogAsync = ref.watch(homeProductCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    if (categoriesAsync.valueOrNull == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final categories = categoriesAsync.valueOrNull!;

    final groceryCategories = categories.where((c) {
      // Subcategories must not create separate home shelves!
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        return false;
      }
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood')) {
        return false;
      }
      if (name.contains('restaurant kitchen') ||
          name.contains('restaurant') ||
          name.contains('cafe') ||
          name.startsWith('fast food')) {
        return false;
      }
      return true;
    }).toList();

    if (groceryCategories.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

    return catalogAsync.when(
      loading: () => groceryCategories.take(4).map((cat) =>
        SliverToBoxAdapter(child: _buildHorizontalProductSection(cat, [], totalCount: 0))
      ).toList(),
      error: (_, __) => groceryCategories.take(4).map((cat) =>
        SliverToBoxAdapter(child: _buildHorizontalProductSection(cat, [], totalCount: 0))
      ).toList(),
      data: (allProducts) {
        final slivers = <Widget>[];

        // If a specific category tab is selected, show only that category's shelf
        var targetCategories = groceryCategories;
        if (_selectedFilterIndex > 0 && _selectedFilterIndex <= groceryCategories.length) {
          targetCategories = [groceryCategories[_selectedFilterIndex - 1]];
        }

        for (final cat in targetCategories) {
          final categoryProducts = allProducts
              .where((p) => _isProductInCategory(p, cat))
              .toList();
          if (categoryProducts.isEmpty) continue;
          final childSubcategories = categories.where((c) =>
            c.parentId != null && c.parentId!.isNotEmpty && c.parentId!.toLowerCase().trim() == cat.id.toLowerCase().trim()
          ).toList();

          slivers.add(
            SliverToBoxAdapter(
              child: _buildHorizontalProductSection(
                cat,
                categoryProducts,
                childSubcategories: childSubcategories,
                totalCount: categoryProducts.length,
              ),
            ),
          );
        }
        return slivers;
      },
    );
  }

  bool _isProductInCategory(Product p, Category cat) {
    if (p.restaurantId != null && p.restaurantId!.isNotEmpty) return false;
    if (p.restaurant != null) return false;

    final catId = cat.id.toLowerCase().trim();
    final pCatId = (p.category?.id ?? p.categoryId ?? '').toLowerCase().trim();
    final pParentId = (p.category?.parentId ?? '').toLowerCase().trim();

    // 0. Direct Category ID match
    if (pCatId.isNotEmpty && pCatId == catId) return true;

    // 1. Direct Parent ID match (Product's subcategory has parentId == cat.id)
    if (pParentId.isNotEmpty && pParentId == catId) return true;

    // 2. Subcategory code match: SUB-<codeId>-XX belongs to CAT-<codeId>
    if (catId.startsWith('cat-')) {
      final code = catId.replaceFirst('cat-', '');
      if (pCatId.startsWith('sub-$code-') || pParentId.startsWith('cat-$code')) {
        return true;
      }
    }

    return false;
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
  Widget _buildHorizontalProductSection(
    Category cat,
    List<Product> allCategoryProducts, {
    List<Category> childSubcategories = const [],
    required int totalCount,
  }) {
    final subtitle = _getCategorySubtitle(cat.name);
    final activeSubcatId = _selectedCategorySubcat[cat.id] ?? 'all';

    List<Product> products = allCategoryProducts;
    if (activeSubcatId != 'all') {
      final selectedSub = childSubcategories.firstWhere(
        (s) => s.id == activeSubcatId,
        orElse: () => childSubcategories.first,
      );
      final targetId = selectedSub.id.toLowerCase().trim();

      products = allCategoryProducts.where((p) {
        final pCatId = (p.categoryId ?? '').toLowerCase().trim();
        final pSubId = (p.category?.id ?? '').toLowerCase().trim();

        return pCatId == targetId || pSubId == targetId;
      }).toList();
    }

    final displayProducts = products.take(10).toList();

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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL ($totalCount)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.red600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 2.5),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.red600),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dynamic Subcategory Chips Strip (only rendered when real subcategories exist in DB)
          if (childSubcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(right: 16),
                itemCount: childSubcategories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final isSelected = isAll
                      ? activeSubcatId == 'all'
                      : activeSubcatId == childSubcategories[index - 1].id;
                  final title = isAll ? 'All' : childSubcategories[index - 1].name;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCategorySubcat[cat.id] = isAll ? 'all' : childSubcategories[index - 1].id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppDesignSystem.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppDesignSystem.primary : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppDesignSystem.primary.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppDesignSystem.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (displayProducts.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppDesignSystem.gray50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Center(
                child: Text(
                  'No items in this subcategory yet',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ),
            )
          else
            AnimationLimiter(
              child: SizedBox(
                height: Responsive.isSmallMobile(context) ? 232 : 252,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(right: Responsive.horizontalPadding(context)),
                  itemCount: displayProducts.length + 1,
                  separatorBuilder: (_, __) => SizedBox(width: Responsive.isSmallMobile(context) ? 8 : 10),
                  itemBuilder: (context, index) {
                    if (index < displayProducts.length) {
                      final product = displayProducts[index];
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

  // 8. Infinite Scroll Product Feed (Batch-loaded 20 items at a time, virtualized 60/120 FPS)
  List<Widget> _buildInfiniteProductFeed() {
    final catalogAsync = ref.watch(homeProductCatalogProvider);

    return catalogAsync.when(
      loading: () => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
            child: _buildInfiniteFeedHeader(0, isLoading: true),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
              childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: 4,
            ),
          ),
        ),
      ],
      error: (_, __) => [const SliverToBoxAdapter(child: SizedBox.shrink())],
      data: (allProducts) {
        // When default "All" is active, avoid dumping an unorganized mixed grid of all 200 items.
        // Instead, show Zepto/Blinkit-style "Explore by Category" Bento Grid + End-of-Aisle Search Prompt!
        if (_selectedFilterIndex == 0) {
          return _buildCategoryBentoFeed();
        }

        final filteredProducts = _getFilteredGridProducts(allProducts);
        if (filteredProducts.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Text('🛍️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        'No products found in this collection',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try picking another category tab above',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        }

        final visibleProducts = filteredProducts.take(_visibleGridCount).toList();
        final hasMore = _visibleGridCount < filteredProducts.length;

        return [
          // Section Title Header with Dynamic Total Count Badge
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
              child: _buildInfiniteFeedHeader(filteredProducts.length, isLoading: false),
            ),
          ),

          // 2-Column Virtualized SliverGrid (Ultra-smooth, zero jank, only on-screen items kept in memory)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
                childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = visibleProducts[index];
                  return ProductCard(
                    key: ValueKey('infinite_grid_${product.id}'),
                    product: product,
                    isCompact: false,
                  );
                },
                childCount: visibleProducts.length,
              ),
            ),
          ),

          // Bottom Load More Indicator or Catalog Completion Badge
          SliverToBoxAdapter(
            child: _buildInfiniteFeedFooter(
              visibleCount: visibleProducts.length,
              totalCount: filteredProducts.length,
              hasMore: hasMore,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildInfiniteFeedHeader(int totalCount, {required bool isLoading}) {
    String title = 'All Groceries & Essentials';
    String subtitle = '⚡ Fast Delivery from Ghatampur darkstore';
    IconData icon = Icons.auto_awesome_rounded;

    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) return false;
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood') ||
          name.contains('restaurant') ||
          name.contains('cafe')) {
        return false;
      }
      return true;
    }).toList();

    if (_selectedFilterIndex > 0 && _selectedFilterIndex <= groceryCategories.length) {
      final selectedCat = groceryCategories[_selectedFilterIndex - 1];
      title = selectedCat.name;
      subtitle = _getCategorySubtitle(selectedCat.name);
      icon = Icons.shopping_basket_rounded;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppDesignSystem.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 16.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppDesignSystem.primary.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 12, color: AppDesignSystem.primary),
                const SizedBox(width: 4),
                Text(
                  '$totalCount Items',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfiniteFeedFooter({
    required int visibleCount,
    required int totalCount,
    required bool hasMore,
  }) {
    if (hasMore) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesignSystem.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading next 20 products... ($visibleCount of $totalCount)',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // When all items have been reached in the feed
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        border: Border.all(color: AppDesignSystem.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
              const SizedBox(width: 6),
              Text(
                'You\'ve explored all $totalCount items!',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _homeScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 13, color: AppDesignSystem.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Back to top',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.primary,
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

  // 8b. Zepto/Blinkit-Style Category Bento Feed (Clean Department Grid replacing mixed product soup)
  List<Widget> _buildCategoryBentoFeed() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final catalogProducts = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];

    return categoriesAsync.when(
      loading: () => [
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      error: (_, __) => [
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      ],
      data: (categories) {
        final groceryCategories = categories.where((cat) {
          final slug = cat.slug.toLowerCase().trim();
          final name = cat.name.toLowerCase().trim();
          if (cat.parentId != null && cat.parentId!.isNotEmpty) return false;
          if (slug == 'all' || slug.contains('restaurant') || slug.contains('cafe')) return false;
          if (name.contains('restaurant') || name.contains('cafe')) return false;
          return true;
        }).toList();

        if (groceryCategories.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

        // Pre-index subcategories by parentId to compute exact recursive product count sums
        final Map<String, int> categorySumMap = {};
        for (final parent in groceryCategories) {
          final parentIdLower = parent.id.toLowerCase().trim();
          final parentSlugLower = parent.slug.toLowerCase().trim();

          // Find all direct children/subcategories
          final childCats = categories.where((c) {
            if (c.parentId == null || c.parentId!.isEmpty) return false;
            final pId = c.parentId!.toLowerCase().trim();
            return pId == parentIdLower || pId == parentSlugLower;
          }).toList();

          int totalCount = parent.productCount ?? 0;
          for (final sub in childCats) {
            totalCount += (sub.productCount ?? 0);
          }

          // Also count loaded catalog products matching this parent category
          if (catalogProducts.isNotEmpty) {
            final liveMatches = catalogProducts.where((p) => _isProductInCategory(p, parent)).length;
            if (liveMatches > totalCount) {
              totalCount = liveMatches;
            }
          }

          // Fallback to rich default estimates if database count is 0
          if (totalCount <= 0) {
            final slug = parent.slug.toLowerCase();
            if (slug.contains('kitchen') || slug.contains('atta') || slug.contains('ration')) {
              totalCount = 42;
            } else if (slug.contains('fruit') || slug.contains('veg')) {
              totalCount = 33;
            } else if (slug.contains('snack') || slug.contains('munch')) {
              totalCount = 28;
            } else if (slug.contains('dry') || slug.contains('super')) {
              totalCount = 24;
            } else if (slug.contains('beverage') || slug.contains('drink')) {
              totalCount = 19;
            } else if (slug.contains('ice') || slug.contains('dessert')) {
              totalCount = 15;
            } else if (slug.contains('package')) {
              totalCount = 18;
            } else if (slug.contains('care') || slug.contains('hygiene')) {
              totalCount = 22;
            } else if (slug.contains('home') || slug.contains('clean')) {
              totalCount = 20;
            } else if (slug.contains('dairy') || slug.contains('milk')) {
              totalCount = 25;
            } else {
              totalCount = 16;
            }
          }

          categorySumMap[parent.id] = totalCount;
        }

        return [
          // Section Title Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                    ),
                    child: const Icon(Icons.grid_view_rounded, size: 18, color: AppDesignSystem.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore All Categories',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Browse complete aisles & subcategories in Ghatampur',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-Column Luxury Bento Grid of Categories
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
                childAspectRatio: context.isCompact ? 1.95 : 2.12,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = groceryCategories[index];
                  final totalCount = categorySumMap[cat.id] ?? (cat.productCount ?? 16);
                  final bgTint = _getCategorySoftColor(cat.slug, cat.name);
                  final borderTint = _getCategoryBorderColor(cat.slug, cat.name);

                  return Bounceable(
                    scaleFactor: 0.94,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderTint.withValues(alpha: 0.6), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Luxury Image Container with soft category-calibrated tint
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: bgTint,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: borderTint, width: 0.9),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: _buildCategoryAvatarImage(cat),
                            ),
                          ),
                          const SizedBox(width: 9),

                          // Text Content (Truncation-Free & Clean)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cat.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$totalCount+ items',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Clean Nav Arrow
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: groceryCategories.length,
              ),
            ),
          ),

          // End of Aisle Search & Discovery Prompt Card
          SliverToBoxAdapter(
            child: _buildEndOfAisleSearchCard(),
          ),
        ];
      },
    );
  }

  Widget _buildEndOfAisleSearchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppDesignSystem.rose50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.red200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_rounded, size: 22, color: AppDesignSystem.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Looking for something else?',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Search 1,000+ grocery essentials & treats',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppDesignSystem.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignSystem.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Search FastKirana Store',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _homeScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward_rounded, size: 13, color: AppDesignSystem.primary),
                const SizedBox(width: 4),
                Text(
                  'Back to top',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 9. Footer
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

    return [
      // Web 1:1 Parity Food Mode Hero Banner ("Good Food, Great Mood" / Craving Something Delicious?)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Container(
            height: 148,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner Image
                  Image.asset(
                    'assets/categories/food_banner_bg.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/categories/food_promo_banner_premium.webp',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Gradient overlay for text contrast (light mode fade like Web)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFDF8F4).withValues(alpha: 0.96),
                          const Color(0xFFFDF8F4).withValues(alpha: 0.82),
                          const Color(0xFFFDF8F4).withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.70, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),

                  // Overlay Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Strip
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'KITCHEN OPEN',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 8.5),
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF15803D),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '✨ Good Food • Mood',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 8.5),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          'Craving Delicious Food?',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 17),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFDC2626),
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Subtitle
                        Text(
                          'Hot burgers, gravies & rolls from top spots',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

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
