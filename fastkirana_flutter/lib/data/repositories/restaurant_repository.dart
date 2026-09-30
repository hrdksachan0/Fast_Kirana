import 'package:dio/dio.dart';
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

  RestaurantRepository(this._dio);

  Future<List<Restaurant>> getRestaurants({
    String? storeId,
    String? cuisine,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${storeId ?? 'all'}_${cuisine ?? ''}_${search ?? ''}';
    try {
      final now = DateTime.now();
      final lastFetch = _lastRestaurantsFetchByStore[cacheKey];
      final cached = _cachedRestaurantsByStore[cacheKey];

      if (!forceRefresh &&
          cached != null &&
          lastFetch != null &&
          now.difference(lastFetch).inMinutes < 5) {
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
  Future<List<Product>> getDarkstoreAddonRecommendations() async {
    try {
      final response = await _dio.get('/api/products', queryParameters: {
        'category': 'beverages,ice-cream',
        'excludeRestaurant': 'true',
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
            return cat == 'beverages' || cat == 'ice-cream';
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
