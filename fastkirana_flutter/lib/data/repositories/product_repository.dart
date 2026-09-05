import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/logger_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../../core/network/api_client.dart';

class ProductRepository {
  final Dio dio;

  // ─── In-memory cache ────────────────────────────────────────
  static List<Product>? _cachedProducts;
  static DateTime? _lastFetchTime;
  static List<Category>? _cachedCategories;
  // Keyed in-flight fetch map to prevent cross-contamination between different query types
  static final Map<String, Future<List<Product>>> _inFlightFetches = {};

  // ─── Disk cache keys ────────────────────────────────────────
  static const _diskProductsKey = 'cached_products';
  static const _diskCategoriesKey = 'cached_categories';
  static const _diskFetchTimestampKey = 'cached_products_timestamp';
  static const _diskCategoryTimestampKey = 'cached_categories_timestamp';
  static const _cacheTTLMinutes = 10;

  // ─── Preload disk cache into memory ──────────────────────────
  // getProducts() always awaits this first to ensure cached data
  // is available before any network call (no race condition).
  static bool _preloadStarted = false;
  static bool _preloadComplete = false;
  ProductRepository(this.dio) {
    if (!_preloadStarted) {
      _preloadStarted = true;
      _preloadFromDisk();
    }
  }

  static Future<void> _preloadFromDisk() async {
    if (_preloadComplete) return;
    try {
      final results = await Future.wait([
        _loadProductsFromDisk(),
        _loadCategoriesFromDisk(),
      ]);
      final diskProducts = results[0] as List<Product>?;
      final diskCategories = results[1] as List<Category>?;

      // Only promote to in-memory cache if disk data is fresh (within TTL)
      final productsFresh = await _isDiskCacheFresh();
      if (productsFresh && diskProducts != null && diskProducts.isNotEmpty) {
        _cachedProducts = diskProducts;
        _lastFetchTime = DateTime.now();
      }

      final categoriesFresh = await _isDiskCategoryCacheFresh();
      if (categoriesFresh && diskCategories != null && diskCategories.isNotEmpty) {
        _cachedCategories = diskCategories;
      }

      _preloadComplete = true;
    } catch (e) { LoggerService.error('ProductRepository: preload failed', e); }
  }

