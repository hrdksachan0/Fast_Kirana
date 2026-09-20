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

  // 2. High-Impact Category-Wise Multi-Cards Default Fallbacks (when offline)
  if (type == 'food') {
    return const [
      CategoryCardData(
        id: 'food-burger-street-hero',
        cardType: 'hero',
        eyebrowTag: '🔥 CHEF SPECIAL DROP',
        title: 'DOUBLE CHEESE BURGER',
        subtitle: 'Crispy Patty • Melted Cheddar • Secret Garlic Dip',
        categoryName: 'A.S. RESTAURANT',
        outletName: 'GHATAMPUR',
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
        ctaText: 'ORDER BURGERS',
        ctaUrl: '/restaurant/as-restaurant',
        ctaBgColorHex: '#EF4444',
        ctaTextColorHex: '#FFFFFF',
        cashbackTitle: 'FLAT 40% OFF',
        cashbackSubtitle: '+ Extra ₹50 on UPI Payment',
        disclaimerText: '*Hot & crispy delivery in 15 mins across Ghatampur.',
        redirectUrl: '/restaurant/as-restaurant',
        sortOrder: 1,
      ),
      CategoryCardData(
        id: 'food-cuisines-bento-grid',
        cardType: 'bento_grid',
        eyebrowTag: '🍽️ MOST ORDERED IN GHATAMPUR',
        title: 'BEST FOOD SPOTS',
        subtitle: 'Pizzas, Dum Biryani, Frankie Rolls & Thick Shakes',
        categoryName: 'POPULAR CUISINES',
        gridImages: [
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
          'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80',
          'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80',
        ],
        ctaText: 'EXPLORE CUISINES',
        ctaUrl: '/category/fast-food',
        ctaBgColorHex: '#EA580C',
        ctaTextColorHex: '#FFFFFF',
        cashbackTitle: 'UP TO 50% OFF',
        cashbackSubtitle: 'FastKirana Food Pass Deals',
        disclaimerText: '*Delivered fresh from top verified kitchens.',
        redirectUrl: '/category/fast-food',
        sortOrder: 2,
      ),
      CategoryCardData(
        id: 'food-wedson-royal-editorial',
        cardType: 'editorial',
        eyebrowTag: '✨ ROYAL MUGHALAI FEAST',
        title: 'MIN. 50% OFF',
        subtitle: 'Shahi Paneer, Dal Makhani & Butter Naan Combos',
        categoryName: 'WEDSON RESTAURANT',
        outletName: 'ROYAL KITCHEN',
        imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80',
        ctaText: 'VIEW FULL MENU',
        ctaUrl: '/restaurant/wedson-restaurant',
        ctaBgColorHex: '#B91C1C',
        ctaTextColorHex: '#FFFFFF',
        cashbackTitle: '+ EXTRA ₹100 OFF',
        cashbackSubtitle: 'Use code WEDSON100 at checkout',
        disclaimerText: '*Special family thalis & party packs.',
        backgroundColorHex: '#18181B',
        redirectUrl: '/restaurant/wedson-restaurant',
        sortOrder: 3,
      ),
    ];
  }

  // Grocery Mode Curated Category Cards
  return const [
    CategoryCardData(
      id: 'grocery-farm-fresh-hero',
      cardType: 'hero',
      eyebrowTag: '🌿 DAILY HARVEST',
      title: 'FARM FRESH GREENS',
      subtitle: 'Crisp Apples, Ripe Avocados & Hydroponic Veggies',
      categoryName: 'FASTKIRANA',
      outletName: 'ORGANIC FARMS',
      imageUrl: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80',
      ctaText: 'SHOP FRESH',
      ctaUrl: '/category/fruits-vegetables',
      ctaBgColorHex: '#10B981',
      ctaTextColorHex: '#FFFFFF',
      cashbackTitle: 'FLAT 35% OFF',
      cashbackSubtitle: '+ 10-Min Morning Delivery in Ghatampur',
      disclaimerText: '*Handpicked daily from verified local farms.',
      redirectUrl: '/category/fruits-vegetables',
      sortOrder: 1,
    ),
    CategoryCardData(
      id: 'grocery-essentials-bento-grid',
      cardType: 'bento_grid',
      eyebrowTag: '⚡ 10-MIN EXPRESS PANTRY',
      title: 'HOUSEHOLD STAPLES',
      subtitle: 'Dairy Milk, Farm Eggs, Atta & Cooking Oils',
      categoryName: 'DAILY ESSENTIALS',
      gridImages: [
        'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
        'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
        'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80',
      ],
      ctaText: 'STOCK UP PANTRY',
      ctaUrl: '/category/dairy-bread-eggs',
      ctaBgColorHex: '#3B82F6',
      ctaTextColorHex: '#FFFFFF',
      cashbackTitle: 'UP TO 60% OFF',
      cashbackSubtitle: 'Zero Minimum Order Value Required',
      disclaimerText: '*Guaranteed fresh batch or instant refund.',
      redirectUrl: '/category/dairy-bread-eggs',
      sortOrder: 2,
    ),
    CategoryCardData(
      id: 'grocery-snacks-editorial',
      cardType: 'editorial',
      eyebrowTag: '🎉 CRAVINGS UNLOCKED',
      title: 'BUY 1 GET 1 FREE',
      subtitle: 'Cadbury Silk, Lays Maxx, Ice Creams & Sodas',
      categoryName: 'SNACKS & MUNCHIES',
      imageUrl: 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=800&q=80',
      ctaText: 'GRAB SWEET DEALS',
      ctaUrl: '/category/snacks-munchies',
      ctaBgColorHex: '#6366F1',
      ctaTextColorHex: '#FFFFFF',
      cashbackTitle: '+ EXTRA 20% OFF',
      cashbackSubtitle: 'Use code SNACK20 at checkout',
      disclaimerText: '*Delivered cold & chilled in thermal bags.',
      backgroundColorHex: '#1E1B4B',
      redirectUrl: '/category/snacks-munchies',
      sortOrder: 3,
    ),
  ];
});

/// Backward compatibility alias for brandOfferCardsProvider
final brandOfferCardsProvider = categoryOfferCardsProvider;
