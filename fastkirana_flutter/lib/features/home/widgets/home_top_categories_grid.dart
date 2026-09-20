import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../../categories/category_products_screen.dart';
import '../main_shell.dart';
import '../utils/category_visual_helper.dart';

class HomeTopCategoriesGrid extends ConsumerWidget {
  const HomeTopCategoriesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Explore Categories',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 16.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 10, color: AppDesignSystem.primary),
                          Text(
                            'FAST',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedTabProvider.notifier).state = 2; // Categories tab
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            data: (categories) {
              final groceryCategories = categories.where((c) {
                if (c.parentId != null && c.parentId!.isNotEmpty) return false;
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

              if (groceryCategories.isEmpty) return const SizedBox.shrink();

              final numCols = (groceryCategories.length / 2).ceil();

              return SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: numCols,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (context, colIdx) {
                    final cat1 = groceryCategories[colIdx * 2];
                    final cat2 = (colIdx * 2 + 1 < groceryCategories.length)
                        ? groceryCategories[colIdx * 2 + 1]
                        : null;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCategoryGridTile(context, cat1),
                        const SizedBox(height: 8),
                        if (cat2 != null)
                          _buildCategoryGridTile(context, cat2)
                        else
                          const SizedBox(width: 72, height: 95.5),
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: AppDesignSystem.border,
                  highlightColor: AppDesignSystem.gray50,
                  child: Column(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(height: 10, width: 50, color: Colors.white),
                      const SizedBox(height: 16),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(height: 10, width: 50, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGridTile(BuildContext context, Category cat) {
    final bgTint = CategoryVisualHelper.getSoftColor(cat.slug, cat.name);
    final borderTint = CategoryVisualHelper.getBorderColor(cat.slug, cat.name);

    return Bounceable(
      scaleFactor: 0.93,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    bgTint,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderTint.withValues(alpha: 0.8),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: borderTint.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2.5),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CategoryVisualHelper.buildAvatarImage(context, cat),
                ),
              ),
            ),
            const SizedBox(height: 3.5),
            SizedBox(
              width: 72,
              height: 26,
              child: Center(
                child: Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.15,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
