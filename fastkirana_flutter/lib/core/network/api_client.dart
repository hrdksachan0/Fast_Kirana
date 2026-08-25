import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        if (options.extra.containsKey('override_base_url')) {
          options.baseUrl = options.extra['override_base_url'] as String;
        }
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final rawUserData = prefs.getString('user_data');
        String? userId = prefs.getString('user_id');
        String? userEmail;
        String? userName;
        String? userRole;
        String? userPhone;

        if (rawUserData != null && rawUserData.isNotEmpty) {
          try {
            final json = jsonDecode(rawUserData) as Map<String, dynamic>;
            userId ??= json['id']?.toString();
            userEmail = json['email']?.toString();
            userName = json['name']?.toString();
            userRole = json['role']?.toString();
            userPhone = json['phone']?.toString();
          } catch (_) {}
        }

        // Real Admin / Default user identity in DB
        userId ??= 'cmqgzqeud0000vkid7hd6mti4';
        userEmail ??= 'admin@fastkirana.com';
        userRole ??= 'ADMIN';
        userPhone ??= '+917054470303';
        userName ??= 'FastKirana Admin';

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['x-user-id'] = userId;
        options.headers['x-user-email'] = userEmail;
        options.headers['x-user-name'] = userName;
        options.headers['x-user-role'] = userRole;
        options.headers['x-user-phone'] = userPhone;
      } catch (_) {}

      return handler.next(options);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) async {
      // If primary endpoint fails (DNS resolving / network error), retry on secondary cloud endpoint
      final isConnectionError = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.unknown;

      final currentBaseUrl = error.requestOptions.baseUrl;
      final fallbackUrl = currentBaseUrl.contains('railway.app')
          ? 'https://fast-kirana-0ezx.onrender.com'
          : 'https://fastkirana-production.up.railway.app';

      if (isConnectionError && !error.requestOptions.extra.containsKey('retried_fallback')) {
        try {
          final options = Options(
            method: error.requestOptions.method,
            headers: error.requestOptions.headers,
            extra: {...error.requestOptions.extra, 'retried_fallback': true},
          );

          final retryResponse = await dio.request(
            error.requestOptions.path,
            data: error.requestOptions.data,
            queryParameters: error.requestOptions.queryParameters,
            options: options.copyWith(
              extra: {...options.extra!, 'override_base_url': fallbackUrl},
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