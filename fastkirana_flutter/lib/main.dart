import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'core/theme/design_system.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log all Flutter UI errors to console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("🔴 Flutter Error: ${details.exceptionAsString()}");
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                const Text('Render Error', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                const SizedBox(height: 6),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Initialize Firebase and Notification Manager Services safely
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final notificationService = NotificationService();
      await notificationService.init();
      await notificationService.requestPermissions();
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppDesignSystem.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: FastKiranaApp()));
}

class FastKiranaApp extends StatelessWidget {
  const FastKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastKirana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: '/splash',
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}