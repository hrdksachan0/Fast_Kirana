import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurant_provider.dart';
import 'table_booking_screen.dart';

class CafeCategorySection {
  final String id;
  final String name;
  final String emoji;
  final List<String> matchTags;

  const CafeCategorySection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.matchTags,
  });
}

class CafeMenuScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const CafeMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<CafeMenuScreen> createState() => _CafeMenuScreenState();
}

class _CafeMenuScreenState extends ConsumerState<CafeMenuScreen> {
  String _selectedCategory = 'all';
  bool _vegOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Full 19 Categories from Web constants.ts (DEFAULT_CAFE_MENU_SECTIONS)
  static const List<CafeCategorySection> _categories = [
    CafeCategorySection(id: 'all', name: 'All Items', emoji: '🍽️', matchTags: []),
    CafeCategorySection(id: 'hot-beverage', name: 'Brews & Tea', emoji: '☕', matchTags: ['hot-beverage', 'brews', 'tea', 'chai', 'hot coffee', 'coffee']),
    CafeCategorySection(id: 'hot-bite', name: 'Quick Snacks', emoji: '🥟', matchTags: ['hot-bite', 'snacks', 'momos', 'fries', 'samosa']),
    CafeCategorySection(id: 'sandwiches', name: 'Sandwiches', emoji: '🥪', matchTags: ['sandwiches', 'sandwich', 'grilled sandwich']),
    CafeCategorySection(id: 'burgers', name: 'Burgers', emoji: '🍔', matchTags: ['burgers', 'burger', 'veg-burger', 'cheese-burger', 'paneer-burger']),
    CafeCategorySection(id: 'frankie-rolls', name: 'Rolls & Frankie', emoji: '🌯', matchTags: ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll', 'kathi-roll']),
    CafeCategorySection(id: 'garlic-bread', name: 'Garlic Bread', emoji: '🧄', matchTags: ['garlic-bread', 'garlic bread', 'garlic-breads']),
    CafeCategorySection(id: 'pizza', name: 'Pizzas', emoji: '🍕', matchTags: ['pizza', 'pizzas']),
    CafeCategorySection(id: 'pav-bhaji', name: 'Pav Bhaji', emoji: '🫕', matchTags: ['pav-bhaji', 'pav bhaji', 'pavbhaji']),
    CafeCategorySection(id: 'chinese', name: 'Chinese', emoji: '🥡', matchTags: ['chinese', 'chinese-cuisine', 'chinese cuisine', 'noodles', 'manchurian']),
    CafeCategorySection(id: 'italian-pasta', name: 'Pastas', emoji: '🍝', matchTags: ['italian-pasta', 'italian-pastas', 'pasta', 'penne']),
    CafeCategorySection(id: 'south-indian', name: 'South Indian', emoji: '🍛', matchTags: ['south-indian', 'south indian', 'dosa', 'idli', 'vada', 'uttapam']),
    CafeCategorySection(id: 'bombay-bites', name: 'Bombay Bites', emoji: '🥪', matchTags: ['bombay-bites', 'bombay bites', 'bombay-bite', 'vada pav', 'misal']),
    CafeCategorySection(id: 'rice-dishes', name: 'Rice & Bowls', emoji: '🍚', matchTags: ['rice-dishes', 'rice dishes', 'biryani', 'pulav', 'fried rice']),
    CafeCategorySection(id: 'shakes', name: 'Shakes', emoji: '🥤', matchTags: ['shakes', 'shake', 'milkshake', 'milkshakes', 'oreo shake']),
    CafeCategorySection(id: 'mocktails', name: 'Mocktails', emoji: '🍹', matchTags: ['mocktails', 'mocktail', 'coolers', 'mojito']),
    CafeCategorySection(id: 'cold-coffee', name: 'Cold Coffee', emoji: '🧋', matchTags: ['cold-coffee', 'cold coffee', 'iced coffee', 'frappe']),
    CafeCategorySection(id: 'bakery', name: 'Bakery', emoji: '🎂', matchTags: ['bakery', 'bakery-biscuits', 'cake', 'cakes', 'pastry']),
    CafeCategorySection(id: 'chilled', name: 'Cold Drinks', emoji: '🥤', matchTags: ['chilled', 'cold-drink', 'beverages', 'beverage', 'drinks', 'soft drink']),
    CafeCategorySection(id: 'desserts', name: 'Desserts', emoji: '🍦', matchTags: ['desserts', 'ice-cream', 'ice cream', 'kulfi', 'dessert', 'sweet', 'brownie']),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isVeg(Product product) {
    final tags = (product.tags ?? []).map((t) => t.toLowerCase()).toList();
    if (tags.any((t) => t.contains('non-veg') || t.contains('nonveg') || t == 'egg' || t.contains('chicken') || t.contains('mutton'))) {
      return false;
    }
    return true;
  }

  bool _matchesCategory(Product product, CafeCategorySection section) {
    if (section.id == 'all') return true;
    final catId = product.categoryId?.toLowerCase() ?? '';
    final prodName = product.name.toLowerCase();
    final prodDesc = (product.description ?? '').toLowerCase();
    final tags = (product.tags ?? []).map((t) => t.toLowerCase()).toList();

    // Check matchTags synonym list
    for (final tag in section.matchTags) {
      final t = tag.toLowerCase();
      if (catId.contains(t) || prodName.contains(t) || prodDesc.contains(t) || tags.any((pt) => pt.contains(t))) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final cart = ref.watch(cartProvider).value;
    final cartCount = cart?.totalItems ?? 0;
    final cartSubtotal = cart?.subtotal ?? 0.0;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // 1. Sliver AppBar with Restaurant Details & Hero Banner
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: const Color(0xFFEA580C),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.table_restaurant_rounded, color: Colors.white),
                tooltip: 'Reserve Table',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TableBookingScreen(
                        restaurantId: widget.restaurantId,
                        restaurantName: widget.restaurantName,
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('🥘', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.restaurantName,
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Freshly prepared • Fast Delivery in 25-35 mins',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text(
                                      '4.8',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• 30-40 min',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Filters, In-Menu Search & Categories Header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Search Bar inside Menu
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search dishes in ${widget.restaurantName}...',
                        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B7280)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)),
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
                  const SizedBox(height: 10),

                  // Veg Only Switch + Book Table Pill
                  Row(
                    children: [
                      // Veg Only Toggle
                      GestureDetector(
                        onTap: () => setState(() => _vegOnly = !_vegOnly),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _vegOnly ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                            border: Border.all(
                              color: _vegOnly ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Veg Only',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _vegOnly ? const Color(0xFF15803D) : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reserve Table Pill
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TableBookingScreen(
                                restaurantId: widget.restaurantId,
                                restaurantName: widget.restaurantName,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_seat_rounded, size: 13, color: Color(0xFFEA580C)),
                              const SizedBox(width: 4),
                              Text(
                                'Book Table',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Category Pills (Web Style with Counts)
                  menuAsync.when(
                    data: (products) {
                      return SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isSelected = _selectedCategory == cat.id;

                            // Compute items count in this category
                            final count = cat.id == 'all'
                                ? products.length
                                : products.where((p) => _matchesCategory(p, cat)).length;

                            if (cat.id != 'all' && count == 0) {
                              return const SizedBox.shrink(); // Don't show empty categories
                            }

                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = cat.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cat.emoji, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      cat.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '($count)',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white.withOpacity(0.85) : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(height: 36),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: menuAsync.when(
          data: (products) {
            var filtered = products;

            // 1. Apply Veg Only Filter (FIXED BUG)
            if (_vegOnly) {
              filtered = filtered.where((p) => _isVeg(p)).toList();
            }

            // 2. Apply Category Filter (FIXED BUG)
            if (_selectedCategory != 'all') {
              final section = _categories.firstWhere(
                (c) => c.id == _selectedCategory,
                orElse: () => _categories.first,
              );
              filtered = filtered.where((p) => _matchesCategory(p, section)).toList();
            }

            // 3. Apply Search Filter
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filtered = filtered.where((p) {
                return p.name.toLowerCase().contains(q) ||
                    (p.description?.toLowerCase().contains(q) ?? false) ||
                    (p.tags?.any((t) => t.toLowerCase().contains(q)) ?? false);
              }).toList();
            }

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🍽️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No items found matching "$_searchQuery"'
                          : _vegOnly
                              ? 'No veg items in this category'
                              : 'No items in this category',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _buildFoodItemCard(filtered[index]);
              },
            );
          },
          loading: () => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _buildFoodItemCard(
                  Product(
                    id: 'skeleton_$index',
                    name: 'Dummy Food Item Name Here',
                    slug: 'dummy-slug',
                    categoryId: 'cat',
                    mrp: 150.0,
                    price: 120.0,
                    discount: 20.0,
                    unit: '1 serving',
                    stock: 99,
                    isAvailable: true,
                    tags: const [],
                    minStock: 0,
                    costPrice: 0,
                    isFlashDeal: false,
                    isTopPick: false,
                    isBestSeller: false,
                    sortOrder: 0,
                    createdAt: DateTime.now(),
                    description: 'This is a description placeholder for the skeleton loading animation card.',
                  ),
                );
              },
            ),
          ),
          error: (_, __) => const Center(
            child: Text('Failed to load menu items'),
          ),
        ),
      ),

      // 3. Floating Bottom Cart Bar
      bottomSheet: cartCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEA580C), Color(0xFFD97706)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$cartCount items · ₹${cartSubtotal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Extra charges may apply',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            'View Cart',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFoodItemCard(Product product) {
    final cart = ref.watch(cartProvider).value;
    final cartItem = cart?.items.where((i) => i.productId == product.id).firstOrNull;
    final inCartQty = cartItem?.quantity ?? 0;
    final isVeg = _isVeg(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        border: Border.all(color: AppDesignSystem.border),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image with rounded border
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Text('🍔', style: TextStyle(fontSize: 32)),
                          ),
                        )
                      : const Center(
                          child: Text('🍔', style: TextStyle(fontSize: 32)),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Food Info (Veg/Non-Veg Dynamic Icon, Name, Price, Description)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Veg / Non-Veg Indicator (DYNAMIC CHECK)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: isVeg ? null : BorderRadius.circular(1),
                        color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Name
                Text(
                  product.name,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Price & MRP
                Row(
                  children: [
                    Text(
                      '₹${product.price.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (product.mrp > product.price) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${product.mrp.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
                if (product.description != null && product.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.description!,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Contextual ADD Button on Right
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: inCartQty > 0
                ? Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (inCartQty == 1 && cartItem != null) {
                              ref.read(cartProvider.notifier).removeItem(cartItem.id);
                            } else if (cartItem != null) {
                              ref.read(cartProvider.notifier).updateQuantity(cartItem.id, inCartQty - 1);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Icon(Icons.remove, size: 14, color: Colors.white),
                          ),
                        ),
                        Text(
                          '$inCartQty',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (cartItem != null) {
                              ref.read(cartProvider.notifier).updateQuantity(cartItem.id, inCartQty + 1);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      ref.read(cartProvider.notifier).addItem(product.id, 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                        border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
                      ),
                      child: Text(
                        'ADD',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}