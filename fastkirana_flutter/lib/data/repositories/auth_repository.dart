import 'package:dio/dio.dart';
import '../models/user.dart';
import '../../core/network/api_client.dart';

class AuthRepository {
  final Dio dio;
  AuthRepository(this.dio);

  Future<AuthResponse> sendOtp(String identifier) async {
    final clean = identifier.trim();
    final response = await dio.post(
      '/api/auth/otp/send',
      data: {
        'phone': clean,
        'email': clean,
      },
    );
    // FastAPI / Next.js returns success
    return AuthResponse(
      success: true,
      user: null,
      token: null,
    );
  }

  Future<AuthResponse> verifyOtp(String identifier, String otp) async {
    final clean = identifier.trim();
    final response = await dio.post(
      '/api/auth/otp/verify',
      data: {
        'phone': clean,
        'email': clean,
        'otp': otp.trim(),
      },
    );
    return _parseSessionResponse(response.data);
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
      final response = await dio.get('/api/profile/setup');
      return User.fromJson(response.data['user'] ?? response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateName(String name) async {
    try {
      await dio.post('/api/profile/update-name', data: {'name': name});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePhone(String phone) async {
    try {
      await dio.post('/api/profile/update-phone', data: {'phone': phone});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateEmail(String email) async {
    try {
      await dio.post('/api/profile/update-email', data: {'email': email});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AuthResponse _parseSessionResponse(dynamic data) {
    final json = data is Map<String, dynamic> ? data : {};
    final token = json['token']?.toString();

    // 1. Next.js / nested user format: { "user": { "id": "...", ... }, "token": "..." }
    if (json['user'] is Map) {
      final u = json['user'] as Map;
      final id = u['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        final user = User(
          id: id,
          name: u['name']?.toString(),
          email: u['email']?.toString() ?? '',
          phone: u['phone']?.toString(),
          role: u['role']?.toString() ?? 'USER',
          isBlocked: u['isBlocked'] == true,
        );
        return AuthResponse(success: true, user: user, token: token);
      }
    }

    // 2. FastAPI flat format: { "id": "...", "name": "...", "email": "...", "token": "..." }
    final id = json['id']?.toString() ?? '';
    final role = json['role']?.toString() ?? 'USER';

    if (id.isNotEmpty) {
      final user = User(
        id: id,
        name: json['name']?.toString(),
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString(),
        role: role,
        isBlocked: false,
      );
      return AuthResponse(success: true, user: user, token: token);
    }

    // 3. Fallback if success flag is true
    if (json['success'] == true) {
      return AuthResponse(success: true, user: null, token: token);
    }

    return AuthResponse(success: false, user: null, token: token);
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      String message = 'Something went wrong';
      if (data is Map) {
        message = data['detail']?.toString() ??
            data['error']?.toString() ??
            data['message']?.toString() ??
            'Something went wrong';
      }
      return ApiException(message, e.response?.statusCode);
    }
    return ApiException('Network error. Please check your connection.');
  }
}