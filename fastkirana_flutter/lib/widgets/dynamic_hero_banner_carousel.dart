import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/design_system.dart';
import '../core/routes/page_transitions.dart';
import '../data/models/brand_offer_card_data.dart';
import '../data/models/category.dart';
import '../data/models/restaurant.dart';
import '../data/repositories/banner_repository.dart';
import '../providers/banner_provider.dart';
import '../providers/product_provider.dart';
import '../providers/restaurant_provider.dart';
import '../features/categories/category_products_screen.dart';
import '../features/cafe/cafe_menu_screen.dart';
import '../features/search/search_screen.dart';
import 'curated_brand_offer_card.dart';

/// Replaces old static single banner with interactive, high-impact multi-cards
/// (Sneaker Street Dark Hero, 2x2 Bento Grid, and HRX Editorial).
class DynamicHeroBannerCarousel extends ConsumerWidget {
  final String? type; // 'grocery', 'food', etc.

  const DynamicHeroBannerCarousel({
    super.key,
    this.type = 'grocery',
  });

  void _handleCardTap(BuildContext context, WidgetRef ref, BrandOfferCardData card) {
    HapticFeedback.lightImpact();
    final link = card.ctaUrl ?? card.redirectUrl ?? '';
    if (link.isEmpty) return;

    // 1. Restaurant Link (/restaurant/{slug})
    if (link.startsWith('/restaurant/')) {
      final slug = link.replaceFirst('/restaurant/', '').trim();
      final restaurantsAsync = ref.read(restaurantsProvider);
      final rest = restaurantsAsync.valueOrNull?.firstWhere(
        (r) => r.slug.toLowerCase() == slug.toLowerCase() || r.id == slug,
        orElse: () => Restaurant(
          id: slug,
          name: card.primaryBrand ?? slug.replaceAll('-', ' '),
          slug: slug,
        ),
      );

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

    // 4. Product Link (/product/{slug})
    if (link.startsWith('/product/')) {
      final slug = link.replaceFirst('/product/', '').trim();
      Navigator.push(
        context,
        FadeScaleRoute(page: SearchScreen(initialQuery: slug.replaceAll('-', ' '))),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(brandOfferCardsProvider(type));

    return offersAsync.when(
      data: (cards) {
        // Zero screen collapse: If zero banners, completely collapse to 0 height
        if (cards.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CuratedBrandOffersCarousel(
            items: cards,
            cardWidth: 260,
            cardHeight: 380,
            onCardTap: (card) => _handleCardTap(context, ref, card),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
