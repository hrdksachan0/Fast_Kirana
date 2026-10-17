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

  Future<String> _getPendingSyncKey() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? prefs.getString('user_id') ?? 'guest';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final owner = cleanPhone.isNotEmpty ? cleanPhone : 'guest';
    final hubId = prefs.getString('selected_hub_id') ?? 'default';
    return 'has_pending_cart_sync_${owner}_$hubId';
  }

  Future<String> getPendingSyncKeyForCurrentScope() => _getPendingSyncKey();

  Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getPendingSyncKey();
    final hubId = prefs.getString('selected_hub_id') ?? 'default';
    return prefs.getBool(key) ?? prefs.getBool('has_pending_cart_sync_$hubId') ?? prefs.getBool('has_pending_cart_sync') ?? false;
  }

  Future<void> setPendingSync(bool pending, {String? targetKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = targetKey ?? await _getPendingSyncKey();
    await prefs.setBool(key, pending);
    if (!pending) {
      await prefs.remove(key);
      final hubId = prefs.getString('selected_hub_id') ?? 'default';
      await prefs.remove('has_pending_cart_sync_$hubId');
      await prefs.remove('has_pending_cart_sync');
    }
  }

  Future<bool> syncCart(
    List<CartItem> items, {
    String? targetSyncKey,
    bool clearPendingOnSuccess = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = targetSyncKey ?? await _getPendingSyncKey();
    try {
      var guestId = prefs.getString('fastkirana_guest_id');
      if (guestId == null || guestId.isEmpty) {
        guestId = 'g_app_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
        await prefs.setString('fastkirana_guest_id', guestId);
      }

      if (items.isEmpty) {
        await dio.delete('/api/cart');
      } else {
        await dio.post('/api/cart', data: {
          'guestId': guestId,
          'items': items.map((item) => {
            'productId': item.productId,
            'quantity': item.quantity,
            'selectedVariant': item.selectedVariant,
            'notes': item.notes,
          }).toList(),
        });
      }
      if (clearPendingOnSuccess) {
        await prefs.setBool(key, false);
        await prefs.remove(key);
        final hubId = prefs.getString('selected_hub_id') ?? 'default';
        await prefs.remove('has_pending_cart_sync_$hubId');
        await prefs.remove('has_pending_cart_sync');
      }
      return true;
    } catch (e) {
      LoggerService.error('CartRepository: syncCart failed', e);
      // Offline / network failure -> mark specific target owner/hub for auto-sync when online
      await prefs.setBool(key, true);
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
      await saveLocalCart([]);
      final success = await syncCart([]);
      if (!success) {
        await setPendingSync(true);
      }
    } catch (e) {
      LoggerService.error('CartRepository: clearCart failed', e);
      await setPendingSync(true);
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
    final hubId = prefs.getString('selected_hub_id') ?? 'default';
    return 'local_cart_${cleanPhone.isNotEmpty ? cleanPhone : 'guest'}_$hubId';
  }

  // Local cart persistence (isolated per user phone and darkstore hub with versioned envelope)
  Future<void> saveLocalCart(List<CartItem> items, {int version = 1, bool isDirty = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCartCacheKey();
    if (items.isEmpty) {
      final envelope = {
        'version': version,
        'isDirty': isDirty,
        'isCleared': true,
        'updatedAt': DateTime.now().toIso8601String(),
        'items': <dynamic>[],
      };
      await prefs.setString(cacheKey, jsonEncode(envelope));
      await prefs.remove('local_cart_guest');
      return;
    }
    final envelope = {
      'version': version,
      'isDirty': isDirty,
      'isCleared': false,
      'updatedAt': DateTime.now().toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
    await prefs.setString(cacheKey, jsonEncode(envelope));
  }

  Future<List<CartItem>> getLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCartCacheKey();
    var data = prefs.getString(cacheKey);
    if (data == null) {
      // Backward compatibility: check un-suffixed key if newly scoped key not found
      final phone = prefs.getString('user_phone') ?? prefs.getString('user_id') ?? 'guest';
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final legacyKey = 'local_cart_${cleanPhone.isNotEmpty ? cleanPhone : 'guest'}';
      data = prefs.getString(legacyKey);
      if (data == null) return [];
    }
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['isCleared'] == true) {
        return [];
      }
      final List rawList = (decoded is Map && decoded['items'] is List)
          ? decoded['items'] as List
          : (decoded is List ? decoded : []);
      final items = rawList
          .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
          .where((i) => i.product.name != 'FastKirana Item' && i.product.name.trim().isNotEmpty)
          .toList();
      // If mock items were filtered out, save clean cart
      if (items.length != rawList.length) {
        await saveLocalCart(items);
      }
      return items;
    } catch (e) {
      LoggerService.error('CartRepository: getLocalCart failed', e);
      return [];
    }
  }


  Exception _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      String message = 'Something went wrong';
      if (data is Map) {
        message = data['detail']?.toString() ?? data['error']?.toString() ?? data['message']?.toString() ?? message;
      } else if (data is String) {
        message = data;
      }
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}