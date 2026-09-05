import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../products/product_detail_screen.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final bool _isSearchActive = false;
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = 12;

  static const Color primaryRed = AppDesignSystem.primary;

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
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (mounted) {
        setState(() {
          _visibleCount += 12;
        });
      }
    }
  }

  void _resetPagination() {
    setState(() {
      _visibleCount = 12;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.gray900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.name,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.gray900,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 12, color: AppDesignSystem.emerald600),
                const SizedBox(width: 2),
                Text(
                  'FAST DELIVERY',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.emerald600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 1. Left Vertical Subcategory Rail (Blinkit 2-Pane Navigation)
              Container(
                width: Responsive.isSmallMobile(context) ? 64 : 82,
                color: AppDesignSystem.gray50,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: subcats.length,
                  itemBuilder: (context, idx) {
                    final item = subcats[idx];
                    final isSelected = _selectedSubcatIndex == idx;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectedSubcatIndex = idx;
                        _resetPagination();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: AppDesignSystem.orange300, width: 1.5)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
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
                                    ? AppDesignSystem.orange50
                                    : AppDesignSystem.surfaceMuted,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item['emoji']!,
                                  style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? AppDesignSystem.orange600 : AppDesignSystem.gray600,
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
                        border: Border(bottom: BorderSide(color: AppDesignSystem.surfaceMuted)),
                      ),
                      child: Column(
                        children: [
                          // Search Input inside category
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                _searchQuery = val.trim().toLowerCase();
                                _resetPagination();
                              },
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.gray900),
                              decoration: InputDecoration(
                                hintText: 'Search in ${widget.category.name}...',
                                hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.textTertiary),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppDesignSystem.textTertiary),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          _searchQuery = '';
                                          _resetPagination();
                                        },
                                        child: const Icon(Icons.clear_rounded, size: 16, color: AppDesignSystem.textTertiary),
                                      )
                                    : null,
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

                          // Search filter (searches across the whole category)
                          if (_searchQuery.isNotEmpty) {
                            list = list.where((p) {
                              final nameMatch = p.name.toLowerCase().contains(_searchQuery);
                              final tagMatch = p.tags.any((t) => t.toLowerCase().contains(_searchQuery));
                              final descMatch = (p.description ?? '').toLowerCase().contains(_searchQuery);
                              final unitMatch = p.unit.toLowerCase().contains(_searchQuery);
                              return nameMatch || tagMatch || descMatch || unitMatch;
                            }).toList();
                          } else if (_selectedSubcatIndex > 0) {
                            // Subcategory filter only when not searching
                            final currentSubcatName = subcats[_selectedSubcatIndex]['name']!.toLowerCase();
                            list = list.where((p) {
                              final name = p.name.toLowerCase();
                              final tagMatch = p.tags.any((t) => currentSubcatName.contains(t.toLowerCase()));
                              return name.contains(currentSubcatName) || tagMatch;
                            }).toList();
                            if (list.isEmpty) list = List<Product>.from(products); // fallback
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
                                  Text('🍿', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 40))),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No products found',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13),
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = (constraints.maxWidth / 140).floor().clamp(2, 6);
                              final itemAspect = Responsive.productCardAspectRatio(context, isCompact: true);
                              final visibleProducts = list.take(_visibleCount).toList();
                              final hasMore = _visibleCount < list.length;

                              return CustomScrollView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                                    sliver: SliverGrid(
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        childAspectRatio: itemAspect,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 10,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final product = visibleProducts[index];
                                          return ProductCard(
                                            key: ValueKey(product.id),
                                            product: product,
                                            isCompact: true,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                FadeSlideRoute(
                                                  page: ProductDetailScreen(product: product),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        childCount: visibleProducts.length,
                                      ),
                                    ),
                                  ),
                                  if (hasMore)
                                    const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: primaryRed,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: cartCount > 0 ? 80 : 20),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        loading: () => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5),
                            childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: true),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 6,
                          itemBuilder: (_, __) => const ProductCardSkeleton(isCompact: true),
                        ),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 36, color: AppDesignSystem.slate400),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to reload products',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    ref.invalidate(productsProvider(widget.category.slug));
                                    ref.invalidate(productsProvider(widget.category.id));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryRed,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text('Retry', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Floating Bottom Cart Bar (Exact Homepage Design)
          FloatingCartBar(bottomOffset: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    ),
  );
  }

  Widget _buildFilterPill(String title, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _selectedSort = title;
        _resetPagination();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : AppDesignSystem.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: AppDesignSystem.border),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 10.5),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppDesignSystem.gray700,
          ),
        ),
      ),
    );
  }
}