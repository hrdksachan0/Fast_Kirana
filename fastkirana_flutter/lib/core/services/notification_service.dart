import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

// Top-level background message handler for when app is killed or phone screen is off
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final notification = message.notification;
  final data = message.data;
  final title = notification?.title ?? data['title'] ?? '⚡ FastKirana Express';
  final body = notification?.body ?? data['body'] ?? data['message'];

  // If received as data-only message in background, manually trigger system notification
  if (body != null && notification == null) {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInit);
      await localNotifications.initialize(initSettings);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'fastkirana_alerts',
        'FastKirana Alerts',
        channelDescription: 'Notifications for order updates and tracking.',
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      await localNotifications.show(
        message.hashCode,
        title.toString(),
        body.toString(),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fastkirana_alerts',
            'FastKirana Alerts',
            channelDescription: 'Notifications for order updates and tracking.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            when: DateTime.now().millisecondsSinceEpoch,
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: data.toString(),
      );
    } catch (e) {
      print("Background notification show error: $e");
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? get _fcm {
    if (kIsWeb) return null;
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  FlutterLocalNotificationsPlugin? get _localNotifications {
    if (kIsWeb) return null;
    try {
      return FlutterLocalNotificationsPlugin();
    } catch (_) {
      return null;
    }
  }

  bool _initialized = false;

  // In-memory preference cache (loaded from SharedPreferences on init)
  final Map<String, bool> _prefs = {
    'order_updates': true,
    'offers_promos': true,
    'delivery_alerts': true,
  };

  // Stream controller to broadcast preference changes
  final _prefsController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get prefsStream => _prefsController.stream;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      // 1. Load persisted preferences
      final prefs = await SharedPreferences.getInstance();
      _prefs['order_updates'] = prefs.getBool('notif_order_updates') ?? true;
      _prefs['offers_promos'] = prefs.getBool('notif_offers_promos') ?? true;
      _prefs['delivery_alerts'] = prefs.getBool('notif_delivery_alerts') ?? true;

      // 2. Request runtime notification permissions explicitly
      try {
        await _fcm?.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          criticalAlert: true,
          provisional: false,
        );
        await _localNotifications
            ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}

      // 3. Setup local notification channel for Android with MAX priority
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fastkirana_alerts',
        'FastKirana Alerts',
        description: 'Notifications for order updates and tracking.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Initialize Local Notifications Plugin
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications?.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print("Notification tapped: ${details.payload}");
        },
      );

      // 5. Handle Foreground Messages with exact current timestamp
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // 6. Handle App Opened from Notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("App opened from notification: ${message.data}");
      });

      // 7. Auto-save refreshed tokens for re-registration
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        print("FCM token refreshed: ${newToken.substring(0, 20)}...");
        await prefs.setString('pending_fcm_token', newToken);
      });

      // 8. Auto-subscribe to broadcast topics
      try {
        await _fcm?.subscribeToTopic('all_users');
        await _fcm?.subscribeToTopic('ghatampur_alerts');
        final savedPhone = prefs.getString('user_phone') ?? '';
        final clean = savedPhone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (clean.length == 10) {
          await _fcm?.subscribeToTopic('phone_$clean');
        }
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null && savedUserId.isNotEmpty) {
          await _fcm?.subscribeToTopic('user_$savedUserId');
        }
      } catch (e) {
        print("Topic subscription error: $e");
      }

      _initialized = true;
    } catch (e) {
      print("Error initializing NotificationService: $e");
    }
  }

  final Set<String> _recentMessageIds = {};

  void _handleForegroundMessage(RemoteMessage message) {
    final msgId = message.messageId ?? '${message.sentTime?.millisecondsSinceEpoch}_${message.data['orderId']}';
    if (_recentMessageIds.contains(msgId)) {
      return; // Dedup across simultaneous topic and token multicast
    }
    _recentMessageIds.add(msgId);
    if (_recentMessageIds.length > 50) {
      _recentMessageIds.remove(_recentMessageIds.first);
    }

    final title = message.notification?.title ?? message.data['title'] ?? '⚡ FastKirana Express';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'];

    if (body != null && body.toString().trim().isNotEmpty) {
      final data = message.data;
      final category = data['category'] as String? ?? 'order';
      if (!_shouldShowNotification(category)) {
        print("Notification suppressed by user preference: $category");
        return;
      }

      _localNotifications?.show(
        message.hashCode,
        title.toString(),
        body.toString(),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fastkirana_alerts',
            'FastKirana Alerts',
            channelDescription: 'Notifications for order updates and tracking.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            when: DateTime.now().millisecondsSinceEpoch,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  bool _shouldShowNotification(String category) {
    switch (category) {
      case 'order':
        return _prefs['order_updates'] ?? true;
      case 'offer':
        return _prefs['offers_promos'] ?? true;
      case 'delivery':
        return _prefs['delivery_alerts'] ?? true;
      default:
        return true;
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      await _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      NotificationSettings? settings = await _fcm?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print("FCM permission status: ${settings?.authorizationStatus}");
    } catch (e) {
      print("Error requesting FCM permissions: $e");
    }
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) return null;
    try {
      return await _fcm?.getToken();
    } catch (e) {
      print("Error getting FCM token: $e");
      return null;
    }
  }

  Future<void> refreshAndRegisterToken(Dio dio) async {
    if (kIsWeb) return;
    try {
      String? token = await _fcm?.getToken();
      if (token == null) return;

      String? authToken = await SecureStorage.read('auth_token');

      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_fcm_token', token);
        return;
      }

      String deviceType = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'));

      final response = await dio.post(
        '/api/fcm/register',
        data: {'token': token, 'deviceType': deviceType},
      );

      if (response.statusCode == 200) {
        print("FCM Token refreshed successfully!");
        final p = await SharedPreferences.getInstance();
        await p.remove('pending_fcm_token');
      }
    } catch (e) {
      print("Error refreshing FCM token: $e");
    }
  }

  Future<void> registerDeviceToken(Dio dio) async {
    if (kIsWeb) return;
    try {
      String? token = await getFcmToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      String deviceType = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'));
      final userId = prefs.getString('user_id');
      final phone = prefs.getString('user_phone') ?? '';

      // Subscribe to user and phone specific topics
      try {
        if (userId != null && userId.isNotEmpty) {
          await _fcm?.subscribeToTopic('user_$userId');
        }
        if (phone.isNotEmpty) {
          final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
          if (cleanPhone.length == 10) {
            await _fcm?.subscribeToTopic('phone_$cleanPhone');
          }
        }
      } catch (e) {
        print("Error subscribing to phone/user topic: $e");
      }

      final response = await dio.post(
        '/api/fcm/register',
        data: {
          'token': token,
          'deviceType': deviceType,
          if (userId != null) 'userId': userId,
          'phone': phone,
        },
      );

      if (response.statusCode == 200) {
        print("FCM Token registered successfully!");
        await prefs.remove('pending_fcm_token');
      }
    } catch (e) {
      print("Error registering FCM token: $e");
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm?.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  // ─── Notification Preferences ───────────────────────────────────────────

  Future<void> updateNotificationPreference(String key, bool value) async {
    _prefs[key] = value;
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _prefKeyFor(key);
    if (prefKey != null) {
      await prefs.setBool(prefKey, value);
    }
    _prefsController.add(Map.from(_prefs));
  }

  Future<Map<String, bool>> getNotificationPreferences() async {
    return Map.from(_prefs);
  }

  bool isNotificationEnabled(String category) {
    switch (category) {
      case 'order':
        return _prefs['order_updates'] ?? true;
      case 'offer':
        return _prefs['offers_promos'] ?? true;
      case 'delivery':
        return _prefs['delivery_alerts'] ?? true;
      default:
        return true;
    }
  }

  String? _prefKeyFor(String key) {
    switch (key) {
      case 'order_updates':
        return 'notif_order_updates';
      case 'offers_promos':
        return 'notif_offers_promos';
      case 'delivery_alerts':
        return 'notif_delivery_alerts';
      default:
        return null;
    }
  }
}
