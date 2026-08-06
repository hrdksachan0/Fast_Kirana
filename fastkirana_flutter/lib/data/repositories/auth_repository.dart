import 'package:dio/dio.dart';
import '../models/user.dart';
import '../../core/network/api_client.dart';

class AuthRepository {
  final Dio dio;
  AuthRepository(this.dio);

  Future<AuthResponse> sendOtp(String identifier) async {
    try {
      final response = await dio.post(
        '/api/auth/otp/send',
        data: {'email': identifier},
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> verifyOtp(String identifier, String otp) async {
    try {
      final response = await dio.post(
        '/api/auth/otp/verify',
        data: {'email': identifier, 'otp': otp},
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> signup(
      String email, String name, String phone) async {
    try {
      final response = await dio.post(
        '/api/auth/signup',
        data: {'email': email, 'name': name, 'phone': phone},
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> getProfile() async {
    try {
      final response = await dio.get('/api/profile');
      return User.fromJson(response.data['user'] ?? response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final message =
          e.response?.data['error'] ?? 'Something went wrong';
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}