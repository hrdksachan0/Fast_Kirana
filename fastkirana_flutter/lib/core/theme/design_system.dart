import 'package:flutter/material.dart';

/// FastKirana Design System — the single source of truth for all colors, spacing, radii, shadows.
/// AppColors (in core/constants/) is a legacy alias; migrate to AppDesignSystem over time.
class AppDesignSystem {
  // FastKirana Brand Colors (Matching Web App globals.css: Red #E20A22)
  static const Color primary = Color(0xFFE20A22);
  static const Color primaryDark = Color(0xFFB30013);
  static const Color primaryLight = Color(0xFFFF4D62);
  static const Color primaryBg = Color(0xFFFFF5F6);
  static const Color cafeAccent = Color(0xFFF97316); // Tailwind Orange 500
  static const Color accent = Color(0xFF00B140); // Leaf Green
  static const Color accentLight = Color(0xFF3CC070);
  static const Color accentDark = Color(0xFF008F33);
  static const Color discount = Color(0xFFFF6B35);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6); // Standard Blue 500
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
  static const Color statusDelivered = Color(0xFFD1FAE5); // Corrected to Emerald 100
  static const Color statusDeliveredText = Color(0xFF065F46); // Corrected to Emerald 800
  static const Color statusCancelled = Color(0xFFFEE2E2);
  static const Color statusCancelledText = Color(0xFF991B1B);

  // Light Mode Surfaces
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);

  // Dark Mode Surfaces (Matching Web globals.css .dark)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF18181B);
  static const Color darkSurfaceMuted = Color(0xFF27272A);
  static const Color darkBorder = Color(0xFF27272A);
  static const Color darkTextPrimary = Color(0xFFE4E4E7);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFF3F4F6);

  // Text Hierarchy (Matching Web)
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
    colors: [Color(0xFF00B140), Color(0xFF3CC070)], // Corrected Green Gradient
  );

  static const LinearGradient cartBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE8153A), Color(0xFFFF2D55), Color(0xFFFF4742)],
  );

  static const LinearGradient deliveryProgressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFCD34D), Color(0xFFFDE047), Color(0xFF6EE7B7)],
  );

  // Shadows
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowCard = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Radius (Normalized to Web standard scale)
  static const double radiusXs = 4;
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 24;
  static const double radiusFull = 9999;

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}