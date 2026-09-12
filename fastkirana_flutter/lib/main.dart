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

  // ─── CRITICAL PERFORMANCE FIX ──────────────────────────────────
  // Allow runtime fetching on all platforms so GoogleFonts don't crash when individual variant files are missing.
  GoogleFonts.config.allowRuntimeFetching = true;


  // Image Cache Memory Bounds (Max 100 images or 60MB RAM)
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;

  // ─── Global Flutter Error Handling ───────────────────────────────
  // When Crashlytics is enabled (Firebase initialized below) we forward
  // uncaught Flutter framework errors to it. Silent errors (like image 404s
  // or asset errors handled by errorBuilder) are recorded as non-fatal
  // or silenced to prevent false fatal crash spikes in Crashlytics.
  if (!kIsWeb && !kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (details.silent) {
        // Handled gracefully in UI (e.g. by errorBuilder / CachedNetworkImage.errorWidget)
        FirebaseCrashlytics.instance.recordFlutterError(details);
      } else {
        // Real uncaught fatal framework error
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

  // ─── System UI Configuration ────────────────────────────────────
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

  // ─── High-Performance Concurrent Startup Pipeline (<1s cold start) ───
  // Run critical initializations in parallel instead of sequential blocking awaits
  await Future.wait([
    // 1. Firebase & Background Messaging (non-web)
    if (!kIsWeb)
      (() async {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          final notificationService = NotificationService();
          await notificationService.init();
          // Note: requestPermissions is moved to non-blocking post-splash to avoid freeze
        } catch (e) {
          debugPrint("Firebase initialization failed: $e");
        }
      })(),

    // 2. Supabase Realtime Initialization
    (() async {
      try {
        await SupabaseService.initialize();
      } catch (e) {
        debugPrint("Supabase initialization error: $e");
      }
    })(),

    // 3. Auth Cache Warm-up (zero I/O on subsequent API calls)
    (() async {
      try {
        await SecureStorage.loadCache();
      } catch (e) {
        debugPrint("Auth cache load error: $e");
      }
    })(),

    // 4. Deep Linking Initialization (Universal Links & Custom Scheme)
    if (!kIsWeb)
      (() async {
        try {
          await DeepLinkService.instance.init();
        } catch (e) {
          debugPrint("DeepLink initialization error: $e");
        }
      })(),
  ]);

  // ─── Launch App Instantly ───────────────────────────────────────
  runApp(const ProviderScope(child: FastKiranaApp()));
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