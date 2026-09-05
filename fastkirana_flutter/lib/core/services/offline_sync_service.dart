import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class OfflineSyncService {
  static const String queuePicker = 'offline_picker_queue';
  static const String queueRestaurant = 'offline_restaurant_queue';
  static const String queueAdmin = 'offline_admin_queue';
  static const String queueDelivery = 'offline_delivery_queue';

  /// Enqueue an action when device is offline
  static Future<void> enqueueAction({
    required String queueName,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(queueName);
      final List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];

      final item = {
        'id': 'action_${DateTime.now().millisecondsSinceEpoch}_${list.length}',
        'action': action,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      };

      list.add(item);
      await prefs.setString(queueName, jsonEncode(list));
      LoggerService.info('[OfflineSync] Enqueued action in $queueName: $action');
    } catch (e) {
      LoggerService.error('[OfflineSync] Failed to enqueue action: $e');
    }
  }

  /// Get count of pending actions in a queue
  static Future<int> getPendingCount(String queueName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(queueName);
      if (raw == null || raw.isEmpty) return 0;
      final List list = jsonDecode(raw);
      return list.length;
    } catch (e) { LoggerService.error('OfflineSyncService: silent catch', e);
      return 0;
    }
  }

  /// Check if there are pending actions
  static Future<bool> hasPendingActions(String queueName) async {
    final count = await getPendingCount(queueName);
    return count > 0;
  }

  /// Flush/Execute all pending actions in a queue when back online
  static Future<int> flushQueue(
    String queueName,
    Future<bool> Function(Map<String, dynamic> actionItem) executor,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(queueName);
      if (raw == null || raw.isEmpty) return 0;

      final List<dynamic> list = jsonDecode(raw);
      if (list.isEmpty) return 0;

      LoggerService.info('[OfflineSync] Flushing actions from $queueName...');
      final List<dynamic> remaining = [];
      int successful = 0;

      for (final item in list) {
        final map = Map<String, dynamic>.from(item as Map);
        try {
          final ok = await executor(map);
          if (ok) {
            successful++;
          } else {
            remaining.add(map);
          }
        } catch (e) {
          LoggerService.error('[OfflineSync] Error executing action in $queueName: $e');
          remaining.add(map);
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove(queueName);
      } else {
        await prefs.setString(queueName, jsonEncode(remaining));
      }

      LoggerService.info('[OfflineSync] Finished flush for $queueName. Success: $successful, Remaining: ${remaining.length}');
      return successful;
    } catch (e) {
      LoggerService.error('[OfflineSync] Failed to flush queue $queueName: $e');
      return 0;
    }
  }

  /// Clear a specific queue
  static Future<void> clearQueue(String queueName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(queueName);
  }
}
