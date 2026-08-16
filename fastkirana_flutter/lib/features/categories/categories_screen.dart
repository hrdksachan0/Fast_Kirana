import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Synchronized with Web constants.ts and database slugs
  static const Map<String, Map<String, dynamic>> _categoryMetadata = {
    'fruits-vegetables': {
      'emoji': '🥦',
      'tagline': '100% Farm-Fresh Organic',
      'badge': 'Farm Direct',
      'badgeIcon': '🌿',
      'badgeBg': Color(0xFFDCFCE7),
      'badgeText': Color(0xFF15803D),
      'asset': 'assets/categories/fruits_vegetables_category.png',
      'subcats': ['Fresh Vegetables', 'Fresh Fruits', 'Leafy Herbs'],
    },
    'dairy-breakfast': {
      'emoji': '🥛',
      'tagline': 'Chilled Dairy, Bread & Breakfast',
      'badge': 'Fresh Daily',
      'badgeIcon': '✨',
      'badgeBg': Color(0xFFEFF6FF),
      'badgeText': Color(0xFF1D4ED8),
      'asset': 'assets/categories/dairy_breakfast_category.png',
      'subcats': ['Milk & Curd', 'Cheese & Paneer', 'Bread & Butter'],
    },
    'dairy-bread-eggs': {
      'emoji': '🥛',
      'tagline': 'Chilled Dairy, Bread & Breakfast',
      'badge': 'Fresh Daily',
      'badgeIcon': '✨',
      'badgeBg': Color(0xFFEFF6FF),
      'badgeText': Color(0xFF1D4ED8),
      'asset': 'assets/categories/dairy_breakfast_category.png',
      'subcats': ['Milk & Curd', 'Cheese & Paneer', 'Bread & Butter'],
    },
    'snacks-munchies': {
      'emoji': '🍿',
      'tagline': 'Crunchy Chips & Namkeen',
      'badge': 'Snack Time',
      'badgeIcon': '⚡',
      'badgeBg': Color(0xFFFFF7ED),
      'badgeText': Color(0xFFC2410C),
      'asset': 'assets/categories/snacks_munchies_category.png',
      'subcats': ['Chips & Crisps', 'Namkeen', 'Biscuits & Cookies'],
    },
    'instant-foods': {
      'emoji': '🍜',
      'tagline': 'Maggi, Noodles & Quick Meals',
      'badge': 'Superfast',
      'badgeIcon': '🔥',
      'badgeBg': Color(0xFFFEF2F2),
      'badgeText': Color(0xFFB91C1C),
      'asset': 'assets/categories/instant_foods_category.png',
      'subcats': ['Maggi & Noodles', 'Pasta', 'Ready to Eat'],
    },
    'bakery-biscuits': {
      'emoji': '🍪',
      'tagline': 'Cakes, Cookies & Toast',
      'badge': 'Fresh Baked',
      'badgeIcon': '🎂',
      'badgeBg': Color(0xFFFAF5FF),
      'badgeText': Color(0xFF7E22CE),
      'asset': 'assets/categories/bakery_biscuits_category.png',
      'subcats': ['Cookies', 'Rusk & Toast', 'Cakes & Muffins'],
    },
    'chocolates': {
      'emoji': '🍫',
      'tagline': 'Sweet Cravings & Chocolates',
      'badge': 'Sweet Treats',
      'badgeIcon': '✨',
      'badgeBg': Color(0xFFFAF5FF),
      'badgeText': Color(0xFF7E22CE),
      'asset': 'assets/categories/bakery_biscuits_category.png',
      'subcats': ['Silk & Bars', 'Candies', 'Gift Boxes'],
    },
    'atta-rice-dal': {
      'emoji': '🌾',
      'tagline': 'Flours, Grains, Oils & Spices',
      'badge': 'Kitchen Staples',
      'badgeIcon': '🧂',
      'badgeBg': Color(0xFFFEFCE8),
      'badgeText': Color(0xFFA16207),
      'asset': 'assets/categories/atta_rice_dal_category.png',
      'subcats': ['Atta & Flours', 'Fortune Oil & Ghee', 'Spices & Salt'],
    },
    'kitchen-needs': {
      'emoji': '🌾',
      'tagline': 'Flours, Grains, Oils & Spices',
      'badge': 'Kitchen Staples',
      'badgeIcon': '🧂',
      'badgeBg': Color(0xFFFEFCE8),
      'badgeText': Color(0xFFA16207),
      'asset': 'assets/categories/atta_rice_dal_category.png',
      'subcats': ['Atta & Flours', 'Fortune Oil & Ghee', 'Spices & Salt'],
    },
    'ice-cream': {
      'emoji': '🍦',
      'tagline': 'Chilled Cones, Tubs & Kulfi',
      'badge': 'Chilled',
      'badgeIcon': '❄️',
      'badgeBg': Color(0xFFF0FDF4),
      'badgeText': Color(0xFF047857),
      'asset': 'assets/categories/ice_cream_category.png',
      'subcats': ['Tubs & Party Packs', 'Cones & Sticks', 'Kulfi'],
    },
    'beverages': {
      'emoji': '🥤',
      'tagline': 'Cold Drinks, Juices & Tea',
      'badge': 'Refreshing',
      'badgeIcon': '🧊',
      'badgeBg': Color(0xFFF0F9FF),
      'badgeText': Color(0xFF0369A1),
      'asset': 'assets/categories/beverages_category.png',
      'subcats': ['Cold Drinks', 'Fruit Juices', 'Tea & Coffee'],
    },
    'household': {
      'emoji': '🧼',
      'tagline': 'Detergents, Cleaners & Care',
      'badge': 'Home Care',
      'badgeIcon': '🏠',
      'badgeBg': Color(0xFFF8FAFC),
      'badgeText': Color(0xFF334155),
      'asset': 'assets/categories/household_category.png',
      'subcats': ['Detergents', 'Dishwash', 'Cleaners'],
    },
    'home-cleaning': {
      'emoji': '🧼',
      'tagline': 'Detergents, Cleaners & Care',
      'badge': 'Home Care',
      'badgeIcon': '🏠',
      'badgeBg': Color(0xFFF8FAFC),
      'badgeText': Color(0xFF334155),
      'asset': 'assets/categories/household_category.png',
      'subcats': ['Detergents', 'Dishwash', 'Cleaners'],
    },
    'personal-care': {
      'emoji': '🧴',
      'tagline': 'Soaps, Shampoos & Skin Care',
      'badge': 'Wellness',
      'badgeIcon': '✨',
      'badgeBg': Color(0xFFF0F9FF),
      'badgeText': Color(0xFF0369A1),
      'asset': 'assets/categories/personal_care_category.png',
      'subcats': ['Soaps & Body Wash', 'Hair Care', 'Oral Care'],
    },
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppDesignSystem.primaryBg,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
              ),
              child: const Icon(Icons.grid_view_rounded, color: AppDesignSystem.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Categories',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Delivered in 10-15 mins',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                border: Border.all(color: AppDesignSystem.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search categories or items...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.textMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppDesignSystem.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // 2. Categories Directory Cards
          Expanded(
            child: RefreshIndicator(
              color: AppDesignSystem.primary,
              onRefresh: () async => ref.invalidate(categoriesProvider),
              child: categoriesAsync.when(
                data: (categories) {
                  var filtered = categories.where((c) => c.slug != 'restaurant').toList();
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((c) {
                      return c.name.toLowerCase().contains(_searchQuery) ||
                          c.slug.toLowerCase().contains(_searchQuery);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'No categories found',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching with a different name',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppDesignSystem.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cat = filtered[index];
                      return _buildCategoryCard(context, cat);
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppDesignSystem.primary),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 44, color: AppDesignSystem.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load categories',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    final meta = _categoryMetadata[category.slug] ??
        {
          'emoji': '🛒',
          'tagline': 'Fresh & Quality Products',
          'badge': '10-Min Fast',
          'badgeIcon': '⚡',
          'badgeBg': const Color(0xFFFFE4E6),
          'badgeText': AppDesignSystem.primary,
          'asset': 'assets/brand/fastkirana_app_icon.png',
          'subcats': <String>['Popular Items', 'Top Deals'],
        };

    final List<String> subcats = (meta['subcats'] as List<String>?) ?? [];
    final count = category.productCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        border: Border.all(color: AppDesignSystem.border),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(category: category),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Badge + Category Name + Image Thumbnail
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Name, Badge & Tagline
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: meta['badgeBg'] as Color? ?? const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(meta['badgeIcon'] as String? ?? '✨', style: const TextStyle(fontSize: 9.5)),
                                const SizedBox(width: 3),
                                Text(
                                  meta['badge'] as String? ?? 'Fast Delivery',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: meta['badgeText'] as Color? ?? AppDesignSystem.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Title + Count
                          Row(
                            children: [
                              Text(
                                category.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                                  ),
                                  child: Text(
                                    '$count Items',
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Tagline
                          Text(
                            meta['tagline'] as String? ?? 'Order now and get it in minutes',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: Category Asset Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                        child: Image.asset(
                          meta['asset'] as String? ?? 'assets/brand/fastkirana_app_icon.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(meta['emoji'] as String? ?? '🛒', style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Subcategories Chips Row
                if (subcats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: subcats.map((subcat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          subcat,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 8),

                // Bottom Row: Explore Category Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Explore Category',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: AppDesignSystem.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
