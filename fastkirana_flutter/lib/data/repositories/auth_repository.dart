import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User, AuthResponse;
import '../models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/supabase_service.dart';

class AuthRepository {
  final Dio dio;
  static String? _lastSupabaseOtpPhone;

  AuthRepository(this.dio);

  static String? extractIndianPhoneDigits(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final last10 = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(last10)) return last10;
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      final last10 = digits.substring(1);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(last10)) return last10;
    }
    return null;
  }

  Future<AuthResponse> sendOtp(String identifier) async {
    final clean = identifier.trim();
    final digits10 = extractIndianPhoneDigits(clean);
    final sb = SupabaseService.client;

    // 1. Primary path for Indian mobile numbers: Supabase Auth -> WhatsApp Hook
    if (digits10 != null && sb != null) {
      final e164 = '+91$digits10';
      try {
        await sb.auth.signInWithOtp(phone: e164);
        _lastSupabaseOtpPhone = e164;
        return AuthResponse(success: true, user: null, token: null);
      } on AuthException catch (e) {
        LoggerService.error('AuthRepository: Supabase sendOtp AuthException', e);
        final msg = e.message.toLowerCase();
        if (msg.contains('rate') || msg.contains('seconds') || msg.contains('limit')) {
          throw ApiException(e.message, int.tryParse(e.statusCode ?? ''));
        }
        // Other config/hook issues fall back cleanly to legacy backend route
        _lastSupabaseOtpPhone = null;
      } catch (e) {
        LoggerService.error('AuthRepository: Supabase sendOtp failed, using fallback', e);
        _lastSupabaseOtpPhone = null;
      }
    } else {
      _lastSupabaseOtpPhone = null;
    }

    // 2. Fallback / Email path: Legacy FastMinute backend OTP route
    try {
      final response = await dio.post(
        '/api/auth/otp/send',
        data: {
          'phone': clean,
          'email': clean,
        },
      );
      // Return actual server result so the UI can react to failures
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponse(
          success: data['success'] == true || data['message'] != null || response.statusCode == 200,
          user: null,
          token: data['token']?.toString(),
        );
      }
      return AuthResponse(success: true, user: null, token: null);
    } on DioException catch (e) {
      LoggerService.error('AuthRepository: sendOtp failed', e);
      throw _handleError(e);
    }
  }

  Future<AuthResponse> verifyOtp(String identifier, String otp) async {
    final clean = identifier.trim();
    final digits10 = extractIndianPhoneDigits(clean);
    final sb = SupabaseService.client;
    final e164 = digits10 != null ? '+91$digits10' : null;

    if (e164 != null && sb != null && _lastSupabaseOtpPhone == e164) {
      try {
        final sbRes = await sb.auth.verifyOTP(
          phone: e164,
          token: otp.trim(),
          type: OtpType.sms,
        );
        final sbToken = sbRes.session?.accessToken;
        if (sbToken == null || sbToken.isEmpty) {
          throw ApiException('Verification failed. Please request a new OTP.');
        }

        // Exchange/hydrate canonical user profile & 30-day session token via Dual-Token Bridge
        final meRes = await dio.get(
          '/api/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $sbToken'}),
        );
        final parsed = _parseSessionResponse(meRes.data);
        final finalToken = (parsed.token != null && parsed.token!.isNotEmpty)
            ? parsed.token
            : sbToken;
        _lastSupabaseOtpPhone = null;
        return AuthResponse(
          success: parsed.success,
          user: parsed.user,
          token: finalToken,
        );
      } on AuthException catch (e) {
        LoggerService.error('AuthRepository: Supabase verifyOTP failed', e);
        throw ApiException(e.message, int.tryParse(e.statusCode ?? ''));
      } on DioException catch (e) {
        LoggerService.error('AuthRepository: /api/auth/me hydration failed', e);
        throw _handleError(e);
      }
    }

    try {
      final response = await dio.post(
        '/api/auth/otp/verify',
        data: {
          'phone': clean,
          'email': clean,
          'otp': otp.trim(),
        },
      );
      return _parseSessionResponse(response.data);
    } on DioException catch (e) {
      LoggerService.error('AuthRepository: verifyOtp failed', e);
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

  Future<void> sendPhoneOtp(String phone) async {
    try {
      await dio.post('/api/profile/send-phone-otp', data: {'phone': phone});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePhoneWithOtp(String phone, String otp) async {
    try {
      await dio.post('/api/profile/update-phone', data: {'phone': phone, 'otp': otp});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> sendEmailOtp(String email) async {
    try {
      await dio.post('/api/profile/send-email-otp', data: {'email': email});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateEmailWithOtp(String email, String otp) async {
    try {
      await dio.post('/api/profile/update-email', data: {'email': email, 'otp': otp});
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