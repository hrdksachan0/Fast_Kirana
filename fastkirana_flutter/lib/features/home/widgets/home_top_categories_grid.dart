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

class HomeTopCategoriesGrid extends ConsumerStatefulWidget {
  const HomeTopCategoriesGrid({super.key});

  @override
  ConsumerState<HomeTopCategoriesGrid> createState() => _HomeTopCategoriesGridState();
}

class _HomeTopCategoriesGridState extends ConsumerState<HomeTopCategoriesGrid> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
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
                        fontSize: Responsive.scaledFontSize(context, 17.5),
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
                    ref.read(selectedTabProvider.notifier).state = 2; // Switch to Categories tab
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
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
          const SizedBox(height: 12),

          // ─── 2. 4-COLUMN BENTO GRID (ZERO HORIZONTAL SLIDING) ───
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

              // Top 8 categories displayed upfront (2 rows of 4). Expandable if more exist.
              final displayedCategories = (_isExpanded || groceryCategories.length <= 8)
                  ? groceryCategories
                  : groceryCategories.take(8).toList();

              // Chunk into rows of 4
              const int crossAxisCount = 4;
              final List<List<Category>> rows = [];
              for (int i = 0; i < displayedCategories.length; i += crossAxisCount) {
                final end = (i + crossAxisCount < displayedCategories.length)
                    ? i + crossAxisCount
                    : displayedCategories.length;
                rows.add(displayedCategories.sublist(i, end));
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    const double horizontalGap = 8.0;
                    final itemWidth =
                        (availableWidth - (crossAxisCount - 1) * horizontalGap) / crossAxisCount;
                    final podSize = (itemWidth - 4).clamp(66.0, 74.0);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated smooth expansion/collapse
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                                if (rowIndex > 0) const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (int colIndex = 0; colIndex < crossAxisCount; colIndex++) ...[
                                      if (colIndex > 0) const SizedBox(width: horizontalGap),
                                      if (colIndex < rows[rowIndex].length)
                                        Expanded(
                                          child: _buildCategoryGridTile(
                                            context,
                                            rows[rowIndex][colIndex],
                                            podSize,
                                          ),
                                        )
                                      else
                                        const Expanded(child: SizedBox.shrink()),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Expand / Collapse Pill Button (if more than 8 categories exist)
                        if (groceryCategories.length > 8) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Bounceable(
                              scaleFactor: 0.96,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isExpanded = !_isExpanded;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isExpanded
                                          ? 'Show Less'
                                          : 'See ${groceryCategories.length - 8} More Categories',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 15,
                                      color: AppDesignSystem.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Shimmer.fromColors(
                baseColor: AppDesignSystem.border,
                highlightColor: AppDesignSystem.gray50,
                child: Column(
                  children: [
                    for (int row = 0; row < 2; row++) ...[
                      if (row > 0) const SizedBox(height: 12),
                      Row(
                        children: [
                          for (int col = 0; col < 4; col++) ...[
                            if (col > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 10,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGridTile(BuildContext context, Category cat, double podSize) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 3. PREMIUM TACTILE GLASS POD ───
          Container(
            width: podSize,
            height: podSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(podSize * 0.28),
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 9,
                  offset: const Offset(0, 3.5),
                ),
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
                // Rounded Category Visual
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(podSize * 0.22),
                    child: CategoryVisualHelper.buildAvatarImage(context, cat),
                  ),
                ),

                // Tactile Glossy Sheen Highlight
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(podSize * 0.26),
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
            height: 29,
            child: Center(
              child: Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, 11),
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
    );
  }
}
