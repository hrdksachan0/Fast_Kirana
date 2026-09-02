import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';

void main() {
  group('SecureStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('readMany', () {
      test('returns map of keys present in SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'tok');
        await prefs.setString('user_id', 'uid');

        final result = await SecureStorage.readMany(
          ['auth_token', 'user_id', 'missing_key'],
        );

        expect(result['auth_token'], 'tok');
        expect(result['user_id'], 'uid');
        expect(result.containsKey('missing_key'), isFalse);
      });
    });

    group('read', () {
      test('returns null for missing key', () async {
        final value = await SecureStorage.read('nonexistent_key_xyz');
        expect(value, isNull);
      });

      test('reads from SharedPreferences when present', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'legacy_tok');

        final value = await SecureStorage.read('auth_token');
        expect(value, 'legacy_tok');
      });
    });

    group('delete', () {
      test('removes key from SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'tok');

        await SecureStorage.delete('auth_token');
        expect(prefs.containsKey('auth_token'), isFalse);
        expect(await SecureStorage.read('auth_token'), isNull);
      });

      test('does not throw on missing key', () async {
        await SecureStorage.delete('auth_token_never_written');
        expect(await SecureStorage.read('auth_token_never_written'), isNull);
      });
    });

    group('write', () {
      test('writes value without throwing', () async {
        await SecureStorage.write('auth_token', 'tok_abc');
        // Value is retrievable via read
        expect(await SecureStorage.read('auth_token'), 'tok_abc');
      });
    });

    group('deleteAll', () {
      test('does not throw with no keys present', () async {
        await SecureStorage.deleteAll();
        expect(await SecureStorage.read('auth_token'), isNull);
      });

      test('does not throw when secure storage has values', () async {
        await SecureStorage.write('auth_token', 't1');
        await SecureStorage.deleteAll();
        // No assertion on outcome since secure storage is a no-op on test env;
        // just verifies the call doesn't throw.
      });
    });
  });
}
