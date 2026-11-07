import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';

import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../../widgets/floating_cart_bar.dart';
import '../products/product_detail_screen.dart';

/// Warm Artisanal Bakery Palette
abstract final class BakeryStyle {
  static const cream = Color(0xFFFAF7ED);
  static const shelf = Color(0xFFF2EFE5);
  static const border = Color(0xFFE5DFC9);
  static const espresso = Color(0xFF2C241E);
  static const amber = Color(0xFFB45309);
  static const green = Color(0xFF15803D);
  static const gold = Color(0xFFD97706);
  static const cardBg = Color(0xFFFCFAF4);
}

class _BakeryCategoryTab {
  final String id;
  final String title;
  final String emoji;
  final List<String> matchKeywords;

  const _BakeryCategoryTab({
    required this.id,
    required this.title,
    required this.emoji,
    required this.matchKeywords,
  });
}

const _kBakeryTabs = [
  _BakeryCategoryTab(
    id: 'breads',
    title: 'Breads\n& Loaves',
    emoji: '🍞',
    matchKeywords: ['bread', 'loaf', 'multigrain', 'white bread', 'brown bread', 'garlic bread', 'whole wheat'],
  ),
  _BakeryCategoryTab(
    id: 'pav_buns',
    title: 'Pav, Buns\n& Bases',
    emoji: '🍔',
    matchKeywords: ['pav', 'bun', 'burger bun', 'pizza base', 'kulcha', 'ladi pav'],
  ),
  _BakeryCategoryTab(
    id: 'puffs',
    title: 'Puffs &\nPatties',
    emoji: '🥐',
    matchKeywords: ['puff', 'patty', 'patties', 'croissant', 'samosa', 'roll', 'starter'],
  ),
  _BakeryCategoryTab(
    id: 'rusk_cookies',
    title: 'Cookies\n& Rusks',
    emoji: '🍪',
    matchKeywords: ['rusk', 'toast', 'biscuit', 'cookie', 'cookies', 'elaichi', 'digestive', 'bourbon', 'crunch'],
  ),
  _BakeryCategoryTab(
    id: 'tea_cakes',
    title: 'Tea Cakes\n& Muffins',
    emoji: '🧁',
    matchKeywords: ['muffin', 'brownie', 'tea cake', 'cupcake', 'slice cake', 'fruit cake'],
  ),
];

/// Dedicated Artisanal Bakery Store Screen (Excluding Birthday Cakes)
/// Features European boulangerie shelf aesthetics, arch-style category tabs,
/// real-time cart integration, and zero-drop quick commerce ordering.
class BakeryStoreScreen extends ConsumerStatefulWidget {
  const BakeryStoreScreen({super.key});

  @override
  ConsumerState<BakeryStoreScreen> createState() => _BakeryStoreScreenState();
}

