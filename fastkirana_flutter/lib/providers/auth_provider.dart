import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/secure_storage_service.dart';
import '../data/repositories/address_repository.dart';
import '../data/repositories/order_repository.dart';
import 'address_provider.dart';
import 'cart_provider.dart';
import '../features/orders/orders_screen.dart';

/// Holds the currently authenticated user, loaded from SharedPreferences.
/// Stored as a JSON string under the `user_data` key after OTP verification.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await SecureStorage.read('user_data');
      final token = await SecureStorage.read('auth_token');
      if (raw == null || token == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = AsyncValue.data(User.fromJson(json));

      // Register device FCM push token on startup
      try {
        final dio = _ref.read(dioProvider);
        NotificationService().registerDeviceToken(dio);
      } catch (e) {
        LoggerService.error("Failed to register FCM token on startup: $e");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setUser(User user) async {
    // Write user data ONLY to SecureStorage (the durable encrypted store).
    // SharedPreferences is legacy -- no longer needed and creates split-brain risk
    // if one write succeeds and the other fails.
    await SecureStorage.write('user_data', jsonEncode(user.toJson()));
    final prefs = await SharedPreferences.getInstance();
    final existingToken = prefs.getString('auth_token') ?? '';
    if (existingToken.isNotEmpty) {
      await SecureStorage.write('auth_token', existingToken);
    }
    await SecureStorage.write('user_id', user.id);
    if (user.phone != null && user.phone!.isNotEmpty) await SecureStorage.write('user_phone', user.phone!);
    if (user.email.isNotEmpty) await SecureStorage.write('user_email', user.email);
    if (user.name != null && user.name!.isNotEmpty) await SecureStorage.write('user_name', user.name!);
    if (user.role.isNotEmpty) await SecureStorage.write('user_role', user.role);
    await SecureStorage.loadCache();
    state = AsyncValue.data(user);

    // Register device FCM push token on login
    try {
      final dio = _ref.read(dioProvider);
      NotificationService().registerDeviceToken(dio);
    } catch (e) {
      LoggerService.error("Failed to register FCM token on login: $e");
    }
  }

  Future<void> updateUser(User user) async {
    await setUser(user);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '';
    final userId = prefs.getString('user_id') ?? '';

    // 1. Unsubscribe from customer-specific topics on logout
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
      NotificationService().unsubscribeFromTopic('phone_$cleanPhone');
    }
    if (userId.isNotEmpty) {
      NotificationService().unsubscribeFromTopic('user_$userId');
    }

    // 2. Clear all active push notifications from Android notification tray
    await NotificationService().clearAllNotifications();

    // 3. Clear all cached addresses and orders from disk
    await AddressRepository.clearCache();
    await OrderRepository.clearCache();

    // 4. Wipe all user-scoped and session keys from SharedPreferences
    final allKeys = prefs.getKeys().toList();
    for (final key in allKeys) {
      if (key.startsWith('user_') ||
          key.startsWith('auth_') ||
          key.startsWith('cart_') ||
          key.startsWith('local_restaurant_') ||
          key.startsWith('cached_admin_') ||
          key == 'has_chosen_location' ||
          key == 'selected_address' ||
          key == 'pending_cart_sync' ||
          key == 'offline_location_queue') {
        await prefs.remove(key);
      }
    }

    // 5. Delete all secure credentials
    await SecureStorage.deleteAll();
    SecureStorage.invalidateCache();

    // 6. Reset in-memory Riverpod providers so old data does not leak into other accounts
    try {
      _ref.read(addressesProvider.notifier).clear();
      _ref.invalidate(addressesProvider);
      _ref.read(selectedAddressProvider.notifier).state = null;
      await _ref.read(cartProvider.notifier).clearCart();
      _ref.invalidate(ordersProvider);
    } catch (e) {
      LoggerService.error('AuthProvider: error clearing state on logout', e);
    }

    state = const AsyncValue.data(null);
  }

  /// Alias for clear() to maintain standard naming across dashboards
  Future<void> logout() => clear();
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

/// Convenience: returns user id synchronously when available, otherwise null.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  return auth.maybeWhen(
    data: (user) => user?.id,
    orElse: () => null,
  );
});

/// Convenience: returns current user or null.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});
