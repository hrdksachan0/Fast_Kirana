import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';

import '../../data/models/product.dart';
import '../../data/models/bakery_store_config.dart';
import '../../providers/bakery_store_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../cart/cart_screen.dart';
import '../products/product_detail_screen.dart';

/// Ultra-Modern Blinkit Glassmorphic Color Palette
abstract final class BlinkitGlassTheme {
  static const creamBg = Color(0xFFFAF8F3);
  static const darkTeal = Color(0xFF134E5E);
  static const slateDark = Color(0xFF0F172A);
  static const yellowPrice = Color(0xFFFFD854);
  static const blueDiscount = Color(0xFF2472F3);
  static const greenAdd = Color(0xFF2D830C);
  static const tagBg = Color(0xFFF0E9C9);
  static const tagText = Color(0xFF695B1D);
  static const frostedBorder = Color(0x66FFFFFF);
}

/// Dedicated Artisanal Bakery Store Screen (Strictly Excluding Birthday/Celebration Cakes)
/// Features Blinkit-grade Connected Arch Category Tabs, Liquid Frosted Emerald Floating Cart,
/// Server-Driven UI configuration from Web Admin, and real-time CartProvider synchronization.
class BakeryStoreScreen extends ConsumerStatefulWidget {
  const BakeryStoreScreen({super.key});

  @override
  ConsumerState<BakeryStoreScreen> createState() => _BakeryStoreScreenState();
}

