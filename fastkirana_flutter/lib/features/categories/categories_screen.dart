import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
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
      'tagline': '100% Farm-Fresh Organic',
      'items': 33,
      'btnColor': AppDesignSystem.emerald600,
      'asset': 'assets/categories/fruits_vegetables_category.webp',
      'webImage': 'https://www.fastkirana.in/fruits-vegetables.png',
    },
    'healthy-foods': {
      'tagline': 'Essential Products',
      'items': 11,
      'btnColor': AppDesignSystem.red600,
      'asset': 'assets/categories/fruits_vegetables_category.webp',
      'webImage': 'https://www.fastkirana.in/healthy-foods.png',
    },
    'kitchen-needs': {
      'tagline': 'Fortune Oil, Atta & Dal',
      'items': 42,
      'btnColor': AppDesignSystem.emerald600,
      'asset': 'assets/categories/atta_rice_dal_category.webp',
      'webImage': 'https://www.fastkirana.in/kitchen-needs.png',
    },
    'atta-rice-dal': {
      'tagline': 'Fortune Oil, Atta & Dal',
      'items': 42,
      'btnColor': AppDesignSystem.emerald600,
      'asset': 'assets/categories/atta_rice_dal_category.webp',
      'webImage': 'https://www.fastkirana.in/kitchen-needs.png',
    },
    'snacks-munchies': {
      'tagline': 'Crisps, Namkeen & Chips',
      'items': 28,
      'btnColor': AppDesignSystem.red600,
      'asset': 'assets/categories/snacks_munchies_category.webp',
      'webImage': 'https://www.fastkirana.in/snacks-munchies.png',
    },
    'beverages': {
      'tagline': 'Cold Drinks & Real Juices',
      'items': 19,
      'btnColor': AppDesignSystem.cyan600,
      'asset': 'assets/categories/beverages_category.webp',
      'webImage': 'https://www.fastkirana.in/beverages.png',
    },
    'ice-cream': {
      'tagline': 'Cool Tubs, Cones & Treats',
      'items': 15,
      'btnColor': AppDesignSystem.red600,
      'asset': 'assets/categories/ice_cream_category.webp',
      'webImage': 'https://www.fastkirana.in/ice-cream.png',
    },
    'chocolates': {
      'tagline': 'Silk, Bars & Confectionery',
      'items': 24,
      'btnColor': AppDesignSystem.violet600,
      'asset': 'assets/categories/bakery_biscuits_category.webp',
      'webImage': 'https://www.fastkirana.in/chocolates.png',
    },
    'bakery': {
      'tagline': 'Fresh Cookies & Rusks',
      'items': 16,
      'btnColor': AppDesignSystem.orange600,
      'asset': 'assets/categories/bakery_biscuits_category.webp',
      'webImage': 'https://www.fastkirana.in/bakery.png',
    },
    'packaged-foods': {
      'tagline': 'Instant Maggi & Ready Meals',
      'items': 18,
      'btnColor': AppDesignSystem.red600,
      'asset': 'assets/categories/snacks_munchies_category.webp',
      'webImage': 'https://www.fastkirana.in/packaged-foods.png',
    },
    'personal-care': {
      'tagline': 'Soaps, Shampoos & Skincare',
      'items': 22,
      'btnColor': AppDesignSystem.teal600,
      'asset': 'assets/categories/personal_care_category.webp',
      'webImage': 'https://www.fastkirana.in/personal-care.png',
    },
    'home-needs-and-cleaning': {
      'tagline': 'Detergents & Home Cleaners',
      'items': 20,
      'btnColor': AppDesignSystem.cyan600,
      'asset': 'assets/categories/household_category.webp',
      'webImage': 'https://www.fastkirana.in/home-cleaning.png',
    },
    'restaurant-food': {
      'tagline': 'Hot Burgers, Rolls & Meals',
      'items': 35,
      'btnColor': AppDesignSystem.orange600,
      'asset': 'assets/categories/cafe_category.webp',
      'webImage': 'https://www.fastkirana.in/restaurant-food.png',
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
      backgroundColor: AppDesignSystem.slate50,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Top Header Banner (Exact Replica from Reference Screenshot)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Breadcrumb + Title + Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Breadcrumb Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.rose50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppDesignSystem.rose100, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'HOME',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.slate600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppDesignSystem.slate400),
                                const SizedBox(width: 4),
                                Text(
                                  'CATEGORIES DIRECTORY',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.rose600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Heading
                          Text(
                            'Shop by Category',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 23),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Explore our curated catalog of groceries\nand hot café treats',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.slate500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Illustration: Grocery Shopping Bag
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/categories/hero_welcome.webp',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/categories/fruits_vegetables_category.webp',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 36))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Search Input Bar (Pill style matching reference)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppDesignSystem.slate200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate400,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.slate400),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppDesignSystem.slate500),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
            ),

            // 3. 2-Column Grid of Beautiful Category Cards
            categoriesAsync.when(
              data: (categories) {
                var filtered = categories.where((c) => c.slug != 'restaurant').toList();
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((c) {
                    return c.name.toLowerCase().contains(_searchQuery) ||
                        c.slug.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔍', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48))),
                          const SizedBox(height: 12),
                          Text(
                            'No categories found',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching with another keyword',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final columns = Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5);
                final aspect = Responsive.categoryCardAspectRatio(context);

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.horizontalPadding(context),
                    0,
                    Responsive.horizontalPadding(context),
                    110,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: aspect,
                      crossAxisSpacing: context.isCompact ? 10 : 14,
                      mainAxisSpacing: context.isCompact ? 10 : 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cat = filtered[index];
                        return _buildReferenceCategoryCard(context, cat);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppDesignSystem.red600),
                ),
              ),
              error: (_, __) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 44, color: AppDesignSystem.red600),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load categories',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.red600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1:1 Replica of Category Card in Screenshot with Ultra-Premium Finish
  Widget _buildReferenceCategoryCard(BuildContext context, Category category) {
    final meta = _categoryMetadata[category.slug] ??
        {
          'tagline': 'Essential Products',
          'items': category.productCount ?? 15,
          'btnColor': AppDesignSystem.red600,
          'asset': 'assets/categories/fruits_vegetables_category.webp',
          'webImage': category.imageUrl ?? 'https://www.fastkirana.in/fruits-vegetables.png',
        };

    final int itemCount = (meta['items'] as int?) ?? (category.productCount ?? 20);
    final Color btnColor = (meta['btnColor'] as Color?) ?? AppDesignSystem.red600;
    final String tagline = (meta['tagline'] as String?) ?? '100% Quality Checked';
    final String assetPath = (meta['asset'] as String?) ?? 'assets/categories/fruits_vegetables_category.webp';
    final String? webUrl = category.imageUrl ?? (meta['webImage'] as String?);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(
            page: CategoryProductsScreen(category: category),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Box with Items Pill
            Expanded(
              child: Container(
                width: double.infinity,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Real Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: webUrl != null && webUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: webUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                            maxWidthDiskCache: 600,
                            maxHeightDiskCache: 600,
                            errorWidget: (_, __, ___) => Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text('🥬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 38))),
                              ),
                            ),
                          )
                        : Image.asset(
                            assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text('🥬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 38))),
                            ),
                          ),
                  ),

                  // Top Left: Items Badge Pill
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 10, color: AppDesignSystem.rose600),
                          const SizedBox(width: 3),
                          Text(
                            '$itemCount ITEMS',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 8.5),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.rose600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            const SizedBox(height: 7),

            // Category Name
            Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: context.isCompact ? 11.5 : 13,
                fontWeight: FontWeight.w900,
                color: category.slug.contains('fruit')
                    ? AppDesignSystem.emerald600
                    : AppDesignSystem.slate900,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1.5),

            // Tagline
            Text(
              tagline,
              style: GoogleFonts.inter(
                fontSize: context.isCompact ? 9 : 10,
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.isCompact ? 5 : 8),

            // Luxury "SHOP NOW" Action Button (Securely Contained Inside Box)
            Container(
              height: context.isCompact ? 28 : 31,
              padding: EdgeInsets.symmetric(horizontal: context.isCompact ? 7 : 10),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SHOP NOW',
                    style: GoogleFonts.inter(
                      fontSize: context.isCompact ? 9 : 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    width: context.isCompact ? 15 : 17,
                    height: context.isCompact ? 15 : 17,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 8.5,
                        color: btnColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
