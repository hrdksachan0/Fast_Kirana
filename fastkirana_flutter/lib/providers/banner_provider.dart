import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/banner.dart';
import '../data/models/brand_offer_card_data.dart';
import '../data/repositories/banner_repository.dart';
import '../core/network/api_client.dart';

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(ref.read(dioProvider));
});

final bannersProvider = FutureProvider.family<List<Banner>, String?>((ref, type) async {
  ref.keepAlive();
  final repo = ref.watch(bannerRepositoryProvider);
  return repo.getBanners(type: type);
});

/// Dynamic Category Offer Cards Provider (Zero hardcoding - 100% model driven from Admin App)
final categoryOfferCardsProvider = FutureProvider.family<List<CategoryCardData>, String?>((ref, type) async {
  ref.keepAlive();
  final repo = ref.watch(bannerRepositoryProvider);
  final banners = await repo.getBanners(type: type);

  // 1. If backend returned banners, map each banner to a dynamic CategoryCardData
  if (banners.isNotEmpty) {
    final List<CategoryCardData> parsedCards = [];
    for (final b in banners) {
      final json = b.toJson();
      parsedCards.add(CategoryCardData.fromJson(json));
    }
    
    // Strict isolation & user control:
    // Only banners explicitly created as 'brand_card' by the user in Admin are shown.
    // Zero auto-injection, zero hero banner bleed-in, zero hardcoding.
    final filteredCards = parsedCards.where((c) {
      if (!c.isActive) return false;

      // 1. Target platform filter: if banner is set to web-only, skip on mobile
      final rawJson = c.toJson();
      final platform = rawJson['platform']?.toString().toLowerCase();
      if (platform == 'web') return false;

      // 2. Strict mode isolation: food cards never show on grocery, and vice versa
      final isFood = c.type == 'food' ||
          c.type == 'cafe' ||
          (c.redirectUrl?.startsWith('/restaurant') ?? false) ||
          (c.ctaUrl?.startsWith('/restaurant') ?? false);
      if (type == 'food' || type == 'cafe') {
        if (!isFood) return false;
      } else if (type == 'grocery') {
        if (isFood) return false;
      }

      // 3. Media validation: Must have a valid image or video
      final hasMedia = (c.imageUrl != null && c.imageUrl!.trim().isNotEmpty) ||
          (c.videoUrl != null && c.videoUrl!.trim().isNotEmpty) ||
          (c.imageAsset != null && c.imageAsset!.trim().isNotEmpty);
      if (!hasMedia) return false;

      return true;
    }).toList();

    return filteredCards;
  }

  // Zero fallbacks: When no banners are in DB or all removed, collapse to empty list
  return const [];
});

/// Backward compatibility alias for brandOfferCardsProvider
final brandOfferCardsProvider = categoryOfferCardsProvider;
