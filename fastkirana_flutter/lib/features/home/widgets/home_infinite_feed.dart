import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/store_hub_provider.dart';
import '../../../widgets/product_card.dart';
import '../utils/category_visual_helper.dart';
import 'home_end_of_aisle_search_card.dart';

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
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: Builder(
            builder: (context) {
              final columns = Responsive.isTablet(context) ? 4 : 3;
              const hSpacing = 5.0;
              final cardWidth = (MediaQuery.of(context).size.width - 24 - (columns - 1) * hSpacing) / columns;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: (cardWidth * 1.12) + 118.0,
                  crossAxisSpacing: hSpacing,
                  mainAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ProductCardSkeleton(isCompact: true, width: cardWidth);
                  },
                  childCount: 6,
                ),
              );
            },
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
          // Section Title Header with Cool Porcelain Mist Liquid Bento & Slim Super Saver Strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
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
            // 3-Column Virtualized SliverGrid (exact mainAxisExtent = 0px overflow on Moto, OnePlus & Tablet!)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: Builder(
                builder: (context) {
                  final columns = Responsive.isTablet(context) ? 4 : 3;
                  const hSpacing = 5.0;
                  final cardWidth = (MediaQuery.of(context).size.width - 24 - (columns - 1) * hSpacing) / columns;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: (cardWidth * 1.12) + 118.0,
                      crossAxisSpacing: hSpacing,
                      mainAxisSpacing: 6,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = visibleProducts[index];
                        return ProductCard(
                          key: ValueKey('infinite_grid_${product.id}'),
                          product: product,
                          isCompact: true,
                          width: cardWidth,
                        );
                      },
                      childCount: visibleProducts.length,
                    ),
                  );
                },
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
    String subtitle = 'Fresh daily essentials from $hubCity';

    if (selectedFilterIndex > 0 && selectedFilterIndex <= subcategories.length) {
      final selectedSub = subcategories[selectedFilterIndex - 1];
      title = selectedSub.name;
      subtitle = _getSubcategorySubtitle(selectedSub.name);
    }

    final int totalTabs = 1 + subcategories.length;
    final int safeSelectedIdx = selectedFilterIndex.clamp(0, math.max(0, totalTabs - 1));

    const headerGradStart = Color(0xFFF8FAFC);
    const headerGradEnd = Color(0xFFEEF2F6);
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cool Porcelain Mist Top Header + Connected Liquid Subcategory Tabs
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [headerGradStart, headerGradEnd],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 16),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 10.8),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECDD3), width: 1.0),
                          ),
                          child: Text(
                            '$totalCount Items',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Animated Connected Liquid Scoop Filter Tabs
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double sidePadding = 8.0;
                    final double availableWidth = constraints.maxWidth - (sidePadding * 2);
                    final double tabWidth = totalTabs <= 4
                        ? (availableWidth / totalTabs).clamp(74.0, 120.0)
                        : 82.0;
                    const double tabHeight = 82.0;
                    final double fullWidth = math.max(
                      constraints.maxWidth,
                      sidePadding * 2 + (tabWidth * totalTabs),
                    );
                    final double targetX = sidePadding + (safeSelectedIdx * tabWidth);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: fullWidth,
                        height: tabHeight,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(end: targetX),
                          builder: (context, animX, child) => CustomPaint(
                            painter: _InfiniteFeedLiquidTabPainter(
                              x: animX,
                              width: tabWidth,
                              radius: 17.0,
                              borderColor: borderColor,
                              fill: Colors.white,
                              glowColor: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              lineWidth: 1.15,
                            ),
                            child: child,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                            child: Row(
                              children: [
                                for (int index = 0; index < totalTabs; index++)
                                  _buildLiquidFilterTab(
                                    context: context,
                                    isAll: index == 0,
                                    sub: index == 0 ? null : subcategories[index - 1],
                                    isSelected: safeSelectedIdx == index,
                                    tabWidth: tabWidth,
                                    tabHeight: tabHeight,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      onFilterChanged(index);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. Slim Animated Silk-Sheen Super Saver Strip + Breathing Live 10–15 min Pill
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: _SilkSheenSuperSaverStrip(hubCity: hubCity),
          ),
        ],
      ),
    );
  }

  static Widget _buildLiquidFilterTab({
    required BuildContext context,
    required bool isAll,
    required Category? sub,
    required bool isSelected,
    required double tabWidth,
    required double tabHeight,
    required VoidCallback onTap,
  }) {
    final String label = isAll ? 'All Items' : (sub?.name ?? '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: tabWidth,
        height: tabHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4, left: 3, right: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: isSelected ? 1.06 : 0.94,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF1F2)
                        : Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFDA4AF)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.14),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isAll
                      ? Center(
                          child: Icon(
                            Icons.flash_on_rounded,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF475569),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: CategoryVisualHelper.buildAvatarImage(
                            context,
                            sub!,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, isSelected ? 10.0 : 9.6),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF475569),
                  height: 1.12,
                ),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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

