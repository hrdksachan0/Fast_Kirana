import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/product.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/cart_conflict_dialog.dart';
import '../../core/utils/restaurant_utils.dart';
import '../products/product_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../profile/add_review_screen.dart';

class WebMenuSection {
  final String tag;
  final List<String> matchTags;
  final String title;
  final String emoji;
  final String? imageUrl;
  final String description;

  const WebMenuSection({
    required this.tag,
    required this.matchTags,
    required this.title,
    required this.emoji,
    this.imageUrl,
    required this.description,
  });
}

// 1:1 Parity with www.fastkirana.in DEFAULT_CAFE_MENU_SECTIONS
const List<WebMenuSection> webCafeSections = [
  WebMenuSection(tag: 'hot-beverage', matchTags: ['hot-beverage', 'hot-coffee', 'hot coffee', 'tea', 'chai'], title: 'Brews & Tea', emoji: '☕', description: 'Chai, hot coffee, and fresh brewing mixes'),
  WebMenuSection(tag: 'hot-bite', matchTags: ['hot-bite', 'snacks', 'momos', 'fries', 'samosa', 'snack', 'spring-rolls', 'spring roll'], title: 'Quick Bites & Snacks', emoji: '🥟', description: 'Samosas, Momos, French Fries, and warm treats'),
  WebMenuSection(tag: 'sandwiches', matchTags: ['sandwiches', 'sandwich', 'grilled sandwich', 'veg sandwich', 'cheese sandwich'], title: 'Sandwiches', emoji: '🥪', description: 'Freshly grilled sandwiches loaded with cheese, paneer, and veggies'),
  WebMenuSection(tag: 'burgers', matchTags: ['burgers', 'burger', 'veg-burger', 'cheese-burger', 'paneer-burger'], title: 'Burgers', emoji: '🍔', description: 'Juicy veg burgers, paneer burgers, and loaded cheese burgers'),
  WebMenuSection(tag: 'frankie-rolls', matchTags: ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll', 'kathi-roll'], title: 'Frankie Rolls', emoji: '🌯', description: 'Fresh rolls stuffed with paneer, cheese, and veg patties'),
  WebMenuSection(tag: 'garlic-bread', matchTags: ['garlic-bread', 'garlic bread', 'garlic-breads', 'cheesy garlic bread'], title: 'Cheesy Garlic Breads', emoji: '🧄', description: 'Loaded garlic breads with corn, paneer & cheese'),
  WebMenuSection(tag: 'pizza', matchTags: ['pizza', 'pizzas', 'cheese pizza', 'paneer pizza', 'capsicum pizza'], title: "Pizza's", emoji: '🍕', description: 'Loaded pizzas with fresh toppings and melted cheese'),
  WebMenuSection(tag: 'pav-bhaji', matchTags: ['pav-bhaji', 'pav bhaji', 'pavbhaji', 'pav', 'bombay-bites', 'bombay bites', 'bombay-bite', 'bombay bite'], title: 'Pav Bhaji & Bombay Bites', emoji: '🍲', description: 'Butter Pav Bhaji, Paneer Pav Bhaji & Extra Pav'),
  WebMenuSection(tag: 'chinese', matchTags: ['chinese', 'chinese-cuisine', 'noodles', 'manchurian', 'chilli', 'chowmein'], title: 'Chinese Cuisine', emoji: '🥡', description: 'Momos, noodles, fried dishes & sauces'),
  WebMenuSection(tag: 'italian-pasta', matchTags: ['italian-pasta', 'italian-pastas', 'pasta', 'red sauce pasta', 'white sauce pasta'], title: 'Italian Pasta', emoji: '🍝', description: 'Fresh penne tossed in aromatic red & white sauces'),
  WebMenuSection(tag: 'south-indian', matchTags: ['south-indian', 'south indian', 'dosa', 'idli', 'vada', 'uttapam'], title: 'South Indian', emoji: '🥞', description: 'Dosa, Idli, Vada, Uttapam & more'),
  WebMenuSection(tag: 'rice-dishes', matchTags: ['rice-dishes', 'rice dishes', 'biryani', 'pulav', 'fried rice', 'fried-rice', 'rice'], title: 'Rice & Bowls', emoji: '🍚', description: 'Flavourful biryani, fried rice, and combos'),
  WebMenuSection(tag: 'shakes', matchTags: ['shakes', 'shake', 'milkshake', 'oreo shake', 'strawberry shake'], title: 'Shakes', emoji: '🥤', description: 'Creamy strawberry, chocolate, and Oreo shakes'),
  WebMenuSection(tag: 'mocktails', matchTags: ['mocktails', 'mocktail', 'coolers', 'mojito'], title: 'Mocktails', emoji: '🍹', description: 'Iced coolers, Virgin Mojito, and summer drinks'),
  WebMenuSection(tag: 'chilled-drinks', matchTags: ['chilled-drinks', 'chilled', 'cold-drink', 'beverages', 'beverage', 'drinks', 'drink', 'soda'], title: 'Cold Drinks & Sodas', emoji: '🥤', description: 'Chilled soft drinks, Campa, Coke, Sprite & refreshing beverages'),
  WebMenuSection(tag: 'desserts', matchTags: ['desserts', 'ice-cream', 'ice cream', 'kulfi', 'dessert', 'sweet', 'icecream', 'ice-creams'], title: 'Ice Creams & Desserts', emoji: '🍦', description: 'Chilled premium ice creams, kulfis, and desserts'),
];

// 1:1 Parity with www.fastkirana.in DEFAULT_RESTAURANT_MENU_SECTIONS (Wedson, Bal Udyan)
const List<WebMenuSection> webRestaurantSections = [
  WebMenuSection(
    tag: 'breakfast',
    matchTags: ['breakfast', 'poori', 'chole-bhature', 'nashta', 'poha', 'muli paratha', 'mix paratha', 'aloo paratha', 'gobhi paratha'],
    title: 'Breakfast & Parathas',
    emoji: '🍳',
    description: 'Parathas, Poori, Chole Bhature and morning specials',
  ),
  WebMenuSection(
    tag: 'starters-tandoori',
    matchTags: ['special-starters', 'tandoori', 'starter', 'starters', 'kebabs', 'kebab', 'tikka', 'chaap', 'malai tikka', 'achari tikka', 'paneer 65', 'cheese balls', 'seekh', 'momos', 'fries', 'spring roll'],
    title: 'Starters & Tandoori',
    emoji: '🍢',
    description: 'Soya Chaap, Paneer Tikka, Veg Seekh Kebab & Tandoori Treats',
  ),
  WebMenuSection(
    tag: 'roti-naan-breads',
    matchTags: ['roti-naan-kulcha', 'roti', 'naan', 'kulcha', 'breads', 'missi roti', 'lachha', 'tandoori roti', 'butter naan', 'garlic naan', 'paneer kulcha', 'stuffed'],
    title: 'Rotis, Naans & Kulchas',
    emoji: '🫓',
    description: 'Butter Naan, Garlic Naan, Tandoori Roti, Missi Roti & Stuffed Kulchas',
  ),
  WebMenuSection(
    tag: 'main-course',
    matchTags: ['curry', 'curries', 'gravy', 'gravies', 'dal-makhani', 'dal makhani', 'dal tadka', 'dal fry', 'butter masala', 'kadhai paneer', 'shahi paneer', 'paneer lababdar', 'paneer do pyaza', 'handi paneer', 'matar paneer', 'palak paneer', 'malai kofta', 'dum aloo', 'mix veg', 'chana masala', 'rajma', 'main-course', 'subji', 'sabji', 'kadhai', 'shahi', 'lababdar', 'handi'],
    title: 'Curries & Gravies',
    emoji: '🥘',
    description: 'Rich Paneer Butter Masala, Creamy Dal Makhani & Special Kadhai Gravies',
  ),
  WebMenuSection(
    tag: 'biryani-rice',
    matchTags: ['biryani-rice', 'biryani', 'pulav', 'fried-rice', 'jeera-rice', 'rice dishes', 'fried rice', 'jeera rice', 'steamed rice'],
    title: 'Biryani & Rice',
    emoji: '🍚',
    description: 'Aromatic basmati veg biryanis, paneer pulavs & loaded fried rice bowls',
  ),
  WebMenuSection(
    tag: 'pizzas-burgers',
    matchTags: ['burger', 'burgers', 'sandwich', 'sandwiches', 'pizza', 'pizzas', 'garlic-bread', 'frankie', 'roll', 'rolls'],
    title: 'Pizza, Burgers & Snacks',
    emoji: '🍕',
    description: 'Fresh baked pizzas, loaded veggie burgers & grilled sandwiches',
  ),
  WebMenuSection(
    tag: 'chinese-soups',
    matchTags: ['chinese', 'noodles', 'manchurian', 'chilli-paneer', 'chilli paneer', 'soup', 'soups', 'chowmein', 'pasta'],
    title: 'Chinese & Soups',
    emoji: '🥡',
    description: 'Stir-fried noodles, saucy veg manchurian, hot soups & pastas',
  ),
  WebMenuSection(
    tag: 'shakes-beverages',
    matchTags: ['shake', 'shakes', 'beverage', 'beverages', 'drinks', 'drink', 'cold-drink', 'mocktail', 'coffee', 'chai', 'tea', 'chilled', 'soda'],
    title: 'Shakes & Drinks',
    emoji: '🥤',
    description: 'Thick shakes, cold sodas, tea & coffee',
  ),
  WebMenuSection(
    tag: 'desserts',
    matchTags: ['dessert', 'desserts', 'ice-cream', 'ice cream', 'kulfi', 'sweet', 'sweets', 'gulab jamun', 'butterscotch', 'cup'],
    title: 'Desserts & Sweets',
    emoji: '🍦',
    description: 'Chilled premium desserts and traditional sweets',
  ),
];

String? getCategoryAssetImage(String tag) {
  const mapping = <String, String>{
    'all': 'assets/categories/cafe_all_menu_category.png',
    'hot-beverage': 'assets/categories/cafe_brews_category.png',
    'hot-bite': 'assets/categories/cafe_snacks_category.png',
    'sandwiches': 'assets/categories/cafe_sandwiches_category.png',
    'burgers': 'assets/categories/cafe_burgers_category.png',
    'frankie-rolls': 'assets/categories/cafe_rolls_category.png',
    'garlic-bread': 'assets/categories/cafe_garlic_bread_category.png',
    'pizza': 'assets/categories/cafe_pizza_category.png',
    'pizzas-burgers': 'assets/categories/cafe_pizza_category.png',
    'pav-bhaji': 'assets/categories/cafe_bombay_bites_category.png',
    'bombay-bites': 'assets/categories/cafe_bombay_bites_category.png',
    'chinese': 'assets/categories/cafe_chinese_category.png',
    'chinese-soups': 'assets/categories/cafe_chinese_category.png',
    'italian-pasta': 'assets/categories/cafe_pasta_category.png',
    'south-indian': 'assets/categories/cafe_south_indian_category.png',
    'rice-dishes': 'assets/categories/cafe_rice_category.png',
    'biryani-rice': 'assets/categories/cafe_rice_category.png',
    'main-course': 'assets/categories/cafe_south_indian_category.png',
    'roti-naan-breads': 'assets/categories/cafe_south_indian_category.png',
    'starters-tandoori': 'assets/categories/cafe_snacks_category.png',
    'breakfast': 'assets/categories/dairy_breakfast_category.png',
    'shakes': 'assets/categories/cafe_shakes_category.png',
    'shakes-beverages': 'assets/categories/cafe_shakes_category.png',
    'mocktails': 'assets/categories/cafe_mocktails_category.png',
    'cold-coffee': 'assets/categories/cafe_coffee_category.png',
    'chilled': 'assets/categories/cafe_cold_drinks_category.png',
    'beverages': 'assets/categories/cafe_cold_drinks_category.png',
    'desserts': 'assets/categories/ice_cream_category.png',
  };
  return mapping[tag.toLowerCase()];
}

class RenderedCategory {
  final String tag;
  final String title;
  final String emoji;
  final String? imageUrl;
  final List<Product> products;

  const RenderedCategory({
    required this.tag,
    required this.title,
    required this.emoji,
    this.imageUrl,
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

class _CafeMenuScreenState extends ConsumerState<CafeMenuScreen> with SingleTickerProviderStateMixin {
  String _activeCategoryTag = 'all';
  final bool _isVegOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final Map<String, bool> _collapsedSections = {};

  final ScrollController _horizontalCategoryController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  bool _isManualTabClick = false;

  static const Color primaryOrange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _horizontalCategoryController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _checkVisibleSection() {
    if (_isManualTabClick || _tabController.index != 0) return;

    String? foundActiveTag;
    for (final entry in _sectionKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;
      if (context != null) {
        final renderObj = context.findRenderObject();
        if (renderObj is RenderBox && renderObj.hasSize) {
          final pos = renderObj.localToGlobal(Offset.zero);
          // If section header is scrolled at or above the visible area threshold (~320px)
          if (pos.dy <= 320) {
            foundActiveTag = entry.key;
          }
        }
      }
    }

    final finalTag = foundActiveTag ?? 'all';
    if (finalTag != _activeCategoryTag) {
      setState(() => _activeCategoryTag = finalTag);
      _centerCategoryInHorizontalBar(finalTag);
    }
  }

  void _centerCategoryInHorizontalBar(String tag) {
    if (!_horizontalCategoryController.hasClients) return;

    final products = ref.read(restaurantMenuProvider(widget.restaurantId)).valueOrNull ?? [];
    final restaurantsList = ref.read(restaurantsProvider).valueOrNull ?? [];
    final currentRestaurant = widget.restaurant ??
        restaurantsList.cast<Restaurant?>().firstWhere((r) => r?.id == widget.restaurantId, orElse: () => null);

    final cats = _buildCategories(products, currentRestaurant);
    final index = cats.indexWhere((c) => c.tag == tag);
    if (index < 0) return;

    const itemWidth = 74.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetScroll = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    final maxScroll = _horizontalCategoryController.position.maxScrollExtent;
    final clampedScroll = targetScroll.clamp(0.0, maxScroll);

    _horizontalCategoryController.animateTo(
      clampedScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToSection(String tag) {
    HapticFeedback.selectionClick();
    setState(() => _activeCategoryTag = tag);
    _isManualTabClick = true;

    _centerCategoryInHorizontalBar(tag);

    final key = tag == 'all' ? _sectionKeys.values.firstOrNull : _sectionKeys[tag];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _isManualTabClick = false;
    });
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
        final img = map['imageUrl']?.toString() ?? map['image']?.toString();
        final matchTags = (map['matchTags'] is List)
            ? (map['matchTags'] as List).map((e) => e.toString()).toList()
            : <String>[];
        return WebMenuSection(
          tag: tag,
          title: title,
          emoji: emoji,
          imageUrl: img,
          description: desc,
          matchTags: matchTags,
        );
      }).toList();
    } else {
      final isCafe = _isCafeRestaurant(restaurant, widget.restaurantName, widget.restaurantId);
      baseSections = isCafe ? webCafeSections : webRestaurantSections;
    }

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
        if (assignedIds.contains(p.id)) return false;

        final pTags = p.tags.map((t) => t.toLowerCase().trim()).toList();
        final pCatSlug = (p.category?.slug ?? '').toLowerCase().trim();
        final pCatName = (p.category?.name ?? '').toLowerCase().trim();

        final matched = sec.matchTags.any((tag) {
          final t = tag.toLowerCase().trim();
          return pTags.contains(t) || pCatSlug == t || pCatName == t;
        }) || pTags.contains(secTagLower) || pCatSlug == secTagLower || pCatName == secTitleLower;

        if (matched) {
          assignedIds.add(p.id);
        }
        return matched;
      }).toList();

      if (secProducts.isNotEmpty) {
        String? catPhoto = sec.imageUrl;
        if (catPhoto == null || catPhoto.isEmpty) {
          final productWithImage = secProducts.firstWhere(
            (p) => p.imageUrl != null && p.imageUrl!.startsWith('http'),
            orElse: () => secProducts.first,
          );
          if (productWithImage.imageUrl != null && productWithImage.imageUrl!.startsWith('http')) {
            catPhoto = productWithImage.imageUrl;
          }
        }

        result.add(RenderedCategory(
          tag: sec.tag,
          title: sec.title,
          emoji: sec.emoji,
          imageUrl: catPhoto,
          products: secProducts,
        ));
      }
    }

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
        final tag = 'custom-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
        final firstImg = grpProducts.firstWhere((p) => p.imageUrl != null && p.imageUrl!.startsWith('http'), orElse: () => grpProducts.first).imageUrl;
        result.add(RenderedCategory(
          tag: tag,
          title: title,
          emoji: '🍳',
          imageUrl: firstImg,
          products: grpProducts,
        ));
      });
    }

    return [
      RenderedCategory(
        tag: 'all',
        title: 'All Items',
        emoji: '🍽️',
        imageUrl: restaurant?.logoUrl?.startsWith('http') == true ? restaurant!.logoUrl : null,
        products: filtered,
      ),
      ...result,
    ];
  }

  Widget _buildBannerImage(Restaurant? r) {
    final name = (r?.name ?? widget.restaurantName).toLowerCase();
    final banner = r?.bannerUrl;

    if (banner != null && banner.isNotEmpty) {
      if (banner.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: banner,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildFallbackBanner(name),
        );
      } else if (banner.startsWith('/')) {
        final assetName = banner.substring(1);
        return Image.asset(
          'assets/categories/$assetName',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackBanner(name),
        );
      }
    }
    return _buildFallbackBanner(name);
  }

  Widget _buildFallbackBanner(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wedson')) {
      return Image.asset(
        'assets/categories/wedson_restaurant_banner.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/categories/wedson_restaurant_bg.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
        ),
      );
    } else if (lower.contains('bal') || lower.contains('udyan')) {
      return Image.asset(
        'assets/categories/cafe_banner.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
      );
    }
    return Image.asset(
      'assets/categories/cafe_banner.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
    );
  }

  Widget _buildLogoWidget(Restaurant? r) {
    final name = (r?.name ?? widget.restaurantName).toLowerCase();
    final logo = r?.logoUrl;

    if (logo != null && logo.isNotEmpty) {
      if (logo.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: logo,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildFallbackLogo(name),
        );
      } else if (logo.startsWith('/')) {
        final assetName = logo.substring(1);
        return Image.asset(
          'assets/categories/$assetName',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackLogo(name),
        );
      }
    }
    return _buildFallbackLogo(name);
  }

  Widget _buildFallbackLogo(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wedson')) {
      return Image.asset(
        'assets/categories/wedson_restaurant_bg.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/categories/wedson_restaurant_banner.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Text('🍽️', style: TextStyle(fontSize: 24))),
        ),
      );
    } else if (lower.contains('a.s') || lower.contains('as-')) {
      return Image.asset(
        'assets/categories/cafe_all_menu_category.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('☕', style: TextStyle(fontSize: 24))),
      );
    } else if (lower.contains('bal') || lower.contains('udyan')) {
      return Image.asset(
        'assets/categories/cafe_category.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('🍲', style: TextStyle(fontSize: 24))),
      );
    }
    return Image.asset(
      'assets/categories/cafe_category.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(child: Text('🍽️', style: TextStyle(fontSize: 24))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final reviewsAsync = ref.watch(restaurantReviewsProvider(widget.restaurantId));
    final restaurantsList = ref.watch(restaurantsProvider).valueOrNull ?? [];
    final currentRestaurant = widget.restaurant ??
        restaurantsList.cast<Restaurant?>().firstWhere((r) => r?.id == widget.restaurantId, orElse: () => null);

    final cart = ref.watch(cartProvider).value;
    final cartCount = cart?.totalItems ?? 0;
    final cartSubtotal = cart?.subtotal ?? 0.0;

    final restaurantName = currentRestaurant?.name ?? widget.restaurantName;
    final description = currentRestaurant?.description;
    final ratingVal = currentRestaurant?.rating ?? 4.5;
    final totalReviews = reviewsAsync.valueOrNull?['totalCount'] ?? currentRestaurant?.totalRatings ?? 8;
    final deliveryTime = currentRestaurant?.deliveryTime ?? 'Hot & Fresh';
    final cuisineTags = currentRestaurant?.cuisineTags ?? ['BURGERS', 'BEVERAGES', 'SHAKES', 'PIZZA'];
    final isPureVeg = currentRestaurant?.isPureVeg ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ─── 1. HERO SLIVER APP BAR (White & Clean on Collapse, Rich on Expand) ───
              SliverAppBar(
                pinned: true,
                expandedHeight: 210,
                backgroundColor: Colors.white,
                elevation: innerBoxIsScrolled ? 0.5 : 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: innerBoxIsScrolled ? Colors.transparent : Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: innerBoxIsScrolled ? const Color(0xFF0F172A) : Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: innerBoxIsScrolled ? Colors.transparent : Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.search_rounded,
                        color: innerBoxIsScrolled ? const Color(0xFF0F172A) : Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _buildSearchSheet(),
                        );
                      },
                    ),
                  ),
                ],
                centerTitle: true,
                title: innerBoxIsScrolled
                    ? Text(
                        restaurantName,
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      )
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildBannerImage(currentRestaurant),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.82),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _buildLogoWidget(currentRestaurant),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          restaurantName,
                                          style: GoogleFonts.inter(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (description != null && description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            description,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ...cuisineTags.take(4).map((tag) => Padding(
                                      padding: const EdgeInsets.only(right: 5),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tag.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    )),
                                    if (isPureVeg)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00B140).withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF4ADE80), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.eco_rounded, size: 10, color: Color(0xFF4ADE80)),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Pure Veg',
                                              style: GoogleFonts.inter(
                                                fontSize: 9.5,
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
                      ),
                    ],
                  ),
                ),
              ),

              // ─── 2. RATING STRIP ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
                              ratingVal > 0 ? ratingVal.toStringAsFixed(1) : "4.5",
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($totalReviews reviews)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── 3. MENU / REVIEWS TAB BAR ───
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryOrange,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: primaryOrange,
                    unselectedLabelColor: const Color(0xFF9CA3AF),
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [
                      const Tab(text: 'MENU'),
                      Tab(text: 'REVIEWS ($totalReviews)'),
                    ],
                  ),
                ),
              ),

              // ─── 4. PINNED CATEGORY CHIPS BAR (Pinned cleanly below AppBar when scrolled!) ───
              if (_tabController.index == 0)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryChipsDelegate(
                    horizontalController: _horizontalCategoryController,
                    menuAsync: menuAsync,
                    currentRestaurant: currentRestaurant,
                    activeCategoryTag: _activeCategoryTag,
                    buildCategories: (prods) => _buildCategories(prods, currentRestaurant),
                    onCategoryTap: (tag) => _scrollToSection(tag),
                  ),
                ),
            ],

            // ─── 5. BODY: MENU or REVIEWS ───
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMenuTab(menuAsync, currentRestaurant, isPureVeg),
                _buildReviewsTab(reviewsAsync),
              ],
            ),
          ),

          // ─── 6. STICKY CART BAR (Unified Exact Homepage Design) ───
          FloatingCartBar(bottomOffset: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    ),
  );
  }

  // ═══════════════════════════════════════════════════════
  // MENU TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildMenuTab(AsyncValue<List<Product>> menuAsync, Restaurant? currentRestaurant, bool isPureVeg) {
    return menuAsync.when(
      data: (products) {
        final renderedCats = _buildCategories(products, currentRestaurant);
        final totalItems = products.length;
        final sections = renderedCats.where((c) => c.tag != 'all').toList();

        for (final sec in sections) {
          _sectionKeys.putIfAbsent(sec.tag, () => GlobalKey());
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _checkVisibleSection();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Items Count Bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFFFF7ED),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$totalItems ITEMS',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: primaryOrange),
                      ),
                      if (isPureVeg)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌿', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 3),
                              Text(
                                '100% Pure Veg Kitchen',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Sections with collapsible headers
              for (final section in sections) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(section),
                ),
                if (!(_collapsedSections[section.tag] ?? false))
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, tablet: 3, desktop: 4),
                        childAspectRatio: Responsive.gridAspectRatio(context, smallMobile: 0.62, mobile: 0.64, tablet: 0.70, desktop: 0.76),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ProductCard(
                          product: section.products[index],
                          isCompact: true,
                          showOutlet: false,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              FadeSlideRoute(page: ProductDetailScreen(product: section.products[index])),
                            );
                          },
                        ),
                        childCount: section.products.length,
                      ),
                    ),
                  ),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
            ],
          ),
        );
      },
      loading: () => _buildShimmerGrid(),
      error: (_, __) => const Center(child: Text('Failed to load menu items')),
    );
  }

  bool _isVegProduct(Product product) {
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

  void _handleDishAddToCart(BuildContext context, Product product) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant != null) {
      final groceryCount = ref.read(cartProvider.notifier).groceryItemsCount;
      final newOutlet = getOutletName(product);
      CartConflictDialog.show(
        context,
        product: product,
        existingOutletName: conflictRestaurant,
        groceryItemsCount: groceryCount,
        onConfirm: () {
          ref.read(cartProvider.notifier).replaceRestaurantItemsWith(product, 1);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groceryCount > 0
                          ? 'Switched to $newOutlet. $groceryCount grocery item(s) kept safe in cart! 🛒'
                          : 'Switched to $newOutlet! 🍽️',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addProduct(product, 1);
  }

  void _handleDishIncrement(BuildContext context, Product product) {
    final conflictRestaurant = ref.read(cartProvider.notifier).checkRestaurantConflict(product);
    if (conflictRestaurant != null) {
      _handleDishAddToCart(context, product);
      return;
    }
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).increment(product);
  }

  Widget _buildRestaurantDishItem(Product product) {
    final cart = ref.watch(cartProvider).value;
    final items = cart?.items.where((i) => i.productId == product.id).toList() ?? [];
    final inCartQty = items.fold<int>(0, (s, i) => s + i.quantity);
    final isVeg = _isVegProduct(product);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          FadeSlideRoute(page: ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Content: Veg badge, Title, Price, Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
                              color: isVeg ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                      if (product.isBestSeller || product.isTopPick) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 8)),
                              const SizedBox(width: 2),
                              Text(
                                'Bestseller',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
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
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.description != null && product.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      product.description!.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Image + Layered ADD Button
            SizedBox(
              width: 106,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 106,
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _buildDishImage(product),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: _buildDishAddButton(product, inCartQty),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishImage(Product product) {
    var imgUrl = product.imageUrl?.trim() ?? '';
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('/')) {
        imgUrl = 'https://www.fastkirana.in$imgUrl';
      }
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFF1F5F9),
          highlightColor: const Color(0xFFFAFAFA),
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => Center(
          child: Text(
            _getEmojiForDish(product.name),
            style: const TextStyle(fontSize: 34),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _getEmojiForDish(product.name),
        style: const TextStyle(fontSize: 34),
      ),
    );
  }

  String _getEmojiForDish(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('sandwich')) return '🥪';
    if (lower.contains('roll') || lower.contains('frankie')) return '🌯';
    if (lower.contains('momo') || lower.contains('spring roll')) return '🥟';
    if (lower.contains('fries') || lower.contains('finger')) return '🍟';
    if (lower.contains('pasta') || lower.contains('noodle')) return '🍝';
    if (lower.contains('dosa') || lower.contains('idli')) return '🥞';
    if (lower.contains('biryani') || lower.contains('rice')) return '🍚';
    if (lower.contains('paneer') || lower.contains('curry') || lower.contains('dal')) return '🥘';
    if (lower.contains('roti') || lower.contains('naan')) return '🫓';
    if (lower.contains('tea') || lower.contains('chai') || lower.contains('coffee')) return '☕';
    if (lower.contains('shake')) return '🥤';
    if (lower.contains('ice cream') || lower.contains('dessert')) return '🍨';
    return '🍽️';
  }

  Widget _buildDishAddButton(Product product, int inCartQty) {
    final isClosed = widget.restaurant?.isOpen == false;
    if (isClosed) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.restaurantName} is currently closed for new orders.',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              'CLOSED',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    if (inCartQty > 0) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).decrement(product.id);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.remove_rounded, color: Colors.white, size: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$inCartQty',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleDishIncrement(context, product),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleDishAddToCart(context, product),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADD',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.add_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(RenderedCategory section) {
    final isCollapsed = _collapsedSections[section.tag] ?? false;
    return Container(
      key: _sectionKeys[section.tag],
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _collapsedSections[section.tag] = !isCollapsed);
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${section.title.toUpperCase()} SPECIALS',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Text(
              '${section.products.length} Items',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 8),
            Text(
              isCollapsed ? 'Expand' : 'Collapse',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: primaryOrange),
            ),
            Icon(
              isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              size: 16,
              color: primaryOrange,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // REVIEWS TAB (Real Data from API & DB)
  // ═══════════════════════════════════════════════════════
  Widget _buildReviewsTab(AsyncValue<Map<String, dynamic>> reviewsAsync) {
    return reviewsAsync.when(
      data: (data) {
        final reviews = data['reviews'] as List? ?? [];
        final totalCount = data['totalCount'] ?? reviews.length;
        final avgRating = data['averageRating'] ?? 4.5;

        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to review!',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: AddReviewScreen(
                          productName: widget.restaurantName,
                          restaurantId: widget.restaurantId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Write a Review',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: reviews.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$avgRating',
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                        ),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: i < (avgRating is num ? avgRating.round() : 4) ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalCount reviews',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(
                            page: AddReviewScreen(
                              productName: widget.restaurantName,
                              restaurantId: widget.restaurantId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Write Review',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final review = reviews[index - 1];
            final user = review['user'] as Map<String, dynamic>?;
            final rating = review['rating'] ?? 5;
            final comment = review['comment'] ?? '';
            final createdAt = review['createdAt'] ?? '';
            final userName = user?['name'] ?? 'Customer';

            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            Row(
                              children: List.generate(5, (i) => Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: i < rating ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
                              )),
                            ),
                          ],
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF)),
                        ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF475569), height: 1.4),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))),
      error: (_, __) => const Center(child: Text('Failed to load reviews')),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildSearchSheet() {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEA580C))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.76,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const ProductCardSkeleton();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// PINNED CATEGORY CHIPS DELEGATE (Circular Icons with Real Photos & Auto-Centering)
