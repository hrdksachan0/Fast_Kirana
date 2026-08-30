import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  static SupabaseClient? get client {
    if (_isInitialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return _client;
      }
    }
    return _client;
  }

  /// Initialize Supabase client
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('[SupabaseService] Initialized successfully with Realtime');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization warning/error: $e');
    }
  }

  /// Listen for live rider location updates for a specific order
  /// Subscribes to postgres_changes on delivery_locations and orders tables
  static RealtimeChannel? subscribeToOrderLocation({
    required String orderId,
    required void Function(Map<String, dynamic> locationData) onLocationUpdate,
    void Function(String newStatus)? onStatusUpdate,
  }) {
    final sb = client;
    if (sb == null) return null;

    try {
      final channelName = 'order-live-tracking-$orderId';
      final channel = sb.channel(channelName);

      // Listen for delivery_locations INSERT/UPDATE for this order
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'delivery_locations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_id',
          value: orderId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            onLocationUpdate({
              'lat': (record['latitude'] as num?)?.toDouble(),
              'lng': (record['longitude'] as num?)?.toDouble(),
              'heading': (record['heading'] as num?)?.toDouble() ?? 0.0,
              'speed': (record['speed'] as num?)?.toDouble() ?? 0.0,
              'accuracy': (record['accuracy'] as num?)?.toDouble() ?? 0.0,
              'timestamp': record['timestamp'] ?? record['created_at'],
            });
          }
        },
      );

      // Listen for order status changes
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: orderId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            final status = record['status']?.toString();
            if (status != null && onStatusUpdate != null) {
              onStatusUpdate(status);
            }
            final liveLat = (record['deliveryLat'] as num?)?.toDouble();
            final liveLng = (record['deliveryLng'] as num?)?.toDouble();
            if (liveLat != null && liveLng != null) {
              onLocationUpdate({
                'lat': liveLat,
                'lng': liveLng,
                'heading': 0.0,
                'speed': 0.0,
                'accuracy': 0.0,
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
          }
        },
      );

      channel.subscribe((status, [error]) {
        debugPrint('[SupabaseService] Realtime channel $channelName status: $status (error: $error)');
      });

      return channel;
    } catch (e) {
      debugPrint('[SupabaseService] Subscribe error: $e');
      return null;
    }
  }

  /// Unsubscribe and remove channel
  static Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null && client != null) {
      try {
        await client!.removeChannel(channel);
      } catch (e) {
        debugPrint('[SupabaseService] Remove channel error: $e');
      }
    }
  }
}
