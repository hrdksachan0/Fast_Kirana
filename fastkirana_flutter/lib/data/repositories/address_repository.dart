import 'package:dio/dio.dart';
import '../models/address.dart';
import '../../core/network/api_client.dart';

class AddressRepository {
  final Dio dio;
  AddressRepository(this.dio);

  Future<List<Address>> getAddresses() async {
    try {
      final response = await dio.get('/api/addresses');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => Address.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Address> createAddress(Map<String, dynamic> data) async {
    try {
      final response = await dio.post('/api/addresses', data: data);
      return Address.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Address> updateAddress(Map<String, dynamic> data) async {
    try {
      final response = await dio.put('/api/addresses', data: data);
      return Address.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await dio.delete('/api/addresses', data: {'id': id});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateCoordinates(String id, double lat, double lng) async {
    try {
      await dio.patch('/api/addresses', data: {
        'id': id,
        'lat': lat,
        'lng': lng,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final message = e.response?.data['error'] ?? 'Something went wrong';
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}