import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/core/services/secure_storage_service.dart';
import 'package:fastkirana_flutter/data/models/user.dart';
import 'package:fastkirana_flutter/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SecureStorage.invalidateCache();
    });

    tearDown(() {
      SecureStorage.invalidateCache();
    });

    group('_load()', () {
      test('starts with loading state when no stored credentials', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // AuthNotifier._load() reads SecureStorage synchronously from cache
        // which is empty (invalidateCache called in setUp)
        final authState = container.read(authProvider);
        // After _load with no credentials, state should be data(null)
        expect(authState.value, isNull);
        expect(authState.hasError, isFalse);
      });

      test('loads user from SecureStorage when credentials exist', () async {
        // Pre-populate SecureStorage
        await SecureStorage.write('auth_token', 'test_token_123');
        await SecureStorage.write('user_id', 'user_42');
        await SecureStorage.write('user_phone', '+919876543210');
        await SecureStorage.write('user_email', 'test@test.com');
        await SecureStorage.write('user_name', 'Test User');
        await SecureStorage.write('user_role', 'USER');
        final userJson = '{"id":"user-42","name":"Test User","email":"test@test.com","role":"USER","phone":"+919876543210"}';
        await SecureStorage.write('user_data', userJson);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read once to instantiate AuthNotifier and start _load()
        container.read(authProvider);

        // Wait for async _load to complete
        await Future.delayed(const Duration(milliseconds: 100));

        final authState = container.read(authProvider);
        expect(authState.value, isNotNull);
        expect(authState.value!.id, 'user-42');
        expect(authState.value!.name, 'Test User');
        expect(authState.value!.email, 'test@test.com');
        expect(authState.value!.role, 'USER');
      });

      test('loadCache populates in-memory fields after reading from SecureStorage', () async {
        await SecureStorage.write('auth_token', 'tok_abc');
        await SecureStorage.write('user_id', 'uid_1');
        await SecureStorage.write('user_role', 'ADMIN');
        await SecureStorage.loadCache();

        expect(SecureStorage.cachedToken, 'tok_abc');
        expect(SecureStorage.cachedUserId, 'uid_1');
        expect(SecureStorage.cachedUserRole, 'ADMIN');
      });
    });

    group('setUser()', () {
      test('writes user data to SecureStorage', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final user = User(
          id: 'user-99',
          name: 'Alice',
          email: 'alice@test.com',
          phone: '+919876543210',
          role: 'USER',
        );

        // Simulate existing auth_token in SharedPreferences (legacy migration scenario)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'legacy_token');

        // setUser is async — call it directly via the notifier
        final notifier = container.read(authProvider.notifier);
        await notifier.setUser(user);

        // Verify user was set in state
        final state = container.read(authProvider);
        expect(state.value, isNotNull);
        expect(state.value!.id, 'user-99');
        expect(state.value!.name, 'Alice');

        // Verify data persisted to SecureStorage
        final storedData = await SecureStorage.read('user_data');
        expect(storedData, isNotNull);
        expect(storedData, contains('alice@test.com'));

        // Verify legacy token was migrated to SecureStorage
        final storedToken = await SecureStorage.read('auth_token');
        expect(storedToken, 'legacy_token');
      });

      test('does not fail when SharedPreferences has no legacy token', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final user = User(
          id: 'user-100',
          name: 'Bob',
          email: 'bob@test.com',
          role: 'USER',
        );

        final notifier = container.read(authProvider.notifier);
        await notifier.setUser(user);

        final state = container.read(authProvider);
        expect(state.value!.id, 'user-100');
        expect(state.value!.name, 'Bob');
      });
    });

    group('clear()', () {
      test('invalidateCache clears all auth fields', () async {
        await SecureStorage.write('auth_token', 'tok_xyz');
        await SecureStorage.write('user_id', 'uid_xyz');
        await SecureStorage.write('user_phone', '+911234567890');
        await SecureStorage.write('user_email', 'x@y.com');
        await SecureStorage.write('user_name', 'X');
        await SecureStorage.write('user_role', 'USER');
        await SecureStorage.loadCache();

        expect(SecureStorage.cachedToken, 'tok_xyz');

        SecureStorage.invalidateCache();

        expect(SecureStorage.cachedToken, isNull);
        expect(SecureStorage.cachedUserId, isNull);
        expect(SecureStorage.cachedUserEmail, isNull);
        expect(SecureStorage.cachedUserRole, isNull);
        expect(SecureStorage.isCacheLoaded, isFalse);
      });
    });

    group('currentUserIdProvider / currentUserProvider', () {
      test('returns null when not authenticated', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(currentUserIdProvider), isNull);
        expect(container.read(currentUserProvider), isNull);
      });
    });
  });
}
