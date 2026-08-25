import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/brand_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/address_provider.dart';
import '../../providers/banner_provider.dart';
import '../categories/category_products_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
import '../cafe/cafe_menu_screen.dart';
import '../profile/address_book_screen.dart';
import '../profile/notifications_screen.dart';
import '../location/delivery_location_screen.dart';
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
  int _currentBannerIndex = 0;
  Timer? _searchTimer;
  Timer? _bannerTimer;
  final PageController _bannerController = PageController();

  static const List<String> _searchPlaceholders = [
    'Search "atta"',
    'Search "milk"',
    'Search "maggi"',
    'Search "fortune oil"',
    'Search "dairy milk"',
    'Search "chips"',
  ];

  static const List<Map<String, dynamic>> _heroPromoSlides = [
    {
      'badge': 'WELCOME OFFER',
      'title': 'Flat 5% OFF on Order',
      'subtitle': 'Use code FIRST5 on checkout',
      'code': 'FIRST5',
      'gradient': [Color(0xFFE20A22), Color(0xFFFF416C)],
      'imageAsset': 'assets/categories/grocery_bag_banner.png',
      'webFallback': 'https://www.fastkirana.in/grocery_bag_banner.png',
      'categorySlug': 'all',
    },
    {
      'badge': 'FARM FRESH',
      'title': 'Fresh Veggies & Fruits',
      'subtitle': 'Directly from local farms',
      'code': 'SAVE20',
      'gradient': [Color(0xFF059669), Color(0xFF10B981)],
      'imageAsset': 'assets/categories/fruits_vegetables_category.png',
      'webFallback': 'https://www.fastkirana.in/fruits_vegetables_category.png',
      'categorySlug': 'fruits-vegetables',
    },
    {
      'badge': 'HOT CAFE MEALS',
      'title': 'Burger, Pizza & Rolls',
      'subtitle': 'Freshly prepared from top cafes',
      'code': 'CAFE5',
      'gradient': [Color(0xFFEA580C), Color(0xFFF97316)],
      'imageAsset': 'assets/categories/cafe_promo_banner.png',
      'webFallback': 'https://www.fastkirana.in/cafe_promo_banner.png',
      'categorySlug': 'restaurant-food',
    },
    {
      'badge': 'SUMMER SPECIAL',
      'title': 'Ice Creams & Shakes',
      'subtitle': 'Amul, Kwality Wall\'s & more',
      'code': 'SWEET10',
      'gradient': [Color(0xFF4F46E5), Color(0xFF818CF8)],
      'imageAsset': 'assets/categories/ice_cream_category.png',
      'webFallback': 'https://www.fastkirana.in/ice_cream_category.png',
      'categorySlug': 'ice-cream',
    },
  ];

  static const Map<String, String> _categoryAssetMap = {
    'fruits-vegetables': 'assets/categories/fruits_vegetables_category.png',
    'fruits-and-vegetables': 'assets/categories/fruits_vegetables_category.png',
    'dairy-breakfast': 'assets/categories/dairy_breakfast_category.png',
    'dairy-bread-eggs': 'assets/categories/dairy_breakfast_category.png',
    'snacks-munchies': 'assets/categories/snacks_munchies_category.png',
    'snacks': 'assets/categories/snacks_munchies_category.png',
    'beverages': 'assets/categories/beverages_category.png',
    'personal-care': 'assets/categories/personal_care_category.png',
    'household': 'assets/categories/household_category.png',
    'home-cleaning': 'assets/categories/household_category.png',
    'bakery-biscuits': 'assets/categories/bakery_biscuits_category.png',
    'bakery': 'assets/categories/bakery_biscuits_category.png',
    'atta-rice-dal': 'assets/categories/atta_rice_dal_category.png',
    'kitchen-needs': 'assets/categories/atta_rice_dal_category.png',
    'ice-cream': 'assets/categories/ice_cream_category.png',
    'instant-foods': 'assets/categories/snacks_munchies_category.png',
    'chocolates': 'assets/categories/bakery_biscuits_category.png',
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

    // Auto-scroll promo banner every 5 seconds
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _bannerController.hasClients) {
        final next = (_currentBannerIndex + 1) % _heroPromoSlides.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
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
                for (final slug in _sectionCategorySlugs.values) {
                  ref.invalidate(productsProvider(slug));
                }
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Pinned Header & Search
                  SliverToBoxAdapter(child: _buildTopHeader()),

                  // 2. Mode Switcher (Grocery vs Food)
                  SliverToBoxAdapter(child: _buildCategoryToggle()),

                  if (_isGrocerySelected) ...[
                    // 3. Hero Promo Banner Carousel
                    SliverToBoxAdapter(child: _buildHeroPromoCarousel()),

                    // 4. Value Proposition Strip
                    SliverToBoxAdapter(child: _buildValuePropositionStrip()),

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

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + Clean Location Header + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: 38),
              const SizedBox(width: 12),

              // Location Selector
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final selectedAddress = ref.watch(selectedAddressProvider);
                    final locationTitle = selectedAddress != null
                        ? (selectedAddress.label.isNotEmpty ? selectedAddress.label : 'Saved Location')
                        : 'Ghatampur, UP';
                    final locationSubtitle = selectedAddress != null
                        ? selectedAddress.area.isNotEmpty
                            ? selectedAddress.area
                            : selectedAddress.fullAddress
                        : 'Express Delivery Zone';

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DeliveryLocationScreen()),
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
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Delivering to • $locationSubtitle',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  locationTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF111827),
                                    height: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF111827)),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF374151)),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE20A22),
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
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
                        key: ValueKey<int>(_searchPlaceholderIndex),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _searchPlaceholders[_searchPlaceholderIndex],
                          textAlign: TextAlign.left,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  // 2. Grocery / Food Mode Switcher (100% Exact Match to Reference Screenshot)
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            // Grocery Option (Active Red Gradient Pill)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: _isGrocerySelected
                        ? const LinearGradient(
                            colors: [Color(0xFFE20A22), Color(0xFFFF334B)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: _isGrocerySelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE20A22).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: _isGrocerySelected ? Colors.white : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grocery',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _isGrocerySelected ? Colors.white : const Color(0xFF374151),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'FAST DELIVERY',
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _isGrocerySelected ? Colors.white.withOpacity(0.95) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
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
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: !_isGrocerySelected
                        ? const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: !_isGrocerySelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        size: 19,
                        color: !_isGrocerySelected ? Colors.white : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: !_isGrocerySelected ? Colors.white : const Color(0xFF374151),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'FOOD & RESTAURANTS',
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: !_isGrocerySelected ? Colors.white.withOpacity(0.95) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Hero Promo Banner Carousel
  Widget _buildHeroPromoCarousel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: PageView.builder(
              controller: _bannerController,
              onPageChanged: (i) => setState(() => _currentBannerIndex = i),
              itemCount: _heroPromoSlides.length,
              itemBuilder: (context, index) {
                final slide = _heroPromoSlides[index];
                final colors = slide['gradient'] as List<Color>;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    slide['badge'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if ((slide['code'] as String).isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.confirmation_number_outlined, size: 10, color: Colors.white),
                                        const SizedBox(width: 3),
                                        Text(
                                          slide['code'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.15,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              slide['subtitle'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.92),
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Real Graphical Banner Illustration
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            slide['imageAsset'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => CachedNetworkImage(
                              imageUrl: slide['webFallback'] as String,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Dot Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _heroPromoSlides.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentBannerIndex == index ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _currentBannerIndex == index
                      ? AppDesignSystem.primary
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedTabProvider.notifier).state = 1; // Switch to categories tab
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'SEE ALL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFDB2777),
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
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final cat = categories[index];

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryProductsScreen(category: cat),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 68,
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF9FAFB),
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildCategoryAvatarImage(cat),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                                height: 1.15,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: const Color(0xFFE5E7EB),
                  highlightColor: const Color(0xFFF9FAFB),
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
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF9FAFB),
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
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF9FAFB),
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => _buildCategoryFallback(cat),
      );
    }

    // 3. Check exact slug mappings
    final slug = cat.slug.toLowerCase().trim();
    if (slug == 'fruits-vegetables' || slug.contains('fruit') || slug.contains('veg')) {
      return Image.asset('assets/categories/fruits_vegetables_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'dairy-breakfast' || slug.contains('dairy') || slug.contains('milk')) {
      return Image.asset('assets/categories/dairy_breakfast_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'snacks-munchies' || slug.contains('snack')) {
      return Image.asset('assets/categories/snacks_munchies_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'beverages' || slug.contains('drink') || slug.contains('cold')) {
      return Image.asset('assets/categories/beverages_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'ice-cream' || slug.contains('ice') || slug.contains('dessert')) {
      return Image.asset('assets/categories/ice_cream_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'atta-rice-dal' || slug.contains('atta') || slug.contains('rice') || slug.contains('kitchen')) {
      return Image.asset('assets/categories/atta_rice_dal_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'personal-care' || slug.contains('care') || slug.contains('hygiene')) {
      return Image.asset('assets/categories/personal_care_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'home-needs-and-cleaning' || slug == 'household' || slug.contains('clean')) {
      return Image.asset('assets/categories/household_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'bakery' || slug.contains('biscuit')) {
      return Image.asset('assets/categories/bakery_biscuits_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }
    if (slug == 'restaurant-food' || slug.contains('cafe') || slug.contains('food')) {
      return Image.asset('assets/categories/cafe_category.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCategoryFallback(cat));
    }

    return _buildCategoryFallback(cat);
  }

  Widget _buildCategoryFallback(Category cat) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Text(
          cat.name.isNotEmpty ? cat.name.characters.first.toUpperCase() : '🛍️',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFE20A22),
          ),
        ),
      ),
    );
  }

  // 4. Value Proposition Strip
  Widget _buildValuePropositionStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '10-15 Min Delivery',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 12, color: const Color(0xFFE2E8F0)),
            Row(
              children: [
                const Text('🏷️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  'Best Prices',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 12, color: const Color(0xFFE2E8F0)),
            Row(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '100% Genuine',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
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
        'iconColor': const Color(0xFF6366F1),
        'bg': const Color(0xFFEEF2FF),
      },
      {
        'title': 'Flash Deals',
        'icon': Icons.bolt_rounded,
        'iconColor': const Color(0xFFEF4444),
        'bg': const Color(0xFFFEF2F2),
      },
      {
        'title': 'Best Sellers',
        'icon': Icons.emoji_events_rounded,
        'iconColor': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFEFCE8),
      },
      {
        'title': 'Trending',
        'icon': Icons.local_fire_department_rounded,
        'iconColor': const Color(0xFFF97316),
        'bg': const Color(0xFFFFF7ED),
      },
      {
        'title': 'Snacks',
        'icon': Icons.fastfood_rounded,
        'iconColor': const Color(0xFFEC4899),
        'bg': const Color(0xFFFDF2F8),
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
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Handpicked collections for every mood',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
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
                            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.25),
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
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Active Purple Underline Indicator
                      if (isSelected)
                        Container(
                          width: 22,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
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
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

        return categories.map((cat) {
          final productsAsync = ref.watch(productsProvider(cat.slug));
          return SliverToBoxAdapter(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) return const SizedBox.shrink();
                // Take up to 10 products for the home preview
                final displayProducts = products.take(10).toList();
                return _buildHorizontalProductSection(
                  cat,
                  displayProducts,
                  totalCount: products.length,
                );
              },
              loading: () => _buildProductSectionSkeleton(cat.name),
              error: (_, __) => const SizedBox.shrink(),
            ),
          );
        }).toList();
      },
      loading: () => [
        SliverToBoxAdapter(child: _buildProductSectionSkeleton('Loading Categories...')),
      ],
      error: (_, __) => [const SliverToBoxAdapter(child: SizedBox.shrink())],
    );
  }

  String _getCategorySubtitle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('snack') || lower.contains('munch')) return 'Crunchy chips, namkeen & snacks';
    if (lower.contains('choco') || lower.contains('sweet')) return 'Dairy Milk Silk, bars & confectionery';
    if (lower.contains('fruit') || lower.contains('veg')) return 'Farm fresh vegetables & fruits';
    if (lower.contains('atta') || lower.contains('rice') || lower.contains('kitchen')) return 'Fortune oil, grains, atta & pulses';
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFFE5E7EB),
            highlightColor: const Color(0xFFF9FAFB),
            child: Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: const Color(0xFFF3F4F6),
                highlightColor: const Color(0xFFFFFFFF),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 14,
                            width: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 55,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL ($totalCount)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              itemCount: products.length + 1, // +1 for "Explore More" End Card
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index < products.length) {
                  final product = products[index];
                  return SizedBox(
                    width: 148,
                    child: ProductCard(product: product),
                  );
                }

                // "Explore All" End Card
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFEE2E2),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'See all\n$totalCount items',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
              style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaymentIcon('UPI', const Color(0xFFD97706)),
                const SizedBox(width: 12),
                _buildPaymentIcon('Card', const Color(0xFF22C55E)),
                const SizedBox(width: 12),
                _buildPaymentIcon('COD', AppDesignSystem.primary),
                const SizedBox(width: 12),
                _buildPaymentIcon('Wallet', const Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '+91 70544 70303 | help@fastkirana.com',
              style: GoogleFonts.inter(fontSize: 10.5, color: AppDesignSystem.textSecondary),
            ),
            Text(
              '6 AM – 12 AM | NH34, Ghatampur, Kanpur Nagar',
              style: GoogleFonts.inter(fontSize: 9.5, color: AppDesignSystem.textMuted),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ==========================================
  // FOOD & CAFE STOREFRONT (1:1 Web App Parity)
  // ==========================================


  // 3. Time-Aware Greeting Card + Birthday Promo Banner (Matches 1_home_grocery.png 1:1)
  Widget _buildHeroPromoBanner() {
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
          color: const Color(0xFFFEFDF5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFEF08A)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCA8A04).withOpacity(0.04),
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
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('☀️ ⚡', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'GROCERY MART • ONLINE',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB45309),
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
                    color: Color(0xFF10B981),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fresh dairy, fruits & daily essentials in 10-15 mins',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),

            // Time range pill: 🛒 GROCERY MART: 7 AM – 10 PM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🛒', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(
                    'GROCERY MART: 7 AM – 10 PM',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF047857),
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
                  colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
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
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 9)),
                        const SizedBox(width: 3),
                        Text(
                          'Fast Delivery',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Freshly baked custom treats, party snacks & drinks',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.9),
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
    final restaurantsAsync = ref.watch(restaurantsProvider);

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
      // 1. Food Hero Promo Card
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withOpacity(0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'HOT & FRESH • 25-30 MINS ⚡',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hungry? Order From Top Outlets! 🍕🔥',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wedson, Bal Udyan & A.S. Cafe delivered hot',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🍲', style: TextStyle(fontSize: 30)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),



      // 3. Featured Outlets Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                'Top Restaurants & Cafes',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'EXPRESS DELIVERY',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFB45309),
                  ),
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
        loading: () => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
