import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/product_card.dart';
import '../../categories/category_products_screen.dart';
import '../utils/category_visual_helper.dart';
import 'home_end_of_aisle_search_card.dart';

class HomeInfiniteFeed {
  HomeInfiniteFeed._();

  static List<Product> getFilteredGridProducts({
    required List<Product> all,
    required List<Category> categories,
    required int selectedFilterIndex,
  }) {
    // Strictly isolate grocery items (exclude restaurant dishes)
    final groceryItems = all.where((p) => p.restaurantId == null && p.restaurant == null).toList();

    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) return false;
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood') ||
          name.contains('restaurant') ||
          name.contains('cafe')) {
        return false;
      }
      return true;
    }).toList();
    groceryCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final List<Product> result;
    if (selectedFilterIndex > 0 && selectedFilterIndex <= groceryCategories.length) {
      final selectedCat = groceryCategories[selectedFilterIndex - 1];
      result = groceryItems.where((p) => isProductInGroceryCategory(p, selectedCat)).toList();
    } else {
      result = groceryItems;
    }
    result.sort((a, b) => compareProductsSystematic(a, b));
    return result;
  }

  static String _getCategorySubtitle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('snack') || lower.contains('munch')) return 'Crunchy chips, namkeen & snacks';
    if (lower.contains('choco') || lower.contains('sweet')) return 'Dairy Milk Silk, bars & confectionery';
    if (lower.contains('fruit') || lower.contains('veg')) return 'Farm fresh vegetables & fruits';
    if (lower.contains('atta') || lower.contains('rice') || lower.contains('dal') || lower.contains('oil') || lower.contains('grain') || lower.contains('pulse')) return 'Fortune oil, grains, atta & pulses';
    if (lower.contains('ice') || lower.contains('cream') || lower.contains('dessert')) return 'Cool tubs, cones, kulfi & desserts';
    if (lower.contains('beverage') || lower.contains('drink')) return 'Cold drinks, real juices & energy sodas';
    if (lower.contains('bakery') || lower.contains('biscuit')) return 'Fresh cookies, rusks & bakery bites';
    if (lower.contains('care') || lower.contains('hygiene')) return 'Soaps, shampoos, skincare & essentials';
    if (lower.contains('clean') || lower.contains('home')) return 'Detergents, cleaners & home supplies';
    if (lower.contains('health')) return 'Nutritious picks, dry fruits & oats';
    if (lower.contains('pack')) return 'Instant noodles, pasta & ready to eat';
    if (lower.contains('food') || lower.contains('rest') || lower.contains('cafe')) return 'Hot burgers, rolls, pizzas & meals';
    return 'Top quality grocery essentials';
  }

  static List<Widget> buildSlivers({
    required BuildContext context,
    required WidgetRef ref,
    required ScrollController scrollController,
    required int visibleGridCount,
    required int selectedFilterIndex,
  }) {
    final catalogAsync = ref.watch(homeProductCatalogProvider);

    return catalogAsync.when(
      loading: () => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
            child: _buildInfiniteFeedHeader(context, ref, 0, isLoading: true, selectedFilterIndex: selectedFilterIndex),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
              childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: 4,
            ),
          ),
        ),
      ],
      error: (_, __) => [const SliverToBoxAdapter(child: SizedBox.shrink())],
      data: (allProducts) {
        // When default "All" is active, avoid dumping an unorganized mixed grid of all 200 items.
        // Instead, show Zepto/Blinkit-style "Explore by Category" Bento Grid + End-of-Aisle Search Prompt!
        if (selectedFilterIndex == 0) {
          return _buildCategoryBentoFeed(context, ref, scrollController);
        }

        final categories = ref.read(categoriesProvider).valueOrNull ?? [];
        final filteredProducts = getFilteredGridProducts(
          all: allProducts,
          categories: categories,
          selectedFilterIndex: selectedFilterIndex,
        );

        if (filteredProducts.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Text('🛍️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        'No products found in this collection',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try picking another category tab above',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        }

        final visibleProducts = filteredProducts.take(visibleGridCount).toList();
        final hasMore = visibleGridCount < filteredProducts.length;

        return [
          // Section Title Header with Dynamic Total Count Badge
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
              child: _buildInfiniteFeedHeader(
                context,
                ref,
                filteredProducts.length,
                isLoading: false,
                selectedFilterIndex: selectedFilterIndex,
              ),
            ),
          ),

          // 2-Column Virtualized SliverGrid (Ultra-smooth, zero jank, only on-screen items kept in memory)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
                childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = visibleProducts[index];
                  return ProductCard(
                    key: ValueKey('infinite_grid_${product.id}'),
                    product: product,
                    isCompact: false,
                  );
                },
                childCount: visibleProducts.length,
              ),
            ),
          ),

          // Bottom Load More Indicator or Catalog Completion Badge
          SliverToBoxAdapter(
            child: _buildInfiniteFeedFooter(
              context,
              scrollController,
              visibleCount: visibleProducts.length,
              totalCount: filteredProducts.length,
              hasMore: hasMore,
            ),
          ),
        ];
      },
    );
  }

  static Widget _buildInfiniteFeedHeader(
    BuildContext context,
    WidgetRef ref,
    int totalCount, {
    required bool isLoading,
    required int selectedFilterIndex,
  }) {
    String title = 'All Groceries & Essentials';
    String subtitle = '⚡ Fast Delivery from Ghatampur darkstore';
    IconData icon = Icons.auto_awesome_rounded;

    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) return false;
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood') ||
          name.contains('restaurant') ||
          name.contains('cafe')) {
        return false;
      }
      return true;
    }).toList();

    if (selectedFilterIndex > 0 && selectedFilterIndex <= groceryCategories.length) {
      final selectedCat = groceryCategories[selectedFilterIndex - 1];
      title = selectedCat.name;
      subtitle = _getCategorySubtitle(selectedCat.name);
      icon = Icons.shopping_basket_rounded;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppDesignSystem.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 16.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppDesignSystem.primary.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 12, color: AppDesignSystem.primary),
                const SizedBox(width: 4),
                Text(
                  '$totalCount Items',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _buildInfiniteFeedFooter(
    BuildContext context,
    ScrollController scrollController, {
    required int visibleCount,
    required int totalCount,
    required bool hasMore,
  }) {
    if (hasMore) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesignSystem.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading next 20 products... ($visibleCount of $totalCount)',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // When all items have been reached in the feed
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        border: Border.all(color: AppDesignSystem.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
              const SizedBox(width: 6),
              Text(
                'You\'ve explored all $totalCount items!',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 13, color: AppDesignSystem.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Back to top',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildCategoryBentoFeed(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
  ) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final catalogProducts = ref.watch(homeProductCatalogProvider).valueOrNull ?? [];

    return categoriesAsync.when(
      loading: () => [
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      error: (_, __) => [
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      ],
      data: (categories) {
        final groceryCategories = categories.where((cat) {
          final slug = cat.slug.toLowerCase().trim();
          final name = cat.name.toLowerCase().trim();
          if (cat.parentId != null && cat.parentId!.isNotEmpty) return false;
          if (slug == 'all' || slug.contains('restaurant') || slug.contains('cafe')) return false;
          if (name.contains('restaurant') || name.contains('cafe')) return false;
          return true;
        }).toList();

        if (groceryCategories.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

        // Pre-index subcategories by parentId to compute exact recursive product count sums
        final Map<String, int> categorySumMap = {};
        for (final parent in groceryCategories) {
          final parentIdLower = parent.id.toLowerCase().trim();
          final parentSlugLower = parent.slug.toLowerCase().trim();

          // Find all direct children/subcategories
          final childCats = categories.where((c) {
            if (c.parentId == null || c.parentId!.isEmpty) return false;
            final pId = c.parentId!.toLowerCase().trim();
            return pId == parentIdLower || pId == parentSlugLower;
          }).toList();

          int totalCount = parent.productCount ?? 0;
          for (final sub in childCats) {
            totalCount += (sub.productCount ?? 0);
          }

          // Also count loaded catalog products matching this parent category
          if (catalogProducts.isNotEmpty) {
            final liveMatches = catalogProducts.where((p) => isProductInGroceryCategory(p, parent)).length;
            if (liveMatches > totalCount) {
              totalCount = liveMatches;
            }
          }

          // Fallback to rich default estimates if database count is 0
          if (totalCount <= 0) {
            final slug = parent.slug.toLowerCase();
            if (slug.contains('kitchen') || slug.contains('atta') || slug.contains('ration')) {
              totalCount = 42;
            } else if (slug.contains('fruit') || slug.contains('veg')) {
              totalCount = 33;
            } else if (slug.contains('snack') || slug.contains('munch')) {
              totalCount = 28;
            } else if (slug.contains('dry') || slug.contains('super')) {
              totalCount = 24;
            } else if (slug.contains('beverage') || slug.contains('drink')) {
              totalCount = 19;
            } else if (slug.contains('ice') || slug.contains('dessert')) {
              totalCount = 15;
            } else if (slug.contains('package')) {
              totalCount = 18;
            } else if (slug.contains('care') || slug.contains('hygiene')) {
              totalCount = 22;
            } else if (slug.contains('home') || slug.contains('clean')) {
              totalCount = 20;
            } else if (slug.contains('dairy') || slug.contains('milk')) {
              totalCount = 25;
            } else {
              totalCount = 16;
            }
          }

          categorySumMap[parent.id] = totalCount;
        }

        return [
          // Section Title Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                    ),
                    child: const Icon(Icons.grid_view_rounded, size: 18, color: AppDesignSystem.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore All Categories',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Browse complete aisles & subcategories in Ghatampur',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-Column Luxury Bento Grid of Categories
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
                childAspectRatio: context.isCompact ? 1.95 : 2.12,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = groceryCategories[index];
                  final totalCount = categorySumMap[cat.id] ?? (cat.productCount ?? 16);
                  final bgTint = CategoryVisualHelper.getSoftColor(cat.slug, cat.name);
                  final borderTint = CategoryVisualHelper.getBorderColor(cat.slug, cat.name);

                  return Bounceable(
                    scaleFactor: 0.94,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderTint.withValues(alpha: 0.6), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Luxury Image Container with soft category-calibrated tint
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: bgTint,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: borderTint, width: 0.9),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CategoryVisualHelper.buildAvatarImage(context, cat),
                            ),
                          ),
                          const SizedBox(width: 9),

                          // Text Content (Truncation-Free & Clean)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cat.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$totalCount+ items',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Clean Nav Arrow
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: groceryCategories.length,
              ),
            ),
          ),

          // End of Aisle Search & Discovery Prompt Card
          SliverToBoxAdapter(
            child: HomeEndOfAisleSearchCard(scrollController: scrollController),
          ),
        ];
      },
    );
  }
}
