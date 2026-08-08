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
              SliverToBoxAdapter(child: _buildHeroPromoBanner()),
              SliverToBoxAdapter(child: _buildTrendingCategoriesSection()),
              SliverToBoxAdapter(child: _buildHorizontalProductSection('Instant Foods', 'Quick meals for busy days', _instantFoods)),
              SliverToBoxAdapter(child: _buildHorizontalProductSection('Kitchen Needs', 'Staples for your pantry', _kitchenNeeds)),
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
}