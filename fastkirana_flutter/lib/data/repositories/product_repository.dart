import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/logger_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';

class ProductRepository {
  final Dio dio;

  // ─── In-memory cache partitioned by hubId ───────────────────
  static final Map<String, List<Product>> _hubCachedProducts = {};
  static final Map<String, DateTime> _hubLastFetchTime = {};
  static final Map<String, List<Product>> _categoryCachedProducts = {};
  static final Map<String, DateTime> _categoryLastFetchTime = {};
  static final Map<String, List<Category>> _hubCachedCategories = {};
  static final Map<String, DateTime> _hubCategoryLastFetchTime = {};
  static List<Category>? _cachedCategories;
  // Keyed in-flight fetch map to prevent cross-contamination between different query types
  static final Map<String, Future<List<Product>>> _inFlightFetches = {};
  // ETag cache for HTTP 304 Not Modified optimization
  static final Map<String, String> _eTags = {};

  // ─── Disk cache keys ────────────────────────────────────────
  static String _diskProductsKey(String hubId) => 'cached_products_${hubId}_v7';
  static String _diskFetchTimestampKey(String hubId) => 'cached_products_ts_${hubId}_v7';
  static String _diskCategoriesKey([String? hubId]) => 'cached_categories_${hubId ?? "global"}_v7';
  static String _diskCategoryTimestampKey([String? hubId]) => 'cached_categories_ts_${hubId ?? "global"}_v7';
  static const _cacheTTLMinutes = 2; // 2 minutes TTL for high freshness while retaining instant render

  // ─── Preload disk cache into memory ──────────────────────────
  // getProducts() always awaits this first to ensure cached data
  // is available before any network call (no race condition).
  static bool _preloadStarted = false;
  static bool _preloadComplete = false;

  /// Synchronous in-memory getters for immediate first-render (<50ms)
  static List<Category> get preloadedCategories => _cachedCategories ?? [];
  static List<Product> get preloadedProducts {
    final defaultId = AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206';
    return _hubCachedProducts[defaultId] ??
        (_hubCachedProducts.isNotEmpty ? _hubCachedProducts.values.first : []);
  }
  static bool get hasPreloadedData =>
      (_cachedCategories?.isNotEmpty ?? false) || (_hubCachedProducts.isNotEmpty);

  ProductRepository(this.dio) {
    if (!_preloadStarted) {
      _preloadStarted = true;
      preloadDiskCache();
    }
  }

