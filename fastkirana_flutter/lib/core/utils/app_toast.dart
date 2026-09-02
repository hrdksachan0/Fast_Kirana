import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static void showSuccess(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    _show(context, title, subtitle: subtitle, type: ToastType.success, duration: duration);
  }

  static void showError(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    _show(context, title, subtitle: subtitle, type: ToastType.error, duration: duration);
  }

  static void showInfo(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    _show(context, title, subtitle: subtitle, type: ToastType.info, duration: duration);
  }

  static void showWarning(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    _show(context, title, subtitle: subtitle, type: ToastType.warning, duration: duration);
  }

  static void _show(
    BuildContext context,
    String title, {
    String? subtitle,
    required ToastType type,
    required Duration duration,
  }) {
    HapticFeedback.lightImpact();

    Color primaryColor;
    Color iconBg;
    IconData icon;

    switch (type) {
      case ToastType.success:
        primaryColor = const Color(0xFF10B981);
        iconBg = const Color(0xFFECFDF5);
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        primaryColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFFEF2F2);
        icon = Icons.error_rounded;
        break;
      case ToastType.info:
        primaryColor = const Color(0xFF3B82F6);
        iconBg = const Color(0xFFEFF6FF);
        icon = Icons.info_rounded;
        break;
      case ToastType.warning:
        primaryColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFFFFBEB);
        icon = Icons.warning_amber_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
