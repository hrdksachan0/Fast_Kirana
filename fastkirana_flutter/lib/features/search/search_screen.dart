import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../products/product_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../../widgets/voice_search_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _query = widget.initialQuery!;
    }
  }

  final List<String> _recentSearches = [
    'Milk',
    'Amul Butter',
    'Maggi',
    'Fortune Oil',
    'Lays',
  ];

  final List<Map<String, String>> _trendingCategories = [
    {'label': 'Doodh & Dairy', 'icon': '🥛', 'query': 'Milk'},
    {'label': 'Atta & Rice', 'icon': '🌾', 'query': 'Atta'},
    {'label': 'Mustard Oil', 'icon': '🍾', 'query': 'Oil'},
    {'label': '2-Min Maggi', 'icon': '🍜', 'query': 'Maggi'},
    {'label': 'Cold Drinks', 'icon': '🥤', 'query': 'Cola'},
    {'label': 'Chips & Namkeen', 'icon': '🥔', 'query': 'Lays'},
    {'label': 'Ice Cream', 'icon': '🍦', 'query': 'Ice Cream'},
    {'label': 'Veg Burger', 'icon': '🍔', 'query': 'Burger'},
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

  void _openVoiceSearch() {
    VoiceSearchSheet.show(context, onResult: (query) {
      _onSearchTermSelected(query);
    });
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
                      onPressed: _openVoiceSearch,
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: Stack(
          children: [
            _query.isEmpty ? _buildTrendingAndRecent() : _buildSearchResults(),

            // Floating Cart Bar (Exact Homepage Design)
            const FloatingCartBar(bottomOffset: 16),
          ],
        ),
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

        // 2. Popular Categories Rail
        Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              'Popular Categories',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _trendingCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = _trendingCategories[idx];
              return GestureDetector(
                onTap: () => _onSearchTermSelected(cat['query']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        cat['label']!,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // 3. Trending Searches
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
                    itemBuilder: (context, index) => const ProductCardSkeleton(),
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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = (constraints.maxWidth / 155).floor().clamp(2, 6);
                              final itemAspect = constraints.maxWidth < 360 ? 0.65 : (columns > 2 ? 0.72 : 0.68);

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: itemAspect,
                                  crossAxisSpacing: 10,
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
                                        FadeSlideRoute(
                                          page: ProductDetailScreen(product: product),
                                        ),
                                      );
                                    },
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 155).floor().clamp(2, 6);
                        final itemAspect = constraints.maxWidth < 360 ? 0.65 : (columns > 2 ? 0.72 : 0.68);

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            childAspectRatio: itemAspect,
                            crossAxisSpacing: 10,
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
                                  FadeSlideRoute(
                                    page: ProductDetailScreen(product: product),
                                  ),
                                );
                              },
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