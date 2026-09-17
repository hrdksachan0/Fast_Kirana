import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/product.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/restaurant.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../core/utils/restaurant_utils.dart';
import '../products/product_detail_screen.dart';
import '../profile/add_review_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/coupon.dart';
import '../../providers/coupon_provider.dart';

class WebMenuSection {
  final String? id;
  final String tag;
  final List<String> matchTags;
  final String title;
  final String emoji;
  final String? imageUrl;
  final String description;

  const WebMenuSection({
    this.id,
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
  if (tag.isEmpty) return null;
  final clean = tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  const mapping = <String, String>{
    'all': 'assets/categories/cafe_all_menu_category.webp',
    'hotbeverage': 'assets/categories/cafe_brews_category.webp',
    'hotbeverages': 'assets/categories/cafe_brews_category.webp',
    'brews': 'assets/categories/cafe_brews_category.webp',
    'brew': 'assets/categories/cafe_brews_category.webp',
    'tea': 'assets/categories/cafe_brews_category.webp',
    'chai': 'assets/categories/cafe_brews_category.webp',
    'hotbite': 'assets/categories/cafe_snacks_category.webp',
    'hotbites': 'assets/categories/cafe_snacks_category.webp',
    'snack': 'assets/categories/cafe_snacks_category.webp',
    'snacks': 'assets/categories/cafe_snacks_category.webp',
    'quickbites': 'assets/categories/cafe_snacks_category.webp',
    'momos': 'assets/categories/cafe_snacks_category.webp',
    'momo': 'assets/categories/cafe_snacks_category.webp',
    'fries': 'assets/categories/cafe_snacks_category.webp',
    'sandwich': 'assets/categories/cafe_sandwiches_category.webp',
    'sandwiches': 'assets/categories/cafe_sandwiches_category.webp',
    'burger': 'assets/categories/cafe_burgers_category.webp',
    'burgers': 'assets/categories/cafe_burgers_category.webp',
    'frankierolls': 'assets/categories/cafe_rolls_category.webp',
    'frankieroll': 'assets/categories/cafe_rolls_category.webp',
    'rolls': 'assets/categories/cafe_rolls_category.webp',
    'roll': 'assets/categories/cafe_rolls_category.webp',
    'garlicbread': 'assets/categories/cafe_garlic_bread_category.webp',
    'garlicbreads': 'assets/categories/cafe_garlic_bread_category.webp',
    'garlic': 'assets/categories/cafe_garlic_bread_category.webp',
    'pizza': 'assets/categories/cafe_pizza_category.webp',
    'pizzas': 'assets/categories/cafe_pizza_category.webp',
    'pizzasburgers': 'assets/categories/cafe_pizza_category.webp',
    'calzone': 'assets/categories/cafe_pizza_category.webp',
    'calzones': 'assets/categories/cafe_pizza_category.webp',
    'maggie': 'assets/categories/cafe_chinese_category.webp',
    'maggi': 'assets/categories/cafe_chinese_category.webp',
    'pavbhaji': 'assets/categories/cafe_bombay_bites_category.webp',
    'bombaybites': 'assets/categories/cafe_bombay_bites_category.webp',
    'chinese': 'assets/categories/cafe_chinese_category.webp',
    'chinesesoups': 'assets/categories/cafe_chinese_category.webp',
    'noodles': 'assets/categories/cafe_chinese_category.webp',
    'chowmein': 'assets/categories/cafe_chinese_category.webp',
    'manchurian': 'assets/categories/cafe_chinese_category.webp',
    'italianpasta': 'assets/categories/cafe_pasta_category.webp',
    'pasta': 'assets/categories/cafe_pasta_category.webp',
    'pastas': 'assets/categories/cafe_pasta_category.webp',
    'southindian': 'assets/categories/cafe_south_indian_category.webp',
    'dosa': 'assets/categories/cafe_south_indian_category.webp',
    'ricedishes': 'assets/categories/cafe_rice_category.webp',
    'rice': 'assets/categories/cafe_rice_category.webp',
    'biryanirice': 'assets/categories/cafe_rice_category.webp',
    'biryani': 'assets/categories/cafe_rice_category.webp',
    'maincourse': 'assets/categories/cafe_south_indian_category.webp',
    'curries': 'assets/categories/cafe_south_indian_category.webp',
    'rotinaanbreads': 'assets/categories/cafe_south_indian_category.webp',
    'starterstandoori': 'assets/categories/cafe_snacks_category.webp',
    'starters': 'assets/categories/cafe_snacks_category.webp',
    'breakfast': 'assets/categories/dairy_breakfast_category.webp',
    'shakes': 'assets/categories/cafe_shakes_category.webp',
    'shake': 'assets/categories/cafe_shakes_category.webp',
    'shakesbeverages': 'assets/categories/cafe_shakes_category.webp',
    'mocktails': 'assets/categories/cafe_mocktails_category.webp',
    'mocktail': 'assets/categories/cafe_mocktails_category.webp',
    'mocktailsshakes': 'assets/categories/cafe_mocktails_category.webp',
    'coldcoffee': 'assets/categories/cafe_coffee_category.webp',
    'coffee': 'assets/categories/cafe_coffee_category.webp',
    'chilled': 'assets/categories/cafe_cold_drinks_category.webp',
    'beverages': 'assets/categories/cafe_cold_drinks_category.webp',
    'beverage': 'assets/categories/cafe_cold_drinks_category.webp',
    'chilleddrinks': 'assets/categories/cafe_cold_drinks_category.webp',
    'drinks': 'assets/categories/cafe_cold_drinks_category.webp',
    'drink': 'assets/categories/cafe_cold_drinks_category.webp',
    'lassi': 'assets/categories/cafe_shakes_category.webp',
    'desserts': 'assets/categories/ice_cream_category.webp',
    'dessert': 'assets/categories/ice_cream_category.webp',
    'icecream': 'assets/categories/ice_cream_category.webp',
    'icecreams': 'assets/categories/ice_cream_category.webp',
  };
  return mapping[clean];
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

  static const Color primaryOrange = AppDesignSystem.orange600;

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
      baseSections = restaurant.menuSections!.map((s) {
        final map = s is Map ? s : <String, dynamic>{};
        final id = map['id']?.toString();
        final tag = map['tag']?.toString() ?? id ?? 'section';
        final title = map['title']?.toString() ?? map['name']?.toString() ?? 'Menu Section';
        final emoji = map['emoji']?.toString() ?? '🍽️';
        final desc = map['description']?.toString() ?? '';
        final img = map['imageUrl']?.toString() ?? map['image']?.toString();
        final matchTags = (map['matchTags'] is List)
            ? (map['matchTags'] as List).map((e) => e.toString()).toList()
            : <String>[];
        return WebMenuSection(
          id: id,
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
      baseSections = isCafe ? List.of(webCafeSections) : List.of(webRestaurantSections);
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
      final secIdLower = (sec.id ?? '').toLowerCase().trim();
      final secTagLower = sec.tag.toLowerCase().trim();
      final secTitleLower = sec.title.toLowerCase().trim();

      final secProducts = filtered.where((p) {
        if (assignedIds.contains(p.id)) return false;

        final pTags = p.tags.map((t) => t.toLowerCase().trim()).toList();
        final pCatSlug = (p.category?.slug ?? '').toLowerCase().trim();
        final pCatName = (p.category?.name ?? '').toLowerCase().trim();
        final pMenuSec = (p.menuSection ?? '').toLowerCase().trim();
        final pName = p.name.toLowerCase().trim();

        final matched = (secIdLower.isNotEmpty && pTags.contains(secIdLower)) ||
            (secIdLower.isNotEmpty && pMenuSec == secIdLower) ||
            (secTagLower.isNotEmpty && pTags.contains(secTagLower)) ||
            (secTagLower.isNotEmpty && pMenuSec == secTagLower) ||
            (secTitleLower.isNotEmpty && pMenuSec == secTitleLower) ||
            sec.matchTags.any((tag) {
              final t = tag.toLowerCase().trim();
              return pTags.contains(t) || pCatSlug == t || pCatName == t || pName.contains(t);
            }) ||
            pCatSlug == secTagLower ||
            pCatName == secTitleLower ||
            (secTagLower.isNotEmpty && secTagLower != 'section' && pName.contains(secTagLower));

        if (matched) {
          assignedIds.add(p.id);
        }
        return matched;
      }).toList();

      if (secProducts.isNotEmpty) {
        // Sort: In-stock dishes first, out-of-stock dishes at the end
        secProducts.sort((a, b) {
          final aInStock = a.isAvailable && a.stock > 0;
          final bInStock = b.isAvailable && b.stock > 0;
          if (aInStock && !bInStock) return -1;
          if (!aInStock && bInStock) return 1;
          return 0;
        });

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
        // Sort: In-stock dishes first, out-of-stock dishes at the end
        grpProducts.sort((a, b) {
          final aInStock = a.isAvailable && a.stock > 0;
          final bInStock = b.isAvailable && b.stock > 0;
          if (aInStock && !bInStock) return -1;
          if (!aInStock && bInStock) return 1;
          return 0;
        });

        final tag = 'custom-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
        final firstImg = grpProducts.firstWhere((p) => p.imageUrl != null && p.imageUrl!.startsWith('http'), orElse: () => grpProducts.first).imageUrl;
        final tLower = title.toLowerCase();
        String emoji = '🍳';
        if (tLower.contains('drink') || tLower.contains('beverage') || tLower.contains('cold') || tLower.contains('soda')) {
          emoji = '🥤';
        } else if (tLower.contains('ice') || tLower.contains('cream') || tLower.contains('dessert') || tLower.contains('sweet') || tLower.contains('kulfi')) {
          emoji = '🍦';
        }
        result.add(RenderedCategory(
          tag: tag,
          title: title,
          emoji: emoji,
          imageUrl: firstImg,
          products: grpProducts,
        ));
      });
    }

    // Sort full filtered list as well
    filtered.sort((a, b) {
      final aInStock = a.isAvailable && a.stock > 0;
      final bInStock = b.isAvailable && b.stock > 0;
      if (aInStock && !bInStock) return -1;
      if (!aInStock && bInStock) return 1;
      return 0;
    });

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

  static const Set<String> _bundledCategoryAssets = {
    'as_restaurant_banner.webp',
    'wedson_restaurant_bg.webp',
    'wedson_restaurant_banner.webp',
    'cafe_all_menu_category.webp',
    'cafe_banner.webp',
    'food_banner_bg.webp',
    'food_promo_banner.webp',
    'food_promo_banner_premium.webp',
    'cafe_category.webp',
    'dairy_breakfast_category.webp',
  };

  Widget _buildRestaurantBanner(Restaurant? r) {
    final effectiveRestaurant = r ?? RestaurantRegistry.find(widget.restaurantId);
    final banner = effectiveRestaurant?.bannerUrl;

    if (banner != null && banner.isNotEmpty) {
      if (banner.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: banner,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 400,
          errorWidget: (_, __, ___) => _buildFallbackBanner(),
        );
      } else if (banner.startsWith('/')) {
        final assetName = banner.substring(1);
        final webpName = assetName.endsWith('.png') ? '${assetName.substring(0, assetName.length - 4)}.webp' : assetName;
        if (_bundledCategoryAssets.contains(webpName)) {
          return Image.asset(
            'assets/categories/$webpName',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackBanner(),
          );
        }
        return CachedNetworkImage(
          imageUrl: 'https://www.fastkirana.in$banner',
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 400,
          errorWidget: (_, __, ___) => _buildFallbackBanner(),
        );
      }
    }
    return _buildFallbackBanner();
  }

  Widget _buildFallbackBanner() {
    return Image.asset(
      'assets/categories/food_banner_bg.webp',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppDesignSystem.gray800),
    );
  }

  Widget _buildLogoWidget(Restaurant? r) {
    final effectiveRestaurant = r ?? RestaurantRegistry.find(widget.restaurantId);
    final logo = effectiveRestaurant?.logoUrl;

    if (logo != null && logo.isNotEmpty) {
      if (logo.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: logo,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          memCacheHeight: 200,
          errorWidget: (_, __, ___) => _buildFallbackLogo(),
        );
      } else if (logo.startsWith('/')) {
        final assetName = logo.substring(1);
        if (_bundledCategoryAssets.contains(assetName)) {
          return Image.asset(
            'assets/categories/$assetName',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackLogo(),
          );
        }
        return CachedNetworkImage(
          imageUrl: 'https://www.fastkirana.in$logo',
          fit: BoxFit.cover,
          memCacheWidth: 200,
          memCacheHeight: 200,
          errorWidget: (_, __, ___) => _buildFallbackLogo(),
        );
      }
    }
    return _buildFallbackLogo();
  }