  /// Returns true if the on-disk product cache is still fresh (within TTL).
  static Future<bool> _isDiskCacheFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_diskFetchTimestampKey);
      if (ts == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age < _cacheTTLMinutes * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the on-disk category cache is still fresh.
  static Future<bool> _isDiskCategoryCacheFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_diskCategoryTimestampKey);
      if (ts == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age < _cacheTTLMinutes * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  /// Load products from disk (SharedPreferences).
  static Future<List<Product>?> _loadProductsFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskProductsKey);
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((j) => Product.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { LoggerService.error('ProductRepository: disk load failed', e);
      return null;
    }
  }

  /// Save products to disk (SharedPreferences).
  static Future<void> _saveProductsToDisk(List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = products.map((p) => p.toJson()).toList();
      await prefs.setString(_diskProductsKey, jsonEncode(jsonList));
      await prefs.setInt(_diskFetchTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) { LoggerService.error('ProductRepository: disk save failed', e); }
  }

  /// Load categories from disk.
  static Future<List<Category>?> _loadCategoriesFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCategoriesKey);
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((j) => Category.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) { LoggerService.error('ProductRepository: disk cat load failed', e);
      return null;
    }
  }

  /// Save categories to disk.
  static Future<void> _saveCategoriesToDisk(List<Category> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = categories.map((c) => c.toJson()).toList();
      await prefs.setString(_diskCategoriesKey, jsonEncode(jsonList));
      await prefs.setInt(_diskCategoryTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) { LoggerService.error('ProductRepository: disk cat save failed', e); }
  }

  /// Invalidate all cached data (call on pull-to-refresh or force refresh).
  static Future<void> invalidateAllCache() async {
    _cachedProducts = null;
    _lastFetchTime = null;
    _cachedCategories = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_diskProductsKey);
      await prefs.remove(_diskFetchTimestampKey);
      await prefs.remove(_diskCategoriesKey);
      await prefs.remove(_diskCategoryTimestampKey);
    } catch (e) { LoggerService.error('ProductRepository: cache invalidation failed', e); }
  }

  /// Build a stable cache key from query parameters
  static String _cacheKey({String? search, String? restaurantId, String? category}) {
    return '${search ?? ''}|${restaurantId ?? ''}|${category ?? ''}';
  }

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    String? restaurantId,
    int limit = 500,
    bool forceRefresh = false,
  }) async {
    // Wait for disk preload to finish so cached data is available before checking
    if (!_preloadComplete) {
      await _preloadFromDisk();
    }

    final isFullCatalog = (category == null || category.isEmpty) &&
        (search == null || search.isEmpty) &&
        (restaurantId == null || restaurantId.isEmpty);

    try {
      final now = DateTime.now();
      // 1. In-memory cache hit (fastest path)
      if (!forceRefresh &&
          _cachedProducts != null &&
          _cachedProducts!.length >= 100 &&
          _lastFetchTime != null &&
          now.difference(_lastFetchTime!).inMinutes < _cacheTTLMinutes) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }

      // 2. Disk cache hit (survives app restarts — prevents hardcoded flash on cold start)
      if (!forceRefresh) {
        final diskFresh = await _isDiskCacheFresh();
        if (diskFresh) {
          final diskProducts = await _loadProductsFromDisk();
          if (diskProducts != null && diskProducts.isNotEmpty) {
            // Promote to in-memory cache so subsequent calls are instant
            _cachedProducts = diskProducts;
            _lastFetchTime = DateTime.now();
            return _filterProducts(diskProducts, category: category, search: search, restaurantId: restaurantId);
          }
        }
      }

      // 3. If a network fetch with the same parameters is already in flight, reuse it
      final key = _cacheKey(search: search, restaurantId: restaurantId, category: category);
      if (_inFlightFetches.containsKey(key) && !forceRefresh) {
        final products = await _inFlightFetches[key]!;
        return _filterProducts(products, category: category, search: search, restaurantId: restaurantId);
      }

      // 4. Fetch from network
      final future = _fetchLiveProducts(
        limit: limit,
        search: search,
        restaurantId: restaurantId,
        category: category,
      );
      _inFlightFetches[key] = future;
      final liveProducts = await future;
      _inFlightFetches.remove(key);

      return _filterProducts(liveProducts, category: category, search: search, restaurantId: restaurantId);
    } catch (e) {
      _inFlightFetches.remove(_cacheKey(search: search, restaurantId: restaurantId, category: category));
      // 5. Fallback chain: in-memory → disk → hardcoded static
      if (_cachedProducts != null && _cachedProducts!.isNotEmpty) {
        return _filterProducts(_cachedProducts!, category: category, search: search, restaurantId: restaurantId);
      }
      final diskProducts = await _loadProductsFromDisk();
      if (diskProducts != null && diskProducts.isNotEmpty) {
        _cachedProducts = diskProducts;
        _lastFetchTime = DateTime.now();
        return _filterProducts(diskProducts, category: category, search: search, restaurantId: restaurantId);
      }
      // Absolute last resort — hardcoded products
      return _filterProducts(_getStaticFallbackProducts(), category: category, search: search, restaurantId: restaurantId);
    }
  }

  Future<List<Product>> _fetchLiveProducts({
    required int limit,
    String? search,
    String? restaurantId,
    String? category,
  }) async {
    final response = await dio.get(
      '/api/products',
      queryParameters: {
        'limit': limit,
        'includeRestaurants': 'true',
        if (search != null && search.isNotEmpty) 'search': search,
        if (restaurantId != null && restaurantId.isNotEmpty) 'restaurantId': restaurantId,
        if (category != null && category.isNotEmpty) 'category': category,
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

    // Cache in memory and on disk when fetching the full catalog without filters
    final isFullCatalog = (category == null || category.isEmpty) &&
        (search == null || search.isEmpty) &&
        (restaurantId == null || restaurantId.isEmpty);
    if (isFullCatalog && liveProducts.isNotEmpty) {
      _cachedProducts = liveProducts;
      _lastFetchTime = DateTime.now();
      _saveProductsToDisk(liveProducts);
    }
    return liveProducts;
  }

  /// Exact Web App Smart Recommendation Engine:
  /// Calls Next.js /api/products/upsell with active cart product IDs.
  /// Recommends based on order co-occurrences, category/tag affinities, and strict restaurant/darkstore isolation.
  Future<List<Product>> getUpsellRecommendations(List<String> productIds) async {
    if (productIds.isEmpty) return [];
    try {
      final cleanIds = productIds.map((id) => id.split('_').first).toSet().join(',');
      final response = await dio.get(
        '/api/products/upsell',
        queryParameters: {'productIds': cleanIds},
      );

      final data = response.data;
      List productsJson = [];
      if (data is List) {
        productsJson = data;
      } else if (data is Map && data['products'] is List) {
        productsJson = data['products'];
      }

      return productsJson
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<Product> _getStaticFallbackProducts() {
    final list = [
      {
        'id': 'prod_potato',
        'name': 'Fresh Potato (Aloo)',
        'slug': 'fresh-potato-aloo',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 28.0,
        'mrp': 35.0,
        'imageUrl': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500&q=80',
        'unit': '1 kg',
        'tags': ['potato', 'aloo', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_onion',
        'name': 'Fresh Red Onion (Pyaz)',
        'slug': 'fresh-red-onion-pyaz',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 38.0,
        'mrp': 45.0,
        'imageUrl': 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=500&q=80',
        'unit': '1 kg',
        'tags': ['onion', 'pyaz', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_tomato',
        'name': 'Hybrid Tomato (Tamatar)',
        'slug': 'hybrid-tomato-tamatar',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 32.0,
        'mrp': 40.0,
        'imageUrl': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500&q=80',
        'unit': '1 kg',
        'tags': ['tomato', 'tamatar', 'vegetables', 'fresh'],
      },
      {
        'id': 'prod_banana',
        'name': 'Robusta Banana (Kela)',
        'slug': 'robusta-banana-kela',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 45.0,
        'mrp': 60.0,
        'imageUrl': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&q=80',
        'unit': '1 Dozen (12 pcs)',
        'tags': ['banana', 'kela', 'fruits', 'fresh'],
      },
      {
        'id': 'prod_apple',
        'name': 'Shimla Royal Apple (Seb)',
        'slug': 'shimla-royal-apple-seb',
        'categoryId': 'cmqh1haw30000zcid4vj7i1yj',
        'category': {'id': 'cmqh1haw30000zcid4vj7i1yj', 'name': 'Fruits & Vegetables', 'slug': 'fruits-vegetables'},
        'price': 140.0,
        'mrp': 180.0,
        'imageUrl': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&q=80',
        'unit': '1 kg (4-5 pcs)',
        'tags': ['apple', 'seb', 'fruits', 'fresh'],
      },
      {
        'id': 'prod_atta',
        'name': 'Aashirvaad Shudh Chakki Atta',
        'slug': 'aashirvaad-shudh-chakki-atta',
        'categoryId': 'cmsfuzs73000404l7q139nk61',
        'category': {'id': 'cmsfuzs73000404l7q139nk61', 'name': 'Atta, Rice & Dal', 'slug': 'atta-rice-dal'},
        'price': 245.0,
        'mrp': 275.0,
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&q=80',
        'unit': '5 kg',
        'tags': ['atta', 'aashirvaad', 'flour', 'grocery'],
      },
      {
        'id': 'prod_milk',
        'name': 'Amul Taaza Homogenised Toned Milk',
        'slug': 'amul-taaza-toned-milk',
        'categoryId': 'cmsfuzs73000404l7q139nk61',
        'category': {'id': 'cmsfuzs73000404l7q139nk61', 'name': 'Dairy & Breakfast', 'slug': 'dairy'},
        'price': 27.0,
        'mrp': 28.0,
        'imageUrl': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
        'unit': '500 ml',
        'tags': ['milk', 'amul', 'doodh', 'dairy'],
      },
      {
        'id': 'prod_lays',
        'name': 'Lay\'s India\'s Magic Masala Chips',
        'slug': 'lays-magical-masala',
        'categoryId': 'cmqh1hb920002zcidoywpi240',
        'category': {'id': 'cmqh1hb920002zcidoywpi240', 'name': 'Snacks & Munchies', 'slug': 'snacks-munchies'},
        'price': 20.0,
        'mrp': 20.0,
        'imageUrl': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&q=80',
        'unit': '50 g',
        'tags': ['lays', 'chips', 'snacks', 'munchies'],
      },
      {
        'id': 'prod_coke',
        'name': 'Coca-Cola Original Taste',
        'slug': 'coca-cola-can',
        'categoryId': 'cmqgzqfz20008vkidoycqg5u2',
        'category': {'id': 'cmqgzqfz20008vkidoycqg5u2', 'name': 'Cold Drinks & Juices', 'slug': 'beverages'},
        'price': 40.0,
        'mrp': 40.0,
        'imageUrl': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&q=80',
        'unit': '300 ml (Can)',
        'tags': ['coke', 'coca-cola', 'drinks', 'cold drinks', 'beverages'],
      },
    ];

    return list.map((j) => Product.fromJson(j)).toList();
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

    // 1. Restaurant vs Grocery Isolation
    // Only filter when explicitly requested (category or restaurantId).
    // Search screen calls with null category — must return ALL products.
    if (restaurantId != null && restaurantId.isNotEmpty) {
      result = result.where((p) => p.restaurantId == restaurantId).toList();
    } else if (category != null && category.isNotEmpty &&
               (category.contains('restaurant') || category.contains('cafe'))) {
      result = result.where((p) => p.restaurantId != null && p.restaurantId!.isNotEmpty).toList();
    }
    // No default filter — return all products when no restaurantId or food-category specified

    // 2. Category matching
    if (category != null && category.isNotEmpty && category != 'all') {
      final catLower = category.toLowerCase().trim();
      final catSlugNormalized = catLower.replaceAll(' ', '-').replaceAll('&', 'and').replaceAll('---', '-');
      result = result.where((p) {
        final prodCatSlug = (p.category?.slug ?? '').toLowerCase();
        final prodCatId = (p.category?.id ?? p.categoryId ?? '').toLowerCase();
        final prodCatName = (p.category?.name ?? '').toLowerCase();
        final pCatIdLower = (p.categoryId ?? '').toLowerCase();

        // Direct ID match
        if (prodCatId == catLower || (pCatIdLower.isNotEmpty && pCatIdLower == catLower)) return true;

        // Direct Slug match
        if (prodCatSlug.isNotEmpty && (prodCatSlug == catLower || prodCatSlug == catSlugNormalized)) return true;

        // Direct Category Name match
        if (prodCatName.isNotEmpty && (prodCatName == catLower || prodCatName == catSlugNormalized)) return true;

        // Alias lookup by ID
        final aliasesForProd = (p.categoryId != null ? _categoryAliases[p.categoryId] : null) ?? _categoryAliases[prodCatId] ?? [];
        if (aliasesForProd.contains(catLower) || aliasesForProd.contains(catSlugNormalized)) return true;

        // Alias lookup by query key
        for (final entry in _categoryAliases.entries) {
          if (entry.value.contains(catLower) || entry.value.contains(catSlugNormalized)) {
            if ((pCatIdLower.isNotEmpty && entry.key.toLowerCase() == pCatIdLower) || entry.key.toLowerCase() == prodCatId) {
              return true;
            }
          }
        }

        return false;
      }).toList();
    }

    // 3. Search query filter
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
    } catch (e) { LoggerService.error('ProductRepository: silent catch', e);
      if (_cachedProducts != null) {
        return _cachedProducts!.firstWhere(
          (p) => p.id == id,
          orElse: () => throw ApiException('Product not found'),
        );
      }
      rethrow;
    }
  }

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // 1. In-memory cache hit
    if (!forceRefresh && _cachedCategories != null && _cachedCategories!.isNotEmpty) {
      return _cachedCategories!;
    }

    // 2. Disk cache hit (survives app restarts)
    if (!forceRefresh) {
      final diskFresh = await _isDiskCategoryCacheFresh();
      if (diskFresh) {
        final diskCategories = await _loadCategoriesFromDisk();
        if (diskCategories != null && diskCategories.isNotEmpty) {
          _cachedCategories = diskCategories;
          return diskCategories;
        }
      }
    }

    // 3. Network fetch
    try {
      final response = await dio.get('/api/categories');
      final data = response.data;
      if (data is List) {
        final cats = data.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
        if (cats.isNotEmpty) {
          _cachedCategories = cats;
          _saveCategoriesToDisk(cats);
          return cats;
        }
      }
    } catch (e, _) { LoggerService.error('ProductRepository: categories fetch failed', e); }

    try {
      final allProducts = await getProducts(limit: 30);
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
        final list = uniqueCategories.values.toList();
        _cachedCategories = list;
        _saveCategoriesToDisk(list);
        return list;
      }
    } catch (e, _) { LoggerService.error('ProductRepository: silent catch', e); }

    final fallbacks = [
      const Category(id: 'cmqh1haw30000zcid4vj7i1yj', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', imageUrl: '/fruits_vegetables_category.png', sortOrder: 0),
      const Category(id: 'cmsfuzs73000404l7q139nk61', name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', imageUrl: '/atta_rice_dal_category.png', sortOrder: 1),
      const Category(id: 'cmqgzqfz20008vkidoycqg5u2', name: 'Cold Drinks & Juices', slug: 'beverages', imageUrl: '/beverages_category.png', sortOrder: 2),
      const Category(id: 'cmqh1hb920002zcidoywpi240', name: 'Snacks & Munchies', slug: 'snacks-munchies', imageUrl: '/snacks_munchies_category.png', sortOrder: 3),
      const Category(id: 'cmqgzqfv70007vkider7h6e4j', name: 'Ice Creams & More', slug: 'ice-cream', imageUrl: '/ice_cream_category.png', sortOrder: 4),
      const Category(id: 'cmseowmy7000004i562szts34', name: 'Chocolates & Sweets', slug: 'chocolates', imageUrl: '/chocolates_category.png', sortOrder: 5),
      const Category(id: 'cmqh1hbyc0005zcidr45bj1ac', name: 'Bakery & Biscuits', slug: 'bakery', imageUrl: '/bakery_biscuits_category.png', sortOrder: 6),
      const Category(id: 'cmqh1hblj0003zcidm9gq5net', name: 'Personal Care', slug: 'personal-care', imageUrl: '/personal_care_category.png', sortOrder: 7),
      const Category(id: 'cmrv2psby000004ldl25xjrlt', name: 'Home & Cleaning', slug: 'home-needs-and-cleaning', imageUrl: '/household_category.png', sortOrder: 8),
      const Category(id: 'cmt59fuss0000tgidoc35458x', name: 'Cafe & Fast Food', slug: 'restaurant-food', imageUrl: '/cafe_category.png', sortOrder: 9),
    ];
    _cachedCategories = fallbacks;
    return fallbacks;
  }
}