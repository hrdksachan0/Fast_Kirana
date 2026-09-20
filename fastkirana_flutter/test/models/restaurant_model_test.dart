import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/restaurant.dart';

void main() {
  group('Restaurant Model & Schedule Tests', () {
    test('Restaurant parses standard JSON correctly', () {
      final json = {
        'id': 'REST-001',
        'name': 'Wedson Restaurant',
        'slug': 'wedson-restaurant',
        'description': 'Finest north indian meals and snacks',
        'address': 'Station Road, Ghatampur',
        'city': 'Ghatampur',
        'phone': '9876543210',
        'cuisineTags': ['North Indian', 'Biryani', 'Snacks'],
        'rating': 4.7,
        'totalRatings': 240,
        'deliveryTime': '25-30 min',
        'priceForTwo': '₹350 for two',
        'isPureVeg': true,
        'isOpen': true,
        'openTime': '11:00 AM',
        'closeTime': '11:00 PM',
        'isClosedBySchedule': false,
        'isClosedByOwner': false,
        'formattedScheduleStr': '11:00 AM - 11:00 PM',
        'discountOffer': 'Flat 20% OFF',
        'lat': 26.1584,
        'lng': 80.1712,
        'activeOrdersCount': 3,
      };

      final restaurant = Restaurant.fromJson(json);

      expect(restaurant.id, 'REST-001');
      expect(restaurant.name, 'Wedson Restaurant');
      expect(restaurant.slug, 'wedson-restaurant');
      expect(restaurant.cuisineTags, contains('North Indian'));
      expect(restaurant.cuisineTags.length, 3);
      expect(restaurant.rating, 4.7);
      expect(restaurant.totalRatings, 240);
      expect(restaurant.isPureVeg, isTrue);
      expect(restaurant.isOpen, isTrue);
      expect(restaurant.isClosedBySchedule, isFalse);
      expect(restaurant.isClosedByOwner, isFalse);
      expect(restaurant.formattedScheduleStr, '11:00 AM - 11:00 PM');
      expect(restaurant.lat, 26.1584);
      expect(restaurant.lng, 80.1712);
      expect(restaurant.activeOrdersCount, 3);

      final map = restaurant.toJson();
      expect(map['id'], 'REST-001');
      expect(map['name'], 'Wedson Restaurant');
      expect(map['isPureVeg'], isTrue);
    });

    test('Restaurant handles string encoded cuisineTags correctly', () {
      final json = {
        'id': 'REST-002',
        'name': 'Cafe Delight',
        'slug': 'cafe-delight',
        'cuisineTags': '["Burgers", "Pizza", "Coffee"]',
      };

      final restaurant = Restaurant.fromJson(json);
      expect(restaurant.cuisineTags, ['Burgers', 'Pizza', 'Coffee']);
    });

    test('Restaurant parses latitude/longitude aliases safely', () {
      final json = {
        'id': 'REST-003',
        'name': 'Corner Bakery',
        'slug': 'corner-bakery',
        'latitude': '26.1600',
        'longitude': '80.1750',
      };

      final restaurant = Restaurant.fromJson(json);
      expect(restaurant.lat, 26.1600);
      expect(restaurant.lng, 80.1750);
    });

    test('Restaurant parses menuSections both as List and JSON string', () {
      final jsonList = {
        'id': 'REST-004',
        'name': 'Pizza Hub',
        'slug': 'pizza-hub',
        'menuSections': [
          {'title': 'Pizzas', 'tag': 'pizza'},
          {'title': 'Beverages', 'tag': 'drinks'},
        ],
      };
      final r1 = Restaurant.fromJson(jsonList);
      expect(r1.menuSections, isNotNull);
      expect(r1.menuSections!.length, 2);

      final jsonString = {
        'id': 'REST-005',
        'name': 'Burger King',
        'slug': 'burger-king',
        'menuSections': '[{"title": "Burgers", "tag": "burger"}]',
      };
      final r2 = Restaurant.fromJson(jsonString);
      expect(r2.menuSections, isNotNull);
      expect(r2.menuSections!.length, 1);
    });
  });
}
