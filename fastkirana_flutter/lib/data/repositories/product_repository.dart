import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../../core/network/api_client.dart';

class ProductRepository {
  final Dio dio;
  ProductRepository(this.dio);

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    String? restaurantId,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get(
        '/api/products',
        queryParameters: {
          if (category != null) 'category': category,
          if (search != null) 'search': search,
          if (restaurantId != null) 'restaurantId': restaurantId,
          'limit': limit,
        },
      );
      final productsJson = response.data['products'] ?? [];
      return (productsJson as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Product> getProduct(String id) async {
    try {
      final response = await dio.get('/api/products/$id');
      return Product.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final response = await dio.get('/api/categories');
      final categories = response.data['categories'] ?? response.data ?? [];
      return (categories as List)
          .map((json) => Category.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final message =
          e.response?.data['error'] ?? 'Something went wrong';
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}