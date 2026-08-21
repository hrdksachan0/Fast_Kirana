import 'package:dio/dio.dart';
import '../models/restaurant.dart';
import '../models/product.dart';

class RestaurantRepository {
  final Dio _dio;

  RestaurantRepository(this._dio);

  Future<List<Restaurant>> getRestaurants({String? cuisine, String? search}) async {
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
    return [];
  }

  Future<List<Product>> getRestaurantMenu(String restaurantId) async {
    try {
      // Fetch 100% real products from live database
      final response = await _dio.get('/api/products', queryParameters: {'limit': 200});
      final data = response.data;
      List productsJson = [];
      if (data is List) {
        productsJson = data;
      } else if (data is Map && data['products'] is List) {
        productsJson = data['products'];
      }

      final allProducts = productsJson
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter restaurant products
      final restaurantProducts = allProducts.where((p) {
        return p.restaurantId == restaurantId ||
            (p.category?.slug == 'restaurant') ||
            p.tags.contains('restaurant');
      }).toList();

      if (restaurantProducts.isNotEmpty) {
        return restaurantProducts;
      }

      return allProducts.take(30).toList();
    } catch (_) {
      return [];
    }
  }
}
