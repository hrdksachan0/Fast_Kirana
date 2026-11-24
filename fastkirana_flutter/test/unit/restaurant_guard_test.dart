import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/core/utils/restaurant_utils.dart';
import 'package:fastminute_flutter/data/models/product.dart';

void main() {
  group('Packaged Grocery vs Restaurant Dish Classification Tests', () {
    test('Packaged brands and items are NEVER classified as restaurant products', () {
      final packagedItems = [
        'Bikaji Bhelpuri',
        'Haldiram Bhelpuri',
        'Himalaya Purifying Neem Face Wash | 200 ml',
        'MuscleBlaze Biozyme Protien',
        'Dukes Creme 4 Fun Sandwich Biscuit',
        'Haldiram\'s Samosa',
        'Haldiram\'s Kachori',
        'Haldiram\'s Punjabi Tadka',
        'Winkies Mini Swiss Roll Choco Cake',
        'Funfoods Pasta & Pizza Red Sauce',
        'Ching\'s Manchurian Instant Noodles',
        'Everest Hing',
        'Everest Black Pepper',
      ];

      for (final name in packagedItems) {
        final p = Product.fromJson({
          'id': 'test_item',
          'name': name,
          'slug': 'test-item',
          'mrp': 100,
          'price': 80,
          'discount': 20,
          'unit': '1 pc',
          'stock': 10,
          'isAvailable': true,
          'tags': <String>[],
        });
        expect(isRestaurantProduct(p), isFalse, reason: '$name should NOT be a restaurant product');
        expect(RestaurantRegistry.isFoodDishName(name), isFalse, reason: '$name should NOT match food dish names');
      }
    });

    test('Actual cooked restaurant dishes ARE classified as food dishes', () {
      final cookedDishes = [
        'Veg Hakka Noodles',
        'Paneer Tikka Pizza',
        'Special Dosa',
        'Chhole Bhature',
        'Veg Burger',
        'Cold Coffee',
        'Tandoori Roti',
      ];

      for (final name in cookedDishes) {
        expect(RestaurantRegistry.isFoodDishName(name), isTrue, reason: '$name SHOULD be a food dish');
      }
    });
  });
}
