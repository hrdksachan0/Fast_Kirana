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
                  _buildCompactGrid(context, bento.compacts),
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

  // ─── HERO CARD (50% WIDTH, WIDE APPETIZING CONTAINER) ───
  Widget _buildHeroCard(
    BuildContext context,
    Category cat,
    String? customDisplayName,
  ) {
    final title = customDisplayName ?? cat.name;

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
          // Soft Clean Card Container (Blinkit / Zepto aesthetic)
          Container(
            height: 98,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Soft slate-100 neutral surface
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CategoryVisualHelper.buildAvatarImage(
                      context,
                      cat,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

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

  // ─── COMPACT GRID (4 COLUMNS, CLEAN SQUIRCLE PODS) ───
  Widget _buildCompactGrid(
    BuildContext context,
    List<_CategorySlot> compacts,
  ) {
    const int crossAxisCount = 4;
    const double gap = 8.0;

    // Split compacts into rows of 4
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

  // ─── COMPACT CARD (25% WIDTH, CLEAN SLATE CONTAINER) ───
  Widget _buildCompactCard(
    BuildContext context,
    Category cat,
    String? customDisplayName,
  ) {
    final title = customDisplayName ?? cat.name;

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
          // Soft Clean Square Container
          Container(
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate-100 neutral surface
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CategoryVisualHelper.buildAvatarImage(
                  context,
                  cat,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 2-Line Centered Label Below Card
          SizedBox(
            height: 29,
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.15,
                  letterSpacing: -0.2,
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
                    height: 98,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 98,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
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

  // ─── UNIFIED BENTO ARCHITECTURE (NO 3-WAY SPLIT, ZERO REDUNDANCY) ───
  _UnifiedBentoData _buildUnifiedBento(List<Category> allCategories) {
    final usedIds = <String>{};

    Category? findCat({required List<String> ids, required List<String> keywords}) {
      // 1. Try exact ID match first
      for (final id in ids) {
        for (final cat in allCategories) {
          if (!usedIds.contains(cat.id) && cat.id.toLowerCase().trim() == id.toLowerCase().trim()) {
            usedIds.add(cat.id);
            return cat;
          }
        }
      }
      // 2. Try slug/name keyword match
      for (final cat in allCategories) {
        if (usedIds.contains(cat.id)) continue;
        final s = cat.slug.toLowerCase().trim();
        final n = cat.name.toLowerCase().trim();
        for (final kw in keywords) {
          if (s.contains(kw) || n.contains(kw)) {
            usedIds.add(cat.id);
            return cat;
          }
        }
      }
      return null;
    }

    void markUsed(List<String> ids) {
      for (final id in ids) {
        for (final cat in allCategories) {
          if (cat.id.toLowerCase().trim() == id.toLowerCase().trim()) {
            usedIds.add(cat.id);
          }
        }
      }
    }

    // ── 1. HEROES (2 Wide Cards) ──
    final vegCat = findCat(ids: ['CAT-101'], keywords: ['fruits-vegetables', 'fruit', 'vegetable']);
    final dairyCat = findCat(ids: ['CAT-116'], keywords: ['dairy-products', 'dairy', 'milk']);
    markUsed(['SUB-101-01', 'SUB-101-02']); // Consume child fruit/veg items

    final heroes = <_CategorySlot>[];
    if (vegCat != null) {
      heroes.add(_CategorySlot(category: vegCat, customName: 'Fruits &\nVegetables'));
    }
    if (dairyCat != null) {
      heroes.add(_CategorySlot(category: dairyCat, customName: 'Dairy, Bread &\nEggs'));
    }

    // ── 2. COMPACT PODS (16 Categories = 4 Clean Rows of 4) ──
    final compacts = <_CategorySlot>[];

    // Row 1: Cooking & Kitchen Staples
    final attaCat = findCat(ids: ['SUB-113-01'], keywords: ['atta-rice-sugar', 'atta', 'flour']);
    if (attaCat != null) {
      compacts.add(_CategorySlot(category: attaCat, customName: 'Atta, Rice\n& Sugar'));
    }
    final dalCat = findCat(ids: ['SUB-113-03'], keywords: ['dals-pulses', 'dal', 'pulse']);
    if (dalCat != null) {
      compacts.add(_CategorySlot(category: dalCat, customName: 'Dals &\nPulses'));
    }
    final oilCat = findCat(ids: ['SUB-113-02'], keywords: ['oils-ghee', 'oil', 'ghee']);
    if (oilCat != null) {
      compacts.add(_CategorySlot(category: oilCat, customName: 'Oils &\nGhee'));
    }
    final masalaCat = findCat(ids: ['SUB-113-04'], keywords: ['spices-masala', 'masala', 'spice']);
    if (masalaCat != null) {
      compacts.add(_CategorySlot(category: masalaCat, customName: 'Spices &\nMasala'));
    }

    // Row 2: Daily Sips, Dry Fruits & Cold Treats
    final dryFruitCat = findCat(ids: ['SUB-114-02', 'CAT-114'], keywords: ['dry-fruits', 'dry fruit', 'nuts']);
    if (dryFruitCat != null) {
      compacts.add(_CategorySlot(category: dryFruitCat, customName: 'Dry Fruits\n& Nuts'));
    }
    markUsed(['CAT-114']);
    final teaCat = findCat(ids: ['SUB-113-05'], keywords: ['tea-coffee-salt', 'tea', 'coffee', 'chai']);
    if (teaCat != null) {
      compacts.add(_CategorySlot(category: teaCat, customName: 'Tea, Coffee\n& More'));
    }
    final drinksCat = findCat(ids: ['CAT-108'], keywords: ['beverages', 'beverage', 'drink', 'cold']);
    if (drinksCat != null) {
      compacts.add(_CategorySlot(category: drinksCat, customName: 'Cold Drinks\n& Juices'));
    }
    final iceCreamCat = findCat(ids: ['CAT-105'], keywords: ['ice-cream', 'ice cream', 'dessert']);
    if (iceCreamCat != null) {
      compacts.add(_CategorySlot(category: iceCreamCat, customName: 'Ice Creams\n& More'));
    }

    // Row 3: Snacks, Sweets & Bakery
    final sauceCat = findCat(ids: ['SUB-104-01'], keywords: ['sauces-spreads', 'sauce', 'spread', 'ketchup']);
    if (sauceCat != null) {
      compacts.add(_CategorySlot(category: sauceCat, customName: 'Sauces &\nSpreads'));
    }
    final chocoCat = findCat(ids: ['SUB-115-03'], keywords: ['chocolates-sweets', 'chocolate', 'choco', 'sweet']);
    if (chocoCat != null) {
      compacts.add(_CategorySlot(category: chocoCat, customName: 'Chocolates\n& Sweets'));
    }
    final namkeenCat = findCat(ids: ['SUB-SUB-115-01-02'], keywords: ['namkeen', 'munch', 'snack', 'chips']);
    if (namkeenCat != null) {
      compacts.add(_CategorySlot(category: namkeenCat, customName: 'Munchies &\nNamkeen'));
    }
    final cookieCat = findCat(ids: ['SUB-SUB-115-01-01', 'SUB-115-01'], keywords: ['cookies', 'biscuit', 'bakery']);
    if (cookieCat != null) {
      compacts.add(_CategorySlot(category: cookieCat, customName: 'Biscuits &\nCookies'));
    }
    markUsed(['CAT-115', 'SUB-115-01', 'SUB-115-04', 'CAT-113', 'CAT-104', 'SUB-104-02']);

    // Row 4: Home & Personal Care Essentials
    final laundryCat = findCat(ids: ['SUB-107-03'], keywords: ['laundary-care', 'laundry', 'detergent']);
    if (laundryCat != null) {
      compacts.add(_CategorySlot(category: laundryCat, customName: 'Laundry\nCare'));
    }
    final dishwashCat = findCat(ids: ['SUB-107-01'], keywords: ['dishwashing', 'dish']);
    if (dishwashCat != null) {
      compacts.add(_CategorySlot(category: dishwashCat, customName: 'Dishwashing'));
    }
    final oralCat = findCat(ids: ['SUB-109-02'], keywords: ['oral-care-hygeine', 'oral', 'dental']);
    if (oralCat != null) {
      compacts.add(_CategorySlot(category: oralCat, customName: 'Oral Care &\nHygiene'));
    }
    final hairCat = findCat(ids: ['SUB-109-01', 'CAT-109'], keywords: ['hair-care-cosmetics', 'personal-care']);
    if (hairCat != null) {
      compacts.add(_CategorySlot(category: hairCat, customName: 'Hair Care &\nCosmetics'));
    }
    markUsed(['CAT-107', 'CAT-109', 'SUB-107-02', 'SUB-107-04']);

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
