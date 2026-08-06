import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/design_system.dart';
import 'features/splash/splash_screen.dart';
import 'core/routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FastKiranaApp()));
}

class FastKiranaApp extends StatelessWidget {
  const FastKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastKirana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppDesignSystem.primary,
          onPrimary: Colors.white,
          secondary: AppDesignSystem.accent,
          error: AppDesignSystem.danger,
          surface: AppDesignSystem.surface,
          onSurface: AppDesignSystem.textPrimary,
        ),
        scaffoldBackgroundColor: AppDesignSystem.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppDesignSystem.primary,
          foregroundColor: Colors.white,
          elevation: 0,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardTheme(
          color: AppDesignSystem.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
            side: const BorderSide(color: AppDesignSystem.borderLight),
          ),
        ),
      ),
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: '/',
    );
  }
}