class _BakeryStoreScreenState extends ConsumerState<BakeryStoreScreen> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Set<String> _favourites = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final currentHub = ref.watch(currentStoreHubProvider);
    final storeName = currentHub.city.isNotEmpty ? currentHub.city : currentHub.name;

    final allProductsAsync = ref.watch(productsProvider(null));
    final allProducts = allProductsAsync.valueOrNull ?? [];

    final cartState = ref.watch(cartProvider);
    final cart = cartState.valueOrNull;
    final cartItems = cart?.items ?? [];

    // Filter products for active category tab
    final currentTab = _kBakeryTabs[_selectedTabIndex];
    final tabProducts = _resolveTabProducts(allProducts, currentTab, _searchQuery);

    return Scaffold(
      backgroundColor: BakeryStyle.cream,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header with Search & Location
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: BakeryStyle.cream,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0C000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Column(
                      children: [
                        // Top Nav Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Bounceable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: BakeryStyle.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: BakeryStyle.espresso,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: BakeryStyle.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📍', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    selectedAddress != null
                                        ? selectedAddress.fullAddress
                                        : '$storeName Hub',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: BakeryStyle.espresso,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                '🥐 BAKERY',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Search Field
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BakeryStyle.espresso,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Search for breads, pav, rusks, cookies...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppDesignSystem.slate400,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 20, color: BakeryStyle.amber),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: BakeryStyle.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: BakeryStyle.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: BakeryStyle.amber, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Editorial Artisanal Bakery Hero Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Container(
                    height: 105,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF451A03), // Deep Roasted Oak
                          Color(0xFF78350F), // Toasted Amber
                          Color(0xFF92400E), // Golden Crust
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF78350F).withValues(alpha: 0.20),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Decorative Bakery Motif on Right
                        Positioned(
                          right: -10,
                          bottom: -8,
                          child: Opacity(
                            opacity: 0.18,
                            child: Text(
                              '🥖🥐',
                              style: TextStyle(fontSize: 88, height: 1),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'FRESH BATCH',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF78350F),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• 100% Whole Wheat Options',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFEF3C7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Baked Fresh Every Morning',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Warm crusts, soft pav & tea-time rusks delivered fast',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Arch-Style Animated Category Tabs (Physical Shelf Illusion)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 98,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _kBakeryTabs.length,
                      itemBuilder: (context, i) {
                        final tab = _kBakeryTabs[i];
                        final isSelected = _selectedTabIndex == i;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTabIndex = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 86,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? BakeryStyle.shelf : const Color(0xFFEFE9DB),
                              border: Border.all(
                                color: isSelected ? BakeryStyle.amber : Colors.transparent,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: const Radius.circular(16),
                                bottom: Radius.circular(isSelected ? 0 : 16),
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, -2),
                                  ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tab.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tab.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? BakeryStyle.espresso : const Color(0xFF786B59),
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 4. Horizontal Product Shelf (The physical shelf shelf-illusion)
              SliverToBoxAdapter(
                child: Container(
                  color: BakeryStyle.shelf,
                  padding: const EdgeInsets.only(top: 14, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⭐ Best in ${currentTab.title.replaceAll("\n", " ")}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: BakeryStyle.espresso,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: BakeryStyle.border),
                              ),
                              child: Text(
                                '${tabProducts.length} Items',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: BakeryStyle.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tabProducts.isEmpty)
                        const SizedBox(
                          height: 180,
                          child: Center(
                            child: Text(
                              'No bakery items found in this shelf.\nTry another tab!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black45, fontSize: 12),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 250,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            scrollDirection: Axis.horizontal,
                            itemCount: tabProducts.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final p = tabProducts[idx];
                              final inCartCount = cartItems
                                  .where((i) => i.product.id == p.id)
                                  .fold(0, (sum, i) => sum + i.quantity);

                              return _BakeryProductCard(
                                product: p,
                                inCartCount: inCartCount,
                                isFavourite: _favourites.contains(p.id),
                                onToggleFav: () {
                                  setState(() {
                                    if (!_favourites.add(p.id)) _favourites.remove(p.id);
                                  });
                                },
                                onAdd: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).addProduct(p);
                                },
                                onIncrement: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).increment(p);
                                },
                                onDecrement: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).decrement(p.id);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 5. Section Divider: Full Category Exploration
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 16, color: BakeryStyle.amber),
                      const SizedBox(width: 6),
                      Text(
                        'All ${currentTab.title.replaceAll("\n", " ")}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: BakeryStyle.espresso,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'In Stock • $storeName',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Two-Column Vertical Grid for complete inventory
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = tabProducts[index];
                      final inCartCount = cartItems
                          .where((i) => i.product.id == p.id)
                          .fold(0, (sum, i) => sum + i.quantity);

                      return _BakeryProductCard(
                        product: p,
                        inCartCount: inCartCount,
                        isFavourite: _favourites.contains(p.id),
                        onToggleFav: () {
                          setState(() {
                            if (!_favourites.add(p.id)) _favourites.remove(p.id);
                          });
                        },
                        onAdd: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).addProduct(p);
                        },
                        onIncrement: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).increment(p);
                        },
                        onDecrement: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).decrement(p.id);
                        },
                      );
                    },
                    childCount: tabProducts.length,
                  ),
                ),
              ),
            ],
          ),

          // 7. Floating Luxury Cart Bar
          const FloatingCartBar(bottomOffset: 16),
        ],
      ),
    );
  }

  List<Product> _resolveTabProducts(
    List<Product> allProducts,
    _BakeryCategoryTab tab,
    String query,
  ) {
    // 1. Search Query Filter
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      return allProducts.where((p) {
        final name = p.name.toLowerCase();
        final cat = (p.category?.name ?? '').toLowerCase();
        final tags = p.tags.map((t) => t.toLowerCase()).toList();
        return name.contains(q) || cat.contains(q) || tags.any((t) => t.contains(q));
      }).toList();
    }

    // 2. Tab Filter
    final matched = allProducts.where((p) {
      final name = p.name.toLowerCase();
      final cat = (p.category?.name ?? '').toLowerCase();
      final tags = p.tags.map((t) => t.toLowerCase()).toList();

      // Exclude big birthday/celebration cakes
      final isCake = name.contains('birthday cake') ||
          (name.contains('cake') && !name.contains('tea cake') && !name.contains('rusk') && !name.contains('biscuit') && !name.contains('muffin') && !name.contains('brownie'));
      if (isCake) return false;

      return tab.matchKeywords.any((kw) => name.contains(kw) || cat.contains(kw) || tags.contains(kw));
    }).toList();

    if (matched.isNotEmpty) {
      return matched;
    }

    // Fallback curated items for the tab if specific darkstore inventory is still indexing
    return _getFallbackBakeryItems(tab.id);
  }

  List<Product> _getFallbackBakeryItems(String tabId) {
    switch (tabId) {
      case 'breads':
        return [
          Product(
            id: 'bake-bread-wheat',
            name: '100% Whole Wheat Brown Bread',
            slug: 'brown-bread-400g',
            price: 45,
            mrp: 50,
            discount: 5,
            unit: '400 g',
            stock: 25,
            isAvailable: true,
            tags: ['100% Atta', 'Zero Maida', 'Fresh Today'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-bread-white',
            name: 'Harvest Fresh White Sandwich Bread',
            slug: 'white-bread-400g',
            price: 35,
            mrp: 40,
            discount: 5,
            unit: '400 g',
            stock: 30,
            isAvailable: true,
            tags: ['Super Soft', 'Daily Fresh'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-bread-garlic',
            name: 'Artisan Cheesy Garlic Loaf',
            slug: 'garlic-bread-loaf',
            price: 85,
            mrp: 99,
            discount: 14,
            unit: '250 g',
            stock: 15,
            isAvailable: true,
            tags: ['Herb Infused', 'Bakery Special'],
            minStock: 2,
            imageUrl: 'https://images.unsplash.com/photo-1619895092538-128341789043?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

      case 'pav_buns':
        return [
          Product(
            id: 'bake-pav-ladi',
            name: 'Bombay Ladi Pav (Pack of 6)',
            slug: 'ladi-pav-pack-6',
            price: 25,
            mrp: 30,
            discount: 5,
            unit: '6 pcs',
            stock: 40,
            isAvailable: true,
            tags: ['Ultra Soft', 'Pav Bhaji Special'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-bun-burger',
            name: 'Sesame Seed Burger Buns (Pack of 2)',
            slug: 'burger-buns-pack-2',
            price: 35,
            mrp: 40,
            discount: 5,
            unit: '2 pcs',
            stock: 25,
            isAvailable: true,
            tags: ['Toasted Sesame', 'Fresh Bakes'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-pizza-base',
            name: 'Stone Oven Pizza Base (Pack of 2)',
            slug: 'pizza-base-pack-2',
            price: 45,
            mrp: 50,
            discount: 5,
            unit: '2 pcs',
            stock: 20,
            isAvailable: true,
            tags: ['Thick Crust', 'Easy Bake'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

      case 'puffs':
        return [
          Product(
            id: 'bake-puff-paneer',
            name: 'Crispy Masala Paneer Puff',
            slug: 'paneer-puff',
            price: 35,
            mrp: 40,
            discount: 5,
            unit: '1 pc',
            stock: 20,
            isAvailable: true,
            tags: ['Flaky Pastry', 'Spicy Paneer'],
            minStock: 3,
            imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-puff-aloo',
            name: 'Golden Veg Aloo Patty',
            slug: 'veg-aloo-patty',
            price: 25,
            mrp: 30,
            discount: 5,
            unit: '1 pc',
            stock: 35,
            isAvailable: true,
            tags: ['Tea Snack', 'Classic Masala'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

      case 'rusk_cookies':
        return [
          Product(
            id: 'bake-rusk-suji',
            name: 'Kishna Elaichi Suji Toast (Crispy Rusk)',
            slug: 'kishna-elaichi-rusk',
            price: 40,
            mrp: 40,
            discount: 0,
            unit: '250 g',
            stock: 50,
            isAvailable: true,
            tags: ['Chai Companion', 'Elaichi Infused'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-cookie-butter',
            name: 'Dukes Premium Choco Bourbon Biscuits',
            slug: 'dukes-bourbon-125g',
            price: 36,
            mrp: 36,
            discount: 0,
            unit: '125 g',
            stock: 45,
            isAvailable: true,
            tags: ['Choco Cream', 'Tea Time'],
            minStock: 5,
            imageUrl: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

      case 'tea_cakes':
      default:
        return [
          Product(
            id: 'bake-muffin-choco',
            name: 'Rich Choco Lava Muffin',
            slug: 'choco-lava-muffin',
            price: 49,
            mrp: 60,
            discount: 11,
            unit: '1 pc',
            stock: 20,
            isAvailable: true,
            tags: ['Melted Core', '100% Eggless'],
            minStock: 3,
            imageUrl: 'https://images.unsplash.com/photo-1586985289688-ca3cf47d3e6e?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Product(
            id: 'bake-brownie-walnut',
            name: 'Classic Fudgy Walnut Brownie',
            slug: 'fudgy-walnut-brownie',
            price: 69,
            mrp: 85,
            discount: 16,
            unit: '1 pc',
            stock: 15,
            isAvailable: true,
            tags: ['Dark Chocolate', 'Real Walnuts'],
            minStock: 3,
            imageUrl: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400&q=80',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
    }
  }
}

/// Artisanal Bakery Product Card with Spec Badges & ADD Stepper
class _BakeryProductCard extends StatelessWidget {
  final Product product;
  final int inCartCount;
  final bool isFavourite;
  final VoidCallback onToggleFav;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BakeryProductCard({
    required this.product,
    required this.inCartCount,
    required this.isFavourite,
    required this.onToggleFav,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercent = product.mrp > product.price
        ? (((product.mrp - product.price) / product.mrp) * 100).round()
        : 0;

    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(page: ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: BakeryStyle.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BakeryStyle.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Square Image Container with Fav Heart & Unit
            AspectRatio(
              aspectRatio: 1.05,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1EDE2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Text('🥐', style: TextStyle(fontSize: 36)),
                            ),
                          )
                        : const Center(
                            child: Text('🥐', style: TextStyle(fontSize: 36)),
                          ),
                  ),

                  // Heart Favourite Button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Bounceable(
                      onTap: onToggleFav,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavourite ? const Color(0xFFE11D48) : AppDesignSystem.slate400,
                        ),
                      ),
                    ),
                  ),

                  // Discount Badge
                  if (discountPercent > 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 2. Unit and Spec Tag
            Row(
              children: [
                Text(
                  product.unit.isNotEmpty ? product.unit : '1 pc',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BakeryStyle.amber,
                  ),
                ),
                if (product.tags.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4D4D8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      product.tags.first,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF65A30D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),

            // 3. Product Title
            Text(
              product.name,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: BakeryStyle.espresso,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // 4. Price & Stepper Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${product.price.round()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BakeryStyle.espresso,
                      ),
                    ),
                    if (product.mrp > product.price)
                      Text(
                        '₹${product.mrp.round()}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),

                // Stepper or ADD Button
                inCartCount == 0
                    ? Bounceable(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BakeryStyle.green, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: BakeryStyle.green.withValues(alpha: 0.10),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'ADD',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: BakeryStyle.green,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: BakeryStyle.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Bounceable(
                              onTap: onDecrement,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.remove, size: 14, color: Colors.white),
                              ),
                            ),
                            Text(
                              '$inCartCount',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Bounceable(
                              onTap: onIncrement,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
