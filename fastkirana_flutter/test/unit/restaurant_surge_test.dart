import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/restaurant.dart';

void main() {
  group('Restaurant Active Orders & Surge Alert Tests', () {
    test('Restaurant parses activeOrdersCount correctly from JSON', () {
      final jsonLowDemand = {
        'id': 'REST-101',
        'name': 'A.S. Restaurant',
        'slug': 'as-restaurant',
        'activeOrdersCount': 3,
      };

      final rLow = Restaurant.fromJson(jsonLowDemand);
      expect(rLow.activeOrdersCount, equals(3));
      expect(rLow.activeOrdersCount >= 6, isFalse);

      final jsonHighDemand = {
        'id': 'REST-102',
        'name': 'Wedson Restaurant',
        'slug': 'wedson-restaurant',
        'activeOrdersCount': 8,
      };

      final rHigh = Restaurant.fromJson(jsonHighDemand);
      expect(rHigh.activeOrdersCount, equals(8));
      expect(rHigh.activeOrdersCount >= 6, isTrue);
    });

    test('Restaurant defaults activeOrdersCount to 0 when not provided', () {
      final jsonNoOrders = {
        'id': 'REST-103',
        'name': 'Bal Udyan Restaurant',
        'slug': 'bal-udyan-restaurant',
      };

      final r = Restaurant.fromJson(jsonNoOrders);
      expect(r.activeOrdersCount, equals(0));
      expect(r.activeOrdersCount >= 6, isFalse);
    });

    test('Threshold 6 activates surge alert condition', () {
      final r5 = Restaurant(
        id: 'r5',
        name: 'Test',
        slug: 'test',
        activeOrdersCount: 5,
      );
      expect(r5.activeOrdersCount >= 6, isFalse);

      final r6 = Restaurant(
        id: 'r6',
        name: 'Test',
        slug: 'test',
        activeOrdersCount: 6,
      );
      expect(r6.activeOrdersCount >= 6, isTrue);
    });
  });
}
