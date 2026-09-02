import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        if (options.extra.containsKey('override_base_url')) {
          options.baseUrl = options.extra['override_base_url'] as String;
        }
        final token = await SecureStorage.read('auth_token');

        final isOtpRoute = options.path.contains('/api/auth/otp');
        if (token != null && token.isNotEmpty && !isOtpRoute) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final isAuthRoute = options.path.contains('/api/auth');
        final isPublicGetRoute = kIsWeb &&
            options.method == 'GET' &&
            !options.path.contains('/api/orders') &&
            !options.path.contains('/api/addresses') &&
            !options.path.contains('/api/user');

        if (!isAuthRoute && !isPublicGetRoute) {
          final authFields = await SecureStorage.readMany(const [
            'user_data', 'user_id', 'user_phone', 'user_email', 'user_name', 'user_role',
          ]);
          final rawUserData = authFields['user_data'];
          String? userId = authFields['user_id'];
          String? directPhone = authFields['user_phone'];
          String? userEmail = authFields['user_email'];
          String? userName = authFields['user_name'];
          String? userRole = authFields['user_role'];
          String? userPhone = directPhone;

          if (rawUserData != null && rawUserData.isNotEmpty) {
            try {
              final json = jsonDecode(rawUserData) as Map<String, dynamic>;
              userId ??= json['id']?.toString();
              userEmail = json['email']?.toString() ?? userEmail;
              userName = json['name']?.toString() ?? userName;
              userRole = json['role']?.toString() ?? userRole;
              userPhone ??= json['phone']?.toString();
            } catch (_) {}
          }

          if (userId != null && userId.isNotEmpty) {
            options.headers['x-user-id'] = userId;
          }
          if (userPhone != null && userPhone.isNotEmpty) {
            options.headers['x-user-phone'] = userPhone;
          }
          if (userEmail != null && userEmail.isNotEmpty) {
            options.headers['x-user-email'] = userEmail;
          }
          if (userName != null && userName.isNotEmpty) {
            options.headers['x-user-name'] = userName;
          }
          if (userRole != null && userRole.isNotEmpty) {
            options.headers['x-user-role'] = userRole;
          }
        }
      } catch (_) {}

      return handler.next(options);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) async {
      final isConnectionError = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.unknown;

      const fallbackUrl = 'https://www.fastkirana.in';

      if (isConnectionError && !error.requestOptions.extra.containsKey('retried_fallback')) {
        try {
          final targetPath = error.requestOptions.path.startsWith('http')
              ? error.requestOptions.path
              : '$fallbackUrl${error.requestOptions.path}';

          final fallbackDio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ));

          final retryResponse = await fallbackDio.request(
            targetPath,
            data: error.requestOptions.data,
            queryParameters: error.requestOptions.queryParameters,
            options: Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers,
              extra: {'retried_fallback': true},
            ),
          );
          return handler.resolve(retryResponse);
        } catch (_) {}
      }
      return handler.next(error);
    },
  ));

  return dio;
});

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}