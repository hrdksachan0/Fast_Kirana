import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/routes/page_transitions.dart';
import '../data/models/brand_offer_card_data.dart';
import '../data/models/category.dart';
import '../data/models/restaurant.dart';
import '../providers/banner_provider.dart';
import '../providers/product_provider.dart';
import '../providers/restaurant_provider.dart';
import '../features/categories/category_products_screen.dart';
import '../features/cafe/cafe_menu_screen.dart';
import '../features/search/search_screen.dart';
import 'card_media_widget.dart';
import '../features/gifting/send_gift_screen.dart';
import '../providers/gifting_store_provider.dart';

/// Ultra-Premium Animated Hero Carousel (Amazon Side-Peek + Swiggy Instamart Depth)
/// Specifications:
/// - Active width: 86% of screen (PageController viewportFraction: 0.86)
/// - 7% partial peek for previous and next banners on both sides
/// - 10-12px horizontal gaps between slides
/// - Banner aspect ratio: ~1.8:1
/// - Border radius: 22px with subtle ambient drop shadows and glass inner rim
/// - Smooth 4.5s autoplay with 550ms Curves.easeInOutCubic transitions
/// - Active scale: 1.0, Inactive scale: 0.94
/// - Active opacity: 1.0, Inactive opacity: 0.85
/// - Animated pagination: FastMinute red pill indicator + grey dots + count badge
/// - Auto-pause on user touch/drag
/// - Strict battery & memory safe lifecycle cleanup
class DynamicHeroBannerCarousel extends ConsumerStatefulWidget {
  final String? type; // 'grocery', 'food', etc.
  final ValueChanged<bool>? onSwitchMode;

  const DynamicHeroBannerCarousel({
    super.key,
    this.type = 'grocery',
    this.onSwitchMode,
  });

  @override
  ConsumerState<DynamicHeroBannerCarousel> createState() => _DynamicHeroBannerCarouselState();
}

