import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late CartRepository cartRepo;
  bool shouldNetworkFail = false;
  int syncCallCount = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shouldNetworkFail = false;
    syncCallCount = 0;

    mockDio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    mockDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (shouldNetworkFail) {
          return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'No Internet Connection',
          ));
        }

        if (options.path == '/api/cart' && options.method == 'POST') {
          syncCallCount++;
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
    final product = makeTestProduct('p101', 'Basmati Rice', 120);

    // Simulate network cut
    shouldNetworkFail = true;

    // Add item while offline
    final added = notifier.addProduct(product, 2);
    expect(added, isTrue);
    await pumpEventQueue();

    // Verify UI state has the item immediately (optimistic UI)
    expect(notifier.getQuantity('p101'), equals(2));

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
    final product = makeTestProduct('p102', 'Tata Salt', 25);

    // 1. User performs action while offline
    shouldNetworkFail = true;
    notifier.addProduct(product, 3);
    await pumpEventQueue();
    expect(await cartRepo.hasPendingSync(), isTrue);
    expect(syncCallCount, equals(0));

    // 2. Network is restored (reconnection)
    shouldNetworkFail = false;

    // 3. Auto-sync trigger executes
    await notifier.syncPendingCart();
    await pumpEventQueue();

    // 4. Verify server was called and pending flag is cleared
    expect(syncCallCount, equals(1));
    expect(await cartRepo.hasPendingSync(), isFalse);
  });
}
