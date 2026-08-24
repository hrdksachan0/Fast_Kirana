import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      'tagline': '100% Farm-Fresh Organic',
      'items': 33,
      'btnColor': Color(0xFF059669),
      'asset': 'assets/categories/fruits_vegetables_category.png',
      'webImage': 'https://www.fastkirana.in/fruits-vegetables.png',
    },
    'healthy-foods': {
      'tagline': 'Essential Products',
      'items': 11,
      'btnColor': Color(0xFFDC2626),
      'asset': 'assets/categories/fruits_vegetables_category.png',
      'webImage': 'https://www.fastkirana.in/healthy-foods.png',
    },
    'kitchen-needs': {
      'tagline': 'Fortune Oil, Atta & Dal',
      'items': 42,
      'btnColor': Color(0xFF059669),
      'asset': 'assets/categories/atta_rice_dal_category.png',
      'webImage': 'https://www.fastkirana.in/kitchen-needs.png',
    },
    'atta-rice-dal': {
      'tagline': 'Fortune Oil, Atta & Dal',
      'items': 42,
      'btnColor': Color(0xFF059669),
      'asset': 'assets/categories/atta_rice_dal_category.png',
      'webImage': 'https://www.fastkirana.in/kitchen-needs.png',
    },
    'snacks-munchies': {
      'tagline': 'Crisps, Namkeen & Chips',
      'items': 28,
      'btnColor': Color(0xFFDC2626),
      'asset': 'assets/categories/snacks_munchies_category.png',
      'webImage': 'https://www.fastkirana.in/snacks-munchies.png',
    },
    'beverages': {
      'tagline': 'Cold Drinks & Real Juices',
      'items': 19,
      'btnColor': Color(0xFF0284C7),
      'asset': 'assets/categories/beverages_category.png',
      'webImage': 'https://www.fastkirana.in/beverages.png',
    },
    'ice-cream': {
      'tagline': 'Cool Tubs, Cones & Treats',
      'items': 15,
      'btnColor': Color(0xFFDC2626),
      'asset': 'assets/categories/ice_cream_category.png',
      'webImage': 'https://www.fastkirana.in/ice-cream.png',
    },
    'chocolates': {
      'tagline': 'Silk, Bars & Confectionery',
      'items': 24,
      'btnColor': Color(0xFF7C3AED),
      'asset': 'assets/categories/bakery_biscuits_category.png',
      'webImage': 'https://www.fastkirana.in/chocolates.png',
    },
    'bakery': {
      'tagline': 'Fresh Cookies & Rusks',
      'items': 16,
      'btnColor': Color(0xFFEA580C),
      'asset': 'assets/categories/bakery_biscuits_category.png',
      'webImage': 'https://www.fastkirana.in/bakery.png',
    },
    'packaged-foods': {
      'tagline': 'Instant Maggi & Ready Meals',
      'items': 18,
      'btnColor': Color(0xFFDC2626),
      'asset': 'assets/categories/snacks_munchies_category.png',
      'webImage': 'https://www.fastkirana.in/packaged-foods.png',
    },
    'personal-care': {
      'tagline': 'Soaps, Shampoos & Skincare',
      'items': 22,
      'btnColor': Color(0xFF0D9488),
      'asset': 'assets/categories/personal_care_category.png',
      'webImage': 'https://www.fastkirana.in/personal-care.png',
    },
    'home-needs-and-cleaning': {
      'tagline': 'Detergents & Home Cleaners',
      'items': 20,
      'btnColor': Color(0xFF0284C7),
      'asset': 'assets/categories/household_category.png',
      'webImage': 'https://www.fastkirana.in/home-cleaning.png',
    },
    'restaurant-food': {
      'tagline': 'Hot Burgers, Rolls & Meals',
      'items': 35,
      'btnColor': Color(0xFFEA580C),
      'asset': 'assets/categories/cafe_category.png',
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
      backgroundColor: const Color(0xFFF8FAFC),
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
                              color: const Color(0xFFFDF2F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFCE7F3), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'HOME',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF475569),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  'CATEGORIES DIRECTORY',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFE11D48),
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
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Explore our curated catalog of groceries\nand hot café treats',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
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
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/categories/hero_welcome.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/categories/fruits_vegetables_category.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🛍️', style: TextStyle(fontSize: 36)),
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
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
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
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'No categories found',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching with another keyword',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.74,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
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
                  child: CircularProgressIndicator(color: Color(0xFFDC2626)),
                ),
              ),
              error: (_, __) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 44, color: Color(0xFFDC2626)),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load categories',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
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

  // 1:1 Replica of Category Card in Screenshot
  Widget _buildReferenceCategoryCard(BuildContext context, Category category) {
    final meta = _categoryMetadata[category.slug] ??
        {
          'tagline': 'Essential Products',
          'items': category.productCount ?? 15,
          'btnColor': const Color(0xFFDC2626),
          'asset': 'assets/categories/fruits_vegetables_category.png',
          'webImage': category.imageUrl ?? 'https://www.fastkirana.in/fruits-vegetables.png',
        };

    final int itemCount = (meta['items'] as int?) ?? (category.productCount ?? 20);
    final Color btnColor = (meta['btnColor'] as Color?) ?? const Color(0xFFDC2626);
    final String tagline = (meta['tagline'] as String?) ?? '100% Quality Checked';
    final String assetPath = (meta['asset'] as String?) ?? 'assets/categories/fruits_vegetables_category.png';
    final String? webUrl = category.imageUrl ?? (meta['webImage'] as String?);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryProductsScreen(category: category),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Box with Items Pill
            Container(
              height: 124,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Real Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: webUrl != null && webUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: webUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('🥬', style: TextStyle(fontSize: 38)),
                              ),
                            ),
                          )
                        : Image.asset(
                            assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🥬', style: TextStyle(fontSize: 38)),
                            ),
                          ),
                  ),

                  // Top Left: Items Badge Pill (Exact Replica from Reference)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 10, color: Color(0xFFE11D48)),
                          const SizedBox(width: 3),
                          Text(
                            '$itemCount ITEMS',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE11D48),
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
            const SizedBox(height: 8),

            // Category Name
            Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: category.slug.contains('fruit')
                    ? const Color(0xFF059669)
                    : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Tagline
            Text(
              tagline,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // SHOP NOW Button with Chevron Circle (Exact Replica)
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withOpacity(0.35),
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: btnColor,
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
