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
          // Filter out restaurant/cafe items and 0-product items if applicable
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

          // Organize categories into Departmental Bento Grids (Zepto / Blinkit architecture)
          final sections = _buildBentoSections(groceryCategories);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 22),
                _buildDepartmentSection(context, ref, sections[i]),
              ],
            ],
          );
        },
        loading: () => _buildBentoShimmer(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  // ─── DEPARTMENT SECTION BUILDER ───
  Widget _buildDepartmentSection(
    BuildContext context,
    WidgetRef ref,
    _BentoDepartment department,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                department.title,
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

          // Layout Builder for Adaptive Sizing
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO ROW (2 Wide Cards)
                  if (department.heroCategories.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int h = 0; h < department.heroCategories.length; h++) ...[
                          if (h > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeroCard(
                              context,
                              department.heroCategories[h].category,
                              department.heroCategories[h].customName,
                            ),
                          ),
                        ],
                        // Balance row if only 1 hero exists
                        if (department.heroCategories.length == 1)
                          const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                    if (department.compactCategories.isNotEmpty) const SizedBox(height: 12),
                  ],

                  // 2. COMPACT ROWS (4 Columns Grid)
                  if (department.compactCategories.isNotEmpty) ...[
                    _buildCompactGrid(context, department.compactCategories, availableWidth),
                  ],
                ],
              );
            },
          ),
        ],
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
    double availableWidth,
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
            Container(height: 18, width: 140, color: Colors.white),
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
        ),
      ),
    );
  }

  // ─── BENTO SECTIONS MAPPING (ZEPTO / BLINKIT STANDARDS) ───
  List<_BentoDepartment> _buildBentoSections(List<Category> allCategories) {
    final usedIds = <String>{};

    Category? findCategory(List<String> keywords) {
      for (final cat in allCategories) {
        if (usedIds.contains(cat.id)) continue;
        final s = cat.slug.toLowerCase();
        final n = cat.name.toLowerCase();
        for (final kw in keywords) {
          if (s.contains(kw) || n.contains(kw)) {
            usedIds.add(cat.id);
            return cat;
          }
        }
      }
      return null;
    }

    final sections = <_BentoDepartment>[];

    // ── 1. GROCERY & KITCHEN ──
    final vegCat = findCategory(['fruit', 'veg', 'sabzi']);
    final dairyCat = findCategory(['dairy', 'milk', 'egg', 'bread', 'paneer', 'curd']);
    final kitchenHeroes = <_CategorySlot>[];
    if (vegCat != null) {
      kitchenHeroes.add(_CategorySlot(category: vegCat, customName: 'Fruits &\nVegetables'));
    }
    if (dairyCat != null) {
      kitchenHeroes.add(_CategorySlot(category: dairyCat, customName: 'Dairy, Bread &\nEggs'));
    }

    final kitchenCompacts = <_CategorySlot>[];
    final rationCat = findCategory(['atta', 'rice', 'dal', 'ration', 'flour', 'grain']);
    if (rationCat != null) {
      kitchenCompacts.add(_CategorySlot(category: rationCat, customName: 'Atta, Rice\n& Dals'));
    }
    final oilCat = findCategory(['oil', 'ghee', 'cooking oil', 'edible']);
    if (oilCat != null) {
      kitchenCompacts.add(_CategorySlot(category: oilCat, customName: 'Oils &\nGhee'));
    }
    final masalaCat = findCategory(['masala', 'spice', 'seasoning', 'haldi', 'mirch']);
    if (masalaCat != null) {
      kitchenCompacts.add(_CategorySlot(category: masalaCat, customName: 'Masala &\nSpices'));
    }
    final dryFruitCat = findCategory(['dry-fruit', 'dry fruit', 'nuts', 'super']);
    if (dryFruitCat != null) {
      kitchenCompacts.add(_CategorySlot(category: dryFruitCat, customName: 'Dry Fruits\n& Nuts'));
    }
    final sauceCat = findCategory(['sauce', 'spread', 'ketchup', 'jam', 'honey']);
    if (sauceCat != null) {
      kitchenCompacts.add(_CategorySlot(category: sauceCat, customName: 'Sauces &\nSpreads'));
    }
    final packagedCat = findCategory(['packaged', 'instant', 'maggi', 'noodle', 'ready']);
    if (packagedCat != null) {
      kitchenCompacts.add(_CategorySlot(category: packagedCat, customName: 'Packaged\nFood'));
    }
    final breakfastCat = findCategory(['breakfast', 'cereal', 'oats', 'muesli', 'diet']);
    if (breakfastCat != null) {
      kitchenCompacts.add(_CategorySlot(category: breakfastCat, customName: 'Breakfast\nEssentials'));
    }

    if (kitchenHeroes.isNotEmpty || kitchenCompacts.isNotEmpty) {
      sections.add(
        _BentoDepartment(
          title: 'Grocery & Kitchen',
          heroCategories: kitchenHeroes,
          compactCategories: kitchenCompacts,
        ),
      );
    }

    // ── 2. SNACKS & DRINKS ──
    final snacksHeroes = <_CategorySlot>[];
    final drinksCat = findCategory(['beverage', 'drink', 'cold', 'juice', 'soda', 'soft drink']);
    if (drinksCat != null) {
      snacksHeroes.add(_CategorySlot(category: drinksCat, customName: 'Cold Drinks &\nJuices'));
    }
    final iceCreamCat = findCategory(['ice', 'dessert', 'ice-cream', 'frozen']);
    if (iceCreamCat != null) {
      snacksHeroes.add(_CategorySlot(category: iceCreamCat, customName: 'Ice Creams &\nMore'));
    }

    final snacksCompacts = <_CategorySlot>[];
    final teaCat = findCategory(['tea', 'coffee', 'chai']);
    if (teaCat != null) {
      snacksCompacts.add(_CategorySlot(category: teaCat, customName: 'Tea, Coffee\n& More'));
    }
    final chocoCat = findCategory(['choco', 'sweet', 'cake', 'candy', 'toffee', 'mithai']);
    if (chocoCat != null) {
      snacksCompacts.add(_CategorySlot(category: chocoCat, customName: 'Chocolates\n& Sweets'));
    }
    final munchiesCat = findCategory(['snack', 'munch', 'namkeen', 'chips', 'bhuj']);
    if (munchiesCat != null) {
      snacksCompacts.add(_CategorySlot(category: munchiesCat, customName: 'Munchies &\nChips'));
    }
    final biscuitCat = findCategory(['bakery', 'biscuit', 'cookie', 'rusk']);
    if (biscuitCat != null) {
      snacksCompacts.add(_CategorySlot(category: biscuitCat, customName: 'Biscuits &\nCookies'));
    }

    if (snacksHeroes.isNotEmpty || snacksCompacts.isNotEmpty) {
      sections.add(
        _BentoDepartment(
          title: 'Snacks & Drinks',
          heroCategories: snacksHeroes,
          compactCategories: snacksCompacts,
        ),
      );
    }

    // ── 3. HOUSEHOLD & PERSONAL CARE ──
    // First, explicitly match known household/care categories
    final householdCompacts = <_CategorySlot>[];

    final laundryCat = findCategory(['laundry', 'detergent', 'wash', 'fabric']);
    if (laundryCat != null) {
      householdCompacts.add(_CategorySlot(category: laundryCat, customName: 'Laundry\nCare'));
    }
    final dishwashCat = findCategory(['dishwash', 'dish', 'utensil']);
    if (dishwashCat != null) {
      householdCompacts.add(_CategorySlot(category: dishwashCat, customName: 'Dishwashing'));
    }
    final cleanCat = findCategory(['clean', 'home need', 'household', 'mop', 'broom', 'pest', 'repellent', 'freshener']);
    if (cleanCat != null) {
      householdCompacts.add(_CategorySlot(category: cleanCat, customName: 'Home\nCleaning'));
    }
    final oralCat = findCategory(['oral', 'dental', 'tooth', 'mouth']);
    if (oralCat != null) {
      householdCompacts.add(_CategorySlot(category: oralCat, customName: 'Oral Care\n& Hygiene'));
    }
    final hairCat = findCategory(['hair', 'shampoo', 'cosmetic']);
    if (hairCat != null) {
      householdCompacts.add(_CategorySlot(category: hairCat, customName: 'Hair Care &\nCosmetics'));
    }
    final skinCat = findCategory(['skin', 'body', 'lotion', 'cream', 'face', 'personal']);
    if (skinCat != null) {
      householdCompacts.add(_CategorySlot(category: skinCat, customName: 'Skin &\nBody Care'));
    }
    final babyCat = findCategory(['baby', 'diaper', 'infant', 'child']);
    if (babyCat != null) {
      householdCompacts.add(_CategorySlot(category: babyCat, customName: 'Baby\nCare'));
    }
    final sanitaryCat = findCategory(['sanitary', 'feminine', 'hygiene', 'pad']);
    if (sanitaryCat != null) {
      householdCompacts.add(_CategorySlot(category: sanitaryCat, customName: 'Hygiene\nEssentials'));
    }
    final petCat = findCategory(['pet', 'dog', 'cat food']);
    if (petCat != null) {
      householdCompacts.add(_CategorySlot(category: petCat, customName: 'Pet\nCare'));
    }
    final stationeryCat = findCategory(['stationery', 'office', 'notebook', 'pen']);
    if (stationeryCat != null) {
      householdCompacts.add(_CategorySlot(category: stationeryCat, customName: 'Stationery'));
    }
    final poojaCat = findCategory(['pooja', 'puja', 'agarbatti', 'diya', 'devotion']);
    if (poojaCat != null) {
      householdCompacts.add(_CategorySlot(category: poojaCat, customName: 'Pooja\nEssentials'));
    }

    // Catch any remaining unassigned categories and add them to Household
    final remainingCategories = allCategories.where((c) => !usedIds.contains(c.id)).toList();
    for (final cat in remainingCategories) {
      householdCompacts.add(_CategorySlot(category: cat, customName: null));
    }

    if (householdCompacts.isNotEmpty) {
      sections.add(
        _BentoDepartment(
          title: 'Household & Personal Care',
          heroCategories: const [],
          compactCategories: householdCompacts,
        ),
      );
    }

    return sections;
  }
}

// ─── INTERNAL HELPER MODELS ───
class _CategorySlot {
  final Category category;
  final String? customName;

  const _CategorySlot({required this.category, this.customName});
}

class _BentoDepartment {
  final String title;
  final List<_CategorySlot> heroCategories;
  final List<_CategorySlot> compactCategories;

  const _BentoDepartment({
    required this.title,
    required this.heroCategories,
    required this.compactCategories,
  });
}
