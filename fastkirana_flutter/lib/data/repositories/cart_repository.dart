import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart.dart';
import '../../core/network/api_client.dart';

class CartRepository {
  final Dio dio;
  CartRepository(this.dio);

  Future<Cart> getCart() async {
    try {
      final response = await dio.get('/api/cart');
      return Cart.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> syncCart(List<CartItem> items) async {
    try {
      await dio.post('/api/cart', data: {
        'items': items.map((item) => {
          'productId': item.productId,
          'quantity': item.quantity,
          'selectedVariant': item.selectedVariant,
          'notes': item.notes,
        }).toList(),
      });
    } on DioException catch (_) {
      // Background sync fail silent
    }
  }

  Future<void> clearCart() async {
    try {
      await dio.delete('/api/cart');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> applyCoupon(String code, {double? subtotal, List<Map<String, dynamic>>? items}) async {
    try {
      final response = await dio.post('/api/coupons/validate', data: {
        'code': code.toUpperCase(),
        if (subtotal != null) 'subtotal': subtotal,
        if (items != null) 'items': items,
      });
      return response.data as Map<String, dynamic>;
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
    try {
      final list = jsonDecode(data) as List;
      final items = list
          .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
          .where((i) => i.product.name != 'FastKirana Item' && i.product.name.trim().isNotEmpty)
          .toList();
      // If mock items were filtered out, save clean cart
      if (items.length != list.length) {
        await saveLocalCart(items);
      }
      return items;
    } catch (_) {
      return [];
    }
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