import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/voice_search_sheet.dart';
import '../../data/models/product.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/restaurant_card.dart';
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
  Timer? _debounce;
  List<String> _recentSearches = [];
  static const String _recentSearchesKey = 'user_recent_searches_list';
  int _searchPlaceholderIndex = 0;
  Timer? _placeholderTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      _query = widget.initialQuery!.trim();
    }
    _placeholderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _query.isEmpty && _controller.text.isEmpty) {
        setState(() {
          _searchPlaceholderIndex++;
        });
      }
    });
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

  void _selectCategory(String categoryId, String categoryName) {
    HapticFeedback.selectionClick();
    _controller.text = categoryName;
    setState(() {
      _query = categoryName;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placeholderTimer?.cancel();
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
    final restaurantsAsync = ref.watch(homeRestaurantsProvider);
    final restaurantNames = restaurantsAsync.valueOrNull
            ?.map((r) => r.name.trim())
            .where((name) => name.isNotEmpty)
            .take(6)
            .toList() ??
        [];

    final List<String> searchHints = [
      'Search for milk',
      if (restaurantNames.isNotEmpty) ...restaurantNames.map((name) => 'Search for "$name"'),
      'Search for "milk"',
      'Search for "butter"',
      'Search for "burger"',
      'Search for "pizza"',
    ];
    final currentHint = searchHints[_searchPlaceholderIndex % searchHints.length];

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
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
                  bottom: BorderSide(color: AppDesignSystem.slate100, width: 1.2),
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
                          color: AppDesignSystem.slate100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppDesignSystem.slate900,
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
                        color: AppDesignSystem.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _query.isNotEmpty ? AppDesignSystem.primary : AppDesignSystem.slate200,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: AppDesignSystem.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
                              onChanged: (val) {
                                _debounce?.cancel();
                                _debounce = Timer(const Duration(milliseconds: 300), () {
                                  if (mounted) setState(() => _query = val.trim());
                                });
                              },
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  _saveRecentSearch(val.trim());
                                }
                              },
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.slate900,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: currentHint,
                                hintStyle: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                  fontWeight: FontWeight.w500,
                                  color: AppDesignSystem.slate400,
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
                                setState(() {
                                  _query = '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppDesignSystem.slate200,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: AppDesignSystem.slate600,
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
                                    colors: [AppDesignSystem.orange200, AppDesignSystem.orange300],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.mic_rounded,
                                      size: 16,
                                      color: AppDesignSystem.orange600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Voice',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.orange700,
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
                      fontSize: Responsive.scaledFontSize(context, 13.5),
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
                    fontSize: Responsive.scaledFontSize(context, 11.5),
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
                          fontSize: Responsive.scaledFontSize(context, 11.5),
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
                    Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                    const SizedBox(width: 6),
                    Text(
                      'Browse by Category',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
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
                        onTap: () {
                          _selectCategory(cat.id, cat.name);
                          _controller.text = '';
                          setState(() => _query = '');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppDesignSystem.slate200),
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
                              Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.slate700,
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
                    Text('🔥', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                    const SizedBox(width: 6),
                    Text(
                      'Trending & Popular Now',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
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
                            const Icon(Icons.trending_up_rounded, size: 13, color: AppDesignSystem.orange600),
                            const SizedBox(width: 5),
                            Text(
                              prod.name,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
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
    final restaurantsAsync = ref.watch(homeRestaurantsProvider);
    final storeSettings = ref.watch(storeSettingsProvider).valueOrNull;

    return productsAsync.when(
      data: (products) {
        final queryClean = _query.toLowerCase().trim();
        final queryWords = queryClean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

        // 1. Dynamic matching for ANY restaurant registered in database
        final allRestaurants = restaurantsAsync.valueOrNull ?? [];
        final matchedRestaurants = allRestaurants.where((r) {
          final rName = r.name.toLowerCase();
          final rCuisines = r.cuisineTags.map((t) => t.toLowerCase()).join(' ');
          return rName.contains(queryClean) ||
              rCuisines.contains(queryClean) ||
              queryWords.any((w) => w.length > 2 && (rName.contains(w) || rCuisines.contains(w)));
        }).toList();

        final isRestaurantQuery = matchedRestaurants.isNotEmpty ||
            ['wedson', 'bal udyan', 'baludyan', 'a.s', 'as restaurant', 'as cafe', 'cafe', 'restaurant', 'dhaba'].any((r) => queryClean.contains(r));

        final filtered = products.where((p) {
          final pName = p.name.toLowerCase();
          final outlet = getOutletName(p).toLowerCase();

          // 1. If user typed restaurant name specifically (e.g. "wedson", "bal udyan", "A.S.")
          if (isRestaurantQuery) {
            // If matched specific restaurants, show dishes from those outlets
            if (matchedRestaurants.isNotEmpty) {
              final matchesMatchedOutlet = matchedRestaurants.any((r) =>
                  p.restaurantId == r.id ||
                  (p.restaurant?.name.toLowerCase() ?? '').contains(r.name.toLowerCase()) ||
                  outlet.contains(r.name.toLowerCase()));
              if (matchesMatchedOutlet) return true;
            }
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

          // 4. Exact substring match in name or outlet
          if (pName.contains(queryClean) || outlet.contains(queryClean)) return true;

          return false;
        }).toList();

        if (filtered.isEmpty && matchedRestaurants.isEmpty) {
          return EmptyState(
            emoji: '🔍',
            title: 'No results found for "$_query"',
            subtitle: 'Try searching for wedson, bal udyan, burger, pizza, milk or check your spelling.',
            ctaLabel: 'Clear Search',
            onCta: () {
              _controller.clear();
              setState(() => _query = '');
            },
          );
        }

        final showRestaurantsSection = matchedRestaurants.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Header summary count
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Showing ${showRestaurantsSection ? "${matchedRestaurants.length} restaurant(s) & " : ""}${filtered.length} items for "$_query"',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.slate500,
                ),
              ),
            ),

            // 🏬 MATCHED RESTAURANTS SECTION
            if (showRestaurantsSection) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('🍽️', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restaurants & Outlets',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...matchedRestaurants.map((r) => RestaurantCard(restaurant: r)),
              const SizedBox(height: 16),
            ],

            // 🍔 MATCHED DISHES / PRODUCTS SECTION
            if (filtered.isNotEmpty) ...[
              if (showRestaurantsSection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('🍜', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dishes & Items',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ...List.generate(filtered.length, (productIndex) {
                final product = filtered[productIndex];
                final isFirst = productIndex == 0;
                final isLast = productIndex == filtered.length - 1;

                final isFood = isRestaurantProduct(product);
                final outletName = isFood ? getOutletName(product) : null;

                Color chipColor = AppDesignSystem.amber600;
                Color chipBg = AppDesignSystem.amber50;
                if (outletName != null) {
                  if (outletName.contains('Wedson')) {
                    chipColor = AppDesignSystem.orange600;
                    chipBg = AppDesignSystem.orange50;
                  } else if (outletName.contains('Bal Udyan')) {
                    chipColor = AppDesignSystem.violet600;
                    chipBg = AppDesignSystem.violet50;
                  } else if (outletName.contains('A.S')) {
                    chipColor = AppDesignSystem.cyan600;
                    chipBg = AppDesignSystem.sky50;
                  }
                }

                final isGroceryOpen = storeSettings?.groceryMartOpen ?? true;
                final isRestaurantOpen = (storeSettings?.restaurantOpen ?? true) && (product.restaurant?.isOpen ?? true);
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
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: isFirst ? const Radius.circular(18) : Radius.zero,
                        bottom: isLast ? const Radius.circular(18) : Radius.zero,
                      ),
                      border: Border(
                        left: const BorderSide(color: AppDesignSystem.slate200, width: 1.1),
                        right: const BorderSide(color: AppDesignSystem.slate200, width: 1.1),
                        top: isFirst ? const BorderSide(color: AppDesignSystem.slate200, width: 1.1) : BorderSide.none,
                        bottom: isLast
                            ? const BorderSide(color: AppDesignSystem.slate200, width: 1.1)
                            : const BorderSide(color: AppDesignSystem.slate100, width: 1),
                      ),
                    ),
                    child: _buildProductRow(
                      product,
                      isFood,
                      outletName,
                      chipColor,
                      chipBg,
                      isClosed,
                      isOutOfStock,
                      isStoreOpen,
                      isVeg,
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
      loading: () => _buildShimmerGrid(),
      error: (err, _) => Center(
        child: Text(
          'Error loading products: $err',
          style: GoogleFonts.inter(color: AppDesignSystem.red600),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 16, Responsive.horizontalPadding(context), 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5),
          childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: true),
          crossAxisSpacing: Responsive.horizontalPadding(context) * 0.5,
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

  Widget _buildProductRow(
    Product product,
    bool isFood,
    String? outletName,
    Color chipColor,
    Color chipBg,
    bool isClosed,
    bool isOutOfStock,
    bool isStoreOpen,
    bool isVeg,
  ) {
    return Row(
      children: [
        // 1. Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 58,
            height: 58,
            color: AppDesignSystem.slate50,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!.startsWith('/')
                        ? 'https://www.fastkirana.in${product.imageUrl}'
                        : product.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                    maxWidthDiskCache: 400,
                    maxHeightDiskCache: 400,
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(isFood ? Icons.restaurant_rounded : Icons.shopping_bag_outlined, color: AppDesignSystem.slate400, size: 22),
                    ),
                  )
                : Center(
                    child: Icon(isFood ? Icons.restaurant_rounded : Icons.shopping_bag_outlined, color: AppDesignSystem.slate400, size: 22),
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
                          color: isVeg ? AppDesignSystem.green700 : AppDesignSystem.red600,
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
                            color: isVeg ? AppDesignSystem.green700 : AppDesignSystem.red600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
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
                          fontSize: Responsive.scaledFontSize(context, 9.5),
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
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.slate500,
                  ),
                ),
              const SizedBox(height: 4),

              // Price
              Row(
                children: [
                  Text(
                    '₹${product.price.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (product.mrp > product.price) ...[
                    const SizedBox(width: 5),
                    Text(
                      '₹${product.mrp.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                        color: AppDesignSystem.slate400,
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
              color: AppDesignSystem.slate100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppDesignSystem.slate200),
            ),
            child: Text(
              isOutOfStock ? 'Sold Out' : 'Closed',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate400,
              ),
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(cartProvider).valueOrNull;
              final inCart = cart?.items.any((i) => i.productId == product.id || i.product.id == product.id) ?? false;

              if (inCart) {
                final qty = cart?.items
                        .firstWhere(
                          (i) => i.productId == product.id || i.product.id == product.id,
                          orElse: () => cart.items.first,
                        )
                        .quantity ??
                    1;

                return Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFood
                          ? const [AppDesignSystem.orange600, AppDesignSystem.orange500]
                          : const [AppDesignSystem.green700, AppDesignSystem.green600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (isFood ? AppDesignSystem.orange600 : AppDesignSystem.green600).withValues(alpha: 0.28),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).decrement(product.id);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                          child: Icon(Icons.remove_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '$qty',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: Responsive.scaledFontSize(context, 12),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (qty >= product.stock) {
                            HapticFeedback.heavyImpact();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Only ${product.stock} units available in stock!',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                backgroundColor: AppDesignSystem.red600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).increment(product);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                          child: Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
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
                      fontSize: Responsive.scaledFontSize(context, 11),
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
    );
  }
}