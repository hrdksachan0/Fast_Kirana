import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fastminute_flutter/core/theme/design_system.dart';

/// Centralized AppException class representing normalized application errors.
class AppException implements Exception {
  final String code;
  final String message;
  final String userMessage;
  final bool isRetryable;
  final dynamic originalError;

  const AppException({
    required this.code,
    required this.message,
    required this.userMessage,
    this.isRetryable = false,
    this.originalError,
  });

  factory AppException.fromError(dynamic error) {
    if (error is AppException) return error;

    final str = error.toString().toLowerCase();

    if (str.contains('socket') ||
        str.contains('network') ||
        str.contains('connection') ||
        str.contains('failed host lookup') ||
        str.contains('offline')) {
      return AppException(
        code: 'NETWORK',
        message: error.toString(),
        userMessage: 'Internet disconnected. Please check your connection.',
        isRetryable: true,
        originalError: error,
      );
    }

    if (str.contains('timeout')) {
      return AppException(
        code: 'NETWORK',
        message: error.toString(),
        userMessage: 'Connection timed out. Please try again.',
        isRetryable: true,
        originalError: error,
      );
    }

    if (str.contains('401') || str.contains('unauthorized')) {
      return AppException(
        code: 'AUTH',
        message: error.toString(),
        userMessage: 'Session expired. Please log in again.',
        isRetryable: false,
        originalError: error,
      );
    }

    if (str.contains('insufficient') || str.contains('stock') || str.contains('inventory')) {
      // Clean up server raw detail if present
      String cleanMsg = error.toString();
      if (cleanMsg.contains('detail:')) {
        cleanMsg = cleanMsg.split('detail:').last.trim();
      } else if (cleanMsg.contains('Exception:')) {
        cleanMsg = cleanMsg.replaceAll('Exception:', '').trim();
      }
      return AppException(
        code: 'STOCK',
        message: error.toString(),
        userMessage: cleanMsg.isNotEmpty ? cleanMsg : 'Item is out of stock. Please adjust quantity.',
        isRetryable: false,
        originalError: error,
      );
    }

    if (str.contains('500') ||
        str.contains('server') ||
        str.contains('internal')) {
      return AppException(
        code: 'SERVER',
        message: error.toString(),
        userMessage: 'Service temporarily unavailable. Please try again.',
        isRetryable: true,
        originalError: error,
      );
    }

    // Default clean user fallback
    String fallback = error.toString().replaceAll('Exception:', '').trim();
    if (fallback.isEmpty || fallback.length > 140) {
      fallback = 'Something went wrong. Please try again.';
    }

    return AppException(
      code: 'GENERIC',
      message: error.toString(),
      userMessage: fallback,
      isRetryable: true,
      originalError: error,
    );
  }

  @override
  String toString() => 'AppException($code): $userMessage';
}

/// Floating Dynamic Island SnackBar presenter for centralized AppExceptions
/// Guarantees ZERO text truncation, adaptive multi-line layout, and non-blocking bottom margin.
void showAppErrorSnackBar(
  BuildContext context,
  dynamic error, {
  VoidCallback? onRetry,
  double? customBottomMargin,
}) {
  final appError = error is AppException ? error : AppException.fromError(error);

  final color = appError.code == 'NETWORK'
      ? AppDesignSystem.warning
      : appError.code == 'STOCK'
          ? const Color(0xFFF59E0B) // Warning amber for stock
          : appError.code == 'SERVER'
              ? AppDesignSystem.danger
              : AppDesignSystem.info;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();

  final bottomPadding = MediaQuery.of(context).padding.bottom;
  final bottomMargin = customBottomMargin ?? (bottomPadding + 96.0);

  messenger.showSnackBar(
    SnackBar(
      content: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xF20F1117), // Obsidian Glass
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: Stack(
                children: [
                  // Specular Highlight
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    height: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Jewel Status Badge
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.40),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            appError.code == 'NETWORK'
                                ? Icons.wifi_off_rounded
                                : appError.code == 'STOCK'
                                    ? Icons.inventory_2_outlined
                                    : Icons.error_outline_rounded,
                            color: color,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),

                      // Zero-Truncation Text Block
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 5.5,
                                  height: 5.5,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  appError.code == 'STOCK'
                                      ? 'INVENTORY NOTICE'
                                      : appError.code == 'NETWORK'
                                          ? 'CONNECTION ALERT'
                                          : 'FASTMINUTE ALERT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appError.userMessage,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                                height: 1.3,
                              ),
                              softWrap: true,
                              maxLines: 4,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),

                      // Retry Action if applicable
                      if (appError.isRetryable && onRetry != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            messenger.hideCurrentSnackBar();
                            onRetry();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => messenger.hideCurrentSnackBar(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Text(
                              'Dismiss',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomMargin,
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}