/// Silky Concave Liquid Scoop Tab Painter for All Groceries & Essentials Bento
class _InfiniteFeedLiquidTabPainter extends CustomPainter {
  final double x;
  final double width;
  final double radius;
  final Color borderColor;
  final Color fill;
  final Color glowColor;
  final double lineWidth;

  const _InfiniteFeedLiquidTabPainter({
    required this.x,
    required this.width,
    required this.radius,
    required this.borderColor,
    required this.fill,
    required this.glowColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height;
    const filletR = 16.0;
    final topR = radius.clamp(15.0, 22.0);
    const top = 3.0;
    const k = 0.58;
    const invK = 1.0 - k;

    final tabLeft = x;
    final tabRight = x + width;

    final path = Path();
    path.moveTo(0, bottom);

    final effectiveLeftFillet = math.min(filletR, tabLeft).clamp(6.0, filletR);
    final leftScoopStartX = math.max(0.0, tabLeft - effectiveLeftFillet);
    if (leftScoopStartX > 0) {
      path.lineTo(leftScoopStartX, bottom);
    }

    path.cubicTo(
      leftScoopStartX + (effectiveLeftFillet * k),
      bottom,
      tabLeft,
      (bottom - effectiveLeftFillet) + (effectiveLeftFillet * invK),
      tabLeft,
      bottom - effectiveLeftFillet,
    );

    path.lineTo(tabLeft, top + topR);
    path.cubicTo(
      tabLeft,
      top + (topR * invK),
      tabLeft + (topR * invK),
      top,
      tabLeft + topR,
      top,
    );

    path.lineTo(tabRight - topR, top);
    path.cubicTo(
      tabRight - (topR * invK),
      top,
      tabRight,
      top + (topR * invK),
      tabRight,
      top + topR,
    );

    final effectiveRightFillet = math.min(filletR, math.max(6.0, size.width - tabRight));
    final rightScoopEndX = math.min(size.width, tabRight + effectiveRightFillet);

    path.lineTo(tabRight, bottom - effectiveRightFillet);
    path.cubicTo(
      tabRight,
      (bottom - effectiveRightFillet) + (effectiveRightFillet * invK),
      rightScoopEndX - (effectiveRightFillet * k),
      bottom,
      rightScoopEndX,
      bottom,
    );

    path.lineTo(size.width, bottom);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height + 2)
      ..lineTo(0, size.height + 2)
      ..close();

    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, glowPaint);

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_InfiniteFeedLiquidTabPainter old) =>
      old.x != x ||
      old.width != width ||
      old.radius != radius ||
      old.borderColor != borderColor ||
      old.fill != fill ||
      old.glowColor != glowColor ||
      old.lineWidth != lineWidth;
}

/// Lightweight 60fps Silk Glass Sheen + Breathing Live Delivery Pill Strip
class _SilkSheenSuperSaverStrip extends StatefulWidget {
  final String hubCity;
  const _SilkSheenSuperSaverStrip({required this.hubCity});

  @override
  State<_SilkSheenSuperSaverStrip> createState() => _SilkSheenSuperSaverStripState();
}

class _SilkSheenSuperSaverStripState extends State<_SilkSheenSuperSaverStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final double t = _ctrl.value;
          // Diagonal silk sheen sweeps across during the last 38% of the cycle
          final double sheenProgress = t < 0.62 ? -1.0 : ((t - 0.62) / 0.38);
          // Smooth breathing pulse for the emerald live dot
          final double pulse = 0.5 + 0.5 * math.sin(t * math.pi * 4);

          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${widget.hubCity} Super Saver Deals',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 10.8),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25 + 0.4 * pulse),
                                  blurRadius: 3 + 3 * pulse,
                                  spreadRadius: 0.5 + 1.2 * pulse,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Live Stock',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (sheenProgress >= 0.0 && sheenProgress <= 1.0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FractionallySizedBox(
                      alignment: Alignment(-1.6 + (3.2 * sheenProgress), 0),
                      widthFactor: 0.35,
                      child: Transform(
                        transform: Matrix4.skewX(-0.3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.65),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
