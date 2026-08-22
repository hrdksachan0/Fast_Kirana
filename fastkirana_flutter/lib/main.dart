import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/design_system.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom Error Widget to prevent White Screen on unhandled UI errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_rounded, size: 64, color: Color(0xFFE20A22)),
              const SizedBox(height: 16),
              const Text(
                'FastKirana',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Loading app components...',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Initialize Firebase and Notification Manager Services safely
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
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
    );
  }
}