class _DynamicHeroBannerCarouselState extends ConsumerState<DynamicHeroBannerCarousel>
    with WidgetsBindingObserver {
  PageController? _pageController;
  Timer? _autoPlayTimer;
  bool _isInteracting = false;
  int _activeCardIndex = 0;
  int _lastCardsCount = 0;

  static const int _kVirtualMultiplier = 10000;
  int _initialVirtualPage = 5000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoPlay();
    } else {
      _stopAutoPlay();
    }
  }

  void _initOrUpdateController(int count) {
    if (count == _lastCardsCount && _pageController != null) return;
    _lastCardsCount = count;

    _stopAutoPlay();
    _pageController?.dispose();

    if (count <= 1) {
      _activeCardIndex = 0;
      _pageController = PageController(viewportFraction: 0.86);
      return;
    }

    _initialVirtualPage = (_kVirtualMultiplier ~/ 2) - ((_kVirtualMultiplier ~/ 2) % count);
    _pageController = PageController(
      viewportFraction: 0.86,
      initialPage: _initialVirtualPage,
    );
    _activeCardIndex = 0;

    _startAutoPlay();
  }

  void _startAutoPlay() {
    _stopAutoPlay();
    if (_lastCardsCount <= 1) return;

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || _isInteracting || _pageController == null || !_pageController!.hasClients) {
        return;
      }
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _goToIndex(int targetIndex, int totalCount) {
    if (_pageController == null || !_pageController!.hasClients || totalCount <= 1) return;
    HapticFeedback.selectionClick();

    final currentPage = _pageController!.page?.round() ?? _initialVirtualPage;
    final currentActual = currentPage % totalCount;
    final diff = targetIndex - currentActual;
    final nextTarget = currentPage + diff;

    _pageController!.animateToPage(
      nextTarget,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoPlay();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _handleCardTap(BuildContext context, BrandOfferCardData card) async {
    HapticFeedback.lightImpact();
    var link = (card.ctaUrl ?? card.redirectUrl ?? '').trim();
    if (link.isEmpty) return;

    // Normalize if link is full FastMinute / FastKirana URL
    if (link.startsWith('http://fastkirana.in') ||
        link.startsWith('https://fastkirana.in') ||
        link.startsWith('http://www.fastkirana.in') ||
        link.startsWith('https://www.fastkirana.in') ||
        link.startsWith('http://fastminute.in') ||
        link.startsWith('https://fastminute.in') ||
        link.startsWith('http://www.fastminute.in') ||
        link.startsWith('https://www.fastminute.in')) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        link = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      }
    }

    final lower = link.toLowerCase().trim();

    // 0. Gifting Boutique Route (/gift, /gifting, gift-for-someone)
    final isGifting = lower == '/gift' ||
        lower == 'gift' ||
        lower == '/gifting' ||
        lower == 'gifting' ||
        lower.contains('gift-for-someone') ||
        lower.contains('send-gift') ||
        card.title.toLowerCase().contains('gift for someone') ||
        card.title.toLowerCase().contains('send a gift');

    if (isGifting) {
      if (context.mounted) {
        Navigator.push(
          context,
          FadeSlideRoute(page: const SendGiftScreen()),
        );
      }
      return;
    }

    // 0. Mode Switch: Food / Restaurants
    final isFoodSwitch = lower.contains('mode=food') ||
        lower == '/food' ||
        lower == 'food' ||
        lower == '/restaurants' ||
        lower == 'restaurants' ||
        lower == '/cafe' ||
        lower == 'cafe' ||
        card.title.toLowerCase() == 'restaurant';

    if (isFoodSwitch) {
      if (widget.onSwitchMode != null) {
        widget.onSwitchMode!(false);
        return;
      }
      final restaurants = ref.read(restaurantsProvider).valueOrNull ?? [];
      if (restaurants.isNotEmpty && context.mounted) {
        final rest = restaurants.first;
        Navigator.push(
          context,
          FadeSlideRoute(
            page: CafeMenuScreen(
              restaurantId: rest.id,
              restaurantName: rest.name,
              restaurant: rest,
            ),
          ),
        );
      }
      return;
    }

    // Mode Switch: Grocery
    final isGrocerySwitch = lower.contains('mode=grocery') ||
        lower == '/grocery' ||
        lower == 'grocery';

    if (isGrocerySwitch) {
      if (widget.onSwitchMode != null) {
        widget.onSwitchMode!(true);
        return;
      }
      return;
    }

    // 1. External Social / Web URLs
    final isExplicitWebUrl = link.startsWith('http://') || link.startsWith('https://');
    final isSocialScheme = link.startsWith('instagram://') ||
        link.startsWith('whatsapp://') ||
        link.startsWith('tel:') ||
        link.startsWith('mailto:');
    final isSocialDomain = link.startsWith('instagram.com') ||
        link.startsWith('www.instagram.com') ||
        link.startsWith('wa.me') ||
        link.startsWith('facebook.com') ||
        link.startsWith('www.facebook.com') ||
        link.startsWith('youtube.com') ||
        link.startsWith('www.youtube.com');

    if (isExplicitWebUrl || isSocialScheme || isSocialDomain) {
      final targetUrl = isSocialDomain ? 'https://$link' : link;
      final uri = Uri.tryParse(targetUrl);
      if (uri != null) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        } catch (e) {
          debugPrint('[DynamicHeroBanner] Failed to launch external url $targetUrl: $e');
        }
      }
      return;
    }

    // 2. Restaurant Link (/restaurant/{slug})
    if (link.startsWith('/restaurant/') || link.startsWith('restaurant/')) {
      final slug = link.replaceFirst(RegExp(r'^/?restaurant/'), '').trim();
      final restaurantsAsync = ref.read(restaurantsProvider);
      final rest = restaurantsAsync.valueOrNull?.firstWhere(
        (r) => r.slug.toLowerCase() == slug.toLowerCase() || r.id == slug,
        orElse: () => Restaurant(
          id: slug,
          name: card.primaryBrand ?? slug.replaceAll('-', ' '),
          slug: slug,
        ),
      );

      if (context.mounted) {
        Navigator.push(
          context,
          FadeSlideRoute(
            page: CafeMenuScreen(
              restaurantId: rest?.id ?? slug,
              restaurantName: rest?.name ?? card.primaryBrand ?? 'Restaurant',
              restaurant: rest,
            ),
          ),
        );
      }
      return;
    }

    // 3. Category Link (/category/{slug})
    if (link.startsWith('/category/') || link.startsWith('category/')) {
      final slug = link.replaceFirst(RegExp(r'^/?category/'), '').trim();
      final categoriesAsync = ref.read(categoriesProvider);
      final cat = categoriesAsync.valueOrNull?.firstWhere(
        (c) => c.slug.toLowerCase() == slug.toLowerCase() || c.id == slug,
        orElse: () => Category(id: slug, name: slug.replaceAll('-', ' '), slug: slug),
      );

      if (cat != null && context.mounted) {
        Navigator.push(
          context,
          FadeSlideRoute(page: CategoryProductsScreen(category: cat)),
        );
      }
      return;
    }

    // 4. Search Link (/search?q={query})
    if (link.startsWith('/search') || link.startsWith('search')) {
      final uri = Uri.tryParse(link.startsWith('/') ? link : '/$link');
      final query = uri?.queryParameters['q'] ?? '';
      if (context.mounted) {
        Navigator.push(
          context,
          FadeScaleRoute(page: SearchScreen(initialQuery: query)),
        );
      }
      return;
    }

    // 5. Product Link (/product/{slug})
    if (link.startsWith('/product/') || link.startsWith('product/')) {
      final slug = link.replaceFirst(RegExp(r'^/?product/'), '').trim();
      if (context.mounted) {
        Navigator.push(
          context,
          FadeScaleRoute(page: SearchScreen(initialQuery: slug.replaceAll('-', ' '))),
        );
      }
      return;
    }

    // 6. Generic Fallback
    if (link.contains('.')) {
      final fallbackUrl = link.startsWith('http') ? link : 'https://$link';
      final uri = Uri.tryParse(fallbackUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('[DynamicHeroBanner] Generic fallback launch failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(brandOfferCardsProvider(widget.type));
    final giftingConfig = ref.watch(giftingStoreConfigProvider).valueOrNull;

    final rawCards = offersAsync.valueOrNull ?? [];
    final List<CategoryCardData> cards = List.of(rawCards);

    // If in grocery mode and no gifting card exists, append the premier gifting card
    if ((widget.type == 'grocery' || widget.type == null) &&
        !cards.any((c) => c.ctaUrl == '/gift' || c.redirectUrl == '/gift')) {
      cards.add(
        CategoryCardData(
          id: 'gift-for-someone-banner',
          title: (giftingConfig != null && giftingConfig.bannerTitle.isNotEmpty)
              ? '${giftingConfig.bannerTitle} 🎁'
              : 'Send a Gift in 15 Mins 🎁',
          subtitle: (giftingConfig != null && giftingConfig.bannerSubtitle.isNotEmpty)
              ? giftingConfig.bannerSubtitle
              : 'Chocolates, Cakes, Mithai & Custom Cards delivered at doorstep',
          eyebrowTag: 'SURPRISE SOMEONE',
          ctaText: 'SEND GIFT →',
          ctaUrl: '/gift',
          redirectUrl: '/gift',
          cardType: 'hero',
          type: 'grocery',
          imageUrl: (giftingConfig != null && giftingConfig.bannerImageUrl.trim().isNotEmpty)
              ? giftingConfig.bannerImageUrl.trim()
              : 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=800&q=80',
          gradientColorsHex: const ['#E11D48', '#BE123C', '#881337'],
          isActive: true,
          sortOrder: 1,
        ),
      );
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    _initOrUpdateController(cards.length);

    final screenWidth = MediaQuery.of(context).size.width;
    // 86% of screen width with 1.8:1 aspect ratio
    final double cardWidth = screenWidth * 0.86;
    final double cardHeight = (cardWidth / 1.8).clamp(155.0, 240.0);
    final bool isInfinite = cards.length > 1;
    final int itemCount = isInfinite ? _kVirtualMultiplier : cards.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        // Carousel Viewport
        SizedBox(
          height: cardHeight,
          child: Listener(
            onPointerDown: (_) {
              _isInteracting = true;
              _stopAutoPlay();
            },
            onPointerUp: (_) {
              _isInteracting = false;
              _startAutoPlay();
            },
            onPointerCancel: (_) {
              _isInteracting = false;
              _startAutoPlay();
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: itemCount,
              onPageChanged: (virtualIndex) {
                final realIdx = virtualIndex % cards.length;
                if (_activeCardIndex != realIdx) {
                  setState(() {
                    _activeCardIndex = realIdx;
                  });
                }
              },
              itemBuilder: (context, virtualIndex) {
                final realIndex = virtualIndex % cards.length;
                final card = cards[realIndex];

                return AnimatedBuilder(
                  animation: _pageController!,
                  builder: (context, child) {
                    double pageOffset = _pageController!.hasClients &&
                            _pageController!.position.haveDimensions
                        ? (_pageController!.page ?? virtualIndex.toDouble())
                        : virtualIndex.toDouble();

                    final double delta = (pageOffset - virtualIndex).abs();
                    // Active scale 1.0, inactive 0.94
                    final double scale = (1.0 - (delta * 0.06)).clamp(0.94, 1.0);
                    // Active opacity 1.0, inactive 0.85
                    final double opacity = (1.0 - (delta * 0.15)).clamp(0.85, 1.0);

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                    );
                  },
                  child: _buildBannerSlide(
                    context,
                    card,
                    cardWidth,
                    cardHeight,
                  ),
                );
              },
            ),
          ),
        ),

        // Pagination Row: Elongated FastMinute Red Pill + Dots + Counter Badge
        if (cards.length > 1) ...[
          const SizedBox(height: 10),
          _buildPaginationBar(cards.length),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }

  /// Builds a single premium banner slide with 22px rounded corners,
  /// full-bleed high resolution visual media, inner glass rim and smooth tap handling
  Widget _buildBannerSlide(
    BuildContext context,
    BrandOfferCardData card,
    double width,
    double height,
  ) {
    final hasMedia = (card.imageUrl != null && card.imageUrl!.trim().isNotEmpty) ||
        (card.videoUrl != null && card.videoUrl!.trim().isNotEmpty) ||
        (card.imageAsset != null && card.imageAsset!.trim().isNotEmpty);

    // Resolve gradient backdrops if media is missing
    List<Color> gradients = [
      const Color(0xFF881337), // Rose 900
      const Color(0xFFBE123C), // Rose 700
    ];
    if (card.gradientColorsHex != null && card.gradientColorsHex!.isNotEmpty) {
      gradients = card.gradientColorsHex!.map((hexStr) {
        try {
          final h = hexStr.trim().replaceFirst('#', '');
          return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
        } catch (_) {
          return const Color(0xFF881337);
        }
      }).toList();
    }

    return Padding(
      // 5.5px horizontal margin on each side = 11px total gap between adjacent slides
      padding: const EdgeInsets.symmetric(horizontal: 5.5),
      child: GestureDetector(
        onTap: () => _handleCardTap(context, card),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. High-Performance Full Bleed Visual Media
              if (hasMedia)
                CardMediaWidget(
                  imageUrl: card.imageUrl,
                  videoUrl: card.videoUrl,
                  imageAsset: card.imageAsset,
                  borderRadius: 22,
                  fit: BoxFit.cover,
                  showLiveBadge: false,
                  showPauseButton: false,
                )
              else
                // Dynamic Gradient Backdrop
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradients,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (card.eyebrowTag != null && card.eyebrowTag!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card.eyebrowTag!.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (card.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          card.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.ctaText ?? 'Explore Store',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Hardware Double-Bezel Glass Rim
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the animated pagination pill indicators with counter badge
  Widget _buildPaginationBar(int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dots / Pill Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalCount, (index) {
            final isActive = index == _activeCardIndex;
            return GestureDetector(
              onTap: () => _goToIndex(index, totalCount),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: isActive ? 22.0 : 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE11D48) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        // Counter Badge (e.g. "1/5")
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: Text(
            '${_activeCardIndex + 1}/$totalCount',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
