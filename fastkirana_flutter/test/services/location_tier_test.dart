import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';

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

    test('Dynamic Store Settings: custom tiers from admin console', () {
      final customSettings = StoreSettings.fromJson({
        'delivery_fee_tier1': '30',
        'delivery_threshold_tier1': '249',
        'delivery_fee_tier2': '45',
        'delivery_threshold_tier2': '349',
        'delivery_fee_tier3': '60',
        'delivery_threshold_tier3': '499',
        'delivery_radius': '6.0',
        'store_name': 'Akbarpur Central Hub',
      });

      // Tier 1 custom fee
      final t1Paid = LocationService.getDeliveryTier(1.5, 200.0, settings: customSettings);
      expect(t1Paid.deliveryFee, 30.0);
      expect(t1Paid.freeDeliveryThreshold, 249.0);
      expect(t1Paid.tierName, contains('Akbarpur Central Hub'));

      final t1Free = LocationService.getDeliveryTier(1.5, 250.0, settings: customSettings);
      expect(t1Free.deliveryFee, 0.0);

      // Tier 2 custom fee
      final t2Paid = LocationService.getDeliveryTier(2.5, 300.0, settings: customSettings);
      expect(t2Paid.deliveryFee, 45.0);
      expect(t2Paid.freeDeliveryThreshold, 349.0);

      // Tier 3 custom fee
      final t3Paid = LocationService.getDeliveryTier(4.5, 400.0, settings: customSettings);
      expect(t3Paid.deliveryFee, 60.0);
      expect(t3Paid.freeDeliveryThreshold, 499.0);

      // Outside custom delivery radius (6km)
      final out = LocationService.getDeliveryTier(6.5, 1000.0, settings: customSettings);
      expect(out.isServiceable, isFalse);
    });

    test('Dynamic Surge Charge: adds surge fee on top of base delivery fee when not free', () {
      final surgeSettings = StoreSettings.fromJson({
        'delivery_fee_tier1': '25',
        'delivery_threshold_tier1': '199',
        'surge_charge': '15',
      });

      // Under free delivery threshold: Base ₹25 + Surge ₹15 = ₹40
      final tier1Surge = LocationService.getDeliveryTier(1.0, 100.0, settings: surgeSettings);
      expect(tier1Surge.deliveryFee, 40.0);
      expect(tier1Surge.baseFee, 25.0);
      expect(tier1Surge.surgeFee, 15.0);
      expect(tier1Surge.feeDescription, contains('15 surge'));

      // Above free delivery threshold: Free delivery applies (₹0 delivery fee)
      final tier1Free = LocationService.getDeliveryTier(1.0, 250.0, settings: surgeSettings);
      expect(tier1Free.deliveryFee, 0.0);
    });
  });
}

