import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';
import 'package:fastkirana_flutter/features/cart/widgets/cart_bill_details_card.dart';
import 'package:fastkirana_flutter/features/cart/widgets/cart_free_delivery_bar.dart';
import 'package:fastkirana_flutter/features/checkout/widgets/checkout_savings_banner.dart';
import 'package:fastkirana_flutter/features/checkout/widgets/checkout_bottom_bar.dart';
import 'package:fastkirana_flutter/features/checkout/widgets/checkout_trust_badges.dart';
import 'package:fastkirana_flutter/features/admin/widgets/admin_stats_grid.dart';

void main() {
  group('Core Component Widget Tests', () {
    testWidgets('CartBillDetailsCard displays line items and totals accurately', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CartBillDetailsCard(
                subtotal: 440.0,
                itemSavings: 60.0,
                deliveryFee: 25.0,
                packagingFee: 10.0,
                packagingLabel: 'Eco-Packaging Charge',
                totalSavings: 85.0,
                grandTotal: 475.0,
                couponDiscount: 25.0,
                selectedTip: 20,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bill Summary'), findsOneWidget);
      expect(find.text('Item Total (MRP)'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget); // 440 + 60
      expect(find.text('Product Savings'), findsOneWidget);
      expect(find.text('-₹60'), findsOneWidget);
      expect(find.text('Coupon Discount'), findsOneWidget);
      expect(find.text('-₹25'), findsOneWidget);
      expect(find.text('Delivery Partner Tip'), findsOneWidget);
      expect(find.text('₹20'), findsOneWidget);
      expect(find.text('To Pay'), findsOneWidget);
      expect(find.text('₹475'), findsOneWidget);
    });

    testWidgets('CartFreeDeliveryBar displays progress when threshold is locked', (WidgetTester tester) async {
      const tier = DeliveryTierInfo(
        distanceKm: 2.5,
        deliveryFee: 25.0,
        baseFee: 25.0,
        freeDeliveryThreshold: 300.0,
        isServiceable: true,
        tierName: 'Zone 1',
        freeDeliveryLabel: 'Free delivery above ₹300',
        feeDescription: 'Standard delivery',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CartFreeDeliveryBar(
              subtotal: 180.0,
              tier: tier,
            ),
          ),
        ),
      );

      expect(find.text('Add ₹120 for FREE Delivery'), findsOneWidget);
      expect(find.text('Shop for ₹300 or more to get free delivery'), findsOneWidget);
      expect(find.text('₹180 / ₹300'), findsOneWidget);
    });

    testWidgets('CartFreeDeliveryBar displays unlocked badge when threshold is met', (WidgetTester tester) async {
      const tier = DeliveryTierInfo(
        distanceKm: 1.8,
        deliveryFee: 0.0,
        baseFee: 20.0,
        freeDeliveryThreshold: 250.0,
        isServiceable: true,
        tierName: 'Zone 1',
        freeDeliveryLabel: 'Free delivery above ₹250',
        feeDescription: 'Standard delivery',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CartFreeDeliveryBar(
              subtotal: 320.0,
              tier: tier,
            ),
          ),
        ),
      );

      expect(find.text('FREE Delivery Unlocked!'), findsOneWidget);
      expect(find.text('You saved ₹20 on delivery (Zone 1)'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('CartFreeDeliveryBar alerts when outside delivery zone', (WidgetTester tester) async {
      const tier = DeliveryTierInfo(
        distanceKm: 8.5,
        deliveryFee: 50.0,
        baseFee: 50.0,
        freeDeliveryThreshold: 500.0,
        isServiceable: false,
        tierName: 'Out of Zone',
        freeDeliveryLabel: 'Not serviceable',
        feeDescription: 'Out of radius',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CartFreeDeliveryBar(
              subtotal: 200.0,
              tier: tier,
            ),
          ),
        ),
      );

      expect(find.textContaining('Outside Delivery Zone (8.5 km away)'), findsOneWidget);
    });

    testWidgets('CheckoutSavingsBanner displays savings amount when positive', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckoutSavingsBanner(
              totalSavings: 145.0,
            ),
          ),
        ),
      );

      expect(find.text('₹145 saved! On this order'), findsOneWidget);
    });

    testWidgets('CheckoutSavingsBanner renders empty when totalSavings is zero', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckoutSavingsBanner(
              totalSavings: 0.0,
            ),
          ),
        ),
      );

      expect(find.textContaining('saved!'), findsNothing);
    });

    testWidgets('CheckoutBottomBar renders bill and responds to proceed click', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CheckoutBottomBar(
              grandTotal: 580.0,
              isPlacingOrder: false,
              onProceedToPay: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('TOTAL BILL'), findsOneWidget);
      expect(find.text('₹580'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsOneWidget);

      await tester.tap(find.text('Proceed to Pay'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CheckoutBottomBar displays loading indicator and disables tap during order placement', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CheckoutBottomBar(
              grandTotal: 580.0,
              isPlacingOrder: true,
              onProceedToPay: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsNothing);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('CheckoutTrustBadges renders security credentials and badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckoutTrustBadges(),
          ),
        ),
      );

      expect(find.text('100% Secure Checkout'), findsOneWidget);
      expect(find.textContaining('End-to-end encrypted 256-bit'), findsOneWidget);
    });

    testWidgets('AdminStatsGrid renders sales, net sales, and order volume cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminStatsGrid(
              displayTodaySales: 15450.0,
              displayTodayNetSales: 14200.0,
              displayTodayOrdersCount: 48,
              displayActiveOrderCount: 7,
              displayTodayDeliveryFee: 1200.0,
              displayTodayPackagingFee: 350.0,
            ),
          ),
        ),
      );

      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('₹15450'), findsOneWidget);
      expect(find.text("Net Sales"), findsOneWidget);
      expect(find.text('₹14200'), findsOneWidget);
      expect(find.text("Today's Orders"), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text("Active Orders"), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
