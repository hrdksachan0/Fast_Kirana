import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/product_card.dart';
import '../../categories/category_products_screen.dart';

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
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
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: CategoryProductsScreen(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL ($totalCount)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.red600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 2.5),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.red600),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dynamic Soft Squircle Subcategory Visual Tiles (Diwali / Zepto Edition Reference)
          if (childSubcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                ),
              ),
              child: SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 16, bottom: 6),
                  itemCount: childSubcategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final isSelected = isAll
                        ? activeSubcatId == 'all'
                        : activeSubcatId == childSubcategories[index - 1].id;
                    final rawTitle = isAll ? 'All' : childSubcategories[index - 1].name;
                    final title = isAll ? 'All' : _formatSubcatTitle(rawTitle);
                    final imageUrl = isAll ? '' : (childSubcategories[index - 1].imageUrl ?? '');
                    final emoji = isAll ? '' : _getSubcatEmoji(rawTitle);

                    return Bounceable(
                      scaleFactor: 0.94,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategorySubcat[cat.id] = isAll ? 'all' : childSubcategories[index - 1].id;
                        });
                      },
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Soft Warm Pastel Squircle Card
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF1F2)
                                    : const Color(0xFFFFF8EE),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFE20A22)
                                      : const Color(0xFFFFE8D1),
                                  width: isSelected ? 1.8 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFFE20A22).withValues(alpha: 0.16)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(7),
                              child: isAll
                                  ? Center(
                                      child: Icon(
                                        Icons.dashboard_rounded,
                                        size: 26,
                                        color: isSelected
                                            ? const Color(0xFFE20A22)
                                            : const Color(0xFFB45309),
                                      ),
                                    )
                                  : imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (_, __) => Container(
                                            color: Colors.transparent,
                                          ),
                                          errorWidget: (_, __, ___) => Center(
                                            child: Text(
                                              emoji,
                                              style: const TextStyle(fontSize: 26),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(fontSize: 26),
                                          ),
                                        ),
                            ),

                            const SizedBox(height: 5),

                            // 2. Title Label (Centered 2-line max)
                            SizedBox(
                              height: 26,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                  color: isSelected ? const Color(0xFFE20A22) : const Color(0xFF334155),
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // 3. Active Indicator Pill
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              height: 2.5,
                              width: isSelected ? 22 : 0,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE20A22) : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
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
          ],
          const SizedBox(height: 12),
          if (displayProducts.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppDesignSystem.gray50,
                borderRadius: BorderRadius.circular(16),
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
          else
            AnimationLimiter(
              child: SizedBox(
                height: Responsive.productShelfHeight(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(right: Responsive.horizontalPadding(context)),
                  itemCount: shelfItemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index < displayProducts.length) {
                      final product = displayProducts[index];
                      final cardWidth = Responsive.productCardShelfWidth(context);
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          horizontalOffset: 40.0,
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
                        Navigator.push(
                          context,
                          FadeSlideRoute(
                            page: CategoryProductsScreen(category: cat),
                          ),
                        );
                      },
                      child: Container(
                        width: 96,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.gray50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.border, width: 1.0),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppDesignSystem.statusCancelled,
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
        ],
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
