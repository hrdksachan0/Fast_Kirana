import 'package:fastminute_flutter/core/services/logger_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'supabase_service.dart';

/// Operational modes for Rider GPS tracking
enum RiderTrackingMode {
  stopped,
  idle,
  activeOrder,
}

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
  RiderTrackingMode _trackingMode = RiderTrackingMode.stopped;
  Dio? _dio;
  final Map<String, RealtimeChannel> _activeChannels = {};

  bool get isTracking => _trackingMode != RiderTrackingMode.stopped;
  bool get isTrackingActiveOrder => _trackingMode == RiderTrackingMode.activeOrder;
  bool get isTrackingIdle => _trackingMode == RiderTrackingMode.idle;
  RiderTrackingMode get trackingMode => _trackingMode;
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

  /// Mode A: High-Precision Live Delivery Tracking (5-7 seconds interval)
  /// Used when rider is actively delivering an order to a customer.
  Future<bool> startTracking({
    required String orderId,
    required String riderId,
    String? readableId,
    List<String>? relatedOrderIds,
    Dio? dioClient,
  }) async {
    if (dioClient != null) _dio = dioClient;

    // If already in active order tracking for the same order, just refresh target aliases
    if (_trackingMode == RiderTrackingMode.activeOrder && _activeOrderId == orderId) {
      _activeReadableId = readableId;
      _activeRelatedOrderIds = relatedOrderIds ?? [];
      _riderId = riderId;
      return true;
    }

    // Cancel any existing idle or previous order subscription
    await _cancelPositionSubscriptionOnly();

    _activeOrderId = orderId;
    _activeReadableId = readableId;
    _activeRelatedOrderIds = relatedOrderIds ?? [];
    _riderId = riderId;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[RiderLocation] Cannot start active tracking: permission denied');
      _trackingMode = RiderTrackingMode.stopped;
      return false;
    }

    _trackingMode = RiderTrackingMode.activeOrder;
    debugPrint('[RiderLocation] Starting High-Precision Active GPS (5-7s) for Order #$orderId (Readable: $readableId)');

    // Immediate initial GPS fix
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      _handleNewPosition(initialPos);
    } catch (e) {
      debugPrint('[RiderLocation] Initial GPS acquisition: $e');
    }

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 6, // 6 meters threshold for active route tracking
        intervalDuration: const Duration(seconds: 5), // 5 seconds hardware interval
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'FastMinute Delivery Partner 🛵',
          notificationText: 'Live GPS Active: Delivering Order #${readableId ?? orderId}',
          notificationChannelName: 'Live Delivery Tracking',
          notificationIcon: const AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: true,
          setOngoing: true,
          color: const Color(0xFFE20A22),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 6,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 6,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) => _handleNewPosition(position),
      onError: (error) {
        debugPrint('[RiderLocation] Active location stream error: $error');
      },
      cancelOnError: false,
    );

    return true;
  }

  /// Mode B: Ultra Battery-Optimized Idle Tracking (100m Distance Filter)
  /// Used when rider is ON DUTY / Online, but waiting for new orders.
  /// Prevents battery drain by allowing phone CPU to sleep until moving 100+ meters.
  Future<bool> startIdleTracking({
    required String riderId,
    Dio? dioClient,
  }) async {
    if (dioClient != null) _dio = dioClient;

    if (_trackingMode == RiderTrackingMode.idle && _riderId == riderId) {
      return true; // Already running in idle mode
    }

    // Cancel active order subscription and close order-specific channels
    await _cancelPositionSubscriptionOnly();
    _clearActiveChannels();

    _activeOrderId = null;
    _activeReadableId = null;
    _activeRelatedOrderIds.clear();
    _riderId = riderId;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[RiderLocation] Cannot start idle tracking: permission denied');
      _trackingMode = RiderTrackingMode.stopped;
      return false;
    }

    _trackingMode = RiderTrackingMode.idle;
    debugPrint('[RiderLocation] Starting Battery-Optimized Idle Tracking (100m filter) for Rider #$riderId');

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.medium, // Cell/WiFi + coarse GPS (drastically lowers power)
        distanceFilter: 100, // Trigger only after 100 meters of actual movement
        intervalDuration: const Duration(seconds: 60), // Check at most once a minute
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FastMinute Delivery Partner 🛵',
          notificationText: 'Online & Waiting for orders (Battery Saver Active)',
          notificationChannelName: 'Live Delivery Tracking',
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: false, // Allow device CPU deep sleep
          setOngoing: true,
          color: Color(0xFF16A34A),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.medium,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 100,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) => _handleNewPosition(position),
      onError: (error) {
        debugPrint('[RiderLocation] Idle location stream error: $error');
      },
      cancelOnError: false,
    );

    return true;
  }

  /// Handle incoming GPS fix according to active operational mode
  void _handleNewPosition(Position position) {
    final now = DateTime.now();

    if (_trackingMode == RiderTrackingMode.idle) {
      // IDLE MODE: Throttled to 60s or >= 80m movement
      if (_lastUploadTime != null && _lastPosition != null) {
        final elapsedMs = now.difference(_lastUploadTime!).inMilliseconds;
        final distanceMoved = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (elapsedMs < 45000 && distanceMoved < 80.0) {
          return;
        }
      }

      _lastUploadTime = now;
      _lastPosition = position;
      _sendIdleLocationUpdate(position);
      return;
    }

    if (_trackingMode == RiderTrackingMode.activeOrder) {
      // ACTIVE ORDER MODE: 5-7 seconds interval when moving, 15s when stationary
      final isStationary = position.speed < 0.8; // < 0.8 m/s (~2.8 km/h)

      if (_lastUploadTime != null && _lastPosition != null) {
        final elapsedMs = now.difference(_lastUploadTime!).inMilliseconds;
        final distanceMoved = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        final requiredIntervalMs = isStationary ? 15000 : 5000;
        final minDistanceMeters = isStationary ? 10.0 : 5.0;

        if (elapsedMs < requiredIntervalMs && distanceMoved < minDistanceMeters) {
          return;
        }
      }

      _lastUploadTime = now;
      _lastPosition = position;
      _sendActiveLocationUpdate(position);
    }
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

  /// Broadcast Active Order GPS update (Realtime WebSocket + DB)
  Future<void> _sendActiveLocationUpdate(Position position) async {
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

    debugPrint('[RiderLocation] Active GPS (5s): Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}, Speed: ${position.speed.toStringAsFixed(1)}m/s');

    // 1. Instant WebSocket Broadcast via Supabase Channels (0ms lag for customer animation)
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
      }
    } catch (e) {
      // WebSocket failover handled silently
    }

    // 2. HTTP Backend update & DB Persist (throttled to 5s moving / 15s stationary)
    final now = DateTime.now();
    final isStationary = position.speed < 0.8;
    final minHttpIntervalMs = isStationary ? 15000 : 5000;
    final shouldPostHttp = _lastDbInsertTime == null || now.difference(_lastDbInsertTime!).inMilliseconds >= minHttpIntervalMs;

    if (shouldPostHttp) {
      _lastDbInsertTime = now;

      if (_dio != null) {
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
          debugPrint('[RiderLocation] Active location API error: $e');
          _queueOfflineLocation(payload);
          return Response(requestOptions: RequestOptions(path: ''));
        });
      }

      // Direct Supabase table sync
      try {
        final sb = SupabaseService.client;
        if (sb != null && _activeOrderId != null) {
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
      } catch (_) {}
    }
  }

  /// Broadcast Idle Location update (Only updates rider presence for dispatching)
  Future<void> _sendIdleLocationUpdate(Position position) async {
    debugPrint('[RiderLocation] Idle GPS (100m): Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}');

    // Update rider presence in Supabase users table
    try {
      final sb = SupabaseService.client;
      if (sb != null && _riderId != null && _riderId!.isNotEmpty) {
        sb.from('users').update({
          'liveLat': position.latitude,
          'liveLng': position.longitude,
        }).eq('id', _riderId!).then((_) {}).catchError((_) {});
      }
    } catch (_) {}

    // Update backend dispatcher
    if (_dio != null && _riderId != null) {
      _dio!.post(
        '/api/delivery/location',
        data: {
          'lat': position.latitude,
          'lng': position.longitude,
          'riderId': _riderId,
          'idle': true,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          headers: {'x-rider-id': _riderId},
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));
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
          } catch (e, _) { LoggerService.error('RiderLocationService: error', e); }
        }
      }
      await prefs.remove('offline_location_queue');
      debugPrint('[RiderLocation] Offline location queue synced successfully.');
    } catch (e) {
      debugPrint('[RiderLocation] Offline sync error: $e');
    }
  }

  Future<void> _cancelPositionSubscriptionOnly() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _clearActiveChannels() {
    for (final chan in _activeChannels.values) {
      SupabaseService.unsubscribe(chan);
    }
    _activeChannels.clear();
  }

  /// Stop all tracking and release GPS completely
  Future<void> stopTracking() async {
    debugPrint('[RiderLocation] Stopping all GPS tracking');
    await _cancelPositionSubscriptionOnly();
    _clearActiveChannels();

    _trackingMode = RiderTrackingMode.stopped;
    _activeOrderId = null;
    _activeReadableId = null;
    _activeRelatedOrderIds.clear();
    _lastPosition = null;
    _lastUploadTime = null;
    _lastDbInsertTime = null;
  }
}
