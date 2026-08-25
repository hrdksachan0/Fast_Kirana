import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../../core/network/api_client.dart';

class OrderRepository {
  final Dio dio;
  static const String _cacheKey = 'user_placed_orders_cache';

  OrderRepository(this.dio);

  Future<List<Order>> getOrders(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    List<Order> localOrders = [];

    final rawJson = prefs.getString(_cacheKey);
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
          if (!merged.containsKey(o.id) && (o.readableId == null || !merged.values.any((m) => m.readableId == o.readableId))) {
            merged[o.id] = o;
          }
        }
        final combined = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveToCache(combined);
        return combined;
      }
    } catch (_) {}

    localOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return localOrders;
  }

  Future<void> savePlacedOrderLocally(Order newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    List<Order> localOrders = [];

    final rawJson = prefs.getString(_cacheKey);
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
    try {
      final response = await dio.get('/api/orders/$orderId');
      if (response.data is Map<String, dynamic>) {
        return Order.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    final orders = await getOrders('');
    return orders.firstWhere(
      (o) => o.id == orderId || o.readableId == orderId,
      orElse: () => Order(
        id: orderId,
        readableId: orderId,
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

    try {
      await dio.patch('/api/orders/$orderId', data: {
        'status': 'CANCELLED',
        'reason': reason,
      });
    } catch (_) {}
  }

  Future<void> _saveToCache(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = orders.map((o) => o.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
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