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

        final matchesSlug = prodCatSlug.isNotEmpty &&
            (prodCatSlug.contains(catLower) ||
                catLower.contains(prodCatSlug) ||
                prodCatSlug.contains(catSlugNormalized) ||
                catSlugNormalized.contains(prodCatSlug));
        final matchesId = prodCatId == catLower || p.categoryId.toLowerCase() == catLower;
        final matchesName = prodCatName.isNotEmpty &&
            (prodCatName.contains(catLower) || catLower.contains(prodCatName));
        final matchesTag = p.tags.any((t) {
          final tLower = t.toLowerCase();
          return tLower.contains(catLower) || catLower.contains(tLower);
        });

        return matchesSlug || matchesId || matchesName || matchesTag;
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
      final allProducts = await getProducts(limit: 500);
      final Map<String, Category> uniqueCategories = {};

      // Category image mapping with high-res defaults
      final Map<String, String> categoryFallbackImages = {
        'fruits-vegetables': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&auto=format&fit=crop&q=60',
        'snacks-munchies': 'https://images.unsplash.com/photo-1621447504864-d8686e12698c?w=400&auto=format&fit=crop&q=60',
        'instant-foods': 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=400&auto=format&fit=crop&q=60',
        'chocolates': 'https://images.unsplash.com/photo-1548907040-4baa42d10919?w=400&auto=format&fit=crop&q=60',
        'kitchen-needs': 'https://images.unsplash.com/photo-1588854337236-6889d631faa8?w=400&auto=format&fit=crop&q=60',
        'home-needs-and-cleaning': 'https://images.unsplash.com/photo-1585421514738-01798e348b17?w=400&auto=format&fit=crop&q=60',
        'home-cleaning': 'https://images.unsplash.com/photo-1585421514738-01798e348b17?w=400&auto=format&fit=crop&q=60',
        'personal-care': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=400&auto=format&fit=crop&q=60',
        'dry-fruits-superfoods': 'https://images.unsplash.com/photo-1596560548464-f010549b84d7?w=400&auto=format&fit=crop&q=60',
        'dairy-breakfast': 'https://images.unsplash.com/photo-1628088062854-d1870b4553da?w=400&auto=format&fit=crop&q=60',
        'ice-cream': 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&auto=format&fit=crop&q=60',
      };

      for (final p in allProducts) {
        if (p.category != null && p.category!.slug.isNotEmpty) {
          final cat = p.category!;
          final slug = cat.slug.toLowerCase().trim();
          if (!uniqueCategories.containsKey(slug) && slug != 'restaurant') {
            String resolvedImg = cat.imageUrl ?? '';
            if (resolvedImg.isEmpty || resolvedImg.length < 5 || !resolvedImg.startsWith('http')) {
              resolvedImg = categoryFallbackImages[slug] ??
                  'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&auto=format&fit=crop&q=60';
            }

            uniqueCategories[slug] = Category(
              id: cat.id.isNotEmpty ? cat.id : 'cat_$slug',
              name: cat.name.isNotEmpty ? cat.name : slug.replaceAll('-', ' ').toUpperCase(),
              slug: slug,
              imageUrl: resolvedImg,
              sortOrder: uniqueCategories.length + 1,
            );
          }
        }
      }

      if (uniqueCategories.isNotEmpty) {
        return uniqueCategories.values.toList();
      }

      return [
        Category(id: 'cat_snacks', name: 'Snacks & Munchies', slug: 'snacks-munchies', imageUrl: categoryFallbackImages['snacks-munchies'], sortOrder: 1),
        Category(id: 'cat_instant', name: 'Instant Foods', slug: 'instant-foods', imageUrl: categoryFallbackImages['instant-foods'], sortOrder: 2),
        Category(id: 'cat_chocolates', name: 'Chocolates', slug: 'chocolates', imageUrl: categoryFallbackImages['chocolates'], sortOrder: 3),
        Category(id: 'cat_kitchen', name: 'Kitchen Needs', slug: 'kitchen-needs', imageUrl: categoryFallbackImages['kitchen-needs'], sortOrder: 4),
        Category(id: 'cat_cleaning', name: 'Home Needs & Cleaning', slug: 'home-needs-and-cleaning', imageUrl: categoryFallbackImages['home-needs-and-cleaning'], sortOrder: 5),
        Category(id: 'cat_fruits', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', imageUrl: categoryFallbackImages['fruits-vegetables'], sortOrder: 6),
        Category(id: 'cat_personal', name: 'Personal Care', slug: 'personal-care', imageUrl: categoryFallbackImages['personal-care'], sortOrder: 7),
        Category(id: 'cat_dryfruits', name: 'Dry Fruits & Superfoods', slug: 'dry-fruits-superfoods', imageUrl: categoryFallbackImages['dry-fruits-superfoods'], sortOrder: 8),
      ];
    } catch (e) {
      rethrow;
    }
  }
}