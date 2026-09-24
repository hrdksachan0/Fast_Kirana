import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product.dart';
import '../data/models/category.dart';
import '../data/repositories/product_repository.dart';
import '../core/network/api_client.dart';
import '../core/utils/restaurant_utils.dart';
import 'cart_provider.dart';
import 'store_hub_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.read(dioProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getCategories();
});

final trendingProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  final hub = ref.watch(currentStoreHubProvider);
  return repo.getProducts(limit: 10, storeId: hub.id);
});

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, categoryKey) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  final hub = ref.watch(currentStoreHubProvider);
  if (categoryKey == null || categoryKey.isEmpty) {
    return repo.getProducts(limit: 500, storeId: hub.id, includeRestaurants: false);
  }
  final resolvedId = ProductRepository.resolveCategoryId(categoryKey);
  final isId = resolvedId.toUpperCase().startsWith('CAT-') || resolvedId.toUpperCase().startsWith('SUB-');
  return repo.getProducts(
    categoryId: isId ? resolvedId : null,
    category: isId ? null : categoryKey,
    limit: 500,
    storeId: hub.id,
    includeRestaurants: false,
  );
});

final productsByRestaurantProvider = FutureProvider.family<List<Product>, String>((ref, restaurantId) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  final hub = ref.watch(currentStoreHubProvider);
  return repo.getProducts(restaurantId: restaurantId, limit: 500, storeId: hub.id, includeRestaurants: true);
});

// Single shared product catalog for home screen — fetches ALL products once,
// sections filter locally instead of each making separate API calls.
final homeProductCatalogProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  final hub = ref.watch(currentStoreHubProvider);
  return repo.getProducts(limit: 1000, storeId: hub.id, includeRestaurants: false, forceRefresh: true);
});

final cartUpsellProductsProvider = FutureProvider.family<List<Product>, List<String>>((ref, productIds) async {
  if (productIds.isEmpty) return [];
  final repo = ref.watch(productRepositoryProvider);

  final cart = ref.read(cartProvider).valueOrNull;
  final cartItems = cart?.items ?? [];
  final cleanIds = productIds.map((id) => id.split('_').first).toSet();

  // 1. Detect active restaurant and food items in cart
  String? activeOutlet;
  String? activeRestaurantId;
  bool hasFoodItem = false;
  for (final item in cartItems) {
    if (isRestaurantProduct(item.product)) {
      activeOutlet = getOutletName(item.product);
      activeRestaurantId = item.product.restaurantId ?? item.product.restaurant?.id;
    }
    final nameLower = item.product.name.toLowerCase();
    if (nameLower.contains('biryani') ||
        nameLower.contains('burger') ||
        nameLower.contains('pizza') ||
        nameLower.contains('roll') ||
        nameLower.contains('meal') ||
        nameLower.contains('thali') ||
        nameLower.contains('noodle') ||
        nameLower.contains('rice') ||
        nameLower.contains('chicken') ||
        nameLower.contains('paneer') ||
        isRestaurantProduct(item.product)) {
      hasFoodItem = true;
    }
  }

  int foodUpsellScore(Product p) {
    final n = p.name.toLowerCase();
    final cat = (p.category?.slug ?? '').toLowerCase();
    final tags = p.tags.map((t) => t.toLowerCase()).toList();

    // Priority 0: Thums Up, Coke, Coca Cola, Pepsi, Sprite, Limca, Cold Drinks
    if (n.contains('thums up') || n.contains('thumsup') || n.contains('coke') ||
        n.contains('coca cola') || n.contains('pepsi') || n.contains('sprite') ||
        n.contains('cold drink') || n.contains('limca') || n.contains('fanta') ||
        n.contains('frooti') || tags.contains('cold-drink') || tags.contains('thums-up') || tags.contains('coke')) {
      return 0;
    }
    // Priority 1: Ice Cream, Sundae, Kulfi, Shakes, Cold Coffee
    if (cat.contains('ice-cream') || cat.contains('shake') ||
        n.contains('ice cream') || n.contains('kulfi') || n.contains('cornetto') ||
        n.contains('chocobar') || n.contains('cold coffee') || n.contains('shake') ||
        tags.contains('ice-cream')) {
      return 1;
    }
    // Priority 2: General beverages
    if (cat == 'beverages' || cat == 'drinks' || tags.contains('beverages')) {
      return 2;
    }
    return 3;
  }

  // 2. Strict Filter Function:
  // - If Cart has Restaurant 'AS': ONLY allow 'AS' dishes OR Darkstore Groceries. Ban Wedson / other restaurants!
  // - If Cart is Pure Grocery: ONLY allow Darkstore Groceries. Ban ALL restaurant dishes!
  bool isAllowed(Product p) {
    if (cleanIds.contains(p.id)) return false;
    final isRest = isRestaurantProduct(p);

    if (activeOutlet != null) {
      // Cart has a restaurant item (e.g. A.S. Restaurant, Wedson, etc.)
      if (!isRest) {
        // Strictly allow only darkstore beverages and ice cream for restaurant orders
        final cat = (p.category?.slug ?? '').toLowerCase();
        return cat == 'beverages' || cat == 'ice-cream';
      }
      final pOutlet = getOutletName(p);
      return pOutlet == activeOutlet ||
          (activeRestaurantId != null && p.restaurantId == activeRestaurantId);
    } else {
      // Pure grocery cart: STRICTLY Darkstore Groceries only!
      return !isRest;
    }
  }

  // 3. Fetch from Upsell API
  final upsells = await repo.getUpsellRecommendations(productIds);
  final filteredUpsells = upsells.where(isAllowed).toList();
  if (filteredUpsells.isNotEmpty) {
    if (hasFoodItem) {
      filteredUpsells.sort((a, b) => foodUpsellScore(a).compareTo(foodUpsellScore(b)));
    }
    return filteredUpsells.take(8).toList();
  }

  // 4. Smart Fallback: fetch dishes + chilled beverages & ice cream
  List<Product> all = [];
  try {
    if (activeRestaurantId != null || activeOutlet != null) {
      final rId = activeRestaurantId ?? RestaurantRegistry.find(activeOutlet)?.id;
      // Fetch restaurant dishes + darkstore chilled drinks & ice-creams
      final results = await Future.wait([
        repo.getProducts(restaurantId: rId, limit: 30),
        repo.getProducts(category: 'beverages,ice-cream', limit: 40),
      ]);
      all = [...results[0], ...results[1]];
    } else if (hasFoodItem) {
      final results = await Future.wait([
        repo.getProducts(category: 'beverages,ice-cream', limit: 40),
        repo.getProducts(limit: 40),
      ]);
      all = [...results[0], ...results[1]];
    } else {
      all = await repo.getProducts(limit: 80);
    }
  } catch (e, st) { LoggerService.error('ProductProvider: upsell fallback fetch failed', e, st);
    all = await repo.getProducts(limit: 80);
  }

  final candidateList = all.where(isAllowed).toList();
  if (hasFoodItem) {
    candidateList.sort((a, b) => foodUpsellScore(a).compareTo(foodUpsellScore(b)));
  }
  return candidateList.take(8).toList();
});

