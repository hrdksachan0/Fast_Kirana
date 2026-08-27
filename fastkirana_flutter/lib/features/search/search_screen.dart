import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/voice_search_sheet.dart';
import '../../widgets/empty_state.dart';
import '../products/product_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  List<String> _recentSearches = [];
  static const String _recentSearchesKey = 'user_recent_searches_list';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      _query = widget.initialQuery!.trim();
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentSearchesKey);
    if (raw != null && mounted) {
      setState(() {
        _recentSearches = raw.where((s) => s.trim().isNotEmpty).toList();
      });
    }
  }

  Future<void> _saveRecentSearch(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;

    final updated = [clean, ..._recentSearches.where((s) => s.toLowerCase() != clean.toLowerCase())];
    if (updated.length > 8) {
      updated.removeRange(8, updated.length);
    }

    setState(() => _recentSearches = updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, updated);
  }

  Future<void> _clearRecentSearches() async {
    HapticFeedback.lightImpact();
    setState(() => _recentSearches.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchTermSelected(String term) {
    HapticFeedback.selectionClick();
    _controller.text = term;
    setState(() => _query = term);
    _saveRecentSearch(term);
  }

  void _openVoiceSearch() {
    VoiceSearchSheet.show(context, onResult: (query) {
      _onSearchTermSelected(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 🔍 Ultra-Premium Zepto / Blinkit Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  // Back Button (If opened from another screen)
                  if (canPop) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                      ),
                    ),
                  ],

                  // Spacious Search Input Box
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _query.isNotEmpty ? const Color(0xFFE20A22) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: Color(0xFFE20A22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
                              onChanged: (val) {
                                setState(() => _query = val.trim());
                              },
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  _saveRecentSearch(val.trim());
                                }
                              },
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: 'Search for milk, butter, burger, maggi...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _openVoiceSearch,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.mic_rounded,
                                      size: 16,
                                      color: Color(0xFFEA580C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Voice',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFC2410C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: ResponsiveContainer(
                maxWidth: Responsive.wideMaxContentWidth,
                fillHeight: true,
                child: Stack(
                  children: [
                    _query.isEmpty ? _buildDiscoveryContent() : _buildSearchResults(),

                    if (canPop)
                      const FloatingCartBar(bottomOffset: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryContent() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final allProductsAsync = ref.watch(productsProvider(null));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Real Persistent Recent Searches (Only visible when user has history)
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
                onTap: _clearRecentSearches,
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

        // 2. Real Dynamic Categories from API
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      'Browse by Category',
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
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final cat = categories[idx];
                      return GestureDetector(
                        onTap: () => _onSearchTermSelected(cat.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Text('🛍️', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
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
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // 3. Real Dynamic Trending & Popular Searches from Database
        allProductsAsync.when(
          data: (products) {
            final popularProducts = products
                .where((p) => p.isAvailable && (p.isBestSeller || p.tags.contains('popular')))
                .take(10)
                .toList();

            final displayItems = popularProducts.isNotEmpty ? popularProducts : products.take(8).toList();
            if (displayItems.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      'Trending & Popular Now',
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
                  children: displayItems.map((prod) {
                    return GestureDetector(
                      onTap: () => _onSearchTermSelected(prod.name),
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
                              prod.name,
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
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final productsAsync = ref.watch(productsProvider(null));

    return productsAsync.when(
      data: (products) {
        final queryClean = _query.toLowerCase().trim();
        final queryWords = queryClean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

        final isRestaurantQuery = ['wedson', 'bal udyan', 'baludyan', 'a.s', 'as restaurant', 'as cafe'].any((r) => queryClean.contains(r));

        final filtered = products.where((p) {
          final pName = p.name.toLowerCase();
          final outlet = getOutletName(p).toLowerCase();
          final isFood = isRestaurantProduct(p);

          // 1. If user typed restaurant name specifically (e.g. "wedson")
          if (isRestaurantQuery) {
            return outlet.contains(queryClean) || pName.contains(queryClean);
          }

          // 2. Strict Category / Dish Type Exclusion
          // If searching "burger", product MUST contain "burger"
          if (queryWords.any((w) => w == 'burger' || w == 'burgers') && !pName.contains('burger')) {
            return false;
          }
          // If searching "pizza", product MUST contain "pizza"
          if (queryWords.any((w) => w == 'pizza' || w == 'pizzas') && !pName.contains('pizza')) {
            return false;
          }
          // If searching "sandwich", product MUST contain "sandwich"
          if (queryWords.any((w) => w.contains('sandwich')) && !pName.contains('sandwich')) {
            return false;
          }
          // If searching "roll", product MUST contain "roll" or "wrap"
          if (queryWords.any((w) => w == 'roll' || w == 'rolls' || w == 'wrap') && !pName.contains('roll') && !pName.contains('wrap')) {
            return false;
          }
          // If searching "momo" / "momos"
          if (queryWords.any((w) => w.startsWith('momo')) && !pName.contains('momo')) {
            return false;
          }
          // If searching "noodle" / "maggi" / "chowmein"
          if (queryWords.any((w) => w.contains('noodle') || w == 'maggi' || w.contains('chowmein')) &&
              !pName.contains('noodle') && !pName.contains('maggi') && !pName.contains('chowmein') && !pName.contains('pasta')) {
            return false;
          }

          // 3. Multi-word match in name
          final isVeg = !p.tags.any((t) => t.toLowerCase().contains('non-veg') || t.toLowerCase() == 'egg') &&
              !pName.contains('chicken') && !pName.contains('egg') && !pName.contains('mutton');

          final matchesWords = queryWords.every((word) {
            if (word == 'veg' || word == 'veggie') {
              return pName.contains('veg') || isVeg;
            }
            return pName.contains(word);
          });

          if (matchesWords) return true;

          // 4. Exact substring match in name
          if (pName.contains(queryClean)) return true;

          return false;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            emoji: '🔍',
            title: 'No results found for "$_query"',
            subtitle: 'Try searching for veg burger, pizza, cheese roll, milk or check your spelling.',
            ctaLabel: 'Clear Search',
            onCta: () {
              _controller.clear();
              setState(() => _query = '');
            },
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Results count
            Text(
              'Showing ${filtered.length} results for "$_query"',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),

            // White Container List with Restaurant Badges on Each Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  final isLast = index == filtered.length - 1;

                  final isFood = isRestaurantProduct(product);
                  final outletName = isFood ? getOutletName(product) : null;

                  Color chipColor = const Color(0xFFD97706);
                  Color chipBg = const Color(0xFFFFFBEB);
                  if (outletName != null) {
                    if (outletName.contains('Wedson')) {
                      chipColor = const Color(0xFFEA580C);
                      chipBg = const Color(0xFFFFF7ED);
                    } else if (outletName.contains('Bal Udyan')) {
                      chipColor = const Color(0xFF7C3AED);
                      chipBg = const Color(0xFFF5F3FF);
                    } else if (outletName.contains('A.S')) {
                      chipColor = const Color(0xFF0284C7);
                      chipBg = const Color(0xFFF0F9FF);
                    }
                  }

                  final settings = ref.watch(storeSettingsProvider).valueOrNull;
                  final isGroceryOpen = settings?.groceryMartOpen ?? true;
                  final isRestaurantOpen = (settings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
                  final isStoreOpen = isFood ? isRestaurantOpen : isGroceryOpen;
                  final isOutOfStock = product.stock <= 0 || !product.isAvailable;
                  final isClosed = !isStoreOpen || isOutOfStock;

                  // Veg / Non-veg
                  final tags = product.tags.map((t) => t.toLowerCase()).toList();
                  final nameLower = product.name.toLowerCase();
                  final isVeg = !tags.any((t) => t.contains('non-veg') || t.contains('nonveg') || t == 'egg' || t.contains('chicken')) &&
                      !nameLower.contains('chicken') && !nameLower.contains('egg') && !nameLower.contains('mutton');

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                      ),
                      child: Row(
                        children: [
                          // 1. Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 58,
                              height: 58,
                              color: const Color(0xFFF8FAFC),
                              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      product.imageUrl!.startsWith('/')
                                          ? 'https://www.fastkirana.in${product.imageUrl}'
                                          : product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Icon(isFood ? Icons.restaurant_rounded : Icons.shopping_bag_outlined, color: const Color(0xFF94A3B8), size: 22),
                                      ),
                                    )
                                  : Center(
                                      child: Icon(isFood ? Icons.restaurant_rounded : Icons.shopping_bag_outlined, color: const Color(0xFF94A3B8), size: 22),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Info Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isFood) ...[
                                      Container(
                                        width: 11,
                                        height: 11,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 4.5,
                                            height: 4.5,
                                            decoration: BoxDecoration(
                                              shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                                              color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),

                                // Respective Restaurant Badge on Card
                                if (outletName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: chipBg,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: chipColor.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.storefront_rounded, size: 10, color: chipColor),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          outletName,
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: chipColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (product.category != null)
                                  Text(
                                    product.category!.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                const SizedBox(height: 4),

                                // Price
                                Row(
                                  children: [
                                    Text(
                                      '₹${product.price.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (product.mrp > product.price) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        '₹${product.mrp.toInt()}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.lineThrough,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 3. Action
                          const SizedBox(width: 8),
                          if (isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                isOutOfStock ? 'Sold Out' : 'Closed',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          else
                            Consumer(
                              builder: (context, ref, _) {
                                final cart = ref.watch(cartProvider).valueOrNull;
                                final inCart = cart?.items.any((i) => i.productId == product.id || i.product.id == product.id) ?? false;

                                if (inCart) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(cartProvider.notifier).addProduct(product);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: chipColor, width: 1.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: chipColor.withValues(alpha: 0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'ADD',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: chipColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => _buildShimmerGrid(),
      error: (err, _) => Center(
        child: Text(
          'Error loading products: $err',
          style: GoogleFonts.inter(color: const Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.60,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}