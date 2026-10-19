import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastminute_flutter/core/network/api_client.dart';
import 'package:fastminute_flutter/core/utils/app_connectivity.dart';
import 'package:fastminute_flutter/data/models/cart.dart';
import 'package:fastminute_flutter/features/checkout/controllers/checkout_controller.dart';
import 'offline_experience_test.dart' show TestConnection;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Checkout immediately halts without pending probe when offline and displays guidance',
      (tester) async {
    final connection = TestConnection()..online = false;
    final client = Dio();
    var requests = 0;
    client.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests++;
      handler.reject(DioException(requestOptions: request));
    }));
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => connection),
          dioProvider.overrideWithValue(client),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          ref.watch(checkoutControllerProvider);
          return Scaffold(
              body: TextButton(
                  onPressed: () {
                    ref
                        .read(checkoutControllerProvider.notifier)
                        .handlePlaceOrder(context, cart: Cart.empty());
                  },
                  child: const Text('Place order')));
        }))));

    await tester.tap(find.text('Place order'));
    await tester.pump();

    // Fast transport guard rejects immediately without waiting for slow probe
    expect(container.read(checkoutControllerProvider).isPlacingOrder, isFalse);
    expect(requests, 0);
    expect(
        find.text(
            'Connect to the internet to confirm prices and place your order.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Checkout guards against duplicate taps during in-flight network request and resets busy state',
      (tester) async {
    final connection = TestConnection()..online = true;
    final client = Dio();
    var orderRequests = 0;
    final holdRequest = Completer<Response>();

    client.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path.contains('/api/orders')) {
        orderRequests++;
        try {
          final res = await holdRequest.future;
          handler.resolve(res);
        } catch (err) {
          handler.reject(DioException(requestOptions: request, error: err));
        }
      } else {
        handler.resolve(Response(
          requestOptions: request,
          statusCode: 200,
          data: <String, dynamic>{},
        ));
      }
    }));

    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => connection),
          dioProvider.overrideWithValue(client),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          ref.watch(checkoutControllerProvider);
          return Scaffold(
              body: TextButton(
                  onPressed: () {
                    ref.read(checkoutControllerProvider.notifier).setDeliveryMethod('PICKUP');
                    ref
                        .read(checkoutControllerProvider.notifier)
                        .handlePlaceOrder(context, cart: Cart.empty());
                  },
                  child: const Text('Place order')));
        }))));

    await tester.tap(find.text('Place order'));
    // Advance frames so async preparation reaches the in-flight order POST
    await tester.pump(const Duration(milliseconds: 50));

    // Order request is in-flight
    expect(container.read(checkoutControllerProvider).isPlacingOrder, isTrue);
    expect(orderRequests, 1);

    // Duplicate tap while order is in flight must be ignored
    await tester.tap(find.text('Place order'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(orderRequests, 1);

    // Complete with error to test recovery
    holdRequest.completeError('Network failed');
    await tester.pumpAndSettle();

    // Busy flag properly cleared after failure
    expect(container.read(checkoutControllerProvider).isPlacingOrder, isFalse);
    expect(tester.takeException(), isNull);
  });
}
