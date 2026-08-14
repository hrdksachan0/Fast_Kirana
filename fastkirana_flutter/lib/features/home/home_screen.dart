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

  static const Color primaryGreen = Color(0xFF047857);
  static const Color primaryGreenDark = Color(0xFF065F46);
  static const Color primaryGreenLight = Color(0xFFD1FAE5);
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color cardBg = Color(0xFFF0FDF4);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  // 12 Trending Categories matching website
  final List<Map<String, dynamic>> _trendingCategories = const [
    {'name': 'Fruits & Vegetables', 'icon': '🥬', 'items': 32, 'color': Color(0xFFDCFCE7)},
    {'name': 'Instant Foods', 'icon': '🍜', 'items': 14, 'color': Color(0xFFFFF7ED)},
    {'name': 'Beverages', 'icon': '🥤', 'items': 14, 'color': Color(0xFFE0F2FE)},
    {'name': 'Ice Cream', 'icon': '🍦', 'items': 37, 'color': Color(0xFFFEF3C7)},
    {'name': 'Snacks & Munchies', 'icon': '🍿', 'items': 44, 'color': Color(0xFFFFF0F0)},
    {'name': 'Bakery', 'icon': '🍞', 'items': 4, 'color': Color(0xFFFFF7ED)},
    {'name': 'Dry Fruits', 'icon': '🥜', 'items': 0, 'color': Color(0xFFFEF3C7)},
    {'name': 'Grocery Essential', 'icon': '🫒', 'items': 21, 'color': Color(0xFFF0FDF4)},
    {'name': 'Chocolates', 'icon': '🍫', 'items': 18, 'color': Color(0xFFFFF0F0)},
    {'name': 'Personal Care', 'icon': '🧴', 'items': 14, 'color': Color(0xFFE0F2FE)},
    {'name': 'Home & Cleaning', 'icon': '🧹', 'items': 16, 'color': Color(0xFFF0FDF4)},
    {'name': 'Kitchen Needs', 'icon': '🧂', 'items': 17, 'color': Color(0xFFFFF7ED)},
  ];

  // Curated filter tabs
  final List<String> _filterTabs = ['All', 'Flash Deals', 'Best Sellers', 'Trending', 'Late Night'];
  int _selectedFilterIndex = 0;

  // 5 Product Sections with products matching website
  late final List<Product> _instantFoods = [
    Product(id: 'inst_1', name: 'Maggi 2-Minute Noodles', slug: 'maggi-noodles', categoryId: 'instant', mrp: 14.0, price: 12.0, discount: 14.0, unit: '70g', stock: 50, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 5, costPrice: 9.0, isFlashDeal: true, isTopPick: true, isBestSeller: true, sortOrder: 1, createdAt: DateTime.now()),
    Product(id: 'inst_2', name: 'Pasta - Fusilli', slug: 'pasta-fusilli', categoryId: 'instant', mrp: 85.0, price: 69.0, discount: 18.0, unit: '400g', stock: 25, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 5, costPrice: 55.0, isFlashDeal: false, isTopPick: false, isBestSeller: true, sortOrder: 2, createdAt: DateTime.now()),
    Product(id: 'inst_3', name: 'Quaker Oats', slug: 'quaker-oats', categoryId: 'instant', mrp: 180.0, price: 149.0, discount: 17.0, unit: '1kg', stock: 3, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 3, costPrice: 120.0, isFlashDeal: false, isTopPick: true, isBestSeller: false, sortOrder: 3, createdAt: DateTime.now()),
    Product(id: 'inst_4', name: 'Soya Chunks', slug: 'soya-chunks', categoryId: 'instant', mrp: 95.0, price: 79.0, discount: 16.0, unit: '200g', stock: 20, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 5, costPrice: 60.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 4, createdAt: DateTime.now()),
    Product(id: 'inst_5', name: 'Poha - Thick', slug: 'poha-thick', categoryId: 'instant', mrp: 60.0, price: 49.0, discount: 18.0, unit: '500g', stock: 30, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 5, costPrice: 40.0, isFlashDeal: true, isTopPick: false, isBestSeller: false, sortOrder: 5, createdAt: DateTime.now()),
    Product(id: 'inst_6', name: 'Dalia / Broken Wheat', slug: 'dalia', categoryId: 'instant', mrp: 70.0, price: 59.0, discount: 15.0, unit: '500g', stock: 15, isAvailable: true, imageUrl: '', tags: ['instant'], minStock: 3, costPrice: 48.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 6, createdAt: DateTime.now()),
  ];

  late final List<Product> _kitchenNeeds = [
    Product(id: 'kit_1', name: 'Desi Ghee', slug: 'desi-ghee', categoryId: 'kitchen', mrp: 650.0, price: 599.0, discount: 8.0, unit: '1L', stock: 10, isAvailable: true, imageUrl: '', tags: ['kitchen'], minStock: 3, costPrice: 500.0, isFlashDeal: false, isTopPick: true, isBestSeller: true, sortOrder: 1, createdAt: DateTime.now()),
    Product(id: 'kit_2', name: 'Everest Hing', slug: 'everest-hing', categoryId: 'kitchen', mrp: 60.0, price: 52.0, discount: 13.0, unit: '25g', stock: 25, isAvailable: true, imageUrl: '', tags: ['kitchen'], minStock: 5, costPrice: 40.0, isFlashDeal: false, isTopPick: false, isBestSeller: true, sortOrder: 2, createdAt: DateTime.now()),
    Product(id: 'kit_3', name: 'Everest Black Pepper', slug: 'everest-pepper', categoryId: 'kitchen', mrp: 110.0, price: 89.0, discount: 19.0, unit: '50g', stock: 18, isAvailable: true, imageUrl: '', tags: ['kitchen'], minStock: 5, costPrice: 70.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 3, createdAt: DateTime.now()),
    Product(id: 'kit_4', name: 'Kasuri Methi', slug: 'kasuri-methi', categoryId: 'kitchen', mrp: 75.0, price: 62.0, discount: 17.0, unit: '40g', stock: 8, isAvailable: true, imageUrl: '', tags: ['kitchen'], minStock: 3, costPrice: 50.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 4, createdAt: DateTime.now()),
  ];

  late final List<Product> _fruitsVegetables = [
    Product(id: 'fv_1', name: 'Fresh Parwal', slug: 'parwal', categoryId: 'fruits-veg', mrp: 60.0, price: 45.0, discount: 25.0, unit: '500g', stock: 2, isAvailable: true, imageUrl: '', tags: ['fruits-veg'], minStock: 5, costPrice: 35.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 1, createdAt: DateTime.now()),
    Product(id: 'fv_2', name: 'Lemon', slug: 'lemon', categoryId: 'fruits-veg', mrp: 40.0, price: 30.0, discount: 25.0, unit: '250g', stock: 40, isAvailable: true, imageUrl: '', tags: ['fruits-veg'], minStock: 10, costPrice: 22.0, isFlashDeal: true, isTopPick: true, isBestSeller: false, sortOrder: 2, createdAt: DateTime.now()),
    Product(id: 'fv_3', name: 'Fresh Coriander', slug: 'coriander', categoryId: 'fruits-veg', mrp: 20.0, price: 15.0, discount: 25.0, unit: '100g', stock: 30, isAvailable: true, imageUrl: '', tags: ['fruits-veg'], minStock: 10, costPrice: 10.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 3, createdAt: DateTime.now()),
    Product(id: 'fv_4', name: 'Brinjal', slug: 'brinjal', categoryId: 'fruits-veg', mrp: 50.0, price: 38.0, discount: 24.0, unit: '500g', stock: 15, isAvailable: true, imageUrl: '', tags: ['fruits-veg'], minStock: 5, costPrice: 30.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 4, createdAt: DateTime.now()),
    Product(id: 'fv_5', name: 'Carrot', slug: 'carrot', categoryId: 'fruits-veg', mrp: 55.0, price: 42.0, discount: 23.0, unit: '500g', stock: 20, isAvailable: true, imageUrl: '', tags: ['fruits-veg'], minStock: 5, costPrice: 32.0, isFlashDeal: false, isTopPick: true, isBestSeller: false, sortOrder: 5, createdAt: DateTime.now()),
  ];

  late final List<Product> _iceCream = [
    Product(id: 'ic_1', name: 'American Cup', slug: 'american-cup', categoryId: 'ice-cream', mrp: 40.0, price: 35.0, discount: 12.0, unit: '1 pcs', stock: 20, isAvailable: true, imageUrl: '', tags: ['ice-cream'], minStock: 5, costPrice: 28.0, isFlashDeal: false, isTopPick: true, isBestSeller: true, sortOrder: 1, createdAt: DateTime.now()),
    Product(id: 'ic_2', name: 'Choco Surprise', slug: 'choco-surprise', categoryId: 'ice-cream', mrp: 45.0, price: 38.0, discount: 15.0, unit: '1 pcs', stock: 15, isAvailable: true, imageUrl: '', tags: ['ice-cream'], minStock: 5, costPrice: 30.0, isFlashDeal: true, isTopPick: false, isBestSeller: true, sortOrder: 2, createdAt: DateTime.now()),
    Product(id: 'ic_3', name: 'Vanilla Tub', slug: 'vanilla-tub', categoryId: 'ice-cream', mrp: 120.0, price: 99.0, discount: 17.0, unit: '500ml', stock: 8, isAvailable: true, imageUrl: '', tags: ['ice-cream'], minStock: 3, costPrice: 80.0, isFlashDeal: false, isTopPick: false, isBestSeller: true, sortOrder: 3, createdAt: DateTime.now()),
    Product(id: 'ic_4', name: 'Strawberry Cone', slug: 'strawberry-cone', categoryId: 'ice-cream', mrp: 35.0, price: 29.0, discount: 17.0, unit: '1 pcs', stock: 25, isAvailable: true, imageUrl: '', tags: ['ice-cream'], minStock: 5, costPrice: 22.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 4, createdAt: DateTime.now()),
  ];

  late final List<Product> _snacksMunchies = [
    Product(id: 'sn_1', name: 'Bhelpuri', slug: 'bhelpuri', categoryId: 'snacks', mrp: 50.0, price: 39.0, discount: 22.0, unit: '200g', stock: 5, isAvailable: true, imageUrl: '', tags: ['snacks'], minStock: 5, costPrice: 30.0, isFlashDeal: false, isTopPick: false, isBestSeller: true, sortOrder: 1, createdAt: DateTime.now()),
    Product(id: 'sn_2', name: 'Hide & Seek', slug: 'hide-seek', categoryId: 'snacks', mrp: 30.0, price: 25.0, discount: 16.0, unit: '75g', stock: 40, isAvailable: true, imageUrl: '', tags: ['snacks'], minStock: 10, costPrice: 20.0, isFlashDeal: true, isTopPick: true, isBestSeller: true, sortOrder: 2, createdAt: DateTime.now()),
    Product(id: 'sn_3', name: 'Choco Pie', slug: 'choco-pie', categoryId: 'snacks', mrp: 90.0, price: 75.0, discount: 16.0, unit: '200g', stock: 4, isAvailable: true, imageUrl: '', tags: ['snacks'], minStock: 5, costPrice: 60.0, isFlashDeal: false, isTopPick: false, isBestSeller: true, sortOrder: 3, createdAt: DateTime.now()),
    Product(id: 'sn_4', name: 'Diet Mixture', slug: 'diet-mixture', categoryId: 'snacks', mrp: 55.0, price: 45.0, discount: 18.0, unit: '150g', stock: 3, isAvailable: true, imageUrl: '', tags: ['snacks'], minStock: 5, costPrice: 35.0, isFlashDeal: false, isTopPick: false, isBestSeller: false, sortOrder: 4, createdAt: DateTime.now()),
  ];

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
              color: primaryGreen,
              onRefresh: () async {
                ref.invalidate(cartProvider);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(cartCount)),
                  SliverToBoxAdapter(child: _buildCategoryToggle()),
                  SliverToBoxAdapter(child: _buildHeroPromoBanner()),
                  SliverToBoxAdapter(child: _buildDeliveryStatsBar()),
                  SliverToBoxAdapter(child: _buildTrendingCategoriesSection()),
                  SliverToBoxAdapter(child: _buildCuratedForYouFilter()),
                  SliverToBoxAdapter(child: _buildHorizontalProductSection('Instant Foods', 'Quick meals for busy days', _instantFoods)),
                  SliverToBoxAdapter(child: _buildHorizontalProductSection('Kitchen Needs', 'Staples for your pantry', _kitchenNeeds)),
                  SliverToBoxAdapter(child: _buildHorizontalProductSection('Fruits & Vegetables', 'Farm fresh goodness', _fruitsVegetables)),
                  SliverToBoxAdapter(child: _buildHorizontalProductSection('Ice Cream', 'Cool treats for everyone', _iceCream)),
                  SliverToBoxAdapter(child: _buildHorizontalProductSection('Snacks & Munchies', 'Crunchy & delicious', _snacksMunchies)),
                  SliverToBoxAdapter(child: _buildFooter()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingCartBar(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Header: Logo + Location + Notifications + Cart
  Widget _buildHeader(int cartCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
      ),
      child: Row(
        children: [
          // Brand Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'FastKirana',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Location Selector
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: primaryGreen),
                    const SizedBox(width: 4),
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

          // Notifications Icon
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: primaryGreen, size: 22),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),

          // Cart Icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                },
                icon: const Icon(Icons.shopping_cart_outlined, color: primaryGreen, size: 22),
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
                      color: primaryGreen,
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

  // 2. Grocery / Food Toggle
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: primaryGreenLight,
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
                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Grocery',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isGrocerySelected ? primaryGreen : textMuted,
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
                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Food',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isGrocerySelected ? primaryGreen : textMuted,
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

  // 3. Hero Promo Banner
  Widget _buildHeroPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: primaryGreen.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
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
                      color: primaryGreen,
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
                    'Fast Delivery in\nGhatampur',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryGreenDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Milk, Fruits, Vegetables, Snacks & more',
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
                      backgroundColor: primaryGreen,
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
            _buildStatItem('Delivered Today', '100+', Icons.delivery_dining_rounded, primaryGreen),
            Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
            _buildStatItem('Fresh Stock', '5 hrs ago', Icons.inventory_2_rounded, const Color(0xFF059669)),
            Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
            _buildStatItem('Happy Families', '50+', Icons.volunteer_activism_rounded, const Color(0xFF047857)),
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

  // 5. Trending Categories (12-grid matching website)
  Widget _buildTrendingCategoriesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Categories',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See All',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _trendingCategories.length,
            itemBuilder: (context, index) {
              final cat = _trendingCategories[index];
              return GestureDetector(
                onTap: () {},
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cat['color'],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(cat['icon'], style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat['name'],
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: textDark),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${cat['items']} items',
                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w500, color: textMuted),
                    ),
                  ],
                ),
              );
            },
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
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
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
                      color: isSelected ? primaryGreen : bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? primaryGreen : const Color(0xFFE5E7EB)),
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
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
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
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryGreen),
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
                    _buildPaymentIcon('UPI', const Color(0xFF10B981)),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('Card', const Color(0xFF047857)),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('COD', const Color(0xFF059669)),
                    const SizedBox(width: 16),
                    _buildPaymentIcon('Wallet', const Color(0xFF10B981)),
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

  // Floating Cart Preview Bar
  Widget _buildFloatingCartBar(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    return cartAsync.when(
      data: (cart) {
        if (cart.items.isEmpty) return const SizedBox.shrink();
        final total = cart.subtotal;
        final itemCount = cart.totalItems;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.borderLight),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const CartScreen(),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$itemCount items',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primaryGreen),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹${total.toInt()}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppDesignSystem.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View Cart', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
