import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/logger_service.dart';
import '../theme/design_system.dart';

/// Centralized application exception with typed classification and user-friendly error messages
class AppException implements Exception {
  final String message;
  final String? code;
  final bool isRetryable;
  final dynamic originalError;

  AppException(
    this.message, {
    this.code,
    this.isRetryable = true,
    this.originalError,
  });

  factory AppException.network(String message, {dynamic originalError}) =>
      AppException(message, code: 'NETWORK', isRetryable: true, originalError: originalError);

  factory AppException.auth(String message, {dynamic originalError}) =>
      AppException(message, code: 'AUTH', isRetryable: false, originalError: originalError);

  factory AppException.validation(String message, {dynamic originalError}) =>
      AppException(message, code: 'VALIDATION', isRetryable: false, originalError: originalError);

  factory AppException.server(String message, {dynamic originalError}) =>
      AppException(message, code: 'SERVER', isRetryable: true, originalError: originalError);

  /// Automatically parses dynamic exceptions (Dio, Socket, Timeout, Format, etc.) into a normalized AppException
  factory AppException.fromError(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return AppException.network('Connection timed out. Please check your network connection.', originalError: error);
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final resData = error.response?.data;
          String? serverMsg;
          if (resData is Map) {
            final val = resData['detail'] ?? resData['error'] ?? resData['message'];
            if (val != null) {
              serverMsg = val is List ? val.map((e) => e.toString()).join(', ') : val.toString();
            }
          } else if (resData is String && resData.isNotEmpty && !resData.startsWith('<')) {
            serverMsg = resData;
          }

          if (statusCode == 401 || statusCode == 403) {
            return AppException.auth(serverMsg ?? 'Authentication required or session expired.', originalError: error);
          } else if (statusCode != null && statusCode >= 500) {
            return AppException.server(serverMsg ?? 'Server temporarily unavailable ($statusCode).', originalError: error);
          }
          if (serverMsg != null && serverMsg.isNotEmpty) {
            return AppException.validation(serverMsg, originalError: error);
          }
          return AppException('Request failed with status $statusCode', code: 'API_ERROR', isRetryable: true, originalError: error);
        case DioExceptionType.cancel:
          return AppException('Request was cancelled', code: 'CANCELLED', isRetryable: false, originalError: error);
        case DioExceptionType.connectionError:
          return AppException.network('Network connection error. Please verify your internet.', originalError: error);
        default:
          return AppException('An unexpected network error occurred', code: 'UNKNOWN_NETWORK', isRetryable: true, originalError: error);
      }
    }

    if (error is SocketException) {
      return AppException.network('Unable to reach server. Please check your connection.', originalError: error);
    }

    if (error is TimeoutException) {
      return AppException.network('Operation timed out. Please try again.', originalError: error);
    }

    if (error is FormatException) {
      return AppException.validation('Data format error occurred.', originalError: error);
    }

    LoggerService.warning('Unclassified error converted to AppException: $error');
    return AppException(
      error?.toString() ?? 'An unexpected error occurred. Please try again.',
      code: 'GENERIC',
      isRetryable: true,
      originalError: error,
    );
  }

  String get userMessage {
    switch (code) {
      case 'NETWORK':
        return "Can't connect right now. Please check your internet connection.";
      case 'AUTH':
        return "Session expired. Please log in again.";
      case 'VALIDATION':
        return message;
      case 'SERVER':
        if (message.isNotEmpty && !message.startsWith('Server temporarily unavailable')) {
          return message;
        }
        return "Something went wrong on our end. Try again in a moment.";
      default:
        return message;
    }
  }

  @override
  String toString() => 'AppException[$code]: $message';
}

/// Floating SnackBar presenter for centralized AppExceptions
void showAppErrorSnackBar(
  BuildContext context,
  dynamic error, {
  VoidCallback? onRetry,
}) {
  final appError = error is AppException ? error : AppException.fromError(error);

  final color = appError.code == 'NETWORK'
      ? AppDesignSystem.warning
      : appError.code == 'SERVER'
          ? AppDesignSystem.danger
          : AppDesignSystem.info;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            appError.code == 'NETWORK' ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appError.userMessage,
              style: TextStyle(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      action: (appError.isRetryable && onRetry != null)
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    ),
  );
}
