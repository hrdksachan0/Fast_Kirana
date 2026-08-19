import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Setup local notification channel for Android (foreground notification popups)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fastkirana_alerts', // id
        'FastKirana Alerts', // title
        description: 'Notifications for order updates and tracking.', // description
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 3. Initialize Local Notifications Plugin
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

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Handle tap on local notification
          print("Notification tapped: ${details.payload}");
        },
      );

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      // 5. Handle App Opened from Notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("App opened from notification: ${message.data}");
      });

      _initialized = true;
    } catch (e) {
      print("Error initializing NotificationService: $e");
    }
  }

  Future<void> requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print("FCM permission status: ${settings.authorizationStatus}");
    } catch (e) {
      print("Error requesting FCM permissions: $e");
    }
  }

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      print("Error getting FCM token: $e");
      return null;
    }
  }

  Future<void> registerDeviceToken(Dio dio) async {
    try {
      String? token = await getFcmToken();
      if (token == null) {
        print("Cannot register device token: Token is null");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString('auth_token');

      // Check if user is logged in
      if (authToken == null) {
        print("User not authenticated. Saving FCM token to register later.");
        await prefs.setString('pending_fcm_token', token);
        return;
      }

      String deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');

      final response = await dio.post(
        '/api/fcm/register',
        data: {
          'token': token,
          'deviceType': deviceType,
        },
      );

      if (response.statusCode == 200) {
        print("FCM Token registered successfully with backend!");
        await prefs.remove('pending_fcm_token');
      } else {
        print("Failed to register FCM token: ${response.data}");
      }
    } catch (e) {
      print("Error registering FCM token with backend: $e");
    }
  }
}
