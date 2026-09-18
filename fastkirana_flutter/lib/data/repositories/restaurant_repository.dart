import 'package:dio/dio.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../models/restaurant.dart';
import '../models/product.dart';

class RestaurantRepository {
  final Dio _dio;
  static List<Restaurant>? _cachedRestaurants;
  static DateTime? _lastRestaurantsFetch;
  static Future<List<Restaurant>>? _inFlightRestaurantsFetch;
  static final Map<String, List<Product>> _cachedMenus = {};
  static final Map<String, DateTime> _menuCacheTimes = {};
  static final Map<String, Future<List<Product>>> _inFlightMenuFetches = {};

  RestaurantRepository(this._dio);

  Future<List<Restaurant>> getRestaurants({String? cuisine, String? search, bool forceRefresh = false}) async {
    try {
      final now = DateTime.now();
      if (!forceRefresh &&
          _cachedRestaurants != null &&
          _cachedRestaurants!.isNotEmpty &&
          _lastRestaurantsFetch != null &&
          now.difference(_lastRestaurantsFetch!).inMinutes < 5) {
        return _cachedRestaurants!;
      }

      if (_inFlightRestaurantsFetch != null && !forceRefresh) {
        return await _inFlightRestaurantsFetch!;
      }

      _inFlightRestaurantsFetch = _fetchRestaurants();
      final list = await _inFlightRestaurantsFetch!;
      _inFlightRestaurantsFetch = null;
      return list;
    } catch (e, st) { LoggerService.error('RestaurantRepository: getRestaurants failed', e, st);
      _inFlightRestaurantsFetch = null;
      if (_cachedRestaurants != null && _cachedRestaurants!.isNotEmpty) {
        return _cachedRestaurants!;
      }
      return _getStaticFallbackRestaurants();
    }
  }

  Future<List<Restaurant>> _fetchRestaurants() async {
    final response = await _dio.get('/api/restaurants');
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
      _cachedRestaurants = parsed;
      _lastRestaurantsFetch = DateTime.now();
      RestaurantRegistry.registerAll(parsed);
      return parsed;
    }
    return _getStaticFallbackRestaurants();
  }

  List<Restaurant> _getStaticFallbackRestaurants() {
    return [
      Restaurant(
        id: 'REST-101',
        name: 'A.S. Restaurant & Cafe',
        slug: 'as-restaurant',
        description: 'Authentic Burgers, Shakes, Pizzas & Rolls in Ghatampur',
        address: 'Main Market, Ghatampur',
        isPureVeg: true,
        rating: 4.8,
        totalRatings: 120,
        deliveryTime: '15-20 mins',
        cuisineTags: ['CHINESE', 'BURGERS', 'SHAKES', 'PIZZA', 'FAST FOOD'],
        isOpen: true,
        logoUrl: '/cafe_all_menu_category.webp',
        bannerUrl: '/as_restaurant_banner.webp',
      ),
      Restaurant(
        id: 'REST-102',
        name: 'Wedson Restaurant',
        slug: 'wedson-restaurant',
        description: 'Premium North Indian, Curries & Family Dining',
        address: 'Hamirpur Road, Ghatampur',
        isPureVeg: true,
        rating: 4.7,
        totalRatings: 95,
        deliveryTime: '20-25 mins',
        cuisineTags: ['NORTH INDIAN', 'PANEER', 'TANDOORI', 'DAL MAKHANI'],
        isOpen: true,
        logoUrl: '/wedson_restaurant_bg.webp',
        bannerUrl: '/wedson_restaurant_banner.webp',
      ),
      Restaurant(
        id: 'REST-103',
        name: 'Bal Udyan Restaurant',
        slug: 'bal-udyan-restaurant',
        description: 'Authentic Indian Food, Chinese & Quick Bites',
        address: 'Near Bal Udyan, Ghatampur',
        isPureVeg: true,
        rating: 4.6,
        totalRatings: 80,
        deliveryTime: '20-25 mins',
        cuisineTags: ['NORTH INDIAN', 'CHINESE', 'SNACKS'],
        isOpen: true,
        logoUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/restaurants/REST-103-logo.webp',
        bannerUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/restaurants/REST-103-banner.webp',
      ),
      Restaurant(
        id: 'REST-104',
        name: 'Hot Pizza Lovers',
        slug: 'hot-pizza-lovers',
        description: 'Fresh Pizzas, Burgers, Sandwiches & Fast Food',
        address: 'Station Road, Ghatampur',
        isPureVeg: true,
        rating: 4.8,
        totalRatings: 52,
        deliveryTime: '20-25 mins',
        cuisineTags: ['PIZZA', 'BURGER', 'SANDWICH', 'FAST FOOD'],
        isOpen: true,
        lat: 26.1530,
        lng: 80.1710,
        logoUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/restaurants/REST-104-logo.webp',
        bannerUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/restaurants/REST-104-banner.webp',
      ),
    ];
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
