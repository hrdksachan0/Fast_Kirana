import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../config/app_config.dart';
import '../network/api_client.dart';
import 'supabase_service.dart';

class RiderLocationService {
  static final RiderLocationService _instance = RiderLocationService._internal();
  factory RiderLocationService() => _instance;
  RiderLocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  String? _activeOrderId;
  String? _riderId;
  DateTime? _lastUploadTime;
  DateTime? _lastDbInsertTime;
  Position? _lastPosition;
  bool _isTracking = false;
  Dio? _dio;

  bool get isTracking => _isTracking;
  String? get activeOrderId => _activeOrderId;

  void setDio(Dio dio) {
    _dio = dio;
  }

  /// Request permissions for location tracking
  static Future<bool> requestPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[RiderLocation] Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[RiderLocation] Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[RiderLocation] Location permissions are permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[RiderLocation] Permission request error: $e');
      return false;
    }
  }

  /// Start live location broadcast for an active delivery
  Future<bool> startTracking({
    required String orderId,
    required String riderId,
    Dio? dioClient,
  }) async {
    if (dioClient != null) _dio = dioClient;
    _activeOrderId = orderId;
    _riderId = riderId;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[RiderLocation] Cannot start tracking: permission denied');
      return false;
    }

    if (_isTracking && _positionSubscription != null) {
      debugPrint('[RiderLocation] Already tracking order $_activeOrderId, updated target to $orderId');
      return true;
    }

    _isTracking = true;
    debugPrint('[RiderLocation] Starting real-time GPS stream for Order #$orderId');

    // Send immediate initial position
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _handleNewPosition(initialPos);
    } catch (e) {
      debugPrint('[RiderLocation] Initial GPS acquisition error: $e');
    }

    // Subscribe to location stream with ultra-responsive 2m distance filter & high accuracy navigation
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Immediate trigger after 2 meters movement
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) => _handleNewPosition(position),
      onError: (error) {
        debugPrint('[RiderLocation] Location stream error: $error');
      },
      cancelOnError: false,
    );

    return true;
  }

  /// Handle incoming GPS fix
  void _handleNewPosition(Position position) {
    final now = DateTime.now();

    // High-speed responsiveness: upload every 1.5 seconds or if moved > 3 meters
    if (_lastUploadTime != null && _lastPosition != null) {
      final elapsedMs = now.difference(_lastUploadTime!).inMilliseconds;
      final distanceMoved = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (elapsedMs < 1500 && distanceMoved < 3) {
        return;
      }
    }

    _lastUploadTime = now;
    _lastPosition = position;

    _sendLocationUpdate(position);
  }

  RealtimeChannel? _trackingChannel;

  /// Broadcast GPS coordinate update to Backend and Supabase Realtime
  Future<void> _sendLocationUpdate(Position position) async {
    final payload = {
      'order_id': _activeOrderId,
      'rider_id': _riderId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint('[RiderLocation] Broadcasting GPS: Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}, Heading: ${position.heading.toStringAsFixed(1)}°');

    // 1. Post to /api/delivery/location
    try {
      if (_dio != null) {
        await _dio!.post(
          '/api/delivery/location',
          data: {
            'lat': position.latitude,
            'lng': position.longitude,
            'orderId': _activeOrderId,
            'riderId': _riderId,
            'heading': position.heading,
            'speed': position.speed,
            'accuracy': position.accuracy,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            headers: {
              if (_riderId != null) 'x-rider-id': _riderId,
              if (_riderId != null) 'x-user-id': _riderId,
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[RiderLocation] API upload failed, queuing for offline sync: $e');
      _queueOfflineLocation(payload);
    }

    // 2. Direct Supabase Broadcast & DB Update
    try {
      final sb = SupabaseService.client;
      if (sb != null && _activeOrderId != null) {
        var cleanId = _activeOrderId!.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

        // Ensure channel is subscribed
        if (_trackingChannel == null) {
          _trackingChannel = sb.channel('order-live-tracking-$cleanId');
          _trackingChannel!.subscribe();
        }

        // Instant in-memory WebSocket broadcast (0ms latency)
        _trackingChannel!.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'lat': position.latitude,
            'lng': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
            'accuracy': position.accuracy,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Update orders table with live deliveryLat & deliveryLng
        final now = DateTime.now();
        if (_lastDbInsertTime == null || now.difference(_lastDbInsertTime!).inSeconds >= 5) {
          _lastDbInsertTime = now;
          sb.from('orders').update({
            'deliveryLat': position.latitude,
            'deliveryLng': position.longitude,
          }).eq('id', cleanId).then((_) {}).catchError((_) {});

          if (_riderId != null && _riderId!.isNotEmpty) {
            sb.from('users').update({
              'liveLat': position.latitude,
              'liveLng': position.longitude,
            }).eq('id', _riderId!).then((_) {}).catchError((_) {});
          }

          sb.from('delivery_locations').insert({
            'order_id': cleanId,
            'rider_id': _riderId,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
            'timestamp': now.toIso8601String(),
          }).then((_) {}).catchError((_) {});
        }
      }
    } catch (e) {
      // Handled silently
    }
  }

  /// Store offline coordinates if network is unavailable
  Future<void> _queueOfflineLocation(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('offline_location_queue') ?? '[]';
      final List<dynamic> queue = jsonDecode(queueStr);
      queue.add(data);
      // Keep queue bounded
      if (queue.length > 50) queue.removeAt(0);
      await prefs.setString('offline_location_queue', jsonEncode(queue));
    } catch (e) {
      debugPrint('[RiderLocation] Failed to queue offline location: $e');
    }
  }

  /// Flush offline queued location updates when connection is restored
  Future<void> syncOfflineLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('offline_location_queue');
      if (queueStr == null || queueStr.isEmpty) return;

      final List<dynamic> queue = jsonDecode(queueStr);
      if (queue.isEmpty) return;

      debugPrint('[RiderLocation] Syncing ${queue.length} offline GPS updates...');
      if (_dio != null) {
        for (final item in queue) {
          try {
            await _dio!.post('/api/delivery/location', data: {
              'lat': item['latitude'] ?? item['lat'],
              'lng': item['longitude'] ?? item['lng'],
              'orderId': item['order_id'],
              'heading': item['heading'],
              'speed': item['speed'],
              'accuracy': item['accuracy'],
            });
          } catch (_) {}
        }
      }
      await prefs.remove('offline_location_queue');
      debugPrint('[RiderLocation] Offline location queue synced successfully.');
    } catch (e) {
      debugPrint('[RiderLocation] Offline sync error: $e');
    }
  }

  /// Stop tracking and cancel GPS stream
  Future<void> stopTracking() async {
    debugPrint('[RiderLocation] Stopping GPS tracking for Order #$_activeOrderId');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (_trackingChannel != null) {
      SupabaseService.unsubscribe(_trackingChannel);
      _trackingChannel = null;
    }
    _isTracking = false;
    _activeOrderId = null;
    _lastPosition = null;
    _lastUploadTime = null;
  }
}