  /// Public preload to warm up in-memory cache during main() initialization
  static Future<void> preloadDiskCache([String? hubId]) async {
    if (_preloadComplete) return;
    try {
      final effectiveHub = (hubId != null && hubId.isNotEmpty)
          ? hubId
          : (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');

      final results = await Future.wait([
        _loadProductsFromDisk(effectiveHub),
        _loadCategoriesFromDisk(),
      ]);
      final diskProducts = results[0] as List<Product>?;
      final diskCategories = results[1] as List<Category>?;

      // Only promote to in-memory cache on launch if full catalog is intact (>= 50 products)
      if (diskProducts != null && diskProducts.length >= 50) {
        _hubCachedProducts[effectiveHub] = diskProducts;
        _hubLastFetchTime[effectiveHub] = DateTime.now();
      }

      if (diskCategories != null && diskCategories.isNotEmpty) {
        _cachedCategories = diskCategories;
      }

      _preloadComplete = true;
    } catch (e) { LoggerService.error('ProductRepository: disk preload failed', e); }
  }

  /// Returns true if the on-disk product cache is still fresh for the hub.
  static Future<bool> _isDiskCacheFresh([String? hubId]) async {
    try {
      final effectiveHub = (hubId != null && hubId.isNotEmpty) ? hubId : AppConfig.darkstoreId;
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_diskFetchTimestampKey(effectiveHub));
      if (ts == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age < _cacheTTLMinutes * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the on-disk category cache is still fresh.
  static Future<bool> _isDiskCategoryCacheFresh([String? hubId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_diskCategoryTimestampKey(hubId));
      if (ts == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age < _cacheTTLMinutes * 60 * 1000;
    } catch (_) {
      return false;
    }
  }

  /// Load products for a specific hub from disk (SharedPreferences).
  static Future<List<Product>?> _loadProductsFromDisk([String? hubId]) async {
    try {
      final effectiveHub = (hubId != null && hubId.isNotEmpty) ? hubId : AppConfig.darkstoreId;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskProductsKey(effectiveHub)) ?? prefs.getString('cached_products_v5');
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((j) => Product.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) { LoggerService.error('ProductRepository: disk load failed for hub $hubId', e);
      return null;
    }
  }

  /// Save products for a specific hub to disk.
  static Future<void> _saveProductsToDisk(List<Product> products, [String? hubId]) async {
    try {
      final effectiveHub = (hubId != null && hubId.isNotEmpty) ? hubId : AppConfig.darkstoreId;
      final prefs = await SharedPreferences.getInstance();
      final jsonList = products.map((p) => p.toJson()).toList();
      await prefs.setString(_diskProductsKey(effectiveHub), jsonEncode(jsonList));
      await prefs.setInt(_diskFetchTimestampKey(effectiveHub), DateTime.now().millisecondsSinceEpoch);
    } catch (e) { LoggerService.error('ProductRepository: disk save failed for hub $hubId', e); }
  }

  /// Load categories from disk for a specific hub.
  static Future<List<Category>?> _loadCategoriesFromDisk([String? hubId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCategoriesKey(hubId)) ?? prefs.getString('cached_categories_v5');
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((j) => Category.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) { LoggerService.error('ProductRepository: disk category load failed for hub $hubId', e);
      return null;
    }
  }

  /// Save categories to disk for a specific hub.
  static Future<void> _saveCategoriesToDisk(List<Category> categories, [String? hubId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = categories.map((c) => c.toJson()).toList();
      await prefs.setString(_diskCategoriesKey(hubId), jsonEncode(jsonList));
      await prefs.setInt(_diskCategoryTimestampKey(hubId), DateTime.now().millisecondsSinceEpoch);
    } catch (e) { LoggerService.error('ProductRepository: disk category save failed for hub $hubId', e); }
  }

  /// Invalidate all cached data (call on pull-to-refresh or force refresh).
  static Future<void> invalidateAllCache() async {
    _hubCachedProducts.clear();
    _hubLastFetchTime.clear();
    _categoryCachedProducts.clear();
    _categoryLastFetchTime.clear();
    _hubCachedCategories.clear();
    _hubCategoryLastFetchTime.clear();
    _cachedCategories = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_products');
      await prefs.remove('cached_products_timestamp');
      await prefs.remove('cached_categories');
      await prefs.remove('cached_categories_timestamp');
      await prefs.remove('cached_products_v2');
      await prefs.remove('cached_products_timestamp_v2');
      await prefs.remove('cached_categories_v2');
      await prefs.remove('cached_categories_timestamp_v2');
      await prefs.remove('cached_products_v3');
      await prefs.remove('cached_products_timestamp_v3');
      await prefs.remove('cached_categories_v3');
      await prefs.remove('cached_categories_timestamp_v3');
      await prefs.remove('cached_products_v4');
      await prefs.remove('cached_products_timestamp_v4');
      await prefs.remove('cached_products_v5');
      await prefs.remove('cached_products_timestamp_v5');
      await prefs.remove(_diskCategoriesKey());
      await prefs.remove(_diskCategoryTimestampKey());
    } catch (e) { LoggerService.error('ProductRepository: cache invalidation failed', e); }
  }

  /// Invalidate cached products and categories for a specific hub (e.g. when changing address/hub)
  static Future<void> invalidateHubCache(String hubId) async {
    _hubCachedProducts.remove(hubId);
    _hubLastFetchTime.remove(hubId);
    _hubCachedCategories.remove(hubId);
    _hubCategoryLastFetchTime.remove(hubId);
    _categoryCachedProducts.removeWhere((key, _) => key.startsWith('$hubId|'));
    _categoryLastFetchTime.removeWhere((key, _) => key.startsWith('$hubId|'));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_diskProductsKey(hubId));
      await prefs.remove(_diskFetchTimestampKey(hubId));
      await prefs.remove(_diskCategoriesKey(hubId));
      await prefs.remove(_diskCategoryTimestampKey(hubId));
    } catch (e) { LoggerService.error('ProductRepository: hub cache invalidation failed ($hubId)', e); }
  }

