import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/category.dart';
import '../../providers/product_provider.dart';
import 'category_products_screen.dart';
import '../../widgets/voice_search_sheet.dart';
import '../home/utils/category_visual_helper.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _priorityParentOrder = [
    'CAT-101', // 🍎 Fruits & Vegetables
    'CAT-116', // 🥛 Dairy Products
    'CAT-113', // 🌾 Kitchen & Ration
    'CAT-104', // 📦 Packaged Items
    'SUB-115-01', // 🍪 Cookies & Namkeen
    'CAT-114', // 🥜 Dry Fruits & Super Foods
    'CAT-115', // 🍫 Cakes & Chocolates
    'CAT-108', // 🥤 Beverages & Drinks
    'CAT-105', // 🍦 Ice Cream & Desserts
    'CAT-109', // 🧴 Personal Care & Hygiene
    'CAT-107', // 🧹 Household Essentials
  ];

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
                          // Speed Pill & Breadcrumb
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  'FAST DELIVERY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Heading
                          Text(
                            'Shop by Category',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 23),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Fresh groceries delivered fast\nfrom your local Ghatampur darkstore',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.slate500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Illustration: Authentic Grocery Delivery Packshot
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
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
                        child: CachedNetworkImage(
                          imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789046038149-zj8z8q.jpg',
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          memCacheHeight: 300,
                          placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                          errorWidget: (_, __, ___) => const Center(
                            child: Text('🛍️', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Search Input Bar (Pill style matching modern aesthetic)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _searchQuery.isNotEmpty ? AppDesignSystem.primary : const Color(0xFFE2E8F0),
                      width: _searchQuery.isNotEmpty ? 1.4 : 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      if (_searchQuery.isNotEmpty)
                        BoxShadow(
                          color: AppDesignSystem.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Circular lens badge
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _searchQuery.isNotEmpty
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: _searchQuery.isNotEmpty
                              ? AppDesignSystem.primary
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Search text input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          cursorColor: AppDesignSystem.primary,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search categories or products...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),

                      // Clear or Voice Search
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 16,
                              width: 1,
                              color: const Color(0xFFE2E8F0),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                VoiceSearchSheet.show(
                                  context,
                                  onResult: (voiceText) {
                                    if (voiceText.trim().isNotEmpty) {
                                      setState(() {
                                        _searchController.text = voiceText.trim();
                                        _searchQuery = voiceText.trim().toLowerCase();
                                      });
                                    }
                                  },
                                );
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
                                  size: 15,
                                  color: AppDesignSystem.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. 2-Column Grid of 11 Beautiful Parent Category Cards
            categoriesAsync.when(
              data: (categories) {
                // Remove restaurant/cafe food categories
                final groceryCategories = categories.where((c) {
                  final slug = c.slug.toLowerCase().trim();
                  final name = c.name.toLowerCase().trim();
                  if (slug == 'restaurant' ||
                      slug == 'restaurant-food' ||
                      slug == 'fast-food-kitchen' ||
                      slug == 'cafe' ||
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

                // STRICT RULE: CategoriesScreen only renders the 11 Top-Level Parent Categories.
                // Subcategories are accessed inside CategoryProductsScreen as horizontal tabs.
                final parentCategories = groceryCategories.where((c) {
                  return c.parentId == null || c.parentId!.isEmpty;
                }).toList();

                // Sort in exact priority order specified for quick-commerce navigation
                parentCategories.sort((a, b) {
                  final aIdx = _priorityParentOrder.indexOf(a.id);
                  final bIdx = _priorityParentOrder.indexOf(b.id);
                  if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
                  if (aIdx != -1) return -1;
                  if (bIdx != -1) return 1;
                  return a.sortOrder.compareTo(b.sortOrder);
                });

                List<Category> filtered;

                if (_searchQuery.isNotEmpty) {
                  filtered = parentCategories.where((c) {
                    final matchName = c.name.toLowerCase().contains(_searchQuery) ||
                        c.slug.toLowerCase().contains(_searchQuery);
                    final matchChild = groceryCategories.any((sub) =>
                        sub.parentId == c.id &&
                        (sub.name.toLowerCase().contains(_searchQuery) || sub.slug.toLowerCase().contains(_searchQuery)));
                    return matchName || matchChild;
                  }).toList();
                } else {
                  filtered = parentCategories;
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
                            'Try selecting another filter or searching with another keyword',
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

  // 1:1 Replica of Category Card with 100% Dynamic Data & Realistic Photography
  Widget _buildReferenceCategoryCard(BuildContext context, Category category) {
    final int itemCount = category.productCount ?? 0;
    final Color btnColor = CategoryVisualHelper.getDynamicButtonColor(category);
    final String tagline = CategoryVisualHelper.getDynamicTagline(category);
    final String resolvedWebUrl = CategoryVisualHelper.resolveRealisticImageUrl(category);

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
                  // Real High-Definition Photographic Packshot
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: resolvedWebUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                      maxWidthDiskCache: 600,
                      maxHeightDiskCache: 600,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFF8FAFC),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppDesignSystem.primary,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFF8FAFC),
                        child: Center(
                          child: Text(
                            category.name.isNotEmpty
                                ? category.name.characters.first.toUpperCase()
                                : '🛍️',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 26),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.primary,
                            ),
                          ),
                        ),
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
                            itemCount > 0 ? '$itemCount ITEMS' : 'IN STOCK',
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

            // Category Name (Truncation-Free 2-line box)
            SizedBox(
              height: context.isCompact ? 28 : 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  category.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: context.isCompact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: category.slug.contains('fruit')
                        ? AppDesignSystem.emerald600
                        : AppDesignSystem.slate900,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Tagline
            Text(
              tagline,
              style: GoogleFonts.plusJakartaSans(
                fontSize: context.isCompact ? 8.5 : 9.5,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.slate500,
                letterSpacing: -0.15,
              ),
              maxLines: 1,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.isCompact ? 6 : 8),

            // Luxury "SHOP NOW" Action Button (Securely Contained Inside Box)
            Container(
              height: context.isCompact ? 28 : 31,
              padding: EdgeInsets.symmetric(horizontal: context.isCompact ? 8 : 11),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withValues(alpha: 0.25),
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: context.isCompact ? 9 : 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
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
