import 'package:dio/dio.dart';
import '../models/restaurant.dart';
import '../models/product.dart';

class RestaurantRepository {
  final Dio _dio;

  RestaurantRepository(this._dio);

  Future<List<Restaurant>> getRestaurants({String? cuisine, String? search}) async {
    try {
      final response = await _dio.get('/api/restaurants');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is List) {
          return data.map((json) => Restaurant.fromJson(json as Map<String, dynamic>)).toList();
        } else if (data is Map && data['restaurants'] is List) {
          return (data['restaurants'] as List)
              .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Product>> getRestaurantMenu(String restaurantId) async {
    try {
      final response = await _dio.get('/api/products', queryParameters: {
        'restaurantId': restaurantId,
        'limit': 200,
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
          .toList();
    } catch (_) {
      return [];
    }
  }
}
