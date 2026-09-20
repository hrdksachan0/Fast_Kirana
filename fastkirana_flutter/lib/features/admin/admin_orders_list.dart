import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/kot_print_service.dart';
import '../../core/services/admin_authorization.dart';
import '../../core/utils/app_toast.dart';
import '../delivery/widgets/connectivity_banner.dart';
import '../common/order_edit_modal.dart';
import 'widgets/admin_order_card.dart';
import 'widgets/admin_stats_grid.dart';
import 'widgets/admin_filter_header.dart';
import 'widgets/admin_substitution_sheet.dart';
import 'widgets/admin_refund_sheet.dart';
import 'widgets/admin_share_sheet.dart';
import 'widgets/admin_orders_empty_view.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/order_alarm_service.dart';
import '../common/widgets/battery_optimization_dialog.dart';
import '../../core/services/secure_storage_service.dart';
import '../../widgets/app_confirmation_dialog.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminOrdersScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen>
    with AutomaticKeepAliveClientMixin<AdminOrdersScreen> {
  @override
  bool get wantKeepAlive => true;

  // 0 = Live Orders, 1 = Order History
  int _selectedTab = 0;
  String _liveSubFilter = 'ALL';
  String _historySubFilter = 'ALL';
  String _searchQuery = '';

  static List<Order> _cachedOrders = [];
  List<Order> _allOrders = _cachedOrders;
  bool _isLoading = _cachedOrders.isEmpty;

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

  Future<void> _loadDiskOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastTodaySales = prefs.getDouble('admin_last_today_sales') ?? _lastTodaySales;
      _lastNetSales = prefs.getDouble('admin_last_net_sales') ?? _lastNetSales;
      _lastTodayOrdersCount = prefs.getInt('admin_last_today_orders_count') ?? _lastTodayOrdersCount;
      _lastActiveOrderCount = prefs.getInt('admin_last_active_orders_count') ?? _lastActiveOrderCount;
      _lastLiveCount = prefs.getInt('admin_last_live_count') ?? _lastLiveCount;
      _lastHistoryCount = prefs.getInt('admin_last_history_count') ?? _lastHistoryCount;
      _lastPendingPaymentCount = prefs.getInt('admin_last_pending_payment_count') ?? _lastPendingPaymentCount;
      _lastDeliveryFee = prefs.getDouble('admin_last_delivery_fee') ?? _lastDeliveryFee;
      _lastPackagingFee = prefs.getDouble('admin_last_packaging_fee') ?? _lastPackagingFee;

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
  bool _isFetchingAdmin = false;

  static const Color primaryRed = AppDesignSystem.primary;

  bool _isAutoApprove = false;

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
  String? _assignedStoreId;

  List<Map<String, String>> _availableRiders = [];

  Future<void> _fetchAdminProfile() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/admin/me', options: AdminAuthorization.options());
      if (res.data != null) {
        final sId = res.data['assignedStoreId']?.toString();
        if (sId != null && sId.isNotEmpty && mounted) {
          setState(() {
            _assignedStoreId = sId;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('assigned_store_id', sId);
          await SecureStorage.write('assigned_store_id', sId);
          _fetchDeliveryRiders();
          _silentFetchAdminOrders();
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

    _loadDiskOrders();
    if (_cachedOrders.isNotEmpty) {
      _allOrders = _cachedOrders;
      _isLoading = false;
      _silentFetchAdminOrders();
    } else {
      _fetchAdminOrders();
    }

    // 1. Ultra-fast WebSocket Realtime Connection (0ms instant sync)
    _realtimeOrdersChannel = SupabaseService.subscribeToAllOrdersRealtime(
      onOrderChange: (record) {
        if (!_isDeviceOffline) {
          final orderStoreId = record['storeId']?.toString();
          if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty &&
              orderStoreId != null && orderStoreId.isNotEmpty &&
              _assignedStoreId != orderStoreId) {
            return; // Ignore order updates from other dark store hubs
          }
          debugPrint('[Admin WebSocket] Live order update event: ${record['id']}');
          _silentFetchAdminOrders();
          final status = (record['status'] ?? '').toString().toUpperCase();
          if (status == 'CANCELLED') {
            final recordId = record['id']?.toString();
            final readableId = record['readableId']?.toString();
            if (OrderAlarmService.instance.isPlaying &&
                (OrderAlarmService.instance.activeOrderId == recordId ||
                 OrderAlarmService.instance.activeOrderId == readableId)) {
              _stopPendingAlarm();
            }
          } else if (status == 'PENDING' || status == 'ADMIN_PENDING') {
            _playChime();
          }
        }
      },
    );

    // 2. Calm fallback sync timer every 30 seconds
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isDeviceOffline) {
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
          if (sb != null && riderId != null) {
            await sb.from('orders').update({
              'deliveryUserId': riderId,
              'status': 'SHIPPED',
              'updatedAt': DateTime.now().toIso8601String(),
            }).eq('id', id);
          }
          await dio.patch('/api/orders/$id', data: {
            if (riderId != null) 'deliveryUserId': riderId,
            'status': 'SHIPPED',
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
      await notif.subscribeToTopic('admin_orders');
      await notif.subscribeToTopic('admin_orders_all');
      if (storeId != null && storeId.isNotEmpty) {
        await notif.subscribeToTopic('admin_orders_$storeId');
      }
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
        _updateOrderStatus(order, OrderStatus.confirmed);
      },
    );
  }

  void _stopPendingAlarm() {
    OrderAlarmService.instance.stopAlarm();
  }

  void _syncAlarmStateWithOrders(List<Order> orders) {
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.adminPending).toList();
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
    _stopPendingAlarm();
    _audioPlayer.dispose();
    _liveSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    SupabaseService.unsubscribe(_realtimeOrdersChannel);
    super.dispose();
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
      final List<Order> loaded = [];
      final Set<String> seenIds = {};

      void addUnique(Order o) {
        final key = o.id;
        if (!seenIds.contains(key)) {
          seenIds.add(key);
          loaded.add(o);
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
                .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)');
            if (storeId != null && storeId.isNotEmpty) {
              query = query.eq('storeId', storeId);
            }
            final res = await query
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
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
                try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
              }
            }
          } catch (e) {
            debugPrint('REST orders fetch error: $e');
          }
        }(),
      ]);

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
      final cid = o.combinedId?.trim();
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
              allItems.add(item.copyWith(
                restaurantId: item.restaurantId ?? sub.restaurantId,
                shopName: item.shopName ?? sub.shopName,
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

      OrderStatus combinedStatus(List<OrderStatus> statuses) {
        final active = statuses.where((s) => s != OrderStatus.cancelled).toList();
        if (active.isEmpty) return OrderStatus.cancelled;
        if (active.contains(OrderStatus.adminPending)) return OrderStatus.adminPending;
        if (active.contains(OrderStatus.pending)) return OrderStatus.pending;
        if (active.contains(OrderStatus.confirmed)) return OrderStatus.confirmed;
        if (active.contains(OrderStatus.packed)) return OrderStatus.packed;
        if (active.contains(OrderStatus.shipped)) return OrderStatus.shipped;
        return OrderStatus.delivered;
      }

      final statuses = subOrders.map((o) => o.status).toList();

      final baseReadableId = (primary.readableId ?? '')
          .replaceAll(RegExp(r'-[GR]\d*$', caseSensitive: false), '');

      final subLabels = subOrders.map((o) {
        final isRest = o.isRestaurantOrder;
        final name = (o.shopName != null && o.shopName!.trim().isNotEmpty && o.shopName != 'FastKirana Dark Store' && o.shopName != 'FastKirana Store')
            ? o.shopName!.trim()
            : (RestaurantRegistry.getName(o.restaurantId) ?? (isRest ? 'Restaurant' : 'Dark Store'));
        return isRest ? '🍽️ $name' : '🛒 $name';
      }).toList();

      final combinedDeliveryFee = subOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.deliveryFee,
      );

      final combinedMiscFee = subOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.miscFee,
      );

      final merged = primary.copyWith(
        readableId: baseReadableId.isNotEmpty ? baseReadableId : primary.readableId,
        items: allItems,
        total: combinedTotal,
        refundAmount: combinedRefundAmount,
        deliveryFee: combinedDeliveryFee,
        miscFee: combinedMiscFee,
        status: combinedStatus(statuses),
        shopName: subLabels.join(' + '),
        combinedId: entry.key,
        isCombined: true,
        subOrders: subOrders,
        subLabels: subLabels,
      );

      result.add(merged);
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _silentFetchAdminOrders() async {
    if (_isFetchingAdmin) return;
    _isFetchingAdmin = true;

    if (!SecureStorage.isCacheLoaded || SecureStorage.cachedUserId == null) {
      await SecureStorage.loadCache();
    }

    try {
      final dio = ref.read(dioProvider);
      final List<Order> loaded = [];
      final Set<String> seenIds = {};

      void addUnique(Order o) {
        if (seenIds.add(o.id)) {
          loaded.add(o);
        }
      }

      // Run ALL 3 sources in PARALLEL (not sequential waterfall)
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
                .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)');
            if (storeId != null && storeId.isNotEmpty) {
              query = query.eq('storeId', storeId);
            }
            final res = await query
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
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
                try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
              }
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
        }(),
        // 3. Local cached orders
        () async {
          try {
            final repo = OrderRepository(dio);
            final local = await repo.getOrders('');
            for (final o in local) {
              addUnique(o);
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); }
        }(),
      ]);

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
    } catch (e, _) { LoggerService.error('AdminOrdersList: order parse', e); } finally {
      _isFetchingAdmin = false;
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
      final List<String> idsToUpdate = (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty)
          ? order.subOrders!.map((s) => s.id).toList()
          : [order.id];

      setState(() {
        _allOrders = _allOrders.map((o) {
          if (o.id == order.id || idsToUpdate.contains(o.id) || (order.combinedId != null && o.combinedId == order.combinedId)) {
            return o.copyWith(status: newStatus);
          }
          return o;
        }).toList();
      });

      if (newStatus != OrderStatus.adminPending && newStatus != OrderStatus.pending) {
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
        }

        for (final id in idsToUpdate) {
          futures.add(OrderRepository(ref.read(dioProvider)).updateOrderStatus(id, newStatus).catchError((_) => false));
        }

        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('[Admin status update error]: $e');
    }
  }

  Future<void> _updateSubOrderStatus(Order parentOrder, Order subOrder, OrderStatus newStatus) async {
    HapticFeedback.heavyImpact();
    try {
      final statusUpper = newStatus == OrderStatus.adminPending ? 'ADMIN_PENDING' : newStatus.name.toUpperCase();

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
        }

        futures.add(OrderRepository(ref.read(dioProvider)).updateOrderStatus(subOrder.id, newStatus).catchError((_) => false));
        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('[SubOrder status update error]: $e');
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappCustomer(String phone, String orderId) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=Hi%20from%20FastKirana%20re:%20Order%20%23$orderId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _assignRider(Order order, String riderId, String riderName, String riderPhone) async {
    HapticFeedback.heavyImpact();
    final List<String> idsToAssign = (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty)
        ? order.subOrders!.map((s) => s.id).toList()
        : [order.id];

    // 1. Instant Optimistic UI Update (0ms)
    setState(() {
      _allOrders = _allOrders.map((o) {
        if (o.id == order.id || idsToAssign.contains(o.id) || (order.combinedId != null && o.combinedId == order.combinedId)) {
          return o.copyWith(
            status: OrderStatus.shipped,
            deliveryBoyName: riderName,
            deliveryBoyPhone: riderPhone,
          );
        }
        return o;
      }).toList();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Assigned to $riderName · Status set to Out for Delivery!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: AppDesignSystem.cyan600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // 2. Concurrent Network Sync
    if (_isDeviceOffline) {
      for (final id in idsToAssign) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        await OfflineSyncService.enqueueAction(
          queueName: OfflineSyncService.queueAdmin,
          action: 'ASSIGN_RIDER',
          payload: {
            'id': cleanId,
            'riderId': riderId,
          },
        );
      }
    } else {
      final futures = <Future>[];
      final sb = SupabaseService.client;
      if (sb != null) {
        for (final id in idsToAssign) {
          var cleanId = id.trim();
          if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
          futures.add(sb.from('orders').update({
            'deliveryUserId': riderId,
            'status': 'SHIPPED',
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', cleanId).catchError((_) {}));
        }
      }

      for (final id in idsToAssign) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        futures.add(ref.read(dioProvider).patch('/api/orders/$cleanId', data: {
          'deliveryUserId': riderId,
          'status': 'SHIPPED',
        }).catchError((_) => Response(requestOptions: RequestOptions())));
      }

      await Future.wait(futures);
    }
  }

  bool _isUnpaidOnline(Order order) {
    final isCOD = order.paymentMethod == PaymentMethod.cod;
    final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
    return !isCOD && !isPaid;
  }

  Future<void> _verifyRazorpayPayment(Order order) async {
    HapticFeedback.heavyImpact();
    AppToast.showInfo(
      context,
      'Verifying Razorpay Payment...',
      subtitle: 'Checking live payment status for #${order.readableId ?? order.id}',
    );

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/api/admin/orders/sync-razorpay',
        data: {'orderId': order.id},
        options: await AdminAuthorization.optionsAsync(),
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
          final msg = res.data?['error']?.toString() ?? 'No captured Razorpay payment found.';
          AppToast.showError(
            context,
            'Verification Notice',
            subtitle: msg,
          );
        }
      }
    } catch (e) {
      String errStr = 'No captured Razorpay payment found for this order.';
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d['error'] != null) {
          errStr = d['error'].toString();
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

    final message = 'Namaste $custName ji, aapka FastKirana order #$displayId (₹$total) payment ke liye pending hai.\n\nAap is link se online pay kar sakte hain ya status track kar sakte hain:\n$trackUrl\n\nFastKirana Ghatampur se judne ke liye dhanyawad!';

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
            'shopName': it.shopName ?? (it.isRestaurantItem ? (order.shopName ?? RestaurantRegistry.getName(effectiveRestId) ?? 'Restaurant') : 'FastKirana Grocery'),
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
            FASTKIRANA KOT
======================================
TOKEN : #$orderId$custName
TYPE  : $typeStr
Print :  $printTimeStr
--------------------------------------
QTY   ITEM
--------------------------------------
$formattedItems
--------------------------------------
      *** FASTKIRANA KITCHEN ***
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
    AdminShareSheet.show(context, order);
  }

  bool _isLiveOrder(Order order) {
    return order.status == OrderStatus.adminPending ||
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.packed ||
        order.status == OrderStatus.shipped;
  }

  List<Order> _getFilteredOrders() {
    List<Order> list = [];
    if (_selectedTab == 0) {
      // Live Tab
      list = _allOrders.where(_isLiveOrder).toList();
      if (_liveSubFilter == 'PAYMENT_PENDING') {
        list = list.where((o) => o.status == OrderStatus.pending && _isUnpaidOnline(o)).toList();
      } else if (_liveSubFilter == 'PENDING') {
        list = list.where((o) => o.status == OrderStatus.pending && !_isUnpaidOnline(o)).toList();
      } else if (_liveSubFilter != 'ALL') {
        list = list.where((o) => o.status.name.toUpperCase() == _liveSubFilter).toList();
      }
    } else {
      // History Tab
      list = _allOrders.where((o) => !_isLiveOrder(o)).toList();
      if (_historySubFilter != 'ALL') {
        list = list.where((o) => o.status.name.toUpperCase() == _historySubFilter).toList();
      }
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
      body: Column(
        children: [
          if (_isDeviceOffline)
            ConnectivityBanner(
              onRetry: () => _fetchAdminOrders(),
            ),

          // 1. Dashboard Stats Cards
          AdminStatsGrid(
            displayTodaySales: displayTodaySales,
            displayTodayNetSales: displayTodayNetSales,
            displayTodayOrdersCount: displayTodayOrdersCount,
            displayActiveOrderCount: displayActiveOrderCount,
            displayTodayDeliveryFee: displayTodayDeliveryFee,
            displayTodayPackagingFee: displayTodayPackagingFee,
          ),

          // 2. Filter & Controls Header
          AdminFilterHeader(
            selectedTab: _selectedTab,
            displayLiveCount: displayLiveCount,
            displayHistoryCount: displayHistoryCount,
            displayPendingPaymentCount: displayPendingPaymentCount,
            searchQuery: _searchQuery,
            isAutoApprove: _isAutoApprove,
            liveStatusFilters: _liveStatusFilters,
            historyStatusFilters: _historyStatusFilters,
            currentSubFilter: _selectedTab == 0 ? _liveSubFilter : _historySubFilter,
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
            onToggleAutoApprove: _toggleAutoApprove,
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

          const Divider(height: 1, color: AppDesignSystem.slate200),

          // 4. Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryRed))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 40, color: AppDesignSystem.danger),
                            const SizedBox(height: 10),
                            Text(_error!, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.slate500)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchAdminOrders,
                              style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : displayOrders.isEmpty
                        ? AdminOrdersEmptyView(
                            isLive: _selectedTab == 0,
                            onRefresh: _fetchAdminOrders,
                          )
                        : RefreshIndicator(
                            color: primaryRed,
                            onRefresh: _fetchAdminOrders,
                            child: ListView.builder(
                              // ignore: deprecated_member_use
                              cacheExtent: 600,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: displayOrders.length,
                              itemBuilder: (context, index) {
                                final order = displayOrders[index];
                                return AdminOrderCard(
                                  key: ValueKey(order.id),
                                  order: order,
                                  isLive: _isLiveOrder(order),
                                  isKOTPrinted: _printedKOTOrders.contains(order.id) ||
                                      (order.readableId != null && _printedKOTOrders.contains(order.readableId)),
                                  isKOTSending: _sendingKOTOrderIds.contains(order.id) ||
                                      (order.readableId != null && _sendingKOTOrderIds.contains(order.readableId)),
                                  availableRiders: _availableRiders,
                                  onUpdateStatus: _updateOrderStatus,
                                  onUpdateSubOrderStatus: _updateSubOrderStatus,
                                  onAssignRider: _assignRider,
                                  onWhatsappCustomer: _whatsappCustomer,
                                  onCallCustomer: _callCustomer,
                                  onShowSubstitution: _showSubstitutionModal,
                                  onVerifyRazorpay: _verifyRazorpayPayment,
                                  onConvertToCOD: _convertToCOD,
                                  onSendWhatsAppPaymentReminder: _sendWhatsAppPaymentReminder,
                                  onOpenSuperOrderEdit: _openSuperOrderEditModal,
                                  onShowRecordRefund: _showRecordRefundModal,
                                  onSendRemoteKOT: _sendRemoteKOT,
                                  onSendWhatsAppKOT: _sendWhatsAppKOT,
                                );
                              },
                            ),
                          ),
          ),
        ],
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
