import 'package:flutter/material.dart';

class AppDesignSystem {
  // FastKirana Brand Colors (Matching Web App globals.css: Red #E20A22)
  static const Color primary = Color(0xFFE20A22);
  static const Color primaryDark = Color(0xFFB30013);
  static const Color primaryLight = Color(0xFFFF4D62);
  static const Color cafeAccent = Color(0xFFF59E0B);
  static const Color accent = Color(0xFF00B140);
  static const Color accentDark = Color(0xFF008F33);
  static const Color discount = Color(0xFFFF6B35);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3080FF);
  static const Color success = Color(0xFF10B981);

  // Status Colors
  static const Color statusPending = Color(0xFFFEF3C7);
  static const Color statusPendingText = Color(0xFF92400E);
  static const Color statusConfirmed = Color(0xFFDBEAFE);
  static const Color statusConfirmedText = Color(0xFF1E40AF);
  static const Color statusPacked = Color(0xFFE0E7FF);
  static const Color statusPackedText = Color(0xFF3730A3);
  static const Color statusShipped = Color(0xFFF3E8FF);
  static const Color statusShippedText = Color(0xFF6B21A8);
  static const Color statusDelivered = Color(0xFFFFE4E6);
  static const Color statusDeliveredText = Color(0xFFB30013);
  static const Color statusCancelled = Color(0xFFFEE2E2);
  static const Color statusCancelledText = Color(0xFF991B1B);

  // Light Mode Surfaces
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFEDEEF1);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE20A22), Color(0xFFFF4D62)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF99C00), Color(0xFFFE6E00)],
  );

  // Shadows
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowCard = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Radius
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radius2xl = 36;
  static const double radiusFull = 999;

  // Spacing
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}