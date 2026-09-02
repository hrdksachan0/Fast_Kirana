import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage wrapper for sensitive data (auth tokens, user credentials).
///
/// Falls back to SharedPreferences for one-time migration of legacy auth keys
/// (`auth_token`, `user_data`, `user_id`, `user_phone`, `user_email`, `user_name`,
/// `user_role`) that may have been written before secure storage was wired.
/// On read, if the value is found in prefs but not in secure storage, it is
/// migrated and removed from prefs.
class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Keys that used to live in SharedPreferences. Read fallback checks these
  /// so existing logged-in users aren't silently logged out after upgrade.
  static const _legacyPrefsKeys = <String>{
    'auth_token',
    'user_data',
    'user_id',
    'user_phone',
  };

  static Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) return value;

      // One-time migration fallback for legacy keys
      if (_legacyPrefsKeys.contains(key)) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(key);
        if (legacy != null && legacy.isNotEmpty) {
          await _storage.write(key: key, value: legacy);
          await prefs.remove(key);
          return legacy;
        }
      }
      return null;
    } catch (_) {
      // Secure storage unavailable (eg. locked device). Fall back to prefs.
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Best-effort fallback to prefs if secure storage fails.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {}
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Wipes ALL keys from secure storage. Used on logout.
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  /// Bulk read — useful for the auth interceptor which previously read
  /// several keys at once from SharedPreferences.
  static Future<Map<String, String>> readMany(Iterable<String> keys) async {
    final result = <String, String>{};
    for (final key in keys) {
      final value = await read(key);
      if (value != null && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }
}