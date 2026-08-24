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
    int limit = 1000,
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
          'limit': limit,
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

  static const Map<String, List<String>> _categoryAliases = {
    'cmqh1haw30000zcid4vj7i1yj': ['fruits-vegetables', 'fruits & vegetables', 'fruits', 'vegetables', 'fresh', 'farm'],
    'cmt76olwr000104l18kcelx0i': ['healthy-foods', 'healthy foods', 'healthy', 'diet', 'dry-fruits', 'oats'],
    'cmsfuzs73000404l7q139nk61': ['kitchen-needs', 'kitchen needs', 'atta-rice-dal', 'atta', 'rice', 'dal', 'oil', 'grocery', 'spices'],
    'cmqh1hb920002zcidoywpi240': ['snacks-munchies', 'snacks & munchies', 'snacks', 'munchies', 'chips', 'namkeen', 'biscuits'],
    'cmqgzqfz20008vkidoycqg5u2': ['beverages', 'beverages & drinks', 'drinks', 'cold drinks', 'juices', 'soda', 'tea', 'coffee'],
    'cmqgzqfv70007vkider7h6e4j': ['ice-cream', 'ice cream & desserts', 'ice cream', 'desserts', 'kulfi', 'cones'],
    'cmseowmy7000004i562szts34': ['chocolates', 'chocolates & sweets', 'sweets', 'chocolate', 'silk', 'cadbury'],
    'cmqh1hbyc0005zcidr45bj1ac': ['bakery', 'bakery & biscuits', 'biscuits', 'cookies', 'bread', 'rusk'],
    'cmt74ypjp000004laoi3athcy': ['packaged-foods', 'packaged foods', 'instant', 'noodles', 'maggie', 'pasta'],
    'cmqh1hblj0003zcidm9gq5net': ['personal-care', 'personal care & hygiene', 'personal care', 'soap', 'shampoo', 'creams'],
    'cmrv2psby000004ldl25xjrlt': ['home-needs-and-cleaning', 'home needs & cleaning', 'cleaning', 'household', 'detergent', 'cleaner'],
    'cmt59fuss0000tgidoc35458x': ['restaurant-food', 'fast food & restaurant kitchen', 'cafe', 'food', 'restaurant'],
  };

  List<Product> _filterProducts(
    List<Product> products, {
    String? category,
    String? search,
    String? restaurantId,
  }) {
    var result = products;

    if (category != null && category.isNotEmpty && category != 'all') {
      final catLower = category.toLowerCase().trim();
      final catSlugNormalized = catLower.replaceAll(' ', '-').replaceAll('&', 'and').replaceAll('---', '-');
      result = result.where((p) {
        final prodCatSlug = (p.category?.slug ?? '').toLowerCase();
        final prodCatId = (p.category?.id ?? p.categoryId).toLowerCase();
        final prodCatName = (p.category?.name ?? '').toLowerCase();

        // 1. Direct ID match
        if (prodCatId == catLower || p.categoryId.toLowerCase() == catLower) return true;

        // 2. Direct Slug match
        if (prodCatSlug.isNotEmpty && (prodCatSlug == catLower || prodCatSlug == catSlugNormalized)) return true;

        // 3. Check aliases for this product's categoryId
        final aliasesForProd = _categoryAliases[p.categoryId] ?? _categoryAliases[prodCatId] ?? [];
        if (aliasesForProd.any((a) => a == catLower || a == catSlugNormalized || a.contains(catLower) || catLower.contains(a))) return true;

        // 4. Check if the query category itself matches any alias in our lookup table
        for (final entry in _categoryAliases.entries) {
          if (entry.value.any((a) => a == catLower || a == catSlugNormalized || a.contains(catLower) || catLower.contains(a))) {
            if (entry.key.toLowerCase() == p.categoryId.toLowerCase() || entry.key.toLowerCase() == prodCatId) return true;
          }
        }

        // 5. Name match
        if (prodCatName.isNotEmpty && (prodCatName.contains(catLower) || catLower.contains(prodCatName))) return true;

        // 6. Tags match
        if (p.tags.any((t) => t.toLowerCase().contains(catLower) || catLower.contains(t.toLowerCase()))) return true;

        return false;
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
      final response = await dio.get('/api/categories');
      final data = response.data;
      if (data is List) {
        return data.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    try {
      final allProducts = await getProducts(limit: 500);
      final Map<String, Category> uniqueCategories = {};

      for (final p in allProducts) {
        if (p.category != null && p.category!.slug.isNotEmpty) {
          final cat = p.category!;
          final slug = cat.slug.toLowerCase().trim();
          if (!uniqueCategories.containsKey(slug) && slug != 'restaurant') {
            uniqueCategories[slug] = Category(
              id: cat.id.isNotEmpty ? cat.id : 'cat_$slug',
              name: cat.name.isNotEmpty ? cat.name : slug.replaceAll('-', ' ').toUpperCase(),
              slug: slug,
              imageUrl: cat.imageUrl,
              sortOrder: uniqueCategories.length + 1,
            );
          }
        }
      }

      if (uniqueCategories.isNotEmpty) {
        return uniqueCategories.values.toList();
      }
    } catch (_) {}

    return [];
  }
}