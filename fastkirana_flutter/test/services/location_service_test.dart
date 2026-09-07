import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';
import 'package:fastkirana_flutter/core/config/app_config.dart';

void main() {
  group('LocationService: Distance & Delivery Tier', () {
    setUp(() {
      // Reset AppConfig to default Ghatampur coords before each test
      AppConfig.updateDarkstore(
        lat: 26.1534185,
        lng: 80.1714024,
        address: 'Ghatampur Market, Kanpur Nagar, UP - 209206',
      );
    });

    group('Tier 1: 0 to 2 km (Local)', () {
      test('subtotal below threshold charges ₹25', () {
        final tier = LocationService.getDeliveryTier(1.2, 150.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 25.0);
        expect(tier.baseFee, 25.0);
        expect(tier.freeDeliveryThreshold, 199.0);
        expect(tier.tierName, contains('2 km'));
      });

      test('subtotal at threshold gets free delivery', () {
        final tier = LocationService.getDeliveryTier(1.2, 199.0);
        expect(tier.deliveryFee, 0.0);
      });

      test('subtotal above threshold gets free delivery', () {
        final tier = LocationService.getDeliveryTier(1.2, 250.0);
        expect(tier.deliveryFee, 0.0);
      });
    });

    group('Tier 2: 2 to 3 km (Suburban)', () {
      test('subtotal below threshold charges ₹35', () {
        final tier = LocationService.getDeliveryTier(2.5, 200.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 35.0);
        expect(tier.baseFee, 35.0);
        expect(tier.freeDeliveryThreshold, 299.0);
      });

      test('subtotal at threshold gets free delivery', () {
        final tier = LocationService.getDeliveryTier(2.5, 299.0);
        expect(tier.deliveryFee, 0.0);
      });
    });

    group('Tier 3: 3 to 5 km (Extended)', () {
      test('subtotal below threshold charges ₹50', () {
        final tier = LocationService.getDeliveryTier(4.2, 300.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 50.0);
        expect(tier.baseFee, 50.0);
        expect(tier.freeDeliveryThreshold, 399.0);
      });

      test('subtotal at threshold gets free delivery', () {
        final tier = LocationService.getDeliveryTier(4.2, 399.0);
        expect(tier.deliveryFee, 0.0);
      });
    });

    group('Dynamic radius (maxRadius parameter)', () {
      test('hub with 8km radius makes 6km serviceable', () {
        final tier = LocationService.getDeliveryTier(6.0, 300.0, maxRadius: 8.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.tierName, contains('8 km'));
      });

      test('hub with 3km radius makes 4km unserviceable', () {
        final tier = LocationService.getDeliveryTier(4.0, 300.0, maxRadius: 3.0);
        expect(tier.isServiceable, isFalse);
        expect(tier.deliveryFee, 0.0);
      });

      test('default radius is 5.0 when maxRadius is null', () {
        final tier = LocationService.getDeliveryTier(5.5, 300.0);
        expect(tier.isServiceable, isFalse);
        expect(tier.tierName, contains('5 km'));
      });
    });

    group('Boundary values', () {
      test('exactly 2.0 km is in Tier 1', () {
        final tier = LocationService.getDeliveryTier(2.0, 150.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 25.0);
      });

      test('exactly 3.0 km is in Tier 2', () {
        final tier = LocationService.getDeliveryTier(3.0, 200.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 35.0);
      });

      test('exactly 5.0 km with default radius is in Tier 3', () {
        final tier = LocationService.getDeliveryTier(5.0, 300.0);
        expect(tier.isServiceable, isTrue);
        expect(tier.deliveryFee, 50.0);
      });

      test('just over 5.0 km with default radius is unserviceable', () {
        final tier = LocationService.getDeliveryTier(5.01, 300.0);
        expect(tier.isServiceable, isFalse);
      });
    });

    group('getDistanceKm with dynamic hub', () {
      test('uses AppConfig by default', () {
        final dist = LocationService.getDistanceKm(
          AppConfig.darkstoreLat + 0.01,
          AppConfig.darkstoreLng + 0.01,
        );
        expect(dist, greaterThan(0.0));
        expect(dist, lessThan(5.0));
      });

      test('zero distance when coordinates match hub', () {
        final dist = LocationService.getDistanceKm(
          AppConfig.darkstoreLat,
          AppConfig.darkstoreLng,
        );
        expect(dist, closeTo(0.0, 0.001));
      });
    });
  });
}
