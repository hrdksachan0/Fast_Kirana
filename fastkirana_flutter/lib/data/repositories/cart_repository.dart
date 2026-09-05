import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart.dart';
import '../../core/services/logger_service.dart';
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

  static const String _pendingSyncKey = 'has_pending_cart_sync';

  Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingSyncKey) ?? false;
  }

  Future<void> setPendingSync(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, pending);
  }

  Future<bool> syncCart(List<CartItem> items) async {
    try {
      await dio.post('/api/cart', data: {
        'items': items.map((item) => {
          'productId': item.productId,
          'quantity': item.quantity,
          'selectedVariant': item.selectedVariant,
          'notes': item.notes,
        }).toList(),
      });
      await setPendingSync(false);
      return true;
    } catch (e) { LoggerService.error('CartRepository: silent catch', e);
      // Offline / network failure -> mark for auto-sync when online
      await setPendingSync(true);
      return false;
    }
  }

  Future<void> syncPendingCartIfNeeded() async {
    final pending = await hasPendingSync();
    if (!pending) return;

    final localItems = await getLocalCart();
    await syncCart(localItems);
  }

  Future<void> clearCart() async {
    try {
      await setPendingSync(false);
      await saveLocalCart([]);
      await dio.delete('/api/cart');
    } catch (e) { LoggerService.error('CartRepository: silent catch', e);
      // Network error on server cart delete shouldn't block local cart wipe
    }
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

  Future<String> _getCartCacheKey() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? prefs.getString('user_id') ?? 'guest';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'local_cart_${cleanPhone.isNotEmpty ? cleanPhone : 'guest'}';
  }

  // Local cart persistence (isolated per user phone)
  Future<void> saveLocalCart(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCartCacheKey();
    if (items.isEmpty) {
      await prefs.remove(cacheKey);
      await prefs.remove('local_cart_guest');
      return;
    }
    final data = items.map((item) => item.toJson()).toList();
    await prefs.setString(cacheKey, jsonEncode(data));
  }

  Future<List<CartItem>> getLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCartCacheKey();
    final data = prefs.getString(cacheKey);
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
    } catch (e) { LoggerService.error('CartRepository: silent catch', e);
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