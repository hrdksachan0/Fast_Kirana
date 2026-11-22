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
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:audioplayers/audioplayers.dart';
import 'order_alarm_service.dart';
import 'order_event_bus.dart';

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

  bool isStaff = false;
  // Check persisted user role. Only suppress staff/admin alerts if user is CONFIRMED to be a CUSTOMER/USER.
  try {
    final prefs = await SharedPreferences.getInstance();
    final prefRole = prefs.getString('user_role');
    final secureRole = await SecureStorage.read('user_role');
    final userRole = (prefRole ?? secureRole ?? '').toUpperCase().trim();
    final isExplicitCustomer = userRole == 'CUSTOMER' || userRole == 'USER';

    final prefUserId = prefs.getString('user_id');
    final secureUserId = await SecureStorage.read('user_id');
    final savedUserId = prefUserId ?? secureUserId;
    final isLoggedOut = savedUserId == null || savedUserId.isEmpty;

    // Detect if this is an Admin / Staff incoming alert (NOT a customer order notification)
    final msgRole = (data['role'] ?? '').toString().toUpperCase();
    final msgScreen = (data['screen'] ?? '').toString().toLowerCase();
    final msgType = (data['type'] ?? '').toString().toUpperCase();
    final isAdminOrStaffAlert = msgRole == 'ADMIN' ||
        msgRole == 'PICKER' ||
        msgRole == 'CHEF' ||
        msgRole == 'DELIVERY' ||
        msgScreen == 'admin-orders' ||
        msgScreen == 'restaurant-console' ||
        msgScreen == 'picker' ||
        msgScreen == 'delivery' ||
        msgType == 'STAFF_ALERT' ||
        title.contains('🚨') ||
        title.contains('🔔') ||
        title.toLowerCase().contains('new order') ||
        title.toLowerCase().contains('awaiting approval');

    final isOrderSpecific = !isAdminOrStaffAlert && (data['orderId'] != null ||
        data['readableId'] != null ||
        data['type'] == 'ORDER_STATUS_UPDATE' ||
        data['type'] == 'ORDER_STATUS_CHANGED' ||
        data['type'] == 'ORDER_PLACED' ||
        data['screen'] == 'order-tracking');

    // 🛡️ LOGOUT LEAKAGE PROTECTION (Background):
    // Only suppress if it was a customer-specific order notification and device is logged out!
    if (isLoggedOut && isOrderSpecific) {
      debugPrint('NotificationService: Suppressed background order notification for logged-out device.');
      return;
    }

    final prefPhone = prefs.getString('user_phone') ?? '';
    final securePhone = await SecureStorage.read('user_phone') ?? '';
    final rawPhone = (prefPhone.isNotEmpty ? prefPhone : securePhone).replaceAll(RegExp(r'[^0-9]'), '');
    final cleanPhone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;

    // 🛡️ CROSS-ACCOUNT PHONE CHECK:
    // Only apply customer phone matching to customer order updates, NEVER to Admin/Store Alerts!
    if (!isLoggedOut && isOrderSpecific && cleanPhone.isNotEmpty) {
      final notifPhone = (data['customerPhone'] ?? data['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      final notifLast10 = notifPhone.length >= 10 ? notifPhone.substring(notifPhone.length - 10) : '';
      if (notifLast10.isNotEmpty && notifLast10 != cleanPhone) {
        debugPrint('NotificationService: Suppressed background notification for different phone ($notifLast10 != $cleanPhone).');
        return;
      }
    }
    final isAdminPhone = cleanPhone == '7054470303' && !isExplicitCustomer;

    isStaff = isAdminPhone ||
        (!isExplicitCustomer && (
            userRole == 'ADMIN' ||
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
            userRole == 'DRIVER'));

    final isStaffOrAdminMessage =
        data['screen'] == 'admin-orders' ||
        data['screen'] == 'restaurant-console' ||
        data['screen'] == 'delivery' ||
data['screen'] == 'delivery-dashboard' ||
data['type'] == 'DELIVERY_ASSIGNED' ||
title.toString().contains('🛵') ||
        data['screen'] == 'picker' ||
        data['role'] == 'ADMIN' ||
        data['type'] == 'STAFF_ALERT' ||
        data['type'] == 'NEW_ORDER' ||
        title.toString().contains('👨‍🍳') ||
        title.toString().contains('🛎️') ||
        title.toString().toLowerCase().contains('kitchen') ||
        title.toString().toLowerCase().contains('new order');

    // ONLY suppress if the user is NOT staff (covers both confirmed CUSTOMER/USER and logged-out/empty role)
    if (!isStaff && isStaffOrAdminMessage) {
      debugPrint('NotificationService: Suppressing staff/admin alert for non-staff user ($userRole) in background.');
      return;
    }

    // STRICT OUTLET ISOLATION IN BACKGROUND:
    final assignedRestId = prefs.getString('assigned_restaurant_id') ?? '';
    final notifRestId = (data['restaurantId'] ?? '').toString().trim();
    final notifScreen = (data['screen'] ?? '').toString().trim();
    final isRestStaff = userRole == 'RESTAURANT' || userRole == 'RESTAURANT_OWNER' || userRole == 'CHEF' || assignedRestId.isNotEmpty;

    // 1. STRICT RESTAURANT ISOLATION (Background):
    // Restaurant staff ONLY receive alerts for THEIR assigned restaurant!
    // Suppress ALL grocery orders (empty restaurantId) and all other restaurants' orders!
    if (isRestStaff) {
      if (notifRestId.isEmpty) {
        debugPrint('NotificationService: Suppressing non-restaurant / grocery alert for restaurant staff in background.');
        return;
      }
      if (assignedRestId.isNotEmpty && assignedRestId.toLowerCase() != notifRestId.toLowerCase()) {
        debugPrint('NotificationService: Suppressing alert in background for different restaurant ($notifRestId != $assignedRestId)');
        return;
      }
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
    final isAdmin = userRole == 'ADMIN' || userRole == 'SUPER_ADMIN';
    if (isAdmin) {
      final msgType = (data['type'] ?? '').toString().toUpperCase();
      final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

      // STRICT HUB ISOLATION:
      // Super Admin (9170942500 or SUPER_ADMIN) monitors ALL hubs!
      // Hub Admins (Ghatampur 7054470303, Barharwa 7633898577) receive alerts strictly for their assigned hub!
      final assignedStoreId = prefs.getString('assigned_store_id') ?? await SecureStorage.read('assigned_store_id') ?? '';
      final notifStoreId = (data['storeId'] ?? '').toString().trim();
      final userPhone = (await SecureStorage.read('user_phone')) ?? prefs.getString('user_phone') ?? '';
      final cleanPhone = userPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final tenDigit = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      final isSuperAdmin = tenDigit == '9170942500' || userRole == 'SUPER_ADMIN';
      final isBarharwa = tenDigit == '7633898577' || assignedStoreId.contains('816101');
      final isGhatampur = tenDigit == '7054470303' || assignedStoreId.contains('209206');

      if (!isSuperAdmin) {
        if (isBarharwa && (notifStoreId.contains('209206') || notifStoreId.toLowerCase().contains('ghatampur'))) {
          debugPrint('NotificationService: Suppressed Ghatampur alert for Barharwa manager in background.');
          return;
        }
        if (isGhatampur && (notifStoreId.contains('816101') || notifStoreId.toLowerCase().contains('barharwa'))) {
          debugPrint('NotificationService: Suppressed Barharwa alert for Ghatampur manager in background.');
          return;
        }
        if (assignedStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
          if (assignedStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
            debugPrint('NotificationService: Suppressed alert for different hub admin ($notifStoreId != $assignedStoreId) in background.');
            return;
          }
        }
      }

      // Suppress ONLY routine customer delivery status updates (e.g. out for delivery, delivered, cooking)
      // DO NOT suppress new incoming orders (PENDING, ADMIN_PENDING, or CONFIRMED live orders)!
      final isNewOrderAlert = msgType == 'NEW_ORDER' ||
          msgType == 'STAFF_ALERT' ||
          data['screen'] == 'admin-orders' ||
          orderStatus == 'PENDING' ||
          orderStatus == 'ADMIN_PENDING' ||
          title.toString().contains('New Order') ||
          title.toString().contains('New Food') ||
          title.toString().contains('👨‍🍳') ||
          title.toString().contains('🛎️') ||
          title.toString().contains('🚨') ||
          title.toString().contains('🔔');

      if (!isNewOrderAlert && (
          msgType == 'ORDER_STATUS_UPDATE' ||
          msgType == 'STATUS_UPDATE' ||
          msgType == 'ORDER_STATUS' ||
          orderStatus == 'PREPARING' ||
          orderStatus == 'COOKING' ||
          orderStatus == 'PACKED' ||
          orderStatus == 'SHIPPED' ||
          orderStatus == 'OUT_FOR_DELIVERY' ||
          orderStatus == 'DELIVERED')) {
        debugPrint('NotificationService: Suppressed routine status update ($orderStatus) for Admin in background.');
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

  // If order was cancelled/rejected/failed/delivered, immediately dismiss any ongoing lock-screen live tracker
  // BEFORE checking `notification != null`, because Android OS displays `message.notification` directly.
  if (orderStatus == 'CANCELLED' || orderStatus == 'REJECTED' || orderStatus == 'FAILED' || orderStatus == 'DELIVERED') {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(NotificationService.LIVE_TRACKING_NOTIF_ID, tag: NotificationService.LIVE_TRACKING_TAG);
      await plugin.cancel(NotificationService.LIVE_TRACKING_NOTIF_ID);
      final rawOid = (data['orderId'] ?? data['id'] ?? '').toString().trim();
      final rawRid = (data['readableId'] ?? '').toString().trim();
      if (rawOid.isNotEmpty || rawRid.isNotEmpty) {
        final plugin = FlutterLocalNotificationsPlugin();
        await NotificationService.clearOrderNotificationsById(
          rawOid,
          readableId: rawRid.isNotEmpty ? rawRid : null,
          plugin: plugin,
        );
      }
    } catch (_) {}
  }

  // Explicit customer tracking notifications must NEVER trigger loud alarms or buzzers
  final isCustomerNotification =
      data['role'] == 'CUSTOMER' ||
      data['screen'] == 'order-tracking' ||
      data['isLiveTracking'] == 'true' ||
      data['type'] == 'ORDER_PLACED' ||
      data['type'] == 'ORDER_STATUS_UPDATE';

  final isDeliveryRiderAlert = !isCustomerNotification && isStaff && (data['type'] == 'DELIVERY_ASSIGNED' ||
      title.toString().contains('🛵') ||
      title.toString().toLowerCase().contains('delivery assigned') ||
      ((data['screen'] == 'delivery' || data['screen'] == 'delivery-dashboard' || data['role'] == 'DELIVERY') &&
          (orderStatus == 'CONFIRMED' || orderStatus == 'PACKED' || data['type'] == 'NEW_ORDER' || data['type'] == 'ORDER_PACKED' || data['type'] == 'DELIVERY_ASSIGNED')));

  final isOrderAlert = !isCustomerNotification && isStaff && (isDeliveryRiderAlert || (!isCancelledOrTerminal && (
      data['type'] == 'NEW_ORDER' ||
      data['type'] == 'VENDOR_NEW_ORDER' ||
      orderStatus == 'PENDING' ||
      orderStatus == 'PLACED' ||
      orderStatus == 'ADMIN_PENDING' ||
      data['status'] == 'ADMIN_PENDING' ||
      data['screen'] == 'admin-orders' ||
      data['role'] == 'ADMIN' ||
      data['screen'] == 'restaurant-console' ||
      (data['restaurantId'] != null && (orderStatus == 'PENDING' || orderStatus == 'CONFIRMED' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
      title.toString().contains('👨‍🍳') ||
      title.toString().contains('🛎️') ||
      title.toString().contains('💳') ||
      title.toString().contains('🚨') ||
      title.toString().contains('🔔') ||
      title.toString().toLowerCase().contains('kitchen') ||
      title.toString().toLowerCase().contains('new order') ||
      title.toString().toLowerCase().contains('new combined order') ||
      title.toString().toLowerCase().contains('combined order') ||
      title.toString().toLowerCase().contains('new approved order') ||
      title.toString().toLowerCase().contains('awaiting approval'))));

  final isOrderStatusUpdate = !isCancelledOrTerminal && !isOrderAlert && (
      isCustomerNotification ||
      !isStaff ||
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

  // Automatically clear ongoing lock-screen tracker when order reaches terminal state (DELIVERED/CANCELLED)
  final rawStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();
  final rawOrderIdForClean = data['readableId'] ?? data['orderId'] ?? data['id'];
  if (rawStatus == 'DELIVERED' || rawStatus == 'CANCELLED' || title.toString().toLowerCase().contains('delivered') || title.toString().toLowerCase().contains('cancel')) {
    if (rawOrderIdForClean != null && rawOrderIdForClean.toString().trim().isNotEmpty) {
      await NotificationService.clearOrderNotificationsById(
        (data['orderId'] ?? rawOrderIdForClean).toString().trim(),
        readableId: data['readableId']?.toString() ?? rawOrderIdForClean.toString().trim(),
      );
    }
  }

  if (notification != null) {
    // Android OS FCM client ALREADY displays notification directly in system tray!
    // Calling localNotifications.show here creates an exact duplicate notification in the tray.
    // Trigger the buzzer audio chime directly, and return to guarantee strictly 1 notification in tray!
    if (isOrderAlert) {
      final rawOrderId = data['readableId'] ?? data['orderId'] ?? data['id'];
      final baseOrderNum = NotificationService.getBaseOrderNumber(rawOrderId);
      final cleanOrderId = baseOrderNum.isNotEmpty
          ? baseOrderNum
          : rawOrderId?.toString().trim().replaceAll('#', '');
      OrderAlarmService.instance.startOrderBuzzer(orderId: cleanOrderId);
    }
    debugPrint('NotificationService: Suppressing duplicate FCM notification in background (Android OS handles display).');
    return;
  }

  // Trigger system notification for data-only messages
  if (body != null && body.toString().trim().isNotEmpty) {
    try {
      final rawOrderId = data['readableId'] ?? data['orderId'] ?? data['id'];
      final baseOrderNum = NotificationService.getBaseOrderNumber(rawOrderId);
      final cleanOrderId = baseOrderNum.isNotEmpty
          ? baseOrderNum
          : rawOrderId?.toString().trim().replaceAll('#', '');

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

      // Blinkit/Zepto Standard: Single dedicated slot for customer live tracking
      final notifId = isOrderStatusUpdate
          ? NotificationService.LIVE_TRACKING_NOTIF_ID
          : ((cleanOrderId != null && cleanOrderId.isNotEmpty)
              ? NotificationService.getOrderNotifId(cleanOrderId)
              : (message.messageId?.hashCode ?? message.hashCode));
      final tag = isOrderStatusUpdate
          ? NotificationService.LIVE_TRACKING_TAG
          : ((cleanOrderId != null && cleanOrderId.isNotEmpty) ? 'order_$cleanOrderId' : null);

      // UNIFY CHANNEL: Customer order tracking updates MUST use the Live Tracking Channel!
      // This guarantees Android mutates the single active card in-place instead of creating 2 duplicate notifications.
      final channelId = isOrderAlert
          ? 'fastminute_order_alarm_v3'
          : (isOrderStatusUpdate ? 'fastkirana_live_tracking_v1' : 'fastkirana_alerts');
      final channelName = isOrderAlert
          ? 'Store & Order Buzz Alerts'
          : (isOrderStatusUpdate ? 'Live Order Status & Dynamic Tracking' : 'FastMinute Alerts');
      final channelDesc = isOrderAlert
          ? 'Loud alarm for store, admin, kitchen orders even when phone is locked.'
          : (isOrderStatusUpdate
              ? 'Persistent lock-screen live activity with real-time delivery progress.'
              : 'Notifications for order updates and tracking.');

      int? progress;
      if (rawStatus == 'CONFIRMED') {
        progress = 35;
      } else if (rawStatus == 'PREPARING' || rawStatus == 'COOKING') {
        progress = 45;
      } else if (rawStatus == 'PACKED') {
        progress = 60;
      } else if (rawStatus == 'SHIPPED' || rawStatus == 'OUT_FOR_DELIVERY') {
        progress = 80;
      } else if (rawStatus == 'ARRIVING_SOON') {
        progress = 95;
      } else if (rawStatus == 'DELIVERED') {
        progress = 100;
      } else if (rawStatus == 'PENDING' || rawStatus == 'ADMIN_PENDING' || rawStatus == 'PLACED') {
        progress = 15;
      }

      String cleanTitle;
      String cleanBodyText = body.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
      if (isOrderStatusUpdate && cleanOrderId != null && cleanOrderId.isNotEmpty) {
        if (rawStatus == 'PENDING' || rawStatus == 'ADMIN_PENDING' || rawStatus == 'PLACED') {
          cleanTitle = 'Store Verifying ⏳ • #$cleanOrderId';
          cleanBodyText = 'Ghatampur Central Hub is checking freshness & stock';
        } else if (rawStatus == 'CONFIRMED') {
          cleanTitle = 'Order Confirmed 👨‍🍳 • #$cleanOrderId';
          cleanBodyText = 'Store accepted your order & preparing fresh items';
        } else if (rawStatus == 'PREPARING' || rawStatus == 'COOKING') {
          cleanTitle = 'Preparing Fresh 🍲 • #$cleanOrderId';
          cleanBodyText = 'Store is preparing your fresh order items';
        } else if (rawStatus == 'PACKED') {
          cleanTitle = 'Order Packed 🛍️ • #$cleanOrderId';
          cleanBodyText = 'Store packed your fresh items • Awaiting rider pickup';
        } else if (rawStatus == 'SHIPPED' || rawStatus == 'OUT_FOR_DELIVERY') {
          cleanTitle = 'Out for Delivery 🛵 • #$cleanOrderId';
          cleanBodyText = 'Rider is on the way to your doorstep • Live GPS tracking';
        } else if (rawStatus == 'ARRIVING_SOON') {
          cleanTitle = 'Arriving Soon! 🛵 • #$cleanOrderId';
          cleanBodyText = 'Rider has reached your area and is arriving at your doorstep!';
        } else if (rawStatus == 'DELIVERED') {
          cleanTitle = '🎉 Order Delivered! • #$cleanOrderId';
          cleanBodyText = 'Your FastMinute order was delivered fresh. Enjoy!';
        } else {
          cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute').trim();
        }
      } else {
        cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute').trim();
      }
      cleanTitle = cleanTitle
          .replaceAll('Order Placed Successfully!', 'Order Placed!')
          .replaceAll('Combined Order Placed Successfully!', 'Order Placed!')
          .replaceAll('Combined Order Confirmed & Paid!', 'Order Confirmed & Paid!')
          .replaceAll('Online Payment Order Confirmed!', 'Order Confirmed!')
          .trim();

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        icon: '@mipmap/ic_launcher',
        importance: isOrderAlert ? Importance.max : Importance.high,
        priority: Priority.high,
        tag: tag,
        fullScreenIntent: isOrderAlert,
        ongoing: (isOrderStatusUpdate && rawStatus != 'DELIVERED' && rawStatus != 'CANCELLED'),
        onlyAlertOnce: true,
        showProgress: !isOrderAlert && progress != null,
        maxProgress: 100,
        progress: !isOrderAlert ? (progress ?? 0) : 0,
        color: const Color(0xFF00A344),
        colorized: true,
        subText: null, // STRICTLY NULL: prevents Android OS from appending truncated text ("Packe...") to header line!
        playSound: isOrderAlert,
        sound: isOrderAlert ? const RawResourceAndroidNotificationSound('order_chime') : null,
        audioAttributesUsage: isOrderAlert ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        enableVibration: isOrderAlert,
        vibrationPattern: isOrderAlert
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000])
            : null,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        styleInformation: BigTextStyleInformation(
          cleanBodyText,
          contentTitle: cleanTitle,
          summaryText: isOrderStatusUpdate ? 'FastMinute Live' : null,
        ),
      );

      final routeUrl = NotificationService._resolveNotificationRoute(Map<String, dynamic>.from(data)) ??
          (isOrderAlert
              ? (data['role'] == 'DELIVERY' || data['type'] == 'DELIVERY_ASSIGNED' ? '/delivery' : '/admin-orders')
              : (cleanOrderId != null ? '/orders/$cleanOrderId/track' : '/orders'));

      await localNotifications.show(
        notifId,
        cleanTitle,
        cleanBodyText,
        NotificationDetails(android: androidDetails),
        payload: routeUrl.toString(),
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

  /// Blinkit / Zepto Standard: Fixed single notification ID & tag for Customer Live Tracking.
  /// Guarantees Android OS will ONLY ever display ONE live order tracking card at any given time.
  static const int LIVE_TRACKING_NOTIF_ID = 88888;
  static const String LIVE_TRACKING_TAG = 'fastminute_live_tracking';

  /// Central check if current user is confirmed staff / admin / rider
  static Future<bool> isStaffUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefRole = prefs.getString('user_role');
      final secureRole = await SecureStorage.read('user_role');
      final userRole = (prefRole ?? secureRole ?? '').toUpperCase().trim();

      // If user is explicitly logged in as a customer/user, they are NOT staff!
      if (userRole == 'CUSTOMER' || userRole == 'USER') {
        return false;
      }

      final prefPhone = prefs.getString('user_phone') ?? '';
      final securePhone = await SecureStorage.read('user_phone') ?? '';
      final rawPhone = (prefPhone.isNotEmpty ? prefPhone : securePhone).replaceAll(RegExp(r'[^0-9]'), '');
      final cleanPhone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;

      if (cleanPhone == '7054470303') return true;

      return userRole == 'ADMIN' ||
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
    } catch (_) {
      return false;
    }
  }

  /// Extracts pure 4-digit human order number (e.g. "4227" from "FK-4227-G", "#4227-R", or "order_4227")
  static String getBaseOrderNumber(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    final noPrefix = str
        .replaceAll('#', '')
        .replaceAll(RegExp(r'^FK-', caseSensitive: false), '')
        .replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    return noPrefix;
  }

  /// Stable single notification ID per order to prevent duplicate stacking/grouping
  static int getOrderNotifId(String? orderId, {String? readableId}) {
    final base = getBaseOrderNumber(readableId != null && readableId.trim().isNotEmpty ? readableId : orderId);
    if (base.isNotEmpty) {
      final lastDigits = base.length >= 4 ? base.substring(base.length - 4) : base;
      final num = int.tryParse(lastDigits);
      if (num != null) return num + 50000;
    }
    final raw = (readableId != null && readableId.trim().isNotEmpty) ? readableId : (orderId ?? 'order');
    return (raw.hashCode.abs() % 100000) + 50000;
  }

  /// Collect all candidate notification IDs that may have been used for an order's live tracker
  static Set<int> getCandidateOrderNotifIds(String? orderId, {String? readableId}) {
    final ids = <int>{};
    final base = getBaseOrderNumber(readableId != null && readableId.trim().isNotEmpty ? readableId : orderId);
    if (base.isNotEmpty) {
      ids.add(getOrderNotifId(base));
    }
    final oid = orderId?.replaceAll('#', '').trim() ?? '';
    final rid = readableId?.replaceAll('#', '').trim() ?? '';
    if (oid.isNotEmpty) {
      ids.add(getOrderNotifId(oid));
      final baseOid = getBaseOrderNumber(oid);
      if (baseOid.isNotEmpty) ids.add(getOrderNotifId(baseOid));
    }
    if (rid.isNotEmpty) {
      ids.add(getOrderNotifId(oid, readableId: rid));
      final baseRid = getBaseOrderNumber(rid);
      if (baseRid.isNotEmpty) ids.add(getOrderNotifId(oid, readableId: baseRid));
    }
    return ids;
  }

  /// Cancel all candidate live-tracker notifications for an order (works in both main & background isolates)
  static Future<void> clearOrderNotificationsById(
    String? orderId, {
    String? readableId,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (kIsWeb) return;
    try {
      final targetPlugin = plugin ?? FlutterLocalNotificationsPlugin();
      final ids = getCandidateOrderNotifIds(orderId, readableId: readableId);
      final base = getBaseOrderNumber(readableId != null && readableId.trim().isNotEmpty ? readableId : orderId);
      final cleanRid = readableId?.replaceAll('#', '').trim() ?? '';
      final cleanOid = orderId?.replaceAll('#', '').trim() ?? '';

      final tags = <String?>[
        null,
        if (base.isNotEmpty) 'order_$base',
        if (cleanRid.isNotEmpty && cleanRid != base) 'order_$cleanRid',
        if (cleanRid.isNotEmpty) 'order_${cleanRid.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '')}',
        if (cleanOid.isNotEmpty && cleanOid != base && cleanOid != cleanRid) 'order_$cleanOid',
        if (cleanOid.isNotEmpty) 'order_${cleanOid.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '')}',
      ];
      for (final id in ids) {
        for (final tag in tags) {
          if (tag == null) {
            await targetPlugin.cancel(id).catchError((_) {});
          } else {
            await targetPlugin.cancel(id, tag: tag).catchError((_) {});
          }
        }
      }
    } catch (_) {}
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
  static String? _lastNavigatedLink;
  static int _lastNavigatedEpoch = 0;
  static Timer? _pendingNavTimer;

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

    // 3. Normalize route aliases to canonical paths
    if (link == '/admin' || link == '/admin/orders' || link == '/admin/dashboard' || link == '/store-manager') {
      link = '/admin-orders';
    }

    // 4. Strict Debounce: Drop duplicate navigation calls within 2000ms
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastNavigatedLink == link && (now - _lastNavigatedEpoch) < 2000) {
      debugPrint('[NotificationService] Suppressed duplicate navigation to $link (debounced)');
      return;
    }

    // 5. Route Guard: Never push duplicate screen if user is ALREADY viewing that screen
    final currentRoute = AppRouteObserver.currentRoute;
    if (currentRoute != null) {
      if (currentRoute == link) {
        debugPrint('[NotificationService] Already on route $link, skipping redundant push');
        return;
      }
      if (link == '/admin-orders' && (currentRoute == '/admin-orders' || currentRoute.startsWith('/admin'))) {
        debugPrint('[NotificationService] Already on admin screen ($currentRoute), skipping redundant push');
        return;
      }
    }

    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[NotificationService] Navigator not ready, storing pending link: $link');
      pendingDeepLinkUrl = link;
      
      // Single controlled timer instead of uncoordinated loop of timers
      _pendingNavTimer?.cancel();
      _pendingNavTimer = Timer(const Duration(milliseconds: 600), () {
        final retryNav = AppRouter.navigatorKey.currentState;
        if (retryNav != null && pendingDeepLinkUrl == link) {
          pendingDeepLinkUrl = null;
          navigateToLink(link);
        }
      });
      return;
    }

    _pendingNavTimer?.cancel();
    _pendingNavTimer = null;
    pendingDeepLinkUrl = null;

    _lastNavigatedLink = link;
    _lastNavigatedEpoch = now;

    debugPrint('[NotificationService] Navigating to link: $link');

    try {
      // For major root-level staff destinations, avoid stacking duplicate instances on top of each other
      if (link == '/admin-orders' || link == '/delivery' || link == '/kitchen') {
        nav.pushNamedAndRemoveUntil(link, (route) => route.settings.name == '/home' || route.isFirst);
      } else {
        nav.pushNamed(link);
      }
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
  Dio? _lastDio;
  static const String _subscribedTopicsPrefKey = 'subscribed_fcm_topics';
  static const String _pendingCleanupPrefKey = 'pending_fcm_cleanup';
  static const String _pendingUnregisterTokenKey = 'pending_fcm_unregister_token';
  static const List<String> _knownHubIds = [
    'hub-209206',
    'hub-224122',
    'hub-816101',
    'hub-816107',
    'hub-209101',
  ];

  // In-memory preference cache (loaded from SharedPreferences on init)
  final Map<String, bool> _prefs = {
    'order_updates': true,
    'offers_promos': true,
    'delivery_alerts': true,
  };

  // Stream controller to broadcast preference changes
  final _prefsController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get prefsStream => _prefsController.stream;

  static AudioPlayer? _buzzerPlayer;

  /// Play loud order chime in-app for foreground alerts via OrderAlarmService (Alarm Audio Stream)
  /// STRICTLY GUARDED: Never plays on customer phones! Only verified Staff/Admin/Rider devices.
  static Future<void> playOrderChime({String? orderId, bool continuous = false}) async {
    if (kIsWeb) return;
    final isStaff = await isStaffUser();
    if (!isStaff) {
      debugPrint('NotificationService: Suppressed loud order chime for non-staff/customer user.');
      return;
    }
    try {
      if (continuous) {
        await OrderAlarmService.instance.startOrderBuzzer(orderId: orderId);
      } else {
        await OrderAlarmService.instance.playChime();
      }
    } catch (e) {
      debugPrint('NotificationService: In-app chime play error: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

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
        'fastminute_order_alarm_v3',
        'Store & Order Buzz Alerts',
        description: 'Loud alarm for store, admin, and kitchen orders even when phone is locked.',
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

      // Force delete stale cached channel so Android OS binds fresh order_chime alarm
      try {
        await androidPlugin?.deleteNotificationChannel('fastkirana_order_buzzer_v2');
        await androidPlugin?.deleteNotificationChannel('fastkirana_order_buzzer');
      } catch (_) {}

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
          logger.d("Notification tapped: ${details.payload}, actionId: ${details.actionId}");
          final payload = details.payload;
          if (details.actionId == 'call_rider' && payload != null) {
            final uri = Uri.tryParse(payload);
            final phone = uri?.queryParameters['phone'];
            if (phone != null && phone.isNotEmpty) {
              launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
              return;
            }
          }
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
        OrderAlarmService.instance.stopAlarm();
        logger.d("App opened from notification: ${message.data}");
        final url = _resolveNotificationRoute(Map<String, dynamic>.from(message.data));
        if (url != null && url.toString().trim().isNotEmpty) {
          NotificationService.navigateToLink(url.toString().trim());
        }
      });

      // 6.1 Check Cold Launch from FCM Notification (when app was terminated)
      try {
        final initialMsg = await _fcm?.getInitialMessage();
        if (initialMsg != null) {
          OrderAlarmService.instance.stopAlarm();
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

      // 6.2 Check Cold Launch from Local Notification (Live Activity / Ongoing notification tap)
      try {
        final launchDetails = await _localNotifications?.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final payload = launchDetails.notificationResponse?.payload;
          final actionId = launchDetails.notificationResponse?.actionId;
          if (actionId == 'call_rider' && payload != null) {
            final uri = Uri.tryParse(payload);
            final phone = uri?.queryParameters['phone'];
            if (phone != null && phone.isNotEmpty) {
              launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
            }
          } else if (payload != null && payload.trim().isNotEmpty) {
            final cleanTarget = payload.trim();
            pendingDeepLinkUrl = cleanTarget;
            debugPrint('[NotificationService] Stored local notification launch link: $pendingDeepLinkUrl');
            NotificationService.navigateToLink(cleanTarget);
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] getNotificationAppLaunchDetails error: $e');
      }

      // 7. Auto-save refreshed tokens and re-register cleanly when authenticated
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        logger.i("FCM token refreshed: ${newToken.substring(0, 20)}...");
        await prefs.setString('pending_fcm_token', newToken);
        final savedUserId = (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
        if (_lastDio != null && savedUserId != null && savedUserId.isNotEmpty) {
          unawaited(registerDeviceToken(_lastDio!));
        }
      });

      // 8. If a previous logout happened offline, finish purging stale staff/admin topics now
      if (prefs.getBool(_pendingCleanupPrefKey) == true) {
        await _purgeTopics(_knownStaffTopics(), keep: const {});
        final savedUserId = (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
        if (savedUserId == null || savedUserId.isEmpty) {
          await prefs.remove(_pendingCleanupPrefKey);
        }
      }

      // 9. Auto-subscribe to broadcast topics
      try {
        await subscribeToTopic('all_users');
        await subscribeToTopic('ghatampur_alerts');
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null && savedUserId.isNotEmpty) {
          await subscribeToTopic('user_$savedUserId');
        }
        final savedPhone = prefs.getString('user_phone') ?? '';
        final clean = savedPhone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (clean.length == 10) {
          await subscribeToTopic('phone_$clean');
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
    if (data.isNotEmpty) {
      OrderEventBus.instance.ingestFromFCMData(data);
    }

    // Check current user role to suppress admin/kitchen alerts ONLY for confirmed customers
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefRole = prefs.getString('user_role');
      final secureRole = await SecureStorage.read('user_role');
      final userRole = (prefRole ?? secureRole ?? '').toUpperCase().trim();
      final isExplicitCustomer = userRole == 'CUSTOMER' || userRole == 'USER';

      final prefUserId = prefs.getString('user_id');
      final secureUserId = await SecureStorage.read('user_id');
      final currentUserId = prefUserId ?? secureUserId;
      final isLoggedOut = currentUserId == null || currentUserId.isEmpty;

      // Detect if this is an Admin / Staff incoming alert (NOT a customer order notification)
      final msgRole = (data['role'] ?? '').toString().toUpperCase();
      final msgScreen = (data['screen'] ?? '').toString().toLowerCase();
      final msgType = (data['type'] ?? '').toString().toUpperCase();
      final isAdminOrStaffAlert = msgRole == 'ADMIN' ||
          msgRole == 'PICKER' ||
          msgRole == 'CHEF' ||
          msgRole == 'DELIVERY' ||
          msgScreen == 'admin-orders' ||
          msgScreen == 'restaurant-console' ||
          msgScreen == 'picker' ||
          msgScreen == 'delivery' ||
          msgType == 'STAFF_ALERT' ||
          title.contains('🚨') ||
          title.contains('🔔') ||
          title.toLowerCase().contains('new order') ||
          title.toLowerCase().contains('awaiting approval');

      final isOrderSpecific = !isAdminOrStaffAlert && (data['orderId'] != null ||
          data['readableId'] != null ||
          data['type'] == 'ORDER_STATUS_UPDATE' ||
          data['type'] == 'ORDER_STATUS_CHANGED' ||
          data['type'] == 'ORDER_PLACED' ||
          data['screen'] == 'order-tracking');

      // 🛡️ LOGOUT LEAKAGE PROTECTION (Foreground):
      if (isLoggedOut && isOrderSpecific) {
        debugPrint('NotificationService: Suppressed foreground order notification on logged-out device.');
        return;
      }

      final prefPhone = prefs.getString('user_phone') ?? '';
      final securePhone = await SecureStorage.read('user_phone') ?? '';
      final rawPhone = (prefPhone.isNotEmpty ? prefPhone : securePhone).replaceAll(RegExp(r'[^0-9]'), '');
      final cleanPhone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;

      // 🛡️ CROSS-ACCOUNT PHONE CHECK:
      // Only apply customer phone matching to customer order updates, NEVER to Admin/Store Alerts!
      if (!isLoggedOut && isOrderSpecific && cleanPhone.isNotEmpty) {
        final notifPhone = (data['customerPhone'] ?? data['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
        final notifLast10 = notifPhone.length >= 10 ? notifPhone.substring(notifPhone.length - 10) : '';
        if (notifLast10.isNotEmpty && notifLast10 != cleanPhone) {
          debugPrint('NotificationService: Suppressed foreground notification for different phone ($notifLast10 != $cleanPhone).');
          return;
        }
      }
      final isAdminPhone = cleanPhone == '7054470303' && !isExplicitCustomer;

      final isStaff = isAdminPhone ||
          (!isExplicitCustomer && (
              userRole == 'ADMIN' ||
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
              userRole == 'DRIVER'));

      final isStaffOrAdminMessage =
          data['screen'] == 'admin-orders' ||
          data['screen'] == 'restaurant-console' ||
          data['screen'] == 'delivery' ||
data['screen'] == 'delivery-dashboard' ||
data['type'] == 'DELIVERY_ASSIGNED' ||
title.toString().contains('🛵') ||
          data['screen'] == 'picker' ||
          data['role'] == 'ADMIN' ||
          data['type'] == 'STAFF_ALERT' ||
          data['type'] == 'NEW_ORDER' ||
          title.toString().contains('👨‍🍳') ||
          title.toString().contains('🛎️') ||
          title.toString().toLowerCase().contains('kitchen') ||
          title.toString().toLowerCase().contains('new order');

      if (!isStaff && isStaffOrAdminMessage) {
        debugPrint('NotificationService: Suppressed staff/admin alert for non-staff user ($userRole) in foreground.');
        return;
      }

      // STRICT OUTLET ISOLATION IN FOREGROUND:
      final assignedRestId = prefs.getString('assigned_restaurant_id') ?? '';
      final notifRestId = (data['restaurantId'] ?? '').toString().trim();
      final notifScreen = (data['screen'] ?? '').toString().trim();
      final isRestStaff = userRole == 'RESTAURANT' || userRole == 'RESTAURANT_OWNER' || userRole == 'CHEF' || assignedRestId.isNotEmpty;

      // 1. STRICT RESTAURANT ISOLATION (Foreground):
      // Restaurant staff ONLY receive alerts for THEIR assigned restaurant!
      // Suppress ALL grocery orders (empty restaurantId) and all other restaurants' orders!
      if (isRestStaff) {
        if (notifRestId.isEmpty) {
          debugPrint('NotificationService: Suppressing non-restaurant / grocery alert for restaurant staff in foreground.');
          return;
        }
        if (assignedRestId.isNotEmpty && assignedRestId.toLowerCase() != notifRestId.toLowerCase()) {
          debugPrint('NotificationService: Suppressing foreground alert for different restaurant ($notifRestId != $assignedRestId)');
          return;
        }
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
        final orderStatus = (data['status'] ?? data['orderStatus'] ?? '').toString().toUpperCase();

        // STRICT HUB ISOLATION:
        // Super Admin (9170942500 or SUPER_ADMIN) monitors ALL hubs!
        // Hub Admins (Ghatampur 7054470303, Barharwa 7633898577) receive alerts strictly for their assigned hub!
        final adminStoreId = prefs.getString('assigned_store_id') ?? await SecureStorage.read('assigned_store_id') ?? '';
        final notifStoreId = (data['storeId'] ?? '').toString().trim();
        final adminPhone = prefs.getString('user_phone') ?? await SecureStorage.read('user_phone') ?? '';
        final cleanPhone = adminPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final tenDigit = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final isSuperAdmin = tenDigit == '9170942500' || userRole == 'SUPER_ADMIN';
        final isBarharwa = tenDigit == '7633898577' || adminStoreId.contains('816101');
        final isGhatampur = tenDigit == '7054470303' || adminStoreId.contains('209206');

        if (!isSuperAdmin) {
          if (isBarharwa && (notifStoreId.contains('209206') || notifStoreId.toLowerCase().contains('ghatampur'))) {
            debugPrint('NotificationService: Suppressed Ghatampur alert for Barharwa manager in foreground.');
            return;
          }
          if (isGhatampur && (notifStoreId.contains('816101') || notifStoreId.toLowerCase().contains('barharwa'))) {
            debugPrint('NotificationService: Suppressed Barharwa alert for Ghatampur manager in foreground.');
            return;
          }
          if (adminStoreId.isNotEmpty && notifStoreId.isNotEmpty) {
            if (adminStoreId.toLowerCase() != notifStoreId.toLowerCase()) {
              debugPrint('NotificationService: Suppressed alert for different hub admin ($notifStoreId != $adminStoreId) in foreground.');
              return;
            }
          }
        }

        // Suppress ONLY routine customer delivery status updates (e.g. out for delivery, delivered, cooking)
        // DO NOT suppress new incoming orders (PENDING, ADMIN_PENDING, or CONFIRMED live orders)!
        final isNewOrderAlert = msgType == 'NEW_ORDER' ||
            msgType == 'STAFF_ALERT' ||
            data['screen'] == 'admin-orders' ||
            orderStatus == 'PENDING' ||
            orderStatus == 'ADMIN_PENDING' ||
            title.toString().contains('New Order') ||
            title.toString().contains('New Food') ||
            title.toString().contains('👨‍🍳') ||
            title.toString().contains('🛎️') ||
            title.toString().contains('🚨') ||
            title.toString().contains('🔔');

        if (!isNewOrderAlert && (
            msgType == 'ORDER_STATUS_UPDATE' ||
            msgType == 'STATUS_UPDATE' ||
            msgType == 'ORDER_STATUS' ||
            orderStatus == 'PREPARING' ||
            orderStatus == 'COOKING' ||
            orderStatus == 'PACKED' ||
            orderStatus == 'SHIPPED' ||
            orderStatus == 'OUT_FOR_DELIVERY' ||
            orderStatus == 'DELIVERED')) {
          debugPrint('NotificationService: Suppressed routine status update ($orderStatus) for Admin in foreground.');
          return;
        }
      }
    } catch (_) {}

    final rawOrderId = data['readableId'] ?? data['orderId'] ?? data['id'];
    final baseOrderNum = NotificationService.getBaseOrderNumber(rawOrderId);
    final cleanOrderId = baseOrderNum.isNotEmpty
        ? baseOrderNum
        : rawOrderId?.toString().trim().replaceAll('#', '');

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

    if (orderStatus == 'CANCELLED' || orderStatus == 'REJECTED' || orderStatus == 'FAILED' || orderStatus == 'DELIVERED') {
      await clearLiveOrderActivity(
        (data['orderId'] ?? data['id'] ?? '').toString(),
        readableId: data['readableId']?.toString(),
      );
    }

    final isStaff = await NotificationService.isStaffUser();

    final isStaffOrAdminMessage =
        data['screen'] == 'admin-orders' ||
        data['screen'] == 'restaurant-console' ||
        data['screen'] == 'delivery' ||
        data['screen'] == 'delivery-dashboard' ||
        data['type'] == 'DELIVERY_ASSIGNED' ||
        title.toString().contains('🛵') ||
        data['screen'] == 'picker' ||
        data['role'] == 'ADMIN' ||
        data['type'] == 'STAFF_ALERT' ||
        data['type'] == 'NEW_ORDER' ||
        title.toString().contains('👨‍🍳') ||
        title.toString().contains('🛎️') ||
        title.toString().toLowerCase().contains('kitchen') ||
        title.toString().toLowerCase().contains('new order');

    // ONLY suppress if the user is NOT staff (covers both confirmed CUSTOMER/USER and logged-out/empty role)
    if (!isStaff && isStaffOrAdminMessage) {
      debugPrint('NotificationService: Suppressing staff/admin alert for non-staff user in foreground.');
      return;
    }

    // Explicit customer tracking notifications must NEVER trigger loud alarms or buzzers
    final isCustomerNotification =
        data['role'] == 'CUSTOMER' ||
        data['screen'] == 'order-tracking' ||
        data['isLiveTracking'] == 'true' ||
        data['type'] == 'ORDER_PLACED' ||
        data['type'] == 'ORDER_STATUS_UPDATE';

    // Rider Loud Buzzer: STRICTLY & ONLY when a delivery order is newly assigned to this rider!
    final isDeliveryRiderAlert = !isCustomerNotification && isStaff && (
        data['type'] == 'DELIVERY_ASSIGNED' ||
        title.toString().toLowerCase().contains('delivery assigned') ||
        title.toString().toLowerCase().contains('new delivery assigned')
    );

    final isOnTheWayOrDelivering = orderStatus == 'SHIPPED' ||
        orderStatus == 'OUT_FOR_DELIVERY' ||
        orderStatus == 'ON_THE_WAY' ||
        title.toString().toLowerCase().contains('out for delivery') ||
        title.toString().toLowerCase().contains('on the way');

    final isOrderAlert = !isCustomerNotification && !isOnTheWayOrDelivering && isStaff && (isDeliveryRiderAlert || (!isCancelledOrTerminal && (
        data['type'] == 'NEW_ORDER' ||
        data['type'] == 'VENDOR_NEW_ORDER' ||
        orderStatus == 'PENDING' ||
        orderStatus == 'PLACED' ||
        orderStatus == 'ADMIN_PENDING' ||
        data['status'] == 'ADMIN_PENDING' ||
        data['screen'] == 'admin-orders' ||
        data['role'] == 'ADMIN' ||
        data['screen'] == 'restaurant-console' ||
        (data['restaurantId'] != null && (orderStatus == 'PENDING' || orderStatus == 'CONFIRMED' || orderStatus == 'PLACED' || data['type'] == 'NEW_ORDER')) ||
        title.toString().contains('👨‍🍳') ||
        title.toString().contains('🛎️') ||
        title.toString().contains('💳') ||
        title.toString().contains('🚨') ||
        title.toString().contains('🔔') ||
        title.toString().toLowerCase().contains('kitchen') ||
        title.toString().toLowerCase().contains('new order') ||
        title.toString().toLowerCase().contains('new live order') ||
        title.toString().toLowerCase().contains('new combined order') ||
        title.toString().toLowerCase().contains('combined order') ||
        title.toString().toLowerCase().contains('new approved order') ||
        title.toString().toLowerCase().contains('awaiting approval'))));

    final isOrderStatusUpdate = !isCancelledOrTerminal && !isOrderAlert && (
        isCustomerNotification ||
        !isStaff ||
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

    // Blinkit/Zepto Standard: Single dedicated slot for customer live tracking
    final notifId = isOrderStatusUpdate
        ? NotificationService.LIVE_TRACKING_NOTIF_ID
        : ((cleanOrderId != null && cleanOrderId.isNotEmpty)
            ? NotificationService.getOrderNotifId(cleanOrderId)
            : (isCartAlert ? 8888 : ('${title}_$body'.hashCode & 0x7FFFFFFF)));
    final tag = isOrderStatusUpdate
        ? NotificationService.LIVE_TRACKING_TAG
        : ((cleanOrderId != null && cleanOrderId.isNotEmpty)
            ? 'order_$cleanOrderId'
            : (isCartAlert ? 'cart_alert' : 'general_alert'));

    // UNIFY CHANNEL: Customer order tracking updates MUST use the Live Tracking Channel!
    // This guarantees Android mutates the single active card in-place instead of creating 2 duplicate notifications.
    if (isOrderAlert) {
      unawaited(playOrderChime(orderId: cleanOrderId, continuous: true));
    }

    final channelId = isOrderAlert
        ? 'fastminute_order_alarm_v3'
        : (isOrderStatusUpdate ? 'fastkirana_live_tracking_v1' : 'fastkirana_alerts');
    final channelName = isOrderAlert
        ? 'Store & Order Buzz Alerts'
        : (isOrderStatusUpdate ? 'Live Order Status & Dynamic Tracking' : 'FastMinute Alerts');
    final channelDesc = isOrderAlert
        ? 'Loud alarm for store, admin, and kitchen orders even when phone is locked.'
        : (isOrderStatusUpdate
            ? 'Persistent lock-screen live activity with real-time delivery progress.'
            : 'Notifications for order updates and tracking.');

    int? progress;
    if (orderStatus == 'CONFIRMED') {
      progress = 35;
    } else if (orderStatus == 'PREPARING' || orderStatus == 'COOKING') {
      progress = 45;
    } else if (orderStatus == 'PACKED') {
      progress = 60;
    } else if (orderStatus == 'SHIPPED' || orderStatus == 'OUT_FOR_DELIVERY') {
      progress = 80;
    } else if (orderStatus == 'ARRIVING_SOON') {
      progress = 95;
    } else if (orderStatus == 'DELIVERED') {
      progress = 100;
    } else if (orderStatus == 'PENDING' || orderStatus == 'ADMIN_PENDING' || orderStatus == 'PLACED') {
      progress = 15;
    }

    String cleanTitle;
    String cleanBodyText = body.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
    if (isOrderStatusUpdate && cleanOrderId != null && cleanOrderId.isNotEmpty) {
      if (orderStatus == 'PENDING' || orderStatus == 'ADMIN_PENDING' || orderStatus == 'PLACED') {
        cleanTitle = 'Store Verifying ⏳ • #$cleanOrderId';
        cleanBodyText = 'Ghatampur Central Hub is checking freshness & stock';
      } else if (orderStatus == 'CONFIRMED') {
        cleanTitle = 'Order Confirmed 👨‍🍳 • #$cleanOrderId';
        cleanBodyText = 'Store accepted your order & preparing fresh items';
      } else if (orderStatus == 'PREPARING' || orderStatus == 'COOKING') {
        cleanTitle = 'Preparing Fresh 🍲 • #$cleanOrderId';
        cleanBodyText = 'Store is preparing your fresh order items';
      } else if (orderStatus == 'PACKED') {
        cleanTitle = 'Order Packed 🛍️ • #$cleanOrderId';
        cleanBodyText = 'Store packed your fresh items • Awaiting rider pickup';
      } else if (orderStatus == 'SHIPPED' || orderStatus == 'OUT_FOR_DELIVERY') {
        cleanTitle = 'Out for Delivery 🛵 • #$cleanOrderId';
        cleanBodyText = 'Rider is on the way to your doorstep • Live GPS tracking';
      } else if (orderStatus == 'ARRIVING_SOON') {
        cleanTitle = 'Arriving Soon! 🛵 • #$cleanOrderId';
        cleanBodyText = 'Rider has reached your area and is arriving at your doorstep!';
      } else if (orderStatus == 'DELIVERED') {
        cleanTitle = '🎉 Order Delivered! • #$cleanOrderId';
        cleanBodyText = 'Your FastMinute order was delivered fresh. Enjoy!';
      } else {
        cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute').trim();
      }
    } else {
      cleanTitle = title.toString().replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute').trim();
    }
    cleanTitle = cleanTitle
        .replaceAll('Order Placed Successfully!', 'Order Placed!')
        .replaceAll('Combined Order Placed Successfully!', 'Order Placed!')
        .replaceAll('Combined Order Confirmed & Paid!', 'Order Confirmed & Paid!')
        .replaceAll('Online Payment Order Confirmed!', 'Order Confirmed!')
        .trim();

    final routeUrl = _resolveNotificationRoute(Map<String, dynamic>.from(message.data)) ??
        (isOrderAlert
            ? (message.data['role'] == 'DELIVERY' || message.data['type'] == 'DELIVERY_ASSIGNED' ? '/delivery' : '/admin-orders')
            : (cleanOrderId != null ? '/orders/$cleanOrderId/track' : '/orders'));

    _localNotifications?.show(
      notifId,
      cleanTitle,
      cleanBodyText,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: isOrderAlert ? Importance.max : Importance.high,
          priority: Priority.high,
          tag: tag,
          showWhen: true,
          ongoing: (isOrderStatusUpdate && orderStatus != 'DELIVERED' && orderStatus != 'CANCELLED'),
          onlyAlertOnce: true,
          showProgress: !isOrderAlert && progress != null,
          maxProgress: 100,
          progress: !isOrderAlert ? (progress ?? 0) : 0,
          color: const Color(0xFF00A344),
          colorized: true,
          subText: null, // STRICTLY NULL: prevents Android OS from appending truncated text ("Packe...") to header line!
          when: DateTime.now().millisecondsSinceEpoch,
          styleInformation: BigTextStyleInformation(
            cleanBodyText,
            contentTitle: cleanTitle,
            summaryText: isOrderStatusUpdate ? 'FastMinute Live' : null,
          ),
          playSound: isOrderAlert,
          sound: isOrderAlert ? const RawResourceAndroidNotificationSound('order_chime') : null,
          audioAttributesUsage: isOrderAlert ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
          enableVibration: isOrderAlert,
          vibrationPattern: isOrderAlert
              ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000])
              : null,
          actions: isOrderStatusUpdate && cleanOrderId != null && cleanOrderId.isNotEmpty
              ? [
                  const AndroidNotificationAction(
                    'open_live_track',
                    '📍 Live Tracking',
                    showsUserInterface: true,
                  ),
                ]
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: routeUrl.toString(),
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

  static String? _lastLiveActivityOrderId;
  static String? _lastLiveActivityTitle;
  static String? _lastLiveActivityBody;
  static int? _lastLiveActivityProgress;
  static int _lastLiveActivityTimestamp = 0;

  /// ─── LIVE ACTIVITY & LOCK SCREEN WIDGET (Android Ongoing Notification & iOS Time-Sensitive) ───
  /// Displays live lock screen status: "Arriving in 6 mins 🛵 • #4220"
  /// Updates silently without playing a chime or vibrating continuously.
  Future<void> updateLiveOrderActivity({
    required Order order,
    String? customEtaText,
    String? customStatusText,
    int? customProgress,
  }) async {
    if (kIsWeb) return;

    final isTerminal = order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled;
    final baseNum = NotificationService.getBaseOrderNumber(
      order.readableId != null && order.readableId!.trim().isNotEmpty
          ? order.readableId!
          : (order.displayId.isNotEmpty ? order.displayId : order.id),
    );
    final displayTag = baseNum.isNotEmpty ? '#$baseNum' : '#ORDER';
    // Blinkit/Zepto Standard: Unified persistent Live Activity tag & ID
    final notifTag = NotificationService.LIVE_TRACKING_TAG;
    final int notifId = NotificationService.LIVE_TRACKING_NOTIF_ID;

    if (isTerminal) {
      _lastLiveActivityOrderId = null;
      _lastLiveActivityTitle = null;
      _lastLiveActivityBody = null;
      _lastLiveActivityProgress = null;
      _lastLiveActivityTimestamp = 0;
      await clearLiveOrderActivity(order.id, readableId: order.readableId);
      if (order.status == OrderStatus.delivered) {
        // Show one-time celebration delivery notification with pleasant chime
        try {
          final androidDelivered = AndroidNotificationDetails(
            'fastkirana_live_tracking_v1',
            'Live Order Status & Dynamic Tracking',
            channelDescription: 'Real-time alerts for delivered orders.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            sound: null,
            enableVibration: false,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF00A344),
            colorized: true,
            tag: notifTag,
            subText: null,
            styleInformation: BigTextStyleInformation(
              'Your FastMinute order was delivered. Thank you for shopping fresh with us! 🎉',
              contentTitle: '🎉 Order Delivered! • $displayTag',
              summaryText: 'Delivered',
            ),
          );
          const iosDelivered = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
            subtitle: 'Delivered Successfully 🎉',
          );
          await _localNotifications?.show(
            notifId,
            '🎉 Order Delivered! • $displayTag',
            'Your FastMinute order was delivered. Enjoy!',
            NotificationDetails(android: androidDelivered, iOS: iosDelivered),
            payload: '/orders/${order.readableId ?? order.id}/track',
          );
        } catch (_) {}
      }
      return;
    }

    String title;
    String body;
    int progress;
    List<AndroidNotificationAction> actions = [];

    final rawRiderName = (order.deliveryBoyName != null && order.deliveryBoyName!.trim().isNotEmpty)
        ? order.deliveryBoyName!.trim()
        : (order.deliveryUser?.name != null && order.deliveryUser!.name!.trim().isNotEmpty
            ? order.deliveryUser!.name!.trim()
            : '');
    final riderName = rawRiderName.isNotEmpty ? rawRiderName : 'Delivery Partner';
    final rawRiderPhone = (order.deliveryBoyPhone != null && order.deliveryBoyPhone!.trim().isNotEmpty)
        ? order.deliveryBoyPhone!.trim()
        : (order.deliveryUser?.phone ?? '');
    final cleanPhone = rawRiderPhone.replaceAll(RegExp(r'[^0-9]'), '');

    switch (order.status) {
      case OrderStatus.shipped:
        if (customEtaText != null && customEtaText.isNotEmpty && customEtaText != 'Delivered 🎉') {
          if (customEtaText.toLowerCase().contains('now') || customEtaText.toLowerCase().contains('arriving')) {
            title = 'Arriving Now! 🛵 • $displayTag';
            body = '$riderName has reached your doorstep!\n📍 FastMinute Live Doorstep Delivery';
            progress = customProgress ?? 95;
          } else {
            title = 'Arriving in $customEtaText 🛵 • $displayTag';
            body = '$riderName is on the way to your doorstep\n📍 FastMinute Live GPS Tracking';
            progress = customProgress ?? 80;
          }
        } else {
          title = 'Out for Delivery 🛵 • $displayTag';
          body = '$riderName is heading to your doorstep\n📍 FastMinute Live GPS Tracking';
          progress = customProgress ?? 75;
        }

        actions = [
          const AndroidNotificationAction(
            'open_live_track',
            '📍 Live Map',
            showsUserInterface: true,
          ),
          if (cleanPhone.isNotEmpty)
            const AndroidNotificationAction(
              'call_rider',
              '📞 Call Rider',
              showsUserInterface: true,
            ),
        ];
        break;

      case OrderStatus.packed:
        title = 'Order Packed 🛍️ • $displayTag';
        body = rawRiderName.isNotEmpty
            ? '$riderName is assigned & picking up package\n🏪 Ghatampur Central Hub'
            : 'Store packed your fresh items • Awaiting rider pickup\n🏪 Ghatampur Central Hub';
        progress = customProgress ?? 60;
        actions = [
          const AndroidNotificationAction(
            'open_live_track',
            '📍 Track Status',
            showsUserInterface: true,
          ),
        ];
        break;

      case OrderStatus.confirmed:
        title = 'Order Confirmed 👨‍🍳 • $displayTag';
        body = 'Store accepted your order & preparing fresh items\n🏪 Ghatampur Central Hub';
        progress = customProgress ?? 35;
        actions = [
          const AndroidNotificationAction(
            'open_live_track',
            '📍 Live Status',
            showsUserInterface: true,
          ),
        ];
        break;

      case OrderStatus.adminPending:
      case OrderStatus.pending:
      default:
        title = 'Store Verifying ⏳ • $displayTag';
        body = 'Ghatampur Central Hub is checking freshness & stock\n⏳ FastMinute Express';
        progress = customProgress ?? 15;
        actions = [
          const AndroidNotificationAction(
            'open_live_track',
            '📍 View Order',
            showsUserInterface: true,
          ),
        ];
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
      ongoing: true, // Lock screen persistent dynamic activity
      autoCancel: false,
      onlyAlertOnce: true, // Updates silently without chime on every GPS tick
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      subText: null, // STRICTLY NULL: prevents Android OS from appending truncated text ("Packe...") to header line!
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'FastMinute Live',
      ),
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      color: const Color(0xFF00A344),
      colorized: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      tag: notifTag,
      actions: actions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'order_tracking',
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (order.id == _lastLiveActivityOrderId &&
        title == _lastLiveActivityTitle &&
        body == _lastLiveActivityBody &&
        progress == _lastLiveActivityProgress &&
        (nowMs - _lastLiveActivityTimestamp < 8000)) {
      return;
    }
    _lastLiveActivityOrderId = order.id;
    _lastLiveActivityTitle = title;
    _lastLiveActivityBody = body;
    _lastLiveActivityProgress = progress;
    _lastLiveActivityTimestamp = nowMs;

    try {
      await _localNotifications?.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: '/orders/${order.readableId ?? order.id}/track?phone=$cleanPhone',
      );
    } catch (e, st) {
      LoggerService.error('NotificationService: updateLiveOrderActivity error', e, st);
    }
  }

  /// Clears ongoing lock screen tracking widget once order is delivered or cancelled
  Future<void> clearLiveOrderActivity(String orderId, {String? readableId}) async {
    if (kIsWeb) return;
    try {
      final p = _localNotifications ?? FlutterLocalNotificationsPlugin();
      await p.cancel(LIVE_TRACKING_NOTIF_ID, tag: LIVE_TRACKING_TAG);
      await p.cancel(LIVE_TRACKING_NOTIF_ID);
    } catch (_) {}
    await clearOrderNotificationsById(
      orderId,
      readableId: readableId,
      plugin: _localNotifications,
    );
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

  Future<void> _trackSubscribedTopic(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(prefs.getStringList(_subscribedTopicsPrefKey) ?? const []);
      if (!list.contains(topic)) {
        list.add(topic);
        await prefs.setStringList(_subscribedTopicsPrefKey, list);
      }
    } catch (_) {}
  }

  Future<void> _untrackSubscribedTopic(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(prefs.getStringList(_subscribedTopicsPrefKey) ?? const []);
      if (list.remove(topic)) {
        await prefs.setStringList(_subscribedTopicsPrefKey, list);
      }
    } catch (_) {}
  }

  Set<String> _knownStaffTopics({String? storeId, String? restaurantId}) {
    final topics = <String>{
      'admin_orders',
      'admin_orders_all',
      'staff_orders',
      'picker_orders',
      'delivery_orders',
      'admin_orders_wedson_store',
      'admin_orders_ghatampur',
      'staff_orders_wedson_store',
      'staff_orders_ghatampur',
    };
    for (final hub in _knownHubIds) {
      topics.add('admin_orders_$hub');
      topics.add('staff_orders_$hub');
      topics.add('picker_orders_$hub');
      topics.add('delivery_orders_$hub');
    }
    if (storeId != null && storeId.isNotEmpty) {
      topics.add('admin_orders_$storeId');
      topics.add('staff_orders_$storeId');
      topics.add('picker_orders_$storeId');
      topics.add('delivery_orders_$storeId');
    }
    if (restaurantId != null && restaurantId.isNotEmpty) {
      topics.add('restaurant_$restaurantId');
      topics.add('kitchen_$restaurantId');
      topics.add('restaurant_orders_$restaurantId');
    }
    return topics;
  }

  Future<void> _purgeTopics(Iterable<String> candidateTopics, {Set<String> keep = const {}}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tracked = prefs.getStringList(_subscribedTopicsPrefKey) ?? const <String>[];
      final toUnsub = <String>{...candidateTopics, ...tracked}.difference(keep).toList();
      if (toUnsub.isEmpty) return;

      await Future.wait(
        toUnsub.map((t) async {
          try {
            await _fcm?.unsubscribeFromTopic(t);
          } catch (_) {}
        }),
      );

      final remaining = tracked.where((t) => keep.contains(t)).toList();
      await prefs.setStringList(_subscribedTopicsPrefKey, remaining);
    } catch (_) {}
  }

  Future<void> registerDeviceToken(
    Dio dio, {
    String? role,
    String? assignedRestaurantId,
    String? assignedStoreId,
  }) async {
    if (kIsWeb) return;
    _lastDio = dio;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Finish any pending offline logout unregister before registering the new user
      if (prefs.getBool(_pendingCleanupPrefKey) == true) {
        final pendingToken = prefs.getString(_pendingUnregisterTokenKey);
        if (pendingToken != null && pendingToken.isNotEmpty) {
          try {
            await dio.post('/api/fcm/unregister', data: {'token': pendingToken});
            await prefs.remove(_pendingUnregisterTokenKey);
          } catch (_) {}
        }
        await _purgeTopics(_knownStaffTopics(), keep: const {});
        await prefs.remove(_pendingCleanupPrefKey);
      }

      String? token = await getFcmToken();
      if (token == null) return;

      String deviceType = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'));
      final userId = (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
      final phone = (await SecureStorage.read('user_phone')) ?? prefs.getString('user_phone') ?? '';
      final resolvedRole = (role ?? prefs.getString('user_role') ?? (await SecureStorage.read('user_role')) ?? 'USER').toUpperCase().trim();
      final storeId = assignedStoreId ?? prefs.getString('assigned_store_id') ?? (await SecureStorage.read('assigned_store_id'));
      final rId = assignedRestaurantId ?? prefs.getString('assigned_restaurant_id') ?? (await SecureStorage.read('assigned_restaurant_id'));

      final savedUserRole = (prefs.getString('user_role') ?? (await SecureStorage.read('user_role')) ?? '').toUpperCase().trim();
      final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final tenDigit = cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
      final isSuperAdminPhone = tenDigit == '9170942500';
      final isGhatampurAdminPhone = tenDigit == '7054470303';
      final isBarharwaAdminPhone = tenDigit == '7633898577';
      final isRiderPhone = tenDigit == '9450358388';

      final isAdminPhone = isSuperAdminPhone || isGhatampurAdminPhone || isBarharwaAdminPhone;
      final isMasterAdmin = isSuperAdminPhone || savedUserRole == 'SUPER_ADMIN';

      // Strictly map role & hub based on verified official credentials
      final effectiveRole = isRiderPhone
          ? 'DELIVERY'
          : (isAdminPhone ? 'ADMIN' : resolvedRole);

      final effectiveStoreId = isGhatampurAdminPhone || isRiderPhone
          ? 'hub-209206'
          : (isBarharwaAdminPhone ? 'hub-816101' : storeId);

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

      // Subscribe to role-based and user-specific topics, and strictly purge all other role/hub/outlet topics
      try {
        final keepTopics = <String>{
          'all_users',
          'ghatampur_alerts',
          if (userId != null && userId.isNotEmpty) 'user_$userId',
        };
        final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (cleanPhone.length == 10) {
          keepTopics.add('phone_$cleanPhone');
        }

        if (isAdmin) {
          final adminTopics = <String>{
            if (isMasterAdmin) ...[
              'admin_orders',
              'admin_orders_all',
              'admin_orders_ghatampur',
              'admin_orders_barharwa',
              'admin_orders_akbarpur',
              'admin_orders_hub-209206',
              'admin_orders_hub-816101',
              'admin_orders_hub-224122',
            ] else if (effectiveStoreId == 'hub-209206') ...[
              'admin_orders_ghatampur',
              'admin_orders_hub-209206',
            ] else if (effectiveStoreId == 'hub-816101') ...[
              'admin_orders_barharwa',
              'admin_orders_hub-816101',
            ] else if (effectiveStoreId == 'hub-224122') ...[
              'admin_orders_akbarpur',
              'admin_orders_hub-224122',
            ] else if (effectiveStoreId != null && effectiveStoreId.isNotEmpty) ...[
              'admin_orders_$effectiveStoreId',
            ],
          };
          for (final topic in adminTopics) {
            keepTopics.add(topic);
            await subscribeToTopic(topic);
          }
          await _purgeTopics(_knownStaffTopics(storeId: effectiveStoreId, restaurantId: rId), keep: keepTopics);
        } else if (isRestaurant) {
          if (rId != null && rId.isNotEmpty) {
            final restTopic = 'restaurant_$rId';
            keepTopics.add(restTopic);
            await subscribeToTopic(restTopic);
          }
          // Strictly purge ALL admin, staff, picker, delivery, and other restaurant topics
          await _purgeTopics(_knownStaffTopics(storeId: effectiveStoreId, restaurantId: rId), keep: keepTopics);
        } else if (isDeliveryOrPicker) {
          final isPicker = effectiveRole == 'PICKER';
          final topic = isPicker
              ? ((effectiveStoreId != null && effectiveStoreId.isNotEmpty) ? 'picker_orders_$effectiveStoreId' : 'picker_orders')
              : ((effectiveStoreId != null && effectiveStoreId.isNotEmpty) ? 'delivery_orders_$effectiveStoreId' : 'delivery_orders');
          keepTopics.add(topic);
          await subscribeToTopic(topic);
          await _purgeTopics(_knownStaffTopics(storeId: effectiveStoreId, restaurantId: rId), keep: keepTopics);
        } else {
          // Normal CUSTOMER / USER (or guest): Actively purge EVERY tracked + known admin/staff/hub/kitchen topic!
          await _purgeTopics(_knownStaffTopics(storeId: storeId, restaurantId: rId), keep: keepTopics);
        }

        if (userId != null && userId.isNotEmpty) {
          await subscribeToTopic('user_$userId');
        }
        if (cleanPhone.length == 10) {
          await subscribeToTopic('phone_$cleanPhone');
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
      await _trackSubscribedTopic(topic);
    } catch (e, _) { LoggerService.error('NotificationService: error', e); }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm?.unsubscribeFromTopic(topic);
      await _untrackSubscribedTopic(topic);
    } catch (e, _) { LoggerService.error('NotificationService: error', e); }
  }

  /// Unsubscribe from ALL FCM topics on logout so no notifications arrive when logged out
  Future<void> unsubscribeAllTopics({
    Dio? dio,
    String? explicitUserId,
    String? explicitPhone,
    String? explicitStoreId,
    String? explicitRestaurantId,
  }) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    String? token;
    try {
      final userId = explicitUserId ?? (await SecureStorage.read('user_id')) ?? prefs.getString('user_id');
      final phone = explicitPhone ?? (await SecureStorage.read('user_phone')) ?? prefs.getString('user_phone') ?? '';
      final restaurantId = explicitRestaurantId ?? (await SecureStorage.read('assigned_restaurant_id')) ?? prefs.getString('assigned_restaurant_id');
      final storeId = explicitStoreId ?? (await SecureStorage.read('assigned_store_id')) ?? prefs.getString('assigned_store_id');
      token = await getFcmToken();

      // 1. Collect EVERY subscribed & known staff/admin/hub/user topic
      final tracked = prefs.getStringList(_subscribedTopicsPrefKey) ?? const <String>[];
      final topics = <String>{
        ...tracked,
        ..._knownStaffTopics(storeId: storeId, restaurantId: restaurantId),
        'all_users',
        'ghatampur_alerts',
      };

      if (userId != null && userId.isNotEmpty) {
        topics.add('user_$userId');
      }
      if (phone.isNotEmpty) {
        final cleanPhone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (cleanPhone.length == 10) {
          topics.add('phone_$cleanPhone');
        }
      }

      // 2. Unsubscribe all topics in parallel + notify backend unregister simultaneously
      var backendUnregistered = false;
      await Future.wait([
        ...topics.map((topic) async {
          try {
            await _fcm?.unsubscribeFromTopic(topic);
          } catch (_) {}
        }),
        if (dio != null && token != null && token.isNotEmpty)
          dio.post('/api/fcm/unregister', data: {
            'token': token,
            if (userId != null && userId.isNotEmpty) 'userId': userId,
          }).then((res) {
            if (res.statusCode == 200) backendUnregistered = true;
          }).catchError((_) {}),
      ]);

      // 3. Delete the FCM token on device so a clean new token is minted for subsequent logins
      try {
        await _fcm?.deleteToken();
      } catch (_) {}

      await prefs.remove(_subscribedTopicsPrefKey);
      if (!backendUnregistered && token != null && token.isNotEmpty) {
        await prefs.setBool(_pendingCleanupPrefKey, true);
        await prefs.setString(_pendingUnregisterTokenKey, token);
      } else {
        await prefs.remove(_pendingCleanupPrefKey);
        await prefs.remove(_pendingUnregisterTokenKey);
      }

      debugPrint('NotificationService: Unsubscribed from ${topics.length} topics on logout (backendUnregistered=$backendUnregistered)');
    } catch (e, _) {
      await prefs.setBool(_pendingCleanupPrefKey, true);
      if (token != null && token.isNotEmpty) {
        await prefs.setString(_pendingUnregisterTokenKey, token);
      }
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
