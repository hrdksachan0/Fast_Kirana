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
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. ELEVATED HEADER ───
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
                        fontSize: Responsive.scaledFontSize(context, 17),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEF2F2), Color(0xFFFFE4E6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 11, color: AppDesignSystem.primary),
                          const SizedBox(width: 2),
                          Text(
                            'FAST',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Bounceable(
                  scaleFactor: 0.95,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedTabProvider.notifier).state = 2; // Categories tab
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
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
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignSystem.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ─── 2. CATEGORIES 2-ROW HORIZONTAL SCROLL ───
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
                if (c.productCount != null) {
                  final anyHasCount = categories.any((cat) => (cat.productCount ?? 0) > 0);
                  if (anyHasCount && (c.productCount ?? 0) == 0) return false;
                }
                return true;
              }).toList();

              if (groceryCategories.isEmpty) return const SizedBox.shrink();

              final numCols = (groceryCategories.length / 2).ceil();

              return SizedBox(
                height: 214,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: numCols,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                          const SizedBox(width: 75, height: 102),
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: AppDesignSystem.border,
                  highlightColor: AppDesignSystem.gray50,
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(height: 10, width: 50, color: Colors.white),
                      const SizedBox(height: 16),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 5),
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
    final gradientColors = CategoryVisualHelper.getGradientColors(cat.slug, cat.name);
    final accentColor = CategoryVisualHelper.getAccentColor(cat.slug, cat.name);

    return Bounceable(
      scaleFactor: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
        );
      },
      child: SizedBox(
        width: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── 3. PREMIUM SOFT POD (Zepto / Blinkit Glass-Pod Aesthetic) ───
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white,
                  width: 1.8,
                ),
                boxShadow: [
                  // Ambient signature glow
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.22),
                    blurRadius: 9,
                    offset: const Offset(0, 3.5),
                  ),
                  // Subtle edge definition
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Clean rounded category visual
                  Padding(
                    padding: const EdgeInsets.all(4.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CategoryVisualHelper.buildAvatarImage(context, cat),
                    ),
                  ),

                  // Tactile Glossy Sheen Highlight (Subtle Apple / Glassmorphic highlight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.03),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            // ─── 4. CRISP LEGIBLE LABEL ───
            SizedBox(
              width: 75,
              height: 28,
              child: Center(
                child: Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    height: 1.18,
                    letterSpacing: -0.2,
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
