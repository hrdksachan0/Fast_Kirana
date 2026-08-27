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
import '../../core/utils/restaurant_utils.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/voice_search_sheet.dart';
import '../../widgets/empty_state.dart';

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
        final queryLower = _query.toLowerCase();
        final filtered = products.where((p) {
          final nameMatch = p.name.toLowerCase().contains(queryLower);
          final descMatch = p.description?.toLowerCase().contains(queryLower) ?? false;
          final catMatch = p.category?.name.toLowerCase().contains(queryLower) ?? false;
          final tagMatch = p.tags.any((t) => t.toLowerCase().contains(queryLower));
          final outlet = getOutletName(p).toLowerCase();
          final restaurantMatch = (p.restaurant?.name.toLowerCase().contains(queryLower) ?? false) ||
              outlet.contains(queryLower);
          return nameMatch || descMatch || catMatch || tagMatch || restaurantMatch;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            emoji: '🔍',
            title: 'No results found for "$_query"',
            subtitle: 'Try searching for milk, bread, butter, burger or check your spelling.',
            ctaLabel: 'Clear Search',
            onCta: () {
              _controller.clear();
              setState(() => _query = '');
            },
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Text(
              'Showing ${filtered.length} results for "$_query"',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return ProductCard(product: filtered[index]);
              },
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