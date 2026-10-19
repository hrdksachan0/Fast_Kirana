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
        final phone = prefs.getString('user_phone') ?? '';
        final name = prefs.getString('user_name') ?? '';
        final userId = prefs.getString('user_id') ?? '';
        final storeId = prefs.getString('selected_hub_id') ?? prefs.getString('selected_store_id') ?? '';

        final cleanItems = items.map((item) {
          final canonicalId = (item.productId.isNotEmpty ? item.productId : item.product.id).trim();
          final variant = (item.selectedVariant != null && item.selectedVariant!.isNotEmpty)
              ? item.selectedVariant
              : null;

          return {
            'productId': canonicalId,
            'quantity': item.quantity,
            'selectedVariant': variant,
            'notes': item.notes,
          };
        }).toList();

        await dio.post('/api/cart', data: {
          'guestId': guestId,
          if (userId.isNotEmpty) 'userId': userId,
          if (phone.isNotEmpty) 'userPhone': phone,
          if (name.isNotEmpty) 'userName': name,
          if (storeId.isNotEmpty) 'storeId': storeId,
          'items': cleanItems,
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

  static const String _appliedOrderDeltasKey = 'cart_applied_order_deltas';

  Future<void> recordAppliedOrderDelta(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_appliedOrderDeltasKey) ?? [];
      if (!list.contains(orderId)) {
        list.add(orderId);
        if (list.length > 50) list.removeAt(0);
        await prefs.setStringList(_appliedOrderDeltasKey, list);
      }
      final cacheKey = await _getCartCacheKey();
      final existingData = prefs.getString(cacheKey);
      if (existingData != null) {
        final decoded = jsonDecode(existingData);
        if (decoded is Map<String, dynamic>) {
          final deltas = (decoded['appliedOrderDeltas'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (!deltas.contains(orderId)) {
            deltas.add(orderId);
            if (deltas.length > 50) deltas.removeAt(0);
            decoded['appliedOrderDeltas'] = deltas;
            await prefs.setString(cacheKey, jsonEncode(decoded));
          }
        }
      }
    } catch (_) {}
  }

  static final Set<String> _failedAppliedOrderIds = {};

  Future<void> _rollbackAttemptedEnvelope(
    SharedPreferences prefs,
    String cacheKey,
    String? existingData,
    String? appliedOrderId,
  ) async {
    if (appliedOrderId != null && appliedOrderId.isNotEmpty) {
      _failedAppliedOrderIds.add(appliedOrderId);
    }
    try {
      if (existingData == null) {
        await prefs.remove(cacheKey);
      } else {
        await prefs.setString(cacheKey, existingData);
      }
    } catch (_) {}
    try {
      await prefs.reload();
    } catch (_) {}
  }

  Future<List<String>> getAppliedOrderDeltas() async {
    final results = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_appliedOrderDeltasKey);
      if (list != null) results.addAll(list);
      final cacheKey = await _getCartCacheKey();
      var data = prefs.getString(cacheKey);
      if (data == null) {
        final phone = prefs.getString('user_phone') ?? prefs.getString('user_id') ?? 'guest';
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        final legacyKey = 'local_cart_${cleanPhone.isNotEmpty ? cleanPhone : 'guest'}';
        data = prefs.getString(legacyKey);
      }
      if (data != null) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['appliedOrderDeltas'] is List) {
          results.addAll((decoded['appliedOrderDeltas'] as List).map((e) => e.toString()));
        }
      }
    } catch (_) {}
    if (_failedAppliedOrderIds.isNotEmpty) {
      results.removeAll(_failedAppliedOrderIds);
    }
    return results.toList();
  }

  // Local cart persistence (isolated per user phone and darkstore hub with versioned envelope)
  Future<bool> saveLocalCart(
    List<CartItem> items, {
    int version = 1,
    bool isDirty = false,
    String? appliedOrderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCartCacheKey();

    List<String> preservedDeltas = [];
    final existingData = prefs.getString(cacheKey);
    if (existingData != null) {
      try {
        final decoded = jsonDecode(existingData);
        if (decoded is Map && decoded['appliedOrderDeltas'] is List) {
          preservedDeltas = (decoded['appliedOrderDeltas'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (preservedDeltas.isEmpty) {
      final journalDeltas = prefs.getStringList(_appliedOrderDeltasKey);
      if (journalDeltas != null) {
        preservedDeltas = List<String>.from(journalDeltas);
      }
    }
    if (_failedAppliedOrderIds.isNotEmpty) {
      preservedDeltas.removeWhere(_failedAppliedOrderIds.contains);
    }

    if (appliedOrderId != null && appliedOrderId.isNotEmpty && !preservedDeltas.contains(appliedOrderId)) {
      preservedDeltas.add(appliedOrderId);
      if (preservedDeltas.length > 50) preservedDeltas.removeAt(0);
    }

    final envelope = items.isEmpty
        ? {
            'version': version,
            'isDirty': isDirty,
            'isCleared': true,
            'updatedAt': DateTime.now().toIso8601String(),
            'items': <dynamic>[],
            if (preservedDeltas.isNotEmpty) 'appliedOrderDeltas': preservedDeltas,
          }
        : {
            'version': version,
            'isDirty': isDirty,
            'isCleared': false,
            'updatedAt': DateTime.now().toIso8601String(),
            'items': items.map((item) => item.toJson()).toList(),
            if (preservedDeltas.isNotEmpty) 'appliedOrderDeltas': preservedDeltas,
          };

    final rawEnvelope = jsonEncode(envelope);
    bool success = false;
    try {
      success = await prefs.setString(cacheKey, rawEnvelope);
    } catch (_) {
      await _rollbackAttemptedEnvelope(prefs, cacheKey, existingData, appliedOrderId);
      rethrow;
    }

    if (!success) {
      await _rollbackAttemptedEnvelope(prefs, cacheKey, existingData, appliedOrderId);
      return false;
    }

    if (appliedOrderId != null && appliedOrderId.isNotEmpty) {
      _failedAppliedOrderIds.remove(appliedOrderId);
    }

    if (items.isEmpty) {
      try {
        await prefs.remove('local_cart_guest');
      } catch (_) {}
    }

    if (appliedOrderId != null && appliedOrderId.isNotEmpty) {
      try {
        final list = prefs.getStringList(_appliedOrderDeltasKey) ?? [];
        if (!list.contains(appliedOrderId)) {
          list.add(appliedOrderId);
          if (list.length > 50) list.removeAt(0);
          await prefs.setStringList(_appliedOrderDeltasKey, list);
        }
      } catch (_) {}
    }
    return true;
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