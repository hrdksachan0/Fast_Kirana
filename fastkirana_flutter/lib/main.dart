import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/design_system.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Global Flutter Error Handling ───────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exceptionAsString()}");
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: const Color(0xFFFEF2F2),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFDC2626)),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppDesignSystem.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kDebugMode
                        ? details.exceptionAsString()
                        : 'Please restart the app. If the problem persists, contact support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppDesignSystem.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (kDebugMode)
                    ElevatedButton.icon(
                      onPressed: () => FlutterError.dumpErrorToConsole(details),
                      icon: const Icon(Icons.bug_report_rounded, size: 18),
                      label: const Text('Show Stack Trace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.danger,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // ─── System UI Configuration ────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppDesignSystem.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ─── Firebase Initialization ────────────────────────────────────
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final notificationService = NotificationService();
      await notificationService.init();
      await notificationService.requestPermissions();
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }
  }

  // ─── Supabase Realtime Initialization ───────────────────────────
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }

  // ─── Launch App ─────────────────────────────────────────────────
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
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}