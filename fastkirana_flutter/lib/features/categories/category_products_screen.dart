import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/utils/app_connectivity.dart';
import '../../core/widgets/contextual_brand_transition_screen.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../../data/repositories/product_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/dish_timing.dart';
import '../../widgets/variant_selector_sheet.dart';
import '../../widgets/floating_cart_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../products/product_detail_screen.dart';
import '../bakery/bakery_store_screen.dart';

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
  final TransitionContextType? loadingContext;
  final Duration loadingTimeout;
  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.loadingContext,
    this.loadingTimeout = const Duration(milliseconds: 1200),
  });

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  String _selectedSubcatId = 'all';
  bool _showContextualLoader = false;
  Timer? _loadingDelay;
  Timer? _loadingLimit;
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
    if (widget.loadingContext != null &&
        widget.loadingTimeout > const Duration(milliseconds: 180)) {
      _loadingDelay = Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _showContextualLoader = true);
      });
      _loadingLimit = Timer(widget.loadingTimeout, () {
        if (mounted) setState(() => _showContextualLoader = false);
      });
    }
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
      _visibleCount = 14;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _loadingDelay?.cancel();
    _loadingLimit?.cancel();
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
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final cachedPreview = ref.read(productRepositoryProvider).peekCachedProducts(
        categoryKey: catKey,
        storeId: ref.watch(currentStoreHubProvider).id);
    final visibleProductsAsync = !productsAsync.hasValue && (cachedPreview?.isNotEmpty ?? false)
        ? AsyncValue<List<Product>>.data(cachedPreview!)
        : productsAsync;

    if (_showContextualLoader &&
        widget.loadingContext != null &&
        !visibleProductsAsync.hasValue &&
        productsAsync.isLoading &&
        isOnline &&
        !MediaQuery.disableAnimationsOf(context)) {
      return ContextualBrandTransitionScreen(contextType: widget.loadingContext!);
    }

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
                  cursorColor: const Color(0xFFDB2777),
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
          Row(
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

              // 3. Right Product Feed (2-Column Reference Replica)
              Expanded(
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

                    return RefreshIndicator(
                      color: const Color(0xFFDB2777),
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
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = visibleProducts[index];
                                  return _ReferenceExactProductCard(
                                    key: ValueKey(product.id),
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
                                        color: const Color(0xFFDB2777),
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
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFDB2777)),
                  ),
                  error: (_, __) => Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.invalidate(productsProvider(widget.category.slug));
                        ref.invalidate(productsProvider(widget.category.id));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ),
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

class _ReferenceExactProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  const _ReferenceExactProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).value;
    final inCartQty = cart?.items
            .where((i) => i.productId == product.id || i.productId.startsWith('${product.id}_'))
            .fold<int>(0, (sum, i) => sum + i.quantity) ??
        0;

    // Store, timings, and stock availability checks
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isFood = isRestaurantProduct(product);
    final isGroceryOpen = settings?.groceryMartOpen ?? true;
    final isRestaurantOpen = RestaurantScheduleHelper.isProductRestaurantOpen(
      product,
      storeSettings: settings,
    );
    final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;

    final isOutOfStock = !product.isInStock;
    final timingStatus = isFood && product.availableStartTime != null && product.availableStartTime!.trim().isNotEmpty
        ? checkDishTimeAvailability(product.availableStartTime, product.availableEndTime)
        : const DishTimingStatus(isAvailableNow: true);

    final variants = product.parsedVariants.isNotEmpty ? product.parsedVariants : (product.variants ?? []);
    final hasVariants = variants.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Photo Container with Wishlist Heart & Floating Action Pill
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Clean Image Box with 16px radius
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 0.9),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.contain,
                              memCacheWidth: 350,
                              memCacheHeight: 350,
                              placeholder: (_, __) => Container(color: const Color(0xFFF8FAFC)),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.shopping_basket_outlined, color: Color(0xFFCBD5E1), size: 30),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.shopping_basket_outlined, color: Color(0xFFCBD5E1), size: 30),
                            ),
                    ),
                  ),
                ),

                // Top-Right: Heart Wishlist Icon
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),

                // Bottom Center/Right: Action Pill (Closed / Sold Out / In Cart Stepper / ADD)
                Positioned(
                  bottom: -11,
                  right: 8,
                  child: !isStoreOpen
                      ? GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isFood
                                            ? '${product.restaurant?.name ?? "Restaurant"} is currently closed.'
                                            : 'FastMinute Grocery Darkstore is currently closed at this hour.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF0F172A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  'CLOSED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : isOutOfStock
                          ? Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'SOLD OUT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            )
                          : !timingStatus.isAvailableNow
                              ? Container(
                                  height: 28,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                      width: 1.0,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    timingStatus.nextAvailableTimeStr != null
                                        ? timingStatus.nextAvailableTimeStr!
                                        : 'CLOSED',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                )
                              : inCartQty > 0
                                  ? Container(
                                      height: 29,
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDB2777), // Vibrant Pink/Rose from screenshot
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFDB2777).withValues(alpha: 0.30),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: hasVariants
                                          ? GestureDetector(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                VariantSelectorSheet.show(context, product);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '$inCartQty in cart',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.lightImpact();
                                                    ref.read(cartProvider.notifier).decrement(product.id);
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 3),
                                                    child: Icon(Icons.remove, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                                  child: Text(
                                                    '$inCartQty',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.lightImpact();
                                                    ref.read(cartProvider.notifier).increment(product);
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 3),
                                                    child: Icon(Icons.add, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (hasVariants) {
                                          VariantSelectorSheet.show(context, product);
                                        } else {
                                          ref.read(cartProvider.notifier).addProduct(product, 1);
                                        }
                                      },
                                      child: Container(
                                        height: hasVariants ? 32 : 29,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: hasVariants ? 10 : 14,
                                          vertical: hasVariants ? 2 : 0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFDB2777), // Pink/Rose border
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: hasVariants
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'ADD',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w900,
                                                      color: const Color(0xFFDB2777),
                                                      height: 1.0,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1.5),
                                                  Text(
                                                    '${variants.length} options',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF94A3B8),
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Center(
                                                child: Text(
                                                  'ADD',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(0xFFDB2777),
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Product Title (UPAR! 2-lines max, uniform height for locked grid rows)
          SizedBox(
            height: 36,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // 3. Unit / Weight
          Text(
            product.unit.isNotEmpty ? product.unit : '1 pc',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),

          // 4. Price Row (NICHE!): Solid Green Badge + Strike-through MRP (No OFF pill)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A), // Solid green badge from reference
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '₹${product.price.toInt()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (product.mrp > product.price) ...[
                const SizedBox(width: 5),
                Text(
                  '₹${product.mrp.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
