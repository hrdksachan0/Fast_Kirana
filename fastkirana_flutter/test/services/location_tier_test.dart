import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';

void main() {
  group('Delivery Tier & Distance-Based Fee Tests', () {
    test('Tier 1: 0 to 2 km (Local Ghatampur) - ₹25 fee, free above ₹199', () {
      // Subtotal < ₹199 -> ₹25 fee
      final tier1Paid = LocationService.getDeliveryTier(1.2, 150.0);
      expect(tier1Paid.isServiceable, isTrue);
      expect(tier1Paid.deliveryFee, 25.0);
      expect(tier1Paid.baseFee, 25.0);
      expect(tier1Paid.freeDeliveryThreshold, 199.0);

      // Subtotal >= ₹199 -> Free delivery
      final tier1Free = LocationService.getDeliveryTier(1.2, 200.0);
      expect(tier1Free.isServiceable, isTrue);
      expect(tier1Free.deliveryFee, 0.0);
    });

    test('Tier 2: 2 to 3 km (Suburban Area) - ₹35 fee, free above ₹299', () {
      // Subtotal < ₹299 -> ₹35 fee
      final tier2Paid = LocationService.getDeliveryTier(2.5, 250.0);
      expect(tier2Paid.isServiceable, isTrue);
      expect(tier2Paid.deliveryFee, 35.0);
      expect(tier2Paid.baseFee, 35.0);
      expect(tier2Paid.freeDeliveryThreshold, 299.0);

      // Subtotal >= ₹299 -> Free delivery
      final tier2Free = LocationService.getDeliveryTier(2.5, 300.0);
      expect(tier2Free.isServiceable, isTrue);
      expect(tier2Free.deliveryFee, 0.0);
    });

    test('Tier 3: 3 to 5 km (Extended Area) - ₹50 fee, free above ₹399', () {
      // Subtotal < ₹399 -> ₹50 fee
      final tier3Paid = LocationService.getDeliveryTier(4.2, 350.0);
      expect(tier3Paid.isServiceable, isTrue);
      expect(tier3Paid.deliveryFee, 50.0);
      expect(tier3Paid.baseFee, 50.0);
      expect(tier3Paid.freeDeliveryThreshold, 399.0);

      // Subtotal >= ₹399 -> Free delivery
      final tier3Free = LocationService.getDeliveryTier(4.2, 450.0);
      expect(tier3Free.isServiceable, isTrue);
      expect(tier3Free.deliveryFee, 0.0);
    });

    test('Outside 5 km (Strict Boundary) - Unserviceable', () {
      final unserviceable = LocationService.getDeliveryTier(5.5, 1000.0);
      expect(unserviceable.isServiceable, isFalse);
      expect(unserviceable.deliveryFee, 0.0);
      expect(unserviceable.feeDescription, contains('5.0 km'));
    });
  });
}
