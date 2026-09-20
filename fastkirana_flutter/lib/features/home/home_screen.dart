import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/address.dart';
import '../../data/repositories/product_repository.dart';
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
import '../../providers/restaurant_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    _orderSyncTimer?.cancel();
    super.dispose();
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
                await ProductRepository.invalidateAllCache();
                ref.invalidate(cartProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(bannersProvider('grocery'));
                ref.invalidate(trendingProductsProvider);
                ref.invalidate(ordersProvider(''));
                for (final slug in _sectionCategorySlugs.values) {
                  ref.invalidate(productsProvider(slug));
                }
                ref.invalidate(homeProductCatalogProvider);
                ref.invalidate(homeRestaurantsProvider);
                await Future.wait([
                  ref.refresh(homeProductCatalogProvider.future).catchError((_) => <Product>[]),
                  ref.refresh(categoriesProvider.future).catchError((_) => <Category>[]),
                ]);
                if (mounted) {
                  setState(() {
                    _visibleGridCount = 20;
                    _isLoadingMoreGrid = false;
                  });
                }
              },
              child: CustomScrollView(
                controller: _homeScrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Pinned Header & Search
                  const SliverToBoxAdapter(child: HomeTopHeader()),

                  // 1b. Location Unserviceable Warning Banner (Swiggy / Zepto Style)
                  const SliverToBoxAdapter(child: UnserviceableLocationBanner()),

                  // 2. Mode Switcher (Grocery vs Food) - Placed directly above banner
                  SliverToBoxAdapter(
                    child: HomeCategoryToggle(
                      isGrocerySelected: _isGrocerySelected,
                      onModeChanged: (val) {
                        setState(() => _isGrocerySelected = val);
                      },
                    ),
                  ),

                  if (_isGrocerySelected) ...[
                    // 2.5 Dynamic Hero Promotional Banner Carousel (Matching Web 1:1, Auto-Slide, Zero Coupons)
                    const SliverToBoxAdapter(child: DynamicHeroBannerCarousel(type: 'grocery')),

                    // 3. Top 8 Categories (2 rows) - Premium squircle tiles
                    const SliverToBoxAdapter(child: HomeTopCategoriesGrid()),

                    // 3.5 Buy Again Shelf (Instant 1-tap reordering from past purchases)
                    SliverToBoxAdapter(child: HomeBuyAgainShelf(isGrocerySelected: _isGrocerySelected)),

                    // 4. Product Shelves (Category title + Subcategory chips + Products with + ADD)
                    SliverToBoxAdapter(child: HomeProductSections(selectedFilterIndex: _selectedFilterIndex)),

                    // 5. Infinite Scroll Product Feed (Batch-loaded 20 items at a time, Blinkit/Zepto style)
                    ...HomeInfiniteFeed.buildSlivers(
                      context: context,
                      ref: ref,
                      scrollController: _homeScrollController,
                      visibleGridCount: _visibleGridCount,
                      selectedFilterIndex: _selectedFilterIndex,
                    ),

                    // Footer
                    const SliverToBoxAdapter(child: HomeFooter()),
                  ] else ...[
                    // Food & Cafe Mode — directly show restaurants
                    const SliverToBoxAdapter(child: HomeFoodStorefront()),
                    const SliverToBoxAdapter(child: HomeFooter()),
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