// ═══════════════════════════════════════════════════════
class _CategoryChipsDelegate extends SliverPersistentHeaderDelegate {
  final ScrollController horizontalController;
  final AsyncValue<List<Product>> menuAsync;
  final Restaurant? currentRestaurant;
  final String activeCategoryTag;
  final List<RenderedCategory> Function(List<Product>) buildCategories;
  final Function(String) onCategoryTap;

  _CategoryChipsDelegate({
    required this.horizontalController,
    required this.menuAsync,
    required this.currentRestaurant,
    required this.activeCategoryTag,
    required this.buildCategories,
    required this.onCategoryTap,
  });

  @override
  double get maxExtent => 96;

  @override
  double get minExtent => 96;

  @override
  bool shouldRebuild(covariant _CategoryChipsDelegate oldDelegate) {
    return activeCategoryTag != oldDelegate.activeCategoryTag ||
        menuAsync != oldDelegate.menuAsync;
  }

  Widget _buildCategoryThumbnail(RenderedCategory cat) {
    if (cat.imageUrl != null && cat.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: cat.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 18))),
        errorWidget: (_, __, ___) => _buildLocalAssetOrEmoji(cat),
      );
    }
    return _buildLocalAssetOrEmoji(cat);
  }

  Widget _buildLocalAssetOrEmoji(RenderedCategory cat) {
    final asset = getCategoryAssetImage(cat.tag);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 20))),
      );
    }
    return Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 20)));
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: menuAsync.when(
        data: (products) {
          final cats = buildCategories(products);
          return SizedBox(
            height: 96,
            child: ListView.separated(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final cat = cats[index];
                final isSelected = activeCategoryTag == cat.tag;

                return GestureDetector(
                  onTap: () => onCategoryTap(cat.tag),
                  child: SizedBox(
                    width: 68,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: _buildCategoryThumbnail(cat),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cat.title,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const SizedBox(height: 96),
        error: (_, __) => const SizedBox(height: 96),
      ),
    );
  }
}