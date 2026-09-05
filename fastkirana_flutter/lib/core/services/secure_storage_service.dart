import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage wrapper for sensitive data (auth tokens, user credentials).
///
/// Falls back to SharedPreferences for one-time migration of legacy auth keys
class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _legacyPrefsKeys = <String>{
    'auth_token',
    'user_data',
    'user_id',
    'user_phone',
  };

  // ─── In-memory auth cache (avoids repeated I/O on every API call) ───
  static String? _cachedToken;
  static String? _cachedRefreshToken;
  static String? _cachedUserId;
  static String? _cachedUserPhone;
  static String? _cachedUserEmail;
  static String? _cachedUserName;
  static String? _cachedUserRole;
  static Map<String, String>? _cachedUserData;
  static bool _isCacheLoaded = false;

  /// Returns true if the in-memory cache has been populated.
  static bool get isCacheLoaded => _isCacheLoaded;

  /// Load all auth fields into the in-memory cache once.
  /// Call this on app startup and after any auth mutation (login/logout).
  static Future<void> loadCache() async {
    if (_isCacheLoaded) return;
    try {
      _cachedToken = await read('auth_token');
      _cachedRefreshToken = await read('refresh_token');
      _cachedUserId = await read('user_id');
      _cachedUserPhone = await read('user_phone');
      _cachedUserEmail = await read('user_email');
      _cachedUserName = await read('user_name');
      _cachedUserRole = await read('user_role');

      final raw = await read('user_data');
      if (raw != null && raw.isNotEmpty) {
        try {
          _cachedUserData = Map<String, String>.from(
            (jsonDecode(raw) as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          );
        } catch (e) { LoggerService.error('SecureStorageService: silent catch', e);
          _cachedUserData = null;
        }
      }

      _isCacheLoaded = true;
    } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
  }

  /// Invalidate the cache. Call on logout or when user data changes.
  static void invalidateCache() {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;
    _cachedUserPhone = null;
    _cachedUserEmail = null;
    _cachedUserName = null;
    _cachedUserRole = null;
    _cachedUserData = null;
    _isCacheLoaded = false;
  }

  /// Quick update for new auth token in memory & storage
  static Future<void> saveAuthToken(String token) async {
    _cachedToken = token;
    await write('auth_token', token);
  }

  /// Quick update for refresh token in memory & storage
  static Future<void> saveRefreshToken(String token) async {
    _cachedRefreshToken = token;
    await write('refresh_token', token);
  }

  // ─── Synchronous cache reads (used by the auth interceptor) ───
  static String? get cachedToken => _cachedToken;
  static String? get cachedRefreshToken => _cachedRefreshToken;
  static String? get cachedUserId => _cachedUserId;
  static String? get cachedUserPhone => _cachedUserPhone;
  static String? get cachedUserEmail => _cachedUserEmail;
  static String? get cachedUserName => _cachedUserName;
  static String? get cachedUserRole => _cachedUserRole;
  static Map<String, String>? get cachedUserData => _cachedUserData;

  /// Parse user_data JSON once from cache and extract fields.
  /// Returns a map with keys: id, email, name, role, phone
  static Map<String, String>? getParsedUserData() {
    if (_cachedUserData == null) return null;
    final result = <String, String>{};
    for (final entry in _cachedUserData!.entries) {
      result[entry.key] = entry.value;
    }
    return result;
  }

  // ─── Async reads (still used for initial load, migrations, etc.) ───
  static Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) return value;

      if (_legacyPrefsKeys.contains(key)) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(key);
        if (legacy != null && legacy.isNotEmpty) {
          await _storage.write(key: key, value: legacy);
          await prefs.remove(key);
          return legacy;
        }
      }
    } catch (e) { LoggerService.error('SecureStorageService: silent catch', e);
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
    }
    return null;
  }

  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) { LoggerService.error('SecureStorageService: silent catch', e);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
  }

  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, _) { LoggerService.error('SecureStorageService: silent catch', e); }
  }

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
