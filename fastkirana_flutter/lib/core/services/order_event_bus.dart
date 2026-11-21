// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FastMinute Unified Order Event Bus (Flutter Singleton)
// Single stream pipeline combining Supabase Realtime + FCM Push events with
// automatic version-based deduplication and topic-based filtering.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_event.dart';

class OrderEventBus {
  OrderEventBus._();
  static final OrderEventBus instance = OrderEventBus._();

  final StreamController<OrderEvent> _controller = StreamController<OrderEvent>.broadcast();

  /// Global broadcast stream of all incoming order events
  Stream<OrderEvent> get stream => _controller.stream;

  /// In-memory version tracker per orderId to drop stale out-of-order or duplicate packets
  final Map<String, int> _lastSeenVersions = {};

  /// Filter stream for a specific order (matches CUID, readableId, displayId, or combinedId)
  Stream<OrderEvent> forOrder(String targetId) {
    final clean = targetId.replaceAll('#', '').trim().toLowerCase();
    return stream.where((event) {
      if (clean.isEmpty) return false;
      return event.orderId.toLowerCase() == clean ||
          event.readableId.toLowerCase() == clean ||
          event.displayId.toLowerCase() == clean ||
          (event.combinedId != null && event.combinedId!.toLowerCase() == clean) ||
          event.readableId.toLowerCase().startsWith(clean);
    });
  }

  /// Filter stream for a specific darkstore hub
  Stream<OrderEvent> forStore(String? storeId) {
    if (storeId == null || storeId.isEmpty) return stream;
    final cleanStore = storeId.toLowerCase().trim();
    return stream.where((event) {
      if (event.storeId == null || event.storeId!.isEmpty) return true;
      return event.storeId!.toLowerCase() == cleanStore;
    });
  }

  /// Filter stream for a specific role (CUSTOMER, ADMIN, PICKER, RIDER, KITCHEN)
  Stream<OrderEvent> forRole(String role) {
    final cleanRole = role.toUpperCase().trim();
    return stream.where((event) {
      if (event.targets.isEmpty) return true;
      return event.targets.contains(cleanRole);
    });
  }

  /// Ingest an OrderEvent envelope from any source (Supabase WebSocket or FCM push)
  void ingest(OrderEvent event) {
    if (event.orderId.isEmpty) return;

    // Strict Version Deduplication: Drop duplicate / older packets
    final lastV = _lastSeenVersions[event.orderId] ?? 0;
    if (event.version > 0 && event.version <= lastV) {
      debugPrint('[OrderEventBus] Dropped duplicate/older event for order #${event.displayId} (v=${event.version} <= $lastV)');
      return;
    }

    _lastSeenVersions[event.orderId] = event.version;
    if (event.readableId.isNotEmpty) {
      _lastSeenVersions[event.readableId] = event.version;
    }
    if (event.displayId.isNotEmpty) {
      _lastSeenVersions[event.displayId] = event.version;
    }

    debugPrint('[OrderEventBus] 🚀 Ingested tag=${event.tag} order=#${event.displayId} status=${event.status} urgency=${event.alert.urgency}');
    _controller.add(event);
  }

  /// Ingest directly from Supabase broadcast payload
  void ingestFromSupabasePayload(Map<String, dynamic> payload) {
    try {
      final envelopeMap = payload['envelope'] is Map<String, dynamic>
          ? payload['envelope'] as Map<String, dynamic>
          : payload;
      final event = OrderEvent.fromMap(envelopeMap);
      ingest(event);
    } catch (e) {
      debugPrint('[OrderEventBus] Error parsing Supabase broadcast: $e');
    }
  }

  /// Ingest directly from FCM RemoteMessage data
  void ingestFromFCMData(Map<String, dynamic> data) {
    try {
      final event = OrderEvent.fromFCMData(data);
      ingest(event);
    } catch (e) {
      debugPrint('[OrderEventBus] Error parsing FCM data: $e');
    }
  }
}
