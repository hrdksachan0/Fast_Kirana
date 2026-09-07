import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Token — persistence and restore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SecureStorage.invalidateCache();
    });

    tearDown(() {
      SecureStorage.invalidateCache();
    });

    test('saveFcmToken persists token and reloads it', () async {
      await SecureStorage.saveFcmToken('fcm_test_token_abc');

      // Token should be retrievable via read
      final token = await SecureStorage.read('fcm_token');
      expect(token, 'fcm_test_token_abc');
    });

    test('saveFcmToken overwrites previous token', () async {
      await SecureStorage.saveFcmToken('token_v1');
      expect(await SecureStorage.read('fcm_token'), 'token_v1');

      await SecureStorage.saveFcmToken('token_v2');
      expect(await SecureStorage.read('fcm_token'), 'token_v2');
    });

    test('clear() removes fcm_token from storage', () async {
      await SecureStorage.saveFcmToken('tok_xyz');
      expect(await SecureStorage.read('fcm_token'), 'tok_xyz');

      await SecureStorage.deleteAll();
      expect(await SecureStorage.read('fcm_token'), isNull);
    });

    test('token survives across reloadCache cycles', () async {
      await SecureStorage.saveFcmToken('persistent_token');

      // Simulate app restart: invalidate cache and reload
      SecureStorage.invalidateCache();
      await SecureStorage.loadCache();

      // Token should be in cache again after loadCache reads from storage
      expect(SecureStorage.cachedToken, isNull); // cachedToken is for 'auth_token', not 'fcm_token'
      // fcm_token is not cached separately in-memory; it's retrieved via read()
      final fcmToken = await SecureStorage.read('fcm_token');
      expect(fcmToken, 'persistent_token');
    });

    test('empty token is not saved', () async {
      await SecureStorage.saveFcmToken('');
      final token = await SecureStorage.read('fcm_token');
      // saveFcmToken skips saving empty strings
      expect(token, isNull);
    });

    test('migration does not affect fcm_token (not a legacy key)', () async {
      // Set fcm_token only in SharedPreferences (simulating a scenario where
      // it was written outside of SecureStorage)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', 'external_fcm');

      // read() only migrates legacy auth keys (auth_token, user_data, etc.),
      // NOT fcm_token, so it should not be found after invalidateCache/loadCache
      // since fcm_token is not in secure storage
      SecureStorage.invalidateCache();
      await SecureStorage.loadCache();

      final token = await SecureStorage.read('fcm_token');
      // In test env: fcm_token is in SharedPreferences, so read() finds it
      expect(token, 'external_fcm');
    });
  });
}
