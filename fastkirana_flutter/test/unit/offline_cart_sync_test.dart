import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:fastminute_flutter/data/models/product.dart';
import 'package:fastminute_flutter/data/models/cart.dart';
import 'package:fastminute_flutter/data/repositories/cart_repository.dart';
import 'package:fastminute_flutter/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late CartRepository cartRepo;
  bool shouldNetworkFail = false;
  int syncCallCount = 0;
  void Function(DioException error)? onNetworkRejected;
  void Function(RequestOptions options)? onNetworkRequest;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shouldNetworkFail = false;
    syncCallCount = 0;
    onNetworkRejected = null;
    onNetworkRequest = null;

    mockDio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    mockDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (shouldNetworkFail) {
          final err = DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'No Internet Connection',
          );
          onNetworkRejected?.call(err);
          return handler.reject(err);
        }

        if (options.path == '/api/cart' && options.method == 'POST') {
          syncCallCount++;
          onNetworkRequest?.call(options);
          return handler.resolve(Response(
            data: {'success': true},
            requestOptions: options,
            statusCode: 200,
          ));
        }

        return handler.next(options);
      },
    ));

    cartRepo = CartRepository(mockDio);
    addTearDown(() => mockDio.close(force: true));
  });

  Product makeTestProduct(String id, String name, double price) {
    return Product(
      id: id,
      name: name,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      categoryId: 'grocery',
      mrp: price + 20,
      price: price,
      discount: 10,
      unit: '1 kg',
      stock: 50,
      isAvailable: true,
      tags: const ['staples'],
      minStock: 2,
      costPrice: price - 10,
      isFlashDeal: false,
      isTopPick: false,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    );
  }

  test('Offline Mode: saves cart locally and marks pending sync flag when network is down', () async {
    final notifier = CartNotifier(cartRepo);
    addTearDown(() => notifier.dispose());
    final product = makeTestProduct('p101', 'Basmati Rice', 120);

    final offlineAttemptCompleter = Completer<void>();
    onNetworkRejected = (_) {
      if (!offlineAttemptCompleter.isCompleted) {
        offlineAttemptCompleter.complete();
      }
    };

    // Simulate network cut
    shouldNetworkFail = true;

    // Add item while offline
    final added = notifier.addProduct(product, 2);
    expect(added, isTrue);

    // Verify UI state has the item immediately (optimistic UI)
    expect(notifier.getQuantity('p101'), equals(2));

    // Await deterministic offline attempt rejection
    await offlineAttemptCompleter.future;
    await pumpEventQueue();

    // Verify item was persisted to local storage
    final localItems = await cartRepo.getLocalCart();
    expect(localItems.length, equals(1));
    expect(localItems.first.productId, equals('p101'));
    expect(localItems.first.quantity, equals(2));

    // Verify pending sync flag is TRUE
    final isPending = await cartRepo.hasPendingSync();
    expect(isPending, isTrue);
  });

  test('Online Recovery: syncPendingCart flushes local cart to server and clears pending flag', () async {
    final notifier = CartNotifier(cartRepo);
    addTearDown(() => notifier.dispose());
    final product = makeTestProduct('p102', 'Tata Salt', 25);

    // 1. User performs action while offline: wait for explicit offline attempt completion
    final offlineAttemptCompleter = Completer<void>();
    onNetworkRejected = (_) {
      if (!offlineAttemptCompleter.isCompleted) {
        offlineAttemptCompleter.complete();
      }
    };

    shouldNetworkFail = true;
    notifier.addProduct(product, 3);

    // Deterministically await the offline attempt failure signal rather than an elapsed duration
    await offlineAttemptCompleter.future;
    await pumpEventQueue();

    expect(await cartRepo.hasPendingSync(), isTrue);
    expect(syncCallCount, equals(0));

    // 2. Network is restored (reconnection)
    shouldNetworkFail = false;

    // 3. Auto-sync trigger executes: await explicit completion of server POST
    final onlineSyncCompleter = Completer<void>();
    onNetworkRequest = (_) {
      if (!onlineSyncCompleter.isCompleted) {
        onlineSyncCompleter.complete();
      }
    };

    await notifier.syncPendingCart();
    await onlineSyncCompleter.future;
    await pumpEventQueue();

    // 4. Verify server was called exactly once and pending flag is cleared
    expect(syncCallCount, equals(1));
    expect(await cartRepo.hasPendingSync(), isFalse);
  });

  test('Restart Resilience: loadCart reconciles pending offline edits without stale server overwrite', () async {
    final product = makeTestProduct('p103', 'Aashirvaad Atta', 240);
    final offlineItem = CartItem(
      id: 'item_p103',
      cartId: 'cart_active',
      productId: 'p103',
      product: product,
      quantity: 5,
    );

    // Save offline items and mark pending sync = true
    await cartRepo.saveLocalCart([offlineItem], isDirty: true);
    await cartRepo.setPendingSync(true);

    // Restart application: instantiate fresh notifier
    shouldNetworkFail = false;
    final restartedNotifier = CartNotifier(cartRepo);
    addTearDown(() => restartedNotifier.dispose());
    await Future.delayed(const Duration(milliseconds: 200));

    // Verify local quantity 5 was preserved and not overwritten
    expect(restartedNotifier.getQuantity('p103'), equals(5));
    // Verify sync to server was attempted to reconcile
    expect(syncCallCount, greaterThanOrEqualTo(1));
  });

  test('Atomic Cart Delta Persistence: cart envelope commits appliedOrderDeltas atomically with remaining items', () async {
    final product = makeTestProduct('p104', 'Sugar', 45);
    final notifier = CartNotifier(cartRepo);
    addTearDown(() => notifier.dispose());
    notifier.addProduct(product, 3);
    await Future.delayed(const Duration(milliseconds: 350));
    expect(notifier.getQuantity('p104'), equals(3));

    // Remove 1 unit with orderId marker
    const testOrderId = 'ord_atomic_recheck_999';
    await notifier.removeDraftItems([
      {'productId': 'p104', 'quantity': 1}
    ], orderId: testOrderId);

    // Verify in-memory quantity is 2
    expect(notifier.getQuantity('p104'), equals(2));

    // Verify appliedOrderDeltas contains the orderId from the cart envelope
    final appliedDeltas = await cartRepo.getAppliedOrderDeltas();
    expect(appliedDeltas.contains(testOrderId), isTrue);

    // Verify on fresh restart reading saved storage that appliedOrderDeltas is preserved
    final restartedRepo = CartRepository(mockDio);
    final restartedDeltas = await restartedRepo.getAppliedOrderDeltas();
    expect(restartedDeltas.contains(testOrderId), isTrue);

    final restartedItems = await restartedRepo.getLocalCart();
    expect(restartedItems.length, equals(1));
    expect(restartedItems.first.quantity, equals(2));
  });

  for (final throws in [false, true]) {
    test('Rejected combined save rollback and retry (throws=$throws)', () async {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = OneShotCombinedFailStore(throws);

      final repo = CartRepository(mockDio);
      final notifier = CartNotifier(repo);
      addTearDown(() => notifier.dispose());
      final product = makeTestProduct('p105', 'Atta', 60);

      // Start cart 3
      notifier.addProduct(product, 3);
      await Future.delayed(const Duration(milliseconds: 350));
      expect(notifier.getQuantity('p105'), equals(3));
      final initialDisk = await repo.getLocalCart();
      expect(initialDisk.first.quantity, equals(3));

      // Arm failure for the combined checkout write
      final store = SharedPreferencesStorePlatform.instance as OneShotCombinedFailStore;
      store.arm();

      // Purchase 1, attempting combined cart write which will fail once
      final orderId = 'order_reject_test_${throws ? "throw" : "false"}';
      var threw = false;
      try {
        await notifier.removeDraftItems([
          {'productId': 'p105', 'quantity': 1}
        ], orderId: orderId);
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);

      // After failure: UI and disk must remain 3
      expect(notifier.getQuantity('p105'), equals(3));
      final diskAfterFailure = await repo.getLocalCart();
      expect(diskAfterFailure.first.quantity, equals(3));

      // Applied-order lookup must NOT report the attempt as committed
      final deltasAfterFailure = await repo.getAppliedOrderDeltas();
      expect(deltasAfterFailure.contains(orderId), isFalse);

      // Retry the same order in the same process without explicit preferences reload
      await notifier.removeDraftItems([
        {'productId': 'p105', 'quantity': 1}
      ], orderId: orderId);

      // Require UI/disk 2
      expect(notifier.getQuantity('p105'), equals(2));
      final diskAfterRetry = await repo.getLocalCart();
      expect(diskAfterRetry.first.quantity, equals(2));
      final deltasAfterRetry = await repo.getAppliedOrderDeltas();
      expect(deltasAfterRetry.contains(orderId), isTrue);

      // Restart / replay and require 2 again
      final restartedRepo = CartRepository(mockDio);
      final restartedDisk = await restartedRepo.getLocalCart();
      expect(restartedDisk.first.quantity, equals(2));
      final restartedDeltas = await restartedRepo.getAppliedOrderDeltas();
      expect(restartedDeltas.contains(orderId), isTrue);
    });
  }

  test('Canonical ID preservation: item_123 retains its exact canonical catalog ID when syncing', () async {
    Map<String, dynamic>? lastSyncedPayload;
    final testDio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    testDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/api/cart' && options.method == 'POST') {
          lastSyncedPayload = options.data as Map<String, dynamic>;
          return handler.resolve(Response(
            data: {'success': true},
            requestOptions: options,
            statusCode: 200,
          ));
        }
        return handler.next(options);
      },
    ));

    final repo = CartRepository(testDio);
    final product = makeTestProduct('item_123', 'Catalog Item With Prefix', 99);
    final cartItem = CartItem(
      id: 'cart_item_row_1',
      cartId: 'cart_active',
      productId: 'item_123',
      product: product,
      quantity: 1,
    );

    await repo.syncCart([cartItem]);

    expect(lastSyncedPayload, isNotNull);
    final items = lastSyncedPayload!['items'] as List;
    expect(items.length, equals(1));
    expect(items.first['productId'], equals('item_123'));
  });
}

class OneShotCombinedFailStore extends InMemorySharedPreferencesStore {
  final bool throws;
  bool _armed = false;
  bool _failed = false;
  OneShotCombinedFailStore(this.throws) : super.withData({});

  void arm() => _armed = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_armed && key.contains('local_cart') && !_failed) {
      _failed = true;
      if (throws) throw StateError('Injected platform storage write failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}


