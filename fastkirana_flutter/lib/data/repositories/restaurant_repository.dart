import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../models/restaurant.dart';
import '../models/product.dart';

class RestaurantRepository {
  final Dio _dio;
  static final Map<String, List<Restaurant>> _cachedRestaurantsByStore = {};
  static final Map<String, DateTime> _lastRestaurantsFetchByStore = {};
  static final Map<String, Future<List<Restaurant>>> _inFlightByStore = {};
  static final Map<String, List<Product>> _cachedMenus = {};
  static final Map<String, DateTime> _menuCacheTimes = {};
  static final Map<String, Future<List<Product>>> _inFlightMenuFetches = {};

  static const int _cacheTTLMinutes = 5;
  static bool _preloadStarted = false;
  static bool _preloadComplete = false;

  static String _diskRestaurantsKey(String storeKey) => 'cached_restaurants_${storeKey}_v1';
  static String _diskRestaurantsTsKey(String storeKey) => 'cached_restaurants_ts_${storeKey}_v1';

  /// Synchronous preloaded getter for instant 0ms cold-start rendering
  static List<Restaurant> preloadedRestaurants([String? storeId]) {
    final effectiveStore = (storeId != null && storeId.isNotEmpty)
        ? storeId
        : (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');
    return _cachedRestaurantsByStore['${effectiveStore}__'] ??
        _cachedRestaurantsByStore['all__'] ??
        const [];
  }

  RestaurantRepository(this._dio) {
    if (!_preloadStarted) {
      _preloadStarted = true;
      unawaited(preloadDiskCache());
    }
  }

  /// Warm up restaurant disk cache during main() cold start (<80ms)
  static Future<void> preloadDiskCache([String? storeId]) async {
    if (_preloadComplete && (storeId == null || storeId.isEmpty)) return;
    try {
      final effectiveStore = (storeId != null && storeId.isNotEmpty)
          ? storeId
          : (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : 'hub-209206');
      final cacheKey = '${effectiveStore}__';
      final diskList = await _loadRestaurantsFromDisk(effectiveStore);
      if (diskList != null && diskList.isNotEmpty) {
        _cachedRestaurantsByStore[cacheKey] = diskList;
        RestaurantRegistry.registerAll(diskList);
        final ts = await _loadDiskTimestamp(effectiveStore);
        if (ts != null) {
          _lastRestaurantsFetchByStore[cacheKey] = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }
      _preloadComplete = true;
    } catch (e) {
      LoggerService.error('RestaurantRepository: disk preload failed', e);
    }
  }

  static Future<List<Restaurant>?> _loadRestaurantsFromDisk(String storeKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskRestaurantsKey(storeKey));
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((j) => Restaurant.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      LoggerService.error('RestaurantRepository: disk load failed for $storeKey', e);
      return null;
    }
  }

  static Future<int?> _loadDiskTimestamp(String storeKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_diskRestaurantsTsKey(storeKey));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveRestaurantsToDisk(String storeKey, List<Restaurant> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
      await prefs.setString(_diskRestaurantsKey(storeKey), encoded);
      await prefs.setInt(_diskRestaurantsTsKey(storeKey), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      LoggerService.error('RestaurantRepository: disk save failed for $storeKey', e);
    }
  }

  static Future<void> invalidateCache([String? storeId]) async {
    if (storeId != null && storeId.isNotEmpty && storeId != 'all') {
      _cachedRestaurantsByStore.removeWhere((k, _) => k.startsWith(storeId));
      _lastRestaurantsFetchByStore.removeWhere((k, _) => k.startsWith(storeId));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_diskRestaurantsKey(storeId));
        await prefs.remove(_diskRestaurantsTsKey(storeId));
      } catch (_) {}
    } else {
      _cachedRestaurantsByStore.clear();
      _lastRestaurantsFetchByStore.clear();
      _preloadComplete = false;
    }
  }

  Future<List<Restaurant>> getRestaurants({
    String? storeId,
    String? cuisine,
    String? search,
    bool forceRefresh = false,
  }) async {
    final storeKey = (storeId != null && storeId.isNotEmpty) ? storeId : 'all';
    final isBaseFeed = (cuisine == null || cuisine.isEmpty || cuisine == 'all') &&
        (search == null || search.isEmpty);
    final cacheKey = '${storeKey}_${cuisine ?? ''}_${search ?? ''}';

    if (!_preloadComplete && isBaseFeed) {
      await preloadDiskCache(storeKey == 'all' ? null : storeKey);
    }

    try {
      final now = DateTime.now();
      final lastFetch = _lastRestaurantsFetchByStore[cacheKey];
      var cached = _cachedRestaurantsByStore[cacheKey];

      // Lazy disk hydrate if switching to a hub that wasn't preloaded yet
      if (!forceRefresh && cached == null && isBaseFeed) {
        final diskList = await _loadRestaurantsFromDisk(storeKey);
        if (diskList != null && diskList.isNotEmpty) {
          cached = diskList;
          _cachedRestaurantsByStore[cacheKey] = diskList;
          RestaurantRegistry.registerAll(diskList);
          final ts = await _loadDiskTimestamp(storeKey);
          if (ts != null) {
            _lastRestaurantsFetchByStore[cacheKey] = DateTime.fromMillisecondsSinceEpoch(ts);
          }
        }
      }

      if (!forceRefresh && cached != null && cached.isNotEmpty) {
        final effectiveLastFetch = _lastRestaurantsFetchByStore[cacheKey] ?? lastFetch;
        final isFresh = effectiveLastFetch != null &&
            now.difference(effectiveLastFetch).inMinutes < _cacheTTLMinutes;
        if (isFresh) {
          return cached;
        }

        // Stale-While-Revalidate (SWR): return cached restaurants in 0ms and refresh silently in background
        debugPrint('[RestaurantRepo] SWR HIT for $cacheKey (${cached.length} restaurants) — refreshing in background');
        if (!_inFlightByStore.containsKey(cacheKey)) {
          final bgFuture = _fetchRestaurants(storeId: storeId, cuisine: cuisine, search: search);
          _inFlightByStore[cacheKey] = bgFuture;
          unawaited(bgFuture.then((fresh) async {
            _inFlightByStore.remove(cacheKey);
            if (fresh.isNotEmpty) {
              _cachedRestaurantsByStore[cacheKey] = fresh;
              _lastRestaurantsFetchByStore[cacheKey] = DateTime.now();
              if (isBaseFeed) {
                await _saveRestaurantsToDisk(storeKey, fresh);
              }
            }
          }).catchError((Object e) {
            _inFlightByStore.remove(cacheKey);
            debugPrint('[RestaurantRepo] background SWR refresh skipped: $e');
          }));
        }
        return cached;
      }

      if (_inFlightByStore.containsKey(cacheKey) && !forceRefresh) {
        return await _inFlightByStore[cacheKey]!;
      }

      final fetchFuture = _fetchRestaurants(storeId: storeId, cuisine: cuisine, search: search);
      _inFlightByStore[cacheKey] = fetchFuture;
      final list = await fetchFuture;
      _inFlightByStore.remove(cacheKey);
      _cachedRestaurantsByStore[cacheKey] = list;
      _lastRestaurantsFetchByStore[cacheKey] = DateTime.now();
      if (isBaseFeed && list.isNotEmpty) {
        unawaited(_saveRestaurantsToDisk(storeKey, list));
      }
      return list;
    } catch (e, st) {
      LoggerService.error('RestaurantRepository: getRestaurants failed', e, st);
      _inFlightByStore.remove(cacheKey);
      if (_cachedRestaurantsByStore.containsKey(cacheKey)) {
        return _cachedRestaurantsByStore[cacheKey]!;
      }
      return _getStaticFallbackRestaurants();
    }
  }

  Future<List<Restaurant>> _fetchRestaurants({String? storeId, String? cuisine, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (storeId != null && storeId.isNotEmpty && storeId != 'all') {
      queryParams['storeId'] = storeId;
    }
    if (cuisine != null && cuisine.isNotEmpty && cuisine != 'all') {
      queryParams['cuisine'] = cuisine;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _dio.get('/api/restaurants', queryParameters: queryParams);
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      List rawList = [];
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['restaurants'] is List) {
        rawList = data['restaurants'] as List;
      }
      final parsed = rawList
          .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
          .toList();
      RestaurantRegistry.registerAll(parsed);
      return parsed;
    }
    return _getStaticFallbackRestaurants();
  }

  List<Restaurant> _getStaticFallbackRestaurants() {
    return [];
  }

  Future<List<Product>> getRestaurantMenu(String restaurantId, {bool forceRefresh = false}) async {
    try {
      final now = DateTime.now();
      final lastFetch = _menuCacheTimes[restaurantId];
      if (!forceRefresh &&
          _cachedMenus.containsKey(restaurantId) &&
          _cachedMenus[restaurantId]!.isNotEmpty &&
          lastFetch != null &&
          now.difference(lastFetch).inMinutes < 3) {
        return _cachedMenus[restaurantId]!;
      }

      if (_inFlightMenuFetches.containsKey(restaurantId) && !forceRefresh) {
        return await _inFlightMenuFetches[restaurantId]!;
      }

      Future<List<Product>> fetchCall() async {
        String canonicalId = restaurantId.trim();
        String? canonicalSlug;

        // Dynamic restaurant lookup from database-backed registry
        final matched = RestaurantRegistry.find(canonicalId);
        if (matched != null) {
          canonicalId = matched.id;
          canonicalSlug = matched.slug;
        }

        final queryParams = <String, dynamic>{
          'restaurantId': canonicalId,
          'limit': 500,
        };
        if (canonicalSlug != null) {
          queryParams['restaurantSlug'] = canonicalSlug;
        }

        final response = await _dio.get('/api/products', queryParameters: queryParams);
        final data = response.data;
        List productsJson = [];
        if (data is List) {
          productsJson = data;
        } else if (data is Map && data['products'] is List) {
          productsJson = data['products'];
        }
        final menu = productsJson
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();

        // Stably place in-stock dishes first, out-of-stock dishes at the end (1:1 Web App parity)
        menu.sort((a, b) {
          final aInStock = a.isAvailable && a.stock > 0;
          final bInStock = b.isAvailable && b.stock > 0;
          if (aInStock && !bInStock) return -1;
          if (!aInStock && bInStock) return 1;
          return 0;
        });

        if (menu.isNotEmpty) {
          _cachedMenus[restaurantId] = menu;
          _menuCacheTimes[restaurantId] = DateTime.now();
        }
        return menu;
      }

      final future = fetchCall();
      _inFlightMenuFetches[restaurantId] = future;
      final result = await future;
      _inFlightMenuFetches.remove(restaurantId);
      return result;
    } catch (e, st) { LoggerService.error('RestaurantRepository: getRestaurantMenu failed', e, st);
      _inFlightMenuFetches.remove(restaurantId);
      if (_cachedMenus.containsKey(restaurantId)) {
        return _cachedMenus[restaurantId]!;
      }
      return [];
    }
  }

  /// Fetches darkstore cold drinks & ice cream for meal upsell recommendations
  Future<List<Product>> getDarkstoreAddonRecommendations({String? storeId}) async {
    try {
      final response = await _dio.get('/api/products', queryParameters: {
        'category': 'beverages,ice-cream',
        'excludeRestaurant': 'true',
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
        'limit': 50,
      });
      final data = response.data;
      List productsJson = [];
      if (data is List) {
        productsJson = data;
      } else if (data is Map && data['products'] is List) {
        productsJson = data['products'];
      }
      return productsJson
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .where((p) {
            final cat = (p.category?.slug ?? '').toLowerCase();
            final isMatch = cat == 'beverages' || cat == 'ice-cream' || cat.contains('drink') || cat.contains('dessert');
            // STRICT: Must be available and strictly in-stock (>0)
            final inStock = p.isAvailable &&
                p.isInStock &&
                (p.parsedVariants.isNotEmpty
                    ? p.parsedVariants.any((v) => v.stock > 0)
                    : p.stock > 0);
            return isMatch && inStock;
          })
          .toList();
    } catch (e, st) {
      LoggerService.error('RestaurantRepository: getDarkstoreAddonRecommendations failed', e, st);
      return [];
    }
  }

  Future<Map<String, dynamic>> getRestaurantReviews(String restaurantId) async {
    try {
      final response = await _dio.get('/api/restaurants/$restaurantId/reviews', queryParameters: {
        'slug': restaurantId,
      });
      final data = response.data;
      if (data is Map<String, dynamic> && data['reviews'] is List && (data['reviews'] as List).isNotEmpty) {
        return data;
      }
    } catch (e, st) { LoggerService.error('RestaurantRepository: getRestaurantReviews failed', e, st); }

    return {'reviews': <Map<String, dynamic>>[], 'totalCount': 0, 'averageRating': 0.0};
  }
}
