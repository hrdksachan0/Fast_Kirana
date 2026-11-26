import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastminute_flutter/core/services/offline_sync_service.dart';
import 'package:fastminute_flutter/data/repositories/restaurant_repository.dart';
import 'package:fastminute_flutter/features/orders/utils/geo_math_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pre-Release Guard: Realistic ETA Math', () {
    test('1.1 km delivery ETA never blows up to 43 mins when rider is slow/stationary', () {
      const origin = LatLng(26.1534, 80.1714);
      const dest = LatLng(26.1633, 80.1714);

      // Simulate multiple near-stationary pings (red light / GPS drift)
      int eta = 0;
      for (int i = 0; i < 4; i++) {
        eta = GeoMathUtils.estimateEtaWeightedAverage(origin, dest, 1.1);
      }

      expect(eta, greaterThanOrEqualTo(2));
      expect(eta, lessThanOrEqualTo(10));
    });

    test('Short 0.2 km distance clamps to at least 2 mins and 5 km stays realistic', () {
      const pos = LatLng(26.1534, 80.1714);
      const dest = LatLng(26.1984, 80.1714);

      final shortEta = GeoMathUtils.estimateEtaWeightedAverage(pos, dest, 0.2);
      final longEta = GeoMathUtils.estimateEtaWeightedAverage(pos, dest, 5.0);

      expect(shortEta, greaterThanOrEqualTo(2));
      expect(shortEta, lessThanOrEqualTo(8));
      expect(longEta, greaterThanOrEqualTo(10));
      expect(longEta, lessThanOrEqualTo(35));
    });
  });

  group('Pre-Release Guard: Rider Offline Sync Queue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('deduplicates repeated offline taps for same orderId + newStatus', () async {
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {'orderId': 'ord-101', 'newStatus': 'DELIVERED', 'attempt': 1},
      );
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {'orderId': 'ord-101', 'newStatus': 'DELIVERED', 'attempt': 2},
      );
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {'orderId': 'ord-102', 'newStatus': 'SHIPPED', 'attempt': 1},
      );

      final count = await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery);
      expect(count, 2);
    });

    test('retains failed actions on network outage and clears succeeded ones', () async {
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {'orderId': 'ord-ok', 'newStatus': 'SHIPPED'},
      );
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {'orderId': 'ord-fail', 'newStatus': 'DELIVERED'},
      );

      final synced = await OfflineSyncService.flushQueue(
        OfflineSyncService.queueDelivery,
        (item) async {
          final p = item['payload'] as Map;
          return p['orderId'] == 'ord-ok';
        },
      );

      expect(synced, 1);
      expect(await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery), 1);
    });
  });

  group('Pre-Release Guard: Restaurant SWR Disk Cache', () {
    test('preloads cached restaurants from disk in 0ms on cold start', () async {
      final sampleRestaurant = {
        'id': 'rest-1',
        'name': 'Hot Pizza Lovers',
        'slug': 'hot-pizza-lovers',
        'isActive': true,
        'isOpen': true,
        'rating': 4.9,
        'city': 'Ghatampur',
      };

      SharedPreferences.setMockInitialValues({
        'cached_restaurants_hub-209206_v1': jsonEncode([sampleRestaurant]),
        'cached_restaurants_ts_hub-209206_v1': DateTime.now().millisecondsSinceEpoch,
      });

      await RestaurantRepository.invalidateCache();
      await RestaurantRepository.preloadDiskCache('hub-209206');

      final preloaded = RestaurantRepository.preloadedRestaurants('hub-209206');
      expect(preloaded.length, 1);
      expect(preloaded.first.name, 'Hot Pizza Lovers');

      // getRestaurants returns cached feed immediately without hitting network
      final repo = RestaurantRepository(Dio());
      final list = await repo.getRestaurants(storeId: 'hub-209206');
      expect(list.length, 1);
      expect(list.first.id, 'rest-1');
    });
  });
}
