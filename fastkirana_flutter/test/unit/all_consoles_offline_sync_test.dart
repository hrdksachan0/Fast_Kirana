import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/core/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineSyncService Console Queues', () {
    test('Picker Console: enqueues action and flushes successfully', () async {
      // 1. Enqueue action offline
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queuePicker,
        action: 'MARK_PACKED',
        payload: {'orderId': 'ord_101'},
      );

      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queuePicker), isTrue);
      expect(await OfflineSyncService.getPendingCount(OfflineSyncService.queuePicker), equals(1));

      // 2. Reconnect and flush
      final List<String> executedOrders = [];
      final flushed = await OfflineSyncService.flushQueue(
        OfflineSyncService.queuePicker,
        (item) async {
          final payload = item['payload'] as Map<String, dynamic>;
          executedOrders.add(payload['orderId'] as String);
          return true;
        },
      );

      expect(flushed, equals(1));
      expect(executedOrders, equals(['ord_101']));
      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queuePicker), isFalse);
    });

    test('Restaurant Console: enqueues status updates and 86 menu toggles', () async {
      // 1. Enqueue order status
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueRestaurant,
        action: 'UPDATE_ORDER_STATUS',
        payload: {'orderId': 'ord_rest_1', 'nextStatus': 'CONFIRMED', 'prepTime': 20},
      );

      // 2. Enqueue menu toggle
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueRestaurant,
        action: 'TOGGLE_MENU_STOCK',
        payload: {'itemId': 'dish_paneer_butter', 'isAvailable': false},
      );

      expect(await OfflineSyncService.getPendingCount(OfflineSyncService.queueRestaurant), equals(2));

      // 3. Flush on reconnection
      final List<String> processedActions = [];
      final flushed = await OfflineSyncService.flushQueue(
        OfflineSyncService.queueRestaurant,
        (item) async {
          processedActions.add(item['action'] as String);
          return true;
        },
      );

      expect(flushed, equals(2));
      expect(processedActions, containsAll(['UPDATE_ORDER_STATUS', 'TOGGLE_MENU_STOCK']));
      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queueRestaurant), isFalse);
    });

    test('Admin Console: enqueues order status changes and rider assignment', () async {
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueAdmin,
        action: 'ASSIGN_RIDER',
        payload: {'id': 'ord_adm_10', 'riderId': 'rider_sooraj'},
      );

      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queueAdmin), isTrue);

      final flushed = await OfflineSyncService.flushQueue(
        OfflineSyncService.queueAdmin,
        (item) async => true,
      );

      expect(flushed, equals(1));
      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queueAdmin), isFalse);
    });

    test('Retry handling: failed executions remain in queue', () async {
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_DELIVERY_STATUS',
        payload: {'orderId': 'ord_del_1', 'status': 'DELIVERED'},
      );

      // Return false to simulate network server 500 error during flush
      final flushed = await OfflineSyncService.flushQueue(
        OfflineSyncService.queueDelivery,
        (item) async => false,
      );

      expect(flushed, equals(0));
      expect(await OfflineSyncService.hasPendingActions(OfflineSyncService.queueDelivery), isTrue);
      expect(await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery), equals(1));
    });
  });
}
