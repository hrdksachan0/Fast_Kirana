import 'dart:async';







import 'dart:math' as math;







import 'package:flutter/material.dart';







import 'package:flutter/services.dart';







import 'package:flutter_riverpod/flutter_riverpod.dart';







import 'package:google_fonts/google_fonts.dart';







import 'package:flutter_bounceable/flutter_bounceable.dart';







import '../../core/theme/design_system.dart';













import '../../data/models/product.dart';
import '../../data/models/category.dart';







import '../../data/repositories/product_repository.dart';







import '../../data/repositories/banner_repository.dart';







import '../../core/network/api_client.dart';







import '../../providers/cart_provider.dart';







import '../../providers/product_provider.dart';







import 'widgets/home_footer.dart';







import 'widgets/home_food_storefront.dart';







import 'widgets/home_buy_again_shelf.dart';







import 'widgets/home_top_categories_grid.dart';







import 'widgets/home_product_sections.dart';







import 'widgets/home_infinite_feed.dart';







import 'widgets/home_top_header.dart';







import 'widgets/home_sticky_search_toggle.dart';







import '../../providers/address_provider.dart';







import '../orders/orders_screen.dart';







import '../../widgets/unserviceable_location_banner.dart';







import '../../core/services/location_service.dart';







import '../../widgets/app_update_dialog.dart';







import 'package:shared_preferences/shared_preferences.dart';



import '../../widgets/swiggy_location_permission_sheet.dart';







import 'package:geolocator/geolocator.dart';







import '../../widgets/dynamic_hero_banner_carousel.dart';







import '../../providers/banner_provider.dart';







import '../../providers/hub_availability_provider.dart';







import '../../providers/store_hub_provider.dart';







import '../../providers/store_settings_provider.dart';







import '../../providers/restaurant_provider.dart';







import '../../data/models/store_settings.dart';







import 'widgets/hub_coming_soon_view.dart';







import 'widgets/outside_delivery_zone_view.dart';







import 'widgets/select_delivery_location_view.dart';







import '../navratri/navratri_data.dart';







import '../navratri/navratri_linked_products.dart';







import '../navratri/navratri_shopping_section.dart';
import '../campaign_bento/campaign_bento_zone.dart';
import '../categories/category_products_screen.dart';







import '../search/search_screen.dart';







import '../products/product_detail_screen.dart';







import '../../core/routes/page_transitions.dart';















class HomeScreen extends ConsumerStatefulWidget {







  const HomeScreen({super.key});















  @override







  ConsumerState<HomeScreen> createState() => _HomeScreenState();







}















