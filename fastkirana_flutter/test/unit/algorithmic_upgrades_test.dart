import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/utils/fuzzy_matcher.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';

void main() {
  group('1. Damerau-Levenshtein Fuzzy Search Algorithm Tests', () {
    test('Exact matches should have distance 0 and similarity 100', () {
      expect(FuzzyMatcher.damerauLevenshtein('maggi', 'maggi'), 0);
      expect(FuzzyMatcher.damerauLevenshtein('milk', 'milk'), 0);
      expect(FuzzyMatcher.similarityScore('paneer', 'paneer'), 100);
    });

    test('Common Indian grocery typos should be detected with distance <= 2', () {
      // 1 edit distance
      expect(FuzzyMatcher.damerauLevenshtein('magi', 'maggi'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('layz', 'lays'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('dodh', 'doodh'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('ata', 'atta'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('aashirvad', 'aashirvaad'), 1);

      // Transposition (Damerau feature: amlu -> amul)
      expect(FuzzyMatcher.damerauLevenshtein('amlu', 'amul'), 1);

      // 2 edit distance
      expect(FuzzyMatcher.damerauLevenshtein('tmatr', 'tamatar'), 2);
    });

    test('Early-exit pruning triggers when distance exceeds maxDistance', () {
      // "computer" vs "atta" length difference is 4 > maxDistance 2
      final dist = FuzzyMatcher.damerauLevenshtein('computer', 'atta', maxDistance: 2);
      expect(dist > 2, isTrue);
    });

    test('bestTokenFuzzyDistance correctly identifies typos in multi-word product names', () {
      const prodName = 'Amul Taaza Homogenised Toned Milk 1L';

      // Typo "amlu" should match "Amul" with distance 1 (transposition)
      final distAmul = FuzzyMatcher.bestTokenFuzzyDistance('amlu', prodName, maxDistance: 2);
      expect(distAmul, 1);

      // Typo "taza" should match "Taaza" with distance 1
      final distTaaza = FuzzyMatcher.bestTokenFuzzyDistance('taza', prodName, maxDistance: 2);
      expect(distTaaza, 1);

      // Typo "mlik" should match "Milk" with distance 1 (transposition)
      final distMilk = FuzzyMatcher.bestTokenFuzzyDistance('mlik', prodName, maxDistance: 2);
      expect(distMilk, 1);

      // Irrelevant query word should return null
      final distPhone = FuzzyMatcher.bestTokenFuzzyDistance('iphone', prodName, maxDistance: 2);
      expect(distPhone, isNull);
    });

    test('isFuzzyMatch uses adaptive length thresholds', () {
      // Short word <= 4 chars allows max 1 edit
      expect(FuzzyMatcher.isFuzzyMatch('ata', 'atta'), isTrue);
      // Very short word <= 2 chars returns false to avoid false positives
      expect(FuzzyMatcher.isFuzzyMatch('a', 'atta'), isFalse);
    });
  });

  group('2. Real-Time Dynamic ETA & Elastic Surge Pricing Algorithm Tests', () {
    test('Standard grocery order within 1.5 km should have fast 8-12 min ETA', () {
      final normalTime = DateTime(2026, 9, 20, 15, 30); // 3:30 PM (non-rush)
      final eta = LocationService.calculateDynamicEta(
        distanceKm: 1.2,
        pendingOrders: 0,
        activePickers: 2,
        isRestaurant: false,
        now: normalTime,
      );

      expect(eta.minMinutes, inInclusiveRange(8, 10));
      expect(eta.maxMinutes, inInclusiveRange(10, 14));
      expect(eta.displayLabel, contains('8-12 mins'));
      expect(eta.isRushHour, isFalse);
      expect(eta.isHighDemand, isFalse);
    });

    test('Dinner rush hour should apply traffic multiplier and peak label', () {
      final dinnerRush = DateTime(2026, 9, 20, 20, 15); // 8:15 PM (Dinner rush)
      final eta = LocationService.calculateDynamicEta(
        distanceKm: 3.5,
        pendingOrders: 8,
        activePickers: 2,
        isRestaurant: false,
        now: dinnerRush,
      );

      expect(eta.isRushHour, isTrue);
      expect(eta.isHighDemand, isTrue);
      expect(eta.surgeMultiplier, 1.25);
      expect(eta.displayLabel, contains('High Demand'));
    });

    test('Restaurant delivery accounts for 15-minute kitchen preparation time', () {
      final normalTime = DateTime(2026, 9, 20, 16, 0); // 4:00 PM
      final eta = LocationService.calculateDynamicEta(
        distanceKm: 2.0,
        pendingOrders: 2,
        activePickers: 2,
        isRestaurant: true,
        now: normalTime,
      );

      // Restaurant base prep is 15 mins, so minMinutes should be >= 15
      expect(eta.minMinutes, greaterThanOrEqualTo(15));
      expect(eta.maxMinutes, greaterThan(eta.minMinutes));
    });

    test('getDeliveryTier includes dynamic ETA metadata in DeliveryTierInfo', () {
      final tier = LocationService.getDeliveryTier(
        1.5,
        250.0,
        pendingOrders: 2,
        isRestaurant: false,
      );

      expect(tier.isServiceable, isTrue);
      expect(tier.eta.minMinutes, greaterThan(0));
      expect(tier.eta.displayLabel, isNotEmpty);
    });
  });
}