  Widget _buildFallbackLogo() {
    return Image.asset(
      'assets/categories/cafe_category.webp',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(child: Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final reviewsAsync = ref.watch(restaurantReviewsProvider(widget.restaurantId));
    final restaurantsList = ref.watch(restaurantsProvider).valueOrNull ?? [];
    final currentRestaurant = widget.restaurant ??
        restaurantsList.cast<Restaurant?>().firstWhere((r) => r?.id == widget.restaurantId, orElse: () => null);

    final restaurantName = currentRestaurant?.name ?? widget.restaurantName;
    final description = currentRestaurant?.description;
    final ratingVal = currentRestaurant?.rating ?? 4.5;
    final totalReviews = reviewsAsync.valueOrNull?['totalCount'] ?? currentRestaurant?.totalRatings ?? 8;
    final cuisineTags = currentRestaurant?.cuisineTags ?? ['BURGERS', 'BEVERAGES', 'SHAKES', 'PIZZA'];
    final isPureVeg = currentRestaurant?.isPureVeg ?? true;

    return Scaffold(
      backgroundColor: AppDesignSystem.gray50,
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
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: innerBoxIsScrolled
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
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
                      color: innerBoxIsScrolled ? AppDesignSystem.slate900 : Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  // 1. Search Action
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: innerBoxIsScrolled ? Colors.transparent : Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.search_rounded,
                        color: innerBoxIsScrolled ? AppDesignSystem.slate900 : Colors.white,
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
                  // 2. Share Menu Action
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8, left: 4),
                    decoration: BoxDecoration(
                      color: innerBoxIsScrolled ? Colors.transparent : Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.share_rounded,
                        color: innerBoxIsScrolled ? AppDesignSystem.slate900 : Colors.white,
                        size: 19,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final shareUrl = 'https://fastkirana.in/cafe';
                        final shareText = '🍔 Craving delicious food? Check out the fresh menu of $restaurantName on FastKirana!\nOrder online for fast express delivery: $shareUrl';
                        Share.share(shareText, subject: '$restaurantName Menu - FastKirana');
                      },
                    ),
                  ),
                ],
                centerTitle: true,
                title: innerBoxIsScrolled
                    ? Text(
                        restaurantName,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                          letterSpacing: -0.2,
                        ),
                      )
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildRestaurantBanner(currentRestaurant),
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
                          padding: EdgeInsets.fromLTRB(
                            Responsive.horizontalPadding(context),
                            Responsive.isSmallMobile(context) ? 36 : 44,
                            Responsive.horizontalPadding(context),
                            14,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: Responsive.isSmallMobile(context) ? 44 : 56,
                                    height: Responsive.isSmallMobile(context) ? 44 : 56,
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
                                            fontSize: Responsive.scaledFontSize(context, 19),
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
                                              fontSize: Responsive.scaledFontSize(context, 11),
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
                                            fontSize: Responsive.scaledFontSize(context, 9.5),
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
                                          color: AppDesignSystem.accent.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppDesignSystem.green400, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.eco_rounded, size: 10, color: AppDesignSystem.green400),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Pure Veg',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                                fontWeight: FontWeight.w800,
                                                color: AppDesignSystem.green400,
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

              // ─── 2. RATING STRIP & HIGH RUSH BADGE ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              ratingVal > 0 ? ratingVal.toStringAsFixed(1) : "4.5",
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($totalReviews reviews)',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: AppDesignSystem.textSecondary),
                      ),
                      if ((currentRestaurant != null && currentRestaurant.activeOrdersCount >= 6) ||
                          currentRestaurant?.discountBadge?.toUpperCase().contains('RUSH') == true ||
                          currentRestaurant?.discountBadge?.toUpperCase().contains('BUSY') == true) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'HIGH DEMAND (NO SURGE FEE)',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── 2.5 RESTAURANT OFFERS / BOGO TICKETS STRIP ───
              _buildRestaurantOffersStrip(currentRestaurant),

              // ─── 3. MENU / REVIEWS TAB BAR ───
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppDesignSystem.border, width: 1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryOrange,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: primaryOrange,
                    unselectedLabelColor: AppDesignSystem.textTertiary,
                    labelStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, letterSpacing: 0.3),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600),
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
                  color: AppDesignSystem.orange50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$totalItems ITEMS',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w900, color: primaryOrange),
                      ),
                      if (isPureVeg)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.green50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.emerald200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🌿', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                              const SizedBox(width: 3),
                              Text(
                                '100% Pure Veg Kitchen',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: AppDesignSystem.emerald700),
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
                        childAspectRatio: Responsive.gridAspectRatio(context, smallMobile: 0.64, mobile: 0.66, tablet: 0.70, desktop: 0.75),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ProductCard(
                          product: section.products[index],
                          isCompact: false,
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

              // Frequently Ordered Together: Chilled Drinks & Ice Creams Recommendations
              if (_searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: _buildDarkstoreRecommendationsSection(),
                ),

              SliverPadding(padding: EdgeInsets.only(bottom: 180 + MediaQuery.of(context).padding.bottom)),
            ],
          ),
        );
      },
      loading: () => _buildShimmerGrid(),
      error: (_, __) => const Center(child: Text('Failed to load menu items')),
    );
  }

  Widget _buildDarkstoreRecommendationsSection() {
    return ref.watch(restaurantAddonsProvider).when(
      data: (addons) {
        if (addons.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('🥤🍦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Frequently ordered together',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate800,
                            ),
                          ),
                          Text(
                            'Chilled drinks & sweet desserts from Darkstore',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'Slide for more →',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w600,
                      color: primaryOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addons.length,
                  itemBuilder: (context, idx) {
                    final p = addons[idx];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 10),
                      child: ProductCard(
                        product: p,
                        isCompact: true,
                        showOutlet: false,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            FadeSlideRoute(page: ProductDetailScreen(product: p)),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Text(
              '${section.products.length} Items',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: AppDesignSystem.textTertiary),
            ),
            const SizedBox(width: 8),
            Text(
              isCollapsed ? 'Expand' : 'Collapse',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w700, color: primaryOrange),
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
                Text('⭐', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48))),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w700, color: AppDesignSystem.slate600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to review!',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate400),
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
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white),
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
                  border: Border.all(color: AppDesignSystem.slate100),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$avgRating',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 32), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                        ),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: i < (avgRating is num ? avgRating.round() : 4) ? AppDesignSystem.warning : AppDesignSystem.border,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalCount reviews',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: AppDesignSystem.textTertiary),
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
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white),
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
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppDesignSystem.slate100,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.slate600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.slate900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: List.generate(5, (i) => Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: i < rating ? AppDesignSystem.warning : AppDesignSystem.border,
                              )),
                            ),
                          ],
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), color: AppDesignSystem.textTertiary),
                        ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w500, color: AppDesignSystem.slate600, height: 1.4),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.orange600)),
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
    } catch (e) { LoggerService.error('CafeMenuScreen: silent catch', e);
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
            decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.slate400),
              prefixIcon: const Icon(Icons.search_rounded, color: AppDesignSystem.slate400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close_rounded, color: AppDesignSystem.slate400),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.orange600)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.slate900),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 12, Responsive.horizontalPadding(context), 90),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5),
        childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: true),
        crossAxisSpacing: Responsive.horizontalPadding(context) * 0.5,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const ProductCardSkeleton();
      },
    );
  }


  Widget _buildRestaurantOffersStrip(Restaurant? currentRestaurant) {
    final couponsAsync = ref.watch(restaurantCouponsProvider(widget.restaurantId));

    return SliverToBoxAdapter(
      child: couponsAsync.when(
        data: (coupons) {
          final activeCoupons = coupons.where((c) => c.isValid).toList();
          final hasOffer = currentRestaurant?.discountOffer != null && currentRestaurant!.discountOffer!.trim().isNotEmpty;

          if (activeCoupons.isEmpty && !hasOffer) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('🎟️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        'OFFERS & DEALS FOR YOU',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (activeCoupons.isNotEmpty)
                        ...activeCoupons.map((coupon) => _buildOfferTicketCard(coupon))
                      else if (hasOffer)
                        _buildFallbackOfferTicket(currentRestaurant!.discountOffer!),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOfferTicketCard(Coupon coupon) {
    final isBogo = coupon.isBogo;
    final isFreeDelivery = coupon.discountType == DiscountType.freeDelivery;

    String title;
    if (coupon.badgeText != null && coupon.badgeText!.isNotEmpty) {
      title = coupon.badgeText!;
    } else if (isBogo) {
      if (coupon.bogoType == 'BUY_LARGE_GET_SMALL') {
        title = 'BUY ${(coupon.triggerVariant ?? 'LARGE').toUpperCase()} GET ${(coupon.rewardVariant ?? 'SMALL').toUpperCase()} FREE';
      } else if (coupon.bogoType == 'CHEAPEST_FREE') {
        title = 'BUY 2+, CHEAPEST ITEM FREE';
      } else {
        title = 'BUY 1 GET 1 FREE';
      }
    } else if (isFreeDelivery) {
      title = '100% FREE DELIVERY';
    } else if (coupon.discountType == DiscountType.percent) {
      title = 'FLAT ${coupon.value.toInt()}% OFF';
    } else {
      title = 'FLAT ₹${coupon.value.toInt()} OFF';
    }

    String subtitle;
    if (coupon.autoApply) {
      subtitle = '⚡ Auto-applied in cart • ${coupon.code}';
    } else if (coupon.minOrder > 0) {
      subtitle = 'Min order ₹${coupon.minOrder.toInt()} • Use ${coupon.code}';
    } else {
      subtitle = 'Code: ${coupon.code} • Tap to copy';
    }

    final accentColor = isBogo
        ? const Color(0xFFEA580C)
        : isFreeDelivery
            ? AppDesignSystem.emerald600
            : AppDesignSystem.primary;

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: coupon.code));
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: accentColor,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Copied "${coupon.code}"! Apply at checkout.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBogo ? const Color(0xFFFDBA74) : AppDesignSystem.slate200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isBogo
                    ? const Color(0xFFFFF7ED)
                    : isFreeDelivery
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBogo
                      ? const Color(0xFFFDBA74)
                      : isFreeDelivery
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFBFDBFE),
                ),
              ),
              child: Center(
                child: Text(
                  isBogo ? '🔥' : isFreeDelivery ? '🚚' : '🏷️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackOfferTicket(String offerText) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(const ClipboardData(text: 'BOGO'));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEA580C),
            content: Text('🔥 Offer "$offerText" available at checkout!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offerText.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEA580C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⚡ Auto-applied at checkout',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    var url = cat.imageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('/')) {
        url = 'https://www.fastkirana.in$url';
      }
      if (url.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          memCacheHeight: 200,
          maxWidthDiskCache: 200,
          maxHeightDiskCache: 200,
          placeholder: (_, __) => Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 18))),
          errorWidget: (_, __, ___) => _buildLocalAssetOrEmoji(cat),
        );
      }
    }
    return _buildLocalAssetOrEmoji(cat);
  }

  Widget _buildLocalAssetOrEmoji(RenderedCategory cat) {
    final asset = getCategoryAssetImage(cat.tag) ?? getCategoryAssetImage(cat.title);
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
          bottom: BorderSide(color: AppDesignSystem.slate100, width: 1.5),
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
                            color: isSelected ? AppDesignSystem.orange50 : Colors.white,
                            border: Border.all(
                              color: isSelected ? AppDesignSystem.orange600 : AppDesignSystem.slate200,
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppDesignSystem.orange600.withValues(alpha: 0.25),
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
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.orange600 : AppDesignSystem.slate600,
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
