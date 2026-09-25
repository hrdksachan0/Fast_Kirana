import 'package:flutter/material.dart';
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
import 'package:share_plus/share_plus.dart';
import 'models/cafe_menu_section.dart';
import 'widgets/cafe_reviews_tab.dart';
import 'widgets/cafe_offers_strip.dart';

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

  final GlobalKey _topMenuKey = GlobalKey();
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

    const itemWidth = 76.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetScroll = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    final maxScroll = _horizontalCategoryController.position.maxScrollExtent;
    final clampedScroll = targetScroll.clamp(0.0, maxScroll);

    _horizontalCategoryController.animateTo(
      clampedScroll,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToSection(String tag) {
    HapticFeedback.selectionClick();
    _isManualTabClick = true;

    if (tag == 'all') {
      setState(() => _activeCategoryTag = 'all');
      _centerCategoryInHorizontalBar('all');
      if (_topMenuKey.currentContext != null) {
        Scrollable.ensureVisible(
          _topMenuKey.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.0,
        );
      }
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _isManualTabClick = false;
      });
      return;
    }

    // Resolve matching section tag if tag came from cuisine tags or fuzzy matching
    String resolvedTag = tag;
    if (!_sectionKeys.containsKey(tag)) {
      final clean = tag.toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and');
      for (final secKey in _sectionKeys.keys) {
        final cleanSec = secKey.toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and');
        if (cleanSec.contains(clean) || clean.contains(cleanSec)) {
          resolvedTag = secKey;
          break;
        }
      }
    }

    // Auto-uncollapse target section so its contents are immediately visible
    if (_collapsedSections[resolvedTag] == true) {
      _collapsedSections[resolvedTag] = false;
    }

    setState(() => _activeCategoryTag = resolvedTag);
    _centerCategoryInHorizontalBar(resolvedTag);

    final key = _sectionKeys[resolvedTag] ?? _sectionKeys[tag];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }

    Future.delayed(const Duration(milliseconds: 450), () {
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

        // Match Cold Drinks
        if (['chilled', 'beverages', 'shakes-beverages', 'sec_chilled_drinks'].contains(secTagLower) || secTagLower == 'chilled') {
          if (pCatSlug == 'beverages' || pCatSlug == 'chilled' || pTags.contains('beverages') || pTags.contains('cold-drink') || pTags.contains('chilled')) {
            assignedIds.add(p.id);
            return true;
          }
        }

        // Match Desserts & Ice Cream
        if (['desserts', 'ice-cream', 'sec_ice_creams'].contains(secTagLower) || secTagLower == 'desserts') {
          if (pCatSlug == 'ice-cream' || pCatSlug == 'desserts' || pTags.contains('ice-cream') || pTags.contains('desserts') || pTags.contains('kulfi')) {
            assignedIds.add(p.id);
            return true;
          }
        }

        final matched = 
          sec.matchTags.any((tag) {
            final t = tag.toLowerCase().trim();
            return pTags.contains(t) || pCatSlug.contains(t) || pCatName.contains(t) || pMenuSec == t;
          }) ||
          pTags.contains(secTagLower) ||
          pCatSlug == secTagLower ||
          pCatName == secTitleLower ||
          (pMenuSec.isNotEmpty && (pMenuSec == secTagLower || pMenuSec == secIdLower || pMenuSec == secTitleLower)) ||
          (secIdLower.isNotEmpty && pTags.contains(secIdLower));

        if (matched) {
          assignedIds.add(p.id);
        }
        return matched;
      }).toList();

      if (secProducts.isNotEmpty) {
        // Sort systematically: in-stock first, sortOrder: desc, createdAt: desc
        secProducts.sort((a, b) => compareProductsSystematic(a, b));

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
        final groupTitle = (p.menuSection != null && p.menuSection!.trim().isNotEmpty)
            ? p.menuSection!.trim()
            : ((p.category?.name != null && p.category!.name.trim().isNotEmpty && p.category!.name != 'Restaurant Food' && p.category!.name != 'Cafe')
                ? p.category!.name.trim()
                : 'Specialties');
        categoryGroups.putIfAbsent(groupTitle, () => []).add(p);
      }

      categoryGroups.forEach((title, grpProducts) {
        // Sort systematically: in-stock first, sortOrder, natural ID, then name
        grpProducts.sort((a, b) => compareProductsSystematic(a, b));

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

    // Sort full filtered list systematically as well
    filtered.sort((a, b) => compareProductsSystematic(a, b));

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
            RefreshIndicator(
              color: AppDesignSystem.primary,
              onRefresh: () async {
                ref.invalidate(restaurantMenuProvider(widget.restaurantId));
                ref.invalidate(restaurantReviewsProvider(widget.restaurantId));
                ref.invalidate(restaurantCouponsProvider(widget.restaurantId));
                ref.invalidate(restaurantsProvider);
              },
              child: NestedScrollView(
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
                        const shareUrl = 'https://fastkirana.in/cafe';
                        final shareText = '🍔 Craving delicious food? Check out the fresh menu of $restaurantName on FastKirana!\nOrder online for fast express delivery: $shareUrl';
                        Share.share(shareText, subject: '$restaurantName Menu - FastKirana');
                      },
                    ),
                  ),
                ],
                centerTitle: false,
                titleSpacing: 0,
                title: innerBoxIsScrolled
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          restaurantName,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                                      child: GestureDetector(
                                        onTap: () => _scrollToSection(tag),
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
                key: _topMenuKey,
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
                        childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: false),
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
                color: Colors.black.withValues(alpha: 0.03),
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
                height: Responsive.productShelfHeight(context),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addons.length,
                  itemBuilder: (context, idx) {
                    final p = addons[idx];
                    final cardWidth = Responsive.productCardShelfWidth(context);
                    return Container(
                      width: cardWidth,
                      margin: const EdgeInsets.only(right: 10),
                      child: ProductCard(
                        product: p,
                        width: cardWidth,
                        isCompact: false,
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
    return CafeReviewsTab(
      reviewsAsync: reviewsAsync,
      restaurantName: widget.restaurantName,
      restaurantId: widget.restaurantId,
    );
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
    return CafeOffersStrip(
      currentRestaurant: currentRestaurant,
      restaurantId: widget.restaurantId,
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
  double get maxExtent => 102;

  @override
  double get minExtent => 102;

  @override
  bool shouldRebuild(covariant _CategoryChipsDelegate oldDelegate) {
    return activeCategoryTag != oldDelegate.activeCategoryTag ||
        menuAsync != oldDelegate.menuAsync;
  }

  static String _formatCategoryTitle(String title) {
    final t = title.trim();
    final lower = t.toLowerCase();
    if (lower.contains('north indian') || lower.contains('curries & grav')) return 'Curries & Gravy';
    if (lower.contains('warm naan') || lower.contains('rotis, naan') || lower.contains('roti-naan') || lower.contains('rotis & naan') || lower.contains('naans, roti')) return 'Rotis & Naan';
    if (lower.contains('starters & tandoori') || lower.contains('starters & tikka') || lower.contains('tandoori tikka')) return 'Starters & Tikka';
    if (lower.contains('biryani & rice') || lower.contains('biryani-rice') || lower.contains('rice feast')) return 'Biryani & Rice';
    if (lower.contains('chinese') && (lower.contains('wok') || lower.contains('soup') || lower.contains('cuisine') || lower.contains('pasta'))) return 'Chinese & Soups';
    if (lower.contains('pizza') && (lower.contains('burger') || lower.contains('snack') || lower.contains('bite'))) return 'Pizza & Burgers';
    if (lower.contains('shake') && (lower.contains('beverage') || lower.contains('drink'))) return 'Shakes & Drinks';
    if (lower.contains('dessert') || lower.contains('ice cream') || lower.contains('sweet')) return 'Desserts';
    if (lower.contains('breakfast') || lower.contains('nashta')) return 'Breakfast';
    if (lower.contains('pav bhaji') || lower.contains('bombay bite')) return 'Pav Bhaji';
    if (lower.contains('dosa') || lower.contains('south indian')) return 'South Indian';
    if (lower.contains('garlic bread')) return 'Garlic Bread';
    if (lower.contains('frankie') || lower.contains('roll')) return 'Frankie & Rolls';
    if (lower.contains('sandwich')) return 'Sandwiches';
    if (lower.contains('pasta')) return 'Pastas';
    return t;
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
            height: 102,
            child: ListView.separated(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final cat = cats[index];
                final isSelected = activeCategoryTag == cat.tag;
                final formattedTitle = _formatCategoryTitle(cat.title);

                return GestureDetector(
                  onTap: () => onCategoryTap(cat.tag),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppDesignSystem.orange50 : Colors.white,
                            border: Border.all(
                              color: isSelected ? AppDesignSystem.orange600 : const Color(0xFFE2E8F0),
                              width: isSelected ? 2.2 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppDesignSystem.orange600.withValues(alpha: 0.28)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildCategoryThumbnail(cat),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedTitle,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.orange600 : const Color(0xFF334155),
                            height: 1.15,
                            letterSpacing: -0.1,
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
        loading: () => const SizedBox(height: 102),
        error: (_, __) => const SizedBox(height: 102),
      ),
    );
  }
}
