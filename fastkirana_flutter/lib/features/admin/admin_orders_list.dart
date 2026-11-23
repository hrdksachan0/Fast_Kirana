import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastminute_flutter/core/theme/design_system.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/route_detector.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/kot_print_service.dart';
import '../../core/services/admin_authorization.dart';
import '../../core/models/order_event.dart';
import '../../core/services/order_event_bus.dart';
import '../../core/services/alert_engine.dart';
import '../../core/utils/app_toast.dart';
import '../delivery/widgets/connectivity_banner.dart';
import '../common/order_edit_modal.dart';
import 'widgets/admin_order_card.dart';
import 'widgets/admin_stats_grid.dart';
import 'widgets/admin_filter_header.dart';
import 'widgets/admin_auto_approve_banner.dart';
import 'widgets/admin_substitution_sheet.dart';
import 'widgets/admin_refund_sheet.dart';
import 'widgets/admin_share_sheet.dart';
import 'widgets/admin_orders_empty_view.dart';
import 'widgets/admin_console_skeletons.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/order_alarm_service.dart';
import '../common/widgets/battery_optimization_dialog.dart';
import '../../core/services/secure_storage_service.dart';
import '../../widgets/app_confirmation_dialog.dart';

class _OptimisticStatusLock {
  final OrderStatus status;
  final DateTime lockedAt;
  final int durationSeconds;

  _OptimisticStatusLock({
    required this.status,
    required this.lockedAt,
    this.durationSeconds = 8,
  });

  bool get isExpired => DateTime.now().difference(lockedAt).inSeconds >= durationSeconds;
}

class _OptimisticRiderLock {
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final bool isUnassigned;
  final DateTime lockedAt;
  final int durationSeconds;

  _OptimisticRiderLock({
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.isUnassigned = false,
    required this.lockedAt,
    this.durationSeconds = 12,
  });

  bool get isExpired => DateTime.now().difference(lockedAt).inSeconds >= durationSeconds;
}

class AdminOrdersScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminOrdersScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen>
    with AutomaticKeepAliveClientMixin<AdminOrdersScreen>, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  // 0 = Live Orders, 1 = Order History
  int _selectedTab = 0;
  String _liveSubFilter = 'ALL';
  String _historySubFilter = 'ALL';
  String _selectedOutlet = 'ALL';
  DeliveryRouteKey _selectedRoadCorridor = DeliveryRouteKey.all;
  String _selectedRiderFilter = 'ALL';
  String _searchQuery = '';

  static List<Order> _cachedOrders = [];
  List<Order> _allOrders = _cachedOrders;
  bool _isLoading = _cachedOrders.isEmpty;
  static final Map<String, DateTime> _recentlyDeliveredOrderIds = {};
  static final Map<String, _OptimisticStatusLock> _optimisticStatusLocks = {};
  static final Map<String, _OptimisticRiderLock> _optimisticRiderLocks = {};
  final Set<String> _inProgressOrderIds = {};

  static void _lockOrderStatus(String orderId, OrderStatus status, {int durationSeconds = 8}) {
    final cleanId = orderId.trim();
    if (cleanId.isEmpty) return;
    _optimisticStatusLocks[cleanId] = _OptimisticStatusLock(
      status: status,
      lockedAt: DateTime.now(),
      durationSeconds: durationSeconds,
    );
  }

  static OrderStatus? _getLockedStatus(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return null;
    final cleanId = orderId.trim();
    final lock = _optimisticStatusLocks[cleanId];
    if (lock == null) return null;
    if (lock.isExpired) {
      _optimisticStatusLocks.remove(cleanId);
      return null;
    }
    return lock.status;
  }

  static void _lockRiderAssignment({
    required List<String> orderIds,
    String? riderId,
    String? riderName,
    String? riderPhone,
    bool isUnassigned = false,
    int durationSeconds = 12,
  }) {
    final now = DateTime.now();
    for (final id in orderIds) {
      final cleanId = id.trim();
      if (cleanId.isEmpty) continue;
      _optimisticRiderLocks[cleanId] = _OptimisticRiderLock(
        riderId: riderId,
        riderName: riderName,
        riderPhone: riderPhone,
        isUnassigned: isUnassigned,
        lockedAt: now,
        durationSeconds: durationSeconds,
      );
    }
  }

  static _OptimisticRiderLock? _getLockedRider(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return null;
    final cleanId = orderId.trim();
    final lock = _optimisticRiderLocks[cleanId];
    if (lock == null) return null;
    if (lock.isExpired) {
      _optimisticRiderLocks.remove(cleanId);
      return null;
    }
    return lock;
  }

  static int _orderStatusRank(OrderStatus s) {
    switch (s) {
      case OrderStatus.adminPending:
        return 0;
      case OrderStatus.pending:
        return 1;
      case OrderStatus.confirmed:
        return 2;
      case OrderStatus.packed:
        return 3;
      case OrderStatus.shipped:
        return 4;
      case OrderStatus.delivered:
        return 5;
      case OrderStatus.cancelled:
        return 6;
    }
  }

  // Persistent previous state stats to avoid UI jumping abruptly to 0 0 0 0
  static double _lastTodaySales = 0.0;
  static double _lastNetSales = 0.0;
  static int _lastTodayOrdersCount = 0;
  static int _lastActiveOrderCount = 0;
  static int _lastLiveCount = 0;
  static int _lastHistoryCount = 0;
  static int _lastPendingPaymentCount = 0;
  static double _lastDeliveryFee = 0.0;
  static double _lastPackagingFee = 0.0;

  static const String _diskAdminOrdersKey = 'cached_admin_orders_v2';

  static String _getTodayDateKey() {
    final nowUtc = DateTime.now().toUtc();
    final istNow = nowUtc.add(const Duration(hours: 5, minutes: 30));
    return '${istNow.year}-${istNow.month.toString().padLeft(2, '0')}-${istNow.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDiskOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStoreId = prefs.getString('assigned_store_id');
      if (savedStoreId != null && savedStoreId.isNotEmpty) {
        _assignedStoreId = savedStoreId;
      }

      final todayKey = _getTodayDateKey();
      final savedDate = prefs.getString('admin_stats_saved_date');

      // Only load cached metrics if they belong to TODAY!
      if (savedDate == todayKey) {
        _lastTodaySales = prefs.getDouble('admin_last_today_sales') ?? _lastTodaySales;
        _lastNetSales = prefs.getDouble('admin_last_net_sales') ?? _lastNetSales;
        _lastTodayOrdersCount = prefs.getInt('admin_last_today_orders_count') ?? _lastTodayOrdersCount;
        _lastActiveOrderCount = prefs.getInt('admin_last_active_orders_count') ?? _lastActiveOrderCount;
        _lastLiveCount = prefs.getInt('admin_last_live_count') ?? _lastLiveCount;
        _lastHistoryCount = prefs.getInt('admin_last_history_count') ?? _lastHistoryCount;
        _lastPendingPaymentCount = prefs.getInt('admin_last_pending_payment_count') ?? _lastPendingPaymentCount;
        _lastDeliveryFee = prefs.getDouble('admin_last_delivery_fee') ?? _lastDeliveryFee;
        _lastPackagingFee = prefs.getDouble('admin_last_packaging_fee') ?? _lastPackagingFee;
      } else {
        // Date changed! Reset previous metrics to 0 so yesterday's figures do not flash
        _lastTodaySales = 0.0;
        _lastNetSales = 0.0;
        _lastTodayOrdersCount = 0;
        _lastActiveOrderCount = 0;
        _lastLiveCount = 0;
        _lastHistoryCount = 0;
        _lastPendingPaymentCount = 0;
        _lastDeliveryFee = 0.0;
        _lastPackagingFee = 0.0;
      }

      final raw = prefs.getString(_diskAdminOrdersKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded.map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) {
          _cachedOrders = list;
          if (_allOrders.isEmpty) {
            setState(() {
              _allOrders = list;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminOrdersList] disk load error: $e');
    }
  }

  Future<void> _saveDiskOrders(List<Order> orders) async {
    if (orders.isEmpty) return; // Never overwrite disk cache with empty list
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep most recent 100 orders on disk
      final toSave = orders.take(100).map((o) => o.toJson()).toList();
      await prefs.setString(_diskAdminOrdersKey, jsonEncode(toSave));
    } catch (e) {
      debugPrint('[AdminOrdersList] disk save error: $e');
    }
  }

  static Future<void> _persistStats({
    required double todaySales,
    required double netSales,
    required int todayOrdersCount,
    required int activeOrderCount,
    required int liveCount,
    required int historyCount,
    required int pendingPaymentCount,
    required double deliveryFee,
    required double packagingFee,
  }) async {
    _lastTodaySales = todaySales;
    _lastNetSales = netSales;
    _lastTodayOrdersCount = todayOrdersCount;
    _lastActiveOrderCount = activeOrderCount;
    _lastLiveCount = liveCount;
    _lastHistoryCount = historyCount;
    _lastPendingPaymentCount = pendingPaymentCount;
    _lastDeliveryFee = deliveryFee;
    _lastPackagingFee = packagingFee;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_stats_saved_date', _getTodayDateKey());
      await prefs.setDouble('admin_last_today_sales', todaySales);
      await prefs.setDouble('admin_last_net_sales', netSales);
      await prefs.setInt('admin_last_today_orders_count', todayOrdersCount);
      await prefs.setInt('admin_last_active_orders_count', activeOrderCount);
      await prefs.setInt('admin_last_live_count', liveCount);
      await prefs.setInt('admin_last_history_count', historyCount);
      await prefs.setInt('admin_last_pending_payment_count', pendingPaymentCount);
      await prefs.setDouble('admin_last_delivery_fee', deliveryFee);
      await prefs.setDouble('admin_last_packaging_fee', packagingFee);
    } catch (_) {}
  }
  String? _error;
  Timer? _liveSyncTimer;
  RealtimeChannel? _realtimeOrdersChannel;
  StreamSubscription<OrderEvent>? _adminEventBusSub;
  bool _isFetchingAdmin = false;
  bool _needsRefetch = false;

  static const Color primaryRed = AppDesignSystem.primary;

  bool _isAutoApprove = false;
  final Set<String> _dismissedOrAcknowledgedAlarmOrders = {};

  Future<void> _loadAutoApproveSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getBool('admin_auto_approve_orders') ?? false;
      if (mounted) setState(() => _isAutoApprove = local);

      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/settings');
      if (res.data != null && res.data is Map) {
        final serverVal = res.data['admin_auto_approve_orders'] == 'true' || res.data['admin_auto_approve_orders'] == true;
        if (mounted) {
          setState(() => _isAutoApprove = serverVal);
          await prefs.setBool('admin_auto_approve_orders', serverVal);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleAutoApprove(bool val) async {
    HapticFeedback.mediumImpact();
    setState(() => _isAutoApprove = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_auto_approve_orders', val);

      final dio = ref.read(dioProvider);
      await dio.patch(
        '/api/admin/settings',
        data: {'admin_auto_approve_orders': val ? 'true' : 'false'},
        options: AdminAuthorization.options(),
      );

      final sb = SupabaseService.client;
      if (sb != null) {
        await sb.from('store_settings').upsert({
          'key': 'admin_auto_approve_orders',
          'value': val ? 'true' : 'false',
        });
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          val ? '⚡ Auto-Approve Activated' : '🔒 Manual Verification Required',
          subtitle: val ? 'New orders will reach kitchen directly' : 'Orders will wait for Admin call confirmation',
        );
      }
    } catch (e) {
      debugPrint('[AutoApprove toggle error]: $e');
    }
  }

  final Set<String> _printedKOTOrders = {};
  final Set<String> _sendingKOTOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _liveStatusFilters = [
    'ALL',
    'PAYMENT_PENDING',
    'ADMIN_PENDING',
    'PENDING',
    'CONFIRMED',
    'PACKED',
    'SHIPPED',
  ];

  final List<String> _historyStatusFilters = [
    'ALL',
    'DELIVERED',
    'CANCELLED',
  ];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDeviceOffline = false;
  String? _assignedStoreId = 'hub-209206';

  List<Map<String, String>> _availableRiders = [];

  Future<void> _fetchAdminProfile() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/admin/me', options: AdminAuthorization.options());
      if (res.data != null) {
        final sId = res.data['assignedStoreId']?.toString();
        if (sId != null && sId.isNotEmpty && mounted) {
          final wasDifferent = _assignedStoreId != sId;
          setState(() {
            _assignedStoreId = sId;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('assigned_store_id', sId);
          await SecureStorage.write('assigned_store_id', sId);
          _fetchDeliveryRiders();
          if (wasDifferent) {
            _silentFetchAdminOrders();
          }
        }
      }
    } catch (e) {
      debugPrint('[Admin] Profile fetch error: $e');
    }
  }

  Future<void> _fetchDeliveryRiders() async {
    try {
      final dio = ref.read(dioProvider);
      final prefs = await SharedPreferences.getInstance();
      final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
      final res = await dio.get(
        '/api/admin/riders',
        queryParameters: (storeId != null && storeId.isNotEmpty) ? {'storeId': storeId} : null,
      );
      if (res.data != null && res.data['riders'] is List) {
        final List list = res.data['riders'];
        if (mounted) {
          setState(() {
            _availableRiders = list.map<Map<String, String>>((r) => {
              'id': r['id']?.toString() ?? '',
              'name': r['name']?.toString() ?? 'Rider',
              'phone': r['phone']?.toString() ?? '',
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('[Admin] Failed to fetch riders: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityAndOfflineQueue();
    _fetchAdminProfile();
    _fetchDeliveryRiders();
    _initAudioPlayer();
    _loadAutoApproveSetting();
    _initNotificationSubscriptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BatteryOptimizationDialog.showIfNecessary(context);
      }
    });

    _loadDiskOrders().then((_) {
      if (mounted) {
        if (_allOrders.isNotEmpty) {
          _silentFetchAdminOrders();
        } else {
          _fetchAdminOrders();
        }
      }
    });

    // 0. Unified EventBus listener for instant real-time sync & alerts
    _adminEventBusSub?.cancel();
    _adminEventBusSub = OrderEventBus.instance.forStore(_assignedStoreId).listen((event) {
      if (!mounted) return;
      debugPrint('[Admin] ⚡ EventBus order event: tag=${event.tag} status=${event.status} urgency=${event.alert.urgency}');
      
      if (event.alert.urgency == 'CRITICAL' || event.tag == 'ORDER_CREATED') {
        final id = event.orderId;
        final rid = event.readableId;
        if (!_dismissedOrAcknowledgedAlarmOrders.contains(id) && !_dismissedOrAcknowledgedAlarmOrders.contains(rid)) {
          AlertEngine.handle(event, currentUserRole: 'ADMIN', context: context);
        }
      }
      _silentFetchAdminOrders();
    });

    // 1. Ultra-fast WebSocket Realtime Connection (0ms instant sync)
    _realtimeOrdersChannel = SupabaseService.subscribeToAllOrdersRealtime(
      onOrderChange: (record) {
        if (!_isDeviceOffline) {
          final isKot = record['event'] == 'kot_printed' || record['kotPrinted'] == true;
          if (isKot) {
            final oid = (record['orderId'] ?? record['id'])?.toString();
            final rid = record['readableId']?.toString();
            if (oid != null && oid.isNotEmpty) _printedKOTOrders.add(oid);
            if (rid != null && rid.isNotEmpty) _printedKOTOrders.add(rid);
            if (mounted) setState(() {});
            return;
          }

          final orderStoreId = record['storeId']?.toString();
          if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty &&
              orderStoreId != null && orderStoreId.isNotEmpty &&
              _assignedStoreId != orderStoreId) {
            return; // Ignore order updates from other dark store hubs
          }
          debugPrint('[Admin WebSocket] Live order update event: ${record['id']}');
          final orderId = (record['orderId'] ?? record['id'])?.toString();
          final readableId = record['readableId']?.toString();

          // Suppress echo if this order is actively locked by our own optimistic action (status or rider)
          if ((orderId != null && (_getLockedStatus(orderId) != null || _getLockedRider(orderId) != null)) ||
              (readableId != null && (_getLockedStatus(readableId) != null || _getLockedRider(readableId) != null))) {
            debugPrint('[Admin WebSocket] Skipping echo for actively locked order: $orderId / $readableId');
            return;
          }
          final rawStatus = (record['status'] ?? '').toString();
          if (orderId != null && rawStatus.isNotEmpty) {
            final parsedStatus = Order.parseStatus(rawStatus);
            for (var i = 0; i < _allOrders.length; i++) {
              if (_allOrders[i].id == orderId || (readableId != null && _allOrders[i].readableId == readableId)) {
                _allOrders[i] = _allOrders[i].copyWith(
                  status: parsedStatus,
                  deliveredAt: parsedStatus == OrderStatus.delivered ? DateTime.now() : _allOrders[i].deliveredAt,
                  confirmedAt: parsedStatus == OrderStatus.confirmed ? DateTime.now() : _allOrders[i].confirmedAt,
                );
                break;
              }
            }
            if (parsedStatus == OrderStatus.confirmed ||
                parsedStatus == OrderStatus.delivered ||
                parsedStatus == OrderStatus.packed ||
                parsedStatus == OrderStatus.shipped ||
                parsedStatus == OrderStatus.cancelled) {
              _dismissedOrAcknowledgedAlarmOrders.add(orderId);
              if (readableId != null) {
                _dismissedOrAcknowledgedAlarmOrders.add(readableId);
                final base = readableId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim();
                if (base.isNotEmpty) _dismissedOrAcknowledgedAlarmOrders.add(base);
              }
              _stopPendingAlarm();
            }
            if (mounted) setState(() {});
          }

          _silentFetchAdminOrders();
          final status = (record['status'] ?? '').toString().toUpperCase();
          if (status == 'CANCELLED' || status == 'CONFIRMED' || status == 'DELIVERED' || status == 'PACKED' || status == 'PREPARING' || status == 'SHIPPED') {
            final recordId = record['id']?.toString();
            final readableId = record['readableId']?.toString();
            if (recordId != null) _dismissedOrAcknowledgedAlarmOrders.add(recordId);
            if (readableId != null) {
              _dismissedOrAcknowledgedAlarmOrders.add(readableId);
              final base = readableId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim();
              if (base.isNotEmpty) _dismissedOrAcknowledgedAlarmOrders.add(base);
            }
            // Stop active order alarm immediately across all admin devices
            _stopPendingAlarm();
          } else if (status == 'PENDING' || status == 'ADMIN_PENDING' || status == 'PLACED') {
            final recId = record['id']?.toString();
            final recRid = record['readableId']?.toString();
            final recBase = recRid != null ? recRid.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim() : '';
            final isAcked = (recId != null && _dismissedOrAcknowledgedAlarmOrders.contains(recId)) ||
                (recRid != null && _dismissedOrAcknowledgedAlarmOrders.contains(recRid)) ||
                (recBase.isNotEmpty && _dismissedOrAcknowledgedAlarmOrders.contains(recBase));
            if (!isAcked) {
              OrderAlarmService.instance.startOrderBuzzer(orderId: recId ?? recRid);
            }
          }
        }
      },
    );

    // 2. Realtime continuous auto-refresh timer every 12 seconds
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_isDeviceOffline && mounted) {
        _silentFetchAdminOrders();
      }
    });
  }

  void _initConnectivityAndOfflineQueue() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (mounted) {
        final wasOffline = _isDeviceOffline;
        setState(() => _isDeviceOffline = isOffline);
        if (wasOffline && !isOffline) {
          _flushOfflineAdminQueue();
          _silentFetchAdminOrders();
        }
      }
    });
  }

  Future<void> _flushOfflineAdminQueue() async {
    final dio = ref.read(dioProvider);
    final sb = SupabaseService.client;

    await OfflineSyncService.flushQueue(OfflineSyncService.queueAdmin, (item) async {
      final action = item['action']?.toString();
      final payload = Map<String, dynamic>.from(item['payload'] as Map);
      final id = payload['id']?.toString();
      if (id == null) return true;

      try {
        if (action == 'ASSIGN_RIDER') {
          final riderId = payload['riderId']?.toString();
          final targetStatus = payload['status']?.toString();
          final combinedId = payload['combinedId']?.toString();
          if (sb != null && riderId != null) {
            final updateData = <String, dynamic>{
              'deliveryUserId': riderId,
              'updatedAt': DateTime.now().toIso8601String(),
            };
            if (targetStatus != null && targetStatus.isNotEmpty) {
              updateData['status'] = targetStatus;
            }
            await sb.from('orders').update(updateData).eq('id', id);
            if (combinedId != null && combinedId.isNotEmpty) {
              await sb.from('orders').update(updateData).eq('combinedId', combinedId);
            }
          }
          await dio.patch('/api/orders/$id', data: {
            if (riderId != null) 'deliveryUserId': riderId,
            if (targetStatus != null && targetStatus.isNotEmpty) 'status': targetStatus,
          });
          return true;
        } else {
          final status = payload['status']?.toString();
          if (status == null) return true;

          if (sb != null) {
            await sb.from('orders').update({
              'status': status.toUpperCase(),
              'updatedAt': DateTime.now().toIso8601String(),
            }).eq('id', id);
          }

          final parsedStatus = OrderStatus.values.firstWhere(
            (s) => s.name.toUpperCase() == status.toUpperCase(),
            orElse: () => OrderStatus.pending,
          );
          await OrderRepository(dio).updateOrderStatus(id, parsedStatus);
          return true;
        }
      } catch (e) {
        LoggerService.error('[Admin Offline Sync Error]: $e');
        return false;
      }
    });
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _initNotificationSubscriptions() async {
    try {
      final notif = NotificationService();
      await notif.init();
      await notif.requestPermissions();
      final dio = ref.read(dioProvider);
      final prefs = await SharedPreferences.getInstance();
      final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
      await notif.registerDeviceToken(dio, role: 'ADMIN', assignedStoreId: storeId);
    } catch (e) {
      debugPrint('[Admin] Notification init error: $e');
    }
  }

  Future<void> _playChime() async {
    try {
      HapticFeedback.heavyImpact();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/order_chime.mp3'), volume: 1.0);
    } catch (_) {
      try { await SystemSound.play(SystemSoundType.alert); } catch (_) {}
    }
  }

  void _startPendingAlarm(Order order) {
    OrderAlarmService.instance.startAlarm(
      order: order,
      context: context,
      onAccept: () {
        _markAlarmAcknowledged(order);
        _stopPendingAlarm();
        _updateOrderStatus(order, OrderStatus.confirmed);
      },
      onDismiss: () {
        _markAlarmAcknowledged(order);
        _stopPendingAlarm();
      },
    );
  }

  void _markAlarmAcknowledged(Order order) {
    void addNormalized(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final clean = raw.replaceAll('#', '').trim();
      if (clean.isEmpty) return;
      _dismissedOrAcknowledgedAlarmOrders.add(clean);
      _dismissedOrAcknowledgedAlarmOrders.add('#$clean');
      final base = clean.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim();
      if (base.isNotEmpty) {
        _dismissedOrAcknowledgedAlarmOrders.add(base);
        _dismissedOrAcknowledgedAlarmOrders.add('#$base');
      }
    }

    addNormalized(order.id);
    addNormalized(order.readableId);
    addNormalized(order.combinedId);
    if (order.subOrders != null) {
      for (final s in order.subOrders!) {
        addNormalized(s.id);
        addNormalized(s.readableId);
        addNormalized(s.combinedId);
      }
    }
  }

  void _stopPendingAlarm() {
    OrderAlarmService.instance.stopAlarm(closeModal: false);
  }

  void _syncAlarmStateWithOrders(List<Order> orders) {
    // Alarm must ONLY ring for pending or adminPending orders that have not been acknowledged!
    // Confirmed orders NEVER trigger alarms!
    final pendingOrders = orders.where((o) {
      if (o.status != OrderStatus.pending && o.status != OrderStatus.adminPending) {
        return false;
      }
      final cleanOid = o.id.replaceAll('#', '').trim();
      final cleanRid = (o.readableId ?? '').replaceAll('#', '').trim();
      final cleanCid = (o.combinedId ?? '').replaceAll('#', '').trim();
      final cleanBase = cleanRid.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim();

      if (_dismissedOrAcknowledgedAlarmOrders.contains(cleanOid) ||
          _dismissedOrAcknowledgedAlarmOrders.contains('#$cleanOid') ||
          (cleanRid.isNotEmpty && (_dismissedOrAcknowledgedAlarmOrders.contains(cleanRid) || _dismissedOrAcknowledgedAlarmOrders.contains('#$cleanRid'))) ||
          (cleanCid.isNotEmpty && (_dismissedOrAcknowledgedAlarmOrders.contains(cleanCid) || _dismissedOrAcknowledgedAlarmOrders.contains('#$cleanCid'))) ||
          (cleanBase.isNotEmpty && (_dismissedOrAcknowledgedAlarmOrders.contains(cleanBase) || _dismissedOrAcknowledgedAlarmOrders.contains('#$cleanBase')))) {
        return false;
      }
      return true;
    }).toList();

    if (pendingOrders.isNotEmpty) {
      final latestPending = pendingOrders.first;
      if (!OrderAlarmService.instance.isPlaying) {
        _startPendingAlarm(latestPending);
      }
    } else {
      _stopPendingAlarm();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adminEventBusSub?.cancel();
    _stopPendingAlarm();
    _audioPlayer.dispose();
    _liveSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    SupabaseService.unsubscribe(_realtimeOrdersChannel);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (!_isDeviceOffline) {
        _silentFetchAdminOrders();
      }
    }
  }

  Future<void> _fetchAdminOrders() async {
    if (_isFetchingAdmin) return;
    _isFetchingAdmin = true;

    // Guarantee auth credentials are ready on first boot
    if (!SecureStorage.isCacheLoaded || SecureStorage.cachedUserId == null) {
      await SecureStorage.loadCache();
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final Map<String, Order> orderMap = {};

      void addOrUpdate(Order o) {
        final now = DateTime.now();
        _recentlyDeliveredOrderIds.removeWhere((_, time) => now.difference(time).inMinutes >= 3);
        if (_recentlyDeliveredOrderIds.containsKey(o.id) || (o.combinedId != null && _recentlyDeliveredOrderIds.containsKey(o.combinedId!))) {
          o = o.copyWith(status: OrderStatus.delivered, paymentStatus: 'PAID');
        }

        // Respect active optimistic status locks from user actions
        final lockedStatus = _getLockedStatus(o.id) ??
            (o.combinedId != null ? _getLockedStatus(o.combinedId!) : null) ??
            (o.readableId != null ? _getLockedStatus(o.readableId!) : null);
        if (lockedStatus != null) {
          o = o.copyWith(
            status: lockedStatus,
            paymentStatus: lockedStatus == OrderStatus.delivered ? 'PAID' : o.paymentStatus,
          );
        }

        // Respect active optimistic rider locks from admin actions
        final lockedRider = _getLockedRider(o.id) ??
            (o.combinedId != null ? _getLockedRider(o.combinedId!) : null) ??
            (o.readableId != null ? _getLockedRider(o.readableId!) : null);
        if (lockedRider != null) {
          if (lockedRider.isUnassigned) {
            o = o.copyWith(clearDeliveryUser: true);
          } else {
            o = o.copyWith(
              deliveryUserId: lockedRider.riderId,
              deliveryBoyName: lockedRider.riderName,
              deliveryBoyPhone: lockedRider.riderPhone,
            );
          }
        } else if ((o.deliveryBoyName == null || o.deliveryBoyName!.isEmpty) &&
                   o.deliveryUserId != null && o.deliveryUserId!.isNotEmpty) {
          // Resolve rider from _availableRiders list if Supabase returned deliveryUserId without joins
          final matchedRider = _availableRiders.firstWhereOrNull((r) => r['id'] == o.deliveryUserId);
          if (matchedRider != null) {
            o = o.copyWith(
              deliveryBoyName: matchedRider['name'],
              deliveryBoyPhone: matchedRider['phone'],
            );
          }
        }

        // If rider is still empty, check existing order in memory to preserve assigned rider
        final existing = orderMap[o.id] ?? _allOrders.firstWhereOrNull((curr) => curr.id == o.id);
        if ((o.deliveryBoyName == null || o.deliveryBoyName!.isEmpty) &&
            existing != null && existing.deliveryBoyName != null && existing.deliveryBoyName!.isNotEmpty) {
          if (lockedRider == null || !lockedRider.isUnassigned) {
            o = o.copyWith(
              deliveryUserId: existing.deliveryUserId,
              deliveryBoyName: existing.deliveryBoyName,
              deliveryBoyPhone: existing.deliveryBoyPhone,
            );
          }
        }

        if (orderMap[o.id] == null) {
          orderMap[o.id] = o;
        } else {
          final existingInMap = orderMap[o.id]!;
          // If admin explicitly locked/reversed status, allow it!
          final existingLocked = _getLockedStatus(existingInMap.id) ?? (existingInMap.combinedId != null ? _getLockedStatus(existingInMap.combinedId!) : null);
          if (existingLocked != null) {
            if (o.status == existingLocked) {
              orderMap[o.id] = o;
            }
            return;
          }

          // Never downgrade a DELIVERED or CANCELLED order without an explicit admin lock!
          if (existingInMap.status == OrderStatus.delivered && o.status != OrderStatus.delivered) {
            return;
          }
          if (existingInMap.status == OrderStatus.cancelled && o.status != OrderStatus.cancelled) {
            return;
          }

          final existingItemCount = existingInMap.items?.length ?? 0;
          final newItemCount = o.items?.length ?? 0;
          final isMoreItems = newItemCount > existingItemCount;
          final isNewerStatus = _orderStatusRank(o.status) > _orderStatusRank(existingInMap.status);
          final isSameStatusNewerData = o.status == existingInMap.status && (isMoreItems || o.createdAt.isAfter(existingInMap.createdAt));

          if (isNewerStatus || isSameStatusNewerData) {
            orderMap[o.id] = o;
          }
        }
      }

      // Run Supabase + REST API fetch in PARALLEL (not sequential waterfall)
      await Future.wait([
        // Source 1: Supabase direct query
        () async {
          final sb = SupabaseService.client;
          if (sb == null) return;
          try {
            final prefs = await SharedPreferences.getInstance();
            final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
            var query = sb
                .from('orders')
                .select('*, order_items(*)');
            if (storeId != null && storeId.isNotEmpty) {
              query = query.eq('storeId', storeId);
            }
            final res = await query
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addOrUpdate(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
            }
          } catch (e) {
            debugPrint('Supabase orders fetch error: $e');
          }
        }(),
        // Source 2: REST API
        () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
            final response = await dio.get(
              '/api/admin/orders',
              queryParameters: {
                'limit': 100,
                if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
              },
              options: await AdminAuthorization.optionsAsync(),
            );
            final data = response.data;
            List rawList = [];
            if (data is Map && data['orders'] is List) {
              rawList = data['orders'];
            } else if (data is List) {
              rawList = data;
            }
            for (final j in rawList) {
              if (j is Map<String, dynamic>) {
                try { addOrUpdate(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
              }
            }
          } catch (e) {
            debugPrint('REST orders fetch error: $e');
          }
        }(),
      ]);

      final loaded = orderMap.values.toList();
      if (loaded.isNotEmpty) {
        final mergedOrders = _mergeCombinedOrders(loaded);
        _cachedOrders = mergedOrders;
        _saveDiskOrders(mergedOrders);

        if (mounted) {
          // Hydrate KOT printed state from DB so button stays disabled across refreshes
          for (final o in mergedOrders) {
            if (o.kotPrinted) {
              _printedKOTOrders.add(o.id);
              if (o.readableId != null) _printedKOTOrders.add(o.readableId!);
            }
            // Also check sub-orders
            if (o.subOrders != null) {
              for (final sub in o.subOrders!) {
                if (sub.kotPrinted) {
                  _printedKOTOrders.add(sub.id);
                  if (sub.readableId != null) _printedKOTOrders.add(sub.readableId!);
                }
              }
            }
          }
          setState(() {
            _allOrders = mergedOrders;
            _isLoading = false;
          });
          _syncAlarmStateWithOrders(mergedOrders);
        }
      } else {
        // If loaded is empty (e.g. temporary API timeout/network hiccup), retain previous state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _isFetchingAdmin = false;
    }
  }

  /// Merge sub-orders that share a combinedId into one unified combined order card.
  List<Order> _mergeCombinedOrders(List<Order> orders) {
    final Map<String, List<Order>> groups = {};
    final List<Order> soloOrders = [];

    for (final o in orders) {
      String? cid = o.combinedId?.trim();
      if (cid == null || cid.isEmpty) {
        final rid = (o.readableId ?? '').toUpperCase().trim();
        final match = RegExp(r'^(\d+|[A-Z0-9]+)-[GR\d]+$').firstMatch(rid);
        if (match != null) {
          cid = 'readable_${match.group(1)}';
        }
      }
      if (cid != null && cid.isNotEmpty) {
        groups.putIfAbsent(cid, () => []).add(o);
      } else {
        soloOrders.add(o);
      }
    }

    final List<Order> result = [...soloOrders];

    for (final entry in groups.entries) {
      final subOrders = entry.value;
      if (subOrders.length == 1) {
        result.add(subOrders.first);
        continue;
      }

      // Prefer grocery -G as primary sub-order
      final primary = subOrders.firstWhere(
        (o) => (o.readableId ?? '').toUpperCase().endsWith('-G'),
        orElse: () => subOrders.first,
      );

      final allItems = <OrderItem>[];
      final seenItemKeys = <String>{};

      for (final sub in subOrders) {
        if (sub.items != null) {
          for (final item in sub.items!) {
            final key = item.id.isNotEmpty
                ? item.id
                : '${item.name.toLowerCase().trim()}_${item.selectedVariant?.toLowerCase().trim() ?? ""}_${item.notes?.toLowerCase().trim() ?? ""}';
            if (seenItemKeys.add(key)) {
              final isRest = item.isRestaurantItem || (sub.isRestaurantOrder && item.restaurantId != null);
              allItems.add(item.copyWith(
                restaurantId: isRest ? (item.restaurantId ?? sub.restaurantId) : null,
                shopName: isRest
                    ? (item.shopName ?? sub.shopName ?? 'Restaurant Kitchen')
                    : 'FastMinute Dark Store',
              ));
            }
          }
        }
      }

      final combinedTotal = subOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.total,
      );

      final combinedRefundAmount = subOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.refundAmount,
      );

      var resolvedSubOrders = subOrders;
      final isCombinedRecentlyDelivered = (entry.key.isNotEmpty && _recentlyDeliveredOrderIds.containsKey(entry.key)) ||
          subOrders.any((s) => _recentlyDeliveredOrderIds.containsKey(s.id));

      if (isCombinedRecentlyDelivered) {
        resolvedSubOrders = subOrders.map((s) => s.copyWith(status: OrderStatus.delivered, paymentStatus: 'PAID')).toList();
      }

      OrderStatus combinedStatus(List<OrderStatus> statuses) {
        if (isCombinedRecentlyDelivered) return OrderStatus.delivered;
        final lockedCombined = _getLockedStatus(entry.key);
        if (lockedCombined != null) return lockedCombined;

        final resolvedSubStatuses = resolvedSubOrders.map((s) {
          return _getLockedStatus(s.id) ?? (s.readableId != null ? _getLockedStatus(s.readableId!) : null) ?? s.status;
        }).toList();

        final active = resolvedSubStatuses.where((s) => s != OrderStatus.cancelled).toList();
        if (active.isEmpty) return OrderStatus.cancelled;
        if (active.contains(OrderStatus.adminPending)) return OrderStatus.adminPending;
        if (active.contains(OrderStatus.pending)) return OrderStatus.pending;
        if (active.contains(OrderStatus.confirmed)) return OrderStatus.confirmed;
        if (active.contains(OrderStatus.packed)) return OrderStatus.packed;
        if (active.contains(OrderStatus.shipped)) return OrderStatus.shipped;
        return OrderStatus.delivered;
      }

      final statuses = resolvedSubOrders.map((o) => o.status).toList();

      final baseReadableId = (primary.readableId ?? '')
          .replaceAll(RegExp(r'-[GR]\d*$', caseSensitive: false), '');

      final subLabels = resolvedSubOrders.map((o) {
        final isRest = o.isRestaurantOrder;
        final name = (o.shopName != null && o.shopName!.trim().isNotEmpty && o.shopName != 'FastMinute Dark Store' && o.shopName != 'FastMinute Store' && o.shopName != 'FastKirana Dark Store' && o.shopName != 'FastKirana Store')
            ? o.shopName!.trim()
            : (RestaurantRegistry.getName(o.restaurantId) ?? (isRest ? 'Restaurant' : 'Dark Store'));
        return isRest ? '🍽️ $name' : '🛒 $name';
      }).toList();

      final combinedDeliveryFee = resolvedSubOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.deliveryFee,
      );

      final combinedMiscFee = resolvedSubOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.miscFee,
      );

      final resolvedMergedStatus = combinedStatus(statuses);
      if (resolvedMergedStatus == OrderStatus.delivered) {
        resolvedSubOrders = resolvedSubOrders.map((s) => s.copyWith(status: OrderStatus.delivered, paymentStatus: 'PAID')).toList();
      }

      final merged = primary.copyWith(
        readableId: baseReadableId.isNotEmpty ? baseReadableId : primary.readableId,
        items: allItems,
        total: combinedTotal,
        refundAmount: combinedRefundAmount,
        deliveryFee: combinedDeliveryFee,
        miscFee: combinedMiscFee,
        status: resolvedMergedStatus,
        paymentStatus: resolvedMergedStatus == OrderStatus.delivered ? 'PAID' : primary.paymentStatus,
        shopName: subLabels.join(' + '),
        combinedId: entry.key,
        isCombined: true,
        subOrders: resolvedSubOrders,
        subLabels: subLabels,
      );

      result.add(merged);
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _silentFetchAdminOrders() async {
    if (_isFetchingAdmin) {
      _needsRefetch = true;
      return;
    }
    _isFetchingAdmin = true;
    _needsRefetch = false;

    if (!SecureStorage.isCacheLoaded || SecureStorage.cachedUserId == null) {
      await SecureStorage.loadCache();
    }

    try {
      final dio = ref.read(dioProvider);
      final Map<String, Order> orderMap = {};

      void addOrUpdate(Order o) {
        final now = DateTime.now();
        _recentlyDeliveredOrderIds.removeWhere((_, time) => now.difference(time).inMinutes >= 3);
        if (_recentlyDeliveredOrderIds.containsKey(o.id) || (o.combinedId != null && _recentlyDeliveredOrderIds.containsKey(o.combinedId!))) {
          o = o.copyWith(status: OrderStatus.delivered, paymentStatus: 'PAID');
        }

        // Respect active optimistic status locks from user actions
        final lockedStatus = _getLockedStatus(o.id) ??
            (o.combinedId != null ? _getLockedStatus(o.combinedId!) : null) ??
            (o.readableId != null ? _getLockedStatus(o.readableId!) : null);
        if (lockedStatus != null) {
          o = o.copyWith(
            status: lockedStatus,
            paymentStatus: lockedStatus == OrderStatus.delivered ? 'PAID' : o.paymentStatus,
          );
        }

        // Respect active optimistic rider locks from admin actions
        final lockedRider = _getLockedRider(o.id) ??
            (o.combinedId != null ? _getLockedRider(o.combinedId!) : null) ??
            (o.readableId != null ? _getLockedRider(o.readableId!) : null);
        if (lockedRider != null) {
          if (lockedRider.isUnassigned) {
            o = o.copyWith(clearDeliveryUser: true);
          } else {
            o = o.copyWith(
              deliveryUserId: lockedRider.riderId,
              deliveryBoyName: lockedRider.riderName,
              deliveryBoyPhone: lockedRider.riderPhone,
            );
          }
        } else if ((o.deliveryBoyName == null || o.deliveryBoyName!.isEmpty) &&
                   o.deliveryUserId != null && o.deliveryUserId!.isNotEmpty) {
          // Resolve rider from _availableRiders list if Supabase returned deliveryUserId without joins
          final matchedRider = _availableRiders.firstWhereOrNull((r) => r['id'] == o.deliveryUserId);
          if (matchedRider != null) {
            o = o.copyWith(
              deliveryBoyName: matchedRider['name'],
              deliveryBoyPhone: matchedRider['phone'],
            );
          }
        }

        // If rider is still empty, check existing order in memory to preserve assigned rider
        final existing = orderMap[o.id] ?? _allOrders.firstWhereOrNull((curr) => curr.id == o.id);
        if ((o.deliveryBoyName == null || o.deliveryBoyName!.isEmpty) &&
            existing != null && existing.deliveryBoyName != null && existing.deliveryBoyName!.isNotEmpty) {
          if (lockedRider == null || !lockedRider.isUnassigned) {
            o = o.copyWith(
              deliveryUserId: existing.deliveryUserId,
              deliveryBoyName: existing.deliveryBoyName,
              deliveryBoyPhone: existing.deliveryBoyPhone,
            );
          }
        }

        if (orderMap[o.id] == null) {
          orderMap[o.id] = o;
        } else {
          final existingInMap = orderMap[o.id]!;
          // If admin explicitly locked/reversed status, allow it!
          final existingLocked = _getLockedStatus(existingInMap.id) ?? (existingInMap.combinedId != null ? _getLockedStatus(existingInMap.combinedId!) : null);
          if (existingLocked != null) {
            if (o.status == existingLocked) {
              orderMap[o.id] = o;
            }
            return;
          }

          // Never downgrade a DELIVERED or CANCELLED order without an explicit admin lock!
          if (existingInMap.status == OrderStatus.delivered && o.status != OrderStatus.delivered) {
            return;
          }
          if (existingInMap.status == OrderStatus.cancelled && o.status != OrderStatus.cancelled) {
            return;
          }

          final existingItemCount = existingInMap.items?.length ?? 0;
          final newItemCount = o.items?.length ?? 0;
          final isMoreItems = newItemCount > existingItemCount;
          final isNewerStatus = _orderStatusRank(o.status) > _orderStatusRank(existingInMap.status);
          final isSameStatusNewerData = o.status == existingInMap.status && (isMoreItems || o.createdAt.isAfter(existingInMap.createdAt));

          if (isNewerStatus || isSameStatusNewerData) {
            orderMap[o.id] = o;
          }
        }
      }

      // Run Supabase + REST API in PARALLEL
      await Future.wait([
        // 1. Direct Supabase Query
        () async {
          final sb = SupabaseService.client;
          if (sb == null) return;
          try {
            final prefs = await SharedPreferences.getInstance();
            final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
            var query = sb
                .from('orders')
                .select('*, order_items(*)');
            if (storeId != null && storeId.isNotEmpty) {
              query = query.eq('storeId', storeId);
            }
            final res = await query
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addOrUpdate(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
        }(),
        // 2. REST API
        () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final storeId = _assignedStoreId ?? prefs.getString('assigned_store_id');
            final response = await dio.get(
              '/api/admin/orders',
              queryParameters: {
                'limit': 100,
                if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
              },
              options: await AdminAuthorization.optionsAsync(),
            );
            final data = response.data;
            List rawList = [];
            if (data is Map && data['orders'] is List) {
              rawList = data['orders'];
            } else if (data is List) {
              rawList = data;
            }
            for (final j in rawList) {
              if (j is Map<String, dynamic>) {
                try { addOrUpdate(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
              }
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
        }(),
      ]);

      final loaded = orderMap.values.toList();
      if (loaded.isNotEmpty) {
        final mergedOrders = _mergeCombinedOrders(loaded);
        _cachedOrders = mergedOrders;
        _saveDiskOrders(mergedOrders);
        if (mounted) {
          // Hydrate KOT printed state from DB
          for (final o in mergedOrders) {
            if (o.kotPrinted) {
              _printedKOTOrders.add(o.id);
              if (o.readableId != null) _printedKOTOrders.add(o.readableId!);
            }
            if (o.subOrders != null) {
              for (final sub in o.subOrders!) {
                if (sub.kotPrinted) {
                  _printedKOTOrders.add(sub.id);
                  if (sub.readableId != null) _printedKOTOrders.add(sub.readableId!);
                }
              }
            }
          }
          setState(() {
            _allOrders = mergedOrders;
          });
          _syncAlarmStateWithOrders(mergedOrders);
        }
      }
    } catch (e, _) {
      LoggerService.error('AdminOrdersList: order parse', e);
    } finally {
      _isFetchingAdmin = false;
      if (_needsRefetch && mounted) {
        _needsRefetch = false;
        unawaited(_silentFetchAdminOrders());
      }
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    HapticFeedback.heavyImpact();
    try {
      final statusUpper = newStatus == OrderStatus.adminPending ? 'ADMIN_PENDING' : newStatus.name.toUpperCase();

      // If status is CANCELLED and was not previously cancelled, restore product stock
      if (newStatus == OrderStatus.cancelled && order.status != OrderStatus.cancelled) {
        final sb = SupabaseService.client;
        if (sb != null) {
          try {
            final items = order.items ?? [];
            for (final item in items) {
              final pId = item.productId;
              if (pId != null && pId.isNotEmpty) {
                final prodRes = await sb
                    .from('products')
                    .select('id, stock, variants')
                    .eq('id', pId)
                    .maybeSingle();

                if (prodRes != null) {
                  if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
                    final rawVars = prodRes['variants'];
                    if (rawVars is List) {
                      final updatedVariants = rawVars.map((v) {
                        if (v is Map && v['name'] == item.selectedVariant) {
                          final curStock = (v['stock'] as num?)?.toInt() ?? 0;
                          return Map<String, dynamic>.from(v)..['stock'] = curStock + item.quantity;
                        }
                        return v;
                      }).toList();
                      final newTotalStock = updatedVariants.fold<int>(
                        0,
                        (sum, v) => sum + ((v is Map ? v['stock'] as num? : 0)?.toInt() ?? 0),
                      );
                      await sb.from('products').update({
                        'variants': updatedVariants,
                        'stock': newTotalStock,
                      }).eq('id', pId);
                    }
                  } else {
                    final curStock = (prodRes['stock'] as num?)?.toInt() ?? 0;
                    final newStock = curStock + item.quantity;
                    await sb.from('products').update({
                      'stock': newStock,
                    }).eq('id', pId);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[Admin Cancel Stock Restore Error]: $e');
          }
        }
      }

      // 1. Instant Optimistic UI Update (0ms)
      final Set<String> idSet = {order.id};
      if (order.readableId != null && order.readableId!.isNotEmpty) {
        idSet.add(order.readableId!);
      }
      if (order.subOrders != null && order.subOrders!.isNotEmpty) {
        for (final s in order.subOrders!) {
          idSet.add(s.id);
          if (s.readableId != null && s.readableId!.isNotEmpty) {
            idSet.add(s.readableId!);
          }
        }
      }
      final baseReadable = (order.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '').trim();
      for (final o in _allOrders) {
        if (order.combinedId != null && order.combinedId!.isNotEmpty && o.combinedId == order.combinedId) {
          idSet.add(o.id);
          if (o.readableId != null && o.readableId!.isNotEmpty) idSet.add(o.readableId!);
        }
        if (baseReadable.isNotEmpty && (o.readableId ?? '').startsWith(baseReadable)) {
          idSet.add(o.id);
          if (o.readableId != null && o.readableId!.isNotEmpty) idSet.add(o.readableId!);
        }
      }
      final List<String> idsToUpdate = idSet.toList();

      for (final id in idsToUpdate) {
        _lockOrderStatus(id, newStatus, durationSeconds: 8);
      }
      if (order.combinedId != null && order.combinedId!.isNotEmpty) {
        _lockOrderStatus(order.combinedId!, newStatus, durationSeconds: 8);
      }

      if (newStatus == OrderStatus.delivered) {
        final now = DateTime.now();
        _recentlyDeliveredOrderIds[order.id] = now;
        for (final id in idsToUpdate) {
          _recentlyDeliveredOrderIds[id] = now;
        }
        if (order.combinedId != null && order.combinedId!.isNotEmpty) {
          _recentlyDeliveredOrderIds[order.combinedId!] = now;
        }
      }

      setState(() {
        _inProgressOrderIds.add(order.id);
        _allOrders = _allOrders.map((o) {
          final isSameOrder = o.id == order.id || idsToUpdate.contains(o.id);
          final isSameCombined = order.combinedId != null && order.combinedId!.isNotEmpty && o.combinedId == order.combinedId;
          final isSameBase = baseReadable.isNotEmpty && (o.readableId ?? '').startsWith(baseReadable);

          if (isSameOrder || isSameCombined || isSameBase) {
            final updatedSubs = o.subOrders?.map((s) {
              if (idsToUpdate.contains(s.id) || s.id == order.id || idsToUpdate.contains(s.readableId)) {
                return s.copyWith(
                  status: newStatus,
                  paymentStatus: newStatus == OrderStatus.delivered ? 'PAID' : s.paymentStatus,
                );
              }
              return s;
            }).toList();

            return o.copyWith(
              status: newStatus,
              paymentStatus: newStatus == OrderStatus.delivered ? 'PAID' : o.paymentStatus,
              subOrders: updatedSubs,
            );
          }
          return o;
        }).toList();
      });

      if (newStatus != OrderStatus.adminPending && newStatus != OrderStatus.pending) {
        _markAlarmAcknowledged(order);
        for (final id in idsToUpdate) {
          _dismissedOrAcknowledgedAlarmOrders.add(id);
        }
        _stopPendingAlarm();
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          'Order #${order.readableId ?? order.id} Updated!',
          subtitle: 'Status changed to ${newStatus.displayName}',
        );
      }

      // 2. Concurrent Background Network Sync (Supabase + REST API)
      if (_isDeviceOffline) {
        for (final id in idsToUpdate) {
          await OfflineSyncService.enqueueAction(
            queueName: OfflineSyncService.queueAdmin,
            action: 'UPDATE_STATUS',
            payload: {'id': id, 'status': statusUpper},
          );
        }
      } else {
        final futures = <Future>[];
        final sb = SupabaseService.client;
        if (sb != null) {
          for (final id in idsToUpdate) {
            futures.add(sb.from('orders').update({
              'status': statusUpper,
              'updatedAt': DateTime.now().toIso8601String(),
            }).eq('id', id).catchError((_) {}));
          }
          if (order.combinedId != null && order.combinedId!.trim().isNotEmpty) {
            futures.add(sb.from('orders').update({
              'status': statusUpper,
              'updatedAt': DateTime.now().toIso8601String(),
            }).eq('combinedId', order.combinedId!.trim()).catchError((_) {}));
          }
          if (baseReadable.isNotEmpty) {
            futures.add(sb.from('orders').update({
              'status': statusUpper,
              'updatedAt': DateTime.now().toIso8601String(),
            }).ilike('readableId', '$baseReadable%').catchError((_) {}));
          }
        }

        // Direct sub-30ms Realtime broadcast to fellow admin and tracking screens
        if (sb != null) {
          try {
            final adminChan = sb.channel('admin-global-orders-websocket');
            final broadcastPayload = {
              'id': order.id,
              'orderId': order.id,
              'readableId': order.readableId ?? order.id,
              'status': statusUpper,
              'paymentStatus': newStatus == OrderStatus.delivered ? 'PAID' : (order.paymentStatus.toUpperCase() == 'PAID' ? 'PAID' : 'PENDING'),
              'timestamp': DateTime.now().toIso8601String(),
            };
            adminChan.sendBroadcastMessage(
              event: 'status_update',
              payload: broadcastPayload,
            );
            final custChan = sb.channel('order-live-tracking-${order.id}');
            custChan.sendBroadcastMessage(
              event: 'status_update',
              payload: broadcastPayload,
            );
            if (order.readableId != null && order.readableId!.isNotEmpty) {
              final custChanRid = sb.channel('order-live-tracking-${order.readableId}');
              custChanRid.sendBroadcastMessage(
                event: 'status_update',
                payload: broadcastPayload,
              );
            }

            // Trigger instant buzzer for the respected restaurant when verified/confirmed!
            String? targetRestId = order.restaurantId;
            if (targetRestId == null || targetRestId.isEmpty) {
              if (order.subOrders != null && order.subOrders!.isNotEmpty) {
                for (final sub in order.subOrders!) {
                  if (sub.restaurantId != null && sub.restaurantId!.isNotEmpty) {
                    targetRestId = sub.restaurantId;
                    break;
                  }
                }
              }
            }

            if (targetRestId != null && targetRestId.isNotEmpty &&
                (newStatus == OrderStatus.confirmed || newStatus == OrderStatus.pending)) {
              final restPayload = {
                'orderId': order.id,
                'readableId': order.readableId ?? order.id,
                'restaurantId': targetRestId,
                'restaurantName': order.shopName ?? 'Restaurant',
                'status': statusUpper,
                'timestamp': DateTime.now().toIso8601String(),
              };
              sb.channel('restaurant-orders-live-$targetRestId').sendBroadcastMessage(
                event: 'new_order',
                payload: restPayload,
              );
              sb.channel('restaurant-orders-live').sendBroadcastMessage(
                event: 'new_order',
                payload: restPayload,
              );
            }
          } catch (_) {}
        }

        final isApproval = order.status == OrderStatus.adminPending &&
            (newStatus == OrderStatus.confirmed || newStatus == OrderStatus.pending);
        for (final id in idsToUpdate) {
          futures.add(OrderRepository(ref.read(dioProvider)).updateOrderStatus(
            id,
            newStatus,
            isApproval: isApproval,
            previousStatus: order.status == OrderStatus.adminPending ? 'ADMIN_PENDING' : null,
          ).catchError((_) => false));
        }

        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('[Admin status update error]: $e');
    } finally {
      if (mounted) setState(() => _inProgressOrderIds.remove(order.id));
    }
  }

  Future<void> _updateSubOrderStatus(Order parentOrder, Order subOrder, OrderStatus newStatus) async {
    HapticFeedback.heavyImpact();
    try {
      final statusUpper = newStatus == OrderStatus.adminPending ? 'ADMIN_PENDING' : newStatus.name.toUpperCase();
      _lockOrderStatus(subOrder.id, newStatus, durationSeconds: 8);
      if (subOrder.readableId != null && subOrder.readableId!.isNotEmpty) {
        _lockOrderStatus(subOrder.readableId!, newStatus, durationSeconds: 8);
      }

      // 1. Instant Optimistic UI Update (0ms)
      setState(() {
        _allOrders = _allOrders.map((o) {
          if (o.id == subOrder.id) {
            return o.copyWith(status: newStatus);
          }
          if (o.id == parentOrder.id && o.subOrders != null) {
            final updatedSubs = o.subOrders!.map((s) => s.id == subOrder.id ? s.copyWith(status: newStatus) : s).toList();
            return o.copyWith(subOrders: updatedSubs);
          }
          return o;
        }).toList();
      });

      if (newStatus != OrderStatus.adminPending && newStatus != OrderStatus.pending) {
        _markAlarmAcknowledged(subOrder);
        _dismissedOrAcknowledgedAlarmOrders.add(subOrder.id);
        if (subOrder.readableId != null) {
          _dismissedOrAcknowledgedAlarmOrders.add(subOrder.readableId!);
        }
        _stopPendingAlarm();
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          '${subOrder.shopName ?? "Outlet"} #${subOrder.readableId ?? subOrder.id} Updated!',
          subtitle: 'Status set to ${newStatus.displayName}',
        );
      }

      // 2. Concurrent Background Sync
      if (_isDeviceOffline) {
        await OfflineSyncService.enqueueAction(
          queueName: OfflineSyncService.queueAdmin,
          action: 'UPDATE_STATUS',
          payload: {'id': subOrder.id, 'status': statusUpper},
        );
      } else {
        final futures = <Future>[];
        final sb = SupabaseService.client;
        if (sb != null) {
          futures.add(sb.from('orders').update({
            'status': statusUpper,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', subOrder.id).catchError((_) {}));

          if (subOrder.restaurantId != null && subOrder.restaurantId!.isNotEmpty &&
              (newStatus == OrderStatus.confirmed || newStatus == OrderStatus.pending)) {
            final restPayload = {
              'orderId': subOrder.id,
              'readableId': subOrder.readableId ?? subOrder.id,
              'restaurantId': subOrder.restaurantId,
              'restaurantName': subOrder.shopName ?? 'Restaurant',
              'status': statusUpper,
              'timestamp': DateTime.now().toIso8601String(),
            };
            try {
              sb.channel('restaurant-orders-live-${subOrder.restaurantId}').sendBroadcastMessage(
                event: 'new_order',
                payload: restPayload,
              );
              sb.channel('restaurant-orders-live').sendBroadcastMessage(
                event: 'new_order',
                payload: restPayload,
              );
            } catch (_) {}
          }
        }

        final isApproval = subOrder.status == OrderStatus.adminPending &&
            (newStatus == OrderStatus.confirmed || newStatus == OrderStatus.pending);
        futures.add(OrderRepository(ref.read(dioProvider)).updateOrderStatus(
          subOrder.id,
          newStatus,
          isApproval: isApproval,
          previousStatus: subOrder.status == OrderStatus.adminPending ? 'ADMIN_PENDING' : null,
        ).catchError((_) => false));
        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('[SubOrder status update error]: $e');
    }
  }

  Future<void> _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        AppToast.showWarning(context, 'No valid phone number found for this customer');
      }
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch phone dialer: $e');
      if (mounted) {
        AppToast.showError(context, 'Could not open dialer for $cleanPhone');
      }
    }
  }

  Future<void> _whatsappCustomer(String phone, String orderId) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=Hi%20from%20FastMinute%20re:%20Order%20%23$orderId');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  Future<void> _assignRider(Order order, String riderId, String riderName, String riderPhone) async {
    HapticFeedback.heavyImpact();
    final bool isUnassigning = riderId.isEmpty || riderId == 'UNASSIGNED';
    final Set<String> targetIds = {
      order.id,
      if (order.subOrders != null) ...order.subOrders!.map((s) => s.id),
    };

    final allTargetIds = <String>{
      order.id,
      if (order.readableId != null && order.readableId!.isNotEmpty) order.readableId!,
      if (order.combinedId != null && order.combinedId!.isNotEmpty) order.combinedId!,
      ...targetIds,
      if (order.subOrders != null) ...order.subOrders!.map((s) => s.id),
      if (order.subOrders != null) ...order.subOrders!.where((s) => s.readableId != null).map((s) => s.readableId!),
    };

    // 0. Active 12-second Optimistic Rider Lock across all linked IDs
    _lockRiderAssignment(
      orderIds: allTargetIds.toList(),
      riderId: isUnassigning ? null : riderId,
      riderName: isUnassigning ? null : riderName,
      riderPhone: isUnassigning ? null : riderPhone,
      isUnassigned: isUnassigning,
      durationSeconds: 12,
    );

    // Status preservation:
    // When assigning a rider, preserve the order's existing status (CONFIRMED, PENDING, PACKED, SHIPPED).
    final targetStatus = order.status;
    final targetStatusStr = order.status.name.toUpperCase();

    // 1. Instant Optimistic UI Update (0ms)
    setState(() {
      _allOrders = _allOrders.map((o) {
        if (allTargetIds.contains(o.id) ||
            (o.readableId != null && allTargetIds.contains(o.readableId!)) ||
            (order.combinedId != null && o.combinedId == order.combinedId)) {
          final updatedSubs = o.subOrders?.map((s) => s.copyWith(
            status: targetStatus,
            deliveryUserId: isUnassigning ? null : riderId,
            deliveryBoyName: isUnassigning ? '' : riderName,
            deliveryBoyPhone: isUnassigning ? '' : riderPhone,
            clearDeliveryUser: isUnassigning,
          )).toList();
          return o.copyWith(
            status: targetStatus,
            deliveryUserId: isUnassigning ? null : riderId,
            deliveryBoyName: isUnassigning ? '' : riderName,
            deliveryBoyPhone: isUnassigning ? '' : riderPhone,
            clearDeliveryUser: isUnassigning,
            subOrders: updatedSubs,
          );
        }
        return o;
      }).toList();
    });

    if (mounted) {
      final statusLabel = isUnassigning
          ? 'Order unassigned'
          : 'Assigned to $riderName';
      if (isUnassigning) {
        AppToast.showInfo(context, statusLabel);
      } else {
        AppToast.showSuccess(context, 'Rider Assigned 🛵', subtitle: statusLabel);
      }
    }

    // 2. Concurrent Network Sync
    if (_isDeviceOffline) {
      for (final id in targetIds) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        await OfflineSyncService.enqueueAction(
          queueName: OfflineSyncService.queueAdmin,
          action: 'ASSIGN_RIDER',
          payload: {
            'id': cleanId,
            'riderId': isUnassigning ? '' : riderId,
            'status': targetStatusStr,
            if (order.combinedId != null && order.combinedId!.trim().isNotEmpty)
              'combinedId': order.combinedId!.trim(),
          },
        );
      }
    } else {
      final futures = <Future>[];
      final sb = SupabaseService.client;
      if (sb != null) {
        for (final id in targetIds) {
          var cleanId = id.trim();
          if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
          futures.add(sb.from('orders').update({
            'deliveryUserId': isUnassigning ? null : riderId,
            'status': targetStatusStr,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', cleanId).catchError((_) {}));
        }

        if (order.combinedId != null && order.combinedId!.trim().isNotEmpty) {
          futures.add(sb.from('orders').update({
            'deliveryUserId': isUnassigning ? null : riderId,
            'status': targetStatusStr,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('combinedId', order.combinedId!.trim()).catchError((_) {}));
        }

        // 🌟 Direct Realtime Broadcast to customer tracking channels
        for (final tId in allTargetIds) {
          var cleanTId = tId.trim();
          if (cleanTId.startsWith('#')) cleanTId = cleanTId.substring(1);
          try {
            final ch = sb.channel('order-live-tracking-$cleanTId');
            ch.sendBroadcastMessage(
              event: 'rider_assigned',
              payload: {
                'orderId': cleanTId,
                'riderId': isUnassigning ? null : riderId,
                'riderName': isUnassigning ? null : riderName,
                'riderPhone': isUnassigning ? null : riderPhone,
                'status': targetStatusStr,
              },
            );
          } catch (_) {}
        }
      }

      final authOptions = await AdminAuthorization.optionsAsync();
      for (final id in targetIds) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        futures.add(ref.read(dioProvider).patch(
          '/api/orders/$cleanId',
          data: {
            'deliveryUserId': isUnassigning ? '' : riderId,
            'status': targetStatusStr,
          },
          options: authOptions,
        ).catchError((_) => Response(requestOptions: RequestOptions())));
      }

      await Future.wait(futures);
    }
  }

  Future<void> _updateOrderRoute(Order order, DeliveryRouteKey newRoute) async {
    HapticFeedback.mediumImpact();
    final rInfo = DeliveryRoutes.getByKey(newRoute);
    final updatedNotes = DeliveryRoutes.setRouteInNotes(order.notes, newRoute);

    // 1. Optimistic local UI update (including subOrders)
    setState(() {
      _allOrders = _allOrders.map((o) {
        if (o.id == order.id || (order.combinedId != null && o.combinedId == order.combinedId)) {
          final updatedSubs = o.subOrders?.map((s) => s.copyWith(notes: updatedNotes)).toList();
          return o.copyWith(notes: updatedNotes, subOrders: updatedSubs);
        }
        return o;
      }).toList();
    });

    if (mounted) {
      AppToast.showSuccess(
        context,
        'Delivery Route Updated',
        subtitle: '${rInfo.emoji} ${rInfo.label}',
      );
    }

    // 2. Sync to Supabase & API
    try {
      final authOptions = await AdminAuthorization.optionsAsync();
      final idsToUpdate = <String>{order.id};
      if (order.subOrders != null) {
        for (final s in order.subOrders!) {
          idsToUpdate.add(s.id);
        }
      }

      final futures = <Future>[];
      final sb = SupabaseService.client;
      if (sb != null) {
        for (final id in idsToUpdate) {
          var cleanId = id.trim();
          if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
          futures.add(sb.from('orders').update({
            'notes': updatedNotes,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', cleanId).catchError((_) {}));
        }

        if (order.combinedId != null && order.combinedId!.isNotEmpty) {
          futures.add(sb.from('orders').update({
            'notes': updatedNotes,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('combinedId', order.combinedId!).catchError((_) {}));
        }
      }

      for (final id in idsToUpdate) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        futures.add(ref.read(dioProvider).patch(
          '/api/orders/$cleanId',
          data: {
            'deliveryRoute': newRoute.name.toUpperCase(),
            'notes': updatedNotes,
          },
          options: authOptions,
        ).catchError((_) => Response(requestOptions: RequestOptions())));
      }

      await Future.wait(futures);
    } catch (_) {}
  }

  bool _isUnpaidOnline(Order order) {
    return AdminOrderCard.isUnpaidOnline(order);
  }

  Future<void> _verifyOnlinePayment(Order order) async {
    HapticFeedback.heavyImpact();
    AppToast.showInfo(
      context,
      'Verifying Online Payment...',
      subtitle: 'Checking Cashfree payment status for #${order.readableId ?? order.id}',
    );

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/api/payment/cashfree/verify',
        data: {'orderId': order.id},
      );

      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          AppToast.showSuccess(
            context,
            'Payment Verified & Synced! ✅',
            subtitle: 'Order marked as PAID and Confirmed.',
          );
          _fetchAdminOrders();
        } else {
          final msg = res.data?['message']?.toString() ?? res.data?['error']?.toString() ?? 'No completed payment found on Cashfree.';
          AppToast.showError(
            context,
            'Verification Notice',
            subtitle: msg,
          );
        }
      }
    } catch (e) {
      String errStr = 'No completed payment found for this order on Cashfree.';
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && (d['message'] != null || d['error'] != null)) {
          errStr = (d['message'] ?? d['error']).toString();
        }
      }
      if (mounted) {
        AppToast.showError(
          context,
          'Verification Incomplete',
          subtitle: errStr,
        );
      }
    }
  }

  Future<void> _convertToCOD(Order order) async {
    HapticFeedback.lightImpact();
    final total = order.total.toInt();
    final displayId = order.readableId ?? order.id;

    final shouldConvert = await AppConfirmationDialog.showCODConversion(
      context: context,
      displayId: displayId,
      totalAmount: total,
    );

    if (shouldConvert != true) return;

    HapticFeedback.heavyImpact();

    final targetIds = (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty)
        ? order.subOrders!.map((s) => s.id).toList()
        : [order.id];

    // Instant optimistic update
    setState(() {
      _allOrders = _allOrders.map((o) {
        if (o.id == order.id || targetIds.contains(o.id) || (order.combinedId != null && o.combinedId == order.combinedId)) {
          return o.copyWith(
            paymentMethod: PaymentMethod.cod,
            paymentStatus: 'PENDING',
            status: OrderStatus.confirmed,
          );
        }
        return o;
      }).toList();
    });

    if (mounted) {
      AppToast.showSuccess(
        context,
        'Converted to COD & Confirmed! 💵',
        subtitle: 'Order #$displayId moved to Confirmed queue.',
      );
    }

    try {
      final dio = ref.read(dioProvider);
      final opt = await AdminAuthorization.optionsAsync();
      await Future.wait(targetIds.map((tid) => dio.patch(
        '/api/orders/$tid',
        data: {
          'paymentMethod': 'COD',
          'paymentStatus': 'PENDING',
          'status': 'CONFIRMED',
        },
        options: opt,
      )));
      _fetchAdminOrders();
    } catch (e) {
      debugPrint('[Admin Convert to COD error]: $e');
    }
  }

  Future<void> _sendWhatsAppPaymentReminder(Order order) async {
    HapticFeedback.lightImpact();
    final custPhone = (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty)
        ? order.customerPhone!.trim()
        : (order.addressRaw?['phone']?.toString().isNotEmpty == true
            ? order.addressRaw!['phone'].toString().trim()
            : '');
    final cleanPhone = custPhone.replaceAll(RegExp(r'[^\d]'), '').replaceFirst(RegExp(r'^91'), '');

    if (cleanPhone.length < 10) {
      AppToast.showError(
        context,
        'Customer Phone Missing',
        subtitle: 'Cannot send WhatsApp reminder without a valid mobile number.',
      );
      return;
    }

    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'Customer';
    final displayId = order.readableId ?? order.id;
    final total = order.total.toInt();
    final trackUrl = 'https://fast-kirana-gtm.vercel.app/order/${order.id}/track';

    final message = 'Namaste $custName ji, aapka FastMinute order #$displayId (₹$total) payment ke liye pending hai.\n\nAap is link se online pay kar sakte hain ya status track kar sakte hain:\n$trackUrl\n\nFastMinute Ghatampur se judne ke liye dhanyawad!';

    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSubstitutionModal(Order order, OrderItem item) {
    AdminSubstitutionSheet.show(context, order, item);
  }

  void _openSuperOrderEditModal(Order order) {
    HapticFeedback.selectionClick();
    final isRest = order.isRestaurantOrder;
    String? effectiveRestId = order.restaurantId;
    if (effectiveRestId == null || effectiveRestId.isEmpty || effectiveRestId == 'null') {
      if (order.shopName != null && order.shopName!.isNotEmpty) {
        effectiveRestId = RestaurantRegistry.find(order.shopName)?.id;
      }
      if (effectiveRestId == null && order.isCombined && order.subOrders != null) {
        final restSub = order.subOrders!.firstWhereOrNull((s) => s.isRestaurantOrder);
        effectiveRestId = restSub?.restaurantId;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderEditModal(
        order: {
          'id': order.id,
          'readableId': order.readableId ?? order.id,
          'items': (order.items ?? []).map((it) => {
            'id': it.id,
            'productId': it.productId,
            'name': it.name,
            'price': it.price,
            'quantity': it.quantity,
            'imageUrl': it.imageUrl,
            'selectedVariant': it.selectedVariant,
            'notes': it.notes,
            'restaurantId': it.restaurantId ?? (it.isRestaurantItem ? effectiveRestId : order.restaurantId),
            'shopName': it.shopName ?? (it.isRestaurantItem ? (order.shopName ?? RestaurantRegistry.getName(effectiveRestId) ?? 'Restaurant') : 'FastMinute Grocery'),
          }).toList(),
          'restaurantId': effectiveRestId,
          'shopName': order.shopName ?? RestaurantRegistry.getName(effectiveRestId),
          'user': {
            'phone': order.customerPhone,
            'name': order.customerName,
          },
        },
        isRestaurant: isRest,
        isAdmin: true,
        restaurantId: effectiveRestId,
        onOrderUpdated: () {
          _fetchAdminOrders();
        },
      ),
    );
  }

  void _showRecordRefundModal(Order order) {
    HapticFeedback.selectionClick();
    AdminRefundSheet.show(
      context: context,
      order: order,
      ref: ref,
      onRefundSuccess: _fetchAdminOrders,
    );
  }

  String _formatOrderDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  bool _isDeliveryOnlyInstruction(String? note) {
    if (note == null || note.trim().isEmpty) return true;
    final lower = note.toLowerCase().trim();
    final deliveryKeywords = [
      'ring bell', 'don\'t ring', 'dont ring', 'leave at door', 'leave at gate',
      'call before', 'avoid calling', 'drop at door', 'keep at door', 'deliver to',
      'call when reach', 'call upon arrival', 'gate pe', 'bell bajana', 'doorbell'
    ];
    return deliveryKeywords.any((k) => lower.contains(k));
  }

  String _generateKOTText(Order order) {
    final itemsList = (order.items ?? []).where((i) {
      final name = i.name.toLowerCase();
      const groceryKeywords = [
        'atta', 'rice', 'dal', 'oil', 'ghee', 'flour', 'sugar', 'salt', 'spice', 'masala',
        'soap', 'shampoo', 'paste', 'brush', 'detergent', 'surf', 'cleaning', 'biscuit',
        'namkeen', 'chips', 'munchies', 'red bull', 'dairy', 'milk', 'bread', 'butter',
        'personal care', 'household'
      ];
      // If it's pure grocery, exclude from kitchen ticket
      return !groceryKeywords.any((k) => name == k || name.startsWith('$k '));
    }).toList();

    final formattedItems = itemsList.isNotEmpty
        ? itemsList.map((i) {
            final variant = (i.selectedVariant != null && i.selectedVariant!.isNotEmpty)
                ? ' (${i.selectedVariant})'
                : '';
            final dishNote = (!_isDeliveryOnlyInstruction(order.notes))
                ? '\n      * Note: ${order.notes!.trim()}'
                : '';
            final qtyStr = '${i.quantity}'.padRight(2);
            return '$qtyStr x  ${i.name}$variant$dishNote';
          }).join('\n')
        : '1  x  Food Items';

    final orderId = order.readableId ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id);

    final custName = order.customerName != null && order.customerName!.trim().isNotEmpty
        ? ' | ${order.customerName!.trim()}'
        : '';
    final printTimeStr = '${_formatOrderDate(DateTime.now())}  ${_formatOrderTime(DateTime.now())}';
    final typeStr = order.deliveryMethod ?? 'DELIVERY';

    return '''======================================
            FASTMINUTE KOT
======================================
TOKEN : #$orderId$custName
TYPE  : $typeStr
Print :  $printTimeStr
--------------------------------------
QTY   ITEM
--------------------------------------
$formattedItems
--------------------------------------
      *** FASTMINUTE KITCHEN ***
======================================''';
  }

  Future<void> _sendRemoteKOT(Order order) async {
    // 1. Guard: Check if it's purely a grocery order
    final readable = (order.readableId ?? '').toUpperCase();
    if (readable.endsWith('-G')) {
      if (mounted) {
        AppToast.showInfo(
          context,
          'Grocery Order — No Kitchen KOT Needed 🛒',
          subtitle: 'KOT is only for Restaurant / Fresh Kitchen orders.',
        );
      }
      return;
    }

    // 2. Combined Order: Target ONLY the Restaurant Sub-Order (Never send grocery -G)
    Order targetOrder = order;
    if (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty) {
      final restSub = order.subOrders!.firstWhereOrNull((s) => s.isRestaurantOrder);

      if (restSub != null) {
        targetOrder = restSub;
      } else {
        // No restaurant sub-order found in combined order
        if (mounted) {
          AppToast.showInfo(
            context,
            'No Kitchen Items in Order 🛒',
            subtitle: 'This order only contains Darkstore Grocery items.',
          );
        }
        return;
      }
    }

    // Prevent multi-click while print request is in-flight
    if (_sendingKOTOrderIds.contains(order.id) || _sendingKOTOrderIds.contains(targetOrder.id)) {
      return;
    }

    setState(() {
      _sendingKOTOrderIds.add(order.id);
      _sendingKOTOrderIds.add(targetOrder.id);
    });

    HapticFeedback.heavyImpact();

    var cleanId = targetOrder.id.trim();
    if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

    // Dual-Path Remote Broadcast to Web Kitchen Console
    final kitchenNotes = !_isDeliveryOnlyInstruction(targetOrder.notes) ? targetOrder.notes : null;
    final itemsList = (targetOrder.items ?? []).map((i) => {
      'name': i.name,
      'quantity': i.quantity,
      'selectedVariant': i.selectedVariant,
      'notes': kitchenNotes,
    }).toList();

    try {
      await KotPrintService.sendRemoteKOTToKitchen(
        orderId: targetOrder.id,
        readableId: targetOrder.readableId ?? targetOrder.id,
        restaurantId: targetOrder.restaurantId,
        shopName: targetOrder.shopName ?? 'Kitchen',
        customerName: targetOrder.customerName ?? order.customerName ?? 'Customer',
        items: itemsList,
        deliveryMethod: targetOrder.deliveryMethod?.toString() ?? order.deliveryMethod?.toString() ?? 'DELIVERY',
        notes: kitchenNotes,
        kotText: _generateKOTText(targetOrder),
        dioClient: ref.read(dioProvider),
      );

      if (mounted) {
        setState(() {
          _printedKOTOrders.add(order.id);
          if (order.readableId != null) _printedKOTOrders.add(order.readableId!);
          _printedKOTOrders.add(targetOrder.id);
          if (targetOrder.readableId != null) _printedKOTOrders.add(targetOrder.readableId!);
        });

        AppToast.showSuccess(
          context,
          'KOT Sent to Kitchen! 👨‍🍳',
          subtitle: 'Order #${targetOrder.readableId ?? targetOrder.id} sent to kitchen printer',
        );
      }
    } finally {
      // Cooldown of 4 seconds before unlocking button to prevent accidental multi-tap
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _sendingKOTOrderIds.remove(order.id);
            _sendingKOTOrderIds.remove(targetOrder.id);
          });
        }
      });
    }
  }

  Future<void> _sendWhatsAppKOT(Order order) async {
    AdminShareSheet.show(context, order, allOrders: _allOrders);
  }

  bool _isLiveOrder(Order order) {
    return order.status == OrderStatus.adminPending ||
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.packed ||
        order.status == OrderStatus.shipped;
  }

  bool _orderMatchesOutlet(Order o, String outletId) {
    if (outletId == 'ALL') return true;
    if (outletId == 'DARKSTORE') {
      if (!o.isRestaurantOrder) return true;
      if (o.isCombined == true && o.subOrders != null) {
        return o.subOrders!.any((s) => !s.isRestaurantOrder);
      }
      return false;
    }
    final target = outletId.toLowerCase().trim();
    final rId = (o.restaurantId ?? '').toLowerCase().trim();
    final sName = (o.shopName ?? '').toLowerCase().trim();
    if (rId == target || sName.contains(target) || target.contains(sName)) return true;
    if (o.subOrders != null && o.subOrders!.isNotEmpty) {
      return o.subOrders!.any((s) {
        final subRId = (s.restaurantId ?? '').toLowerCase().trim();
        final subSName = (s.shopName ?? '').toLowerCase().trim();
        return subRId == target || subSName.contains(target) || target.contains(subSName);
      });
    }
    return false;
  }

  List<Map<String, dynamic>> _buildOutletsList() {
    final relevantOrders = _selectedTab == 0
        ? _allOrders.where(_isLiveOrder).toList()
        : _allOrders.where((o) => !_isLiveOrder(o)).toList();

    final List<Map<String, dynamic>> result = [];

    // 1. All Outlets
    result.add({
      'id': 'ALL',
      'name': 'All Outlets',
      'icon': '🏢',
      'count': relevantOrders.length,
    });

    // 2. Darkstore (Grocery)
    final darkstoreCount = relevantOrders.where((o) => _orderMatchesOutlet(o, 'DARKSTORE')).length;
    result.add({
      'id': 'DARKSTORE',
      'name': 'Darkstore',
      'icon': '🛒',
      'count': darkstoreCount,
    });

    // 3. Known / Registered Restaurants & Dynamic Restaurants from orders
    final Map<String, String> uniqueRestaurants = {};
    for (final r in RestaurantRegistry.all) {
      uniqueRestaurants[r.id] = r.name;
    }
    for (final o in relevantOrders) {
      if (o.restaurantId != null && o.restaurantId!.isNotEmpty) {
        uniqueRestaurants[o.restaurantId!] = o.shopName ?? RestaurantRegistry.getName(o.restaurantId) ?? 'Restaurant';
      }
      if (o.subOrders != null) {
        for (final sub in o.subOrders!) {
          if (sub.restaurantId != null && sub.restaurantId!.isNotEmpty) {
            uniqueRestaurants[sub.restaurantId!] = sub.shopName ?? RestaurantRegistry.getName(sub.restaurantId) ?? 'Restaurant';
          }
        }
      }
    }

    uniqueRestaurants.forEach((restId, restName) {
      final count = relevantOrders.where((o) => _orderMatchesOutlet(o, restId)).length;
      String icon = '🍽️';
      final lowerName = restName.toLowerCase();
      if (lowerName.contains('cafe') || lowerName.contains('burger') || lowerName.contains('pizza')) {
        icon = '🍕';
      } else if (lowerName.contains('bal udyan') || lowerName.contains('garden')) {
        icon = '🌲';
      }
      String shortName = restName
          .replaceAll(RegExp(r'\s+restaurant', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+cafe', caseSensitive: false), ' Cafe')
          .trim();
      result.add({
        'id': restId,
        'name': shortName,
        'icon': icon,
        'count': count,
      });
    });

    return result;
  }

  Map<String, int> _buildStatusCounts() {
    final relevantOrders = _selectedTab == 0
        ? _allOrders.where(_isLiveOrder).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList()
        : _allOrders.where((o) => !_isLiveOrder(o)).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList();

    final Map<String, int> counts = {};
    counts['ALL'] = relevantOrders.length;
    counts['PAYMENT_PENDING'] = relevantOrders.where((o) => o.status == OrderStatus.pending && _isUnpaidOnline(o)).length;
    counts['ADMIN_PENDING'] = relevantOrders.where((o) => o.status == OrderStatus.adminPending).length;
    counts['PENDING'] = relevantOrders.where((o) => o.status == OrderStatus.pending && !_isUnpaidOnline(o)).length;
    counts['CONFIRMED'] = relevantOrders.where((o) => o.status == OrderStatus.confirmed).length;
    counts['PACKED'] = relevantOrders.where((o) => o.status == OrderStatus.packed).length;
    counts['SHIPPED'] = relevantOrders.where((o) => o.status == OrderStatus.shipped).length;
    counts['DELIVERED'] = relevantOrders.where((o) => o.status == OrderStatus.delivered).length;
    counts['CANCELLED'] = relevantOrders.where((o) => o.status == OrderStatus.cancelled).length;
    return counts;
  }

  Map<DeliveryRouteKey, int> _buildRoadCorridorCounts() {
    final relevantOrders = _selectedTab == 0
        ? _allOrders.where(_isLiveOrder).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList()
        : _allOrders.where((o) => !_isLiveOrder(o)).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList();

    final Map<DeliveryRouteKey, int> counts = {
      DeliveryRouteKey.all: relevantOrders.length,
      DeliveryRouteKey.hamirpur: 0,
      DeliveryRouteKey.moosanagar: 0,
      DeliveryRouteKey.kanpur: 0,
      DeliveryRouteKey.jahanabad: 0,
      DeliveryRouteKey.townCenter: 0,
    };

    for (final o in relevantOrders) {
      final key = DeliveryRoutes.detect(o).key;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, String>> _buildAllAvailableRiders() {
    final Map<String, Map<String, String>> riderMap = {};

    // 1. Store Partner (Self Delivery)
    riderMap['store_admin_self'] = {
      'id': 'store_admin_self',
      'name': 'Store Partner',
      'phone': 'Store Self-Delivery',
    };

    // 2. Add fetched active riders
    for (final r in _availableRiders) {
      final id = r['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      riderMap[id] = {
        'id': id,
        'name': r['name']?.toString() ?? 'Rider',
        'phone': r['phone']?.toString() ?? '',
      };
    }

    // 3. Add any riders present in orders
    for (final o in _allOrders) {
      if (o.deliveryBoyName != null && o.deliveryBoyName!.trim().isNotEmpty && o.deliveryBoyName != 'UNASSIGNED') {
        final norm = o.deliveryBoyName!.trim().toLowerCase();
        if (norm == 'store partner' || norm == 'store_admin_self') continue;
        final id = o.deliveryUserId ?? o.deliveryBoyName!;
        if (!riderMap.containsKey(id)) {
          riderMap[id] = {
            'id': id,
            'name': o.deliveryBoyName!,
            'phone': o.deliveryBoyPhone ?? '',
          };
        }
      }
    }

    return riderMap.values.toList();
  }

  Map<String, int> _buildRiderCounts() {
    final relevantOrders = _selectedTab == 0
        ? _allOrders.where(_isLiveOrder).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList()
        : _allOrders.where((o) => !_isLiveOrder(o)).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList();

    final Map<String, int> counts = {'ALL': relevantOrders.length};

    // Unassigned orders count
    counts['UNASSIGNED'] = relevantOrders.where((o) {
      final isPickup = (o.deliveryMethod ?? '').toUpperCase().contains('PICKUP');
      final hasRider = (o.deliveryBoyName != null && o.deliveryBoyName!.trim().isNotEmpty && o.deliveryBoyName != 'UNASSIGNED') || o.deliveryUserId != null;
      return !isPickup && !hasRider;
    }).length;

    // Specific rider counts
    for (final r in _buildAllAvailableRiders()) {
      final id = r['id'] ?? '';
      final name = (r['name'] ?? '').toLowerCase();
      final isStorePartner = id == 'store_admin_self' || name.contains('store partner');

      counts[id] = relevantOrders.where((o) {
        if (o.deliveryUserId != null && o.deliveryUserId == id) return true;
        if (o.deliveryBoyName != null) {
          final oName = o.deliveryBoyName!.toLowerCase();
          if (isStorePartner && (oName.contains('store partner') || oName == 'store_admin_self')) return true;
          if (oName == name) return true;
        }
        return false;
      }).length;
    }

    return counts;
  }

  List<Order> _getFilteredOrders() {
    List<Order> list = [];
    if (_selectedTab == 0) {
      // Live Tab with Outlet Filter
      list = _allOrders.where(_isLiveOrder).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList();
      if (_liveSubFilter == 'PAYMENT_PENDING') {
        list = list.where((o) => o.status == OrderStatus.pending && _isUnpaidOnline(o)).toList();
      } else if (_liveSubFilter == 'PENDING') {
        list = list.where((o) => o.status == OrderStatus.pending && !_isUnpaidOnline(o)).toList();
      } else if (_liveSubFilter != 'ALL') {
        list = list.where((o) => o.status.name.toUpperCase() == _liveSubFilter).toList();
      }
      // Newest orders on TOP (Admin preference: latest incoming order first)
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      // History Tab with Outlet Filter
      list = _allOrders.where((o) => !_isLiveOrder(o)).where((o) => _orderMatchesOutlet(o, _selectedOutlet)).toList();
      if (_historySubFilter != 'ALL') {
        list = list.where((o) => o.status.name.toUpperCase() == _historySubFilter).toList();
      }
      // LIFO for History: Most recently completed orders on TOP!
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Filter by Road Corridor (Arterial Corridor Dispatch)
    if (_selectedRoadCorridor != DeliveryRouteKey.all) {
      list = list.where((o) => DeliveryRoutes.detect(o).key == _selectedRoadCorridor).toList();
    }

    // Filter by Rider / Unassigned Dispatch
    if (_selectedRiderFilter == 'UNASSIGNED') {
      list = list.where((o) {
        final isPickup = (o.deliveryMethod ?? '').toUpperCase().contains('PICKUP');
        final hasRider = (o.deliveryBoyName != null && o.deliveryBoyName!.trim().isNotEmpty && o.deliveryBoyName != 'UNASSIGNED') || o.deliveryUserId != null;
        return !isPickup && !hasRider;
      }).toList();
    } else if (_selectedRiderFilter != 'ALL') {
      final rider = _buildAllAvailableRiders().firstWhereOrNull((r) => r['id'] == _selectedRiderFilter);
      final riderName = (rider?['name'] ?? '').toLowerCase();
      final isStorePartner = _selectedRiderFilter == 'store_admin_self' || riderName.contains('store partner');

      list = list.where((o) {
        if (o.deliveryUserId != null && o.deliveryUserId == _selectedRiderFilter) return true;
        if (o.deliveryBoyName != null) {
          final oName = o.deliveryBoyName!.toLowerCase();
          if (isStorePartner && (oName.contains('store partner') || oName == 'store_admin_self')) return true;
          if (oName == riderName) return true;
        }
        return false;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((o) {
        final idMatch = (o.readableId ?? o.id).toLowerCase().contains(_searchQuery);
        final nameMatch = (o.customerName ?? '').toLowerCase().contains(_searchQuery);
        final phoneMatch = (o.customerPhone ?? '').contains(_searchQuery);
        return idMatch || nameMatch || phoneMatch;
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hasOrders = _allOrders.isNotEmpty;
    final int rawPendingPaymentCount = _allOrders.where((o) => _isLiveOrder(o) && o.status == OrderStatus.pending && _isUnpaidOnline(o)).length;
    final int rawLiveCount = _allOrders.where((o) => _isLiveOrder(o)).length;
    final int rawHistoryCount = _allOrders.where((o) => !_isLiveOrder(o)).length;

    // Exact Indian Standard Time (IST - UTC+5:30) start of day calculation
    final nowUtc = DateTime.now().toUtc();
    final istNow = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final istStartOfDay = DateTime.utc(istNow.year, istNow.month, istNow.day).subtract(const Duration(hours: 5, minutes: 30));

    final todayOrders = _allOrders.where((o) =>
      o.createdAt.isAfter(istStartOfDay) &&
      (o.deliveryMethod?.toUpperCase() != 'RETAIL')
    ).toList();

    // Today's Sales: sum of all non-cancelled orders placed today (gross — before refunds)
    final double rawTodaySales = todayOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0.0, (sum, o) => sum + o.total);

    // Today's Net Sales: sum of DELIVERED orders placed today (net — after refunds)
    final double rawTodayNetSales = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0.0, (sum, o) => sum + (o.total - o.refundAmount).clamp(0.0, double.infinity));

    final double rawTodayDeliveryFee = todayOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0.0, (sum, o) => sum + o.deliveryFee);

    final double rawTodayPackagingFee = todayOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0.0, (sum, o) => sum + o.miscFee);

    final int rawTodayOrdersCount = todayOrders.length;

    final int rawActiveOrderCount = _allOrders.where((o) =>
      o.status != OrderStatus.delivered &&
      o.status != OrderStatus.cancelled
    ).length;

    if (hasOrders) {
      _persistStats(
        todaySales: rawTodaySales,
        netSales: rawTodayNetSales,
        todayOrdersCount: rawTodayOrdersCount,
        activeOrderCount: rawActiveOrderCount,
        liveCount: rawLiveCount,
        historyCount: rawHistoryCount,
        pendingPaymentCount: rawPendingPaymentCount,
        deliveryFee: rawTodayDeliveryFee,
        packagingFee: rawTodayPackagingFee,
      );
    }

    final double displayTodaySales = hasOrders ? rawTodaySales : _lastTodaySales;
    final double displayTodayNetSales = hasOrders ? rawTodayNetSales : _lastNetSales;
    final int displayTodayOrdersCount = hasOrders ? rawTodayOrdersCount : _lastTodayOrdersCount;
    final int displayActiveOrderCount = hasOrders ? rawActiveOrderCount : _lastActiveOrderCount;
    final double displayTodayDeliveryFee = hasOrders ? rawTodayDeliveryFee : _lastDeliveryFee;
    final double displayTodayPackagingFee = hasOrders ? rawTodayPackagingFee : _lastPackagingFee;
    final int displayLiveCount = hasOrders ? rawLiveCount : _lastLiveCount;
    final int displayHistoryCount = hasOrders ? rawHistoryCount : _lastHistoryCount;
    final int displayPendingPaymentCount = hasOrders ? rawPendingPaymentCount : _lastPendingPaymentCount;
    final displayOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.slate900),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Orders',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 16.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Live Auto-Sync (Every 3s)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: OrderAlarmService.instance.isMuted ? 'Unmute Order Alarm' : 'Mute Order Alarm',
                  icon: Icon(
                    OrderAlarmService.instance.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: OrderAlarmService.instance.isMuted ? AppDesignSystem.slate400 : AppDesignSystem.green600,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      OrderAlarmService.instance.toggleMute();
                    });
                    AppToast.showInfo(
                      context,
                      OrderAlarmService.instance.isMuted
                          ? '🔇 Order Alarm Sound Muted'
                          : '🔊 Order Alarm Sound Active',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: primaryRed),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _fetchAdminOrders();
                  },
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: primaryRed,
        onRefresh: _fetchAdminOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 1. Scrollable Dashboard Top Section (Stats & Auto-Approve switch banner)
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isDeviceOffline)
                    ConnectivityBanner(
                      onRetry: () => _fetchAdminOrders(),
                    ),

                  AdminStatsGrid(
                    displayTodaySales: displayTodaySales,
                    displayTodayNetSales: displayTodayNetSales,
                    displayTodayOrdersCount: displayTodayOrdersCount,
                    displayActiveOrderCount: displayActiveOrderCount,
                    displayTodayDeliveryFee: displayTodayDeliveryFee,
                    displayTodayPackagingFee: displayTodayPackagingFee,
                  ),

                  AdminAutoApproveBanner(
                    isAutoApprove: _isAutoApprove,
                    onToggleAutoApprove: _toggleAutoApprove,
                  ),
                ],
              ),
            ),

            // 2. Pinned Sticky Filter Header (Live/History tabs + Unified Outlet & Status bar)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyAdminFilterHeaderDelegate(
                height: 88.0,
                child: AdminFilterHeader(
                  selectedTab: _selectedTab,
                  displayLiveCount: displayLiveCount,
                  displayHistoryCount: displayHistoryCount,
                  displayPendingPaymentCount: displayPendingPaymentCount,
                  searchQuery: _searchQuery,
                  liveStatusFilters: _liveStatusFilters,
                  historyStatusFilters: _historyStatusFilters,
                  currentSubFilter: _selectedTab == 0 ? _liveSubFilter : _historySubFilter,
                  selectedOutlet: _selectedOutlet,
                  outlets: _buildOutletsList(),
                  onOutletSelected: (outletId) {
                    setState(() => _selectedOutlet = outletId);
                  },
                  statusCounts: _buildStatusCounts(),
                  selectedRoadCorridor: _selectedRoadCorridor,
                  roadCorridorCounts: _buildRoadCorridorCounts(),
                  onRoadCorridorSelected: (corridor) {
                    setState(() => _selectedRoadCorridor = corridor);
                  },
                  selectedRider: _selectedRiderFilter,
                  riders: _buildAllAvailableRiders(),
                  riderCounts: _buildRiderCounts(),
                  onRiderSelected: (riderId) {
                    setState(() => _selectedRiderFilter = riderId);
                  },
                  onTabChanged: (index) {
                    setState(() {
                      _selectedTab = index;
                      _searchQuery = '';
                    });
                  },
                  onSearchChanged: (q) {
                    if (mounted) setState(() => _searchQuery = q);
                  },
                  onSearchCleared: () {
                    if (mounted) setState(() => _searchQuery = '');
                  },
                  onFilterSelected: (status) {
                    setState(() {
                      if (_selectedTab == 0) {
                        _liveSubFilter = status;
                      } else {
                        _historySubFilter = status;
                      }
                    });
                  },
                ),
              ),
            ),

            // 2.5 Subtle Background Sync Indicator
            if (_isFetchingAdmin && _allOrders.isNotEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 2.5,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                  ),
                ),
              ),

            // 3. Orders List or Loading Skeleton or Empty / Error Views
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  child: const AdminOrdersListSkeleton(itemCount: 4)
                      .animate()
                      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: AppDesignSystem.danger),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchAdminOrders,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (displayOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AdminOrdersEmptyView(
                  isLive: _selectedTab == 0,
                  onRefresh: _fetchAdminOrders,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = displayOrders[index];
                      return AdminOrderCard(
                        key: ValueKey(order.id),
                        order: order,
                        isProcessing: _inProgressOrderIds.contains(order.id),
                        isLive: _isLiveOrder(order),
                        isKOTPrinted: _printedKOTOrders.contains(order.id) ||
                            (order.readableId != null && _printedKOTOrders.contains(order.readableId)),
                        isKOTSending: _sendingKOTOrderIds.contains(order.id) ||
                            (order.readableId != null && _sendingKOTOrderIds.contains(order.readableId)),
                        availableRiders: _availableRiders,
                        onUpdateStatus: _updateOrderStatus,
                        onUpdateSubOrderStatus: _updateSubOrderStatus,
                        onAssignRider: _assignRider,
                        onUpdateRoute: _updateOrderRoute,
                        onWhatsappCustomer: _whatsappCustomer,
                        onCallCustomer: _callCustomer,
                        onShowSubstitution: _showSubstitutionModal,
                        onVerifyPayment: _verifyOnlinePayment,
                        onConvertToCOD: _convertToCOD,
                        onSendWhatsAppPaymentReminder: _sendWhatsAppPaymentReminder,
                        onOpenSuperOrderEdit: _openSuperOrderEditModal,
                        onShowRecordRefund: _showRecordRefundModal,
                        onSendRemoteKOT: _sendRemoteKOT,
                        onSendWhatsAppKOT: _sendWhatsAppKOT,
                      )
                          .animate()
                          .fadeIn(
                            duration: 320.ms,
                            delay: (index * 40).clamp(0, 240).ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                    childCount: displayOrders.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatOrderTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }
}

/// Sticky delegate to pin AdminFilterHeader (Tabs & Filters) at the top of scroll
class _StickyAdminFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyAdminFilterHeaderDelegate({
    required this.child,
    this.height = 92.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyAdminFilterHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
