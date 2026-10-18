import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/features/checkout/widgets/checkout_bottom_bar.dart';

void main() {
  testWidgets('CheckoutBottomBar renders inline offline banner and triggers retry without SnackBar', (tester) async {
    var proceedTaps = 0;
    var retryTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: CheckoutBottomBar(
            grandTotal: 691.0,
            isPlacingOrder: false,
            isOffline: true,
            isCheckingConnection: false,
            onProceedToPay: () => proceedTaps++,
            onRetryConnection: () => retryTaps++,
          ),
        ),
      ),
    );

    // Verify inline banner exists cleanly
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Connect to internet to place order'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Check Connection & Pay'), findsOneWidget);
    expect(find.text('TOTAL BILL'), findsOneWidget);
    expect(find.text('₹691'), findsOneWidget);

    // Verify tapping Retry triggers retry callback
    await tester.tap(find.text('Retry'));
    expect(retryTaps, 1);
    expect(proceedTaps, 0);

    // Verify tapping the main offline button triggers retry callback and does NOT show SnackBar
    await tester.tap(find.text('Check Connection & Pay'));
    expect(retryTaps, 2);
    expect(proceedTaps, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('CheckoutBottomBar online state renders Proceed to Pay and no offline banner', (tester) async {
    var proceedTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: CheckoutBottomBar(
            grandTotal: 691.0,
            isPlacingOrder: false,
            isOffline: false,
            onProceedToPay: () => proceedTaps++,
          ),
        ),
      ),
    );

    expect(find.text('You are offline'), findsNothing);
    expect(find.text('Proceed to Pay'), findsOneWidget);

    await tester.tap(find.text('Proceed to Pay'));
    expect(proceedTaps, 1);
  });
}
