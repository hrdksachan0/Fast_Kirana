import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_system.dart';
import '../routes/page_transitions.dart';

class AppTheme {
  static const _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FastKiranaPageTransitionsBuilder(),
      TargetPlatform.iOS: FastKiranaPageTransitionsBuilder(),
      TargetPlatform.macOS: FastKiranaPageTransitionsBuilder(),
      TargetPlatform.windows: FastKiranaPageTransitionsBuilder(),
      TargetPlatform.linux: FastKiranaPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.light(
        primary: AppDesignSystem.primary,
        onPrimary: Colors.white,
        secondary: AppDesignSystem.accent,
        onSecondary: Colors.white,
        error: AppDesignSystem.danger,
        surface: AppDesignSystem.surface,
        onSurface: AppDesignSystem.textPrimary,
      ),
      scaffoldBackgroundColor: AppDesignSystem.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignSystem.primary,
          side: const BorderSide(color: AppDesignSystem.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppDesignSystem.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          side: const BorderSide(color: AppDesignSystem.borderLight),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppDesignSystem.divider,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: GoogleFonts.interTextTheme(),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppDesignSystem.primary,
        onPrimary: Colors.white,
        secondary: AppDesignSystem.accent,
        onSecondary: Colors.white,
        error: AppDesignSystem.danger,
        surface: AppDesignSystem.darkSurface,
        onSurface: AppDesignSystem.darkTextPrimary,
      ),
      scaffoldBackgroundColor: AppDesignSystem.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDesignSystem.darkSurface,
        foregroundColor: AppDesignSystem.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignSystem.primary,
          side: const BorderSide(color: AppDesignSystem.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.darkSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: const BorderSide(color: AppDesignSystem.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppDesignSystem.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          side: const BorderSide(color: AppDesignSystem.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppDesignSystem.darkBorder,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppDesignSystem.darkSurface,
        modalBackgroundColor: AppDesignSystem.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );
  }
}