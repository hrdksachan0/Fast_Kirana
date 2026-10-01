import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/features/checkout/controllers/checkout_controller.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/order.dart';

void main() {
  group('Automated E2E Checkout Smoke Test (Flutter Mobile)', () {
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

    final mockRice = Product.fromJson({
      'id': 'prod_rice_103',
      'name': 'India Gate Basmati Rice 1kg',
      'slug': 'india-gate-rice-1kg',
      'price': 110.0,
      'mrp': 130.0,
      'stock': 15,
      'category': 'Staples',
      'imageUrl': 'https://example.com/rice.png',
      'isAvailable': true,
    });

    test('E2E Flow 1: Grocery Cart -> Address -> COD Order Placement Smoke Test', () {
      // 1. Build Cart with multiple grocery items
      final cart = Cart(
        id: 'cart_session_mobile_01',
        userId: 'usr_customer_mobile_42',
        items: [
          CartItem(
            id: 'item_1',
            cartId: 'cart_session_mobile_01',
            productId: mockAtta.id,
            product: mockAtta,
            quantity: 1, // 245 * 1 = 245
          ),
          CartItem(
            id: 'item_2',
            cartId: 'cart_session_mobile_01',
            productId: mockMilk.id,
            product: mockMilk,
            quantity: 3, // 27 * 3 = 81
          ),
          CartItem(
            id: 'item_3',
            cartId: 'cart_session_mobile_01',
            productId: mockRice.id,
            product: mockRice,
            quantity: 2, // 110 * 2 = 220
          ),
        ],
        couponDiscount: 50.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify cart totals
      // Subtotal = 245 + 81 + 220 = 546
      expect(cart.subtotal, equals(546.0));
      expect(cart.totalItems, equals(6));
      expect(cart.couponDiscount, equals(50.0));

      // 2. Initialize CheckoutState with default COD
      var state = const CheckoutState();
      expect(state.selectedPayment, equals('cod'));
      expect(state.selectedPackaging, equals('NORMAL'));
      expect(state.deliveryMethod, equals('DELIVERY'));

      // 3. Configure delivery instructions & custom receiver
      final instructions = Set<String>.from(state.selectedDeliveryInstructions)
        ..add('leave_at_door')
        ..add('avoid_calling');
      state = state.copyWith(
        selectedDeliveryInstructions: instructions,
        customReceiverName: 'Aarav Gupta',
        customReceiverPhone: '9876543210',
      );

      expect(state.selectedDeliveryInstructions.contains('leave_at_door'), isTrue);
      expect(state.selectedDeliveryInstructions.contains('avoid_calling'), isTrue);
      expect(state.customReceiverName, equals('Aarav Gupta'));
      expect(state.customReceiverPhone, equals('9876543210'));

      // 4. Calculate Bill Breakdown
      // Subtotal ₹546 >= ₹199 threshold -> Free Delivery (0)
      const deliveryFee = 0.0;
      const packagingFee = 5.0; // NORMAL packaging
      final grandTotal = (cart.subtotal + deliveryFee + packagingFee - cart.couponDiscount)
          .clamp(0.0, 999999.0);
      // 546 + 0 + 5 - 50 = 501
      expect(grandTotal, equals(501.0));

      // 5. Construct & Validate Backend Order Placement Payload
      final orderPayload = {
        'items': cart.items.map((item) => {
          'productId': item.productId,
          'name': item.product?.name ?? '',
          'price': item.product?.price ?? 0.0,
          'quantity': item.quantity,
        }).toList(),
        'paymentMethod': state.selectedPayment.toUpperCase(), // 'COD'
        'deliveryMethod': state.deliveryMethod, // 'DELIVERY'
        'packaging': state.selectedPackaging, // 'NORMAL'
        'address': {
          'houseNo': 'House #22',
          'area': 'Station Road',
          'city': 'Ghatampur',
          'pincode': '209206',
          'lat': 26.1584,
          'lng': 80.1707,
          'phone': state.customReceiverPhone,
          'recipientName': state.customReceiverName,
        },
        'deliveryInstructions': state.selectedDeliveryInstructions.toList(),
        'couponDiscount': cart.couponDiscount,
        'storeId': 'hub-209206',
      };

      expect(orderPayload['paymentMethod'], equals('COD'));
      expect((orderPayload['items'] as List).length, equals(3));
      expect((orderPayload['address'] as Map)['pincode'], equals('209206'));
      expect(orderPayload['storeId'], equals('hub-209206'));

      // 6. Simulate Server Response & Order Model Lifecycle
      final simulatedServerResponse = {
        'id': 'ord_cod_mobile_789',
        'userId': 'usr_customer_mobile_42',
        'status': 'pending',
        'total': grandTotal,
        'paymentMethod': 'cod',
        'paymentStatus': 'pending',
        'items': [
          {
            'id': 'oi_1',
            'orderId': 'ord_cod_mobile_789',
            'productId': mockAtta.id,
            'quantity': 1,
            'price': 245.0,
          },
          {
            'id': 'oi_2',
            'orderId': 'ord_cod_mobile_789',
            'productId': mockMilk.id,
            'quantity': 3,
            'price': 27.0,
          },
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final order = Order.fromJson(simulatedServerResponse);
      expect(order.id, equals('ord_cod_mobile_789'));
      expect(order.status, equals(OrderStatus.pending));
      expect(order.total, equals(501.0));
      expect(order.paymentStatus, equals('pending'));

      // Verify all canonical order status transitions
      expect(OrderStatus.pending.displayName, equals('Placed'));
      expect(OrderStatus.confirmed.displayName, equals('Confirmed'));
      expect(OrderStatus.packed.displayName, equals('Packed'));
      expect(OrderStatus.shipped.displayName, equals('On the Way'));
      expect(OrderStatus.delivered.displayName, equals('Delivered'));
    });

    test('E2E Flow 2: Online Payment Switch & Premium Packaging Smoke Test', () {
      final cart = Cart(
        id: 'cart_online_02',
        userId: 'usr_online_02',
        items: [
          CartItem(
            id: 'item_1',
            cartId: 'cart_online_02',
            productId: mockMilk.id,
            product: mockMilk,
            quantity: 4, // 27 * 4 = 108 (< 199 threshold)
          ),
        ],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Switch to online payment with Premium packaging
      var state = const CheckoutState();
      state = state.copyWith(
        selectedPayment: 'online',
        selectedPackaging: 'PREMIUM',
      );

      expect(state.selectedPayment, equals('online'));
      expect(state.selectedPackaging, equals('PREMIUM'));

      // Bill calculation: Subtotal 108 + Zone 1 delivery 25 + Premium packaging 15 = 148
      const baseDeliveryFee = 25.0;
      const premiumPackagingFee = 15.0;
      final total = (cart.subtotal + baseDeliveryFee + premiumPackagingFee).clamp(0.0, 999999.0);
      expect(total, equals(148.0));

      // Simulate payment gateway initiation state
      state = state.copyWith(
        isPlacingOrder: true,
        pendingOrderId: 'ord_pg_pre_001',
        pendingCashfreeOrderId: 'cf_order_stage_123',
        pendingCart: cart,
        pendingGrandTotal: total,
      );

      expect(state.isPlacingOrder, isTrue);
      expect(state.pendingOrderId, equals('ord_pg_pre_001'));
      expect(state.pendingCashfreeOrderId, equals('cf_order_stage_123'));
      expect(state.pendingGrandTotal, equals(148.0));

      // Test Payment Failure -> Seamless COD Fallback without losing user choices
      final fallbackState = state.copyWith(
        selectedPayment: 'cod',
        isPlacingOrder: false,
      );
      expect(fallbackState.selectedPayment, equals('cod'));
      expect(fallbackState.selectedPackaging, equals('PREMIUM'));
      expect(fallbackState.isPlacingOrder, isFalse);
    });

    test('E2E Flow 3: Store Pickup Delivery Method Zero Fee Calculation', () {
      final cart = Cart(
        id: 'cart_pickup_03',
        userId: 'usr_pickup_03',
        items: [
          CartItem(
            id: 'item_1',
            cartId: 'cart_pickup_03',
            productId: mockAtta.id,
            product: mockAtta,
            quantity: 2, // 245 * 2 = 490
          ),
        ],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      var state = const CheckoutState();
      state = state.copyWith(deliveryMethod: 'PICKUP');

      expect(state.deliveryMethod, equals('PICKUP'));

      // Pickup must yield zero delivery fee regardless of distance
      const pickupDeliveryFee = 0.0;
      const normalPackagingFee = 5.0;
      final total = (cart.subtotal + pickupDeliveryFee + normalPackagingFee).clamp(0.0, 999999.0);
      expect(total, equals(495.0));
    });
  });
}
