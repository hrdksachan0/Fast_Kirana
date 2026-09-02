import 'package:flutter_test/flutter_test.dart';

import 'package:fastkirana_flutter/data/models/order.dart';

void main() {
  group('Order.fromJson', () {
    test('parses full order with all fields', () {
      final json = {
        'id': 'ord-001',
        'readableId': '#1089',
        'userId': 'user-1',
        'addressId': 'addr-1',
        'status': 'SHIPPED',
        'subtotal': 500.0,
        'discount': 50.0,
        'deliveryFee': 30.0,
        'taxes': 10.0,
        'miscFee': 0.0,
        'total': 490.0,
        'paymentMethod': 'UPI',
        'paymentStatus': 'PAID',
        'deliveryBoyName': 'Rahul',
        'deliveryBoyPhone': '9876543210',
        'shopName': 'A.S. Restaurant',
        'estimatedDelivery': '2026-09-01T14:00:00.000Z',
        'customerName': 'Sooraj',
        'customerPhone': '9123456780',
        'address': {
          'houseNo': '12/3',
          'area': 'Ghatampur Market',
          'city': 'Kanpur Nagar',
          'pincode': '209206',
        },
        'items': [
          {'name': 'Pizza', 'qty': 2, 'price': 150.0},
        ],
        'isCombined': true,
        'combinedId': 'comb-001',
        'createdAt': '2026-09-01T10:00:00.000Z',
      };

      final order = Order.fromJson(json);

      expect(order.id, 'ord-001');
      expect(order.displayId, '1089');
      expect(order.status, OrderStatus.shipped);
      expect(order.paymentMethod, PaymentMethod.upi);
      expect(order.total, 490.0);
      expect(order.deliveryBoyName, 'Rahul');
      expect(order.customerName, 'Sooraj');
      expect(order.customerAddress, '12/3, Ghatampur Market, Kanpur Nagar, 209206');
      expect(order.isCombined, isTrue);
      expect(order.items?.length, 1);
      expect(order.items?.first.name, 'Pizza');
      expect(order.address!.label, 'Delivery Location');
    });

    test('handles empty json with safe defaults', () {
      final order = Order.fromJson({});

      expect(order.id, '');
      expect(order.displayId, '');
      expect(order.status, OrderStatus.pending);
      expect(order.paymentMethod, PaymentMethod.cod);
      expect(order.subtotal, 0.0);
      expect(order.total, 0.0);
      expect(order.deliveryBoyName, isNull);
      expect(order.customerName, isNull);
      expect(order.items, isEmpty); // empty list, not null
      expect(order.isCombined, isFalse);
      expect(order.subOrders, isNull);
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'id': 'ord-002',
        'userId': 'user-2',
        'addressId': 'addr-2',
        'status': 'delivered',
        'subtotal': 300.0,
        'discount': 0.0,
        'deliveryFee': 20.0,
        'taxes': 5.0,
        'miscFee': 0.0,
        'total': 325.0,
        'paymentMethod': 'cod',
        'paymentStatus': 'PENDING',
        'createdAt': '2026-08-31T18:00:00.000Z',
      };

      final order = Order.fromJson(json);

      expect(order.status, OrderStatus.delivered);
      expect(order.paymentMethod, PaymentMethod.cod);
      expect(order.deliveryBoyName, isNull);
      expect(order.customerAddress, isNull);
      expect(order.address!.formattedAddress, 'Ghatampur Zone');
    });
  });

  group('OrderStatus parsing', () {
    test('maps status strings via fromJson', () {
      for (final entry in {
        'pending': OrderStatus.pending,
        'confirmed': OrderStatus.confirmed,
        'PACKED': OrderStatus.packed,
        'SHIPPED': OrderStatus.shipped,
        'out_for_delivery': OrderStatus.shipped,
        'delivered': OrderStatus.delivered,
        'cancelled': OrderStatus.cancelled,
        'weird_status': OrderStatus.pending,
        '': OrderStatus.pending,
      }.entries) {
        final order = Order.fromJson({
          'id': 's1',
          'userId': 'u1',
          'addressId': 'a1',
          'status': entry.key,
          'subtotal': 0,
          'discount': 0,
          'deliveryFee': 0,
          'taxes': 0,
          'miscFee': 0,
          'total': 0,
          'paymentMethod': 'cod',
          'paymentStatus': 'PENDING',
          'createdAt': '2026-09-01T10:00:00.000Z',
        });
        expect(order.status, entry.value, reason: 'status: "${entry.key}"');
      }
    });
  });

  group('Order.address getter', () {
    test('extracts coordinates from addressRaw', () {
      final json = {
        'id': 'o1',
        'userId': 'u1',
        'addressId': 'a1',
        'status': 'pending',
        'subtotal': 100.0,
        'discount': 0.0,
        'deliveryFee': 0.0,
        'taxes': 0.0,
        'miscFee': 0.0,
        'total': 100.0,
        'paymentMethod': 'cod',
        'paymentStatus': 'PENDING',
        'createdAt': '2026-09-01T10:00:00.000Z',
        'address': {
          'lat': 26.1534,
          'lng': 80.1714,
          'formattedAddress': 'Ghatampur Market',
          'label': 'Home',
        },
      };

      final order = Order.fromJson(json);
      final addr = order.address!;

      expect(addr.label, 'Home');
      expect(addr.formattedAddress, 'Ghatampur Market');
      expect(addr.lat, 26.1534);
      expect(addr.lng, 80.1714);
    });

    test('falls back to delivery coordinates when addressRaw is absent', () {
      final json = {
        'id': 'o2',
        'userId': 'u1',
        'addressId': 'a1',
        'status': 'pending',
        'subtotal': 100.0,
        'discount': 0.0,
        'deliveryFee': 0.0,
        'taxes': 0.0,
        'miscFee': 0.0,
        'total': 100.0,
        'paymentMethod': 'cod',
        'paymentStatus': 'PENDING',
        'createdAt': '2026-09-01T10:00:00.000Z',
        'deliveryLat': 26.1558,
        'deliveryLng': 80.1685,
      };

      final order = Order.fromJson(json);
      final addr = order.address!;

      expect(addr.lat, 26.1558);
      expect(addr.lng, 80.1685);
    });
  });

  group('Order.copyWith', () {
    test('creates copy with overridden fields', () {
      final order = Order(
        id: 'o1',
        userId: 'u1',
        addressId: 'a1',
        status: OrderStatus.pending,
        subtotal: 100.0,
        discount: 0.0,
        deliveryFee: 10.0,
        taxes: 0.0,
        miscFee: 0.0,
        total: 110.0,
        paymentMethod: PaymentMethod.cod,
        paymentStatus: 'PENDING',
        createdAt: DateTime.now(),
      );

      final updated = order.copyWith(
        status: OrderStatus.delivered,
        total: 110.0,
      );

      expect(updated.status, OrderStatus.delivered);
      expect(updated.id, 'o1'); // unchanged
      expect(updated.deliveryBoyName, isNull); // unchanged
    });
  });

  group('combined / sub-orders', () {
    test('parses isCombined from combinedId', () {
      final json = {
        'id': 'c1',
        'userId': 'u1',
        'addressId': 'a1',
        'status': 'pending',
        'subtotal': 500.0,
        'discount': 0.0,
        'deliveryFee': 30.0,
        'taxes': 0.0,
        'miscFee': 0.0,
        'total': 530.0,
        'paymentMethod': 'cod',
        'paymentStatus': 'PENDING',
        'createdAt': '2026-09-01T10:00:00.000Z',
        'combinedId': '#1099',
        'subLabels': ['#1099-G', '#1099-R'],
      };

      final order = Order.fromJson(json);
      expect(order.isCombined, isTrue);
      expect(order.subLabels, ['#1099-G', '#1099-R']);
    });
  });
}
