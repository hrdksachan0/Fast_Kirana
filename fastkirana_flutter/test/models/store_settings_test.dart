import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';

void main() {
  group('StoreSettings Model Tests', () {
    test('StoreSettings provides correct production defaults', () {
      const settings = StoreSettings();

      expect(settings.deliveryFee, 25.0);
      expect(settings.miscFee, 5.0);
      expect(settings.miscFeeLabel, 'Packaging charge');
      expect(settings.groceryFreeDeliveryThreshold, 199.0);
      expect(settings.cafeFreeDeliveryThreshold, 199.0);
      expect(settings.combinedFreeDeliveryThreshold, 199.0);
      expect(settings.deliveryRadiusKm, 5.0);
      expect(settings.serviceablePincode, '209206');
      expect(settings.groceryMartOpen, isTrue);
      expect(settings.cafeOpen, isTrue);
      expect(settings.restaurantOpen, isTrue);
    });

    test('StoreSettings parses custom configuration from JSON safely', () {
      final json = {
        'delivery_fee': '30.0',
        'misc_fee': 10,
        'misc_fee_label': 'Handling fee',
        'grocery_free_delivery_threshold': 249.0,
        'cafe_free_delivery_threshold': '299',
        'surge_charge': 15.0,
        'min_order_value': 50.0,
        'delivery_radius': 7.5,
        'serviceable_pincode': '209206',
        'grocery_mart_open': false,
        'cafe_open': true,
        'restaurant_open': false,
        'support_phone': '9999888877',
      };

      final settings = StoreSettings.fromJson(json);

      expect(settings.deliveryFee, 30.0);
      expect(settings.miscFee, 10.0);
      expect(settings.miscFeeLabel, 'Handling fee');
      expect(settings.groceryFreeDeliveryThreshold, 249.0);
      expect(settings.cafeFreeDeliveryThreshold, 299.0);
      expect(settings.surgeCharge, 15.0);
      expect(settings.minOrderValue, 50.0);
      expect(settings.deliveryRadiusKm, 7.5);
      expect(settings.groceryMartOpen, isFalse);
      expect(settings.cafeOpen, isTrue);
      expect(settings.restaurantOpen, isFalse);
      expect(settings.supportPhone, '9999888877');
    });

    test('StoreSettings falls back gracefully on null or invalid values', () {
      final json = {
        'delivery_fee': null,
        'grocery_mart_open': null,
        'misc_fee': 'not_a_number',
      };

      final settings = StoreSettings.fromJson(json);

      expect(settings.deliveryFee, 25.0);
      expect(settings.miscFee, 5.0);
      expect(settings.groceryMartOpen, isTrue);
    });
  });
}
