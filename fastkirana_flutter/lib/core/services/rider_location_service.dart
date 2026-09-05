import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'supabase_service.dart';

class RiderLocationService {
  static final RiderLocationService _instance = RiderLocationService._internal();
  factory RiderLocationService() => _instance;
  RiderLocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  String? _activeOrderId;
  String? _activeReadableId;
  List<String> _activeRelatedOrderIds = [];
  String? _riderId;
  DateTime? _lastUploadTime;
  DateTime? _lastDbInsertTime;
  Position? _lastPosition;
  bool _isTracking = false;
  Dio? _dio;
  final Map<String, RealtimeChannel> _activeChannels = {};

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
    String? readableId,
    List<String>? relatedOrderIds,
    Dio? dioClient,
  }) async {
    if (dioClient != null) _dio = dioClient;
    _activeOrderId = orderId;
    _activeReadableId = readableId;
    _activeRelatedOrderIds = relatedOrderIds ?? [];
    _riderId = riderId;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[RiderLocation] Cannot start tracking: permission denied');
      return false;
    }

    if (_isTracking && _positionSubscription != null) {
      debugPrint('[RiderLocation] Already tracking order $_activeOrderId, updated targets ($orderId, $readableId)');
      return true;
    }

    _isTracking = true;
    debugPrint('[RiderLocation] Starting real-time GPS stream for Order #$orderId (Readable: $readableId)');

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

    // Configure foreground service for uninterrupted tracking when screen is off or app is backgrounded
    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Trigger after 1 meter of movement
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FastKirana Delivery Partner 🛵',
          notificationText: 'Sharing live location with customer',
          notificationChannelName: 'Live Delivery Tracking',
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: true,
          setOngoing: true,
          color: Color(0xFFE20A22),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 1,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );
    }

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

    // High-speed responsiveness: broadcast every 1 second or if moved > 1.5 meters
    if (_lastUploadTime != null && _lastPosition != null) {
      final elapsedMs = now.difference(_lastUploadTime!).inMilliseconds;
      final distanceMoved = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (elapsedMs < 1000 && distanceMoved < 1.5) {
        return;
      }
    }

    _lastUploadTime = now;
    _lastPosition = position;

    _sendLocationUpdate(position);
  }

  Set<String> _getChannelKeys() {
    final keys = <String>{};
    void addKey(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      var clean = raw.trim().replaceAll('#', '');
      if (clean.isNotEmpty) {
        keys.add(clean);
        if (clean.startsWith('FK-')) {
          final numOnly = clean.substring(3);
          if (numOnly.isNotEmpty) keys.add(numOnly);
        } else if (RegExp(r'^\d+$').hasMatch(clean)) {
          keys.add('FK-$clean');
        }
      }
    }
    addKey(_activeOrderId);
    addKey(_activeReadableId);
    for (final rel in _activeRelatedOrderIds) {
      addKey(rel);
    }
    return keys;
  }

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

    debugPrint('[RiderLocation] Live GPS: Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}, Heading: ${position.heading.toStringAsFixed(1)}°, Speed: ${position.speed.toStringAsFixed(1)}m/s');

    // 1. Post to /api/delivery/location (throttled to 3s to not overload API while streaming live over WS)
    final now = DateTime.now();
    final shouldPostHttp = _lastDbInsertTime == null || now.difference(_lastDbInsertTime!).inMilliseconds >= 3000;

    if (shouldPostHttp && _dio != null) {
      try {
        _dio!.post(
          '/api/delivery/location',
          data: {
            'lat': position.latitude,
            'lng': position.longitude,
            'orderId': _activeOrderId,
            'readableId': _activeReadableId,
            'riderId': _riderId,
            'heading': position.heading,
            'speed': position.speed,
            'accuracy': position.accuracy,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
            headers: {
              if (_riderId != null) 'x-rider-id': _riderId,
              if (_riderId != null) 'x-user-id': _riderId,
            },
          ),
        ).catchError((e) {
          debugPrint('[RiderLocation] API upload failed: $e');
          _queueOfflineLocation(payload);
          return Response(requestOptions: RequestOptions(path: ''));
        });
      } catch (e) {
        _queueOfflineLocation(payload);
      }
    }

    // 2. Direct Supabase Broadcast & DB Update across all channel aliases
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        final channelKeys = _getChannelKeys();

        for (final key in channelKeys) {
          RealtimeChannel? chan = _activeChannels[key];
          if (chan == null) {
            chan = sb.channel('order-live-tracking-$key');
            chan.subscribe();
            _activeChannels[key] = chan;
          }

          // Instant in-memory WebSocket broadcast (0ms latency to customer app)
          chan.sendBroadcastMessage(
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
        }

        // Direct database record update every 4 seconds
        if (shouldPostHttp && _activeOrderId != null) {
          _lastDbInsertTime = now;
          var cleanId = _activeOrderId!.trim().replaceAll('#', '');

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
          } catch (e, _) { LoggerService.error('RiderLocationService: silent catch', e); }
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

    for (final chan in _activeChannels.values) {
      SupabaseService.unsubscribe(chan);
    }
    _activeChannels.clear();

    _isTracking = false;
    _activeOrderId = null;
    _activeReadableId = null;
    _activeRelatedOrderIds.clear();
    _lastPosition = null;
    _lastUploadTime = null;
  }
}
