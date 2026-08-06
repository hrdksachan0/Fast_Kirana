import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FastKirana Premium Brand Design System
/// Color palette, typography, spacing, and shadows matching web app
class AppDesignSystem {
  // Primary brand colors (matching web app orange theme)
  static const Color primary = Color(0xFFEA580C);
  static const Color primaryLight = Color(0xFFFB923C);
  static const Color primaryDark = Color(0xFFC2410C);

  // Accent colors
  static const Color accent = Color(0xFF10B981);
  static const Color accentLight = Color(0xFF34D399);
  static const Color accentDark = Color(0xFF047857);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Colors.white;

  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Typography
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
      displayMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
      displaySmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
      headlineLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
      headlineMedium: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      headlineSmall: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary),
      bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
      labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
      labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: textTertiary),
    );
  }

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // Shadows
  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: const Color(0x0A000000), blurRadius: 4, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(color: const Color(0x1A000000), blurRadius: 8, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: const Color(0x33000000), blurRadius: 12, offset: const Offset(0, 6)),
  ];
  static List<BoxShadow> get shadowXl => [
    BoxShadow(color: const Color(0x4D000000), blurRadius: 20, offset: const Offset(0, 10)),
  ];
}