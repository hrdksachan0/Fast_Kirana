import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGrocerySelected = true;

  // Primary Theme Colors
  static const Color primaryRed = Color(0xFFB50017);
  static const Color primaryButtonRed = Color(0xFFE20A23);
  static const Color bgLight = Color(0xFFFCF8F8);
  static const Color cardBorder = Color(0xFFF4E7E8);
  static const Color textDark = Color(0xFF1C0D0F);
  static const Color textMuted = Color(0xFF9D4852);
  static const Color greenBadgeBg = Color(0xFFDCFCE7);
  static const Color greenBadgeText = Color(0xFF005319);

  final List<Map<String, String>> _trendingCategories = const [
    {'name': 'Vegetables', 'icon': '🥬'},
    {'name': 'Instant Food', 'icon': '🍜'},
    {'name': 'Beverages', 'icon': '🥤'},
    {'name': 'Bakery', 'icon': '🍞'},
    {'name': 'Kitchen', 'icon': '🧂'},
  ];

  final List<Product> _instantFoods = [
    Product(
      id: 'inst_1',
      name: 'Premium Instant Ramen',
      slug: 'instant-ramen',
      categoryId: 'instant',
      mrp: 110.0,
      price: 85.0,
      discount: 22.0,
      unit: '150g',
      stock: 20,
      isAvailable: true,
      imageUrl: '',
      tags: const ['instant'],
      minStock: 5,
      costPrice: 65.0,
      isFlashDeal: true,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'inst_2',
      name: 'Butter Chicken Meal',
      slug: 'butter-chicken',
      categoryId: 'instant',
      mrp: 249.0,
      price: 199.0,
      discount: 20.0,
      unit: '300g',
      stock: 15,
      isAvailable: true,
      imageUrl: '',
      tags: const ['instant'],
      minStock: 5,
      costPrice: 150.0,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 2,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'inst_3',
      name: 'Creamy Mac & Cheese',
      slug: 'mac-and-cheese',
      categoryId: 'instant',
      mrp: 55.0,
      price: 45.0,
      discount: 18.0,
      unit: '70g',
      stock: 30,
      isAvailable: true,
      imageUrl: '',
      tags: const ['instant'],
      minStock: 5,
      costPrice: 35.0,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: false,
      sortOrder: 3,
      createdAt: DateTime.now(),
    ),
  ];

  final List<Product> _kitchenNeeds = [
    Product(
      id: 'kitch_1',
      name: 'Pure Cow Ghee',
      slug: 'pure-cow-ghee',
      categoryId: 'kitchen',
      mrp: 650.0,
      price: 599.0,
      discount: 8.0,
      unit: '1L',
      stock: 12,
      isAvailable: true,
      imageUrl: '',
      tags: const ['kitchen'],
      minStock: 3,
      costPrice: 500.0,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'kitch_2',
      name: 'Classic Basmati Rice',
      slug: 'basmati-rice',
      categoryId: 'kitchen',
      mrp: 520.0,
      price: 445.0,
      discount: 14.0,
      unit: '5kg',
      stock: 25,
      isAvailable: true,
      imageUrl: '',
      tags: const ['kitchen'],
      minStock: 5,
      costPrice: 380.0,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 2,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartCount = cartState.value?.items.fold<int>(0, (s, item) => s + item.quantity) ?? 0;

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: () async {
            ref.invalidate(cartProvider);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(cartCount)),
              SliverToBoxAdapter(child: _buildCategoryToggle()),
              if (_isGrocerySelected) ...[
                SliverToBoxAdapter(child: _buildHeroPromoBanner()),
                SliverToBoxAdapter(child: _buildTrendingCategoriesSection()),
                SliverToBoxAdapter(child: _buildHorizontalProductSection('Instant Foods', 'Quick meals for busy days', _instantFoods)),
                SliverToBoxAdapter(child: _buildHorizontalProductSection('Kitchen Needs', 'Staples for your pantry', _kitchenNeeds)),
              ] else ...[
                SliverToBoxAdapter(child: _buildFoodSearchBar()),
                SliverToBoxAdapter(child: _buildEditorialBanners()),
                SliverToBoxAdapter(child: _buildGourmetCurationSection()),
                SliverToBoxAdapter(child: _buildFeaturedDiningSection()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Sticky Glass Header Section
  Widget _buildHeader(int cartCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFAFCF8F8),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: Row(
        children: [
          // Brand Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'FastKirana',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Location Selector Dropdown
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: primaryRed),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        'Ghatampur Market',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: textMuted),
                  ],
                ),
              ),
            ),
          ),

          // Actions: Notifications & Cart Icons
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: primaryRed, size: 22),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                },
                icon: const Icon(Icons.shopping_cart_outlined, color: primaryRed, size: 22),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              if (cartCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: primaryRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Category Toggle (Grocery vs Food)
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isGrocerySelected ? bgLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _isGrocerySelected
                        ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Grocery',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isGrocerySelected ? primaryRed : textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGrocerySelected = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: !_isGrocerySelected ? bgLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: !_isGrocerySelected
                        ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Food',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isGrocerySelected ? primaryRed : textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Hero Promo Banner Section
  Widget _buildHeroPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE4E6), Color(0xFFFEE2E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLASH SALE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryRed,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "IT'S SNACK O'CLOCK!",
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tea & snacks are ready for your break.',
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
                      backgroundColor: primaryButtonRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Text(
                      'Order Now',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Hero Floating Food Graphic
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const Center(child: Text('🍟', style: TextStyle(fontSize: 42))),
                ),
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: const Center(child: Text('🥟', style: TextStyle(fontSize: 36))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. Trending Categories Section
  Widget _buildTrendingCategoriesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Categories',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 95,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _trendingCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final cat = _trendingCategories[index];
                return Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(child: Text(cat['icon']!, style: const TextStyle(fontSize: 32))),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name']!,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. Horizontal Product Cards Section
  Widget _buildHorizontalProductSection(String title, String subtitle, List<Product> products) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
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
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final product = products[index];
                return SizedBox(
                  width: 155,
                  child: ProductCard(product: product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Set of favorited restaurant IDs
  final Set<String> _favoritedRestaurants = {};

  // 6. Food Mode Search Bar
  Widget _buildFoodSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: textMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search for restaurants, dishes...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textMuted.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none_rounded, size: 18, color: textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 7. Editorial Banners Section (Michelin Starred & New Arrival)
  Widget _buildEditorialBanners() {
    final banners = [
      {
        'tag': 'MICHELIN STARRED',
        'title': 'The Tasting Menu',
        'subtitle': 'Curated experiences delivered.',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuD_ZtZ5AFxDNkXc6DM3c7LFS7yhT7FbmtJWXbdi6dVpYEOt_X5B4LNzxX_8Kif4vLZtBDcjOZNlaEDOCf0cn9blz8nM-FQDUYCP4OI6c7Ykazrr4CwQq_Ukws8S76EsfhFabGM8FTtKU4hU5TPlNedEC8SC9R_rdxvY7kyoze_UyGBW6O-lzqSgle_mtKmJk2hqOGJo9eCG0vUytuUr0lFLnyyq_kf4TLtF6YoLaPf-nKT4Ev-nf_tLZQ',
      },
      {
        'tag': 'NEW ARRIVAL',
        'title': 'Sushi Masterclass',
        'subtitle': 'Direct from Omotenashi.',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCOysdCGB-yLxHOeKTwh3f65j8ITYAMdj_5FdRFW2NxHMmh_Th249nJ_Fc1GglNE7T8BFwTi5oqxykmE4K9ec3bDHNAB-igNUp5FRq3C5eUKnO5rT9UJUz3oQ8pHjH2vgzUqUyQXklRTQrKnAEZfd57oZu7n4YuPq36DwTixm5KcyK00aeEzmzmu-gL_jtafWKX_2DgUL8ujB5qglxpP5KzzSydbhWhtBeizl7QJIiydTTk5Kunb1_wmQ',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 180,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: banners.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final banner = banners[index];
            return Container(
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFEEEEF0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.network(
                      banner['image']!,
                      width: 300,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black87,
                            Colors.black38,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner['tag']!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFB3AD),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner['title']!,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            banner['subtitle']!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFF3F3F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 8. Gourmet Curation Categories
  Widget _buildGourmetCurationSection() {
    final gourmetCategories = [
      {
        'title': 'Artisan\nBakery',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuB-ZPZyaXx-zRpUvOt0LsP93QoUCDVb6DYNf_HsIbZYWUVr2n9XBnH4eqnpk3Gi9-EZv8mcNGDVnGx8xtQUE78_zqNKA7tte5wU6g3E-AyjzhpwuWdGhCP-s--XbZV7mb7nGeiGaVV1LRl2TetN0nx0-CqoWEoR81dS42bzgBLPghs8cUW3FtPd_g9EAtpCYmV2MQS-HtYIr5LP2p-jM7kfBFJ5At7A7MzJYIMJ2UoRcR2_y90BIX3OFA',
      },
      {
        'title': 'Cheese &\nMeat',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAEGCqhCAjyA74S6TcSynXzFVugjnExan72AJvbwe_fEZX33RVYHM_V1vMq2rf3Xkkauw3yeP511gN_HFrETkrhdQXJKD60Zei6jAQjk-YGIz6YeSeqBhvvspDFhf3dNtuobTqna985-8U7646Xd54a0-RgroXFMHnQtrR5ig1TlKFhN6xvWq4WKbeNIkwBvD4_p5xOOxGkwzMnI3cjCnbMQknu1oCviQdUys_7pZqzgO5oxWupKThGiA',
      },
      {
        'title': 'Café\nElite',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCKw_bVU_RzroNTk3YSj1gW4v7bjNjjg5pL0X--aXYrURT32RffSwr9Zcyh8-9aDYVAggwujWw3KJWqzhDGVtCl9eDC-uWi1n4Uh75foPQK_8B_ma8Q1ZxOQBuPXLAbikOMdlKP5g-ALihnP_3wpiTzszP3sSqy5CXnnE-_3yhPLJQnwFSnkkuSNyNrCKr-xL_dCUFz-fmScj8MOSsIKlFSLtSD_ng4I9AosZbY-ttvDFFsrM9Ic6nWRg',
      },
      {
        'title': 'Healthy\nLuxe',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCZYaeJTUZgVB57e7gwHo6wcvP_5itQ6qguzxgYJKF3Y1nykTJG15yai06ex-_2h9XlN46oSVz1T-JP2TZxOupy_0N1EQgf9kdVaWSv-wKxOlv74MR5v736561tTbb-R9OL74NlHc5-5O0J5GX1N0NwbdrmRabL3rauvFnwqmEaFNiYKHFgkwTgyN302rxIM1vTfYhIRo7BUZc3fmPf_QXla_gSOPkyd8fQtMRdOB2CP1WhtkDW57jFZA',
      },
      {
        'title': 'Dessert\nBar',
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAIJPjF1weNGEGC1X584-pC4ajDd5TsewVUBYHoBgBZePsgBI_MU5ZekYmkKgSWXLFhctV0selP8q3QW3QXQVaoidVp7cYxrg_Ja-uvFzuO8X4k4efcmntNop4P5FOjcOpFENFGNzX4tCsTJ9bgjvvJQzbFivXouHlOskQUb1jLaA3sdoBMi5Xcap4yjujI8YIF6xLXm_ytY8ygEJ9EQSulrA4Phh2id9PjuvgTC-4YuWvwVekv_946qQ',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gourmet Curation',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: gourmetCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, index) {
                final cat = gourmetCategories[index];
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E2E5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            cat['image']!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['title']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                          height: 1.1,
                        ),
                      ),
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

  // 9. Featured Dining Restaurant Section
  Widget _buildFeaturedDiningSection() {
    final restaurants = [
      {
        'id': 'rest_1',
        'name': 'Osteria Bianca',
        'tag': 'Italian',
        'cuisine': 'Truffle Pasta, Handcrafted Burrata • $$$$',
        'rating': '4.9',
        'time': '35-45 min',
        'delivery': 'Free Delivery',
        'isExclusive': false,
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDR5_WtTX3bdSKsWaacqLduhhtES6xWFUVL83WaI1d8N3qcop2vtAJT2mWsCdqEGnLKIlw3ta3K_6UAKaOr4EbVpySJx99NAFdxKSMquzGfq7qC8FhHSyoV91FeyMiBdK5L1P1jNnfPahs8yHMyOg5mc-Bx573e9nWCKVNaoHXEVyI9-hewBt_o491czEXraas1f55zg0DEpMM5D9SvFNc5chMJsAZPGcznJrF2T6z6k0fvIAYKbe-23Q',
      },
      {
        'id': 'rest_2',
        'name': 'Lotus Garden',
        'tag': 'Pan-Asian',
        'cuisine': 'Dim Sum, Signature Peking Duck • $$$',
        'rating': '4.8',
        'time': '40-55 min',
        'delivery': null,
        'isExclusive': true,
        'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuC6lE8TZZYQecQkdlW8HdSnTFvIdI6tarXfD9ocplRuszK7Kua8j1mvDu3dPPU1Qu5i3d498P5If1Q2ZTF_VJARD-A9zQn9tpVWqI6ukQzc5AOLaJv_jnuzdSkBaMPa5yFvXK_gkwnUdyXO99n3jIAHUN2OnsCWdzaaS89Juox_y66BGHEJMWaNSQsh4u_OWRhxjEt5k-k0SQ1RKEYa8KEm_avFJLtMIoTrSdeYWgaU9UNkCPtTxKHX3Q',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Featured Dining',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final rest = restaurants[index];
              final restId = rest['id'] as String;
              final isFav = _favoritedRestaurants.contains(restId);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1C1E).withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Restaurant Cover Image Header
                      Stack(
                        children: [
                          Image.network(
                            rest['image'] as String,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                            ),
                          ),
                          // Rating Badge Top Left
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, size: 16, color: Color(0xFF006E24)),
                                  const SizedBox(width: 4),
                                  Text(
                                    rest['rating'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Exclusive Badge Bottom Left
                          if (rest['isExclusive'] == true)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006E24),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: Text(
                                  'EXCLUSIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          // Favorite Heart Toggle Top Right
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (isFav) {
                                    _favoritedRestaurants.remove(restId);
                                  } else {
                                    _favoritedRestaurants.add(restId);
                                  }
                                });
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  shape: BoxShape.circle,
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  size: 18,
                                  color: isFav ? primaryRed : const Color(0xFF5E3F3C),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Restaurant Info Footer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    rest['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F3F6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    rest['tag'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF5E3F3C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rest['cuisine'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF5E3F3C),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F3F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 16, color: primaryRed),
                                      const SizedBox(width: 4),
                                      Text(
                                        rest['time'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (rest['delivery'] != null) ...[
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_bike, size: 16, color: Color(0xFF5E3F3C)),
                                      const SizedBox(width: 4),
                                      Text(
                                        rest['delivery'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF5E3F3C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}