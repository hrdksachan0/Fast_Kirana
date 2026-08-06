import 'package:dio/dio.dart';
import '../models/order.dart';
import '../../core/network/api_client.dart';

class OrderRepository {
  final Dio dio;
  OrderRepository(this.dio);

  Future<List<Order>> getOrders(String userId) async {
    try {
      final response = await dio.get('/api/orders', queryParameters: {'userId': userId});
      final orders = response.data['orders'] ?? response.data ?? [];
      return (orders as List).map((json) => Order.fromJson(json)).toList();
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
      final response = await dio.post('/api/orders/create', data: orderData);
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await dio.patch('/api/orders/$orderId/cancel', data: {'reason': reason});
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