class _BakeryStoreScreenState extends ConsumerState<BakeryStoreScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Set<String> _favourites = {};
  String _searchQuery = '';

  late AnimationController _tabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _tabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _tabAnimCtrl.forward();
  }

  @override
  void dispose() {
    _tabAnimCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedTabIndex = index);
    _tabAnimCtrl.reset();
    _tabAnimCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final currentHub = ref.watch(currentStoreHubProvider);
    final storeName = currentHub.city.isNotEmpty ? currentHub.city : currentHub.name;

    // Server-Driven Dynamic Bakery Configuration from Web Admin
    final configAsync = ref.watch(bakeryStoreConfigProvider);
    final config = configAsync.valueOrNull ??
        const BakeryStoreConfigModel(tabs: BakeryStoreConfigModel.defaultTabs);

    final activeTabs = config.tabs.where((t) => t.isActive).toList();
    if (_selectedTabIndex >= activeTabs.length) {
      _selectedTabIndex = 0;
    }
    final currentTab = activeTabs.isNotEmpty ? activeTabs[_selectedTabIndex] : null;

    // Real Supabase Products
    final allProductsAsync = ref.watch(productsProvider(null));
    final allProducts = allProductsAsync.valueOrNull ?? [];

    final cartState = ref.watch(cartProvider);
    final cart = cartState.valueOrNull;
    final cartItems = cart?.items ?? [];
    final totalCartQty = cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final cartTotalAmount = cart?.subtotal ?? 0.0;

    // Filter products strictly excluding celebration/birthday cakes
    final tabProducts = _resolveTabProducts(allProducts, currentTab, _searchQuery);

    return Scaffold(
      backgroundColor: config.backgroundColor,
      body: Stack(
        children: [
          // 1. Ambient Luminous Mesh Glowing Orbs for Glass Refraction
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE68A).withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA7F3D0).withValues(alpha: 0.28),
              ),
            ),
          ),

          // 2. Main Scroll View
          CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sticky Frosted Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: _buildFrostedHeader(context, selectedAddress, storeName),
                ),
              ),

              // Lifestyle Hero Glass Card Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: _buildHeroGlassBanner(config),
                ),
              ),

              // Connected Arch Category Selector
              if (activeTabs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildArchTabBar(activeTabs),
                ),

              // Connected Shelf Section with Products
              SliverToBoxAdapter(
                child: _buildShelfHeader(currentTab),
              ),

              // Product Cards Shelf (Horizontal Scroll or Grid)
              SliverToBoxAdapter(
                child: _buildProductShelf(tabProducts, cartItems),
              ),

              // Morning Chai Pairing Combo Glass Banner
              SliverToBoxAdapter(
                child: _buildChaiComboBanner(),
              ),

              // Bottom Padding for Floating Cart
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          // 3. Liquid Frosted Emerald Floating Cart Bar
          if (totalCartQty > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildLiquidEmeraldCartBar(context, cartItems, totalCartQty, cartTotalAmount),
            ),
        ],
      ),
    );
  }

  // --- HEADER & SEARCH ---
  Widget _buildFrostedHeader(BuildContext context, dynamic selectedAddress, String storeName) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            border: const Border(
              bottom: BorderSide(color: Color(0x33000000), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            children: [
              // Top Bar: Back, Location, FastMinute Hub
              Row(
                children: [
                  Bounceable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: BlinkitGlassTheme.slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      child: Row(
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              selectedAddress != null
                                  ? selectedAddress.fullAddress
                                  : '$storeName Dark Store',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: BlinkitGlassTheme.slateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '⚡ 10 MIN',
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

              // Search Input (Blinkit Frosted Style)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BlinkitGlassTheme.slateDark,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: 'Search for bread, pav, rusk, cookies...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.black38,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Colors.black45,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Blinkit Department Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDeptItem('💊', 'Pharmacy', false),
                  _buildDeptItem('🎁', 'Gifting', false),
                  _buildDeptItem('🥐', 'Bakery', true),
                  _buildDeptItem('👶', 'Kids', false),
                  _buildDeptItem('🛒', 'Imported', false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeptItem(String emoji, String title, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: isActive ? 18 : 16)),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            color: isActive ? BlinkitGlassTheme.slateDark : Colors.black45,
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: BlinkitGlassTheme.slateDark,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }

  // --- HERO GLASS BANNER ---
  Widget _buildHeroGlassBanner(BakeryStoreConfigModel config) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF134E5E).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        config.bannerBadge,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF065F46),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      config.bannerTitle,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: BlinkitGlassTheme.darkTeal,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.bannerSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: BlinkitGlassTheme.darkTeal.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 110,
                  height: 85,
                  child: CachedNetworkImage(
                    imageUrl: config.bannerImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.black12),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFFEF3C7),
                      child: const Center(child: Text('🥐', style: TextStyle(fontSize: 32))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CONNECTED ARCH TAB BAR ---
  Widget _buildArchTabBar(List<BakeryTabModel> tabs) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final tab = entry.value;
            final isSelected = idx == _selectedTabIndex;

            return Bounceable(
              onTap: () => _onTabSelected(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isSelected ? 96 : 84,
                margin: const EdgeInsets.only(right: 6),
                padding: EdgeInsets.fromLTRB(6, 8, 6, isSelected ? 10 : 8),
                decoration: isSelected
                    ? const BoxDecoration(
                        color: BlinkitGlassTheme.creamBg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: BlinkitGlassTheme.slateDark, width: 2.2),
                          left: BorderSide(color: BlinkitGlassTheme.slateDark, width: 2.2),
                          right: BorderSide(color: BlinkitGlassTheme.slateDark, width: 2.2),
                          bottom: BorderSide(color: Colors.transparent, width: 0),
                        ),
                      )
                    : BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Circle
                    Container(
                      width: isSelected ? 48 : 42,
                      height: isSelected ? 48 : 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFFFEF3C7)
                            : Colors.white.withValues(alpha: 0.8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF59E0B)
                              : Colors.white,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          tab.emoji,
                          style: TextStyle(fontSize: isSelected ? 24 : 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tab.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isSelected ? 10.5 : 9.5,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? BlinkitGlassTheme.slateDark : Colors.black54,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- SHELF HEADER WITH CONNECTED STROKE ---
  Widget _buildShelfHeader(BakeryTabModel? currentTab) {
    if (currentTab == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: BlinkitGlassTheme.slateDark, width: 2.2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentTab.title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: BlinkitGlassTheme.slateDark,
                  ),
                ),
                if (currentTab.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    currentTab.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'See all >',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: BlinkitGlassTheme.blueDiscount,
            ),
          ),
        ],
      ),
    );
  }

  // --- PRODUCT SHELF (EXACT BLINKIT CARD ANATOMY) ---
  Widget _buildProductShelf(List<Product> products, List<dynamic> cartItems) {
    if (products.isEmpty) {
      return Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥖', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                'Fresh batch arriving soon for this section!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 270,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final product = products[idx];
          return _buildBlinkitProductCard(product, cartItems);
        },
      ),
    );
  }

  Widget _buildBlinkitProductCard(Product product, List<dynamic> cartItems) {
    final cartItem = cartItems.firstWhereOrNull((i) => i.productId == product.id);
    final inCartQty = cartItem?.quantity ?? 0;
    final isFav = _favourites.contains(product.id);

    final price = product.price;
    final mrp = product.mrp > price ? product.mrp : price * 1.25;
    final discountAmount = (mrp - price).clamp(0, 9999).toInt();

    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Tile: White Frosted Image Box with Heart & ADD button
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E2E6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // 1:1 Aspect Image with Wishlist
                    Bounceable(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                        );
                      },
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl ?? '',
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.black12),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFFFFBEB),
                                  child: const Center(
                                    child: Text('🍞', style: TextStyle(fontSize: 28)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Heart Button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isFav) {
                                    _favourites.remove(product.id);
                                  } else {
                                    _favourites.add(product.id);
                                  }
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                child: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 13,
                                  color: isFav ? Colors.redAccent : Colors.black38,
                                ),
                              ),
                            ),
                          ),
                          // Dots Indicator
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BlinkitGlassTheme.slateDark,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Unit & ADD button (inside tile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.unit.isNotEmpty ? product.unit : '1 pc',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        // ADD / Stepper Button
                        inCartQty > 0
                            ? Container(
                                height: 26,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: BlinkitGlassTheme.greenAdd,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        ref.read(cartProvider.notifier).updateQuantity(
                                              product.id,
                                              inCartQty - 1,
                                            );
                                      },
                                      child: const Icon(Icons.remove, size: 14, color: Colors.white),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        '$inCartQty',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        ref.read(cartProvider.notifier).updateQuantity(
                                              product.id,
                                              inCartQty + 1,
                                            );
                                      },
                                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              )
                            : Bounceable(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(cartProvider.notifier).addItem(product.id, 1);
                                },
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: BlinkitGlassTheme.greenAdd,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: BlinkitGlassTheme.greenAdd.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'ADD',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: BlinkitGlassTheme.greenAdd,
                                      ),
                                    ),
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

          const SizedBox(height: 5),

          // Lower Section (Outside White Tile)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: BlinkitGlassTheme.yellowPrice,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '₹${price.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: BlinkitGlassTheme.slateDark,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              if (mrp > price)
                Text(
                  '₹${mrp.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.black38,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),

          if (discountAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '₹$discountAmount OFF',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: BlinkitGlassTheme.blueDiscount,
                ),
              ),
            ),

          const SizedBox(height: 2),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BlinkitGlassTheme.slateDark,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 3),
          // Spec Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: BlinkitGlassTheme.tagBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _resolveProductBadge(product.name),
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: BlinkitGlassTheme.tagText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CHAI-RUSK COMBO PROMO ---
  Widget _buildChaiComboBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Center(
                    child: Text('☕', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chai-Rusk Combo Deal',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                      Text(
                        'Add Elaichi Rusk & save ₹15 on tea leaves',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'EXPLORE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- LIQUID FROSTED EMERALD FLOATING CART BAR ---
  Widget _buildLiquidEmeraldCartBar(
    BuildContext context,
    List<dynamic> cartItems,
    int totalQty,
    double totalAmount,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Bounceable(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF228413).withValues(alpha: 0.92),
                  const Color(0xFF14600C).withValues(alpha: 0.96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF166534).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Dual Circular Product Previews with Frosted Ring
                SizedBox(
                  width: 52,
                  height: 32,
                  child: Stack(
                    children: [
                      if (cartItems.length > 1)
                        Positioned(
                          left: 18,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Center(
                              child: Text('🥐', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Center(
                            child: Text('🍞', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'View cart',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('•', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            '$totalQty ${totalQty == 1 ? 'item' : 'items'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD1FAE5),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total ₹${totalAmount.toInt()} (Free delivery unlocked)',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFA7F3D0),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- FILTER PRODUCTS STRICTLY EXCLUDING CAKES ---
  List<Product> _resolveTabProducts(
    List<Product> allProducts,
    BakeryTabModel? tab,
    String query,
  ) {
    if (tab == null) return [];

    return allProducts.where((p) {
      final name = p.name.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();

      // STRICT EXCLUSION: Exclude birthday, celebration, and anniversary cakes
      final isCake = (name.contains('cake') && !name.contains('tea cake') && !name.contains('cupcake')) ||
          name.contains('birthday') ||
          name.contains('anniversary') ||
          name.contains('pastry');
      if (isCake) return false;

      // Search Query filter
      if (query.isNotEmpty) {
        return name.contains(query) || desc.contains(query);
      }

      // Match Tab filter tags
      for (final tag in tab.filterTags) {
        if (name.contains(tag) || desc.contains(tag)) {
          return true;
        }
      }

      // Fallback matching if in bakery category
      final category = (p.categoryId ?? '').toLowerCase();
      if (category.contains('bakery') || category.contains('bread')) {
        return true;
      }

      return false;
    }).toList();
  }

  String _resolveProductBadge(String productName) {
    final lower = productName.toLowerCase();
    if (lower.contains('pav')) return 'Pav Bhaji Special';
    if (lower.contains('atta') || lower.contains('wheat')) return 'Zero Maida';
    if (lower.contains('rusk')) return '100% Suji';
    if (lower.contains('multigrain')) return 'High Fibre';
    if (lower.contains('puff') || lower.contains('patty')) return 'Flaky & Hot';
    if (lower.contains('butter')) return 'Pure Butter';
    return 'Dark Store Fresh';
  }
}
