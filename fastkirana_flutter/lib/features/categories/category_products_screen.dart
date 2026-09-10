import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../data/repositories/product_repository.dart';
import '../../providers/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/voice_search_sheet.dart';
import '../products/product_detail_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = 12;

  static const Color primaryRed = AppDesignSystem.primary;

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
    // Watch category products using ID (or slug as fallback)
    final catKey = widget.category.id.isNotEmpty ? widget.category.id : widget.category.slug;
    final productsAsync = ref.watch(productsProvider(catKey));
    final catalogProducts = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartCount = ref.watch(cartProvider).value?.totalItems ?? 0;

    final allCats = categoriesAsync.valueOrNull ?? [];
    final catIdLower = widget.category.id.toLowerCase().trim();
    final catSlugLower = widget.category.slug.toLowerCase().trim();

    final dbSubcats = allCats.where((c) {
      if (c.parentId == null || c.parentId!.isEmpty) return false;
      final pId = c.parentId!.toLowerCase().trim();
      return pId == catIdLower || pId == catSlugLower;
    }).toList();

    final List<_SubcatItem> subcats = [
      const _SubcatItem(id: 'all', name: 'All Items', slug: 'all', emoji: '✨'),
      if (dbSubcats.isNotEmpty)
        ...dbSubcats.map((sc) => _SubcatItem(
          id: sc.id,
          name: sc.name.trim(),
          slug: sc.slug.trim(),
          emoji: (sc.imageUrl != null && !sc.imageUrl!.startsWith('http') && sc.imageUrl!.length < 5) ? sc.imageUrl! : '🏷️',
          imageUrl: (sc.imageUrl != null && sc.imageUrl!.startsWith('http')) ? sc.imageUrl : null,
        )),
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
              // 1. Left Vertical Subcategory Rail (Blinkit 2-Pane Navigation) - only if DB subcategories exist
              if (subcats.length > 1)
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
                                child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: item.imageUrl!,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Text(
                                            item.emoji,
                                            style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18)),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        item.emoji,
                                        style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18)),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.name,
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
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                      ),
                      child: Column(
                        children: [
                          // Modern Aesthetic Search Input inside category
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _searchQuery.isNotEmpty
                                    ? AppDesignSystem.primary
                                    : const Color(0xFFE2E8F0),
                                width: _searchQuery.isNotEmpty ? 1.4 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  BoxShadow(
                                    color: AppDesignSystem.primary.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Circular lens badge
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _searchQuery.isNotEmpty
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search_rounded,
                                    size: 15,
                                    color: _searchQuery.isNotEmpty
                                        ? AppDesignSystem.primary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Input Field
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val.trim().toLowerCase();
                                      });
                                      _resetPagination();
                                    },
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    cursorColor: AppDesignSystem.primary,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Search in ${widget.category.name}...',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),

                                // Clear or Voice Search
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _resetPagination();
                                    },
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        height: 14,
                                        width: 1,
                                        color: const Color(0xFFE2E8F0),
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          VoiceSearchSheet.show(
                                            context,
                                            onResult: (voiceText) {
                                              if (voiceText.trim().isNotEmpty) {
                                                setState(() {
                                                  _searchController.text = voiceText.trim();
                                                  _searchQuery = voiceText.trim().toLowerCase();
                                                });
                                                _resetPagination();
                                              }
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFEF2F2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.mic_rounded,
                                            size: 14,
                                            color: AppDesignSystem.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
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
                                _buildFilterPill('⚡ Deals', _selectedSort == '⚡ Deals'),
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

                          // Fallback to global catalog cache if direct category query returned empty
                          if (list.isEmpty && catalogProducts.isNotEmpty) {
                            list = catalogProducts.where((p) {
                              final pCatId = (p.categoryId ?? '').toLowerCase().trim();
                              final pSubId = (p.category?.id ?? '').toLowerCase().trim();
                              final pSubSlug = (p.category?.slug ?? '').toLowerCase().trim();
                              final pParentId = (p.category?.parentId ?? '').toLowerCase().trim();
                              final isDirectId = pCatId == catIdLower || pSubId == catIdLower || pParentId == catIdLower;
                              final isSlug = catSlugLower.isNotEmpty && (pSubSlug == catSlugLower || pSubSlug.contains(catSlugLower));
                              final isSubCode = catIdLower.startsWith('cat-') &&
                                  (pCatId.startsWith('sub-${catIdLower.replaceFirst('cat-', '')}-') ||
                                   pSubId.startsWith('sub-${catIdLower.replaceFirst('cat-', '')}-'));
                              return isDirectId || isSlug || isSubCode;
                            }).toList();
                          }

                          // Search filter (searches across the whole category)
                          if (_searchQuery.isNotEmpty) {
                            list = list.where((p) {
                              final nameMatch = p.name.toLowerCase().contains(_searchQuery);
                              final tagMatch = p.tags.any((t) => t.toLowerCase().contains(_searchQuery));
                              final descMatch = (p.description ?? '').toLowerCase().contains(_searchQuery);
                              final unitMatch = p.unit.toLowerCase().contains(_searchQuery);
                              return nameMatch || tagMatch || descMatch || unitMatch;
                            }).toList();
                          } else if (_selectedSubcatIndex > 0 && _selectedSubcatIndex < subcats.length) {
                            final selectedSubcat = subcats[_selectedSubcatIndex];
                            if (selectedSubcat.id != 'all') {
                              final targetId = selectedSubcat.id.toLowerCase().trim();
                              final targetSlug = selectedSubcat.slug.toLowerCase().trim();
                              final targetName = selectedSubcat.name.toLowerCase().trim();

                              list = list.where((p) {
                                final pCatId = (p.categoryId ?? '').toLowerCase().trim();
                                final pSubId = (p.category?.id ?? '').toLowerCase().trim();
                                final pSubSlug = (p.category?.slug ?? '').toLowerCase().trim();
                                final pSubName = (p.category?.name ?? '').toLowerCase().trim();
                                final pParentId = (p.category?.parentId ?? '').toLowerCase().trim();
                                final pName = p.name.toLowerCase().trim();

                                // 1. Direct subcategory ID match
                                if (pCatId == targetId || pSubId == targetId || pParentId == targetId) return true;

                                // 2. Direct subcategory slug match
                                if (targetSlug.isNotEmpty && (pSubSlug == targetSlug || pSubSlug.contains(targetSlug))) return true;

                                // 3. Subcategory name match
                                if (targetName.isNotEmpty &&
                                    (pSubName == targetName || pSubName.contains(targetName) || targetName.contains(pSubName))) {
                                  return true;
                                }

                                // 4. Tag match
                                if (p.tags.any((t) =>
                                    t.toLowerCase().trim() == targetSlug ||
                                    t.toLowerCase().trim() == targetName)) {
                                  return true;
                                }

                                // 5. Product name contains subcategory name
                                if (targetName.length >= 4 && pName.contains(targetName)) return true;

                                return false;
                              }).toList();
                            }
                          }

                          // Sort
                          if (_selectedSort == 'Popularity') {
                            list.sort((a, b) {
                              final aScore = (a.isBestsellerProduct ? 30 : 0) + (a.isTopPick ? 20 : 0) + (a.isFlashDealProduct ? 10 : 0);
                              final bScore = (b.isBestsellerProduct ? 30 : 0) + (b.isTopPick ? 20 : 0) + (b.isFlashDealProduct ? 10 : 0);
                              return bScore.compareTo(aScore);
                            });
                          } else if (_selectedSort == '⚡ Deals') {
                            list = list.where((p) => p.isFlashDealProduct || p.discount >= 10 || p.tags.any((t) => t.toLowerCase().contains('deal') || t.toLowerCase().contains('flash'))).toList();
                          } else if (_selectedSort == 'Under ₹199') {
                            list = list.where((p) => p.price <= 199).toList();
                          } else if (_selectedSort == 'Low to High') {
                            list.sort((a, b) => a.price.compareTo(b.price));
                          } else if (_selectedSort == 'High to Low') {
                            list.sort((a, b) => b.price.compareTo(a.price));
                          }

                          // ALWAYS move out-of-stock items to the very end
                          list.sort((a, b) {
                            final aInStock = a.isAvailable && a.stock > 0;
                            final bInStock = b.isAvailable && b.stock > 0;
                            if (aInStock && !bInStock) return -1;
                            if (!aInStock && bInStock) return 1;
                            return 0;
                          });

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
                              final cardWidth = (constraints.maxWidth - 12 - (columns - 1) * 8) / columns;
                              final itemAspect = Responsive.productCardAspectRatio(context, isCompact: true);
                              final visibleProducts = list.take(_visibleCount).toList();
                              final hasMore = _visibleCount < list.length;

                          return RefreshIndicator(
                            color: AppDesignSystem.primary,
                            onRefresh: () async {
                              await ProductRepository.invalidateAllCache();
                              ref.invalidate(productsProvider(widget.category.slug));
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                                            width: cardWidth,
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
                              ),
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
        setState(() {
          _selectedSort = title;
        });
        _resetPagination();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
            width: 1.1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryRed.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 10.5),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}