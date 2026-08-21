import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../products/product_detail_screen.dart';
import '../cart/cart_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  final List<String> _recentSearches = [
    'Milk',
    'Amul Butter',
    'Maggi',
    'Fortune Oil',
    'Lays',
  ];

  final List<String> _trending = [
    'Amul Toned Milk',
    'Dairy Milk Silk',
    'Fortune Mustard Oil',
    'Aashirvaad Atta',
    'Lays India Magic Masala',
    'Coca Cola 750ml',
    'Veg Cheese Burger',
    'Paneer Tikka Roll',
    'Farm Fresh Eggs',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchTermSelected(String term) {
    HapticFeedback.selectionClick();
    _controller.text = term;
    setState(() {
      _query = term;
      if (!_recentSearches.contains(term)) {
        _recentSearches.insert(0, term);
        if (_recentSearches.length > 6) {
          _recentSearches.removeLast();
        }
      }
    });
  }

  void _startVoiceSearch(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.mic_rounded, size: 36, color: Color(0xFFEA580C)),
              ),
              const SizedBox(height: 16),
              Text(
                'Listening... Speak Item Name',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Say "Amul Butter", "Maggi", "Burger", or "Fortune Oil" in Hindi / English',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Amul Butter 🧈', 'Maggi 🍜', 'Veg Burger 🍔', 'Fortune Oil 🍾', 'Dairy Milk 🍫']
                    .map((item) => GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            final cleanTerm = item.split(' ')[0] + ' ' + (item.split(' ').length > 1 ? item.split(' ')[1] : '');
                            _onSearchTermSelected(cleanTerm.trim());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              item,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;
    final cartCount = cart?.totalItems ?? 0;
    final cartSubtotal = cart?.subtotal ?? 0.0;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
            border: Border.all(color: AppDesignSystem.border),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (val) => setState(() => _query = val.trim()),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search 400+ groceries & hot meals...',
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.textMuted,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.primary),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppDesignSystem.textSecondary),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.mic_rounded, size: 18, color: Color(0xFFEA580C)),
                      onPressed: () => _startVoiceSearch(context),
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _query.isEmpty ? _buildTrendingAndRecent() : _buildSearchResults(),

          // Floating Cart Bar
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
                    gradient: AppDesignSystem.cartBarGradient,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppDesignSystem.primary.withOpacity(0.35),
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

  Widget _buildTrendingAndRecent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Recent Searches with Clear All
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: AppDesignSystem.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Searches',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _recentSearches.clear());
                },
                child: Text(
                  'Clear All',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((item) {
              return GestureDetector(
                onTap: () => _onSearchTermSelected(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                    border: Border.all(color: AppDesignSystem.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 12, color: AppDesignSystem.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // 2. Trending Searches
        Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              'Trending Searches',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending.map((item) {
            return GestureDetector(
              onTap: () => _onSearchTermSelected(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  border: Border.all(color: AppDesignSystem.border),
                  boxShadow: AppDesignSystem.shadowSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, size: 13, color: Color(0xFFEA580C)),
                    const SizedBox(width: 5),
                    Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final repo = ref.watch(productRepositoryProvider);

    return FutureBuilder<List<Product>>(
      future: repo.getProducts(search: _query, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Loading search results...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return ProductCard(
                        product: Product(
                          id: 'skeleton_$index',
                          name: 'Dummy Product Name Here',
                          slug: 'dummy-slug',
                          categoryId: 'cat',
                          mrp: 150.0,
                          price: 120.0,
                          discount: 20.0,
                          unit: '1 unit',
                          stock: 99,
                          isAvailable: true,
                          tags: const [],
                          minStock: 0,
                          costPrice: 0,
                          isFlashDeal: false,
                          isTopPick: false,
                          isBestSeller: false,
                          sortOrder: 0,
                          createdAt: DateTime.now(),
                        ),
                        onTap: () {},
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'No products found for "$_query"',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check for spelling mistakes or try a different keyword',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppDesignSystem.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        final restaurantProducts = results.where((p) => p.restaurantId != null && p.restaurant != null).toList();
        final groceryProducts = results.where((p) => p.restaurantId == null || p.restaurant == null).toList();

        final Map<String, List<Product>> groupedByRestaurant = {};
        for (var p in restaurantProducts) {
          final restName = p.restaurant?.name ?? 'Other Restaurant';
          if (!groupedByRestaurant.containsKey(restName)) {
            groupedByRestaurant[restName] = [];
          }
          groupedByRestaurant[restName]!.add(p);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '${results.length} results found',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                children: [
                  // 1. Render Restaurant items grouped restaurant-wise
                  if (groupedByRestaurant.isNotEmpty) ...[
                    ...groupedByRestaurant.entries.map((entry) {
                      final restaurantName = entry.key;
                      final products = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant, size: 15, color: Color(0xFFEA580C)),
                                const SizedBox(width: 6),
                                Text(
                                  restaurantName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, idx) {
                              final product = products[idx];
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
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ],

                  // 2. Render Grocery (Darkstore) items
                  if (groceryProducts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF0D9488)),
                          const SizedBox(width: 6),
                          Text(
                            'FastKirana Darkstore (Grocery)',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: groceryProducts.length,
                      itemBuilder: (context, idx) {
                        final product = groceryProducts[idx];
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
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}