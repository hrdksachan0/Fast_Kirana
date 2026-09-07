import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/logger_service.dart';
import '../models/order.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/admin_authorization.dart';

class OrderRepository {
  final Dio dio;
  static const String _cacheKey = 'user_placed_orders_cache';

  OrderRepository(this.dio);

  Future<String> _getCacheKey() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length >= 10) {
      return 'user_placed_orders_cache_${cleanPhone.substring(cleanPhone.length - 10)}';
    }
    final userId = prefs.getString('user_id');
    if (userId != null && userId.isNotEmpty) {
      return 'user_placed_orders_cache_$userId';
    }
    return 'user_placed_orders_cache_guest';
  }

  Future<List<Order>> getOrders(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCacheKey();
    List<Order> localOrders = [];

    final rawJson = prefs.getString(cacheKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        localOrders = decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => Order.fromJson(j))
            .toList();
      } catch (e, _) { LoggerService.error('OrderRepository: map Orders', e); }
    }

    try {
      final queryParams = <String, dynamic>{};
      if (userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      final phone = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';
      if (phone.isNotEmpty) {
        queryParams['phone'] = phone;
      }

      final response = await dio.get('/api/orders', queryParameters: queryParams);
      final data = response.data;
      List apiList = [];
      if (data is List) {
        apiList = data;
      } else if (data is Map && data['orders'] is List) {
        apiList = data['orders'];
      }

      final remoteOrders = apiList
          .whereType<Map<String, dynamic>>()
          .map((json) => Order.fromJson(json))
          .toList();

      if (remoteOrders.isNotEmpty) {
        final Map<String, Order> merged = {};
        // Remote orders from backend are source of truth for statuses
        for (final o in remoteOrders) {
          merged[o.id] = o;
          if (o.readableId != null && o.readableId!.isNotEmpty) {
            merged[o.readableId!] = o;
          }
        }
        
        final List<Order> finalOrders = [...remoteOrders];

        // For local orders not present in remote API response:
        for (final local in localOrders) {
          final isPresentInRemote = merged.containsKey(local.id) ||
              (local.readableId != null && merged.containsKey(local.readableId!)) ||
              (local.readableId != null && merged.values.any((m) {
                final mBase = (m.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
                final lBase = (local.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
                return (mBase.isNotEmpty && mBase == lBase) || (m.readableId == local.readableId);
              }));

          if (!isPresentInRemote) {
            // Keep strictly recent placed orders (less than 48 hours old)
            if (DateTime.now().difference(local.createdAt).inHours < 48) {
              finalOrders.add(local);
            }
          }
        }

        final combined = finalOrders
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveToCache(combined);
        return combined;
      }
    } catch (e, _) { LoggerService.error('OrderRepository: getOrders combine', e); }

    // Fallback: Direct Supabase query for real-time status - STRICTLY filtered by customer
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        final phone = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final effectiveUserId = userId.isNotEmpty ? userId : (prefs.getString('user_id') ?? '');

        List<dynamic> sbData = [];
        if (effectiveUserId.isNotEmpty) {
          sbData = await sb
              .from('orders')
              .select('*, order_items(*), addresses(*)')
              .eq('userId', effectiveUserId)
              .order('createdAt', ascending: false)
              .limit(30);
        }

        if (sbData.isEmpty && last10.isNotEmpty) {
          try {
            sbData = await sb
                .from('orders')
                .select('*, order_items(*), addresses(*)')
                .ilike('shopPhone', '%$last10%')
                .order('createdAt', ascending: false)
                .limit(30);
          } catch (e, _) { LoggerService.error('OrderRepository: map Orders', e); }
        }

        if (sbData.isNotEmpty) {
          final sbOrders = sbData
              .whereType<Map<String, dynamic>>()
              .map((json) {
                final map = Map<String, dynamic>.from(json);
                map['items'] = map['order_items'];
                map['address'] = map['addresses'];
                return Order.fromJson(map);
              })
              .toList();
          if (sbOrders.isNotEmpty) {
            await _saveToCache(sbOrders);
            return sbOrders;
          }
        }
      }
    } catch (e, _) { LoggerService.error('OrderRepository: getOrders combine', e); }

    localOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return localOrders;
  }

  Future<void> savePlacedOrderLocally(Order newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCacheKey();
    List<Order> localOrders = [];

    final rawJson = prefs.getString(cacheKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        localOrders = decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => Order.fromJson(j))
            .toList();
      } catch (e, _) { LoggerService.error('OrderRepository: map Orders', e); }
    }

    localOrders.removeWhere((o) => o.id == newOrder.id || (o.readableId != null && o.readableId == newOrder.readableId));
    localOrders.insert(0, newOrder);
    await _saveToCache(localOrders);
  }

  /// Fetch a single order by ID or readableId. Returns null if the order
  /// cannot be found remotely or in the local cache (instead of fabricating
  /// a phantom confirmed order).
  Future<Order?> getOrder(String orderId) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    try {
      final response = await dio.get('/api/orders/$cleanId');
      if (response.data is Map<String, dynamic>) {
        final orderData = response.data['order'] ?? response.data;
        if (orderData is Map<String, dynamic>) {
          return Order.fromJson(orderData);
        }
      }
    } catch (e, _) { LoggerService.error('OrderRepository: getOrder fetch', e); }

    // Fallback: search local cache by id, readableId, displayId, or suffix
    final orders = await getOrders('');
    final match = orders.where((o) =>
        o.id == cleanId ||
        o.readableId == cleanId ||
        o.displayId == cleanId ||
        (cleanId.isNotEmpty && (o.id.endsWith(cleanId) || (o.readableId?.endsWith(cleanId) ?? false)))
    ).toList();
    if (match.isNotEmpty) return match.first;
    return null;
  }

  Future<Order> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await dio.post('/api/orders', data: orderData);
      final created = Order.fromJson(response.data as Map<String, dynamic>);
      await savePlacedOrderLocally(created);
      return created;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Updates an order's status by trying the primary endpoint first,
  /// then the admin fallback. Returns true only if at least one endpoint
  /// succeeded. Mutates the local cache to reflect the new status.
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final statusStr = newStatus.name.toUpperCase();
    final adminHeaders = AdminAuthorization.currentStaffHeaders();
    if (adminHeaders == null || adminHeaders.isEmpty) {
      LoggerService.error('OrderRepository: no admin/staff user authenticated');
      return false;
    }

    var primarySucceeded = false;
    var fallbackSucceeded = false;

    // Try primary endpoint
    try {
      final res = await dio.patch(
        '/api/orders/$orderId',
        data: {
          'status': statusStr,
          'scope': 'ALL',
          'updateCombined': true,
        },
        options: Options(headers: adminHeaders),
      );
      primarySucceeded = res.statusCode != null && (res.statusCode! < 300);
    } catch (e, _) {
      LoggerService.error('OrderRepository: primary status update failed', e);
    }

    // Try admin fallback endpoint
    if (!primarySucceeded) {
      try {
        final res = await dio.patch(
          '/api/admin/orders/$orderId/status',
          data: {'status': statusStr},
          options: Options(headers: adminHeaders),
        );
        fallbackSucceeded = res.statusCode != null && (res.statusCode! < 300);
      } catch (e, _) {
        LoggerService.error('OrderRepository: fallback status update failed', e);
      }
    }

    // Update local cache if either endpoint succeeded
    if (primarySucceeded || fallbackSucceeded) {
      try {
        await _updateOrderStatusInCache(orderId, statusStr);
      } catch (e, _) {
        LoggerService.error('OrderRepository: cache update failed after successful API call', e);
      }
    }

    return primarySucceeded || fallbackSucceeded;
  }

  /// Updates a single order's status in the local SharedPreferences cache.
  /// Uses `copyWith` so any new fields added to the Order model are preserved.
  Future<void> _updateOrderStatusInCache(String orderId, String newStatusStr) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanId = orderId.replaceAll('#', '').trim();
    final keys = [_cacheKey, await _getCacheKey()];

    for (final key in keys) {
      final rawJson = prefs.getString(key);
      if (rawJson == null || rawJson.isEmpty) continue;

      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      final localOrders = decoded
          .whereType<Map<String, dynamic>>()
          .map((j) => Order.fromJson(j))
          .toList();

      bool modified = false;
      for (int i = 0; i < localOrders.length; i++) {
        final old = localOrders[i];
        final oBase = (old.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
        final targetBase = cleanId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');

        if (old.id == cleanId ||
            old.readableId == cleanId ||
            old.id.endsWith(cleanId) ||
            (oBase.isNotEmpty && oBase == targetBase)) {

          final newStatus = OrderStatus.values.firstWhere(
            (s) => s.name.toUpperCase() == newStatusStr,
            orElse: () => old.status,
          );

          localOrders[i] = old.copyWith(
            status: newStatus,
            paymentStatus: newStatus == OrderStatus.delivered ? 'PAID' : old.paymentStatus,
            confirmedAt: newStatus == OrderStatus.confirmed ? DateTime.now() : old.confirmedAt,
            packedAt: newStatus == OrderStatus.packed ? DateTime.now() : old.packedAt,
            shippedAt: newStatus == OrderStatus.shipped ? DateTime.now() : old.shippedAt,
            deliveredAt: newStatus == OrderStatus.delivered ? DateTime.now() : old.deliveredAt,
          );
          modified = true;
        }
      }

      if (modified) {
        final jsonList = localOrders.map((o) => o.toJson()).toList();
        await prefs.setString(key, jsonEncode(jsonList));
      }
    }
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    final targetBase = cleanId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');

    final prefs = await SharedPreferences.getInstance();
    final keys = [_cacheKey, await _getCacheKey()];
    Order? cancelledOrder;

    // ── Update local cache first so UI reflects cancellation immediately ──
    for (final key in keys) {
      final rawJson = prefs.getString(key);
      if (rawJson == null || rawJson.isEmpty) continue;
      try {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        final List<Order> localOrders = decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => Order.fromJson(j))
            .toList();

        bool modified = false;
        for (int i = 0; i < localOrders.length; i++) {
          final o = localOrders[i];
          final oBase = (o.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
          if (o.id == cleanId ||
              o.readableId == cleanId ||
              o.id.endsWith(cleanId) ||
              (targetBase.isNotEmpty && oBase == targetBase)) {
            localOrders[i] = o.copyWith(
              status: OrderStatus.cancelled,
              notes: reason,
            );
            cancelledOrder = o;
            modified = true;
          }
        }
        if (modified) {
          final jsonList = localOrders.map((o) => o.toJson()).toList();
          await prefs.setString(key, jsonEncode(jsonList));
        }
      } catch (e, _) { LoggerService.error('OrderRepository: cancel cache update', e); }
    }

    // ── Restore stock for cancelled items ──
    if (cancelledOrder != null) {
      final sb = SupabaseService.client;
      if (sb != null) {
        final items = cancelledOrder.items ?? [];
        // Group items by productId to batch updates per product
        final productQuantities = <String, Map<String, int>>{};
        for (final item in items) {
          final pId = item.productId;
          if (pId == null || pId.isEmpty) continue;
          final variant = item.selectedVariant;
          if (!productQuantities.containsKey(pId)) {
            productQuantities[pId] = {};
          }
          final vKey = variant?.isNotEmpty == true ? variant! : '__base__';
          productQuantities[pId]![vKey] = (productQuantities[pId]![vKey] ?? 0) + item.quantity;
        }

        for (final entry in productQuantities.entries) {
          final pId = entry.key;
          final vMap = entry.value;
          try {
            final prodRes = await sb
                .from('products')
                .select('id, stock, variants')
                .eq('id', pId)
                .maybeSingle();

            if (prodRes == null) continue;

            for (final vEntry in vMap.entries) {
              final variantName = vEntry.key;
              final qty = vEntry.value;

              if (variantName == '__base__') {
                final curStock = (prodRes['stock'] as num?)?.toInt() ?? 0;
                await sb.from('products').update({
                  'stock': curStock + qty,
                }).eq('id', pId);
              } else {
                final rawVars = prodRes['variants'];
                if (rawVars is! List) continue;
                final updatedVariants = rawVars.map((v) {
                  if (v is Map && v['name'] == variantName) {
                    final curStock = (v['stock'] as num?)?.toInt() ?? 0;
                    return Map<String, dynamic>.from(v)..['stock'] = curStock + qty;
                  }
                  return v;
                }).toList();
                final newTotalStock = updatedVariants.fold<int>(
                  0,
                  (sum, v) => sum + ((v is Map ? v['stock'] as num? : 0)?.toInt() ?? 0),
                );
                await sb.from('products').update({
                  'variants': updatedVariants,
                  'stock': newTotalStock,
                }).eq('id', pId);
              }
            }
          } catch (e) {
            LoggerService.error('OrderRepository: stock restore failed for product $pId', e);
          }
        }
      }
    }

    // ── Notify backend of cancellation ──
    try {
      await dio.patch('/api/orders/$orderId', data: {
        'status': 'CANCELLED',
        'reason': reason,
      });
    } on DioException catch (e) {
      LoggerService.error('OrderRepository: cancel API failed', e);
    }

    return;
  }

  Future<void> _saveToCache(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = orders.map((o) => o.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    final keys = {_cacheKey, await _getCacheKey()};
    for (final key in keys) {
      await prefs.setString(key, encoded);
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

  /// Wipe all cached user orders on logout
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      for (final k in allKeys) {
        if (k.startsWith('user_placed_orders_cache')) {
          await prefs.remove(k);
        }
      }
    } catch (e, _) {
      LoggerService.error('OrderRepository: clearCache', e);
    }
  }
}