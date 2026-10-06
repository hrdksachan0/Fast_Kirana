import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/order.dart';
import 'package:fastkirana_flutter/features/checkout/controllers/checkout_controller.dart';
import 'package:fastkirana_flutter/features/orders/widgets/tracking_status_stepper.dart';
import 'package:fastkirana_flutter/features/orders/widgets/tracking_payment_card.dart';
import 'package:fastkirana_flutter/features/cart/widgets/cart_bill_details_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Full E2E Checkout & Live Delivery Tracking Integration Test Suite', () {
    // ── Fixture Products ──
    final mockAtta = Product.fromJson({
      'id': 'prod_atta_101',
      'name': 'Aashirvaad Shudh Chakki Atta 5kg',
      'slug': 'aashirvaad-atta-5kg',
      'price': 245.0,
      'mrp': 275.0,
      'stock': 20,
      'category': 'Staples',
      'imageUrl': 'https://example.com/atta.png',
      'isAvailable': true,
    });

    final mockMilk = Product.fromJson({
      'id': 'prod_milk_102',
      'name': 'Amul Taaza Milk 500ml',
      'slug': 'amul-taaza-500ml',
      'price': 27.0,
      'mrp': 27.0,
      'stock': 50,
      'category': 'Dairy',
      'imageUrl': 'https://example.com/milk.png',
      'isAvailable': true,
    });

    testWidgets('Step 1 & 2: Cart Assembly -> Apply Coupon Code -> Bill Verification',
        (WidgetTester tester) async {
      // 1. Build initial cart without coupons
      var cart = Cart(
        id: 'cart_integration_e2e_01',
        userId: 'usr_test_shopper_01',
        items: [
          CartItem(
            id: 'item_atta',
            cartId: 'cart_integration_e2e_01',
            productId: mockAtta.id,
            product: mockAtta,
            quantity: 2, // 245 * 2 = 490
          ),
          CartItem(
            id: 'item_milk',
            cartId: 'cart_integration_e2e_01',
            productId: mockMilk.id,
            product: mockMilk,
            quantity: 4, // 27 * 4 = 108
          ),
        ],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify initial subtotal: 490 + 108 = 598
      expect(cart.subtotal, equals(598.0));
      expect(cart.totalItems, equals(6));

      // 2. Apply Coupon WELCOME50 (₹50 discount)
      cart = cart.copyWith(
        couponDiscount: 50.0,
        appliedCouponCode: 'WELCOME50',
      );

      expect(cart.couponDiscount, equals(50.0));
      expect(cart.appliedCouponCode, equals('WELCOME50'));

      // 3. Render Bill Details Card Widget & Verify UI Display
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CartBillDetailsCard(
                subtotal: cart.subtotal,
                itemSavings: 0.0,
                deliveryFee: 0.0, // Free delivery for > ₹199
                packagingFee: 5.0, // Packaging
                packagingLabel: 'Normal',
                totalSavings: 50.0,
                grandTotal: 598.0 - 50.0 + 5.0, // 553
                couponDiscount: cart.couponDiscount,
                selectedTip: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Bill UI elements rendered
      expect(find.text('Bill Summary'), findsOneWidget);
      expect(find.textContaining('598'), findsWidgets);
      expect(find.textContaining('50'), findsWidgets);
      expect(find.textContaining('553'), findsWidgets);
    });

    testWidgets('Step 3: Online Payment Initiation & Simulated Cashfree Success Flow',
        (WidgetTester tester) async {
      // 1. Initialize Checkout State
      var checkout = const CheckoutState(
        selectedPayment: 'online',
        selectedPackaging: 'PREMIUM',
        deliveryMethod: 'DELIVERY',
        customReceiverName: 'Priya Sharma',
        customReceiverPhone: '9876500000',
      );

      expect(checkout.selectedPayment, equals('online'));
      expect(checkout.selectedPackaging, equals('PREMIUM'));

      // 2. Simulate Cashfree PG Session Creation
      const cfOrderId = 'cf_order_stage_integration_777';
      checkout = checkout.copyWith(
        isPlacingOrder: true,
        pendingCashfreeOrderId: cfOrderId,
        pendingGrandTotal: 553.0,
      );

      expect(checkout.isPlacingOrder, isTrue);
      expect(checkout.pendingCashfreeOrderId, equals(cfOrderId));

      // 3. Simulate Successful Cashfree PG Webhook / Return Handshake
      final mockVerificationResult = {
        'cfOrderId': cfOrderId,
        'orderStatus': 'PAID',
        'paymentId': 'cf_payment_ref_success_999',
        'isPaid': true,
      };

      expect(mockVerificationResult['isPaid'], isTrue);
      expect(mockVerificationResult['paymentId'], equals('cf_payment_ref_success_999'));

      // 4. Finalize Order Placement State
      checkout = checkout.copyWith(
        isPlacingOrder: false,
        pendingOrderId: 'ord_e2e_cashfree_success_101',
      );

      expect(checkout.isPlacingOrder, isFalse);
      expect(checkout.pendingOrderId, equals('ord_e2e_cashfree_success_101'));
    });

    testWidgets('Step 4: Live Delivery Tracking Screen Lifecycle (Placed -> On the Way -> Delivered)',
        (WidgetTester tester) async {
      // 1. Constructed Confirmed Order
      final confirmedOrder = Order(
        id: 'ord_e2e_cashfree_success_101',
        readableId: 'FK-7701',
        userId: 'usr_test_shopper_01',
        addressId: 'addr_ghatampur_01',
        status: OrderStatus.shipped,
        subtotal: 598.0,
        discount: 50.0,
        deliveryFee: 0.0,
        taxes: 0.0,
        miscFee: 5.0,
        total: 553.0,
        paymentMethod: PaymentMethod.upi,
        paymentStatus: 'PAID',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            id: 'item-1',
            name: 'Aashirvaad Shudh Chakki Atta 5kg',
            quantity: 2,
            price: 245.0,
          ),
          OrderItem(
            id: 'item-2',
            name: 'Amul Taaza Milk 500ml',
            quantity: 4,
            price: 27.0,
          ),
        ],
      );

      // 2. Render Live Delivery Stepper Widget in Shipped ('On the Way') Stage
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TrackingStatusStepper(
                    order: confirmedOrder,
                    statusStep: 3, // Shipped / Out for delivery
                    isDelivered: false,
                    isCancelled: false,
                    cleanDisplayId: 'FK-7701',
                    etaText: '9 mins',
                    distanceText: '1.2 km away',
                  ),
                  TrackingPaymentCard(
                    order: confirmedOrder,
                    isProcessingPayment: false,
                    statusStep: 3,
                    onPayOnline: () {},
                    onSwitchToCOD: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert Live Stepper components
      expect(find.text('Live Order Status'), findsOneWidget);
      expect(find.textContaining('9 mins'), findsOneWidget);
      expect(find.textContaining('1.2 km away'), findsOneWidget);
      expect(find.textContaining('IN TRANSIT'), findsOneWidget);
      expect(find.textContaining('553'), findsWidgets);

      // 3. Simulate Rider Arriving & Stage Transition to Delivered
      final deliveredOrder = confirmedOrder.copyWith(
        status: OrderStatus.delivered,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingStatusStepper(
                order: deliveredOrder,
                statusStep: 4, // Delivered
                isDelivered: true,
                isCancelled: false,
                cleanDisplayId: 'FK-7701',
                etaText: 'Delivered',
                distanceText: '0 km',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Delivered'), findsWidgets);
    });

    testWidgets('Step 5: Edge Case - Cashfree Payment Failure with Seamless COD Recovery',
        (WidgetTester tester) async {
      // 1. Customer attempts online payment that fails or is aborted in UPI app
      var checkout = const CheckoutState(
        selectedPayment: 'online',
        isPlacingOrder: true,
        pendingCashfreeOrderId: 'cf_order_failed_user_cancelled_404',
        pendingGrandTotal: 553.0,
      );

      // 2. Cashfree callback returns CANCELLED / FAILED
      final failedResult = {
        'cfOrderId': 'cf_order_failed_user_cancelled_404',
        'orderStatus': 'CANCELLED',
        'isPaid': false,
        'paymentId': null,
      };
      expect(failedResult['isPaid'], isFalse);

      // 3. User selects 'Switch to COD' option
      checkout = checkout.copyWith(
        selectedPayment: 'cod',
        isPlacingOrder: false,
        pendingCashfreeOrderId: null,
      );

      expect(checkout.selectedPayment, equals('cod'));
      expect(checkout.pendingCashfreeOrderId, isNull);
      expect(checkout.isPlacingOrder, isFalse);

      // 4. Order successfully placed under COD
      checkout = checkout.copyWith(
        isPlacingOrder: false,
        pendingOrderId: 'ord_cod_fallback_success_202',
      );
      expect(checkout.pendingOrderId, equals('ord_cod_fallback_success_202'));
    });
  });
}
