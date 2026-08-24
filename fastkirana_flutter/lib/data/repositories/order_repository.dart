import 'package:dio/dio.dart';
import '../models/order.dart';
import '../../core/network/api_client.dart';

class OrderRepository {
  final Dio dio;
  OrderRepository(this.dio);

  Future<List<Order>> getOrders(String userId) async {
    try {
      final response = await dio.get('/api/orders', queryParameters: {
        if (userId.isNotEmpty) 'userId': userId,
      });
      final data = response.data;
      List ordersList = [];
      if (data is List) {
        ordersList = data;
      } else if (data is Map && data['orders'] is List) {
        ordersList = data['orders'];
      }
      return ordersList.whereType<Map<String, dynamic>>().map((json) => Order.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final response = await dio.get('/api/orders/$orderId');
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Order> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await dio.post('/api/orders', data: orderData);
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await dio.patch('/api/orders/$orderId', data: {
        'status': 'CANCELLED',
        'reason': reason,
      });
    } on DioException catch (e) {
      throw _handleError(e);
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