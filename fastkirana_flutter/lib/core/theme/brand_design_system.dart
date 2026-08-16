import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FastKirana Premium Design System
/// Based on brand guidelines: Orange-Red primary, green accent, clean modern aesthetic
class BrandColors {
  // Primary Brand Colors (Web globals.css: #E20A22)
  static const Color primary = Color(0xFFE20A22); // FastKirana Core Red
  static const Color primaryDark = Color(0xFFB30013);
  static const Color primaryLight = Color(0xFFFF4D62);
  static const Color primaryGradientStart = Color(0xFFE20A22);
  static const Color primaryGradientEnd = Color(0xFFFF4D62);

  // Accent & Secondary
  static const Color accent = Color(0xFF00B140); // Leaf Green (#00B140)
  static const Color accentLight = Color(0xFF3CC070);
  static const Color accentDark = Color(0xFF008F33);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral Palette
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Colors.white;

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6); // Gray 100

  // Status Colors
  static const Color statusPending = Color(0xFFFEF3C7); // Yellow 100
  static const Color statusPendingText = Color(0xFF92400E); // Yellow 800
  static const Color statusConfirmed = Color(0xFFDBEAFE); // Blue 100
  static const Color statusConfirmedText = Color(0xFF1E40AF); // Blue 800
  static const Color statusPacked = Color(0xFFE0E7FF); // Indigo 100
  static const Color statusPackedText = Color(0xFF3730A3); // Indigo 800
  static const Color statusShipped = Color(0xFFF3E8FF); // Purple 100
  static const Color statusShippedText = Color(0xFF6B21A8); // Purple 800
  static const Color statusDelivered = Color(0xFFD1FAE5); // Green 100
  static const Color statusDeliveredText = Color(0xFF065F46); // Green 800
  static const Color statusCancelled = Color(0xFFFEE2E2); // Red 100
  static const Color statusCancelledText = Color(0xFF991B1B); // Red 800

  // Shadows
  static const Color shadowSm = Color(0x0A000000);
  static const Color shadowMd = Color(0x1A000000);
  static const Color shadowLg = Color(0x33000000);
  static const Color shadowXl = Color(0x4D000000);
}

class BrandTypography {
  static TextTheme get textTheme {
    return TextTheme(
      // Display
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: BrandColors.textPrimary,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: BrandColors.textPrimary,
        height: 1.25,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: BrandColors.textPrimary,
        height: 1.3,
      ),

      // Headings
      headlineLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: BrandColors.textPrimary,
        height: 1.4,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: BrandColors.textPrimary,
        height: 1.4,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: BrandColors.textPrimary,
        height: 1.5,
      ),

      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: BrandColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: BrandColors.textSecondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: BrandColors.textSecondary,
        height: 1.5,
      ),

      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: BrandColors.textPrimary,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: BrandColors.textSecondary,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: BrandColors.textTertiary,
        height: 1.4,
      ),
    );
  }
}

class BrandSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double cardPadding = 16.0;
  static const double screenPadding = 20.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;
}

class BrandShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: BrandColors.shadowSm,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: BrandColors.shadowMd,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: BrandColors.shadowLg,
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: BrandColors.shadowXl,
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
}