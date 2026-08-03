import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE20A22);
  static const Color primaryDark = Color(0xFFB7151E);
  static const Color accent = Color(0xFFF43F5E);
  static const Color discount = Color(0xFFE20A22);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF4F4F5);
  static const Color border = Color(0xFFE4E4E7);
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textMuted = Color(0xFFA1A1AA);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color cafeAccent = Color(0xFFF97316);
  static const Color groceryAccent = Color(0xFFEF4444);
  static const Color bestSellerBg = Color(0xFFFEF3C7);
  static const Color bestSellerText = Color(0xFFD97706);

  static TextStyle _text(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
      letterSpacing: size < 12 ? 0.2 : 0,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: Color(0xFFFEF2F2),
        surface: background,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        outline: border,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'PlusJakartaSans',
      textTheme: TextTheme(
        displayLarge: _text(32, FontWeight.w800, textPrimary),
        headlineMedium: _text(24, FontWeight.w700, textPrimary),
        titleLarge: _text(20, FontWeight.w700, textPrimary),
        titleMedium: _text(16, FontWeight.w600, textPrimary),
        bodyMedium: _text(14, FontWeight.w400, textPrimary),
        bodySmall: _text(12, FontWeight.w400, textSecondary),
        labelLarge: _text(14, FontWeight.w700, Colors.white),
        labelMedium: _text(12, FontWeight.w600, textPrimary),
        labelSmall: _text(11, FontWeight.w700, textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withOpacity(0.5), width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonTheme(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: _text(14, FontWeight.w800, Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _text(12, FontWeight.w800, primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        labelStyle: _text(12, FontWeight.w600, textSecondary),
        selectedLabelStyle: _text(12, FontWeight.w700, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: _text(12, FontWeight.w400, textMuted),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: Color(0xFF3F1218),
        surface: Color(0xFF09090B),
        onSurface: Color(0xFFFAFAFA),
        onPrimary: Colors.white,
        outline: Color(0xFF27272A),
        error: error,
      ),
      scaffoldBackgroundColor: const Color(0xFF09090B),
      fontFamily: 'PlusJakartaSans',
      textTheme: TextTheme(
        displayLarge: _text(32, FontWeight.w800, Color(0xFFFAFAFA)),
        headlineMedium: _text(24, FontWeight.w700, Color(0xFFFAFAFA)),
        titleLarge: _text(20, FontWeight.w700, Color(0xFFFAFAFA)),
        titleMedium: _text(16, FontWeight.w600, Color(0xFFFAFAFA)),
        bodyMedium: _text(14, FontWeight.w400, Color(0xFFFAFAFA)),
        bodySmall: _text(12, FontWeight.w400, Color(0xFFA1A1AA)),
        labelLarge: _text(14, FontWeight.w700, Colors.white),
        labelMedium: _text(12, FontWeight.w600, Color(0xFFFAFAFA)),
        labelSmall: _text(11, FontWeight.w700, Color(0xFFFAFAFA)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFFFAFAFA),
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF18181B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFF27272A), width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonTheme(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: _text(14, FontWeight.w800, Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _text(12, FontWeight.w800, primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF27272A),
        selectedColor: primary,
        labelStyle: _text(12, FontWeight.w600, Color(0xFFA1A1AA)),
        selectedLabelStyle: _text(12, FontWeight.w700, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF18181B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: _text(12, FontWeight.w400, Color(0xFF71717A)),
      ),
    );
  }
}
