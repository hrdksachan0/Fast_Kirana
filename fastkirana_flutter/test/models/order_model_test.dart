import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/order.dart';

void main() {
  group('Order & OrderItem Serialization Tests', () {
    test('OrderItem correctly serializes and deserializes selectedVariant and notes', () {
      final json = {
        'id': 'item_101',
        'productId': 'prod_paneer_1',
        'name': 'Paneer Butter Masala',
        'price': 220.0,
        'quantity': 2,
        'selectedVariant': 'Full (Double Gravy)',
        'notes': 'Make it extra spicy and less oil',
        'imageUrl': 'https://example.com/paneer.jpg',
      };

      final orderItem = OrderItem.fromJson(json);

      expect(orderItem.id, 'item_101');
      expect(orderItem.productId, 'prod_paneer_1');
      expect(orderItem.name, 'Paneer Butter Masala');
      expect(orderItem.price, 220.0);
      expect(orderItem.quantity, 2);
      expect(orderItem.lineTotal, 440.0);
      expect(orderItem.selectedVariant, 'Full (Double Gravy)');
      expect(orderItem.variant, 'Full (Double Gravy)');
      expect(orderItem.notes, 'Make it extra spicy and less oil');

      final serialized = orderItem.toJson();
      expect(serialized['id'], 'item_101');
      expect(serialized['selectedVariant'], 'Full (Double Gravy)');
      expect(serialized['notes'], 'Make it extra spicy and less oil');
    });

    test('Order correctly serializes and computes status and grand total', () {
      final orderJson = {
        'id': 'FK-123456',
        'readableId': 'FK-123456',
        'userId': 'usr_789',
        'addressId': 'addr_ghatampur_1',
        'restaurantId': 'cms2p1lyx0001n0idod904lfu',
        'shopName': 'Wedson Restaurant',
        'status': 'CONFIRMED',
        'subtotal': 440.0,
        'discount': 40.0,
        'deliveryFee': 25.0,
        'taxes': 0.0,
        'miscFee': 15.0,
        'total': 440.0,
        'paymentMethod': 'UPI',
        'paymentStatus': 'PAID',
        'deliveryMethod': 'DELIVERY',
        'customerName': 'Sooraj Sachan',
        'customerPhone': '7054470303',
        'customerAddress': 'Hamirpur Road, Ghatampur',
        'notes': 'Ring the bell twice',
        'createdAt': DateTime(2026, 8, 31, 12, 0).toIso8601String(),
        'items': [
          {
            'id': 'item_101',
            'productId': 'prod_paneer_1',
            'name': 'Paneer Butter Masala',
            'price': 220.0,
            'quantity': 2,
            'selectedVariant': 'Full',
            'notes': 'Extra spicy',
          }
        ],
      };

      final order = Order.fromJson(orderJson);

      expect(order.id, 'FK-123456');
      expect(order.readableId, 'FK-123456');
      expect(order.status, OrderStatus.confirmed);
      expect(order.subtotal, 440.0);
      expect(order.discount, 40.0);
      expect(order.deliveryFee, 25.0);
      expect(order.miscFee, 15.0);
      expect(order.paymentStatus, 'PAID');
      expect(order.items?.length, 1);
      expect(order.items?.first.name, 'Paneer Butter Masala');

      final backToJson = order.toJson();
      expect(backToJson['readableId'], 'FK-123456');
      expect(backToJson['paymentStatus'], 'PAID');
    });
  });
}
