import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/category.dart';
import '../../../providers/product_provider.dart';
import '../main_shell.dart';
import '../utils/category_visual_helper.dart';
import '../../../core/utils/category_transition_helper.dart';

class HomeTopCategoriesGrid extends ConsumerWidget {
  const HomeTopCategoriesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: categoriesAsync.when(
        data: (categories) {
          // Filter out restaurant/cafe items
          final groceryCategories = categories.where((c) {
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

          // Build unified Blinkit-style category architecture (no 3 separate departments)
          final bento = _buildUnifiedBento(groceryCategories);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Single Unified Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explore by Category',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 18),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
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
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 8.5,
                              color: AppDesignSystem.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Top Hero Row (2 Wide Appetizing Anchors)
                if (bento.heroes.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int h = 0; h < bento.heroes.length; h++) ...[
                        if (h > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _buildHeroCard(
                            context,
                            ref,
                            bento.heroes[h].category,
                            bento.heroes[h].customName,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Compact 4-Column Grid (Symmetric Rows)
                if (bento.compacts.isNotEmpty) ...[
                  _buildCompactGrid(context, ref, bento.compacts),
                ],
              ],
            ),
          );
        },
        loading: () => _buildBentoShimmer(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  // ─── HERO CARD (50% WIDTH, WIDE LUXURY APPETIZING CONTAINER) ───
  Widget _buildHeroCard(
    BuildContext context,
    WidgetRef ref,
    Category cat,
    String? customDisplayName,
  ) {
    final title = customDisplayName ?? cat.name;
    final softBg = CategoryVisualHelper.getSoftColor(cat.slug, cat.name);
    final borderColor = CategoryVisualHelper.getBorderColor(cat.slug, cat.name);
    final accentColor = CategoryVisualHelper.getAccentColor(cat.slug, cat.name);

    return Bounceable(
      scaleFactor: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        CategoryTransitionHelper.pushCategoryWithTransition(context, ref, cat);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Luxury Dual-Tone Hero Container with Smooth Squircle Finish
          Container(
            height: 114,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  softBg,
                  Colors.white.withValues(alpha: 0.95),
                  softBg.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.09),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Subtle Ambient Corner Glow Pod
                Positioned(
                  top: -12,
                  right: -12,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Center(
                    child: Transform.scale(
                      scale: 1.14,
                      child: CategoryVisualHelper.buildAvatarImage(
                        context,
                        cat,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          // 2-Line Centered Title Below Card
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, 12),
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

  // ─── COMPACT GRID (CLEAN SQUIRCLE PODS) ───
  Widget _buildCompactGrid(
    BuildContext context,
    WidgetRef ref,
    List<_CategorySlot> compacts,
  ) {
    final int crossAxisCount = (compacts.length % 3 == 0) ? 3 : 4;
    const double gap = 8.0;

    // Split compacts into rows
    final List<List<_CategorySlot>> rows = [];
    for (int i = 0; i < compacts.length; i += crossAxisCount) {
      final end = (i + crossAxisCount < compacts.length) ? i + crossAxisCount : compacts.length;
      rows.add(compacts.sublist(i, end));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int c = 0; c < crossAxisCount; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                if (c < rows[r].length)
                  Expanded(
                    child: _buildCompactCard(
                      context,
                      ref,
                      rows[r][c].category,
                      rows[r][c].customName,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ─── COMPACT CARD (25% WIDTH, LUXURY SQUIRCLE CONTAINER) ───
  Widget _buildCompactCard(
    BuildContext context,
    WidgetRef ref,
    Category cat,
    String? customDisplayName,
  ) {
    final title = customDisplayName ?? cat.name;
    final softBg = CategoryVisualHelper.getSoftColor(cat.slug, cat.name);
    final borderColor = CategoryVisualHelper.getBorderColor(cat.slug, cat.name);
    final accentColor = CategoryVisualHelper.getAccentColor(cat.slug, cat.name);

    return Bounceable(
      scaleFactor: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        CategoryTransitionHelper.pushCategoryWithTransition(context, ref, cat);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Luxury Soft-Gradient Squircle Container
          Container(
            height: 86,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  softBg,
                  Colors.white,
                ],
                stops: const [0.0, 0.8],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.85),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ambient corner aura
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Center(
                    child: Transform.scale(
                      scale: 1.14,
                      child: CategoryVisualHelper.buildAvatarImage(
                        context,
                        cat,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2-Line Centered Label Below Card (Truncation-Free)
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                title,
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

  // ─── SHIMMER SKELETON ───
  Widget _buildBentoShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: AppDesignSystem.border,
        highlightColor: AppDesignSystem.gray50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 18, width: 160, color: Colors.white),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 102,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 102,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int r = 0; r < 3; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(
                children: [
                  for (int c = 0; c < 4; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── UNIFIED BENTO ARCHITECTURE (DYNAMIC, RESILIENT & BEAUTIFUL) ───
  static String _formatSlotTitle(String rawName) {
    var name = rawName.trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    final lower = name.toLowerCase();
    // Dry fruit check MUST come before generic fruit check
    if (lower.contains('dry fruit') || lower.contains('super food') || lower.contains('superfood') || lower.contains('nut')) return 'Dry Fruits\n& Superfoods';
    if (lower.contains('fruit') || lower.contains('veg')) return 'Fruits &\nVegetables';
    if (lower.contains('dairy') || lower.contains('milk')) return 'Dairy\nProducts';
    if (lower.contains('kitchen') || lower.contains('ration')) return 'Kitchen &\nRation';
    if (lower.contains('cookie') || lower.contains('namkeen')) return 'Cookies &\nNamkeen';
    if (lower.contains('packaged') || lower.contains('instant')) return 'Packaged\nItems';
    if (lower.contains('cake') || lower.contains('choco')) return 'Cakes &\nChocolates';
    if (lower.contains('beverage') || lower.contains('drink')) return 'Beverages\n& Drinks';
    if (lower.contains('ice cream') || lower.contains('dessert')) return 'Ice Cream\n& Desserts';
    if (lower.contains('personal') || lower.contains('hygiene')) return 'Personal Care\n& Hygiene';
    if (lower.contains('household') || lower.contains('clean')) return 'Household\nEssentials';

    if (name.contains('\n')) return name;

    // Smart line balancing for clean 2-line rendering
    if (name.contains(' & ')) {
      final parts = name.split(' & ');
      return '${parts[0]} &\n${parts.sublist(1).join(' & ')}';
    }
    if (name.contains(', ') && name.length > 10) {
      final commaIdx = name.indexOf(', ');
      return '${name.substring(0, commaIdx + 1)}\n${name.substring(commaIdx + 2)}';
    }
    if (name.contains(' ') && name.length > 12) {
      final spaceIdx = name.indexOf(' ');
      return '${name.substring(0, spaceIdx)}\n${name.substring(spaceIdx + 1)}';
    }
    return name;
  }

  _UnifiedBentoData _buildUnifiedBento(List<Category> allCategories) {
    // 1. Strictly filter only ROOT categories (parentId == null or empty)
    final rootCategories = allCategories.where((c) {
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

    rootCategories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final usedIds = <String>{};

    // 2. HEROES (2 Wide High-Demand Anchors: Fresh Produce & Dairy)
    final heroes = <_CategorySlot>[];
    for (final cat in rootCategories) {
      if (cat.id == 'CAT-101' || cat.id == 'CAT-116') {
        usedIds.add(cat.id);
        heroes.add(_CategorySlot(
          category: cat,
          customName: _formatSlotTitle(cat.name),
        ));
      }
    }
    // Fallback heroes if veg or dairy were not matched by ID
    if (heroes.length < 2) {
      for (final cat in rootCategories) {
        if (!usedIds.contains(cat.id)) {
          usedIds.add(cat.id);
          heroes.add(_CategorySlot(
            category: cat,
            customName: _formatSlotTitle(cat.name),
          ));
          if (heroes.length == 2) break;
        }
      }
    }

    // 3. COMPACT PODS (All remaining 9 ROOT categories only - ZERO subcategories!)
    final compacts = <_CategorySlot>[];
    for (final cat in rootCategories) {
      if (!usedIds.contains(cat.id)) {
        usedIds.add(cat.id);
        compacts.add(_CategorySlot(
          category: cat,
          customName: _formatSlotTitle(cat.name),
        ));
      }
    }

    return _UnifiedBentoData(
      heroes: heroes,
      compacts: compacts,
    );
  }
}

// ─── INTERNAL HELPER MODELS ───
class _CategorySlot {
  final Category category;
  final String? customName;

  const _CategorySlot({required this.category, this.customName});
}

class _UnifiedBentoData {
  final List<_CategorySlot> heroes;
  final List<_CategorySlot> compacts;

  const _UnifiedBentoData({
    required this.heroes,
    required this.compacts,
  });
}
