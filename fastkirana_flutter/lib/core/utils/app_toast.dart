import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
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
        primaryColor = AppDesignSystem.success;
        iconBg = AppDesignSystem.green50;
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        primaryColor = AppDesignSystem.danger;
        iconBg = AppDesignSystem.statusCancelled;
        icon = Icons.error_rounded;
        break;
      case ToastType.info:
        primaryColor = AppDesignSystem.info;
        iconBg = AppDesignSystem.blue50;
        icon = Icons.info_rounded;
        break;
      case ToastType.warning:
        primaryColor = AppDesignSystem.warning;
        iconBg = AppDesignSystem.amber50;
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
            color: AppDesignSystem.slate900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.slate700, width: 1),
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
                        fontSize: Responsive.scaledFontSize(context, 13),
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
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate400,
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

