import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user.dart';
import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';

/// Holds the currently authenticated user, loaded from SharedPreferences.
/// Stored as a JSON string under the `user_data` key after OTP verification.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_data');
      final token = prefs.getString('auth_token');
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
        print("Failed to register FCM token on startup: $e");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    state = AsyncValue.data(user);

    // Register device FCM push token on login
    try {
      final dio = _ref.read(dioProvider);
      NotificationService().registerDeviceToken(dio);
    } catch (e) {
      print("Failed to register FCM token on login: $e");
    }
  }

  Future<void> updateUser(User user) async {
    await setUser(user);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';
    final userId = prefs.getString('user_id') ?? '';

    // Unsubscribe from customer-specific topics on logout
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
      NotificationService().unsubscribeFromTopic('phone_$cleanPhone');
    }
    if (userId.isNotEmpty) {
      NotificationService().unsubscribeFromTopic('user_$userId');
    }

    await prefs.remove('user_data');
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_phone');
    state = const AsyncValue.data(null);
  }
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
