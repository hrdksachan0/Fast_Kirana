import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../../core/network/api_client.dart';

class WishlistRepository {
  final Dio dio;
  WishlistRepository(this.dio);

  Future<List<Product>> getWishlist() async {
    try {
      final response = await dio.get('/api/wishlist');
      final data = response.data;
      if (data is Map && data['items'] is List) {
        final List items = data['items'];
        return items
            .where((item) => item['product'] != null)
            .map((item) => Product.fromJson(item['product'] as Map<String, dynamic>))
            .toList();
      }
    } catch (e, _) { LoggerService.error('WishlistRepository: silent catch', e); }
    return [];
  }

  Future<void> addToWishlist(String productId) async {
    try {
      await dio.post('/api/wishlist', data: {'productId': productId});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    try {
      await dio.delete('/api/wishlist', data: {'productId': productId});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final message = e.response?.data['error'] ?? 'Something went wrong';
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}
