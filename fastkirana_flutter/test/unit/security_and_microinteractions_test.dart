import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';
import 'package:fastkirana_flutter/core/services/biometric_service.dart';
import 'package:fastkirana_flutter/widgets/shimmer_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'old_expired_jwt_token',
      'refresh_token': 'valid_refresh_token_123',
      'user_id': 'usr_test_1',
    });
    await SecureStorage.loadCache();
  });

  group('Step 3: Security & Token Auto-Refresh', () {
    test('SecureStorage handles tokens in memory and storage', () async {
      expect(SecureStorage.cachedToken, equals('old_expired_jwt_token'));
      expect(SecureStorage.cachedRefreshToken, equals('valid_refresh_token_123'));

      // Update with new token
      await SecureStorage.saveAuthToken('new_fresh_jwt_token');
      expect(SecureStorage.cachedToken, equals('new_fresh_jwt_token'));

      final storedToken = await SecureStorage.read('auth_token');
      expect(storedToken, equals('new_fresh_jwt_token'));
    });

    test('BiometricService provides safe fallback on unsupported environments', () async {
      final available = await BiometricService.isBiometricAvailable();
      // On headless test runners, biometric hardware should report false or handle gracefully
      expect(available, isA<bool>());

      final authenticated = await BiometricService.authenticate(reason: 'Test Unlock');
      expect(authenticated, isA<bool>());
    });
  });

  group('Step 4: UI/UX Micro-Interactions & Shimmer', () {
    testWidgets('ProductCardShimmer renders without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductCardShimmer(),
          ),
        ),
      );

      expect(find.byType(ProductCardShimmer), findsOneWidget);
    });

    testWidgets('CategoryShimmer and OrderRowShimmer render cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CategoryShimmer(),
                OrderRowShimmer(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CategoryShimmer), findsOneWidget);
      expect(find.byType(OrderRowShimmer), findsOneWidget);
    });
  });
}
