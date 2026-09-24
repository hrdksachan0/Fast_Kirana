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
import 'package:url_launcher/url_launcher.dart';
import 'curated_brand_offer_card.dart';

/// Replaces old static single banner with interactive, high-impact multi-cards
/// (Sneaker Street Dark Hero, 2x2 Bento Grid, and HRX Editorial).
class DynamicHeroBannerCarousel extends ConsumerWidget {
  final String? type; // 'grocery', 'food', etc.

  const DynamicHeroBannerCarousel({
    super.key,
    this.type = 'grocery',
  });

  Future<void> _handleCardTap(BuildContext context, WidgetRef ref, BrandOfferCardData card) async {
    HapticFeedback.lightImpact();
    var link = (card.ctaUrl ?? card.redirectUrl ?? '').trim();
    if (link.isEmpty) return;

    // Normalize if link is full FastKirana URL (e.g. https://www.fastkirana.in/category/fruits-vegetables)
    if (link.startsWith('http://fastkirana.in') ||
        link.startsWith('https://fastkirana.in') ||
        link.startsWith('http://www.fastkirana.in') ||
        link.startsWith('https://www.fastkirana.in')) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        link = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      }
    }

    // 1. External Social / Web URLs (Instagram, WhatsApp, YouTube, External Website)
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

    // 6. Generic Fallback: If link contains a dot (domain) or URI, try launching externally
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
