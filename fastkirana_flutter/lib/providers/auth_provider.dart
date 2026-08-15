import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user.dart';

/// Holds the currently authenticated user, loaded from SharedPreferences.
/// Stored as a JSON string under the `user_data` key after OTP verification.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    state = AsyncValue.data(user);
  }

  Future<void> updateUser(User user) async {
    await setUser(user);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('auth_token');
    state = const AsyncValue.data(null);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
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
