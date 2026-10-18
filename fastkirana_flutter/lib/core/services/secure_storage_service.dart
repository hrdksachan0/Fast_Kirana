import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastminute_flutter/core/services/logger_service.dart';
import '../../data/models/user_session.dart';

/// Secure storage wrapper for sensitive data (auth tokens, user credentials).
///
/// Authentication credentials (auth_token, refresh_token) are stored strictly
/// in encrypted FlutterSecureStorage. Plaintext SharedPreferences is never used
/// for new credentials. Existing legacy preferences are safely migrated and deleted.
class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _sensitiveKeys = <String>{
    'auth_token',
    'refresh_token',
  };

  static const _legacyPrefsKeys = <String>{
    'auth_token',
    'refresh_token',
    'user_data',
    'user_id',
    'user_phone',
    'user_email',
    'user_name',
    'user_role',
    'assigned_restaurant_id',
    'assigned_store_id',
    'fcm_token',
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

  /// Load all auth fields into the in-memory cache.
  /// Always reads sensitive tokens via encrypted secure storage with safe legacy migration.
  static Future<void> loadCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Sensitive credentials must be read from secure storage (migrating legacy prefs if present)
      _cachedToken = await read('auth_token');
      _cachedRefreshToken = await read('refresh_token');

      // Non-sensitive profile metadata
      _cachedUserId = await read('user_id') ?? prefs.getString('user_id');
      _cachedUserPhone = await read('user_phone') ?? prefs.getString('user_phone');
      _cachedUserEmail = await read('user_email') ?? prefs.getString('user_email');
      _cachedUserName = await read('user_name') ?? prefs.getString('user_name');
      _cachedUserRole = await read('user_role') ?? prefs.getString('user_role');

      final raw = await read('user_data') ?? prefs.getString('user_data');
      if (raw != null && raw.isNotEmpty) {
        try {
          _cachedUserData = Map<String, String>.from(
            (jsonDecode(raw) as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          );
          _cachedUserId ??= _cachedUserData?['id'];
          _cachedUserRole ??= _cachedUserData?['role'];
          _cachedUserPhone ??= _cachedUserData?['phone'];
          _cachedUserEmail ??= _cachedUserData?['email'];
          _cachedUserName ??= _cachedUserData?['name'];
        } catch (e) {
          LoggerService.error('SecureStorageService: loadCache parse user_data', e);
          _cachedUserData = null;
        }
      }

      _isCacheLoaded = true;
    } catch (e, _) {
      LoggerService.error('SecureStorageService: loadCache', e);
    }
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
    await write('auth_token', token);
    _cachedToken = token;
  }

  /// Quick update for refresh token in memory & storage
  static Future<void> saveRefreshToken(String token) async {
    await write('refresh_token', token);
    _cachedRefreshToken = token;
  }

  /// Save FCM device token for push notifications
  static Future<void> saveFcmToken(String token) async {
    if (token.isEmpty) return;
    await write('fcm_token', token);
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

  /// Returns strongly-typed user session from in-memory cache
  static UserSession? get cachedUserSession {
    final id = _cachedUserId;
    if (id == null || id.isEmpty) return null;
    return UserSession(
      id: id,
      name: _cachedUserName,
      email: _cachedUserEmail,
      phone: _cachedUserPhone,
      role: _cachedUserRole ?? 'USER',
    );
  }

  /// Save or update user session in memory & persisted storage
  static Future<void> saveUserSession(UserSession session) async {
    final map = {
      'id': session.id,
      if (session.name != null) 'name': session.name!,
      if (session.email != null) 'email': session.email!,
      if (session.phone != null) 'phone': session.phone!,
      'role': session.role,
    };

    // Save session metadata
    await write('user_id', session.id);
    if (session.name != null) await write('user_name', session.name!);
    if (session.email != null) await write('user_email', session.email!);
    if (session.phone != null) await write('user_phone', session.phone!);
    await write('user_role', session.role);
    await write('user_data', jsonEncode(map));

    _cachedUserId = session.id;
    _cachedUserName = session.name;
    _cachedUserEmail = session.email;
    _cachedUserPhone = session.phone;
    _cachedUserRole = session.role;
    _cachedUserData = map;
    _isCacheLoaded = true;
  }

  /// Parse user_data JSON once from cache and extract fields.
  static Map<String, String>? getParsedUserData() {
    if (_cachedUserData == null) return null;
    final result = <String, String>{};
    for (final entry in _cachedUserData!.entries) {
      result[entry.key] = entry.value;
    }
    return result;
  }

  // ─── Async reads with safe one-time migration ───
  static Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) {
        // If encrypted storage has the value and a legacy plaintext copy exists in prefs, purge it
        if (_sensitiveKeys.contains(key)) {
          try {
            final prefs = await SharedPreferences.getInstance();
            if (prefs.containsKey(key)) {
              await prefs.remove(key);
            }
          } catch (_) {}
        }
        return value;
      }
    } catch (e) {
      LoggerService.error('SecureStorageService: read storage failed, checking migration', e);
    }

    // Migration fallback: If key exists in legacy SharedPreferences, migrate to encrypted storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyValue = prefs.getString(key);
      if (legacyValue != null && legacyValue.isNotEmpty) {
        try {
          await _storage.write(key: key, value: legacyValue);
          final readback = await _storage.read(key: key);
          if (readback == legacyValue) {
            // Write to encrypted storage verified; purge legacy plaintext copy
            await prefs.remove(key);
            return legacyValue;
          }
        } catch (e) {
          LoggerService.error('SecureStorageService: migration write verification failed', e);
        }
        // Fail-closed migration policy: do not return unverified plaintext credentials
        LoggerService.error('SecureStorageService: migration verification failed, failing closed for $key', null);
        return null;
      }
    } catch (e, _) {
      LoggerService.error('SecureStorageService: migration read fallback error', e);
    }
    return null;
  }

  /// Write a key-value pair.
  /// Sensitive keys ('auth_token', 'refresh_token') are written EXCLUSIVELY to encrypted storage
  /// and verified with readback. They are NEVER written to ordinary SharedPreferences.
  static Future<void> write(String key, String value) async {
    final isSensitive = _sensitiveKeys.contains(key);

    if (isSensitive) {
      // 1. Write exclusively to encrypted storage
      await _storage.write(key: key, value: value);

      // 2. Verify write succeeded with readback
      final verified = await _storage.read(key: key);
      if (verified != value) {
        throw Exception('Secure storage write verification failed for $key');
      }

      // 3. Purge any legacy plaintext copy from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      } catch (_) {}

      // 4. Update in-memory caches ONLY after verified persistence
      if (key == 'auth_token') _cachedToken = value;
      if (key == 'refresh_token') _cachedRefreshToken = value;
    } else {
      // Non-sensitive metadata (user name, phone, etc.) can be persisted in both
      try {
        await _storage.write(key: key, value: value);
      } catch (e) {
        LoggerService.error('SecureStorageService: metadata secure write', e);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {}

      if (key == 'user_id') _cachedUserId = value;
      if (key == 'user_phone') _cachedUserPhone = value;
      if (key == 'user_email') _cachedUserEmail = value;
      if (key == 'user_name') _cachedUserName = value;
      if (key == 'user_role') _cachedUserRole = value;
    }
  }

  static Future<void> delete(String key) async {
    if (key == 'auth_token') _cachedToken = null;
    if (key == 'refresh_token') _cachedRefreshToken = null;
    if (key == 'user_id') _cachedUserId = null;
    if (key == 'user_phone') _cachedUserPhone = null;
    if (key == 'user_email') _cachedUserEmail = null;
    if (key == 'user_name') _cachedUserName = null;
    if (key == 'user_role') _cachedUserRole = null;
    if (key == 'user_data') _cachedUserData = null;

    try {
      await _storage.delete(key: key);
    } catch (e, _) {
      LoggerService.error('SecureStorageService: delete', e);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e, _) {
      LoggerService.error('SecureStorageService: delete fallback', e);
    }
  }

  static Future<void> deleteAll() async {
    invalidateCache();
    try {
      for (final key in _legacyPrefsKeys) {
        await _storage.delete(key: key);
      }
      await _storage.deleteAll();
    } catch (e, _) {
      LoggerService.error('SecureStorageService: deleteAll', e);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _legacyPrefsKeys) {
        await prefs.remove(key);
      }
    } catch (e, _) {
      LoggerService.error('SecureStorageService: deleteAll fallback', e);
    }
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

  static Future<String?> getAuthToken() async {
    return _cachedToken ?? await read('auth_token');
  }

  static Future<void> setAuthToken(String token) async {
    await write('auth_token', token);
  }

  static Future<String?> getRefreshToken() async {
    return _cachedRefreshToken ?? await read('refresh_token');
  }

  static Future<void> setRefreshToken(String token) async {
    await write('refresh_token', token);
  }
}

/// Service instance interface for dependency-injected or instance-based consumers
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  Future<String?> getAuthToken() => SecureStorage.getAuthToken();
  Future<void> setAuthToken(String token) => SecureStorage.setAuthToken(token);
  Future<String?> getRefreshToken() => SecureStorage.getRefreshToken();
  Future<void> setRefreshToken(String token) => SecureStorage.setRefreshToken(token);
  Future<String?> read(String key) => SecureStorage.read(key);
  Future<void> write(String key, String value) => SecureStorage.write(key, value);
  Future<void> delete(String key) => SecureStorage.delete(key);
  Future<void> deleteAll() => SecureStorage.deleteAll();
}
