import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'design_system.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
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
      textTheme: GoogleFonts.interTextTheme(),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppDesignSystem.primary,
        onPrimary: Colors.white,
        surface: AppDesignSystem.darkSurface,
        onSurface: AppDesignSystem.darkTextPrimary,
      ),
      scaffoldBackgroundColor: AppDesignSystem.darkBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );
  }
}