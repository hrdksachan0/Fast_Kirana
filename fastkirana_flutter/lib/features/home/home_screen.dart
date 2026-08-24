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
import '../../widgets/brand_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../categories/category_products_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
import '../cafe/cafe_menu_screen.dart';
import '../profile/address_book_screen.dart';
import '../profile/notifications_screen.dart';
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
    "Search 'milk', 'bread', 'butter'...",
    "Search 'paneer', 'cheese', 'curd'...",
    "Search 'maggi', 'chips', 'snacks'...",
    "Search 'atta', 'rice', 'fortune oil'...",
    "Search 'burger', 'pizza', 'rolls'...",
  ];

  static const List<Map<String, dynamic>> _heroPromoSlides = [
    {
      'badge': 'WELCOME OFFER',
      'title': 'Flat 5% OFF on Order',
      'subtitle': 'Use code FIRST5 on checkout',
      'code': 'FIRST5',
      'gradient': [Color(0xFFE20A22), Color(0xFFFF4D62)],
      'emoji': '🛍️',
    },
    {
      'badge': 'SUPER SAVINGS',
      'title': 'Free Delivery on ₹200+',
      'subtitle': 'Express Fast Delivery',
      'code': 'FASTFREE',
      'gradient': [Color(0xFF00B140), Color(0xFF3CC070)],
      'emoji': '⚡',
    },
    {
      'badge': 'HOT CAFE MEALS',
      'title': 'Burger, Pizza & Rolls',
      'subtitle': 'Freshly prepared from top cafes',
      'code': 'CAFE5',
      'gradient': [Color(0xFFEA580C), Color(0xFFD97706)],
      'emoji': '🍔',
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
        child: RefreshIndicator(
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
              SliverToBoxAdapter(child: _buildHeader(cartCount)),

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
      ),
    );
  }

  // 1. Top Bar (Logo, 10-15 Min Delivery Timing, Location Selector, Notifications)
  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + Delivery Speed & Address + Notifications
          Row(
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: 38),
              const SizedBox(width: 12),

              // Location & Speed Delivery Info
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen()));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timing & Lightning Badge Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF15803D)),
                                const SizedBox(width: 2.5),
                                Text(
                                  '10-15 MINS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF14532D),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EXPRESS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE20A22),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Location Name with Chevron
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Ghatampur, UP',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF111827),
                                height: 1.15,
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

          // Search Bar (Modern Pill with Animated Rotating Placeholder & Mic)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFFE20A22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _searchPlaceholders[_searchPlaceholderIndex],
                        key: ValueKey<int>(_searchPlaceholderIndex),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Grocery / Food Mode Switcher
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            // Grocery Option
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    gradient: _isGrocerySelected
                        ? const LinearGradient(
                            colors: [Color(0xFFE8153A), Color(0xFFFF2D55), Color(0xFFFF5533)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                    boxShadow: _isGrocerySelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE8153A).withOpacity(0.35),
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
                        size: 18,
                        color: _isGrocerySelected ? Colors.white : AppDesignSystem.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grocery',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _isGrocerySelected ? Colors.white : AppDesignSystem.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'FAST DELIVERY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _isGrocerySelected ? Colors.white.withOpacity(0.9) : AppDesignSystem.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Center Dot Divider
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),

            // Food & Cafe Option
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    gradient: !_isGrocerySelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFF5500), Color(0xFFFF7700), Color(0xFFFFAA00)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                    boxShadow: !_isGrocerySelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF5500).withOpacity(0.35),
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
                        size: 18,
                        color: !_isGrocerySelected ? Colors.white : AppDesignSystem.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food & Cafe',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: !_isGrocerySelected ? Colors.white : AppDesignSystem.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'CAFE & BISTRO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: !_isGrocerySelected ? Colors.white.withOpacity(0.9) : AppDesignSystem.textMuted,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
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
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            slide['emoji'] as String,
                            style: const TextStyle(fontSize: 28),
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

  // 4. Value Proposition Strip (Exact www.fastkirana.in Web Match)
  Widget _buildValuePropositionStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '⚡ Ghatampur',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 16, color: const Color(0xFFE5E7EB)),
            Text(
              '📦 50+',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            Container(width: 1, height: 16, color: const Color(0xFFE5E7EB)),
            Text(
              '❤️ 1000+',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropItem(String title, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppDesignSystem.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
            color: AppDesignSystem.textSecondary,
          ),
        ),
      ],
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
                    final imgUrl = cat.imageUrl ?? '';

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
                            // Circular Avatar with High-Res Image
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF3F4F6),
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                                boxShadow: AppDesignSystem.shadowSm,
                              ),
                              child: ClipOval(
                                child: imgUrl.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: imgUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Shimmer.fromColors(
                                          baseColor: const Color(0xFFE5E7EB),
                                          highlightColor: const Color(0xFFF9FAFB),
                                          child: Container(color: Colors.white),
                                        ),
                                        errorWidget: (_, __, ___) => const Center(
                                          child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF9CA3AF), size: 28),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF9CA3AF), size: 28),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textPrimary,
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

  // 6. Curated For You Filter Tabs (Sticky & Dynamic)
  Widget _buildCuratedForYouFilter() {
    final timeTab = _getTimeBasedTab();
    final filterTabs = ['All', 'Flash Deals', 'Best Sellers', 'Trending', timeTab];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                'Curated For You',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filterTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedFilterIndex;
                final isTimeTab = index == 4;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppDesignSystem.primary
                          : isTimeTab
                              ? const Color(0xFFFEF3C7)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                      border: Border.all(
                        color: isSelected
                            ? AppDesignSystem.primary
                            : isTimeTab
                                ? const Color(0xFFFDE68A)
                                : AppDesignSystem.border,
                      ),
                    ),
                    child: Text(
                      filterTabs[index],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : isTimeTab
                                ? const Color(0xFFB45309)
                                : AppDesignSystem.textSecondary,
                      ),
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

  // 7. Dynamic Product Sections
  List<Widget> _buildApiProductSections() {
    final entries = _sectionCategorySlugs.entries.toList();
    return entries.map((entry) {
      final slug = entry.value;
      final productsAsync = ref.watch(productsProvider(slug));
      return SliverToBoxAdapter(
        child: productsAsync.when(
          data: (products) => products.isEmpty
              ? const SizedBox.shrink()
              : _buildHorizontalProductSection(
                  entry.key,
                  _sectionSubtitle(entry.key),
                  products,
                ),
          loading: () => _buildProductSectionSkeleton(entry.key),
          error: (_, __) => const SizedBox.shrink(),
        ),
      );
    }).toList();
  }

  String _sectionSubtitle(String name) {
    switch (name) {
      case 'Snacks & Munchies':
        return 'Crunchy chips, namkeen & biscuits';
      case 'Chocolates & Sweets':
        return 'Dairy Milk Silk, bars & treats';
      case 'Instant Foods':
        return 'Maggi, noodles & instant soup';
      case 'Kitchen Needs':
        return 'Fortune oil, atta, spices & salt';
      case 'Ice Cream':
        return 'Cool tubs, cones & shakes';
      default:
        return '';
    }
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

  // Horizontal Product Track with End Card
  Widget _buildHorizontalProductSection(String title, String subtitle, List<Product> products) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
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
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All →',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 235,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return SizedBox(
                  width: 150,
                  child: ProductCard(product: product),
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
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Popular Restaurants & Cafes',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppDesignSystem.textPrimary),
          ),
        ),
      ),
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
