import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/product_card.dart';
import '../cart/cart_screen.dart';
import 'table_booking_screen.dart';
import '../profile/add_review_screen.dart';

class WebMenuSection {
  final String tag;
  final List<String> matchTags;
  final String title;
  final String emoji;
  final String description;

  const WebMenuSection({
    required this.tag,
    required this.matchTags,
    required this.title,
    required this.emoji,
    required this.description,
  });
}

// 1:1 Parity with www.fastkirana.in DEFAULT_CAFE_MENU_SECTIONS
const List<WebMenuSection> webCafeSections = [
  WebMenuSection(tag: 'hot-beverage', matchTags: ['hot-beverage', 'hot-coffee', 'hot coffee', 'tea', 'chai'], title: 'Brews & Tea', emoji: '☕', description: 'Chai, hot coffee, and fresh brewing mixes'),
  WebMenuSection(tag: 'hot-bite', matchTags: ['hot-bite', 'snacks', 'momos', 'fries', 'samosa'], title: 'Quick Snacks', emoji: '🥟', description: 'Samosas, Momos, French Fries, and warm treats'),
  WebMenuSection(tag: 'sandwiches', matchTags: ['sandwiches', 'sandwich'], title: 'Sandwiches', emoji: '🥪', description: 'Freshly grilled sandwiches loaded with cheese, paneer, and veggies'),
  WebMenuSection(tag: 'burgers', matchTags: ['burgers', 'burger', 'veg-burger', 'cheese-burger', 'paneer-burger'], title: 'Burgers', emoji: '🍔', description: 'Juicy veg burgers, paneer burgers, and loaded cheese burgers'),
  WebMenuSection(tag: 'frankie-rolls', matchTags: ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll'], title: 'Rolls & Frankie', emoji: '🌯', description: 'Fresh rolls stuffed with paneer, cheese, and veg patties'),
  WebMenuSection(tag: 'garlic-bread', matchTags: ['garlic-bread', 'garlic bread', 'garlic-breads'], title: 'Garlic Bread', emoji: '🧄', description: 'Loaded garlic breads with corn, paneer & cheese'),
  WebMenuSection(tag: 'pizza', matchTags: ['pizza', 'pizzas'], title: 'Pizzas', emoji: '🍕', description: 'Loaded pizzas with fresh toppings and melted cheese'),
  WebMenuSection(tag: 'pav-bhaji', matchTags: ['pav-bhaji', 'pav bhaji', 'pavbhaji', 'pav'], title: 'Pav Bhaji', emoji: '🍲', description: 'Butter Pav Bhaji, Paneer Pav Bhaji & Extra Pav'),
  WebMenuSection(tag: 'chinese', matchTags: ['chinese', 'chinese-cuisine', 'noodles', 'manchurian', 'chilli'], title: 'Chinese', emoji: '🥡', description: 'Momos, noodles, fried dishes & sauces'),
  WebMenuSection(tag: 'italian-pasta', matchTags: ['italian-pasta', 'italian-pastas', 'pasta'], title: 'Pastas', emoji: '🍝', description: 'Fresh penne tossed in aromatic red & white sauces'),
  WebMenuSection(tag: 'south-indian', matchTags: ['south-indian', 'south indian', 'dosa', 'idli', 'vada'], title: 'South Indian', emoji: '🥞', description: 'Dosa, Idli, Vada, Uttapam & more'),
  WebMenuSection(tag: 'bombay-bites', matchTags: ['bombay-bites', 'bombay bites', 'vada pav'], title: 'Bombay Bites', emoji: '🥪', description: 'Vada Pav, special Bombay Masala Toast, and street snacks'),
  WebMenuSection(tag: 'rice-dishes', matchTags: ['rice-dishes', 'rice dishes', 'biryani', 'pulav', 'fried rice', 'rice'], title: 'Rice & Bowls', emoji: '🍚', description: 'Flavourful biryani, fried rice, and combos'),
  WebMenuSection(tag: 'shakes', matchTags: ['shakes', 'shake', 'milkshake', 'oreo shake'], title: 'Shakes', emoji: '🥤', description: 'Creamy strawberry, chocolate, and Oreo shakes'),
  WebMenuSection(tag: 'mocktails', matchTags: ['mocktails', 'mocktail', 'coolers', 'mojito'], title: 'Mocktails', emoji: '🍹', description: 'Iced coolers, Virgin Mojito, and summer drinks'),
  WebMenuSection(tag: 'cold-coffee', matchTags: ['cold-coffee', 'cold coffee', 'iced coffee'], title: 'Cold Coffee', emoji: '🧋', description: 'Classic cold brews, hazelnut cold coffee & iced sips'),
  WebMenuSection(tag: 'desserts', matchTags: ['desserts', 'ice-cream', 'ice cream', 'kulfi', 'dessert', 'sweet'], title: 'Desserts', emoji: '🍦', description: 'Chilled premium ice creams, kulfis, and desserts'),
];

// 1:1 Parity with www.fastkirana.in DEFAULT_RESTAURANT_MENU_SECTIONS (Wedson, Bal Udyan)
const List<WebMenuSection> webRestaurantSections = [
  WebMenuSection(tag: 'main-course', matchTags: ['north-indian', 'curry', 'dal-makhani', 'paneer-butter-masala', 'paneer', 'main-course', 'dal', 'makhani', 'tadka', 'shahi', 'kadhai', 'curries', 'gravy'], title: 'Curries & Gravies', emoji: '🥘', description: 'Rich paneer butter masala, creamy dal makhani & Special Kadhai Gravies'),
  WebMenuSection(tag: 'roti-naan-breads', matchTags: ['roti-naan-kulcha', 'roti', 'naan', 'kulcha', 'breads', 'paratha', 'missi roti', 'lachha'], title: 'Rotis & Naans', emoji: '🫓', description: 'Butter Naan, Garlic Naan, Tandoori Roti, Missi Roti & Stuffed Kulchas'),
  WebMenuSection(tag: 'starters-tandoori', matchTags: ['special-starters', 'tandoori', 'starter', 'starters', 'kebabs', 'tikka', 'chaap', 'malai tikka', 'achari tikka'], title: 'Starters & Tandoori', emoji: '🍢', description: 'Soya Malai Chaap, Paneer Tikka, Veg Seekh Kebab & Tandoori Treats'),
  WebMenuSection(tag: 'biryani-rice', matchTags: ['biryani-rice', 'biryani', 'pulav', 'fried-rice', 'jeera-rice', 'rice'], title: 'Biryani & Rice', emoji: '🍚', description: 'Aromatic basmati veg biryanis, paneer pulavs & loaded fried rice bowls'),
  WebMenuSection(tag: 'pizzas-burgers', matchTags: ['pizza', 'burger', 'burgers', 'pizzas', 'sandwich', 'garlic-bread'], title: 'Pizza & Burgers', emoji: '🍕', description: 'Fresh baked pizzas, loaded veggie burgers & grilled sandwiches'),
  WebMenuSection(tag: 'chinese-soups', matchTags: ['chinese', 'noodles', 'manchurian', 'chilli-paneer', 'spring-rolls', 'soup', 'pasta', 'momo'], title: 'Chinese & Soups', emoji: '🥡', description: 'Stir-fried noodles, saucy veg manchurian, hot soups & pastas'),
  WebMenuSection(tag: 'breakfast', matchTags: ['breakfast', 'paratha', 'poori', 'chole-bhature', 'nashta', 'poha'], title: 'Breakfast', emoji: '🍳', description: 'Chole Bhature, Parathas, Poori and morning favorites'),
  WebMenuSection(tag: 'shakes-beverages', matchTags: ['shake', 'shakes', 'beverage', 'beverages', 'drinks', 'drink', 'cold-drink', 'mocktail', 'coffee', 'chai', 'tea', 'chilled'], title: 'Shakes & Drinks', emoji: '🥤', description: 'Thick shakes, cold sodas, tea & coffee'),
  WebMenuSection(tag: 'desserts', matchTags: ['dessert', 'desserts', 'ice-cream', 'ice cream', 'kulfi', 'sweet', 'gulab jamun'], title: 'Desserts & Sweets', emoji: '🍦', description: 'Chilled premium desserts and traditional sweets'),
];

class RenderedCategory {
  final String tag;
  final String title;
  final String emoji;
  final List<Product> products;

  const RenderedCategory({
    required this.tag,
    required this.title,
    required this.emoji,
    required this.products,
  });
}

class CafeMenuScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final Restaurant? restaurant;

  const CafeMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurant,
  });

  @override
  ConsumerState<CafeMenuScreen> createState() => _CafeMenuScreenState();
}

