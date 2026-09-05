import 'package:fastkirana_flutter/core/services/logger_service.dart';
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
      } catch (e) { LoggerService.error('SupabaseService: silent catch', e);
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

      // Listen for direct broadcast events for sub-100ms ultra-fast updates
      channel.onBroadcast(
        event: 'location_update',
        callback: (payload) {
          if (payload.isNotEmpty) {
            final lat = (payload['lat'] ?? payload['latitude']) as num?;
            final lng = (payload['lng'] ?? payload['longitude']) as num?;
            if (lat != null && lng != null) {
              onLocationUpdate({
                'lat': lat.toDouble(),
                'lng': lng.toDouble(),
                'heading': (payload['heading'] as num?)?.toDouble() ?? 0.0,
                'speed': (payload['speed'] as num?)?.toDouble() ?? 0.0,
                'accuracy': (payload['accuracy'] as num?)?.toDouble() ?? 0.0,
                'timestamp': payload['timestamp'] ?? DateTime.now().toIso8601String(),
              });
            }
          }
        },
      );

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

  /// Listen for ALL live order changes in realtime (INSERT, UPDATE, DELETE) over WebSocket for Admin
  static RealtimeChannel? subscribeToAllOrdersRealtime({
    required void Function(Map<String, dynamic> orderRecord) onOrderChange,
  }) {
    final sb = client;
    if (sb == null) return null;

    try {
      final channel = sb.channel('admin-global-orders-websocket');

      // Listen for all Postgres changes on 'orders' table
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
          if (record.isNotEmpty) {
            onOrderChange(record);
          }
        },
      );

      // Listen for direct broadcast events
      channel.onBroadcast(
        event: 'new_order',
        callback: (payload) {
          if (payload.isNotEmpty) {
            onOrderChange(payload);
          }
        },
      );

      channel.subscribe((status, [error]) {
        debugPrint('[SupabaseService] Admin orders WebSocket status: $status (error: $error)');
      });

      return channel;
    } catch (e) {
      debugPrint('[SupabaseService] Global orders subscribe error: $e');
      return null;
    }
  }

  static final Map<String, RealtimeChannel> _activeBroadcastChannels = {};

  /// Broadcast rider GPS location to customer order tracking screen (called by delivery app/rider flow)
  static Future<void> broadcastRiderLocation({
    required String orderId,
    required double lat,
    required double lng,
    double heading = 0.0,
    double speed = 0.0,
  }) async {
    final sb = client;
    if (sb == null) return;
    try {
      final channelName = 'order-live-tracking-$orderId';
      final channel = _activeBroadcastChannels.putIfAbsent(
        channelName,
        () => sb.channel(channelName)..subscribe(),
      );
      await channel.sendBroadcastMessage(
        event: 'location_update',
        payload: {
          'lat': lat,
          'lng': lng,
          'heading': heading,
          'speed': speed,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[SupabaseService] broadcastRiderLocation error: $e');
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
