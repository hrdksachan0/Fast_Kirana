import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/product_card.dart';
import '../../../core/utils/category_transition_helper.dart';

class HomeProductSections extends ConsumerStatefulWidget {
  final int selectedFilterIndex;

  const HomeProductSections({
    super.key,
    this.selectedFilterIndex = 0,
  });

  @override
  ConsumerState<HomeProductSections> createState() => _HomeProductSectionsState();
}

class _HomeProductSectionsState extends ConsumerState<HomeProductSections> {
  final Map<String, String> _selectedCategorySubcat = {};

  String _getCategorySubtitle(String name) {
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

  String _formatSubcatTitle(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('noodle') || lower.contains('pasta') || lower.contains('instant')) return 'Noodles & Pasta';
    if (lower.contains('namkeen') || lower.contains('mixture') || lower.contains('bhujia')) return 'Namkeen';
    if (lower.contains('sauce') || lower.contains('ketchup') || lower.contains('spread') || lower.contains('jam')) return 'Sauces';
    if (lower.contains('breakfast') || lower.contains('cereal') || lower.contains('oats')) return 'Breakfast';
    if (lower.contains('tea') || lower.contains('chai') || lower.contains('coffee')) return 'Tea & Coffee';
    if (lower.contains('oil') || lower.contains('ghee') || lower.contains('mustard')) return 'Oil & Ghee';
    if (lower.contains('atta') || lower.contains('flour') || lower.contains('dal') || lower.contains('pulse')) return 'Atta & Dal';
    if (lower.contains('masala') || lower.contains('spice')) return 'Spices';
    if (lower.contains('choco') || lower.contains('gift')) return 'Chocolates';
    if (lower.contains('diya') || lower.contains('pooja') || lower.contains('candle')) return 'Diyas & Pooja';
    if (lower.contains('dry fruit') || lower.contains('nut')) return 'Dry Fruits';
    return name;
  }

  String _getSubcatEmoji(String name) {
    final l = name.toLowerCase();
    if (l.contains('sweet') || l.contains('mithai') || l.contains('choco')) return '🍬';
    if (l.contains('milk') || l.contains('dairy') || l.contains('dahi') || l.contains('curd')) return '🥛';
    if (l.contains('paneer') || l.contains('cheese') || l.contains('butter')) return '🧀';
    if (l.contains('fruit')) return '🍎';
    if (l.contains('veg')) return '🥦';
    if (l.contains('snack') || l.contains('namkeen') || l.contains('chip')) return '🍿';
    if (l.contains('biscuit') || l.contains('cookie') || l.contains('rusk') || l.contains('bakery')) return '🍪';
    if (l.contains('drink') || l.contains('beverage') || l.contains('juice') || l.contains('soda')) return '🧃';
    if (l.contains('tea') || l.contains('coffee')) return '☕';
    if (l.contains('ice') || l.contains('cream') || l.contains('kulfi')) return '🍦';
    if (l.contains('atta') || l.contains('rice') || l.contains('dal') || l.contains('flour')) return '🌾';
    if (l.contains('oil') || l.contains('ghee')) return '🫒';
    if (l.contains('masala') || l.contains('spice')) return '🌶️';
    if (l.contains('soap') || l.contains('shampoo') || l.contains('care')) return '🧴';
    if (l.contains('clean') || l.contains('detergent')) return '🧼';
    return '✨';
  }

