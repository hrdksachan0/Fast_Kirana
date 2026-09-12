import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme/design_system.dart';
import '../core/routes/page_transitions.dart';
import '../data/models/banner.dart' as model;
import '../data/models/category.dart';
import '../data/models/restaurant.dart';
import '../providers/banner_provider.dart';
import '../providers/product_provider.dart';
import '../providers/restaurant_provider.dart';
import '../features/categories/category_products_screen.dart';
import '../features/cafe/cafe_menu_screen.dart';
import '../features/search/search_screen.dart';

class DynamicHeroBannerCarousel extends ConsumerStatefulWidget {
  final String? type; // 'grocery', 'cafe', etc.

  const DynamicHeroBannerCarousel({
    super.key,
    this.type = 'grocery',
  });

  @override
  ConsumerState<DynamicHeroBannerCarousel> createState() => _DynamicHeroBannerCarouselState();
}

class _DynamicHeroBannerCarouselState extends ConsumerState<DynamicHeroBannerCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _isInteracting = false;

  // Progress animation controller for the Instamart timer progress line
  late final AnimationController _progressController;

  static const Duration _slideDuration = Duration(milliseconds: 3500);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _progressController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _advanceToNext();
        }
      });

    _startTimer();
  }

  void _startTimer() {
    _progressController.reset();
    _progressController.forward();
  }

  void _advanceToNext() {
    if (!mounted) return;
    final bannersAsync = ref.read(bannersProvider(widget.type));
    final banners = bannersAsync.valueOrNull ?? [];
    if (banners.length <= 1) return;

    final nextPage = (_currentPage + 1) % banners.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 650),
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );
  }

  void _goToPrevious() {
    HapticFeedback.selectionClick();
    final bannersAsync = ref.read(bannersProvider(widget.type));
    final banners = bannersAsync.valueOrNull ?? [];
    if (banners.length <= 1) return;

    final prevPage = (_currentPage - 1 + banners.length) % banners.length;
    _pageController.animateToPage(
      prevPage,
      duration: const Duration(milliseconds: 650),
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );
  }

  void _goToNext() {
    HapticFeedback.selectionClick();
    _advanceToNext();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(model.Banner banner) {
    HapticFeedback.lightImpact();
    final link = banner.linkUrl ?? '';
    if (link.isEmpty) return;

    // 1. Category Link (/category/{slug})
    if (link.startsWith('/category/')) {
      final slug = link.replaceFirst('/category/', '').trim();
      final categoriesAsync = ref.read(categoriesProvider);
      final cat = categoriesAsync.valueOrNull?.firstWhere(
        (c) => c.slug.toLowerCase() == slug.toLowerCase() || c.id == slug,
        orElse: () => Category(id: slug, name: _prettifySlug(slug), slug: slug),
      ) ?? Category(id: slug, name: _prettifySlug(slug), slug: slug);

      Navigator.push(
        context,
        FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
      );
      return;
    }

    // 2. Restaurant Link (/restaurant/{slug})
    if (link.startsWith('/restaurant/')) {
      final slug = link.replaceFirst('/restaurant/', '').trim();
      final restaurantsAsync = ref.read(restaurantsProvider);
      final rest = restaurantsAsync.valueOrNull?.firstWhere(
        (r) => r.slug.toLowerCase() == slug.toLowerCase() || r.id == slug,
        orElse: () => Restaurant(id: slug, name: _prettifySlug(slug), slug: slug),
      );

      Navigator.push(
        context,
        FadeSlideRoute(
          page: CafeMenuScreen(
            restaurantId: rest?.id ?? slug,
            restaurantName: rest?.name ?? _prettifySlug(slug),
            restaurant: rest,
          ),
        ),
      );
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

  String _prettifySlug(String slug) {
    return slug
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider(widget.type));

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        final bannerCount = banners.length;
        final isMulti = bannerCount > 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            height: context.isCompact ? 138 : 158,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView Carousel
                  Listener(
                    onPointerDown: (_) {
                      _isInteracting = true;
                      _progressController.stop();
                    },
                    onPointerUp: (_) {
                      _isInteracting = false;
                      _startTimer();
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: bannerCount,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                        if (!_isInteracting) {
                          _startTimer();
                        }
                      },
                      itemBuilder: (context, index) {
                        final banner = banners[index];
                        return GestureDetector(
                          onTap: () => _handleBannerTap(banner),
                          child: _buildBannerCard(banner),
                        );
                      },
                    ),
                  ),

                  // Instamart Signature Floating Counter Pill with Animated Progress Line
                  if (isMulti)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _goToPrevious,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_currentPage + 1}/$bannerCount',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _goToNext,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Animated timer progress line
                              Container(
                                width: 42,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: Alignment.centerLeft,
                                child: AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (context, _) {
                                    return FractionallySizedBox(
                                      widthFactor: _progressController.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFBBF24), Color(0xFFFB7185)],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => _buildShimmerPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBannerCard(model.Banner banner) {
    final rawImageUrl = banner.imageUrl ?? '';

    // 1. Real Image Banner: Ambient blurred backdrop + sharp centered image
    if (rawImageUrl.isNotEmpty) {
      final resolvedUrl = rawImageUrl.startsWith('http')
          ? rawImageUrl
          : (rawImageUrl.startsWith('/') ? 'https://www.fastkirana.in$rawImageUrl' : null);

      if (resolvedUrl != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Ambient blurred backdrop
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Transform.scale(
                  scale: 1.15,
                  child: CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    memCacheHeight: 120,
                  ),
                ),
              ),
            ),
            // Semi-dark ambient overlay
            Container(color: Colors.black.withValues(alpha: 0.12)),
            // Sharp centered main image
            Center(
              child: CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.contain,
                memCacheWidth: 800,
                memCacheHeight: 400,
              ),
            ),
          ],
        );
      }
    }

    // 2. Express Delivery Banner Template ("Fast Delivery in Ghatampur")
    if (banner.type == 'express-delivery') {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDF0F1),
          border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
        ),
        padding: EdgeInsets.fromLTRB(
          context.isCompact ? 14 : 18,
          context.isCompact ? 10 : 14,
          context.isCompact ? 12 : 16,
          context.isCompact ? 10 : 14,
        ),
        child: Row(
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'FAST DELIVERY IN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 8.5),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFE20A22),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ghatampur',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: context.isCompact ? 19 : 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFE20A22),
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    banner.description.isNotEmpty ? banner.description : 'Milk, Fruits, Vegetables, Snacks & more',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: context.isCompact ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4D4D4D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Shop Now pill button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE20A22),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shop Now',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: context.isCompact ? 9 : 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // FAST Delivery roundel badge
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE20A22).withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            'FAST',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE20A22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right illustration
            SizedBox(
              width: context.isCompact ? 84 : 100,
              height: context.isCompact ? 84 : 100,
              child: CachedNetworkImage(
                imageUrl: 'https://www.fastkirana.in/grocery_bag_banner.webp',
                fit: BoxFit.contain,
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (_, __) => Image.asset(
                  'assets/categories/fruits_vegetables_category.webp',
                  fit: BoxFit.contain,
                ),
                errorWidget: (_, __, ___) => Image.asset(
                  'assets/categories/fruits_vegetables_category.webp',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Dynamic Gradient Banners (Farm Fresh, Festival, Super Savings, etc. — NO coupon chips)
    final gradient = _parseCssGradient(banner.gradient);

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: EdgeInsets.fromLTRB(
        context.isCompact ? 14 : 18,
        context.isCompact ? 12 : 16,
        context.isCompact ? 12 : 16,
        context.isCompact ? 12 : 16,
      ),
      child: Row(
        children: [
          // Left text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Express badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFFDE047)),
                      const SizedBox(width: 3),
                      Text(
                        'FAST DELIVERY',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 8.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  banner.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: context.isCompact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  banner.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: context.isCompact ? 9.5 : 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Right themed visual icon
          Container(
            width: context.isCompact ? 56 : 68,
            height: context.isCompact ? 56 : 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                _getBannerEmoji(banner),
                style: TextStyle(fontSize: context.isCompact ? 28 : 34),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getBannerEmoji(model.Banner banner) {
    final type = banner.type.toLowerCase();
    final title = banner.title.toLowerCase();
    if (type.contains('fresh') || title.contains('fruit') || title.contains('veg')) return '🥬';
    if (type.contains('snack') || title.contains('snack') || title.contains('munch')) return '🍿';
    if (type.contains('first') || title.contains('sav')) return '🛍️';
    if (type.contains('festiv') || title.contains('diwali') || title.contains('special')) return '🪔';
    if (title.contains('sweet')) return '🍬';
    if (title.contains('burger') || title.contains('cafe')) return '🍔';
    return '⚡';
  }

  LinearGradient _parseCssGradient(String css) {
    if (css.contains('emerald')) {
      return const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF2DD4BF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (css.contains('amber') || css.contains('orange')) {
      return const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFF97316), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (css.contains('purple') || css.contains('indigo')) {
      return const LinearGradient(
        colors: [Color(0xFF4C1D95), Color(0xFF4338CA), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (css.contains('cyan') || css.contains('blue')) {
      return const LinearGradient(
        colors: [Color(0xFF0891B2), Color(0xFF2563EB), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // Default Rose / Red / Orange Gradient matching Web
    return const LinearGradient(
      colors: [Color(0xFFE20A22), Color(0xFFF43F5E), Color(0xFFFB923C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 138,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
