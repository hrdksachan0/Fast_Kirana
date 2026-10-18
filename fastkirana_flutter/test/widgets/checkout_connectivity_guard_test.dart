import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/core/network/api_client.dart';
import 'package:fastminute_flutter/core/utils/app_connectivity.dart';
import 'package:fastminute_flutter/data/models/cart.dart';
import 'package:fastminute_flutter/features/checkout/controllers/checkout_controller.dart';
import 'offline_experience_test.dart' show TestConnection;

class PendingConnection extends TestConnection {
  final response = Completer<bool>();
  int checks = 0;
  @override
  Future<bool> checkConnection() {
    checks++;
    return response.future;
  }
}

void main() {
  testWidgets(
      'Checkout waits for API verification, ignores duplicate taps, and stops before payment when unreachable',
      (tester) async {
    final connection = PendingConnection();
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
    expect(container.read(checkoutControllerProvider).isPlacingOrder, isTrue);
    await tester.tap(find.text('Place order'));
    expect(connection.checks, 1);
    expect(requests, 0);
    connection.response.complete(false);
    await tester.pumpAndSettle();
    expect(container.read(checkoutControllerProvider).isPlacingOrder, isFalse);
    expect(
        find.text(
            'Connect to the internet to confirm prices and place your order.'),
        findsOneWidget);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });
}
