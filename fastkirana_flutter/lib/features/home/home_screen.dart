import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/address.dart';
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
import 'widgets/home_category_toggle.dart';
import '../../providers/address_provider.dart';
import '../orders/orders_screen.dart';
import '../../widgets/unserviceable_location_banner.dart';
import '../../core/services/location_service.dart';
import '../../widgets/app_update_dialog.dart';
import '../../widgets/dynamic_hero_banner_carousel.dart';
import '../../providers/banner_provider.dart';
import '../../providers/hub_availability_provider.dart';
import '../../providers/store_hub_provider.dart';
import 'widgets/hub_coming_soon_view.dart';
import 'widgets/outside_delivery_zone_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _isGrocerySelected = false; // Food mode default (Food first, then Grocery)
  final int _selectedFilterIndex = 0;
  Timer? _orderSyncTimer;

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
    // Infinite scroll listener for seamless product pagination (Blinkit / Zepto)
    _homeScrollController.addListener(_onHomeScroll);

    // Check for app version updates and background location resolve (Zepto / Blinkit style)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateDialog.checkAndShow(context, ref);
        // If no address selected yet, auto-fetch GPS location and resolve nearest dark store hub
        if (ref.read(selectedAddressProvider) == null) {
          LocationService.getCurrentPosition().then((pos) async {
            if (pos != null && mounted) {
              final details = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
              final addr = Address(
                id: 'gps_${DateTime.now().millisecondsSinceEpoch}',
                userId: 'current',
                label: 'Current Location',
                houseNo: details.houseNo,
                street: details.street,
                area: details.area,
                city: details.city,
                pincode: details.pincode,
                latitude: details.latitude,
                longitude: details.longitude,
                isDefault: true,
              );
              ref.read(selectedAddressProvider.notifier).state = addr;
              ref.invalidate(homeProductCatalogProvider);
            }
          }).catchError((_) {});
        } else {
          // Silent background check for location drift after smooth initial render
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              LocationService.checkLocationDriftAndPrompt(context, ref);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    _orderSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRevalidateCatalog();
    }
  }

  Future<void> _checkAndRevalidateCatalog() async {
    try {
      final dio = ref.read(dioProvider);
      final hub = ref.read(currentStoreHubProvider);
      final changed = await ProductRepository.checkAndRevalidateCatalog(dio, hub.id);
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

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppDesignSystem.primary,
              onRefresh: () async {
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
                  const SliverToBoxAdapter(child: HomeTopHeader()),

                  // 1. Outside All Serviceable Delivery Zones
                  if (hubStatus.isOutsideZone) ...[
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
                    const SliverToBoxAdapter(child: UnserviceableLocationBanner()),
                    SliverToBoxAdapter(
                      child: HomeCategoryToggle(
                        isGrocerySelected: _isGrocerySelected,
                        onModeChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isGrocerySelected = val;
                          });
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: DynamicHeroBannerCarousel(
                        key: ValueKey('hero_carousel_${_isGrocerySelected ? "grocery" : "food"}'),
                        type: _isGrocerySelected ? 'grocery' : 'food',
                      ),
                    ),
                    if (_isGrocerySelected) ...[
                      if (hubStatus.isHybridFoodOnly) ...[
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppDesignSystem.orange200),
                              boxShadow: [
                                BoxShadow(
                                  color: AppDesignSystem.orange500.withValues(alpha: 0.08),
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
                                  child: const Text('🥕', style: TextStyle(fontSize: 28)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Grocery Stocking Up Soon!',
                                  style: GoogleFonts.outfit(
                                    fontSize: Responsive.scaledFontSize(context, 18),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Our local dark store in ${hubStatus.hub.city} is currently stocking up. In the meantime, order hot & fresh meals from top partner restaurants!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppDesignSystem.orange600,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Order Food Now',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
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
                        const SliverToBoxAdapter(child: HomeTopCategoriesGrid()),
                        SliverToBoxAdapter(
                          child: HomeBuyAgainShelf(isGrocerySelected: _isGrocerySelected),
                        ),
                        const SliverToBoxAdapter(child: HomeProductSections()),
                        ...HomeInfiniteFeed.buildSlivers(
                          context: context,
                          ref: ref,
                          scrollController: _homeScrollController,
                          visibleGridCount: _visibleGridCount,
                          selectedFilterIndex: _selectedFilterIndex,
                        ),
                      ],
                      const SliverToBoxAdapter(child: HomeFooter()),
                    ] else ...[
                      if (hubStatus.isHybridGroceryOnly) ...[
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
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
                                  child: const Text('🍕', style: TextStyle(fontSize: 28)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Food Delivery Coming Soon!',
                                  style: GoogleFonts.outfit(
                                    fontSize: Responsive.scaledFontSize(context, 18),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Partner kitchens are currently onboarding in ${hubStatus.hub.city}. You can enjoy ultra-fast 10-minute grocery delivery right now!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Shop Groceries in 10 Mins',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
