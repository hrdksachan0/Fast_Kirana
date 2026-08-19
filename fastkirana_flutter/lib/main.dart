import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/design_system.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and Notification Manager Services
  try {
    await Firebase.initializeApp();
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
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
      initialRoute: '/home',
    );
  }
}