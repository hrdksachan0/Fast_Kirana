import '../../widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/floating_cart_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../bakery/bakery_store_screen.dart';
import '../../core/widgets/loading_widgets.dart';
import '../../widgets/offline_banner.dart';

class _SubcatItem {
  final String id;
  final String name;
  final String slug;
  final String emoji;
  final String? imageUrl;
  const _SubcatItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.emoji,
    this.imageUrl,
  });
}

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final Category category;
  const CategoryProductsScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  String _selectedSubcatId = 'all';
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = 14;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _scrollController.positions.length != 1) {
      return;
    }
    final position = _scrollController.position;
    if (position.hasContentDimensions &&
        position.pixels >= position.maxScrollExtent - 250) {
      if (mounted) {
        setState(() {
          _visibleCount += 12;
        });
      }
    }
  }

  void _resetPagination() {
    setState(() {
      _visibleCount = 14;
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
    if (widget.category.slug.toLowerCase().contains('bakery') ||
        widget.category.name.toLowerCase().contains('bakery')) {
      return const BakeryStoreScreen();
    }

    final catKey = (widget.category.id.isNotEmpty &&
            (widget.category.id.toUpperCase().startsWith('CAT-') ||
                widget.category.id.toUpperCase().startsWith('SUB-')))
        ? widget.category.id
        : (widget.category.slug.isNotEmpty ? widget.category.slug : widget.category.id);

    final productsAsync = ref.watch(productsProvider(catKey));
    final cachedPreview = ref.read(productRepositoryProvider).peekCachedProducts(
        categoryKey: catKey,
        storeId: ref.watch(currentStoreHubProvider).id);
    final visibleProductsAsync = !productsAsync.hasValue && (cachedPreview?.isNotEmpty ?? false)
        ? AsyncValue<List<Product>>.data(cachedPreview!)
        : productsAsync;

    final catalogProducts = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    final categoriesAsync = ref.watch(categoriesProvider);

    final allCats = categoriesAsync.valueOrNull ?? [];
    final catIdLower = widget.category.id.toLowerCase().trim();
    final catSlugLower = widget.category.slug.toLowerCase().trim();

    final dbSubcats = allCats.where((c) {
      if (c.parentId == null || c.parentId!.isEmpty) return false;
      final pId = c.parentId!.toLowerCase().trim();
      return pId == catIdLower || pId == catSlugLower;
    }).toList();

    final List<_SubcatItem> subcats = [
      const _SubcatItem(id: 'all', name: 'All', slug: 'all', emoji: '🧺'),
      if (dbSubcats.isNotEmpty)
        ...dbSubcats.map((sc) => _SubcatItem(
              id: sc.id,
              name: sc.name.trim(),
              slug: sc.slug.trim(),
              emoji: (sc.imageUrl != null &&
                      !sc.imageUrl!.startsWith('http') &&
                      sc.imageUrl!.length < 5)
                  ? sc.imageUrl!
                  : '🌱',
              imageUrl: (sc.imageUrl != null && sc.imageUrl!.startsWith('http'))
                  ? sc.imageUrl
                  : null,
            )),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      // 1. Reference Style Clean AppBar with Perfect Text Alignment & In-Category Search
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 42,
        titleSpacing: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
              _resetPagination();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSearching
            ? Container(
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                    _resetPagination();
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  cursorColor: AppDesignSystem.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    hintText: 'Search in ${widget.category.name}...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _resetPagination();
                            },
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                          )
                        : null,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.category.name,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
        actions: _isSearching
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded, color: Color(0xFF0F172A), size: 21),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(),
                  onPressed: () => HapticFeedback.lightImpact(),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF0F172A), size: 23),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSearching = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _searchFocusNode.requestFocus();
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Left Subcategory Rail (Reference Replica with Soft Lavender Active Pill)
              if (subcats.length > 1)
                Container(
                  width: Responsive.isSmallMobile(context) ? 72 : 82,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: subcats.length,
                    itemBuilder: (context, idx) {
                      final item = subcats[idx];
                      final isSelected = _selectedSubcatId == item.id;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedSubcatId = item.id;
                          });
                          _resetPagination();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          decoration: BoxDecoration(
                            // Reference screenshot uses soft purple/lavender background for selected
                            color: isSelected ? const Color(0xFFF3E8FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 38,
                                height: 38,
                                child: Center(
                                  child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: item.imageUrl!,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, __, ___) => Text(item.emoji, style: const TextStyle(fontSize: 20)),
                                        )
                                      : Text(item.emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF9333EA) : const Color(0xFF334155),
                                  height: 1.15,
                                  letterSpacing: -0.2,
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

              // 3. Right Product Feed (2-Column Reference Replica with Smooth Fluid Crossfade)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('feed_${_selectedSubcatId}_${_searchQuery}_${visibleProductsAsync.isLoading}'),
                    child: visibleProductsAsync.when(
                      skipLoadingOnRefresh: true,
                  data: (products) {
                    var list = List<Product>.from(products);

                    if (list.isEmpty && catalogProducts.isNotEmpty) {
                      list = catalogProducts
                          .where((p) => isProductInGroceryCategory(p, widget.category))
                          .toList();
                    }

                    if (_searchQuery.isNotEmpty) {
                      list = list.where((p) {
                        final nameMatch = p.name.toLowerCase().contains(_searchQuery);
                        final tagMatch = p.tags.any((t) => t.toLowerCase().contains(_searchQuery));
                        final unitMatch = p.unit.toLowerCase().contains(_searchQuery);
                        final descMatch = (p.description ?? '').toLowerCase().contains(_searchQuery);
                        return nameMatch || tagMatch || unitMatch || descMatch;
                      }).toList();
                    } else if (_selectedSubcatId != 'all' &&
                        subcats.any((item) => item.id == _selectedSubcatId)) {
                      final selectedSubcat =
                          subcats.firstWhere((item) => item.id == _selectedSubcatId);
                      if (selectedSubcat.id != 'all') {
                        list = list.where((p) => isProductInGroceryCategory(p, selectedSubcat)).toList();
                      }
                    }

                    // Sort in stock first
                    list.sort((a, b) {
                      if (a.isInStock && !b.isInStock) return -1;
                      if (!a.isInStock && b.isInStock) return 1;
                      return compareProductsSystematic(a, b, inStockFirst: false);
                    });

                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                                size: 42,
                                color: const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No items matching "$_searchQuery"'
                                    : 'Fresh stock arriving soon!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try checking another spelling in ${widget.category.name}'
                                    : 'Check back in a few minutes.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final visibleProducts = list.take(_visibleCount).toList();
                    final hasMore = _visibleCount < list.length;
                    final hasSubcats = subcats.length > 1;
                    final railWidth = hasSubcats ? (Responsive.isSmallMobile(context) ? 72.0 : 82.0) : 0.0;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final colWidth = (screenWidth - railWidth - 28.0) / 2;

                    return RefreshIndicator(
                      color: AppDesignSystem.primary,
                      onRefresh: () async {
                        await ProductRepository.invalidateAllCache();
                        ref.invalidate(productsProvider(widget.category.slug));
                        ref.invalidate(productsProvider(widget.category.id));
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: hasSubcats),
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = visibleProducts[index];
                                  return ProductCard(
                                    key: ValueKey(product.id),
                                    product: product,
                                    width: colWidth,
                                    isCompact: hasSubcats,
                                  );
                                },
                                childCount: visibleProducts.length,
                              ),
                            ),
                          ),
                          if (hasMore)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => _visibleCount += 12),
                                    child: Text(
                                      'Show more products',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppDesignSystem.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 90),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const ProductGridShimmer(count: 6),
                  error: (_, __) => Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.invalidate(productsProvider(widget.category.slug));
                        ref.invalidate(productsProvider(widget.category.id));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.primary),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
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

          // 4. Exact Reference Floating Bottom Cart Bar (Single Universal Widget)
          FloatingCartBar(bottomOffset: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exact Replica Product Card (Matching User's Reference Screenshot)
// ─────────────────────────────────────────────────────────────────────────────

