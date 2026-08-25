import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:action_slider/action_slider.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../products/product_detail_screen.dart';
import '../cart/cart_screen.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final Category category;
  const CategoryProductsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  int _selectedSubcatIndex = 0;
  String _selectedSort = 'Popularity';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color primaryRed = Color(0xFFE20A22);

  // Subcategories mapping matching the Next.js Web App
  final Map<String, List<Map<String, String>>> _subcatMap = {
    'snacks-munchies': [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Chips & Crisps', 'emoji': '🥔'},
      {'name': 'Namkeen & Bhujia', 'emoji': '🥨'},
      {'name': 'Biscuits & Cookies', 'emoji': '🍪'},
      {'name': 'Chocolates', 'emoji': '🍫'},
    ],
    'instant-foods': [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Noodles & Pasta', 'emoji': '🍜'},
      {'name': 'Instant Soups', 'emoji': '🥣'},
      {'name': 'Ready to Eat', 'emoji': '🍲'},
    ],
    'kitchen-needs': [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Atta & Flours', 'emoji': '🌾'},
      {'name': 'Oils & Ghee', 'emoji': '🧈'},
      {'name': 'Spices & Salt', 'emoji': '🧂'},
      {'name': 'Rice & Dals', 'emoji': '🍚'},
    ],
    'chocolates': [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Silk & Bars', 'emoji': '🍫'},
      {'name': 'Toffees & Candies', 'emoji': '🍬'},
      {'name': 'Gift Boxes', 'emoji': '🎁'},
    ],
    'ice-cream': [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Tubs & Packs', 'emoji': '🍨'},
      {'name': 'Cones & Sticks', 'emoji': '🍦'},
      {'name': 'Kulfi', 'emoji': '🍧'},
    ],
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.category.slug));
    final cart = ref.watch(cartProvider).value;
    final cartCount = cart?.totalItems ?? 0;
    final cartSubtotal = cart?.subtotal ?? 0.0;

    final subcats = _subcatMap[widget.category.slug] ?? [
      {'name': 'All Items', 'emoji': '✨'},
      {'name': 'Popular Deals', 'emoji': '🔥'},
      {'name': 'New Arrivals', 'emoji': '⭐'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF059669)),
                const SizedBox(width: 2),
                Text(
                  '10-15 MINS DELIVERY',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Color(0xFF111827)),
                if (cartCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Left Vertical Subcategory Rail (Blinkit 2-Pane Navigation)
              Container(
                width: 82,
                color: const Color(0xFFF9FAFB),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: subcats.length,
                  itemBuilder: (context, idx) {
                    final item = subcats[idx];
                    final isSelected = _selectedSubcatIndex == idx;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedSubcatIndex = idx);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFFFED7AA), width: 1.5)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF7ED)
                                    : const Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item['emoji']!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF4B5563),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2. Right Products Grid
              Expanded(
                child: Column(
                  children: [
                    // Search & Filter Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                      ),
                      child: Column(
                        children: [
                          // Search Input inside category
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: 'Search in ${subcats[_selectedSubcatIndex]['name']}...',
                                hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sort Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterPill('Popularity', _selectedSort == 'Popularity'),
                                const SizedBox(width: 6),
                                _buildFilterPill('Under ₹199', _selectedSort == 'Under ₹199'),
                                const SizedBox(width: 6),
                                _buildFilterPill('Low to High', _selectedSort == 'Low to High'),
                                const SizedBox(width: 6),
                                _buildFilterPill('High to Low', _selectedSort == 'High to Low'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Products Grid
                    Expanded(
                      child: productsAsync.when(
                        data: (products) {
                          var list = List<Product>.from(products);

                          // Subcategory filter
                          if (_selectedSubcatIndex > 0) {
                            final currentSubcatName = subcats[_selectedSubcatIndex]['name']!.toLowerCase();
                            list = list.where((p) {
                              final name = p.name.toLowerCase();
                              final tagMatch = p.tags.any((t) => currentSubcatName.contains(t.toLowerCase()));
                              return name.contains(currentSubcatName) || tagMatch;
                            }).toList();
                            if (list.isEmpty) list = List<Product>.from(products); // fallback
                          }

                          // Search filter
                          if (_searchQuery.isNotEmpty) {
                            list = list.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                          }

                          // Sort
                          if (_selectedSort == 'Under ₹199') {
                            list = list.where((p) => p.price <= 199).toList();
                          } else if (_selectedSort == 'Low to High') {
                            list.sort((a, b) => a.price.compareTo(b.price));
                          } else if (_selectedSort == 'High to Low') {
                            list.sort((a, b) => b.price.compareTo(a.price));
                          }

                          if (list.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🍿', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No products found',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(8, 10, 8, cartCount > 0 ? 80 : 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.54,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final product = list[index];
                              return ProductCard(
                                product: product,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.54,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 6,
                          itemBuilder: (_, __) => const ProductCardSkeleton(),
                        ),
                        error: (e, _) => Center(
                          child: Text('Error loading products: $e'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Floating Bottom Cart Bar
          if (cartCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryRed, Color(0xFFB30013)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$cartCount items · ₹${cartSubtotal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Delivery in 10-15 mins',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            'View Cart',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String title, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSort = title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}