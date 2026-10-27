import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

/// Provides a permanently persistent device-level guest ID for shopping cart sync
/// and live cart tracking. Caches the ID in memory to eliminate I/O on every request
/// and prevent parallel request race conditions from generating duplicate guest IDs.
class GuestDeviceService {
  static String? _cachedGuestId;

  /// Returns the persistent guest ID for this device.
  static Future<String> getGuestId() async {
    if (_cachedGuestId != null && _cachedGuestId!.isNotEmpty) {
      return _cachedGuestId!;
    }

    try {
      // 1. Check encrypted SecureStorage (survives app cache clearing)
      final secureId = await SecureStorage.read('fastkirana_guest_id');
      if (secureId != null && secureId.trim().isNotEmpty) {
        _cachedGuestId = secureId.trim();
        return _cachedGuestId!;
      }
    } catch (_) {}

    try {
      // 2. Check SharedPreferences fallback
      final prefs = await SharedPreferences.getInstance();
      final prefsId = prefs.getString('fastkirana_guest_id');
      if (prefsId != null && prefsId.trim().isNotEmpty) {
        _cachedGuestId = prefsId.trim();
        try {
          await SecureStorage.write('fastkirana_guest_id', _cachedGuestId!);
        } catch (_) {}
        return _cachedGuestId!;
      }

      // 3. Generate permanently once and store in both storage layers
      final newId = 'g_app_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
      _cachedGuestId = newId;
      await prefs.setString('fastkirana_guest_id', newId);
      try {
        await SecureStorage.write('fastkirana_guest_id', newId);
      } catch (_) {}
      return _cachedGuestId!;
    } catch (_) {
      // Emergency memory fallback
      final fallbackId = 'g_app_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
      _cachedGuestId = fallbackId;
      return fallbackId;
    }
  }

  /// Clears in-memory cache for unit testing
  static void resetForTesting() {
    _cachedGuestId = null;
  }
}
