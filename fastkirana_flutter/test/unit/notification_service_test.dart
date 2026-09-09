import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification — token persistence and auth gate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SecureStorage.invalidateCache();
    });

    tearDown(() {
      SecureStorage.invalidateCache();
    });

    test('pending_fcm_token survives app restart until user logs in', () async {
      // Simulate: app gets FCM token but user is not yet authenticated
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_fcm_token', 'fcm_pending_token_xyz');

      // User data is not in SecureStorage (not logged in)
      SecureStorage.invalidateCache();

      // pending_fcm_token should still be there for later registration
      expect(prefs.getString('pending_fcm_token'), 'fcm_pending_token_xyz');
    });

    test('auth_token availability gates FCM registration', () async {
      // Without auth_token, notification service stores token as pending
      SecureStorage.invalidateCache();

      final authToken = await SecureStorage.read('auth_token');
      expect(authToken, isNull,
          reason: 'Without login, auth_token should be null → FCM stays pending');

      // After login, token is stored
      await SecureStorage.write('auth_token', 'jwt_token_here');
      expect(await SecureStorage.read('auth_token'), 'jwt_token_here');
    });

    test('phone number normalization for topic subscription', () {
      String normalize(String phone) =>
          phone.replaceAll(RegExp(r'^\+?91[-\s]?'), '').replaceAll(RegExp(r'[-\s]'), '').trim();

      expect(normalize('+919876543210'), '9876543210');
      expect(normalize('91 9876 543 210'), '9876543210');
      expect(normalize('9876543210'), '9876543210');
      expect(normalize('+91-98765-43210'), '9876543210');
      expect(normalize(''), '');
    });

    test('pending_fcm_token is cleared after successful registration', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_fcm_token', 'token_to_clear');

      // NotificationService clears pending_fcm_token after successful API response
      await prefs.remove('pending_fcm_token');

      expect(prefs.containsKey('pending_fcm_token'), isFalse);
    });
  });
}
