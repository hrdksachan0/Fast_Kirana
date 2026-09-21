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
    
    // Strict isolation: food cards never show on grocery, and vice versa
    final filteredCards = parsedCards.where((c) {
      if (!c.isActive) return false;
      final isFood = c.type == 'food' ||
          c.type == 'cafe' ||
          (c.redirectUrl?.startsWith('/restaurant') ?? false) ||
          (c.ctaUrl?.startsWith('/restaurant') ?? false);
      if (type == 'food' || type == 'cafe') {
        if (!isFood) return false;
      } else if (type == 'grocery') {
        if (isFood) return false;
      }

      // Mobile platform filter: if banner is set to web-only, ignore
      // Note: Both 'hero' and 'brand_card' placements are fully supported on mobile carousel

      return true;
    }).toList();

    return filteredCards;
  }

  // Zero fallbacks: When no banners are in DB or all removed, collapse to empty list
  return const [];
});

/// Backward compatibility alias for brandOfferCardsProvider
final brandOfferCardsProvider = categoryOfferCardsProvider;
