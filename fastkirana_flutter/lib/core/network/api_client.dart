import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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

  // ─── Request/Response Logging (debug builds only) ───────────────────
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => LoggerService.debug(obj),
    ));
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        if (options.extra.containsKey('override_base_url')) {
          options.baseUrl = options.extra['override_base_url'] as String;
        }

        // ─── In-memory auth headers (instant, zero I/O) with boot fallback ──
        var token = SecureStorage.cachedToken;
        if (token == null || token.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            await SecureStorage.loadCache();
          }
        }

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
          final rawUserData = SecureStorage.cachedUserData;
          String? userId = SecureStorage.cachedUserId;
          String? directPhone = SecureStorage.cachedUserPhone;
          String? userEmail = SecureStorage.cachedUserEmail;
          String? userName = SecureStorage.cachedUserName;
          String? userRole = SecureStorage.cachedUserRole;
          String? userPhone = directPhone;

          if (userId == null || userRole == null) {
            final prefs = await SharedPreferences.getInstance();
            userId ??= prefs.getString('user_id');
            userRole ??= prefs.getString('user_role');
            directPhone ??= prefs.getString('user_phone');
            userEmail ??= prefs.getString('user_email');
            userName ??= prefs.getString('user_name');
            userPhone ??= directPhone;
          }

          if (rawUserData != null && rawUserData.isNotEmpty) {
            parse(String k) => rawUserData[k];
            userId ??= parse('id');
            userEmail = parse('email') ?? userEmail;
            userName = parse('name') ?? userName;
            userRole = parse('role') ?? userRole;
            userPhone ??= parse('phone');
          }

          if (userId != null && userId.isNotEmpty) {
            options.headers.putIfAbsent('x-user-id', () => userId);
          }
          if (userPhone != null && userPhone.isNotEmpty) {
            options.headers.putIfAbsent('x-user-phone', () => userPhone);
          }
          if (userEmail != null && userEmail.isNotEmpty) {
            options.headers.putIfAbsent('x-user-email', () => userEmail);
          }
          if (userName != null && userName.isNotEmpty) {
            options.headers.putIfAbsent('x-user-name', () => userName);
          }
          if (userRole != null && userRole.isNotEmpty) {
            options.headers.putIfAbsent('x-user-role', () => userRole);
          }
        }
      } catch (e, _) { LoggerService.error('ApiClient: request interceptor', e); }

      return handler.next(options);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) async {
      // ─── 1. Automatic 401 Token Refresh & Request Replay ───────────────
      if (error.response?.statusCode == 401 && !error.requestOptions.extra.containsKey('retried_refresh')) {
        final isAuthEndpoint = error.requestOptions.path.contains('/api/auth/login') ||
            error.requestOptions.path.contains('/api/auth/otp') ||
            error.requestOptions.path.contains('/api/auth/refresh');

        if (!isAuthEndpoint) {
          try {
            final newToken = await _refreshToken();
            if (newToken != null && newToken.isNotEmpty) {
              final requestOptions = error.requestOptions;
              requestOptions.headers['Authorization'] = 'Bearer $newToken';
              requestOptions.extra['retried_refresh'] = true;

              final retryResponse = await dio.fetch(requestOptions);
              return handler.resolve(retryResponse);
            }
          } catch (e, _) { LoggerService.error('ApiClient: token refresh', e); }
        }
      }

      // ─── 2. Safe Transient Network Retry (Exponential Backoff for Idempotent/GET calls) ──
      // NEVER auto-retry KOT broadcast, order mutations, or payments to prevent duplicates
      final isNonRetryable = error.requestOptions.path.contains('kot-broadcast') ||
          error.requestOptions.path.contains('broadcast') ||
          error.requestOptions.path.contains('/api/orders') ||
          error.requestOptions.path.contains('/api/payment');

      final isTransientError = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;

      final isIdempotent = error.requestOptions.method == 'GET' ||
          error.requestOptions.extra['idempotent'] == true;

      final retryCount = (error.requestOptions.extra['retry_count'] as int?) ?? 0;

      if (isTransientError && !isNonRetryable && isIdempotent && retryCount < 2) {
        try {
          final nextRetry = retryCount + 1;
          final delayMs = nextRetry * 600; // 600ms, 1200ms backoff
          await Future.delayed(Duration(milliseconds: delayMs));

          final newOptions = error.requestOptions;
          newOptions.extra['retry_count'] = nextRetry;

          final retryResponse = await dio.fetch(newOptions);
          return handler.resolve(retryResponse);
        } catch (retryErr, _) {
          LoggerService.error('ApiClient: transient retry failed (attempt $retryCount)', retryErr);
        }
      }

      // ─── 3. Connection Fallback to secondary URL ─────────────────────
      if (isNonRetryable) {
        return handler.next(error);
      }

      final isConnectionError = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.unknown;

      if (isConnectionError && !error.requestOptions.extra.containsKey('retried_fallback')) {
        try {
          final targetPath = error.requestOptions.path.startsWith('http')
              ? error.requestOptions.path
              : '${AppConfig.secondaryApiUrl}${error.requestOptions.path}';

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
        } catch (e, _) { LoggerService.error('ApiClient: fallback URL retry', e); }
      }
      return handler.next(error);
    },
  ));

  return dio;
});

// ─── Token Refresh Concurrency Queue ───────────────────────────────────────
bool _isRefreshingToken = false;
Completer<String?>? _refreshCompleter;

Future<String?> _refreshToken() async {
  if (_isRefreshingToken && _refreshCompleter != null) {
    return _refreshCompleter!.future;
  }

  _isRefreshingToken = true;
  _refreshCompleter = Completer<String?>();

  try {
    final currentToken = SecureStorage.cachedToken;
    final refreshToken = SecureStorage.cachedRefreshToken ?? currentToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      _refreshCompleter!.complete(null);
      return null;
    }

    final refreshDio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    final res = await refreshDio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(headers: {
        'Authorization': 'Bearer $currentToken',
      }),
    );

    if (res.statusCode == 200 && res.data != null) {
      final String? newToken = res.data['token'] ?? res.data['accessToken'];
      final String? newRefreshToken = res.data['refreshToken'];

      if (newToken != null && newToken.isNotEmpty) {
        await SecureStorage.saveAuthToken(newToken);
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await SecureStorage.saveRefreshToken(newRefreshToken);
        }
        _refreshCompleter!.complete(newToken);
        return newToken;
      }
    }
  } catch (e, _) { LoggerService.error('ApiClient: token refresh', e); } finally {
    _isRefreshingToken = false;
  }

  _refreshCompleter?.complete(null);
  return null;
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}
