import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/features/checkout/controllers/checkout_controller.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';

void main() {
  group('CheckoutState & Logic Tests', () {
    test('Default CheckoutState initializes with safe COD defaults', () {
      const state = CheckoutState();

      expect(state.isPlacingOrder, isFalse);
      expect(state.selectedPayment, equals('cod'));
      expect(state.selectedPackaging, equals('NORMAL'));
      expect(state.deliveryMethod, equals('DELIVERY'));
      expect(state.selectedAddressIndex, equals(0));
      expect(state.deliveryInstruction, equals('🔔 Ring Bell'));
      expect(state.selectedDeliveryInstructions.contains('ring_bell'), isTrue);
      expect(state.customReceiverName, isNull);
      expect(state.customReceiverPhone, isNull);
    });

    test('copyWith properly updates payment and packaging options', () {
      const initial = CheckoutState();

      final updated = initial.copyWith(
        selectedPayment: 'online',
        selectedPackaging: 'PREMIUM',
        deliveryMethod: 'PICKUP',
      );

      expect(updated.selectedPayment, equals('online'));
      expect(updated.selectedPackaging, equals('PREMIUM'));
      expect(updated.deliveryMethod, equals('PICKUP'));
      expect(updated.isPlacingOrder, isFalse);
    });

    test('Toggling delivery instructions adds and removes preset IDs', () {
      var state = const CheckoutState(selectedDeliveryInstructions: {'ring_bell'});

      // Add 'leave_at_door'
      final withDoor = Set<String>.from(state.selectedDeliveryInstructions)..add('leave_at_door');
      state = state.copyWith(selectedDeliveryInstructions: withDoor);
      expect(state.selectedDeliveryInstructions.contains('leave_at_door'), isTrue);
      expect(state.selectedDeliveryInstructions.length, equals(2));

      // Remove 'ring_bell'
      final withoutBell = Set<String>.from(state.selectedDeliveryInstructions)..remove('ring_bell');
      state = state.copyWith(selectedDeliveryInstructions: withoutBell);
      expect(state.selectedDeliveryInstructions.contains('ring_bell'), isFalse);
      expect(state.selectedDeliveryInstructions.contains('leave_at_door'), isTrue);
      expect(state.selectedDeliveryInstructions.length, equals(1));
    });

    test('Receiver details override and clear properly', () {
      const initial = CheckoutState();

      final withReceiver = initial.copyWith(
        customReceiverName: 'Rahul Sharma',
        customReceiverPhone: '9876543210',
      );

      expect(withReceiver.customReceiverName, equals('Rahul Sharma'));
      expect(withReceiver.customReceiverPhone, equals('9876543210'));

      final cleared = withReceiver.copyWith(clearReceiverDetails: true);
      expect(cleared.customReceiverName, isNull);
      expect(cleared.customReceiverPhone, isNull);
    });

    test('Grand total calculation clamps safely to zero on 100% discounts', () {
      const subtotal = 100.0;
      const deliveryFee = 30.0;
      const packagingFee = 5.0; // NORMAL
      const discount = 200.0; // Promo higher than total

      final grandTotal = (subtotal + deliveryFee + packagingFee - discount).clamp(0.0, 999999.0);
      expect(grandTotal, equals(0.0));
    });

    test('Cart total with Premium packaging fee calculates accurately', () {
      final dummyProduct = Product.fromJson({
        'id': 'prod_1',
        'name': 'Atta 5kg',
        'slug': 'atta-5kg',
        'price': 240.0,
        'mrp': 275.0,
        'stock': 10,
        'category': 'Flour',
        'imageUrl': '',
      });

      final cart = Cart(
        id: 'cart_test',
        userId: 'u1',
        items: [
          CartItem(
            id: 'item_1',
            cartId: 'cart_test',
            productId: dummyProduct.id,
            product: dummyProduct,
            quantity: 2,
          ),
        ],
        couponDiscount: 20.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(cart.subtotal, equals(480.0));

      const deliveryFee = 0.0; // free delivery
      const premiumPackagingFee = 15.0;
      final discount = cart.couponDiscount;

      final total = (cart.subtotal + deliveryFee + premiumPackagingFee - discount).clamp(0.0, 999999.0);
      expect(total, equals(475.0));
    });
  });
}