  /// Zepto/Swiggy SWR Epoch Revalidation:
  /// Checks server's 100-byte /api/products/catalog-version.
  /// If the server version is newer than local disk version,
  /// it invalidates the cache and signals that fresh data is available.
  static Future<bool> checkAndRevalidateCatalog(Dio dio, [String? hubId]) async {
    try {
      final effectiveHub = (hubId != null && hubId.isNotEmpty) ? hubId : AppConfig.darkstoreId;
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString('catalog_version_$effectiveHub') ?? '';

      final res = await dio.get('/api/products/catalog-version', queryParameters: {
        if (effectiveHub.isNotEmpty && effectiveHub != 'all') 'storeId': effectiveHub,
        't': DateTime.now().millisecondsSinceEpoch,
      });

      if (res.statusCode == 200 && res.data != null) {
        final serverVersion = res.data['productsVersion']?.toString() ?? '';
        if (serverVersion.isNotEmpty && serverVersion != localVersion) {
          debugPrint('[ProductRepository] SWR: Catalog changed (local: $localVersion -> server: $serverVersion). Invalidating cache!');
          await prefs.setString('catalog_version_$effectiveHub', serverVersion);
          await invalidateHubCache(effectiveHub);
          return true; // Catalog changed
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ProductRepository] SWR version check error: $e');
      return false;
    }
  }

  /// Resolves any category slug or ID to its canonical Category ID in the database.
  static String resolveCategoryId(String slugOrId) {
    switch (slugOrId.toLowerCase().trim()) {
      case 'fruits-vegetables':
      case 'fruits-and-vegetables':
      case 'vegetables':
      case 'fruits':
        return 'CAT-101';
      case 'fresh-fruits':
        return 'SUB-101-01';
      case 'fresh-vegetables':
        return 'SUB-101-02';
      case 'beverages':
      case 'cold-drinks':
      case 'beverages-drinks':
      case 'drinks':
        return 'CAT-108';
      case 'ice-cream':
      case 'ice-cream-desserts':
      case 'desserts':
        return 'CAT-105';
      case 'dairy-products':
      case 'dairy':
      case 'dairy-breakfast':
        return 'CAT-116';
      case 'kitchen-ration':
      case 'kitchen-needs':
        return 'CAT-113';
      case 'packaged-items':
      case 'packaged-foods':
        return 'CAT-104';
      case 'dry-fruits-super-foods':
      case 'dry-fruits':
        return 'CAT-114';
      case 'cakes-chocolates':
      case 'chocolates':
        return 'CAT-115';
      case 'personal-care':
        return 'CAT-109';
      case 'household-essentials':
      case 'home-needs-and-cleaning':
        return 'CAT-107';
      default:
        return slugOrId;
    }
  }

  /// Build a stable cache key from query parameters including limit
  static String _cacheKey({String? search, String? restaurantId, String? category, String? categoryId, String? storeId, int limit = 1000}) {
    return '${search ?? ''}|${restaurantId ?? ''}|${category ?? ''}|${categoryId ?? ''}|${storeId ?? ''}|$limit';
  }

  Future<List<Product>> getProducts({
    String? categoryId,
    String? category,
    String? search,
    String? restaurantId,
    String? storeId,
    int limit = 1000,
    bool forceRefresh = false,
    bool? includeRestaurants,
  }) async {
    final effectiveStoreId = (storeId != null && storeId.isNotEmpty)
        ? storeId
        : (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');

    // Canonical Category ID resolution (ID-wise authoritative database fetch)
    final resolvedId = (categoryId != null && categoryId.isNotEmpty)
        ? resolveCategoryId(categoryId)
        : ((category != null && category.isNotEmpty && category != 'all') ? resolveCategoryId(category) : null);

    final isCategoryQuery = (resolvedId != null && resolvedId.isNotEmpty && resolvedId != 'all');

    // Wait for disk preload to finish so cached data is available before checking
    if (!_preloadComplete) {
      await preloadDiskCache(effectiveStoreId);
    }

    try {
      final now = DateTime.now();

      // Case A: Specific Category Query (ID-wise authoritative fetch)
      if (isCategoryQuery) {
        final catCacheKey = '$effectiveStoreId|$resolvedId|${category ?? ''}';
        final cachedCatProds = _categoryCachedProducts[catCacheKey];
        final lastCatTime = _categoryLastFetchTime[catCacheKey];

        if (!forceRefresh &&
            cachedCatProds != null &&
            cachedCatProds.isNotEmpty &&
            lastCatTime != null &&
            now.difference(lastCatTime).inMinutes < _cacheTTLMinutes) {
          debugPrint('[ProductRepo] category cache HIT for $catCacheKey: ${cachedCatProds.length} items');
          return _filterProducts(cachedCatProds, category: category, search: search, restaurantId: restaurantId);
        }

        final key = _cacheKey(search: search, restaurantId: restaurantId, category: category, categoryId: resolvedId, storeId: effectiveStoreId, limit: limit);
        if (_inFlightFetches.containsKey(key) && !forceRefresh) {
          final products = await _inFlightFetches[key]!;
          return _filterProducts(products, category: category, search: search, restaurantId: restaurantId);
        }

        final future = _fetchLiveProducts(
          limit: limit,
          search: search,
          restaurantId: restaurantId,
          category: category,
          categoryId: resolvedId,
          storeId: effectiveStoreId,
          includeRestaurants: includeRestaurants,
        );
        _inFlightFetches[key] = future;
        final liveProducts = await future;
        _inFlightFetches.remove(key);

        if (liveProducts.isNotEmpty) {
          _categoryCachedProducts[catCacheKey] = liveProducts;
          _categoryLastFetchTime[catCacheKey] = DateTime.now();
        }

        return _filterProducts(liveProducts, category: category, search: search, restaurantId: restaurantId);
      }

      // Case B: Full Catalog / Search / Restaurant Query
      final cached = _hubCachedProducts[effectiveStoreId];
      final lastTime = _hubLastFetchTime[effectiveStoreId];

      // 1. In-memory cache hit for full catalog of this specific hub
      if (!forceRefresh &&
          search == null &&
          restaurantId == null &&
          cached != null &&
          cached.length >= 150 &&
          lastTime != null &&
          now.difference(lastTime).inMinutes < _cacheTTLMinutes) {
        debugPrint('[ProductRepo] in-memory cache HIT for hub $effectiveStoreId: ${cached.length} items');
        return _filterProducts(cached, category: category, search: search, restaurantId: restaurantId);
      }

      // 2. Disk cache hit for this specific hub (survives app restarts)
      if (!forceRefresh && search == null && restaurantId == null) {
        final diskProducts = await _loadProductsFromDisk(effectiveStoreId);
        if (diskProducts != null && diskProducts.length >= 150) {
          _hubCachedProducts[effectiveStoreId] = diskProducts;
          final diskFresh = await _isDiskCacheFresh(effectiveStoreId);
          if (diskFresh) {
            _hubLastFetchTime[effectiveStoreId] = DateTime.now();
            debugPrint('[ProductRepo] disk cache HIT & FRESH for hub $effectiveStoreId: ${diskProducts.length} items');
            return _filterProducts(diskProducts, category: category, search: search, restaurantId: restaurantId);
          }
          debugPrint('[ProductRepo] disk cache HIT but stale for hub $effectiveStoreId: revalidating in background');
          _fetchLiveProducts(
            limit: limit,
            search: search,
            restaurantId: restaurantId,
            category: category,
            categoryId: resolvedId,
            storeId: effectiveStoreId,
            includeRestaurants: includeRestaurants,
          ).catchError((_) => <Product>[]);
          return _filterProducts(diskProducts, category: category, search: search, restaurantId: restaurantId);
        }
      }

      // 3. In-flight fetch reuse
      final key = _cacheKey(search: search, restaurantId: restaurantId, category: category, categoryId: resolvedId, storeId: effectiveStoreId, limit: limit);
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
        categoryId: resolvedId,
        storeId: effectiveStoreId,
        includeRestaurants: includeRestaurants,
      );
      _inFlightFetches[key] = future;
      final liveProducts = await future;
      _inFlightFetches.remove(key);

      return _filterProducts(liveProducts, category: category, search: search, restaurantId: restaurantId);
    } catch (e, st) {
      LoggerService.error('ProductRepository: fetchProducts failed ($search, cat=$category, catId=$resolvedId, rid=$restaurantId, store=$effectiveStoreId)', e, st);
      _inFlightFetches.remove(_cacheKey(search: search, restaurantId: restaurantId, category: category, categoryId: resolvedId, storeId: effectiveStoreId, limit: limit));

      // Fallback chain: category cache -> hub in-memory -> hub disk -> static
      if (isCategoryQuery) {
        final catCacheKey = '$effectiveStoreId|$resolvedId|${category ?? ''}';
        final cachedCatProds = _categoryCachedProducts[catCacheKey];
        if (cachedCatProds != null && cachedCatProds.isNotEmpty) {
          return _filterProducts(cachedCatProds, category: category, search: search, restaurantId: restaurantId);
        }
      }

      final memFallback = _hubCachedProducts[effectiveStoreId];
      if (memFallback != null && memFallback.isNotEmpty) {
        return _filterProducts(memFallback, category: category, search: search, restaurantId: restaurantId);
      }
      final diskProducts = await _loadProductsFromDisk(effectiveStoreId);
      if (diskProducts != null && diskProducts.isNotEmpty) {
        _hubCachedProducts[effectiveStoreId] = diskProducts;
        _hubLastFetchTime[effectiveStoreId] = DateTime.now();
        return _filterProducts(diskProducts, category: category, search: search, restaurantId: restaurantId);
      }
      return _filterProducts(_getStaticFallbackProducts(), category: category, search: search, restaurantId: restaurantId);
    }
  }

  Future<List<Product>> _fetchLiveProducts({
    required int limit,
    String? search,
    String? restaurantId,
    String? category,
    String? categoryId,
    String? storeId,
    bool? includeRestaurants,
  }) async {
    final effectiveStoreId = (storeId != null && storeId.isNotEmpty)
        ? storeId
        : (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : null);

    // Only include restaurant dishes when explicitly requested (e.g. restaurant screens or search)
    final bool shouldIncludeRestaurants = includeRestaurants ??
        ((restaurantId != null && restaurantId.isNotEmpty) ||
         (search != null && search.isNotEmpty) ||
         (category != null && (category.contains('restaurant') || category.contains('cafe'))));

    final effectiveCatId = (categoryId != null && categoryId.isNotEmpty)
        ? categoryId
        : ((category != null && (category.toUpperCase().startsWith('CAT-') || category.toUpperCase().startsWith('SUB-'))) ? category : null);

    final effectiveCatSlug = (category != null && !category.toUpperCase().startsWith('CAT-') && !category.toUpperCase().startsWith('SUB-'))
        ? category
        : null;

    final String etagKey = '${effectiveStoreId ?? ''}|${effectiveCatId ?? ''}|${effectiveCatSlug ?? ''}|${restaurantId ?? ''}|$limit';
    final String? cachedETag = _eTags[etagKey];

    final response = await dio.get(
      '/api/products',
      queryParameters: {
        'limit': limit,
        if (shouldIncludeRestaurants) 'includeRestaurants': 'true',
        if (search != null && search.isNotEmpty) 'search': search,
        if (restaurantId != null && restaurantId.isNotEmpty) 'restaurantId': restaurantId,
        if (effectiveCatId != null) 'categoryId': effectiveCatId,
        if (effectiveCatSlug != null) 'category': effectiveCatSlug,
        if (effectiveStoreId != null) 'storeId': effectiveStoreId,
      },
      options: Options(
        headers: {
          if (cachedETag != null) 'If-None-Match': cachedETag,
        },
        validateStatus: (status) => status != null && ((status >= 200 && status < 300) || status == 304),
      ),
    );

    if (response.statusCode == 304) {
      final targetHub = effectiveStoreId ?? (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');
      final existing = _hubCachedProducts[targetHub];
      if (existing != null && existing.isNotEmpty) {
        debugPrint('[ProductRepo] 304 Not Modified: Using in-memory cached catalog (${existing.length} items)');
        return existing;
      }
      final diskCatalog = await _loadProductsFromDisk(targetHub);
      if (diskCatalog.isNotEmpty) {
        _hubCachedProducts[targetHub] = diskCatalog;
        debugPrint('[ProductRepo] 304 Not Modified: Restored ${diskCatalog.length} items from disk cache');
        return diskCatalog;
      }
      // If memory and disk caches are empty, invalidate cached ETag and fetch fresh
      _eTags.remove(etagKey);
      return getProducts(
        limit: limit,
        search: search,
        restaurantId: restaurantId,
        category: category,
        categoryId: categoryId,
        storeId: storeId,
        includeRestaurants: includeRestaurants,
      );
    }

    final newETag = response.headers.value('etag');
    if (newETag != null && newETag.isNotEmpty) {
      _eTags[etagKey] = newETag;
    }

    final data = response.data;
    List productsJson = [];
    if (data is List) {
      productsJson = data;
    } else if (data is Map && data['products'] is List) {
      productsJson = data['products'];
    }

    final liveProducts = productsJson
        .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();

    // Stably place in-stock products first, then sortOrder desc, then createdAt desc (1:1 Web App parity)
    liveProducts.sort((a, b) => compareProductsSystematic(a, b));

    // Cache in memory and on disk ONLY when fetching the comprehensive grocery catalog without filters
    final isFullCatalog = (category == null || category.isEmpty) &&
        (categoryId == null || categoryId.isEmpty) &&
        (search == null || search.isEmpty) &&
        (restaurantId == null || restaurantId.isEmpty) &&
        limit >= 100 &&
        liveProducts.length >= 20;
    if (isFullCatalog) {
      final targetHub = effectiveStoreId ?? (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');
      _hubCachedProducts[targetHub] = liveProducts;
      _hubLastFetchTime[targetHub] = DateTime.now();
      _saveProductsToDisk(liveProducts, targetHub);
    }
    return liveProducts;
  }

  /// Exact Web App Smart Recommendation Engine:
  /// Calls Next.js /api/products/upsell with active cart product IDs.
  /// Recommends based on order co-occurrences, category/tag affinities, and strict restaurant/darkstore isolation.
  Future<List<Product>> getUpsellRecommendations(List<String> productIds) async {
    if (productIds.isEmpty) return [];
    final cleanIds = productIds.map((id) => id.split('_').first).toSet().join(',');
    try {
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
          .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e, st) {
      LoggerService.error('ProductRepository: getUpsellProducts failed for $cleanIds', e, st);
      return [];
    }
  }

  List<Product> _getStaticFallbackProducts() {
    return [];
  }

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
      result = result.where((p) => isProductInGroceryCategory(p, category)).toList();
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

    // Stably place in-stock products first, then sortOrder desc, then createdAt desc (1:1 Web App parity)
    result.sort((a, b) => compareProductsSystematic(a, b));

    return result;
  }

  Future<Product> getProduct(String id) async {
    try {
      final response = await dio.get('/api/products/$id');
      final data = response.data;
      if (data is Map) {
        return Product.fromJson(Map<String, dynamic>.from(data));
      }
      throw ApiException('Product not found');
    } catch (e, st) { LoggerService.error('ProductRepository: getProduct failed', e, st);
      for (final hubProducts in _hubCachedProducts.values) {
        final match = hubProducts.cast<Product?>().firstWhere((p) => p?.id == id, orElse: () => null);
        if (match != null) return match;
      }
      rethrow;
    }
  }

  Future<List<Category>> getCategories({String? storeId, bool forceRefresh = false}) async {
    const effectiveHub = 'global';
    final cachedForHub = _hubCachedCategories[effectiveHub];
    final lastFetch = _hubCategoryLastFetchTime[effectiveHub];
    final isMemFresh = lastFetch != null && DateTime.now().difference(lastFetch).inMinutes < _cacheTTLMinutes;

    // 1. In-memory cache hit (only if healthy count >= 10)
    if (!forceRefresh && isMemFresh && cachedForHub != null && cachedForHub.length >= 10) {
      return cachedForHub;
    }

    // 2. Disk cache hit (survives app restarts — 0ms instant render, only if full taxonomy >= 10)
    if (!forceRefresh) {
      final diskCategories = await _loadCategoriesFromDisk(effectiveHub);
      if (diskCategories != null && diskCategories.length >= 10) {
        _hubCachedCategories[effectiveHub] = diskCategories;
        _cachedCategories = diskCategories;
        final diskFresh = await _isDiskCategoryCacheFresh(effectiveHub);
        if (diskFresh) {
          return diskCategories;
        }
        // Background refresh if stale without blocking the immediate UI return
        dio.get('/api/categories').then((response) {
          final data = response.data;
          if (data is List) {
            final cats = data.map((json) => Category.fromJson(Map<String, dynamic>.from(json as Map))).toList();
            if (cats.length >= 10) {
              _hubCachedCategories[effectiveHub] = cats;
              _cachedCategories = cats;
              _hubCategoryLastFetchTime[effectiveHub] = DateTime.now();
              _saveCategoriesToDisk(cats, effectiveHub);
            }
          }
        }).catchError((_) => null);
        return diskCategories;
      }
    }

    // 3. Network fetch (Global categories taxonomy)
    try {
      final response = await dio.get('/api/categories');
      final data = response.data;
      if (data is List) {
        final cats = data.map((json) => Category.fromJson(Map<String, dynamic>.from(json as Map))).toList();
        if (cats.isNotEmpty) {
          if (cats.length >= 10) {
            _hubCachedCategories[effectiveHub] = cats;
            _cachedCategories = cats;
            _hubCategoryLastFetchTime[effectiveHub] = DateTime.now();
            _saveCategoriesToDisk(cats, effectiveHub);
          }
          return cats;
        }
      }
    } catch (e, st) {
      LoggerService.error('ProductRepository: getCategories failed', e, st);
    }

    // Disk cache fallback on network failure even if stale
    final diskCats = await _loadCategoriesFromDisk(effectiveHub);
    if (diskCats != null && diskCats.isNotEmpty) {
      _hubCachedCategories[effectiveHub] = diskCats;
      _cachedCategories = diskCats;
      return diskCats;
    }

    try {
      final allProducts = await getProducts(limit: 30, storeId: effectiveHub);
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
        _hubCachedCategories[effectiveHub] = list;
        _cachedCategories = list;
        _saveCategoriesToDisk(list, effectiveHub);
        return list;
      }
    } catch (e, st) { LoggerService.error('ProductRepository: categories fallback failed', e, st); }

    final fallbacks = [
      const Category(id: 'CAT-101', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', imageUrl: '/fruits_vegetables_category.png', sortOrder: 1),
      const Category(id: 'CAT-116', name: 'Dairy Products', slug: 'dairy-products', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789230143014-0cjv7m.webp', sortOrder: 0),
      const Category(id: 'CAT-113', name: 'Kitchen & Ration', slug: 'kitchen-ration', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789047720250-xu6kpy.webp', sortOrder: 2),
      const Category(id: 'CAT-104', name: 'Packaged Items', slug: 'packaged-items', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/CAT-104.webp', sortOrder: 3),
      const Category(id: 'SUB-115-01', name: 'Cookies & Namkeen', slug: 'cookies-namkeen', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789579040785-w7gcgz.jpg', sortOrder: 3),
      const Category(id: 'CAT-114', name: 'Dry Fruits & Super Foods', slug: 'dry-fruits-super-foods', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789067277061-gfywnh.jpg', sortOrder: 4),
      const Category(id: 'CAT-115', name: 'Cakes & Chocolates', slug: 'cakes-chocolates', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789580069746-5jc34m.webp', sortOrder: 5),
      const Category(id: 'CAT-108', name: 'Beverages & Drinks', slug: 'beverages', imageUrl: '/beverages_category.png', sortOrder: 6),
      const Category(id: 'CAT-105', name: 'Ice Cream & Desserts', slug: 'ice-cream', imageUrl: '/ice_cream_category.png', sortOrder: 7),
      const Category(id: 'CAT-109', name: 'Personal Care & Hygiene', slug: 'personal-care', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/products/1789065601003-5xq1gj.jpg', sortOrder: 8),
      const Category(id: 'CAT-107', name: 'Household Essentials', slug: 'household-essentials', imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/categories/CAT-107.webp', sortOrder: 9),
    ];
    _cachedCategories = fallbacks;
    return fallbacks;
  }
}