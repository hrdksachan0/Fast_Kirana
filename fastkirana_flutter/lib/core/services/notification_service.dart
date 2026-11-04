import 'package:fastminute_flutter/core/services/logger_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';
import '../routes/app_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order.dart';

final logger = Logger();

// Top-level background message handler for when app is killed or phone screen is off
final Map<String, int> _bgRecentMessageTimes = {};

// Top-level background message handler for when app is killed or phone screen is off
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
  } catch (e, _) { LoggerService.error('NotificationService: error', e); }

  final notification = message.notification;
  final data = message.data;
  final rawTitle = notification?.title ?? data['title'] ?? '⚡ FastMinute Express';
  final rawBody = notification?.body ?? data['body'] ?? data['message'];
  final title = rawTitle.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
  final body = rawBody?.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');

  // Check persisted user role. Only suppress staff/admin alerts if user is CONFIRMED to be a CUSTOMER/USER.
  try {
    final prefs = await SharedPreferences.getInstance();
    final prefRole = prefs.getString('user_role');
    final secureRole = await SecureStorage.read('user_role');
    final userRole = (prefRole ?? secureRole ?? '').toUpperCase().trim();

    final isStaff = userRole == 'ADMIN' ||
        userRole == 'SUPER_ADMIN' ||
        userRole == 'STORE_MANAGER' ||
        userRole == 'STAFF' ||
        userRole == 'RESTAURANT' ||
        userRole == 'RESTAURANT_OWNER' ||
        userRole == 'CHEF' ||
        userRole == 'VENDOR' ||
        userRole == 'STORE_OWNER' ||
        userRole == 'DELIVERY' ||
        userRole == 'PICKER' ||
        userRole == 'RIDER' ||
        userRole == 'DELIVERY_PARTNER' ||
        userRole == 'DRIVER';

    final isStaffOrAdminMessage =
        data['screen'] == 'admin-orders' ||
        data['screen'] == 'restaurant-console' ||
        data['screen'] == 'delivery' ||
        data['screen'] == 'picker' ||
        data['role'] == 'ADMIN' ||
        data['type'] == 'STAFF_ALERT' ||
        data['type'] == 'NEW_ORDER' ||
        title.toString().contains('👨‍🍳') ||
        title.toString().contains('🛎️') ||
        title.toString().toLowerCase().contains('kitchen') ||
        title.toString().toLowerCase().contains('new order');

    // ONLY suppress if the user is explicitly identified as a normal CUSTOMER / USER and NOT staff
    if (!isStaff && (userRole == 'CUSTOMER' || userRole == 'USER') && isStaffOrAdminMessage) {
      debugPrint('NotificationService: Suppressing staff/admin alert for customer user in background.');
      return;
    }

    // STRICT OUTLET ISOLATION IN BACKGROUND:
    final assignedRestId = prefs.getString('assigned_restaurant_id') ?? '';
    final notifRestId = (data['restaurantId'] ?? '').toString().trim();
    final notifScreen = (data['screen'] ?? '').toString().trim();
    final isRestStaff = userRole == 'RESTAURANT' || userRole == 'RESTAURANT_OWNER' || userRole == 'CHEF' || assignedRestId.isNotEmpty;

    // 1. If assigned to an outlet and notification is for another restaurant, SUPPRESS!
    if (isRestStaff && assignedRestId.isNotEmpty && notifRestId.isNotEmpty) {
      if (assignedRestId.toLowerCase() != notifRestId.toLowerCase()) {
        debugPrint('NotificationService: Suppressing alert in background for different restaurant ($notifRestId != $assignedRestId)');
        return;
      }
    }
    // 2. If restaurant staff and notification is grocery picker alert, SUPPRESS!
    if (isRestStaff && (notifScreen == 'picker' || data['role'] == 'PICKER')) {
      debugPrint('NotificationService: Suppressing grocery picker alert for restaurant staff in background.');
      return;
    }
    // 3. If grocery picker and notification is restaurant console alert, SUPPRESS!
    if (userRole == 'PICKER' && (notifScreen == 'restaurant-console' || notifRestId.isNotEmpty)) {
      debugPrint('NotificationService: Suppressing restaurant alert for grocery picker in background.');
      return;
    }

    // 3B. STRICT RIDER HUB ISOLATION IN BACKGROUND:
    // If rider is assigned to a specific hub (e.g. hub-209206 Ghatampur) and order belongs to another hub, SUPPRESS!
    final assignedStoreId = prefs.getString('assigned_store_id') ?? prefs.getString('rider_store_id') ?? '';
    final notifStoreId = (data['storeId'] ?? '').toString().trim();
    final isRider = userRole == 'DELIVERY' || userRole == 'RIDER' || userRole == 'DELIVERY_PARTNER' || userRole == 'DRIVER';

    if (isRider && assignedStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
      if (assignedStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
        debugPrint('NotificationService: Suppressing alert in background for different hub rider ($notifStoreId != $assignedStoreId)');
        return;
      }
    }
    // 4. If VENDOR, strictly suppress restaurant, picker, rider, and non-vendor alerts!
    if (userRole == 'VENDOR' && data['type'] != 'VENDOR_NEW_ORDER' && data['screen'] != 'vendor-console') {
      debugPrint('NotificationService: Suppressing non-vendor alert for vendor in background.');
      return;
    }

    // 5. STRICT ADMIN ISOLATION:
    // Admin ONLY receives notification when an order is in ADMIN_PENDING state (awaiting approval).
    // All intermediate status updates (packed, picked, on the way, delivered) and non-pending orders are strictly suppressed!
    final isAdmin = userRole == 'ADMIN' || userRole == 'SUPER_ADMIN';
    if (isAdmin) {
      final msgType = (data['type'] ?? '').toString().toUpperCase();
      final msgScreen = (data['screen'] ?? '').toString();
      final msgRole = (data['role'] ?? '').toString().toUpperCase();
      final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

      // STRICT HUB ISOLATION: Akbarpur admin never receives Ghatampur alerts, and vice versa!
      final assignedStoreId = prefs.getString('assigned_store_id') ?? await SecureStorage.read('assigned_store_id') ?? '';
      final notifStoreId = (data['storeId'] ?? '').toString().trim();
      if (assignedStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
        if (assignedStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
          debugPrint('NotificationService: Suppressed alert for different hub admin ($notifStoreId != $assignedStoreId) in background.');
          return;
        }
      }

      // Suppress all status updates and non-approval orders for Admin (Admin receives approval alert only!)
      if (msgType == 'ORDER_STATUS_UPDATE' ||
          msgType == 'STATUS_UPDATE' ||
          msgType == 'ORDER_STATUS' ||
          (orderStatus.isNotEmpty && orderStatus != 'ADMIN_PENDING') ||
          orderStatus == 'CONFIRMED' ||
          orderStatus == 'PREPARING' ||
          orderStatus == 'COOKING' ||
          orderStatus == 'PACKED' ||
          orderStatus == 'SHIPPED' ||
          orderStatus == 'OUT_FOR_DELIVERY' ||
          orderStatus == 'DELIVERED') {
        debugPrint('NotificationService: Suppressed status update ($orderStatus) for Admin in background.');
        return;
      }

      // Suppress sub-console alerts (picker, delivery, kitchen) so Admin receives EXACTLY ONE Master Admin alert!
      if (msgScreen == 'picker' ||
          msgRole == 'PICKER' ||
          msgScreen == 'delivery' ||
          msgRole == 'DELIVERY' ||
          msgScreen == 'restaurant-console' ||
          title.toString().contains('👨‍🍳') ||
          title.toString().contains('📦 New Order') ||
          title.toString().contains('🛵 New Delivery') ||
          title.toString().contains('🛵 New Food')) {
        debugPrint('NotificationService: Suppressed sub-console duplicate ($msgScreen/$msgRole) for Admin in background.');
        return;
      }
    }
  } catch (_) {}

  // Detect cancel/reject notifications — those should be quiet and not trigger loud alarm
  final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();
  final isCancelledOrTerminal = orderStatus == 'CANCELLED' || orderStatus == 'REJECTED' ||
      orderStatus == 'FAILED' || orderStatus == 'REFUNDED' ||
      title.toString().toLowerCase().contains('cancel') ||
      (body ?? '').toString().toLowerCase().contains('cancel');

  final isOrderStatusUpdate = !isCancelledOrTerminal && (
      orderStatus == 'OUT_FOR_DELIVERY' ||
      orderStatus == 'DISPATCHED' ||
      orderStatus == 'DELIVERED' ||
      orderStatus == 'CONFIRMED' ||
      orderStatus == 'PREPARING' ||
      orderStatus == 'COOKING' ||
      orderStatus == 'PACKED' ||
      orderStatus == 'ON_THE_WAY' ||
      orderStatus == 'ARRIVING_SOON' ||
      data['type'] == 'ORDER_STATUS_UPDATE' ||
      title.toString().toLowerCase().contains('out for delivery') ||
      title.toString().toLowerCase().contains('dispatched') ||
      title.toString().toLowerCase().contains('delivered') ||
      title.toString().toLowerCase().contains('on the way') ||
      title.toString().toLowerCase().contains('arriving') ||
      (body ?? '').toString().toLowerCase().contains('out for delivery') ||
      (body ?? '').toString().toLowerCase().contains('dispatched') ||
      (body ?? '').toString().toLowerCase().contains('delivered') ||
      (body ?? '').toString().toLowerCase().contains('on the way') ||
      (body ?? '').toString().toLowerCase().contains('arriving'));

  final isDeliveryRiderAlert = (data['screen'] == 'delivery' || data['role'] == 'DELIVERY') &&
      (orderStatus == 'CONFIRMED' || orderStatus == 'PACKED' || data['type'] == 'NEW_ORDER' || data['type'] == 'ORDER_PACKED');

  final isOrderAlert = isDeliveryRiderAlert || (!isCancelledOrTerminal && !isOrderStatusUpdate && (
      data['type'] == 'NEW_ORDER' ||
      data['type'] == 'VENDOR_NEW_ORDER' ||
      orderStatus == 'PENDING' ||
      orderStatus == 'PLACED' ||
      data['screen'] == 'admin-orders' ||
      (data['screen'] == 'restaurant-console' && (orderStatus == 'PENDING' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
      (data['restaurantId'] != null && (orderStatus == 'PENDING' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
      title.toString().contains('👨‍🍳') ||
      title.toString().contains('🛎️') ||
      title.toString().contains('💳') ||
      title.toString().toLowerCase().contains('kitchen') ||
      title.toString().toLowerCase().contains('new order')));

  if (notification != null) {
    // Android OS FCM client displays notification directly in system tray.
    // Suppress localNotifications.show here to avoid showing 2 notifications for the same message.
    debugPrint('NotificationService: Android OS already displayed FCM notification in background.');
    return;
  }

  // Trigger system notification for data-only messages
  if (body != null && body.toString().trim().isNotEmpty) {
    try {
      final rawOrderId = data['orderId'] ?? data['readableId'] ?? data['id'];
      final cleanOrderId = (rawOrderId != null && rawOrderId.toString().trim().isNotEmpty)
          ? rawOrderId.toString().trim().replaceAll('#', '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '')
          : null;

      // Background Deduplication within 30 seconds: exactly ONE notification per order
      final dedupKey = (cleanOrderId != null && cleanOrderId.isNotEmpty)
          ? 'order_$cleanOrderId'
          : (message.messageId ?? '${title}_${body.hashCode}');

      final now = DateTime.now().millisecondsSinceEpoch;
      _bgRecentMessageTimes.removeWhere((_, time) => now - time > 30000);
      if (_bgRecentMessageTimes.containsKey(dedupKey)) {
        debugPrint("NotificationService: Suppressed duplicate background notification for $dedupKey");
        return;
      }
      _bgRecentMessageTimes[dedupKey] = now;

      final localNotifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInit);
      await localNotifications.initialize(initSettings);

      final notifId = (cleanOrderId != null && cleanOrderId.isNotEmpty)
          ? NotificationService.getOrderNotifId(cleanOrderId)
          : (message.messageId?.hashCode ?? message.hashCode);
      final tag = (cleanOrderId != null && cleanOrderId.isNotEmpty) ? 'order_$cleanOrderId' : null;

      final channelId = isOrderAlert
          ? 'fastkirana_order_buzzer_v2'
          : (isOrderStatusUpdate ? 'fastkirana_order_status' : 'fastkirana_alerts');
      final channelName = isOrderAlert
          ? 'Kitchen & Order Buzz Alerts'
          : (isOrderStatusUpdate ? 'Live Order Tracking & Delivery' : 'FastMinute Alerts');
      final channelDesc = isOrderAlert
          ? 'Loud alarm for kitchen, admin, and staff orders even when phone is locked.'
          : (isOrderStatusUpdate
              ? 'Real-time chime alerts for Dispatched, Out for Delivery, and Delivered orders.'
              : 'Notifications for order updates and tracking.');

      String cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
      cleanTitle = cleanTitle
          .replaceAll('Order Placed Successfully!', 'Order Placed!')
          .replaceAll('Combined Order Placed Successfully!', 'Order Placed!')
          .replaceAll('Combined Order Confirmed & Paid!', 'Order Confirmed & Paid!')
          .replaceAll('Online Payment Order Confirmed!', 'Order Confirmed!')
          .trim();
      final cleanBody = body.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        icon: '@mipmap/ic_launcher',
        importance: (isOrderAlert || isOrderStatusUpdate) ? Importance.max : Importance.high,
        priority: Priority.high,
        tag: tag,
        fullScreenIntent: isOrderAlert,
        playSound: true,
        sound: (isOrderAlert || isOrderStatusUpdate) ? const RawResourceAndroidNotificationSound('order_chime') : null,
        audioAttributesUsage: isOrderAlert ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        enableVibration: true,
        vibrationPattern: isOrderAlert
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000])
            : (isOrderStatusUpdate ? Int64List.fromList([0, 250, 200, 250]) : null),
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        styleInformation: BigTextStyleInformation(
          cleanBody,
          contentTitle: cleanTitle,
        ),
      );

      await localNotifications.show(
        notifId,
        cleanTitle,
        cleanBody,
        NotificationDetails(android: androidDetails),
        payload: (data['url'] ?? data['linkUrl'] ?? data['link'] ?? (cleanOrderId != null ? '/orders/track' : '')).toString(),
      );
    } catch (e) {
      debugPrint("Background notification show error: $e");
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Stable single notification ID per order to prevent duplicate stacking/grouping
  static int getOrderNotifId(String? orderId, {String? readableId}) {
    final raw = (readableId != null && readableId.trim().isNotEmpty) ? readableId : (orderId ?? 'order');
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && digits.length >= 4) {
      return (int.tryParse(digits.substring(digits.length - 4)) ?? 1000) + 50000;
    }
    return (raw.hashCode.abs() % 100000) + 50000;
  }

  /// Centralized route resolver for push notifications across Customer, Admin, Store Manager, Restaurant, and Rider
  static String? _resolveNotificationRoute(Map<String, dynamic> data) {
    final rawUrl = data['url'] ?? data['linkUrl'] ?? data['link'];
    if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
      final str = rawUrl.toString().trim();
      if (str == '/admin' || str == 'admin') return '/admin-orders';
      return str;
    }
    final screen = data['screen']?.toString().toLowerCase().trim();
    if (screen == 'admin-orders' || screen == 'admin' || screen == 'store-manager' || screen == 'admin_orders') {
      return '/admin-orders';
    }
    if (screen == 'delivery' || screen == 'rider') {
      return '/delivery';
    }
    if (screen == 'picker') {
      return '/picker';
    }
    if (screen == 'restaurant-console' || screen == 'kitchen') {
      return '/kitchen';
    }
    if (screen == 'restaurants' || screen == 'food' || screen == 'cafe' || screen == 'dining' || screen == 'restaurant-list') {
      final rId = data['restaurantId'] ?? data['id'];
      return (rId != null && rId.toString().trim().isNotEmpty) ? '/restaurants/$rId' : '/restaurants';
    }
    if (screen == 'categories' || screen == 'category') {
      final cat = data['categoryId'] ?? data['category'];
      return cat != null ? '/products?category=$cat' : '/categories';
    }
    if (screen == 'products' || screen == 'product') {
      final pId = data['productId'] ?? data['id'];
      return pId != null ? '/product/$pId' : '/products';
    }
    if (screen == 'order-tracking' || screen == 'track' || screen == 'order') {
      final oId = data['orderId'] ?? data['readableId'] ?? data['id'];
      return oId != null ? '/orders/$oId/track' : '/orders';
    }
    if (screen == 'karwachauth' || screen == 'karwa-chauth' || screen == 'pooja') {
      return '/category/pooja-path';
    }
    return null;
  }

  /// Stored target link for cold-launch from a tapped notification
  static String? pendingDeepLinkUrl;

  /// Centralized link router for push notification taps and deep links
  static void navigateToLink(String rawUrl) {
    if (rawUrl.trim().isEmpty || rawUrl.trim() == '/') return;

    String link = rawUrl.trim();

    // 1. Strip domain if full URL (e.g. https://fastminute.in/category/cleaning -> /category/cleaning)
    if (link.startsWith('http://') || link.startsWith('https://')) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        if (uri.host.contains('fastminute.in') || uri.host.contains('fastkirana.in')) {
          link = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
        } else {
          // External web link
          try {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
          return;
        }
      }
    }

    // 2. Strip custom scheme (e.g. fastminute://category/cleaning -> /category/cleaning)
    if (link.startsWith('fastminute://') || link.startsWith('fastkirana://')) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        final queryStr = uri.hasQuery ? '?${uri.query}' : '';
        link = '/${uri.host}${uri.path}$queryStr';
      }
    }

    if (!link.startsWith('/')) {
      link = '/$link';
    }

    debugPrint('[NotificationService] Navigating to link: $link');

    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[NotificationService] Navigator not ready, queued pending link: $link');
      pendingDeepLinkUrl = link;
      for (final delayMs in [300, 700, 1500, 2500]) {
        Future.delayed(Duration(milliseconds: delayMs), () {
          final retryNav = AppRouter.navigatorKey.currentState;
          if (retryNav != null && pendingDeepLinkUrl == link) {
            pendingDeepLinkUrl = null;
            debugPrint('[NotificationService] Executing delayed navigation to: $link');
            try {
              retryNav.pushNamed(link);
            } catch (e) {
              debugPrint('[NotificationService] Delayed navigation error: $e');
            }
          }
        });
      }
      return;
    }

    try {
      nav.pushNamed(link);
    } catch (e) {
      debugPrint('[NotificationService] Navigation failed: $e');
    }
  }

  FirebaseMessaging? get _fcm {
    if (kIsWeb) return null;
    try {
      return FirebaseMessaging.instance;
    } catch (e) { LoggerService.error('NotificationService: error', e);
      return null;
    }
  }

  FlutterLocalNotificationsPlugin? get _localNotifications {
    if (kIsWeb) return null;
    try {
      return FlutterLocalNotificationsPlugin();
    } catch (e) { LoggerService.error('NotificationService: error', e);
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

      // 2. Request runtime notification permissions asynchronously (non-blocking for startup)
      unawaited(() async {
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
        } catch (e, _) { LoggerService.error('NotificationService: error', e); }
      }());

      // 3. Setup local notification channel for Android with MAX priority
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fastkirana_alerts',
        'FastMinute Alerts',
        description: 'Notifications for order updates and tracking.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final AndroidNotificationChannel kitchenChannel = AndroidNotificationChannel(
        'fastkirana_order_buzzer_v2',
        'Kitchen & Order Buzz Alerts',
        description: 'Loud alarm for kitchen orders even when phone is locked.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('order_chime'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        showBadge: true,
      );

      final AndroidNotificationChannel orderStatusChannel = AndroidNotificationChannel(
        'fastkirana_order_status',
        'Live Order Tracking & Delivery',
        description: 'Real-time chime alerts for Dispatched, Out for Delivery, and Delivered orders.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('order_chime'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
        audioAttributesUsage: AudioAttributesUsage.notification,
        showBadge: true,
      );

      const AndroidNotificationChannel liveTrackingChannel = AndroidNotificationChannel(
        'fastkirana_live_tracking_v1',
        'Live Order Status & Dynamic Tracking',
        description: 'Persistent lock-screen live activity with real-time rider ETA and delivery progress.',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      );

      final androidPlugin = _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(kitchenChannel);
      await androidPlugin?.createNotificationChannel(orderStatusChannel);
      await androidPlugin?.createNotificationChannel(liveTrackingChannel);

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
          logger.d("Notification tapped: ${details.payload}");
          final payload = details.payload;
          if (payload != null && payload.trim().isNotEmpty) {
            NotificationService.navigateToLink(payload.trim());
          }
        },
      );

      // 5. Handle Foreground Messages with exact current timestamp
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // 6. Handle App Opened from Background Notification Tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logger.d("App opened from notification: ${message.data}");
        final url = _resolveNotificationRoute(Map<String, dynamic>.from(message.data));
        if (url != null && url.toString().trim().isNotEmpty) {
          NotificationService.navigateToLink(url.toString().trim());
        }
      });

      // 6.1 Check Cold Launch from Notification (when app was terminated)
      try {
        final initialMsg = await _fcm?.getInitialMessage();
        if (initialMsg != null) {
          final url = _resolveNotificationRoute(Map<String, dynamic>.from(initialMsg.data));
          if (url != null && url.toString().trim().isNotEmpty) {
            final cleanTarget = url.toString().trim();
            pendingDeepLinkUrl = cleanTarget;
            debugPrint('[NotificationService] Stored initial notification link: $pendingDeepLinkUrl');
            NotificationService.navigateToLink(cleanTarget);
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] getInitialMessage error: $e');
      }

      // 7. Auto-save refreshed tokens for re-registration
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        logger.i("FCM token refreshed: ${newToken.substring(0, 20)}...");
        await prefs.setString('pending_fcm_token', newToken);
      });

      // 8. Auto-subscribe to broadcast topics
      try {
        await _fcm?.subscribeToTopic('all_users');
        await _fcm?.subscribeToTopic('ghatampur_alerts');
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null && savedUserId.isNotEmpty) {
          await _fcm?.subscribeToTopic('user_$savedUserId');
        }
        // Purge legacy phone topic to prevent duplicate pushes
        final savedPhone = prefs.getString('user_phone') ?? '';
        final clean = savedPhone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (clean.length == 10) {
          try { await _fcm?.subscribeToTopic('phone_$clean'); } catch (_) {}
        }
      } catch (e) {
        logger.e("Topic subscription error: $e");
      }

      _initialized = true;
    } catch (e) {
      logger.e("Error initializing NotificationService: $e");
    }
  }

  final Map<String, int> _recentMessageTimes = {};

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final rawTitle = message.notification?.title ?? message.data['title'] ?? '⚡ FastMinute Express';
    final rawBody = message.notification?.body ?? message.data['body'] ?? message.data['message'];

    if (rawBody == null || rawBody.toString().trim().isEmpty) return;

    final title = rawTitle.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
    final body = rawBody.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');

    final data = message.data;

    // Check current user role to suppress admin/kitchen alerts ONLY for confirmed customers
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefRole = prefs.getString('user_role');
      final secureRole = await SecureStorage.read('user_role');
      final userRole = (prefRole ?? secureRole ?? '').toUpperCase().trim();

      final isStaff = userRole == 'ADMIN' ||
          userRole == 'SUPER_ADMIN' ||
          userRole == 'STORE_MANAGER' ||
          userRole == 'STAFF' ||
          userRole == 'RESTAURANT' ||
          userRole == 'RESTAURANT_OWNER' ||
          userRole == 'CHEF' ||
          userRole == 'VENDOR' ||
          userRole == 'STORE_OWNER' ||
          userRole == 'DELIVERY' ||
          userRole == 'PICKER' ||
          userRole == 'RIDER' ||
          userRole == 'DELIVERY_PARTNER' ||
          userRole == 'DRIVER';

      final isStaffOrAdminMessage =
          data['screen'] == 'admin-orders' ||
          data['screen'] == 'restaurant-console' ||
          data['screen'] == 'delivery' ||
          data['screen'] == 'picker' ||
          data['role'] == 'ADMIN' ||
          data['type'] == 'STAFF_ALERT' ||
          data['type'] == 'NEW_ORDER' ||
          title.toString().contains('👨‍🍳') ||
          title.toString().contains('🛎️') ||
          title.toString().toLowerCase().contains('kitchen') ||
          title.toString().toLowerCase().contains('new order');

      if (!isStaff && (userRole == 'CUSTOMER' || userRole == 'USER') && isStaffOrAdminMessage) {
        debugPrint('NotificationService: Suppressed staff/admin alert for customer user in foreground.');
        return;
      }

      // STRICT OUTLET ISOLATION IN FOREGROUND:
      final assignedRestId = prefs.getString('assigned_restaurant_id') ?? '';
      final notifRestId = (data['restaurantId'] ?? '').toString().trim();
      final notifScreen = (data['screen'] ?? '').toString().trim();
      final isRestStaff = userRole == 'RESTAURANT' || userRole == 'RESTAURANT_OWNER' || userRole == 'CHEF' || assignedRestId.isNotEmpty;

      // 1. If assigned to an outlet and notification is for another restaurant, SUPPRESS!
      if (isRestStaff && assignedRestId.isNotEmpty && notifRestId.isNotEmpty) {
        if (assignedRestId.toLowerCase() != notifRestId.toLowerCase()) {
          debugPrint('NotificationService: Suppressing foreground alert for different restaurant ($notifRestId != $assignedRestId)');
          return;
        }
      }
      // 2. If restaurant staff and notification is grocery picker alert, SUPPRESS!
      if (isRestStaff && (notifScreen == 'picker' || data['role'] == 'PICKER')) {
        debugPrint('NotificationService: Suppressing grocery picker alert for restaurant staff in foreground.');
        return;
      }
      // 3. If grocery picker and notification is restaurant console alert, SUPPRESS!
      if (userRole == 'PICKER' && (notifScreen == 'restaurant-console' || notifRestId.isNotEmpty)) {
        debugPrint('NotificationService: Suppressing restaurant alert for grocery picker in foreground.');
        return;
      }

      // 3B. STRICT RIDER HUB ISOLATION IN FOREGROUND:
      final assignedStoreId = prefs.getString('assigned_store_id') ?? prefs.getString('rider_store_id') ?? '';
      final notifStoreId = (data['storeId'] ?? '').toString().trim();
      final isRider = userRole == 'DELIVERY' || userRole == 'RIDER' || userRole == 'DELIVERY_PARTNER' || userRole == 'DRIVER';

      if (isRider && assignedStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
        if (assignedStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
          debugPrint('NotificationService: Suppressing alert in foreground for different hub rider ($notifStoreId != $assignedStoreId)');
          return;
        }
      }
      // 4. If VENDOR, strictly suppress restaurant, picker, rider, and non-vendor alerts!
      if (userRole == 'VENDOR' && data['type'] != 'VENDOR_NEW_ORDER' && data['screen'] != 'vendor-console') {
        debugPrint('NotificationService: Suppressing non-vendor alert for vendor in foreground.');
        return;
      }

      // 5. STRICT ADMIN ISOLATION:
      // Admin ONLY receives notification when an order is in ADMIN_PENDING state (awaiting approval).
      // All intermediate status updates (packed, picked, on the way, delivered) and non-pending orders are strictly suppressed!
      final isAdmin = userRole == 'ADMIN' || userRole == 'SUPER_ADMIN';
      if (isAdmin) {
        final msgType = (data['type'] ?? '').toString().toUpperCase();
        final msgScreen = (data['screen'] ?? '').toString();
        final msgRole = (data['role'] ?? '').toString().toUpperCase();
        final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

        // STRICT HUB ISOLATION: Akbarpur admin never receives Ghatampur alerts, and vice versa!
        final adminStoreId = prefs.getString('assigned_store_id') ?? await SecureStorage.read('assigned_store_id') ?? '';
        final notifStoreId = (data['storeId'] ?? '').toString().trim();
        if (adminStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
          if (adminStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
            debugPrint('NotificationService: Suppressed alert for different hub admin ($notifStoreId != $adminStoreId) in foreground.');
            return;
          }
        }

        // Suppress all status updates and non-approval orders for Admin (Admin receives approval alert only!)
        if (msgType == 'ORDER_STATUS_UPDATE' ||
            msgType == 'STATUS_UPDATE' ||
            msgType == 'ORDER_STATUS' ||
            (orderStatus.isNotEmpty && orderStatus != 'ADMIN_PENDING') ||
            orderStatus == 'CONFIRMED' ||
            orderStatus == 'PREPARING' ||
            orderStatus == 'COOKING' ||
            orderStatus == 'PACKED' ||
            orderStatus == 'SHIPPED' ||
            orderStatus == 'OUT_FOR_DELIVERY' ||
            orderStatus == 'DELIVERED') {
          debugPrint('NotificationService: Suppressed status update ($orderStatus) for Admin in foreground.');
          return;
        }

        // Suppress sub-console alerts (picker, delivery, kitchen) so Admin receives EXACTLY ONE Master Admin alert!
        if (msgScreen == 'picker' ||
            msgRole == 'PICKER' ||
            msgScreen == 'delivery' ||
            msgRole == 'DELIVERY' ||
            msgScreen == 'restaurant-console' ||
            title.toString().contains('👨‍🍳') ||
            title.toString().contains('📦 New Order') ||
            title.toString().contains('🛵 New Delivery') ||
            title.toString().contains('🛵 New Food')) {
          debugPrint('NotificationService: Suppressed sub-console duplicate ($msgScreen/$msgRole) for Admin in foreground.');
          return;
        }
      }
    } catch (_) {}

    final rawOrderId = data['orderId'] ?? data['readableId'] ?? data['id'];
    final cleanOrderId = (rawOrderId != null && rawOrderId.toString().trim().isNotEmpty)
        ? rawOrderId.toString().trim().replaceAll('#', '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '')
        : null;

    final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

    // Foreground Deduplication within 30 seconds: exactly ONE notification per order
    final isCartAlert = (data['type'] ?? '').toString().toUpperCase() == 'CART_ALERT' ||
        title.toString().toLowerCase().contains('cart') ||
        body.toString().toLowerCase().contains('cart');

    final dedupKey = (cleanOrderId != null && cleanOrderId.isNotEmpty)
        ? 'order_$cleanOrderId'
        : (isCartAlert ? 'cart_alert' : '${title}_${body.toString().trim()}');

    final now = DateTime.now().millisecondsSinceEpoch;
    _recentMessageTimes.removeWhere((_, time) => now - time > 30000);
    if (_recentMessageTimes.containsKey(dedupKey)) {
      debugPrint("NotificationService: Suppressed duplicate foreground notification for $dedupKey");
      return;
    }
    _recentMessageTimes[dedupKey] = now;

    final category = data['category'] as String? ?? 'order';
    if (!_shouldShowNotification(category)) {
      logger.w("Notification suppressed by user preference: $category");
      return;
    }

    // Detect cancel/reject notifications — these should NOT trigger loud alarm
    final isCancelledOrTerminal = orderStatus == 'CANCELLED' || orderStatus == 'REJECTED' ||
        orderStatus == 'FAILED' || orderStatus == 'REFUNDED' ||
        title.toString().toLowerCase().contains('cancel') ||
        body.toString().toLowerCase().contains('cancel');

    final isOrderStatusUpdate = !isCancelledOrTerminal && (
        orderStatus == 'OUT_FOR_DELIVERY' ||
        orderStatus == 'DISPATCHED' ||
        orderStatus == 'DELIVERED' ||
        orderStatus == 'CONFIRMED' ||
        orderStatus == 'PREPARING' ||
        orderStatus == 'COOKING' ||
        orderStatus == 'PACKED' ||
        orderStatus == 'ON_THE_WAY' ||
        orderStatus == 'ARRIVING_SOON' ||
        data['type'] == 'ORDER_STATUS_UPDATE' ||
        title.toString().toLowerCase().contains('out for delivery') ||
        title.toString().toLowerCase().contains('dispatched') ||
        title.toString().toLowerCase().contains('delivered') ||
        title.toString().toLowerCase().contains('on the way') ||
        title.toString().toLowerCase().contains('arriving') ||
        body.toString().toLowerCase().contains('out for delivery') ||
        body.toString().toLowerCase().contains('dispatched') ||
        body.toString().toLowerCase().contains('delivered') ||
        body.toString().toLowerCase().contains('on the way') ||
        body.toString().toLowerCase().contains('arriving'));

    final isDeliveryRiderAlert = (data['screen'] == 'delivery' || data['role'] == 'DELIVERY') &&
        (orderStatus == 'CONFIRMED' || orderStatus == 'PACKED' || data['type'] == 'NEW_ORDER' || data['type'] == 'ORDER_PACKED');

    final isOrderAlert = isDeliveryRiderAlert || (!isCancelledOrTerminal && !isOrderStatusUpdate && (
        data['type'] == 'NEW_ORDER' ||
        data['type'] == 'VENDOR_NEW_ORDER' ||
        orderStatus == 'PENDING' ||
        orderStatus == 'PLACED' ||
        data['screen'] == 'admin-orders' ||
        (data['screen'] == 'restaurant-console' && (orderStatus == 'PENDING' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
        (data['restaurantId'] != null && (orderStatus == 'PENDING' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
        title.toString().contains('👨‍🍳') ||
        title.toString().contains('🛎️') ||
        title.toString().contains('💳') ||
        title.toString().toLowerCase().contains('kitchen') ||
        title.toString().toLowerCase().contains('new order')));

    final notifId = (cleanOrderId != null && cleanOrderId.isNotEmpty)
        ? NotificationService.getOrderNotifId(cleanOrderId)
        : (isCartAlert ? 8888 : ('${title}_$body'.hashCode & 0x7FFFFFFF));
    final tag = (cleanOrderId != null && cleanOrderId.isNotEmpty)
        ? 'order_$cleanOrderId'
        : (isCartAlert ? 'cart_alert' : 'general_alert');

    final channelId = isOrderAlert
        ? 'fastkirana_order_buzzer_v2'
        : (isOrderStatusUpdate ? 'fastkirana_order_status' : 'fastkirana_alerts');
    final channelName = isOrderAlert
        ? 'Kitchen & Order Buzz Alerts'
        : (isOrderStatusUpdate ? 'Live Order Tracking & Delivery' : 'FastMinute Alerts');
    final channelDesc = isOrderAlert
        ? 'Loud alarm for kitchen, admin, and staff orders even when phone is locked.'
        : (isOrderStatusUpdate
            ? 'Real-time chime alerts for Dispatched, Out for Delivery, and Delivered orders.'
            : 'Notifications for order updates and tracking.');

    String cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
    cleanTitle = cleanTitle
        .replaceAll('Order Placed Successfully!', 'Order Placed!')
        .replaceAll('Combined Order Placed Successfully!', 'Order Placed!')
        .replaceAll('Combined Order Confirmed & Paid!', 'Order Confirmed & Paid!')
        .replaceAll('Online Payment Order Confirmed!', 'Order Confirmed!')
        .trim();
    final cleanBody = body.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');

    _localNotifications?.show(
      notifId,
      cleanTitle,
      cleanBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: (isOrderAlert || isOrderStatusUpdate) ? Importance.max : Importance.high,
          priority: Priority.high,
          tag: tag,
          showWhen: true,
          when: DateTime.now().millisecondsSinceEpoch,
          styleInformation: BigTextStyleInformation(
            cleanBody,
            contentTitle: cleanTitle,
          ),
          playSound: true,
          sound: (isOrderAlert || isOrderStatusUpdate) ? const RawResourceAndroidNotificationSound('order_chime') : null,
          audioAttributesUsage: isOrderAlert ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
          enableVibration: true,
          vibrationPattern: isOrderAlert
              ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000])
              : (isOrderStatusUpdate ? Int64List.fromList([0, 250, 200, 250]) : null),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: (_resolveNotificationRoute(Map<String, dynamic>.from(message.data)) ?? (cleanOrderId != null ? '/orders/track' : '')).toString(),
    );
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

  /// ─── LIVE ACTIVITY & LOCK SCREEN WIDGET (Android Ongoing Notification & iOS Time-Sensitive) ───
  /// Displays live lock screen status: "Rider 4 mins away • Reaching your gate"
  /// Updates silently without playing a chime or vibrating continuously.
  Future<void> updateLiveOrderActivity({
    required Order order,
    String? customEtaText,
    String? customStatusText,
    int? customProgress,
  }) async {
    if (kIsWeb) return;

    final isTerminal = order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled;
    final int notifId = NotificationService.getOrderNotifId(order.id, readableId: order.readableId);

    if (isTerminal) {
      await clearLiveOrderActivity(order.id, readableId: order.readableId);
      if (order.status == OrderStatus.delivered) {
        // Show one-time celebration delivery notification
        try {
          const androidDelivered = AndroidNotificationDetails(
            'fastkirana_order_status',
            'Live Order Tracking & Delivery',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('order_chime'),
            icon: '@mipmap/ic_launcher',
          );
          const iosDelivered = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );
          await _localNotifications?.show(
            notifId,
            '🎉 Order Delivered!',
            'Your FastMinute order was delivered. Enjoy!',
            const NotificationDetails(android: androidDelivered, iOS: iosDelivered),
            payload: '/orders/${order.readableId ?? order.id}/track',
          );
        } catch (_) {}
      }
      return;
    }

    String title;
    String body;
    int progress;

    final riderName = (order.deliveryBoyName != null && order.deliveryBoyName!.trim().isNotEmpty)
        ? order.deliveryBoyName!.trim()
        : 'Rider';

    switch (order.status) {
      case OrderStatus.shipped:
        title = 'Rider on the Way';
        body = '🛵 $riderName is on the way';
        progress = customProgress ?? 80;
        break;
      case OrderStatus.packed:
        title = 'Order Packed';
        body = '🛍️ Packed & ready for delivery partner';
        progress = customProgress ?? 55;
        break;
      case OrderStatus.confirmed:
        title = 'Order Confirmed';
        body = '👨‍🍳 Store is packing your order';
        progress = customProgress ?? 30;
        break;
      case OrderStatus.adminPending:
      case OrderStatus.pending:
      default:
        title = 'Order Placed';
        body = '⏳ Order received • Preparing fresh';
        progress = customProgress ?? 15;
        break;
    }

    if (customStatusText != null && customStatusText.isNotEmpty) {
      body = customStatusText;
    }

    final androidDetails = AndroidNotificationDetails(
      'fastkirana_live_tracking_v1',
      'Live Order Status & Dynamic Tracking',
      channelDescription: 'Persistent lock-screen live activity with real-time delivery progress.',
      importance: Importance.high,
      priority: Priority.max,
      ongoing: true, // Lock screen persistent widget
      autoCancel: false,
      onlyAlertOnce: true, // Updates silently without chime on every tick
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      subText: 'Live Tracker ($progress%)',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Live Tracker ($progress%)',
      ),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      color: const Color(0xFF00B140),
      colorized: true,
      icon: '@mipmap/ic_launcher',
      actions: const [
        AndroidNotificationAction(
          'open_live_track',
          '📍 Track Order',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
      subtitle: 'Live Order Tracker',
      categoryIdentifier: 'order_tracking',
    );

    try {
      await _localNotifications?.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: '/orders/${order.readableId ?? order.id}/track',
      );
    } catch (e, st) {
      LoggerService.error('NotificationService: updateLiveOrderActivity error', e, st);
    }
  }

  /// Clears ongoing lock screen tracking widget once order is delivered or cancelled
  Future<void> clearLiveOrderActivity(String orderId, {String? readableId}) async {
    if (kIsWeb) return;
    try {
      final int notifId = NotificationService.getOrderNotifId(orderId, readableId: readableId);
      await _localNotifications?.cancel(notifId);
    } catch (_) {}
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
      logger.i("FCM permission status: ${settings?.authorizationStatus}");
    } catch (e) {
      logger.e("Error requesting FCM permissions: $e");
    }
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) return null;
    try {
      return await _fcm?.getToken();
    } catch (e) {
      logger.e("Error getting FCM token: $e");
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
        logger.i("FCM Token refreshed successfully!");
        final p = await SharedPreferences.getInstance();
        await p.remove('pending_fcm_token');
      }
    } catch (e) {
      logger.e("Error refreshing FCM token: $e");
    }
  }

  Future<void> registerDeviceToken(
    Dio dio, {
    String? role,
    String? assignedRestaurantId,
    String? assignedStoreId,
  }) async {
    if (kIsWeb) return;
    try {
      String? token = await getFcmToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      String deviceType = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'));
      final userId = (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
      final phone = (await SecureStorage.read('user_phone')) ?? prefs.getString('user_phone') ?? '';
      final resolvedRole = (role ?? prefs.getString('user_role') ?? (await SecureStorage.read('user_role')) ?? 'USER').toUpperCase().trim();
      final storeId = assignedStoreId ?? prefs.getString('assigned_store_id') ?? (await SecureStorage.read('assigned_store_id'));
      final rId = assignedRestaurantId ?? prefs.getString('assigned_restaurant_id') ?? (await SecureStorage.read('assigned_restaurant_id'));

      final savedUserRole = (prefs.getString('user_role') ?? (await SecureStorage.read('user_role')) ?? '').toUpperCase().trim();
      final isMasterAdmin = savedUserRole == 'ADMIN' || savedUserRole == 'SUPER_ADMIN';

      // If user is logged in as Admin, never downgrade their device registration or topics to Picker/Delivery/Restaurant
      final effectiveRole = isMasterAdmin ? 'ADMIN' : resolvedRole;

      final isAdmin = effectiveRole == 'ADMIN' ||
          effectiveRole == 'SUPER_ADMIN' ||
          effectiveRole == 'STORE_MANAGER' ||
          effectiveRole == 'STAFF';

      final isRestaurant = !isAdmin && (effectiveRole == 'RESTAURANT' ||
          effectiveRole == 'RESTAURANT_OWNER' ||
          effectiveRole == 'CHEF' ||
          effectiveRole == 'VENDOR' ||
          effectiveRole == 'STORE_OWNER' ||
          (rId != null && rId.isNotEmpty));

      final isDeliveryOrPicker = !isAdmin && !isRestaurant && (effectiveRole == 'DELIVERY' ||
          effectiveRole == 'PICKER' ||
          effectiveRole == 'RIDER' ||
          effectiveRole == 'DELIVERY_PARTNER' ||
          effectiveRole == 'DRIVER');

      // Subscribe to role-based and user-specific topics
      try {
        if (isAdmin) {
          final hasAssignedStore = (storeId != null && storeId.isNotEmpty);
          if (hasAssignedStore) {
            // Hub Admin / Store Manager: Subscribe ONLY to this specific hub's orders (Strict Hub Isolation)
            await _fcm?.subscribeToTopic('admin_orders_$storeId');
            try { await _fcm?.unsubscribeFromTopic('admin_orders'); } catch (_) {}
          } else {
            // Super Admin without assigned store: Subscribes to global canonical admin_orders topic
            await _fcm?.subscribeToTopic('admin_orders');
          }
          // Actively purge duplicate, sub-console, and other hub topics
          final duplicateTopicsToPurge = [
            'admin_orders_all',
            'staff_orders',
            'picker_orders',
            'delivery_orders',
            'admin_orders_hub-209206',
            'admin_orders_hub-209101',
            'admin_orders_wedson_store',
            'admin_orders_ghatampur',
            if (storeId != null && storeId.isNotEmpty) ...[
              'staff_orders_$storeId',
              'picker_orders_$storeId',
              'delivery_orders_$storeId',
            ],
          ];
          for (final t in duplicateTopicsToPurge) {
            if (hasAssignedStore && t == 'admin_orders_$storeId') continue;
            try { await _fcm?.unsubscribeFromTopic(t); } catch (_) {}
          }
        } else if (isRestaurant) {
          if (rId != null && rId.isNotEmpty) {
            // Subscribe to single canonical restaurant topic
            await _fcm?.subscribeToTopic('restaurant_$rId');
            // Purge duplicate legacy topics
            try { await _fcm?.unsubscribeFromTopic('kitchen_$rId'); } catch (_) {}
            try { await _fcm?.unsubscribeFromTopic('restaurant_orders_$rId'); } catch (_) {}
          }
        } else if (isDeliveryOrPicker) {
          final isPicker = effectiveRole == 'PICKER';
          if (isPicker) {
            final topic = (storeId != null && storeId.isNotEmpty) ? 'picker_orders_$storeId' : 'picker_orders';
            await _fcm?.subscribeToTopic(topic);
            try { await _fcm?.unsubscribeFromTopic('staff_orders'); } catch (_) {}
            try { await _fcm?.unsubscribeFromTopic('delivery_orders'); } catch (_) {}
            if (storeId != null && storeId.isNotEmpty) {
              try { await _fcm?.unsubscribeFromTopic('staff_orders_$storeId'); } catch (_) {}
              try { await _fcm?.unsubscribeFromTopic('delivery_orders_$storeId'); } catch (_) {}
            }
          } else {
            // Delivery / Rider - Strict Hub Subscription
            if (storeId != null && storeId.isNotEmpty) {
              await _fcm?.subscribeToTopic('delivery_orders_$storeId');
              try { await _fcm?.unsubscribeFromTopic('delivery_orders'); } catch (_) {}
            } else {
              await _fcm?.subscribeToTopic('delivery_orders');
            }
            try { await _fcm?.unsubscribeFromTopic('staff_orders'); } catch (_) {}
            try { await _fcm?.unsubscribeFromTopic('picker_orders'); } catch (_) {}
            if (storeId != null && storeId.isNotEmpty) {
              try { await _fcm?.unsubscribeFromTopic('staff_orders_$storeId'); } catch (_) {}
              try { await _fcm?.unsubscribeFromTopic('picker_orders_$storeId'); } catch (_) {}
            }
          }
        } else if (effectiveRole == 'CUSTOMER' || effectiveRole == 'USER') {
          // Normal CUSTOMER / USER: Actively purge ANY leftover admin/staff/kitchen subscriptions on this device!
          final staffTopicsToPurge = [
            'admin_orders',
            'admin_orders_all',
            'staff_orders',
            'admin_orders_wedson_store',
            'admin_orders_ghatampur',
            'staff_orders_wedson_store',
            'staff_orders_ghatampur',
          ];
          for (final t in staffTopicsToPurge) {
            try { await _fcm?.unsubscribeFromTopic(t); } catch (_) {}
          }
        }

        if (userId != null && userId.isNotEmpty) {
          await _fcm?.subscribeToTopic('user_$userId');
        }
        if (phone.isNotEmpty) {
          final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
          if (cleanPhone.length == 10) {
            try { await _fcm?.subscribeToTopic('phone_$cleanPhone'); } catch (_) {}
          }
        }
      } catch (e) {
        logger.e("Error subscribing to topics: $e");
      }

      final response = await dio.post(
        '/api/fcm/register',
        data: {
          'token': token,
          'deviceType': deviceType,
          if (userId != null) 'userId': userId,
          'phone': phone,
          'role': effectiveRole,
          if (assignedRestaurantId != null) 'assignedRestaurantId': assignedRestaurantId,
          if (assignedStoreId != null) 'assignedStoreId': assignedStoreId,
        },
      );

      if (response.statusCode == 200) {
        logger.i("FCM Token registered successfully!");
        await prefs.remove('pending_fcm_token');
      }
    } catch (e) {
      logger.e("Error registering FCM token: $e");
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm?.subscribeToTopic(topic);
    } catch (e, _) { LoggerService.error('NotificationService: error', e); }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm?.unsubscribeFromTopic(topic);
    } catch (e, _) { LoggerService.error('NotificationService: error', e); }
  }

  /// Unsubscribe from ALL FCM topics on logout so no notifications arrive when logged out
  Future<void> unsubscribeAllTopics([Dio? dio]) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
      final phone = (await SecureStorage.read('user_phone')) ?? prefs.getString('user_phone') ?? '';
      final restaurantId = (await SecureStorage.read('assigned_restaurant_id')) ?? prefs.getString('assigned_restaurant_id');
      final storeId = (await SecureStorage.read('assigned_store_id')) ?? prefs.getString('assigned_store_id');
      final token = await getFcmToken();

      // 1. Tell backend to unbind and delete this token from admin/user records immediately
      if (dio != null && token != null && token.isNotEmpty) {
        try {
          await dio.post('/api/fcm/unregister', data: {'token': token});
        } catch (_) {}
      }

      // 2. Unsubscribe from all possible topics this device may have subscribed to
      final topics = <String>[
        'all_users',
        'ghatampur_alerts',
        'admin_orders',
        'admin_orders_all',
        'staff_orders',
        'admin_orders_wedson_store',
        'admin_orders_ghatampur',
        'staff_orders_wedson_store',
        'staff_orders_ghatampur',
      ];

      if (storeId != null && storeId.isNotEmpty) {
        topics.add('admin_orders_$storeId');
        topics.add('staff_orders_$storeId');
      }

      if (userId != null && userId.isNotEmpty) {
        topics.add('user_$userId');
      }
      if (phone.isNotEmpty) {
        final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (cleanPhone.length == 10) {
          topics.add('phone_$cleanPhone');
        }
      }
      if (restaurantId != null && restaurantId.isNotEmpty) {
        topics.add('restaurant_$restaurantId');
        topics.add('kitchen_$restaurantId');
        topics.add('restaurant_orders_$restaurantId');
      }

      for (final topic in topics) {
        try {
          await _fcm?.unsubscribeFromTopic(topic);
        } catch (_) {}
      }

      // 3. Delete the FCM token on device so a clean new token is minted for subsequent logins
      try {
        await _fcm?.deleteToken();
      } catch (_) {}

      debugPrint('NotificationService: Unsubscribed from ${topics.length} topics on logout');
    } catch (e, _) {
      LoggerService.error('NotificationService: unsubscribeAllTopics error', e);
    }
  }

  /// Cancel all active notifications in system tray (used on logout)
  Future<void> clearAllNotifications() async {
    if (kIsWeb) return;
    try {
      await _localNotifications?.cancelAll();
    } catch (e, _) {
      LoggerService.error('NotificationService: clearAllNotifications', e);
    }
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
