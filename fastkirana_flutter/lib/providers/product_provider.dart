import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product.dart';
import '../data/models/category.dart';
import '../data/repositories/product_repository.dart';
import '../core/network/api_client.dart';
import '../core/utils/restaurant_utils.dart';
import 'cart_provider.dart';

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
  return repo.getProducts(limit: 10);
});

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, categoryId) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  // Home page (null category) needs more products to fill all category sections.
  // Category-specific screens only need ~30.
  final limit = categoryId == null ? 100 : 30;
  return repo.getProducts(category: categoryId, limit: limit);
});

// Single shared product catalog for home screen — fetches ALL products once,
// sections filter locally instead of each making separate API calls.
final homeProductCatalogProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts(limit: 300);
});

final cartUpsellProductsProvider = FutureProvider.family<List<Product>, List<String>>((ref, productIds) async {
  if (productIds.isEmpty) return [];
  final repo = ref.watch(productRepositoryProvider);

  final cart = ref.read(cartProvider).valueOrNull;
  final cartItems = cart?.items ?? [];
  final cleanIds = productIds.map((id) => id.split('_').first).toSet();

  // 1. Detect active restaurant in cart (e.g. A.S. Restaurant or Wedson)
  String? activeOutlet;
  String? activeRestaurantId;
  for (final item in cartItems) {
    if (isRestaurantProduct(item.product)) {
      activeOutlet = getOutletName(item.product);
      activeRestaurantId = item.product.restaurantId ?? item.product.restaurant?.id;
      break;
    }
  }

  // 2. Strict Filter Function:
  // - If Cart has Restaurant 'AS': ONLY allow 'AS' dishes OR Darkstore Groceries. Ban Wedson / other restaurants!
  // - If Cart is Pure Grocery: ONLY allow Darkstore Groceries. Ban ALL restaurant dishes!
  bool isAllowed(Product p) {
    if (cleanIds.contains(p.id)) return false;
    final isRest = isRestaurantProduct(p);

    if (activeOutlet != null) {
      // Cart has a restaurant item (e.g. A.S. Restaurant)
      if (!isRest) return true; // Darkstore groceries & beverages allowed
      final pOutlet = getOutletName(p);
      return pOutlet == activeOutlet ||
          (activeRestaurantId != null && p.restaurantId == activeRestaurantId);
    } else {
      // Pure grocery cart: STRICTLY Darkstore Groceries only!
      return !isRest;
    }
  }

  // 3. Fetch from Next.js Upsell API
  final upsells = await repo.getUpsellRecommendations(productIds);
  final filteredUpsells = upsells.where(isAllowed).toList();
  if (filteredUpsells.isNotEmpty) {
    return filteredUpsells.take(8).toList();
  }

  // 3. Smart Fallback: one single product fetch instead of 3 parallel calls
  List<Product> all = [];
  try {
    if (activeRestaurantId != null || activeOutlet != null) {
      final rId = activeRestaurantId ?? (activeOutlet?.toLowerCase().contains('wedson') == true ? outletWedsonId : outletAsRestaurantId);
      // Fetch restaurant products + a broader batch to cover snacks/beverages
      final results = await Future.wait([
        repo.getProducts(restaurantId: rId, limit: 30),
        repo.getProducts(limit: 80),  // generic pool for grocery upsells
      ]);
      all = [...results[0], ...results[1]];
    } else {
      all = await repo.getProducts(limit: 80);
    }
  } catch (_) {
    all = await repo.getProducts(limit: 80);
  }

  return all.where(isAllowed).take(8).toList();
});

