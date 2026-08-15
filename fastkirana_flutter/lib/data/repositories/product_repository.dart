import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../../core/network/api_client.dart';

class ProductRepository {
  final Dio dio;
  List<Product>? _cachedProducts;
  DateTime? _lastFetchTime;

  ProductRepository(this.dio);

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    String? restaurantId,
    int limit = 200,
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();
      // Cache products in memory for 2 minutes to keep app super fast
      if (!forceRefresh &&
          _cachedProducts != null &&
          _lastFetchTime != null &&
          now.difference(_lastFetchTime!).inMinutes < 2) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }

      final response = await dio.get(
        '/api/products',
        queryParameters: {
          'limit': 200,
          if (search != null && search.isNotEmpty) 'search': search,
          if (restaurantId != null && restaurantId.isNotEmpty) 'restaurantId': restaurantId,
        },
      );

      final data = response.data;
      List productsJson = [];
      if (data is List) {
        productsJson = data;
      } else if (data is Map && data['products'] is List) {
        productsJson = data['products'];
      }

      final liveProducts = productsJson
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      _cachedProducts = liveProducts;
      _lastFetchTime = now;

      return _filterProducts(liveProducts, category: category, search: search, restaurantId: restaurantId);
    } catch (e) {
      if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }
      rethrow;
    }
  }

  List<Product> _filterProducts(
    List<Product> products, {
    String? category,
    String? search,
    String? restaurantId,
  }) {
    var result = products;

    if (category != null && category.isNotEmpty && category != 'all') {
      final catLower = category.toLowerCase().trim();
      result = result.where((p) {
        final prodCatSlug = (p.category?.slug ?? p.categoryId).toLowerCase();
        final prodCatName = (p.category?.name ?? '').toLowerCase();
        final matchesSlug = prodCatSlug.contains(catLower) || catLower.contains(prodCatSlug);
        final matchesName = prodCatName.contains(catLower) || catLower.contains(prodCatName);
        final matchesTag = p.tags.any((t) => t.toLowerCase().contains(catLower));
        return matchesSlug || matchesName || matchesTag;
      }).toList();
    }

    if (restaurantId != null && restaurantId.isNotEmpty) {
      result = result.where((p) => p.restaurantId == restaurantId).toList();
    }

    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase().trim();
      result = result.where((p) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = (p.description ?? '').toLowerCase().contains(query);
        final matchesTag = p.tags.any((t) => t.toLowerCase().contains(query));
        final matchesCat = (p.category?.name ?? '').toLowerCase().contains(query);
        return matchesName || matchesDesc || matchesTag || matchesCat;
      }).toList();
    }

    return result;
  }

  Future<Product> getProduct(String id) async {
    try {
      final response = await dio.get('/api/products/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Product.fromJson(data);
      }
      throw ApiException('Product not found');
    } catch (_) {
      if (_cachedProducts != null) {
        return _cachedProducts!.firstWhere(
          (p) => p.id == id,
          orElse: () => throw ApiException('Product not found'),
        );
      }
      rethrow;
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final allProducts = await getProducts(limit: 200);
      // Extract live real categories directly from live products
      final Map<String, Category> uniqueCategories = {};

      for (final p in allProducts) {
        if (p.category != null && p.category!.slug.isNotEmpty) {
          final cat = p.category!;
          if (!uniqueCategories.containsKey(cat.slug) && cat.slug != 'restaurant') {
            uniqueCategories[cat.slug] = Category(
              id: cat.id.isNotEmpty ? cat.id : 'cat_${cat.slug}',
              name: cat.name.isNotEmpty ? cat.name : cat.slug,
              slug: cat.slug,
              imageUrl: cat.imageUrl,
              sortOrder: uniqueCategories.length + 1,
            );
          }
        }
      }

      if (uniqueCategories.isNotEmpty) {
        return uniqueCategories.values.toList();
      }

      // If no categories attached yet, group by tags
      return [
        Category(id: 'cat_snacks', name: 'Snacks & Munchies', slug: 'snacks-munchies', sortOrder: 1),
        Category(id: 'cat_instant', name: 'Instant Foods', slug: 'instant-foods', sortOrder: 2),
        Category(id: 'cat_chocolates', name: 'Chocolates', slug: 'chocolates', sortOrder: 3),
        Category(id: 'cat_kitchen', name: 'Kitchen Needs', slug: 'kitchen-needs', sortOrder: 4),
        Category(id: 'cat_cleaning', name: 'Home Cleaning', slug: 'home-cleaning', sortOrder: 5),
        Category(id: 'cat_ice_cream', name: 'Ice Cream', slug: 'ice-cream', sortOrder: 6),
      ];
    } catch (e) {
      rethrow;
    }
  }
}