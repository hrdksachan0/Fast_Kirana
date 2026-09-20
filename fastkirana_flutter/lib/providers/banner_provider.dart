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
      final isFood = c.type == 'food' ||
          c.type == 'cafe' ||
          (c.redirectUrl?.startsWith('/restaurant') ?? false) ||
          (c.ctaUrl?.startsWith('/restaurant') ?? false);
      if (type == 'food' || type == 'cafe') {
        return isFood;
      } else if (type == 'grocery') {
        return !isFood;
      }
      return true;
    }).toList();

    if (filteredCards.isNotEmpty) {
      return filteredCards;
    }
  }

  // 2. Pure data driven - return empty list when no banners exist
  return const [];
});

/// Backward compatibility alias for brandOfferCardsProvider
final brandOfferCardsProvider = categoryOfferCardsProvider;
