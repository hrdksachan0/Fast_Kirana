import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/theme/design_system.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/deep_link_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Low-memory safe bounds: Max 50 images, 35MB RAM (prevents OOM on 2GB/3GB Android devices)
  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 35 * 1024 * 1024;

  // Global Flutter Error Handling
  if (!kIsWeb && !kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (details.silent) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      } else {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };
  } else {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint("Flutter Error: ${details.exceptionAsString()}");
    };
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: AppDesignSystem.statusCancelled,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: AppDesignSystem.danger),
                  const SizedBox(height: 16),
                  const Text(
                    'Oops! Something went wrong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppDesignSystem.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppDesignSystem.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          AppRouter.navigatorKey.currentState?.pop();
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Go Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // System UI Configuration
  SystemChrome.setPreferredOrientations([
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

  // Fast warm-up for auth cache (with 150ms timeout so it never blocks UI)
  try {
    await SecureStorage.loadCache().timeout(const Duration(milliseconds: 150));
  } catch (_) {}

  // ─── Instant UI Render (<100ms) ─────────────────────────────────
  // Launch the widget tree immediately to draw the first frame on Android.
  // This completely eliminates OS ANR (Application Not Responding) watchdog kills on small phones!
  runApp(const ProviderScope(child: FastKiranaApp()));

  // ─── Non-Blocking Background Services Pipeline ──────────────────
  // Heavy services (Firebase, Supabase, Notifications, Deep Links)
  // initialize asynchronously in background without freezing the UI thread.
  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeBackgroundServices() async {
  try {
    await Future.wait([
      if (!kIsWeb)
        (() async {
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
            FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
            final notificationService = NotificationService();
            await notificationService.init();
          } catch (e) {
            debugPrint("Firebase background initialization notice: $e");
          }
        })(),

      (() async {
        try {
          await SupabaseService.initialize();
        } catch (e) {
          debugPrint("Supabase background initialization notice: $e");
        }
      })(),

      if (!kIsWeb)
        (() async {
          try {
            await DeepLinkService.instance.init();
          } catch (e) {
            debugPrint("DeepLink background initialization notice: $e");
          }
        })(),
    ]);
  } catch (e) {
    debugPrint("Background services batch notice: $e");
  }
}

class FastKiranaApp extends StatelessWidget {
  const FastKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastKirana',
      navigatorKey: AppRouter.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: '/splash',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Industry-standard mobile clamping (prevents severe card blowout & truncation on high-DPI / large OS font devices)
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}