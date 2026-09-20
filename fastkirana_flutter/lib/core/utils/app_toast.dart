import 'dart:async';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

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

    try {
      _dismissTimer?.cancel();
      _currentOverlay?.remove();
      _currentOverlay = null;

      final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);

      final entry = OverlayEntry(
        builder: (ctx) => _GenZTopToastWidget(
          title: title,
          subtitle: subtitle,
          type: type,
          onDismiss: () {
            _dismissTimer?.cancel();
            _currentOverlay?.remove();
            _currentOverlay = null;
          },
        ),
      );

      _currentOverlay = entry;
      overlay.insert(entry);

      _dismissTimer = Timer(duration, () {
        _currentOverlay?.remove();
        _currentOverlay = null;
      });
    } catch (_) {
      // Fallback to top-spaced SnackBar if overlay cannot be inserted
      _fallbackSnackBar(context, title, subtitle: subtitle, type: type, duration: duration);
    }
  }

  static void _fallbackSnackBar(
    BuildContext context,
    String title, {
    String? subtitle,
    required ToastType type,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    Color primaryColor = AppDesignSystem.success;
    if (type == ToastType.error) primaryColor = AppDesignSystem.danger;
    if (type == ToastType.warning) primaryColor = AppDesignSystem.warning;
    if (type == ToastType.info) primaryColor = AppDesignSystem.info;

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).padding.bottom + 84,
        ),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xF20F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GenZTopToastWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ToastType type;
  final VoidCallback onDismiss;

  const _GenZTopToastWidget({
    required this.title,
    this.subtitle,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_GenZTopToastWidget> createState() => _GenZTopToastWidgetState();
}

class _GenZTopToastWidgetState extends State<_GenZTopToastWidget> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    List<Color> gradientColors;
    IconData icon;
    String badgeEmoji;

    switch (widget.type) {
      case ToastType.success:
        accentColor = const Color(0xFF10B981);
        gradientColors = const [Color(0xFF059669), Color(0xFF10B981)];
        icon = Icons.check_circle_rounded;
        badgeEmoji = '✨';
        break;
      case ToastType.error:
        accentColor = const Color(0xFFF43F5E);
        gradientColors = const [Color(0xFFE11D48), Color(0xFFFB7185)];
        icon = Icons.error_rounded;
        badgeEmoji = '⚡';
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        gradientColors = const [Color(0xFFD97706), Color(0xFFFBBF24)];
        icon = Icons.warning_amber_rounded;
        badgeEmoji = '⚠️';
        break;
      case ToastType.info:
        accentColor = const Color(0xFF38BDF8);
        gradientColors = const [Color(0xFF0284C7), Color(0xFF38BDF8)];
        icon = Icons.info_rounded;
        badgeEmoji = '💡';
        break;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth - 28).clamp(280.0, 540.0);

    return Positioned(
      top: topPadding + 8,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: _isExiting ? 0.0 : 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * -36),
                  child: Transform.scale(
                    scale: 0.92 + (value * 0.08),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isExiting = true);
                  Future.delayed(const Duration(milliseconds: 180), widget.onDismiss);
                },
                child: Container(
                  width: maxWidth,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xF50B1120),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Vibrant Glow Icon Capsule
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 11),

                      // Title and Subtitle Column (Multi-line, Zero Truncation)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(badgeEmoji, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle!.trim(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.visible,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Subtle swipe-up pull indicator
                      Container(
                        width: 3.5,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

