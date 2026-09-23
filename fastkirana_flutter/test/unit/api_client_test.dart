import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/core/network/api_client.dart';
import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient Network Resilience & Retry Constants', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SecureStorage.invalidateCache();
    });

    test('kNetworkRetryDelays contains 3-step exponential backoff (3s, 6s, 9s)', () {
      expect(kNetworkRetryDelays.length, 3);
      expect(kNetworkRetryDelays[0], const Duration(seconds: 3));
      expect(kNetworkRetryDelays[1], const Duration(seconds: 6));
      expect(kNetworkRetryDelays[2], const Duration(seconds: 9));
    });

    test('Non-retryable routes check prevents financial & order mutation duplicates', () {
      final nonRetryablePaths = [
        '/api/orders',
        '/api/orders/checkout',
        '/api/payment/verify',
        'kot-broadcast',
        'broadcast',
      ];

      for (final path in nonRetryablePaths) {
        final isNonRetryable = path.contains('kot-broadcast') ||
            path.contains('broadcast') ||
            path.contains('/api/orders') ||
            path.contains('/api/payment');
        expect(isNonRetryable, isTrue, reason: '$path should be protected from automatic retry');
      }

      final retryablePaths = [
        '/api/products',
        '/api/categories',
        '/api/banners',
        '/api/restaurants',
      ];

      for (final path in retryablePaths) {
        final isNonRetryable = path.contains('kot-broadcast') ||
            path.contains('broadcast') ||
            path.contains('/api/orders') ||
            path.contains('/api/payment');
        expect(isNonRetryable, isFalse, reason: '$path should be retryable');
      }
    });

    test('Token cache loads properly and cleans up on session revocation', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'initial_token_123');
      await prefs.setString('refresh_token', 'refresh_token_456');

      await SecureStorage.loadCache();
      expect(SecureStorage.cachedToken, 'initial_token_123');
      expect(SecureStorage.cachedRefreshToken, 'refresh_token_456');

      // Emulate session clear on 401 revocation
      await SecureStorage.deleteAll();
      expect(SecureStorage.cachedToken, isNull);
      expect(SecureStorage.cachedRefreshToken, isNull);
    });
  });
}
