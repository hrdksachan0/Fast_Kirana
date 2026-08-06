import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart.dart';
import '../../core/network/api_client.dart';

class CartRepository {
  final Dio dio;
  CartRepository(this.dio);

  Future<Cart> getCart(String userId) async {
    try {
      final response = await dio.get('/api/cart', queryParameters: {'userId': userId});
      return Cart.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> addItem(String userId, String productId, int quantity) async {
    try {
      await dio.post('/api/cart/add', data: {
        'userId': userId,
        'productId': productId,
        'quantity': quantity,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateItem(String itemId, int quantity) async {
    try {
      await dio.patch('/api/cart/item/$itemId', data: {'quantity': quantity});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await dio.delete('/api/cart/item/$itemId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> applyCoupon(String code) async {
    try {
      await dio.post('/api/coupons/apply', data: {'code': code});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Local cart persistence
  Future<void> saveLocalCart(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((item) => item.toJson()).toList();
    await prefs.setString('local_cart', jsonEncode(data));
  }

  Future<List<CartItem>> getLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('local_cart');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((json) => CartItem.fromJson(json)).toList();
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      return ApiException(
        e.response?.data['error'] ?? 'Something went wrong',
        e.response?.statusCode,
      );
    }
    return ApiException('Network error. Please check your connection.');
  }
}