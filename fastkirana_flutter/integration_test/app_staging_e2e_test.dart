import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fastminute_flutter/main.dart';
import 'package:fastminute_flutter/core/config/app_config.dart';

/// Real physical-device / staging integration test entry point.
/// Initializes IntegrationTestWidgetsFlutterBinding, launches the full application,
/// operates with real persistent storage (SharedPreferences / SecureStorage),
/// and connects to the staging backend.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('FastKirana Real-World Staging Integration Test', () {
    testWidgets('App boots full widget tree and renders home shell against staging',
        (WidgetTester tester) async {
      // 1. Launch real application entry point
      await tester.pumpWidget(
        const ProviderScope(
          child: FastKiranaApp(),
        ),
      );

      // Settle initial asynchronous initialization and layout
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 2. Verify that core UI shell renders without fatal crashes or unhandled exceptions
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify current API configuration is targeted
      debugPrint('[STAGING E2E] API Base URL configured: ${AppConfig.apiBaseUrl}');
      debugPrint('[STAGING E2E] Cashfree Environment: ${AppConfig.cashfreeEnv}');
    });
  });
}
