import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';

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
      } catch (_) {}
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
        for (final o in remoteOrders) {
          merged[o.id] = o;
        }
        for (final o in localOrders) {
          final isMatched = merged.containsKey(o.id) ||
              (o.readableId != null && merged.values.any((m) => m.readableId == o.readableId));
          if (!isMatched) {
            merged[o.id] = o;
          }
        }
        final combined = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveToCache(combined);
        return combined;
      }
    } catch (_) {}

    // Fallback: Direct Supabase query for real-time status - STRICTLY filtered by customer
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        final phone = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final effectiveUserId = userId.isNotEmpty ? userId : (prefs.getString('user_id') ?? '');

        if (effectiveUserId.isNotEmpty) {
          final List<dynamic> sbData = await sb
              .from('orders')
              .select('*, order_items(*), addresses(*)')
              .eq('userId', effectiveUserId)
              .order('createdAt', ascending: false)
              .limit(30);

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
      }
    } catch (_) {}

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
      } catch (_) {}
    }

    localOrders.removeWhere((o) => o.id == newOrder.id || (o.readableId != null && o.readableId == newOrder.readableId));
    localOrders.insert(0, newOrder);
    await _saveToCache(localOrders);
  }

  Future<Order> getOrder(String orderId) async {
    final cleanId = orderId.replaceAll('#', '').trim();
    try {
      final response = await dio.get('/api/orders/$cleanId');
      if (response.data is Map<String, dynamic>) {
        final orderData = response.data['order'] ?? response.data;
        if (orderData is Map<String, dynamic>) {
          return Order.fromJson(orderData);
        }
      }
    } catch (_) {}

    final orders = await getOrders('');
    return orders.firstWhere(
      (o) =>
          o.id == cleanId ||
          o.readableId == cleanId ||
          o.displayId == cleanId ||
          (cleanId.isNotEmpty && (o.id.endsWith(cleanId) || (o.readableId?.endsWith(cleanId) ?? false))),
      orElse: () => Order(
        id: cleanId,
        readableId: cleanId,
        userId: '',
        addressId: '',
        status: OrderStatus.confirmed,
        subtotal: 0,
        discount: 0,
        deliveryFee: 0,
        taxes: 0,
        miscFee: 0,
        total: 0,
        paymentMethod: PaymentMethod.cod,
        paymentStatus: 'PAID',
        createdAt: DateTime.now(),
      ),
    );
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

  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final statusStr = newStatus.name.toUpperCase();
    try {
      await dio.patch('/api/orders/$orderId', data: {'status': statusStr});
    } catch (_) {
      try {
        await dio.patch('/api/admin/orders/$orderId/status', data: {'status': statusStr});
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        final List<Order> localOrders = decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => Order.fromJson(j))
            .toList();

        final idx = localOrders.indexWhere((o) => o.id == orderId || o.readableId == orderId);
        if (idx != -1) {
          final old = localOrders[idx];
          localOrders[idx] = Order(
            id: old.id,
            readableId: old.readableId,
            userId: old.userId,
            addressId: old.addressId,
            restaurantId: old.restaurantId,
            shopName: old.shopName,
            shopPhone: old.shopPhone,
            notes: old.notes,
            customerName: old.customerName,
            customerPhone: old.customerPhone,
            customerAddress: old.customerAddress,
            status: newStatus,
            subtotal: old.subtotal,
            discount: old.discount,
            deliveryFee: old.deliveryFee,
            taxes: old.taxes,
            miscFee: old.miscFee,
            total: old.total,
            paymentMethod: old.paymentMethod,
            paymentStatus: newStatus == OrderStatus.delivered ? 'PAID' : old.paymentStatus,
            deliveryMethod: old.deliveryMethod,
            createdAt: old.createdAt,
            confirmedAt: newStatus == OrderStatus.confirmed ? DateTime.now() : old.confirmedAt,
            packedAt: newStatus == OrderStatus.packed ? DateTime.now() : old.packedAt,
            shippedAt: newStatus == OrderStatus.shipped ? DateTime.now() : old.shippedAt,
            deliveredAt: newStatus == OrderStatus.delivered ? DateTime.now() : old.deliveredAt,
            items: old.items,
          );
          await _saveToCache(localOrders);
        }
      }
    } catch (_) {}

    return true;
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    final orders = await getOrders('');
    final updated = orders.map((o) {
      if (o.id == orderId || o.readableId == orderId) {
        return Order(
          id: o.id,
          readableId: o.readableId,
          userId: o.userId,
          addressId: o.addressId,
          restaurantId: o.restaurantId,
          status: OrderStatus.cancelled,
          subtotal: o.subtotal,
          discount: o.discount,
          deliveryFee: o.deliveryFee,
          taxes: o.taxes,
          miscFee: o.miscFee,
          total: o.total,
          paymentMethod: o.paymentMethod,
          paymentStatus: o.paymentStatus,
          estimatedDelivery: o.estimatedDelivery,
          deliveryPhoto: o.deliveryPhoto,
          deliveryMethod: o.deliveryMethod,
          shopName: o.shopName,
          shopPhone: o.shopPhone,
          notes: reason,
          couponCode: o.couponCode,
          createdAt: o.createdAt,
          confirmedAt: o.confirmedAt,
          packedAt: o.packedAt,
          shippedAt: o.shippedAt,
          deliveredAt: o.deliveredAt,
          items: o.items,
        );
      }
      return o;
    }).toList();
    await _saveToCache(updated);

    Order? cancelledOrder;
    for (final o in orders) {
      if (o.id == orderId || o.readableId == orderId) {
        cancelledOrder = o;
        break;
      }
    }

    if (cancelledOrder != null && cancelledOrder.status != OrderStatus.cancelled) {
      final sb = SupabaseService.client;
      if (sb != null) {
        try {
          final items = cancelledOrder.items ?? [];
          for (final item in items) {
            final pId = item.productId;
            if (pId != null && pId.isNotEmpty) {
              final prodRes = await sb
                  .from('products')
                  .select('id, stock, variants')
                  .eq('id', pId)
                  .maybeSingle();

              if (prodRes != null) {
                if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
                  final rawVars = prodRes['variants'];
                  if (rawVars is List) {
                    final updatedVariants = rawVars.map((v) {
                      if (v is Map && v['name'] == item.selectedVariant) {
                        final curStock = (v['stock'] as num?)?.toInt() ?? 0;
                        return Map<String, dynamic>.from(v)..['stock'] = curStock + item.quantity;
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
                } else {
                  final curStock = (prodRes['stock'] as num?)?.toInt() ?? 0;
                  final newStock = curStock + item.quantity;
                  await sb.from('products').update({
                    'stock': newStock,
                  }).eq('id', pId);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[CancelOrder Stock Restore Error]: $e');
        }
      }
    }

    try {
      await dio.patch('/api/orders/$orderId', data: {
        'status': 'CANCELLED',
        'reason': reason,
      });
    } catch (_) {}
  }

  Future<void> _saveToCache(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getCacheKey();
    final jsonList = orders.map((o) => o.toJson()).toList();
    await prefs.setString(cacheKey, jsonEncode(jsonList));
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