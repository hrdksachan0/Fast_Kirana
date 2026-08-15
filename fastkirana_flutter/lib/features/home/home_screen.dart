import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/restaurant_card.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
import '../cafe/cafe_menu_screen.dart';
import 'main_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGrocerySelected = true;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color primaryRedDark = Color(0xFFB30013);
  static const Color primaryRedLight = Color(0xFFFF4D62);
  static const Color primaryRedBg = Color(0xFFFFE4E6);
  static const Color accentGreen = Color(0xFF00B140);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentOrangeDark = Color(0xFFEA580C);
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  // Map of category slug -> palette color, used purely for visual styling of tiles
  static const Map<String, Color> _categoryTints = {
    'fruits-vegetables': Color(0xFFDCFCE7),
    'fruits-and-vegetables': Color(0xFFDCFCE7),
    'instant-foods': Color(0xFFFFF7ED),
    'beverages': Color(0xFFE0F2FE),
    'ice-cream': Color(0xFFFEF3C7),
    'snacks-munchies': Color(0xFFFFF0F0),
    'snacks': Color(0xFFFFF0F0),
    'bakery': Color(0xFFFFF7ED),
    'dry-fruits': Color(0xFFFEF3C7),
    'grocery': Color(0xFFFFF5F7),
    'grocery-essential': Color(0xFFFFF5F7),
    'chocolates': Color(0xFFFFF0F0),
    'personal-care': Color(0xFFE0F2FE),
    'home-cleaning': Color(0xFFFFF5F7),
    'kitchen-needs': Color(0xFFFFF7ED),
  };

  // Default gradient cycle for tiles without a slug match
  static const List<Color> _tilePalette = [
    Color(0xFFDCFCE7),
    Color(0xFFFFF7ED),
    Color(0xFFE0F2FE),
    Color(0xFFFEF3C7),
    Color(0xFFFFF0F0),
    Color(0xFFFFF5F7),
  ];

  Color _tintForCategory(String slug) {
    return _categoryTints[slug] ?? _tilePalette[slug.hashCode.abs() % _tilePalette.length];
  }

  String _getCategoryAssetImage(String slug) {
    final cleanSlug = slug.replaceAll('-', '_');
    final categoryImageMap = {
      'fruits_vegetables': 'assets/categories/fruits_vegetables_category.png',
      'fruits_and_vegetables': 'assets/categories/fruits_vegetables_category.png',
      'dairy_breakfast': 'assets/categories/dairy_breakfast_category.png',
      'snacks_munchies': 'assets/categories/snacks_munchies_category.png',
      'snacks': 'assets/categories/snacks_munchies_category.png',
      'beverages': 'assets/categories/beverages_category.png',
      'personal_care': 'assets/categories/personal_care_category.png',
      'household': 'assets/categories/household_category.png',
      'bakery_biscuits': 'assets/categories/bakery_biscuits_category.png',
      'bakery': 'assets/categories/bakery_biscuits_category.png',
      'atta_rice_dal': 'assets/categories/atta_rice_dal_category.png',
      'grocery': 'assets/categories/atta_rice_dal_category.png',
      'ice_cream': 'assets/categories/ice_cream_category.png',
      'cafe': 'assets/categories/cafe_category.png',
    };
    return categoryImageMap[cleanSlug] ?? 'assets/brand/fastkirana_app_icon.png';
  }

  // Curated filter tabs
  final List<String> _filterTabs = ['All', 'Flash Deals', 'Best Sellers', 'Trending', 'Late Night'];
  int _selectedFilterIndex = 0;

  // Category slug mapping for product sections
  static const Map<String, String> _sectionCategorySlugs = {
    'Snacks & Munchies': 'snacks-munchies',
    'Chocolates & Sweets': 'chocolates',
    'Instant Foods': 'instant-foods',
    'Kitchen Needs': 'kitchen-needs',
    'Ice Cream': 'ice-cream',
  };

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartCount = cartState.value?.items.fold<int>(0, (s, item) => s + item.quantity) ?? 0;

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: primaryRed,
              onRefresh: () async {
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
                  SliverToBoxAdapter(child: _buildHeader(cartCount)),
                  SliverToBoxAdapter(child: _buildCategoryToggle()),
                  if (_isGrocerySelected) ...[
                    SliverToBoxAdapter(child: _buildHeroPromoBanner()),
                    SliverToBoxAdapter(child: _buildDeliveryStatsBar()),
                    SliverToBoxAdapter(child: _buildTrendingCategoriesSection()),
                    SliverToBoxAdapter(child: _buildCuratedForYouFilter()),
                    ..._buildApiProductSections(),
                    SliverToBoxAdapter(child: _buildFooter()),
                  ] else ...[
                    SliverToBoxAdapter(child: _buildFoodBanner()),
                    SliverToBoxAdapter(child: _buildFoodCuisineCategories()),
                    SliverToBoxAdapter(child: _buildFoodFilterChips()),
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

  // Build each product section dynamically from the API
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
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Header: Delivery Badge + Location + Search + Cart (matches Web App Mobile UI 1:1)
  Widget _buildHeader(int cartCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Brand Logo + Delivery Estimate + Profile
          Row(
            children: [
              // FastKirana Official Brand Logo
              Image.asset(
                'assets/brand/fastkirana_exact_logo.png',
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FastKirana',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Delivery Time Pill (Web App style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryRedBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryRedLight.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      '10-15 MINS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: primaryRed,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Location Selector
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Delivery to',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: textMuted),
                        ],
                      ),
                      Text(
                        'Ghatampur, Kanpur',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Profile Avatar Icon
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedTabProvider.notifier).state = 3; // Switch to Profile tab
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.person_outline_rounded, size: 20, color: textDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Bar (Web App Pill style)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: primaryRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Search 'milk', 'bread', 'chips'...",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.mic_none_rounded, size: 18, color: textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Grocery / Food Mode Switcher Toggle (Matches Web App Ambient Glow Pill 1:1)
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(29),
        ),
        child: Row(
          children: [
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
                    color: _isGrocerySelected ? primaryRed : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: _isGrocerySelected
                        ? [
                            BoxShadow(
                              color: primaryRed.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
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
                        color: _isGrocerySelected ? Colors.white : textMuted,
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
                              fontWeight: FontWeight.w900,
                              color: _isGrocerySelected ? Colors.white : textDark,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'FAST DELIVERY',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _isGrocerySelected ? Colors.white.withOpacity(0.85) : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                    color: !_isGrocerySelected ? accentOrange : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: !_isGrocerySelected
                        ? [
                            BoxShadow(
                              color: accentOrange.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        size: 20,
                        color: !_isGrocerySelected ? Colors.white : textMuted,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food & Cafe',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: !_isGrocerySelected ? Colors.white : textDark,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'CAFE & RESTRO',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: !_isGrocerySelected ? Colors.white.withOpacity(0.85) : textMuted,
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

  // 3. Hero Promo Banner
  Widget _buildHeroPromoBanner() {
    final hour = TimeOfDay.now().hour;
    List<Color> gradientColors;
    String greeting;
    String subtitle;

    if (hour >= 5 && hour < 11) {
      greeting = 'Good Morning!';
      subtitle = 'Breakfast essentials delivered fast';
      gradientColors = const [Color(0xFFFEF3C7), Color(0xFFFFF7ED)];
    } else if (hour >= 11 && hour < 15) {
      greeting = 'Lunch Time!';
      subtitle = 'Fresh ingredients for a great meal';
      gradientColors = const [Color(0xFFD1FAE5), Color(0xFFCCFBF1)];
    } else if (hour >= 15 && hour < 19) {
      greeting = 'Good Evening!';
      subtitle = 'Snacks and beverages for you';
      gradientColors = const [Color(0xFFFFF7ED), Color(0xFFFFE4E6)];
    } else {
      greeting = 'Night Cravings?';
      subtitle = 'Late night munchies delivered fast';
      gradientColors = const [Color(0xFFE0E7FF), Color(0xFFF3E8FF)];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: primaryRed.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FAST Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Text(
                      'Shop Now →',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.7),
              ),
              child: const Center(child: Text('🛒', style: TextStyle(fontSize: 48))),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Delivery Stats Bar
  Widget _buildDeliveryStatsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Delivered Today', '100+', Icons.delivery_dining_rounded, primaryRed),
            Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
            _buildStatItem('Fresh Stock', '5 hrs ago', Icons.inventory_2_rounded, const Color(0xFFD97706)),
            Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
            _buildStatItem('Happy Families', '50+', Icons.volunteer_activism_rounded, primaryRed),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: textDark)),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: textMuted)),
      ],
    );
  }

  // 5. Trending Categories (from API)
  Widget _buildTrendingCategoriesSection() {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Categories',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final name = cat.name;
                  final slug = cat.slug;
                  final icon = cat.imageUrl;
                  final tint = _tintForCategory(slug);
                  final count = cat.productCount ?? 0;
                  return GestureDetector(
                    onTap: () {},
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              _getCategoryAssetImage(slug),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => icon != null && icon.isNotEmpty
                                  ? Center(child: Text(icon, style: const TextStyle(fontSize: 28)))
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: textDark),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count items',
                          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w500, color: textMuted),
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
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 8,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed)),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // 6. Curated For You Filter Tabs
  Widget _buildCuratedForYouFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curated For You',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filterTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedFilterIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryRed : bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? primaryRed : const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      _filterTabs[index],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : textMuted,
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

  // 7. Horizontal Product Section
  Widget _buildHorizontalProductSection(String title, String subtitle, List<Product> products) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
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
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryRed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Text(
                  '© 2026 FastKirana. All rights reserved.',
                  style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPaymentIcon('UPI', const Color(0xFFD97706)),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('Card', const Color(0xFF22C55E)),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('COD', primaryRed),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('Wallet', const Color(0xFF3080FF)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(onPressed: () {}, child: Text('Privacy Policy', style: GoogleFonts.inter(fontSize: 11, color: textMuted))),
                    TextButton(onPressed: () {}, child: Text('Terms', style: GoogleFonts.inter(fontSize: 11, color: textMuted))),
                    TextButton(onPressed: () {}, child: Text('Refund', style: GoogleFonts.inter(fontSize: 11, color: textMuted))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '+91 70544 70303 | help@fastkirana.com',
                  style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                ),
                Text(
                  '6 AM – 12 AM | NH34, Ghatampur, Kanpur Nagar',
                  style: GoogleFonts.inter(fontSize: 10, color: textMuted.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentIcon(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ==========================================
  // FOOD & CAFE STOREFRONT (1:1 Web App Parity)
  // ==========================================

  static const List<Map<String, String>> _cuisineCategories = [
    {'id': 'all', 'label': 'All', 'emoji': '🍽️'},
    {'id': 'specials', 'label': 'Specials', 'emoji': '🔥'},
    {'id': 'rolls', 'label': 'Rolls', 'emoji': '🌯'},
    {'id': 'biryani', 'label': 'Biryani', 'emoji': '🍚'},
    {'id': 'cakes', 'label': 'Cakes', 'emoji': '🎂'},
    {'id': 'naan', 'label': 'Naan', 'emoji': '🫓'},
    {'id': 'burgers', 'label': 'Burgers', 'emoji': '🍔'},
    {'id': 'chinese', 'label': 'Chinese', 'emoji': '🥡'},
    {'id': 'pizza', 'label': 'Pizza', 'emoji': '🍕'},
    {'id': 'south-indian', 'label': 'South Indian', 'emoji': '🍛'},
    {'id': 'beverages', 'label': 'Beverages', 'emoji': '☕'},
    {'id': 'desserts', 'label': 'Desserts', 'emoji': '🍨'},
    {'id': 'fast-food', 'label': 'Fast Food', 'emoji': '🍟'},
    {'id': 'indian', 'label': 'Indian', 'emoji': '🥘'},
  ];

  // 1. Food Banner
  Widget _buildFoodBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFE11D48), Color(0xFFD97706)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Center(
                child: Text('🍔', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hot Cafe & Restaurant Meals',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '5% OFF',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF18181B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order fresh food super fast · Code: FIRST5',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Food Cuisine Categories Carousel
  Widget _buildFoodCuisineCategories() {
    final selectedCuisine = ref.watch(selectedCuisineProvider);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _cuisineCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = _cuisineCategories[index];
          final isSelected = selectedCuisine == cat['id'];

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(selectedCuisineProvider.notifier).state = cat['id']!;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEA580C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE5E7EB),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat['emoji']!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    cat['label']!,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. Food Filter Chips (Pure Veg, Offers, 4.0+ Rating)
  Widget _buildFoodFilterChips() {
    final pureVeg = ref.watch(pureVegFilterProvider);
    final offers = ref.watch(offersFilterProvider);
    final rating = ref.watch(ratingFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Pure Veg Chip
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(pureVegFilterProvider.notifier).state = !pureVeg;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pureVeg ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: pureVeg ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    'Pure Veg',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: pureVeg ? FontWeight.w800 : FontWeight.w600,
                      color: pureVeg ? const Color(0xFF15803D) : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Offers Chip
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(offersFilterProvider.notifier).state = !offers;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: offers ? const Color(0xFFFFF7ED) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: offers ? const Color(0xFFFFEDD5) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    'Offers',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: offers ? FontWeight.w800 : FontWeight.w600,
                      color: offers ? const Color(0xFFEA580C) : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Rating 4.0+ Chip
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(ratingFilterProvider.notifier).state = !rating;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: rating ? const Color(0xFFFEF3C7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: rating ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    'Top Rated',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: rating ? FontWeight.w800 : FontWeight.w600,
                      color: rating ? const Color(0xFFB45309) : const Color(0xFF4B5563),
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

  // 4. Food Restaurant Listing
  List<Widget> _buildFoodRestaurantListing() {
    final restaurants = ref.watch(filteredRestaurantsProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);
    final pureVeg = ref.watch(pureVegFilterProvider);
    final offers = ref.watch(offersFilterProvider);
    final rating = ref.watch(ratingFilterProvider);

    final isFiltered = selectedCuisine != 'all' || pureVeg || offers || rating;

    return [
      // Count Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${restaurants.length} restaurant${restaurants.length != 1 ? 's' : ''} near you',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
              ),
              if (isFiltered)
                GestureDetector(
                  onTap: () {
                    ref.read(selectedCuisineProvider.notifier).state = 'all';
                    ref.read(pureVegFilterProvider.notifier).state = false;
                    ref.read(offersFilterProvider.notifier).state = false;
                    ref.read(ratingFilterProvider.notifier).state = false;
                  },
                  child: Text(
                    'Clear all',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // Restaurant Cards List
      if (restaurants.isEmpty)
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  'No restaurants found',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your selected filters',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final restaurant = restaurants[index];
                return RestaurantCard(restaurant: restaurant);
              },
              childCount: restaurants.length,
            ),
          ),
        ),
    ];
  }

}

