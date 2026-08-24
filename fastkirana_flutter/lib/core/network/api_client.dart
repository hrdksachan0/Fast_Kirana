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