class _HomeScreenState extends ConsumerState<HomeScreen>







    with WidgetsBindingObserver {







  bool _isGrocerySelected =







      true; // Grocery mode default (Grocery first, then Food)







  int _selectedFilterIndex = 0;
  bool _isResolvingInitialLocation = true;







  Timer? _orderSyncTimer;







  Timer? _storeStatusTimer;















  // Infinite Product Feed Scroll & Pagination State (Zepto/Blinkit architecture)







  final ScrollController _homeScrollController = ScrollController();







  int _visibleGridCount = 20;







  bool _isLoadingMoreGrid = false;















  static const Map<String, String> _sectionCategorySlugs = {







    'Snacks & Munchies': 'snacks-munchies',







    'Chocolates & Sweets': 'chocolates',







    'Instant Foods': 'instant-foods',







    'Kitchen Needs': 'kitchen-needs',







    'Ice Cream': 'ice-cream',







  };















  @override







  void initState() {







    super.initState();







    WidgetsBinding.instance.addObserver(this);















    // Live Order Sync with Admin Updates (60s fallback — Supabase handles instant real-time)







    _orderSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {







      if (mounted) {







        ref.invalidate(ordersProvider(''));







      }







    });















    // Store Status & Serviceability Live Polling (every 20s)







    _storeStatusTimer = Timer.periodic(const Duration(seconds: 20), (_) {







      if (mounted) {







        ref.invalidate(storeSettingsProvider);







      }







    });







    // Infinite scroll listener for seamless product pagination (Blinkit / Zepto)







    _homeScrollController.addListener(_onHomeScroll);















    // Check for app version updates and background location resolve (Zepto / Blinkit style)







    WidgetsBinding.instance.addPostFrameCallback((_) {







      if (mounted) {







        AppUpdateDialog.checkAndShow(context, ref);







        // Swiggy / Zomato Location Flow: Check permission & current address







        () async {







          final currentAddress = ref.read(selectedAddressProvider);







          final prefs = await SharedPreferences.getInstance();







          final hasChosen = prefs.getBool('has_chosen_location') ?? false;















          final serviceEnabled = await Geolocator.isLocationServiceEnabled();







          final permission = await Geolocator.checkPermission();







          final isAllowed = permission == LocationPermission.whileInUse ||







              permission == LocationPermission.always;















          if (isAllowed && serviceEnabled) {
            try {
              // Agar Pehle se Allowed hai:
              // App khulte hi bina kuch puche background me current location auto-set ho jati hai.
              if (currentAddress == null ||
                  currentAddress.id.startsWith('gps_') ||
                  currentAddress.id.startsWith('addr_bootstrap_gps_')) {
                await LocationService.bootstrapUserLocation(ref)
                    .timeout(const Duration(seconds: 3), onTimeout: () {});
              } else {
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    LocationService.checkLocationDriftAndPrompt(context, ref);
                  }
                });
              }
            } finally {
              if (mounted && _isResolvingInitialLocation) {
                setState(() => _isResolvingInitialLocation = false);
              }
            }
          } else {
            if (mounted && _isResolvingInitialLocation) {
              setState(() => _isResolvingInitialLocation = false);
            }







            // First-Time App Open (Jab koi address set na ho):







            // Customer ko home page par aate hi Swiggy-style sleek permission sheet dikhta hai.







            if (currentAddress == null && !hasChosen) {







              Future.delayed(const Duration(milliseconds: 300), () {







                if (mounted) {







                  SwiggyLocationPermissionSheet.show(context);







                }







              });







            }







          }







        }();







      }







    });







  }















  @override







  void dispose() {







    WidgetsBinding.instance.removeObserver(this);







    _homeScrollController.removeListener(_onHomeScroll);







    _homeScrollController.dispose();







    _orderSyncTimer?.cancel();







    _storeStatusTimer?.cancel();







    super.dispose();







  }















  @override







  void didChangeAppLifecycleState(AppLifecycleState state) {







    if (state == AppLifecycleState.resumed) {







      ref.invalidate(storeSettingsProvider);







      ref.invalidate(navratriDataProvider);







      ref.invalidate(navratriLinkedProductsProvider);







      _checkAndRevalidateCatalog();







    }







  }















  Future<void> _checkAndRevalidateCatalog() async {







    try {







      final dio = ref.read(dioProvider);







      final hub = ref.read(currentStoreHubProvider);







      final changed =







          await ProductRepository.checkAndRevalidateCatalog(dio, hub.id);







      if (changed && mounted) {







        debugPrint('[HomeScreen] SWR: Catalog refreshed on app resume!');







        refreshAllCatalogProviders(ref);







      }







    } catch (_) {}







  }















  void _onHomeScroll() {







    if (!_homeScrollController.hasClients || _isLoadingMoreGrid) return;







    final pos = _homeScrollController.position;







    // Auto-fetch next 20 products seamlessly when user is 450px from bottom







    if (pos.pixels >= pos.maxScrollExtent - 450) {







      _loadMoreGridProducts();







    }







  }















  void _loadMoreGridProducts() {







    if (_isLoadingMoreGrid) return;







    final catalog = ref.read(homeProductCatalogProvider).valueOrNull ?? [];







    final categories = ref.read(categoriesProvider).valueOrNull ?? [];







    final filtered = HomeInfiniteFeed.getFilteredGridProducts(







      all: catalog,







      categories: categories,







      selectedFilterIndex: _selectedFilterIndex,







    );







    if (_visibleGridCount >= filtered.length) return;















    setState(() {







      _isLoadingMoreGrid = true;







    });















    // Buttery-smooth micro-delay before revealing next 20 items







    Future.delayed(const Duration(milliseconds: 180), () {







      if (mounted) {







        setState(() {







          _visibleGridCount = math.min(_visibleGridCount + 20, filtered.length);







          _isLoadingMoreGrid = false;







        });







      }







    });







  }















  @override







  Widget build(BuildContext context) {







    final hubStatus = ref.watch(hubAvailabilityProvider);







    final showNavratri = _isGrocerySelected &&







        !hubStatus.isOutsideZone &&







        !hubStatus.isComingSoon &&







        !hubStatus.isHybridFoodOnly;







    final campaignState = showNavratri ? ref.watch(navratriDataProvider) : null;
    final configuredCampaign =
        campaignState?.valueOrNull ?? memoryCachedCampaign;
    final navratri =
        configuredCampaign?.enabled == true ? configuredCampaign : null;







    final festiveCatalog =







        navratri != null ? ref.watch(homeProductCatalogProvider) : null;







    final campaignHomeProducts = festiveCatalog?.isLoading == true







        ? <Product>[]







        : festiveCatalog?.valueOrNull ?? <Product>[];







    final missingLinks = navratri == null







        ? <String>[]







        : missingNavratriProductIds(navratri, campaignHomeProducts);







    final linkedProducts = missingLinks.isEmpty







        ? null







        : ref.watch(navratriLinkedProductsProvider(NavratriLinkedProductQuery(







            storeId: ref.watch(currentStoreHubProvider).id,







            productIds: missingLinks,







          )));







    final campaignProducts = mergeNavratriLinkedProducts(







        campaignHomeProducts,







        linkedProducts?.isLoading == true







            ? []







            : linkedProducts?.valueOrNull ?? []);







    final cart = ref.watch(cartProvider).valueOrNull;







    final hasCartItems =







        (cart?.items.fold<int>(0, (s, item) => s + item.quantity) ?? 0) > 0;















    // React smoothly when store transitions from Closed/Paused to ONLINE







    ref.listen<AsyncValue<StoreSettings>>(storeSettingsProvider, (prev, next) {







      final prevSettings = prev?.valueOrNull;







      final nextSettings = next.valueOrNull;







      if (prevSettings != null && nextSettings != null) {







        final wasOpen =







            prevSettings.groceryMartOpen || prevSettings.restaurantOpen;







        final isNowOpen =







            nextSettings.groceryMartOpen || nextSettings.restaurantOpen;







        if (!wasOpen && isNowOpen && mounted) {







          HapticFeedback.mediumImpact();







          refreshAllCatalogProviders(ref);







          ref.invalidate(restaurantsProvider);







          ScaffoldMessenger.of(context).hideCurrentSnackBar();







          ScaffoldMessenger.of(context).showSnackBar(







            SnackBar(







              backgroundColor: const Color(0xFF15803D),







              behavior: SnackBarBehavior.floating,







              duration: const Duration(seconds: 4),







              shape: RoundedRectangleBorder(







                  borderRadius: BorderRadius.circular(14)),







              content: Row(







                children: [







                  Container(







                    padding: const EdgeInsets.all(6),







                    decoration: const BoxDecoration(







                      color: Colors.white24,







                      shape: BoxShape.circle,







                    ),







                    child: const Icon(Icons.storefront_rounded,







                        color: Colors.white, size: 18),







                  ),







                  const SizedBox(width: 10),







                  Expanded(







                    child: Column(







                      mainAxisSize: MainAxisSize.min,







                      crossAxisAlignment: CrossAxisAlignment.start,







                      children: [







                        Text(







                          'Store is now ONLINE! ⚡',







                          style: GoogleFonts.inter(







                              fontWeight: FontWeight.w900,







                              color: Colors.white,







                              fontSize: 13),







                        ),







                        Text(







                          'Accepting fresh orders in Ghatampur.',







                          style: GoogleFonts.inter(







                              fontWeight: FontWeight.w500,







                              color: Colors.white.withValues(alpha: 0.9),







                              fontSize: 11),







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







    });















    return Scaffold(







      backgroundColor: AppDesignSystem.background,







      body: SafeArea(







        bottom: false,







        child: Stack(







          children: [







            RefreshIndicator(







              color: AppDesignSystem.primary,







              onRefresh: () async {







                ref.invalidate(navratriDataProvider);







                ref.invalidate(navratriLinkedProductsProvider);







                HapticFeedback.mediumImpact();







                await BannerRepository.invalidateCache();







                await ProductRepository.invalidateAllCache();







                ref.invalidate(homeProductCatalogProvider);







                ref.invalidate(cartProvider);







                ref.invalidate(categoriesProvider);







                ref.invalidate(activeStoreHubsProvider);







                ref.invalidate(hubAvailabilityProvider);







                ref.invalidate(bannersProvider('grocery'));







                ref.invalidate(bannersProvider('food'));







                ref.invalidate(brandOfferCardsProvider('grocery'));







                ref.invalidate(brandOfferCardsProvider('food'));







                ref.invalidate(trendingProductsProvider);







                ref.invalidate(ordersProvider(''));







                for (final slug in _sectionCategorySlugs.values) {







                  ref.invalidate(productsProvider(slug));







                }







              },







              child: CustomScrollView(







                controller: _homeScrollController,







                physics: const AlwaysScrollableScrollPhysics(







                  parent: BouncingScrollPhysics(),







                ),







                slivers: [







                  const SliverToBoxAdapter(







                    child: HomeTopHeader(showSearch: false),







                  ),















                  // Sticky Search Bar & Grocery/Food Toggle (pinned across Grocery and Food screens)







                  if (!hubStatus.isOutsideZone && !hubStatus.isComingSoon && !hubStatus.isNoLocation)







                    SliverPersistentHeader(







                      pinned: true,







                      delegate: HomeStickyHeaderDelegate(







                        isGrocerySelected: _isGrocerySelected,
                        isFestiveActive: navratri != null,







                        onModeChanged: (val) {







                          HapticFeedback.selectionClick();







                          setState(() {







                            _isGrocerySelected = val;







                          });







                        },







                      ),







                    ),















                  // 0. Customer Has Not Selected Delivery Location Yet (GPS Off / Fresh Launch)







                  if (hubStatus.isNoLocation) ...[
                    if (_isResolvingInitialLocation)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 64),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Detecting your delivery area...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const SliverToBoxAdapter(
                        child: SelectDeliveryLocationView(),
                      ),
                      const SliverToBoxAdapter(child: HomeFooter()),
                    ],







                  ]















                  // 1. Outside All Serviceable Delivery Zones







                  else if (hubStatus.isOutsideZone) ...[







                    SliverToBoxAdapter(







                      child: OutsideDeliveryZoneView(







                        nearestHub: hubStatus.hub,







                        distanceKm: hubStatus.distanceKm,







                      ),







                    ),







                    const SliverToBoxAdapter(child: HomeFooter()),







                  ]















                  // 2. Inside Zone, but Hub is Launching Soon (0 grocery & 0 restaurant)







                  else if (hubStatus.isComingSoon) ...[







                    SliverToBoxAdapter(







                      child: HubComingSoonView(hub: hubStatus.hub),







                    ),







                    const SliverToBoxAdapter(child: HomeFooter()),







                  ]















                  // 3. Fully Active Operational Hub Storefront







                  else ...[







                    const SliverToBoxAdapter(







                        child: UnserviceableLocationBanner()),
                    // 1. Diwali / Festive Campaign Section (Top Position)
                    if (navratri != null && _isGrocerySelected) ...[
                      SliverToBoxAdapter(
                        child: NavratriShoppingSection(
                          data: navratri,
                          catalog: campaignProducts,
                          catalogLoading: festiveCatalog?.isLoading ?? false,
                          catalogFailed: festiveCatalog?.hasError ?? false,
                          onProductSelected: (product) => Navigator.push(
                            context,
                            FadeSlideRoute(
                                page: ProductDetailScreen(product: product)),
                          ),
                          onNavigate: (destination) {
                            final q = destination.query.trim();
                            if (q.startsWith('/category/') || q.startsWith('category/')) {
                              final slug = q.replaceFirst(RegExp(r'^/?category/'), '').trim();
                              final categoriesAsync = ref.read(categoriesProvider);
                              final cat = categoriesAsync.valueOrNull?.firstWhere(
                                (c) => c.slug.toLowerCase() == slug.toLowerCase() || c.id == slug,
                                orElse: () => Category(id: slug, name: slug.replaceAll('-', ' '), slug: slug),
                              );
                              if (cat != null) {
                                Navigator.push(
                                  context,
                                  FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
                                );
                                return;
                              }
                            }
                            final cleanQuery = q.startsWith('/search?q=')
                                ? q.replaceFirst('/search?q=', '')
                                : (q.startsWith('/category/')
                                    ? q.replaceFirst('/category/', '').replaceAll('-', ' ')
                                    : q);
                            Navigator.push(
                              context,
                              FadeSlideRoute(
                                page: SearchScreen(initialQuery: cleanQuery),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // 2. Dynamic Hero Banner Carousel (Below Diwali Campaign)
                    SliverToBoxAdapter(
                      child: DynamicHeroBannerCarousel(
                        key: ValueKey(
                            'hero_carousel_${_isGrocerySelected ? "grocery" : "food"}'),
                        type: _isGrocerySelected ? 'grocery' : 'food',
                        onSwitchMode: (isGrocery) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isGrocerySelected = isGrocery;
                          });
                        },
                      ),
                    ),
                    if (_isGrocerySelected) ...[







                      if (hubStatus.isHybridFoodOnly) ...[







                        SliverToBoxAdapter(







                          child: Container(







                            margin: const EdgeInsets.symmetric(







                                horizontal: 16, vertical: 20),







                            padding: const EdgeInsets.all(22),







                            decoration: BoxDecoration(







                              color: Colors.white,







                              borderRadius: BorderRadius.circular(20),







                              border:







                                  Border.all(color: AppDesignSystem.orange200),







                              boxShadow: [







                                BoxShadow(







                                  color: AppDesignSystem.orange500







                                      .withValues(alpha: 0.08),







                                  blurRadius: 16,







                                  offset: const Offset(0, 4),







                                ),







                              ],







                            ),







                            child: Column(







                              children: [







                                Container(







                                  padding: const EdgeInsets.all(12),







                                  decoration: const BoxDecoration(







                                    color: AppDesignSystem.orange50,







                                    shape: BoxShape.circle,







                                  ),







                                  child: const Text('🥕',







                                      style: TextStyle(fontSize: 28)),







                                ),







                                const SizedBox(height: 12),







                                Text(







                                  'Grocery Stocking Up Soon!',







                                  style: GoogleFonts.outfit(







                                    fontSize:







                                        Responsive.scaledFontSize(context, 18),







                                    fontWeight: FontWeight.w800,







                                    color: AppDesignSystem.slate900,







                                  ),







                                ),







                                const SizedBox(height: 6),







                                Text(







                                  'Our local dark store in ${hubStatus.hub.city} is currently stocking up. In the meantime, order hot & fresh meals from top partner restaurants!',







                                  textAlign: TextAlign.center,







                                  style: GoogleFonts.inter(







                                    fontSize: Responsive.scaledFontSize(







                                        context, 12.5),







                                    fontWeight: FontWeight.w500,







                                    color: AppDesignSystem.slate600,







                                    height: 1.4,







                                  ),







                                ),







                                const SizedBox(height: 16),







                                Bounceable(







                                  onTap: () {







                                    HapticFeedback.selectionClick();







                                    setState(() => _isGrocerySelected = false);







                                  },







                                  child: Container(







                                    padding: const EdgeInsets.symmetric(







                                        horizontal: 22, vertical: 12),







                                    decoration: BoxDecoration(







                                      color: AppDesignSystem.orange600,







                                      borderRadius: BorderRadius.circular(14),







                                    ),







                                    child: Row(







                                      mainAxisSize: MainAxisSize.min,







                                      children: [







                                        const Icon(Icons.restaurant_rounded,







                                            color: Colors.white, size: 16),







                                        const SizedBox(width: 8),







                                        Text(







                                          'Order Food Now',







                                          style: GoogleFonts.inter(







                                            fontSize: Responsive.scaledFontSize(







                                                context, 13),







                                            fontWeight: FontWeight.w800,







                                            color: Colors.white,







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







                      ] else ...[







                        const SliverToBoxAdapter(
                            child: HomeTopCategoriesGrid()),
                        const SliverToBoxAdapter(
                            child: CampaignBentoZone(showLiveEditButton: false)),







                    







                        SliverToBoxAdapter(







                          child: HomeBuyAgainShelf(







                              isGrocerySelected: _isGrocerySelected),







                        ),







                        const SliverToBoxAdapter(child: HomeProductSections()),







                        ...HomeInfiniteFeed.buildSlivers(







                          context: context,







                          ref: ref,







                          scrollController: _homeScrollController,







                          visibleGridCount: _visibleGridCount,







                          selectedFilterIndex: _selectedFilterIndex,







                          onFilterChanged: (newIdx) {







                            HapticFeedback.selectionClick();







                            setState(() {







                              _selectedFilterIndex = newIdx;







                              _visibleGridCount = 20;







                            });







                          },







                        ),







                      ],







                      const SliverToBoxAdapter(child: HomeFooter()),







                    ] else ...[







                      if (hubStatus.isHybridGroceryOnly) ...[







                        SliverToBoxAdapter(







                          child: Container(







                            margin: const EdgeInsets.symmetric(







                                horizontal: 16, vertical: 20),







                            padding: const EdgeInsets.all(22),







                            decoration: BoxDecoration(







                              color: Colors.white,







                              borderRadius: BorderRadius.circular(20),







                              border:







                                  Border.all(color: const Color(0xFFFDE68A)),







                              boxShadow: [







                                BoxShadow(







                                  color: Colors.black.withValues(alpha: 0.04),







                                  blurRadius: 16,







                                  offset: const Offset(0, 4),







                                ),







                              ],







                            ),







                            child: Column(







                              children: [







                                Container(







                                  padding: const EdgeInsets.all(12),







                                  decoration: const BoxDecoration(







                                    color: Color(0xFFFEF3C7),







                                    shape: BoxShape.circle,







                                  ),







                                  child: const Text('🍕',







                                      style: TextStyle(fontSize: 28)),







                                ),







                                const SizedBox(height: 12),







                                Text(







                                  'Food Delivery Coming Soon!',







                                  style: GoogleFonts.outfit(







                                    fontSize:







                                        Responsive.scaledFontSize(context, 18),







                                    fontWeight: FontWeight.w800,







                                    color: AppDesignSystem.slate900,







                                  ),







                                ),







                                const SizedBox(height: 6),







                                Text(







                                  'Partner kitchens are currently onboarding in ${hubStatus.hub.city}. You can enjoy ultra-fast grocery delivery right now!',







                                  textAlign: TextAlign.center,







                                  style: GoogleFonts.inter(







                                    fontSize: Responsive.scaledFontSize(







                                        context, 12.5),







                                    fontWeight: FontWeight.w500,







                                    color: AppDesignSystem.slate600,







                                    height: 1.4,







                                  ),







                                ),







                                const SizedBox(height: 16),







                                Bounceable(







                                  onTap: () {







                                    HapticFeedback.selectionClick();







                                    setState(() => _isGrocerySelected = true);







                                  },







                                  child: Container(







                                    padding: const EdgeInsets.symmetric(







                                        horizontal: 22, vertical: 12),







                                    decoration: BoxDecoration(







                                      color: const Color(0xFF16A34A),







                                      borderRadius: BorderRadius.circular(14),







                                    ),







                                    child: Row(







                                      mainAxisSize: MainAxisSize.min,







                                      children: [







                                        const Icon(Icons.shopping_bag_rounded,







                                            color: Colors.white, size: 16),







                                        const SizedBox(width: 8),







                                        Text(







                                          'Shop Groceries',







                                          style: GoogleFonts.inter(







                                            fontSize: Responsive.scaledFontSize(







                                                context, 13),







                                            fontWeight: FontWeight.w800,







                                            color: Colors.white,







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







                      ] else ...[







                        const SliverToBoxAdapter(child: HomeFoodStorefront()),







                      ],







                      const SliverToBoxAdapter(child: HomeFooter()),







                    ],







                  ],







                  SliverToBoxAdapter(







                      child: SizedBox(height: hasCartItems ? 120 : 80)),







                ],







              ),







            ),







          ],







        ),







      ),







    );







  }







}