class _CafeMenuScreenState extends ConsumerState<CafeMenuScreen> {
  String _activeCategoryTag = 'all';
  bool _isVegOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryOrange = Color(0xFFEA580C);
  static const Color primaryRed = Color(0xFFE20A22);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isVeg(Product product) {
    final tags = product.tags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) => t.contains('non-veg') || t.contains('nonveg') || t == 'egg' || t.contains('chicken') || t.contains('mutton'))) {
      return false;
    }
    final nameLower = product.name.toLowerCase();
    if (nameLower.contains('chicken') || nameLower.contains('egg') || nameLower.contains('mutton') || nameLower.contains('fish')) {
      return false;
    }
    return true;
  }

  bool _isCafeRestaurant(Restaurant? r, String name, String id) {
    final nameLower = (r?.name ?? name).toLowerCase();
    final slugLower = (r?.slug ?? '').toLowerCase();
    return nameLower.contains('a.s') || nameLower.contains('cafe') || slugLower.contains('as-') || slugLower.contains('cafe');
  }

  List<RenderedCategory> _buildCategories(List<Product> products, Restaurant? restaurant) {
    List<WebMenuSection> baseSections;
    if (restaurant?.menuSections != null && restaurant!.menuSections!.isNotEmpty) {
      baseSections = restaurant!.menuSections!.map((s) {
        final map = s is Map ? s : <String, dynamic>{};
        final tag = map['tag']?.toString() ?? 'section';
        final title = map['title']?.toString() ?? 'Menu Section';
        final emoji = map['emoji']?.toString() ?? '🍽️';
        final desc = map['description']?.toString() ?? '';
        final matchTags = (map['matchTags'] is List)
            ? (map['matchTags'] as List).map((e) => e.toString()).toList()
            : <String>[];
        return WebMenuSection(
          tag: tag,
          title: title,
          emoji: emoji,
          description: desc,
          matchTags: matchTags,
        );
      }).toList();
    } else {
      final isCafe = _isCafeRestaurant(restaurant, widget.restaurantName, widget.restaurantId);
      baseSections = isCafe ? webCafeSections : webRestaurantSections;
    }

    // Filter products by search & veg
    var filtered = products;
    if (_isVegOnly) {
      filtered = filtered.where((p) => restaurant?.isPureVeg == true || _isVeg(p)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchDesc = (p.description ?? '').toLowerCase().contains(q);
        final matchTag = p.tags.any((t) => t.toLowerCase().contains(q));
        return matchName || matchDesc || matchTag;
      }).toList();
    }

    final assignedIds = <String>{};
    final result = <RenderedCategory>[];

    for (final sec in baseSections) {
      final secTagLower = sec.tag.toLowerCase();
      final secTitleLower = sec.title.toLowerCase();

      final secProducts = filtered.where((p) {
        final pTags = p.tags.map((t) => t.toLowerCase()).toList();
        final pCatSlug = (p.category?.slug ?? '').toLowerCase();
        final pCatName = (p.category?.name ?? '').toLowerCase();
        final pName = p.name.toLowerCase();

        final matched = sec.matchTags.any((tag) {
          final t = tag.toLowerCase();
          return pTags.contains(t) || pCatSlug.contains(t) || pCatName.contains(t) || pName.contains(t);
        }) || pTags.contains(secTagLower) || pCatSlug == secTagLower || pCatName == secTitleLower;

        if (matched) {
          assignedIds.add(p.id);
        }
        return matched;
      }).toList();

      if (secProducts.isNotEmpty) {
        result.add(RenderedCategory(
          tag: sec.tag,
          title: sec.title,
          emoji: sec.emoji,
          products: secProducts,
        ));
      }
    }

    // Smartly auto-group unassigned products
    final unassigned = filtered.where((p) => !assignedIds.contains(p.id)).toList();
    if (unassigned.isNotEmpty) {
      final Map<String, List<Product>> categoryGroups = {};
      for (final p in unassigned) {
        final groupTitle = (p.category?.name != null && p.category!.name.trim().isNotEmpty && p.category!.name != 'Restaurant Food' && p.category!.name != 'Cafe')
            ? p.category!.name.trim()
            : 'Specialties';
        categoryGroups.putIfAbsent(groupTitle, () => []).add(p);
      }

      categoryGroups.forEach((title, grpProducts) {
        result.add(RenderedCategory(
          tag: 'custom-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
          title: title,
          emoji: '🍳',
          products: grpProducts,
        ));
      });
    }

    return [
      RenderedCategory(tag: 'all', title: 'All Items', emoji: '🍽️', products: filtered),
      ...result,
    ];
  }

  String _getFallbackBackground(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wedson')) return 'assets/categories/wedson_restaurant_bg.png';
    if (lower.contains('bal udyan') || lower.contains('baludyan')) return 'assets/categories/cafe_banner.png';
    return 'assets/categories/cafe_banner.png';
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final restaurantsList = ref.watch(restaurantsProvider).valueOrNull ?? [];
    final currentRestaurant = widget.restaurant ??
        restaurantsList.cast<Restaurant?>().firstWhere((r) => r?.id == widget.restaurantId, orElse: () => null);

    final cart = ref.watch(cartProvider).value;
    final cartCount = cart?.totalItems ?? 0;
    final cartSubtotal = cart?.subtotal ?? 0.0;

    final restaurantName = currentRestaurant?.name ?? widget.restaurantName;
    final addressText = currentRestaurant?.address ?? 'Ghatampur Express Zone';
    final ratingVal = currentRestaurant?.rating ?? 4.5;
    final totalReviews = currentRestaurant?.totalRatings ?? 48;
    final deliveryTime = currentRestaurant?.deliveryTime ?? '25-30 min';
    final cuisineTags = currentRestaurant?.cuisineTags ?? ['North Indian', 'Fast Food', 'Snacks'];
    final isPureVeg = currentRestaurant?.isPureVeg ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // 1. Hero Restaurant Photo Header
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: const Color(0xFF1F2937),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Restaurant background image
                      if (currentRestaurant?.bannerUrl != null && currentRestaurant!.bannerUrl!.startsWith('http'))
                        CachedNetworkImage(
                          imageUrl: currentRestaurant.bannerUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Image.asset(
                            _getFallbackBackground(restaurantName),
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Image.asset(
                          _getFallbackBackground(restaurantName),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
                        ),

                      // Dark Vignette Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      // Content
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Restaurant Thumbnail Card
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: (currentRestaurant?.logoUrl != null && currentRestaurant!.logoUrl!.startsWith('http'))
                                      ? CachedNetworkImage(
                                          imageUrl: currentRestaurant.logoUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Center(
                                            child: Text('🍽️', style: TextStyle(fontSize: 28)),
                                          ),
                                        )
                                      : const Center(
                                          child: Text('🍽️', style: TextStyle(fontSize: 28)),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      restaurantName,
                                      style: GoogleFonts.inter(
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addressText,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),

                                    // Cuisine Badges
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          ...cuisineTags.take(4).map((tag) => Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: _buildCuisineTag(tag.toUpperCase()),
                                          )),
                                          if (isPureVeg)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00B140).withOpacity(0.25),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF4ADE80), width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.eco_rounded, size: 9, color: Color(0xFF4ADE80)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Pure Veg',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF4ADE80),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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

              // 2. Info Strip, Search & Web-Parity Category Tabs
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating & Delivery Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15803D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '$ratingVal ($totalReviews reviews)',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(
                                deliveryTime,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF374151)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Veg Only Filter Switch
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isVegOnly = !_isVegOnly);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isVegOnly ? const Color(0xFFECFDF5) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isVegOnly ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco_rounded, size: 12, color: _isVegOnly ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Veg Only',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _isVegOnly ? const Color(0xFF047857) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search inside restaurant bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: 'Search items in $restaurantName...',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Exact 1:1 Web-Parity Category Tabs for this Restaurant
                    menuAsync.when(
                      data: (products) {
                        final renderedCats = _buildCategories(products, currentRestaurant);
                        return Container(
                          height: 46,
                          margin: const EdgeInsets.only(top: 4, bottom: 4),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: renderedCats.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = renderedCats[index];
                              final isSelected = _activeCategoryTag == cat.tag;

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _activeCategoryTag = cat.tag);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryOrange : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? primaryOrange : const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: primaryOrange.withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${cat.title} (${cat.products.length})',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : const Color(0xFF334155),
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
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                  ],
                ),
              ),
            ],

            // 3. Menu Grid displaying the restaurant's products
            body: menuAsync.when(
              data: (products) {
                final renderedCats = _buildCategories(products, currentRestaurant);
                final selectedCat = renderedCats.firstWhere(
                  (c) => c.tag == _activeCategoryTag,
                  orElse: () => renderedCats.first,
                );
                final displayItems = selectedCat.products;

                if (displayItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No items found in this section',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try selecting another category or clear search filter',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.80,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: displayItems[index]);
                  },
                );
              },
              loading: () => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.80,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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

          // 4. Floating Island Cart Bar
          if (cartCount > 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                child: Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF18181B), Color(0xFF27272A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFFB923C).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withOpacity(0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$cartCount ${cartCount == 1 ? 'ITEM' : 'ITEMS'} ADDED',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFB923C),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '₹${cartSubtotal.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Cart',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCuisineTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}