  Widget _buildProductSectionSkeleton(BuildContext context, String title) {
    final cardWidth = Responsive.productCardShelfWidth(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: AppDesignSystem.border,
            highlightColor: AppDesignSystem.gray50,
            child: Container(
              width: cardWidth * 0.6,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: Responsive.productShelfHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: Responsive.horizontalPadding(context)),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => SizedBox(
                width: cardWidth,
                child: ProductCardSkeleton(width: cardWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProductSection(
    BuildContext context,
    Category cat,
    List<Product> allCategoryProducts, {
    List<Category> childSubcategories = const [],
    required int totalCount,
  }) {
    final subtitle = _getCategorySubtitle(cat.name);
    final activeSubcatId = _selectedCategorySubcat[cat.id] ?? 'all';

    List<Product> products = allCategoryProducts;
    if (activeSubcatId != 'all') {
      final selectedSub = childSubcategories.firstWhere(
        (s) => s.id == activeSubcatId,
        orElse: () => childSubcategories.first,
      );

      products = allCategoryProducts.where((p) {
        return isProductInGroceryCategory(p, selectedSub);
      }).toList();
    }

    final displayProducts = products.take(50).toList();
    final bool showSeeAllCard = displayProducts.length >= 4 || totalCount > displayProducts.length;
    final int shelfItemCount = displayProducts.length + (showSeeAllCard ? 1 : 0);

    // Unified Cool Porcelain Mist palette across all aisles (clean Blinkit-minimal, zero rainbow clutter)
    const softBg = Color(0xFFEEF2F6);
    const borderColor = Color(0xFFE2E8F0);
    const accentColor = Color(0xFF475569);
    const headerGradStart = Color(0xFFF8FAFC);
    const headerGradEnd = Color(0xFFEEF2F6);

    final int totalTabs = childSubcategories.length + 1;
    int selectedIdx = 0;
    if (activeSubcatId != 'all') {
      final foundIdx = childSubcategories.indexWhere((s) => s.id == activeSubcatId);
      if (foundIdx >= 0) selectedIdx = foundIdx + 1;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor.withValues(alpha: 0.9), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Soft Tinted Category Header + Connected Liquid Sub-Category Tabs
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
                  padding: EdgeInsets.fromLTRB(
                    13,
                    11,
                    12,
                    childSubcategories.isNotEmpty ? 8 : 11,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 16),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 10.8),
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            CategoryTransitionHelper.pushCategoryWithTransition(
                              context,
                              ref,
                              cat,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.95),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SEE ALL ($totalCount)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.8),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.red600,
                                    letterSpacing: 0.35,
                                  ),
                                ),
                                const SizedBox(width: 2.5),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 9,
                                  color: AppDesignSystem.red600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Animated Connected Liquid Scoop Sub-Category Tabs
                if (childSubcategories.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const double sidePadding = 10.0;
                      final double availableWidth = constraints.maxWidth - (sidePadding * 2);
                      final double tabWidth = totalTabs <= 4
                          ? (availableWidth / totalTabs).clamp(76.0, 128.0)
                          : 86.0;
                      const double tabHeight = 84.0;
                      final double fullWidth = math.max(
                        constraints.maxWidth,
                        sidePadding * 2 + (tabWidth * totalTabs),
                      );
                      final double targetX = sidePadding + (selectedIdx * tabWidth);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: fullWidth,
                          height: tabHeight,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(end: targetX),
                            builder: (context, animX, child) => CustomPaint(
                              painter: _AisleConnectedTabPainter(
                                x: animX,
                                width: tabWidth,
                                radius: 18.0,
                                borderColor: borderColor.withValues(alpha: 0.85),
                                fill: Colors.white,
                                glowColor: accentColor.withValues(alpha: 0.14),
                                lineWidth: 1.15,
                              ),
                              child: child,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                              child: Row(
                                children: [
                                  for (int index = 0; index < totalTabs; index++)
                                    _buildLiquidSubcatTab(
                                      context: context,
                                      catId: cat.id,
                                      isAll: index == 0,
                                      subcat: index == 0 ? null : childSubcategories[index - 1],
                                      isSelected: index == selectedIdx,
                                      tabWidth: tabWidth,
                                      tabHeight: tabHeight,
                                      accentColor: accentColor,
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

          // 3. Seamless White Product Shelf Body with Smooth Sub-Category Switch Animation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: displayProducts.isEmpty
                  ? Container(
                      key: ValueKey('empty_${cat.id}_$activeSubcatId'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.gray50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.borderLight),
                      ),
                      child: Center(
                        child: Text(
                          'No items in this subcategory yet',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : AnimationLimiter(
                      key: ValueKey('shelf_${cat.id}_$activeSubcatId'),
                      child: SizedBox(
                        height: Responsive.productShelfHeight(context),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 12),
                          itemCount: shelfItemCount,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            if (index < displayProducts.length) {
                              final product = displayProducts[index];
                              final cardWidth = Responsive.productCardShelfWidth(context);
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 300),
                                child: SlideAnimation(
                                  horizontalOffset: 24.0,
                                  child: FadeInAnimation(
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: ProductCard(product: product, width: cardWidth),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // "Explore All" End Card
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                CategoryTransitionHelper.pushCategoryWithTransition(
                                  context,
                                  ref,
                                  cat,
                                );
                              },
                              child: Container(
                                width: 96,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: softBg.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor, width: 1.0),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: AppDesignSystem.red600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'See all\n$totalCount items',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10.5),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidSubcatTab({
    required BuildContext context,
    required String catId,
    required bool isAll,
    required Category? subcat,
    required bool isSelected,
    required double tabWidth,
    required double tabHeight,
    required Color accentColor,
  }) {
    final rawTitle = isAll ? 'All' : (subcat?.name ?? '');
    final title = isAll ? 'All' : _formatSubcatTitle(rawTitle);
    final imageUrl = isAll ? '' : (subcat?.imageUrl ?? '');
    final emoji = isAll ? '' : _getSubcatEmoji(rawTitle);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCategorySubcat[catId] = isAll ? 'all' : (subcat?.id ?? 'all');
        });
      },
      child: SizedBox(
        width: tabWidth,
        height: tabHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4, left: 4, right: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                scale: isSelected ? 1.07 : 0.94,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF1F2)
                        : Colors.white.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFDA4AF)
                          : Colors.white.withValues(alpha: 0.95),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.16),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: isAll
                      ? Center(
                          child: Icon(
                            Icons.dashboard_rounded,
                            size: 22,
                            color: isSelected ? const Color(0xFFE11D48) : accentColor,
                          ),
                        )
                      : imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox.shrink(),
                                errorWidget: (_, __, ___) => Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, isSelected ? 10.5 : 10.0),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF334155),
                  height: 1.12,
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(homeProductCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    if (categoriesAsync.valueOrNull == null) {
      return const SizedBox.shrink();
    }
    final categories = categoriesAsync.valueOrNull!;

    final groceryCategories = categories.where((c) {
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        return false;
      }
      final slug = c.slug.toLowerCase().trim();
      final name = c.name.toLowerCase().trim();
      if (slug == 'restaurant-food' ||
          slug == 'restaurant' ||
          slug == 'cafe' ||
          slug == 'fast-food-kitchen' ||
          slug.contains('restaurant') ||
          slug.contains('fastfood')) {
        return false;
      }
      if (name.contains('restaurant kitchen') ||
          name.contains('restaurant') ||
          name.contains('cafe') ||
          name.startsWith('fast food')) {
        return false;
      }
      return true;
    }).toList();
    groceryCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (groceryCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return catalogAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groceryCategories.take(4).map((cat) =>
          _buildProductSectionSkeleton(context, cat.name)
        ).toList(),
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groceryCategories.take(4).map((cat) =>
          _buildProductSectionSkeleton(context, cat.name)
        ).toList(),
      ),
      data: (allProducts) {
        var targetCategories = groceryCategories;
        if (widget.selectedFilterIndex > 0 && widget.selectedFilterIndex <= groceryCategories.length) {
          targetCategories = [groceryCategories[widget.selectedFilterIndex - 1]];
        }

        final sections = <Widget>[];
        for (final cat in targetCategories) {
          final categoryProducts = allProducts
              .where((p) => isProductInGroceryCategory(p, cat))
              .toList();
          if (categoryProducts.isEmpty) continue;
          categoryProducts.sort((a, b) => compareProductsSystematic(a, b));

          final catIdLower = cat.id.toLowerCase().trim();
          final catSlugLower = cat.slug.toLowerCase().trim();
          final childSubcategories = categories.where((c) {
            if (c.parentId == null || c.parentId!.isEmpty) return false;
            final pId = c.parentId!.toLowerCase().trim();
            return pId == catIdLower || pId == catSlugLower;
          }).toList();

          sections.add(
            _buildHorizontalProductSection(
              context,
              cat,
              categoryProducts,
              childSubcategories: childSubcategories,
              totalCount: categoryProducts.length,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        );
      },
    );
  }
}

/// Silky Concave Liquid Scoop Tab Painter for Combined Category + Sub-Category Bento
class _AisleConnectedTabPainter extends CustomPainter {
  final double x;
  final double width;
  final double radius;
  final Color borderColor;
  final Color fill;
  final Color glowColor;
  final double lineWidth;

  const _AisleConnectedTabPainter({
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
    const filletR = 18.0;
    final topR = radius.clamp(16.0, 24.0);
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
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
  bool shouldRepaint(_AisleConnectedTabPainter old) =>
      old.x != x ||
      old.width != width ||
      old.radius != radius ||
      old.borderColor != borderColor ||
      old.fill != fill ||
      old.glowColor != glowColor ||
      old.lineWidth != lineWidth;
}
