import 'package:flutter/material.dart';
export 'responsive.dart';

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
  static const Color accentDark = Color(0xFF008736);
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
  static const Color statusCancelled = Color(0xFFFEF2F2);
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
    colors: [Color(0xFF00B140), Color(0xFF3CC070)],
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
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowCard = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
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

  // Color Palette
  // Slate Neutrals
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Extended Palette
  static const Color rose300 = Color(0xFFFDA4AF);
  static const Color rose400 = Color(0xFFF43F5E);
  static const Color rose500 = Color(0xFFE11D48);
  static const Color rose500alt = Color(0xFFFF2D55);
  static const Color rose600 = Color(0xFFBE123C);
  static const Color rose800 = Color(0xFF9F1239);
  static const Color rose900 = Color(0xFF881337);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose50 = Color(0xFFFDF2F8);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose100alt = Color(0xFFFCE7F3);
  static const Color zinc950 = Color(0xFF09090B);
  static const Color fuchsia600 = Color(0xFF9333EA);
  static const Color fuchsia500 = Color(0xFFD946EF);
  static const Color indigo950 = Color(0xFF1E1B4B);
  static const Color indigo900 = Color(0xFF4338CA);
  static const Color indigo700 = Color(0xFF4F46E5);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green200 = Color(0xFFBBF7D0);
  static const Color green400 = Color(0xFF4ADE80);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);
  static const Color green900 = Color(0xFF14532D);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald900 = Color(0xFF064E3B);
  static const Color emeraldGreen = Color(0xFF00965E);
  static const Color emeraldBrand = Color(0xFF00965E);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldShadow = Color(0xFF064E3B);
  static const Color lime100 = Color(0xFFF7FEE7);
  static const Color lime500 = Color(0xFF22C55E);
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = Color(0xFF9A3412);
  static const Color amber900 = Color(0xFF78350F);
  static const Color amber600 = Color(0xFFD97706);
  static const Color sky50 = Color(0xFFF0F9FF);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange500 = Color(0xFFF97316);
  static const Color orange700 = Color(0xFFC2410C);
  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange200 = Color(0xFFFFEDD5);
  static const Color orange300 = Color(0xFFFED7AA);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red500 = Color(0xFFFF334B);
  static const Color red400 = Color(0xFFFF1E3C);
  static const Color red300 = Color(0xFFFF4742);
  static const Color red200 = Color(0xFFFFECEF);
  static const Color red100 = Color(0xFFFFD1D8);
  static const Color red700 = Color(0xFFC00418);
  static const Color red800 = Color(0xFFB91C1C);
  static const Color red900 = Color(0xFF7F1D1D);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue500 = Color(0xFF3395FF);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color violet500 = Color(0xFF8B5CF6);
  static const Color violet600 = Color(0xFF7C3AED);
  static const Color violet50 = Color(0xFFFAF5FF);
  static const Color violet200 = Color(0xFFE9D5FF);
  static const Color violet300 = Color(0xFFD8B4FE);
  static const Color violet700 = Color(0xFF6D28D9);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan400 = Color(0xFF38BDF8);
  static const Color cyan300 = Color(0xFF93C5FD);
  static const Color cyan400alt = Color(0xFF22D3EE);
  static const Color cyan300alt = Color(0xFF67E8F9);
  static const Color cyan600 = Color(0xFF0284C7);
  static const Color cyan700 = Color(0xFF0369A1);
  static const Color cyan100 = Color(0xFFE0F2FE);
  static const Color cyan200 = Color(0xFFBAE6FD);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal300 = Color(0xFF99F6E4);
  static const Color teal100 = Color(0xFFCCFBF1);
  // Dark navy for delivery theme
  static const Color darkNavy = Color(0xFF0A0F1D);
  static const Color darkNavyCard = Color(0xFF131C2E);
  static const Color darkNavySubtle = Color(0xFF1A263D);
  static const Color darkNavyBorder = Color(0xFF23324D);
  static const Color darkNavyHeader = Color(0xFF0C2340);
  // Misc
  static const Color warmWhite = Color(0xFFFEFDF5);
  static const Color warmCream = Color(0xFFFEFCE8);
  static const Color stone50 = Color(0xFFFAF9FB);
  static const Color stone500 = Color(0xFF78716C);
  static const Color yellow200 = Color(0xFFFDE68A);
  static const Color yellow50 = Color(0xFFFEFCE8);
  static const Color yellow300 = Color(0xFFFEF08A);
  static const Color yellow400 = Color(0xFFFACC15);
  static const Color fuchsia700 = Color(0xFF7E22CE);
  static const Color yellow700 = Color(0xFFCA8A04);
  static const Color green700Brand = Color(0xFF00A344);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color gray400 = Color(0xFFCCCCCC);
  static const Color rose50alt = Color(0xFFFFF0F0);
  static const Color pink500 = Color(0xFFEC4899);
  static const Color pink600 = Color(0xFFDB2777);

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}
