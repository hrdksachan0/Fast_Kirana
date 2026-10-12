import 'dart:async';
import 'dart:ui';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, info, warning }

enum ToastPosition { top, bottom }

/// FastKirana Ultra-Premium Dynamic Island Toaster
///
/// Features:
/// - 100% Truncation-Free: Multi-line dynamic expansion with zero clipping/ellipsis
/// - Porcelain Glassmorphism: Frosted blur surface, specular highlights, zero harsh black
/// - FastKirana Brand Identity: Jewel status pills, signature brand red & fresh leaf emerald
/// - Non-Blocking Safe Offset: Won't overlap headers or block underlying app navigation
/// - Tactile Dismissal: Flick to dismiss, tap to dismiss, and micro-close button
class AppToast {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  static void showSuccess(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2800),
    ToastPosition position = ToastPosition.top,
  }) {
    _show(
      context,
      title,
      subtitle: subtitle,
      type: ToastType.success,
      duration: duration,
      position: position,
    );
  }

  static void showError(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3200),
    ToastPosition position = ToastPosition.top,
  }) {
    _show(
      context,
      title,
      subtitle: subtitle,
      type: ToastType.error,
      duration: duration,
      position: position,
    );
  }

  static void showInfo(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 2800),
    ToastPosition position = ToastPosition.top,
  }) {
    _show(
      context,
      title,
      subtitle: subtitle,
      type: ToastType.info,
      duration: duration,
      position: position,
    );
  }

  static void showWarning(
    BuildContext context,
    String title, {
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3000),
    ToastPosition position = ToastPosition.top,
  }) {
    _show(
      context,
      title,
      subtitle: subtitle,
      type: ToastType.warning,
      duration: duration,
      position: position,
    );
  }

  static void _show(
    BuildContext context,
    String title, {
    String? subtitle,
    required ToastType type,
    required Duration duration,
    ToastPosition position = ToastPosition.top,
  }) {
    HapticFeedback.lightImpact();

    try {
      _dismissTimer?.cancel();
      _currentOverlay?.remove();
      _currentOverlay = null;

      final overlay =
          Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);

      final entry = OverlayEntry(
        builder: (ctx) => _LuxuryToastWidget(
          title: title,
          subtitle: subtitle,
          type: type,
          position: position,
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
      // Fallback to porcelain floating SnackBar if overlay cannot be inserted
      _fallbackSnackBar(
        context,
        title,
        subtitle: subtitle,
        type: type,
        duration: duration,
      );
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

    Color accentColor;
    Color pillBg;
    IconData icon;

    switch (type) {
      case ToastType.success:
        accentColor = const Color(0xFF059669);
        pillBg = const Color(0xFFECFDF5);
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        accentColor = const Color(0xFFE11D48);
        pillBg = const Color(0xFFFFF1F2);
        icon = Icons.error_outline_rounded;
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFD97706);
        pillBg = const Color(0xFFFFFBEB);
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        accentColor = AppDesignSystem.primary;
        pillBg = const Color(0xFFFFF5F6);
        icon = Icons.bolt_rounded;
        break;
    }

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
          MediaQuery.of(context).padding.bottom + 90,
        ),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: pillBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                      softWrap: true,
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                        softWrap: true,
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

class _LuxuryToastWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ToastType type;
  final ToastPosition position;
  final VoidCallback onDismiss;

  const _LuxuryToastWidget({
    required this.title,
    this.subtitle,
    required this.type,
    required this.position,
    required this.onDismiss,
  });

  @override
  State<_LuxuryToastWidget> createState() => _LuxuryToastWidgetState();
}

class _LuxuryToastWidgetState extends State<_LuxuryToastWidget> {
  bool _isExiting = false;

  void _triggerDismiss() {
    if (_isExiting) return;
    HapticFeedback.lightImpact();
    setState(() => _isExiting = true);
    Future.delayed(const Duration(milliseconds: 200), widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color accentColor;
    Color pillBg;
    IconData icon;
    String badgeEmoji;
    String badgeLabel;

    switch (widget.type) {
      case ToastType.success:
        accentColor = const Color(0xFF059669); // Emerald 600
        pillBg = const Color(0xFFECFDF5); // Fresh Mint
        icon = Icons.check_circle_rounded;
        badgeEmoji = '✨';
        badgeLabel = 'SUCCESS';
        break;
      case ToastType.error:
        accentColor = const Color(0xFFE11D48); // Rose/Crimson 600
        pillBg = const Color(0xFFFFF1F2); // Soft Rose Petal
        icon = Icons.error_outline_rounded;
        badgeEmoji = '⚡';
        badgeLabel = 'ALERT';
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFD97706); // Warm Amber 600
        pillBg = const Color(0xFFFFFBEB); // Warm Honey Butter
        icon = Icons.warning_amber_rounded;
        badgeEmoji = '⚠️';
        badgeLabel = 'NOTICE';
        break;
      case ToastType.info:
        accentColor = AppDesignSystem.primary; // FastKirana Brand Red #E20A22
        pillBg = const Color(0xFFFFF5F6); // FastKirana Soft Rosy White
        icon = Icons.bolt_rounded;
        badgeEmoji = '🚀';
        badgeLabel = 'FASTKIRANA';
        break;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth - 28).clamp(280.0, 480.0);
    final isTop = widget.position == ToastPosition.top;

    return Positioned(
      top: isTop ? (topPadding + 10) : null,
      bottom: isTop ? null : (bottomPadding + 88),
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          child: Dismissible(
            key: UniqueKey(),
            direction: isTop ? DismissDirection.up : DismissDirection.down,
            onDismissed: (_) => widget.onDismiss(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: _isExiting ? 0.0 : 1.0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                final slideOffset = isTop ? (1 - value) * -28 : (1 - value) * 28;
                return Transform.translate(
                  offset: Offset(0, slideOffset),
                  child: Transform.scale(
                    scale: 0.94 + (value * 0.06),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _triggerDismiss,
                child: Container(
                  width: maxWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      // Ambient diffuse shadow (luxury porcelain elevation)
                      BoxShadow(
                        color: (isDark ? Colors.black : const Color(0xFF0F172A))
                            .withValues(alpha: isDark ? 0.40 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                      // Status accent colored glow aura
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                        decoration: BoxDecoration(
                          // Frosted porcelain surface in light mode; elegant slate in dark mode
                          color: isDark
                              ? const Color(0xF21E293B)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // ── Hardware Specular Top Highlight Rim ──
                            Positioned(
                              top: 0,
                              left: 16,
                              right: 16,
                              height: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(
                                          alpha: isDark ? 0.35 : 0.9),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── Content Row ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Jewel Status Icon Pill
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? accentColor.withValues(alpha: 0.18)
                                        : pillBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.28),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),

                                // ── 100% Truncation-Free Title & Subtitle Column ──
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top Micro-Label / Tag Row
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            badgeEmoji,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            badgeLabel,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: accentColor,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),

                                      // Title Text (Zero Truncation - Full Adaptive Wrap)
                                      Text(
                                        widget.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(
                                              context, 13.0),
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? const Color(0xFFF8FAFC)
                                              : const Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                          height: 1.25,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),

                                      // Subtitle Text (Zero Truncation - Full Adaptive Wrap)
                                      if (widget.subtitle != null &&
                                          widget.subtitle!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          widget.subtitle!.trim(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: Responsive.scaledFontSize(
                                                context, 11.5),
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                            height: 1.35,
                                          ),
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Micro Quick Dismiss Action Button
                                GestureDetector(
                                  onTap: _triggerDismiss,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
