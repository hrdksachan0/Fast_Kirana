import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/store_hub_provider.dart';
import '../../../widgets/product_card.dart';
import 'home_end_of_aisle_search_card.dart';
import 'home_aisle_spotlight_banner.dart';

class HomeInfiniteFeed {
  HomeInfiniteFeed._();

  /// Strictly extract only SUBCATEGORIES for granular product filtering in the bottom feed
  static List<Category> getGrocerySubcategories(List<Category> allCategories) {
    final list = allCategories.where((c) {
      // Must be a subcategory (has parentId)
      if (c.parentId == null || c.parentId!.isEmpty) return false;
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

    // Priority ordering for intuitive, fast daily essentials shopping
    int getPriority(Category cat) {
      final id = cat.id.toUpperCase();
      final slug = cat.slug.toLowerCase();
      if (id == 'SUB-113-01' || slug.contains('atta')) return 1;
      if (id == 'SUB-113-03' || slug.contains('dal')) return 2;
      if (id == 'SUB-113-02' || slug.contains('oil')) return 3;
      if (id == 'SUB-113-04' || slug.contains('masala')) return 4;
      if (id == 'SUB-113-05' || slug.contains('tea')) return 5;
      if (id == 'SUB-102-01' || slug.contains('cookie')) return 6;
      if (id == 'SUB-102-02' || slug.contains('namkeen')) return 7;
      if (id == 'SUB-104-01' || slug.contains('sauce')) return 8;
      if (id == 'SUB-104-02' || slug.contains('noodle')) return 9;
      if (id == 'SUB-114-02' || slug.contains('dry-fruit')) return 10;
      if (id == 'SUB-115-03' || slug.contains('choco')) return 11;
      if (id == 'SUB-115-02' || slug.contains('bakery')) return 12;
      if (id == 'SUB-107-03' || slug.contains('laund')) return 13;
      if (id == 'SUB-107-01' || slug.contains('dish')) return 14;
      if (id == 'SUB-109-02' || slug.contains('oral')) return 15;
      if (id == 'SUB-109-01' || slug.contains('hair')) return 16;
      if (id == 'SUB-101-01' || slug.contains('fruit')) return 17;
      if (id == 'SUB-101-02' || slug.contains('veg')) return 18;
      return 50 + cat.sortOrder;
    }

    list.sort((a, b) => getPriority(a).compareTo(getPriority(b)));
    return list;
  }

  static List<Product> getFilteredGridProducts({
    required List<Product> all,
    required List<Category> categories,
    required int selectedFilterIndex,
  }) {
    // Strictly isolate grocery items (exclude restaurant dishes)
    final groceryItems = all.where((p) => p.restaurantId == null && p.restaurant == null).toList();
    final subcategories = getGrocerySubcategories(categories);

    final List<Product> result;
    if (selectedFilterIndex > 0 && selectedFilterIndex <= subcategories.length) {
      final selectedSub = subcategories[selectedFilterIndex - 1];
      result = groceryItems.where((p) => isProductInGroceryCategory(p, selectedSub)).toList();
    } else {
      result = groceryItems;
    }
    result.sort((a, b) => compareProductsSystematic(a, b));
    return result;
  }

  static String _getSubcategoryEmoji(String slug, String name) {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('atta') || s.contains('flour') || s.contains('rice') || s.contains('sugar')) return '🌾';
    if (s.contains('dal') || s.contains('pulse') || n.contains('dal')) return '🍲';
    if (s.contains('oil') || s.contains('ghee') || n.contains('oil') || n.contains('ghee')) return '🛢️';
    if (s.contains('masala') || s.contains('spice') || n.contains('masala')) return '🌶️';
    if (s.contains('tea') || s.contains('coffee') || s.contains('chai')) return '☕';
    if (s.contains('cookie') || s.contains('biscuit') || n.contains('cookie')) return '🍪';
    if (s.contains('namkeen') || s.contains('snack') || n.contains('namkeen')) return '🥨';
    if (s.contains('sauce') || s.contains('spread') || s.contains('ketchup')) return '🍅';
    if (s.contains('noodle') || s.contains('pasta') || s.contains('instant')) return '🍜';
    if (s.contains('dry') || s.contains('nut') || s.contains('cashew') || s.contains('almond')) return '🥜';
    if (s.contains('choco') || s.contains('sweet')) return '🍫';
    if (s.contains('bakery') || s.contains('bread') || s.contains('rusk')) return '🍞';
    if (s.contains('laund') || s.contains('detergent')) return '🧼';
    if (s.contains('dish') || s.contains('scrub')) return '🧽';
    if (s.contains('oral') || s.contains('dental') || s.contains('toothpaste')) return '🪥';
    if (s.contains('hair') || s.contains('shampoo') || s.contains('oil')) return '🧴';
    if (s.contains('fruit')) return '🍎';
    if (s.contains('veg')) return '🥦';
    return '🛍️';
  }

  static String _getSubcategorySubtitle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('atta') || lower.contains('flour') || lower.contains('rice')) return 'Aashirvaad, Fortune atta, basmati & grains';
    if (lower.contains('dal') || lower.contains('pulse')) return 'Toor, moong, chana & unpolished dals';
    if (lower.contains('oil') || lower.contains('ghee')) return 'Refined, mustard oil & Amul pure ghee';
    if (lower.contains('masala') || lower.contains('spice')) return 'Catch, Everest & MDH blended spices';
    if (lower.contains('tea') || lower.contains('coffee') || lower.contains('chai')) return 'Tata Tea Gold, Nescafe & morning brews';
    if (lower.contains('cookie') || lower.contains('biscuit')) return 'Good Day, Parle-G, Oreo & bakery bites';
    if (lower.contains('namkeen') || lower.contains('snack')) return 'Haldiram bhujia, mixture & crunchy munchies';
    if (lower.contains('sauce') || lower.contains('spread')) return 'Kissan ketchup, jams & chocolate spreads';
    if (lower.contains('noodle') || lower.contains('pasta')) return 'Maggi 2-minute, Yippee & quick pasta';
    if (lower.contains('dry') || lower.contains('nut')) return 'Premium almonds, cashews & Afghan raisins';
    if (lower.contains('choco') || lower.contains('sweet')) return 'Dairy Milk Silk, 5 Star & festive chocolates';
    if (lower.contains('bakery') || lower.contains('bread')) return 'Fresh milk breads, pav & tea rusks';
    if (lower.contains('laund') || lower.contains('detergent')) return 'Surf Excel, Ariel & Tide wash powders';
    if (lower.contains('dish')) return 'Vim liquid, bars & dishwash sponges';
    if (lower.contains('oral') || lower.contains('dental')) return 'Colgate, Sensodyne & oral hygiene';
    if (lower.contains('hair')) return 'Head & Shoulders, Dove & hair oils';
    if (lower.contains('fruit')) return 'Fresh farm apples, bananas & seasonal fruits';
    if (lower.contains('veg')) return 'Farm fresh potatoes, onions, tomatoes & greens';
    return 'Top quality grocery essentials in Ghatampur';
  }

  static List<Widget> buildSlivers({
    required BuildContext context,
    required WidgetRef ref,
    required ScrollController scrollController,
    required int visibleGridCount,
    required int selectedFilterIndex,
    required ValueChanged<int> onFilterChanged,
  }) {
    final catalogAsync = ref.watch(homeProductCatalogProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final subcategories = getGrocerySubcategories(categories);

    return catalogAsync.when(
      loading: () => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
            child: _buildInfiniteFeedHeader(
              context: context,
              ref: ref,
              totalCount: 0,
              isLoading: true,
              selectedFilterIndex: selectedFilterIndex,
              subcategories: subcategories,
              onFilterChanged: onFilterChanged,
            ),
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
        final filteredProducts = getFilteredGridProducts(
          all: allProducts,
          categories: categories,
          selectedFilterIndex: selectedFilterIndex,
        );

        final visibleProducts = filteredProducts.take(visibleGridCount).toList();
        final hasMore = visibleGridCount < filteredProducts.length;

        return [
          // Section Title Header with Dynamic Total Count Badge & SUBCATEGORY Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
              child: _buildInfiniteFeedHeader(
                context: context,
                ref: ref,
                totalCount: filteredProducts.length,
                isLoading: false,
                selectedFilterIndex: selectedFilterIndex,
                subcategories: subcategories,
                onFilterChanged: onFilterChanged,
              ),
            ),
          ),

          // Empty State or 2-Column Virtualized Product Grid
          if (filteredProducts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Text('🛍️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        'No products found in this subcategory',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try tapping "All" or picking another aisle above',
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
            )
          else ...[
            // 2-Column Virtualized SliverGrid (Ultra-smooth, native 60/120 FPS)
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
          ],

          // End of Aisle Search & Discovery Prompt Card
          SliverToBoxAdapter(
            child: HomeEndOfAisleSearchCard(scrollController: scrollController),
          ),
        ];
      },
    );
  }

  static Widget _buildInfiniteFeedHeader({
    required BuildContext context,
    required WidgetRef ref,
    required int totalCount,
    required bool isLoading,
    required int selectedFilterIndex,
    required List<Category> subcategories,
    required ValueChanged<int> onFilterChanged,
  }) {
    final currentHub = ref.watch(currentStoreHubProvider);
    final hubCity = currentHub.city.isNotEmpty ? currentHub.city : currentHub.name;
    String title = 'All Groceries & Essentials';
    String subtitle = '⚡ Fast Delivery from $hubCity darkstore';
    IconData icon = Icons.flash_on_rounded;

    if (selectedFilterIndex > 0 && selectedFilterIndex <= subcategories.length) {
      final selectedSub = subcategories[selectedFilterIndex - 1];
      title = selectedSub.name;
      subtitle = _getSubcategorySubtitle(selectedSub.name);
      icon = Icons.grid_view_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Title & Dynamic Count Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: AppDesignSystem.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Horizontal SUBCATEGORY Filter Chips Bar (With [⚡ All] at first!)
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: 1 + subcategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = selectedFilterIndex == index;
              final String label;
              if (index == 0) {
                label = '⚡ All';
              } else {
                final sub = subcategories[index - 1];
                final emoji = _getSubcategoryEmoji(sub.slug, sub.name);
                label = '$emoji ${sub.name}';
              }

              return Bounceable(
                scaleFactor: 0.94,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFilterChanged(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // 3. Dynamic Animated Spotlight Hero Banner (Badi image, pretty animations)
        HomeAisleSpotlightBanner(
          selectedSubcategory: (selectedFilterIndex > 0 && selectedFilterIndex <= subcategories.length)
              ? subcategories[selectedFilterIndex - 1]
              : null,
          totalCount: totalCount,
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
              'Loading next products... ($visibleCount of $totalCount)',
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
}
