import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final bool isRetryable;
  AppException(this.message, {this.code, this.isRetryable = true});

  factory AppException.network(String message) =>
      AppException(message, code: 'NETWORK', isRetryable: true);

  factory AppException.auth(String message) =>
      AppException(message, code: 'AUTH', isRetryable: false);

  factory AppException.validation(String message) =>
      AppException(message, code: 'VALIDATION', isRetryable: false);

  factory AppException.server(String message) =>
      AppException(message, code: 'SERVER', isRetryable: true);

  String get userMessage {
    switch (code) {
      case 'NETWORK':
        return "Can't connect right now. Please check your internet.";
      case 'AUTH':
        return "Session expired. Please log in again.";
      case 'VALIDATION':
        return message;
      case 'SERVER':
        return "Something went wrong on our end. Try again in a moment.";
      default:
        return message;
    }
  }
}

void showAppErrorSnackBar(BuildContext context, AppException error) {
  final color = error.code == 'NETWORK'
      ? const Color(0xFFF59E0B)
      : error.code == 'SERVER'
          ? const Color(0xFFEF4444)
          : AppDesignSystem.info;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error.code == 'NETWORK' ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.userMessage,
              style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      action: error.isRetryable
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {},
            )
          : null,
    ),
  );
}
