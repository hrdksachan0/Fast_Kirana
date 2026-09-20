import 'dart:async';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/routes/page_transitions.dart';
import '../data/models/banner.dart';
import '../data/models/category.dart';
import '../data/models/restaurant.dart';
import '../providers/banner_provider.dart';
import '../providers/product_provider.dart';
import '../providers/restaurant_provider.dart';
import '../features/categories/category_products_screen.dart';
import '../features/cafe/cafe_menu_screen.dart';
import '../features/search/search_screen.dart';
import 'card_media_widget.dart';

/// Pure Photo & Video Hero Banner Carousel
/// Blinkit / Zepto / Swiggy style:
/// - 100% Media Driven (pure photo / looping muted video).
/// - ZERO text overlays, ZERO coupon codes, ZERO buttons plastered over the media.
/// - Returns SizedBox.shrink() when no banners exist in database (zero hardcoding).
class DynamicHeroBannerCarousel extends ConsumerStatefulWidget {
  final String? type; // 'grocery', 'food', etc.

  const DynamicHeroBannerCarousel({
    super.key,
    this.type = 'grocery',
  });

  @override
  ConsumerState<DynamicHeroBannerCarousel> createState() => _DynamicHeroBannerCarouselState();
}

class _DynamicHeroBannerCarouselState extends ConsumerState<DynamicHeroBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide(int itemCount) {
    _autoSlideTimer?.cancel();
    if (itemCount <= 1) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isUserInteracting || !mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % itemCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _handleBannerTap(BuildContext context, WidgetRef ref, Banner banner) {
    HapticFeedback.lightImpact();
    final link = banner.linkUrl ?? banner.link ?? '';
    if (link.isEmpty) return;

    // 1. Restaurant Link (/restaurant/{slug})
    if (link.startsWith('/restaurant/')) {
      final slug = link.replaceFirst('/restaurant/', '').trim();
      final restaurantsAsync = ref.read(restaurantsProvider);
      final rest = restaurantsAsync.valueOrNull?.firstWhere(
        (r) => r.slug.toLowerCase() == slug.toLowerCase() || r.id == slug,
        orElse: () => Restaurant(
          id: slug,
          name: banner.title.isNotEmpty ? banner.title : slug.replaceAll('-', ' '),
          slug: slug,
        ),
      );

      Navigator.push(
        context,
        FadeSlideRoute(
          page: CafeMenuScreen(
            restaurantId: rest?.id ?? slug,
            restaurantName: rest?.name ?? 'Restaurant',
            restaurant: rest,
          ),
        ),
      );
      return;
    }

    // 2. Category Link (/category/{slug})
    if (link.startsWith('/category/')) {
      final slug = link.replaceFirst('/category/', '').trim();
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
      }
      return;
    }

    // 3. Search Link (/search?q={query})
    if (link.startsWith('/search')) {
      final uri = Uri.tryParse(link);
      final query = uri?.queryParameters['q'] ?? '';
      Navigator.push(
        context,
        FadeScaleRoute(page: SearchScreen(initialQuery: query)),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider(widget.type));

    return bannersAsync.when(
      data: (banners) {
        // Filter out inactive banners or banners with zero media
        final activeBanners = banners.where((b) {
          if (!b.isActive) return false;
          final hasMedia = (b.imageUrl != null && b.imageUrl!.trim().isNotEmpty) ||
              (b.videoUrl != null && b.videoUrl!.trim().isNotEmpty);
          if (!hasMedia) return false;

          final isFood = b.type == 'food' ||
              b.type == 'cafe' ||
              (b.linkUrl?.startsWith('/restaurant') ?? false);

          if (widget.type == 'food' || widget.type == 'cafe') {
            return isFood;
          } else if (widget.type == 'grocery') {
            return !isFood;
          }
          return true;
        }).toList();

        // If no banners exist in database, cleanly collapse
        if (activeBanners.isEmpty) {
          return const SizedBox.shrink();
        }

        // Restart timer if count changed
        _startAutoSlide(activeBanners.length);

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Listener(
            onPointerDown: (_) => _isUserInteracting = true,
            onPointerUp: (_) => _isUserInteracting = false,
            onPointerCancel: (_) => _isUserInteracting = false,
            child: AspectRatio(
              aspectRatio: 16 / 7.2,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: activeBanners.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPage = idx;
                      });
                    },
                    itemBuilder: (context, index) {
                      final banner = activeBanners[index];
                      return GestureDetector(
                        onTap: () => _handleBannerTap(context, ref, banner),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CardMediaWidget(
                              imageUrl: banner.imageUrl,
                              videoUrl: banner.videoUrl,
                              fit: BoxFit.cover,
                              borderRadius: 16.0,
                              showLiveBadge: false, // Pure photo/video: NO BADGES, NO OVERLAYS
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Subtle indicator dots (only if multiple banners)
                  if (activeBanners.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(activeBanners.length, (idx) {
                          final isActive = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: isActive ? 16 : 5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: AspectRatio(
          aspectRatio: 16 / 7.2,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E24)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
