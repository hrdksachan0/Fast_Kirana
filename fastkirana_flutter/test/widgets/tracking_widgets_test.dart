import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/order.dart';
import 'package:fastkirana_flutter/features/orders/widgets/tracking_status_stepper.dart';
import 'package:fastkirana_flutter/features/orders/widgets/tracking_receipt_card.dart';
import 'package:fastkirana_flutter/features/orders/widgets/tracking_payment_card.dart';
import 'package:fastkirana_flutter/features/delivery/widgets/connectivity_banner.dart';

void main() {
  group('Order Tracking & Delivery Widgets', () {
    final sampleOrder = Order(
      id: 'ord-12345',
      readableId: 'FK-8901',
      userId: 'usr-1',
      addressId: 'addr-1',
      status: OrderStatus.shipped,
      subtotal: 350.0,
      discount: 50.0,
      deliveryFee: 25.0,
      taxes: 15.0,
      miscFee: 5.0,
      total: 345.0,
      paymentMethod: PaymentMethod.cod,
      paymentStatus: 'PENDING',
      createdAt: DateTime.now(),
      items: [
        OrderItem(
          id: 'item-1',
          name: 'Amul Taaza Milk 500ml',
          quantity: 2,
          price: 27.0,
        ),
        OrderItem(
          id: 'item-2',
          name: 'Modern Bread Large',
          quantity: 1,
          price: 45.0,
        ),
      ],
    );

    testWidgets('TrackingStatusStepper renders active progress and ETA', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingStatusStepper(
                order: sampleOrder,
                statusStep: 2,
                isDelivered: false,
                isCancelled: false,
                cleanDisplayId: 'FK-8901',
                etaText: '12 mins',
                distanceText: '1.2 km away',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Live Order Status'), findsOneWidget);
      expect(find.textContaining('12 mins'), findsOneWidget);
      expect(find.textContaining('1.2 km'), findsOneWidget);
    });

    testWidgets('TrackingStatusStepper renders cancelled state banner when order is cancelled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingStatusStepper(
                order: sampleOrder,
                statusStep: 0,
                isDelivered: false,
                isCancelled: true,
                cleanDisplayId: 'FK-8901',
                etaText: '',
                distanceText: '',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Live Order Status'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('TrackingReceiptCard renders bill breakdown correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingReceiptCard(order: sampleOrder),
            ),
          ),
        ),
      );

      expect(find.text('Bill Details'), findsOneWidget);
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);
      expect(find.text('Modern Bread Large'), findsOneWidget);
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('Delivery Partner Fee'), findsOneWidget);
      expect(find.text('Handling & Taxes'), findsOneWidget);
      expect(find.text('Total Paid'), findsOneWidget);
      expect(find.textContaining('345'), findsOneWidget);
    });

    testWidgets('TrackingPaymentCard shows Cash on Delivery badge for COD orders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingPaymentCard(
                order: sampleOrder,
                isProcessingPayment: false,
                statusStep: 2,
                onPayOnline: () {},
                onSwitchToCOD: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Order is currently set to Cash on Delivery'), findsOneWidget);
      expect(find.text('Pay ₹345 Online'), findsOneWidget);
    });

    testWidgets('TrackingPaymentCard shows Pay Online button for unpaid online orders', (WidgetTester tester) async {
      final onlineOrder = Order(
        id: 'ord-online-99',
        readableId: 'FK-9900',
        userId: 'usr-1',
        addressId: 'addr-1',
        status: OrderStatus.confirmed,
        subtotal: 200.0,
        discount: 0.0,
        deliveryFee: 25.0,
        taxes: 10.0,
        miscFee: 5.0,
        total: 240.0,
        paymentMethod: PaymentMethod.upi,
        paymentStatus: 'PENDING',
        createdAt: DateTime.now(),
      );

      bool payOnlineTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingPaymentCard(
                order: onlineOrder,
                isProcessingPayment: false,
                statusStep: 0,
                onPayOnline: () => payOnlineTapped = true,
                onSwitchToCOD: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('PAYMENT PENDING'), findsOneWidget);
      expect(find.text('Pay Online Now'), findsOneWidget);
      await tester.tap(find.text('Pay Online Now'));
      await tester.pump();
      expect(payOnlineTapped, isTrue);
    });

    testWidgets('ConnectivityBanner displays offline warning with pending count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectivityBanner(
              isOffline: true,
              pendingCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('No Internet • 3 action(s) saved offline'), findsOneWidget);
    });

    testWidgets('ConnectivityBanner displays pending sync chip when online and triggers onRetry', (WidgetTester tester) async {
      bool tappedSync = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectivityBanner(
              isOffline: false,
              pendingCount: 2,
              onRetry: () => tappedSync = true,
            ),
          ),
        ),
      );

      expect(find.text('2 offline action(s) pending sync • Tap to sync now'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tappedSync, isTrue);
    });
  });
}
