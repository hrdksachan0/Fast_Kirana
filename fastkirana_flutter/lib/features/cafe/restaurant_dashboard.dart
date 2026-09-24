import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/network/network_retry_helper.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../common/widgets/battery_optimization_dialog.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/auth_provider.dart';
import '../delivery/widgets/connectivity_banner.dart';
import '../common/order_edit_modal.dart';
import 'widgets/add_restaurant_product_modal.dart';
import 'widgets/edit_restaurant_product_modal.dart';
import 'widgets/restaurant_menu_catalog_tab.dart';
import 'widgets/restaurant_sales_report_tab.dart';
import 'widgets/restaurant_metrics_bar.dart';
import 'widgets/restaurant_order_card_view.dart';
import 'widgets/restaurant_prep_time_modal.dart';
import 'widgets/restaurant_kot_modal.dart';
import 'widgets/restaurant_outlet_switcher_modal.dart';
import 'widgets/restaurant_quick86_sheet.dart';
import 'widgets/restaurant_settings_tab.dart';

class RestaurantDashboard extends ConsumerStatefulWidget {
  final String? initialRestaurantId;
  final String? initialRestaurantName;

  const RestaurantDashboard({
    super.key,
    this.initialRestaurantId,
    this.initialRestaurantName,
  });

  @override
  ConsumerState<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends ConsumerState<RestaurantDashboard> with WidgetsBindingObserver {
  int _activeTab = 0; // 0: Live Orders, 1: Quick 86 Menu, 2: Sales Report, 3: Settings
  static List<Map<String, dynamic>> _cachedOrders = [];
  bool _isLoading = _cachedOrders.isEmpty;
  bool _isStoreOpen = true;
  bool _isBusyMode = false;
  String _openTime = '09:00';
  String _closeTime = '23:59';
  int _refreshCountdown = 15;

  List<Map<String, dynamic>> _orders = _cachedOrders;
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _salesOrders = []; // All orders (incl. delivered) for Sales tab
  Map<String, dynamic> _salesSummary = {};
  
  Timer? _autoRefreshTimer;
  bool _isFetchingOrders = false;
  String _restaurantName = 'Restaurant Console';
  String? _assignedRestaurantId;
  String? _updatingOrderId;
  double _commissionRate = 25.0;

  double _getCommissionRateForOutlet(String? id, String? name) {
    final rest = RestaurantRegistry.find(id) ?? RestaurantRegistry.find(name);
    if (rest?.commissionRate != null) {
      final cr = rest!.commissionRate!;
      return cr <= 1.0 ? (cr * 100) : cr;
    }
    return 20.0;
  }

  final Set<String> _knownPendingOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _pendingAlarmTimer;
  bool _isPlayingAlarm = false;
  RealtimeChannel? _restaurantOrdersChannel;
  RealtimeChannel? _restaurantBroadcastChannel;
  String? _currentlySubscribedOutletId;
  String _selectedStatusFilter = 'ALL'; // ALL, PENDING, CONFIRMED, PACKED

  // Dynamic Theme Colors
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color brandAmber = AppDesignSystem.warning;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;
  static const Color bgMain = AppDesignSystem.slate50;

  List<Map<String, String>> get _availableOutlets {
    final list = RestaurantRegistry.all;
    final outlets = list.map((r) => {'id': r.id, 'name': r.name}).toList();
    if (outlets.isEmpty && _assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
      outlets.add({'id': _assignedRestaurantId!, 'name': _restaurantName});
    }
    return outlets;
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDeviceOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
    _resolveOutletDetailsSync();
    _loadLocalCachedData();
    _initConnectivityAndOfflineQueue();
    _initOutletDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BatteryOptimizationDialog.showIfNecessary(context);
      }
    });

    // 15-second background refresh timer (with countdown indicator)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_refreshCountdown > 1) {
        setState(() => _refreshCountdown--);
      } else {
        setState(() => _refreshCountdown = 15);
        if (!_isFetchingOrders && !_isDeviceOffline) {
          _fetchOrders(silent: true);
        }
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
    } catch (e) {
      LoggerService.error('RestaurantDashboard: AudioContext setup error', e);
    }
  }

  void _initConnectivityAndOfflineQueue() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (mounted) {
        final wasOffline = _isDeviceOffline;
        setState(() => _isDeviceOffline = isOffline);
        if (wasOffline && !isOffline) {
          _flushOfflineRestaurantQueue();
          _fetchOrders(silent: true);
          _fetchMenuItems();
        }
      }
    });
  }

  /// Synchronously and immediately bind the outlet on init before any async or network calls
  void _resolveOutletDetailsSync() {
    // 1. Initial args if passed explicitly
    if (widget.initialRestaurantId != null && widget.initialRestaurantId!.isNotEmpty) {
      _assignedRestaurantId = widget.initialRestaurantId;
      if (widget.initialRestaurantName != null && widget.initialRestaurantName!.isNotEmpty) {
        _restaurantName = widget.initialRestaurantName!;
      }
    }

    // 2. User profile from authProvider state
    final user = ref.read(authProvider).valueOrNull;
    final userPhone = (user?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = userPhone.length >= 10 ? userPhone.substring(userPhone.length - 10) : userPhone;

    if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
      if (user?.assignedRestaurantId != null && user!.assignedRestaurantId!.isNotEmpty) {
        _assignedRestaurantId = user.assignedRestaurantId;
      } else {
        final matchedRest = RestaurantRegistry.findByPhone(last10);
        if (matchedRest != null) {
          _assignedRestaurantId = matchedRest.id;
          _restaurantName = matchedRest.name;
        } else if (_availableOutlets.isNotEmpty) {
          _assignedRestaurantId = _availableOutlets.first['id'];
          _restaurantName = _availableOutlets.first['name'] ?? _restaurantName;
        }
      }
    }

    if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
      final match = _availableOutlets.firstWhere(
        (o) => o['id'] == _assignedRestaurantId,
        orElse: () => {'id': _assignedRestaurantId!, 'name': _restaurantName},
      );
      _restaurantName = match['name'] ?? _restaurantName;
    }

    _commissionRate = _getCommissionRateForOutlet(_assignedRestaurantId, _restaurantName);

    final reg = _assignedRestaurantId != null ? RestaurantRegistry.find(_assignedRestaurantId!) : null;
    if (reg != null) {
      if (reg.openTime != null && reg.openTime!.isNotEmpty) _openTime = reg.openTime!;
      if (reg.closeTime != null && reg.closeTime!.isNotEmpty) _closeTime = reg.closeTime!;
    }

    // Persist active outlet ID for notification and data isolation
    if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('assigned_restaurant_id', _assignedRestaurantId!);
      });
    }
  }

  Future<void> _loadLocalCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check user_data if not yet resolved synchronously
      if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
        final phone = (prefs.getString('user_phone') ?? prefs.getString('auth_phone') ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final last10 = phone.length >= 10 ? phone.substring(phone.length - 10) : phone;
        final matchedRest = RestaurantRegistry.findByPhone(last10);
        if (matchedRest != null) {
          _assignedRestaurantId = matchedRest.id;
          _restaurantName = matchedRest.name;
        } else {
          final rawUserData = prefs.getString('user_data');
          if (rawUserData != null && rawUserData.isNotEmpty) {
            try {
              final json = jsonDecode(rawUserData) as Map<String, dynamic>;
              final rId = json['assignedRestaurantId']?.toString();
              if (rId != null && rId.isNotEmpty) {
                _assignedRestaurantId = rId;
              }
            } catch (_) {}
          }
        }
      }

      final cacheKey = 'local_restaurant_orders_${_assignedRestaurantId ?? "default"}';
      final String? rawOrders = prefs.getString(cacheKey);

      if (rawOrders != null && rawOrders.isNotEmpty && mounted) {
        final List list = jsonDecode(rawOrders);
        var loadedOrders = list.map((e) => Map<String, dynamic>.from(e)).toList();
        if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
          loadedOrders = loadedOrders.where((o) {
            final rId = o['restaurantId'] ?? o['restaurant']?['id'];
            final rName = o['restaurantName'] ?? o['shopName'];
            return _isOrderForThisOutlet(rId, rName);
          }).toList();
        }
        setState(() {
          _orders = loadedOrders;
          _isLoading = false;
        });
        _syncAlarmStateWithOrders(loadedOrders);
      }

      final menuCacheKey = 'local_restaurant_menu_${_assignedRestaurantId ?? "default"}';
      final rawMenu = prefs.getString(menuCacheKey);
      if (rawMenu != null && rawMenu.isNotEmpty && mounted) {
        final List menuList = jsonDecode(rawMenu);
        setState(() {
          _menuItems = menuList.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }

      final savedOpen = prefs.getBool('store_open_${_assignedRestaurantId ?? "default"}');
      if (savedOpen != null && mounted) {
        setState(() => _isStoreOpen = savedOpen);
      }
      final savedBusy = prefs.getBool('busy_mode_${_assignedRestaurantId ?? "default"}');
      if (savedBusy != null && mounted) {
        setState(() => _isBusyMode = savedBusy);
      }
      final savedOpenTime = prefs.getString('open_time_${_assignedRestaurantId ?? "default"}');
      final savedCloseTime = prefs.getString('close_time_${_assignedRestaurantId ?? "default"}');
      if (savedOpenTime != null && savedOpenTime.isNotEmpty && mounted) {
        setState(() => _openTime = savedOpenTime);
      }
      if (savedCloseTime != null && savedCloseTime.isNotEmpty && mounted) {
        setState(() => _closeTime = savedCloseTime);
      }
    } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
  }

  Future<void> _saveLocalCachedOrders(List<Map<String, dynamic>> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_restaurant_orders_${_assignedRestaurantId ?? "default"}', jsonEncode(orders));
    } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
  }

  Future<void> _saveLocalCachedMenu(List<Map<String, dynamic>> menu) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_restaurant_menu_${_assignedRestaurantId ?? "default"}', jsonEncode(menu));
    } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
  }

  Future<void> _flushOfflineRestaurantQueue() async {
    final dio = ref.read(dioProvider);
    await OfflineSyncService.flushQueue(OfflineSyncService.queueRestaurant, (item) async {
      final action = item['action']?.toString();
      final payload = Map<String, dynamic>.from(item['payload'] as Map);

      try {
        if (action == 'UPDATE_ORDER_STATUS') {
          final orderId = payload['orderId']?.toString();
          final status = payload['nextStatus']?.toString();
          if (orderId == null || status == null) return true;

          final body = <String, dynamic>{'status': status};
          if (payload['prepTime'] != null) {
            body['prepTime'] = payload['prepTime'];
          }

          final res = await dio.patch('/api/orders/$orderId', data: body);
          return res.statusCode == 200 || res.statusCode == 204;
        } else if (action == 'TOGGLE_MENU_STOCK') {
          final itemId = payload['itemId']?.toString();
          final isAvailable = payload['isAvailable'] == true;
          if (itemId == null) return true;

          final res = await dio.patch('/api/restaurant-dashboard/products/$itemId', data: {'isAvailable': isAvailable});
          return res.statusCode == 200 || res.statusCode == 204;
        }
        return true;
      } catch (e) {
        LoggerService.error('[Restaurant Offline Sync Error]: $e');
        return false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPendingAlarm();
    _autoRefreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    if (_restaurantOrdersChannel != null) {
      SupabaseService.unsubscribe(_restaurantOrdersChannel);
    }
    if (_restaurantBroadcastChannel != null) {
      SupabaseService.unsubscribe(_restaurantBroadcastChannel);
    }
    if (_currentlySubscribedOutletId != null) {
      final notif = NotificationService();
      notif.unsubscribeFromTopic('restaurant_$_currentlySubscribedOutletId');
      notif.unsubscribeFromTopic('kitchen_$_currentlySubscribedOutletId');
      notif.unsubscribeFromTopic('restaurant_orders_$_currentlySubscribedOutletId');
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verify connectivity & sync on app resume
      if (!_isDeviceOffline) {
        _fetchOrders(silent: true);
        _flushOfflineRestaurantQueue();
        _initSupabaseRealtime();
      }
    }
  }

  Future<void> _initOutletDetails() async {
    // 0. Synchronous check immediately runs first so zero wait time
    _resolveOutletDetailsSync();

    final dio = ref.read(dioProvider);

    // 1. Fetch dynamic active restaurants from backend to support ANY new outlet
    try {
      final res = await dio.get('/api/restaurants');
      if (res.statusCode == 200 && res.data is List) {
        final List list = res.data as List;
        for (final item in list) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              final idx = _availableOutlets.indexWhere((o) => o['id'] == id);
              final outletData = {
                'id': id,
                'name': name,
                'ownerPhone': item['ownerPhone']?.toString() ?? '',
                'commissionRate': item['commissionRate']?.toString() ?? '25',
              };
              if (idx >= 0) {
                _availableOutlets[idx] = outletData;
              } else {
                _availableOutlets.add(outletData);
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Refresh phone and ID with fresh dynamic outlet data if needed
    final user = ref.read(authProvider).valueOrNull;
    final userPhone = (user?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = userPhone.length >= 10 ? userPhone.substring(userPhone.length - 10) : userPhone;

    if ((_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) && last10.isNotEmpty) {
      final matchedByPhone = _availableOutlets.firstWhere(
        (o) {
          final oPhone = (o['ownerPhone'] ?? '').replaceAll(RegExp(r'[^0-9]'), '');
          final oLast10 = oPhone.length >= 10 ? oPhone.substring(oPhone.length - 10) : oPhone;
          return oLast10.isNotEmpty && oLast10 == last10;
        },
        orElse: () => {},
      );
      if (matchedByPhone.isNotEmpty) {
        _assignedRestaurantId = matchedByPhone['id'];
        _restaurantName = matchedByPhone['name'] ?? _restaurantName;
      }
    }

    // 3. Fallback default & resolve name
    if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
      if (RestaurantRegistry.all.isNotEmpty) {
        final first = RestaurantRegistry.all.first;
        _assignedRestaurantId = first.id;
        _restaurantName = first.name;
      }
    } else {
      final match = _availableOutlets.firstWhere(
        (o) => o['id'] == _assignedRestaurantId,
        orElse: () => {'id': _assignedRestaurantId!, 'name': _restaurantName},
      );
      _restaurantName = match['name'] ?? _restaurantName;
    }

    _commissionRate = _getCommissionRateForOutlet(_assignedRestaurantId, _restaurantName);

    if (mounted) setState(() {});

    // Only fetch live orders on init (the active tab). Menu and Sales load lazily.
    if (_cachedOrders.isNotEmpty) {
      _fetchOrders(silent: true);
    } else {
      _fetchOrders();
    }
    _initSupabaseRealtime();
    _initNotificationSubscriptions();
  }

  Future<void> _initNotificationSubscriptions() async {
    try {
      final notif = NotificationService();
      await notif.init();
      await notif.requestPermissions();
      final dio = ref.read(dioProvider);

      // Subscribe to restaurant topics for instant order buzz
      final outletId = _assignedRestaurantId ?? widget.initialRestaurantId;

      // 1. Unsubscribe from previous outlet topics if outlet has switched
      if (_currentlySubscribedOutletId != null && _currentlySubscribedOutletId != outletId) {
        await notif.unsubscribeFromTopic('restaurant_$_currentlySubscribedOutletId');
        await notif.unsubscribeFromTopic('kitchen_$_currentlySubscribedOutletId');
        await notif.unsubscribeFromTopic('restaurant_orders_$_currentlySubscribedOutletId');
        final prevRest = RestaurantRegistry.find(_currentlySubscribedOutletId);
        if (prevRest != null && prevRest.slug.isNotEmpty && prevRest.slug != _currentlySubscribedOutletId) {
          await notif.unsubscribeFromTopic('restaurant_${prevRest.slug}');
          await notif.unsubscribeFromTopic('kitchen_${prevRest.slug}');
          await notif.unsubscribeFromTopic('restaurant_orders_${prevRest.slug}');
        }
      }
      _currentlySubscribedOutletId = outletId;

      // 2. Register token with backend and subscribe strictly to current outlet topics
      await notif.registerDeviceToken(dio, role: 'RESTAURANT', assignedRestaurantId: outletId);
      if (outletId != null && outletId.isNotEmpty) {
        await notif.subscribeToTopic('restaurant_$outletId');
        await notif.subscribeToTopic('kitchen_$outletId');
        await notif.subscribeToTopic('restaurant_orders_$outletId');
        final restObj = RestaurantRegistry.find(outletId);
        if (restObj != null && restObj.slug.isNotEmpty && restObj.slug != outletId) {
          await notif.subscribeToTopic('restaurant_${restObj.slug}');
          await notif.subscribeToTopic('kitchen_${restObj.slug}');
          await notif.subscribeToTopic('restaurant_orders_${restObj.slug}');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      final clean = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
      if (clean.length == 10) {
        await notif.subscribeToTopic('phone_$clean');
      }
    } catch (e, _) {
      LoggerService.error('RestaurantDashboard: notification init error', e);
    }
  }

  // Lazy tab loading flags
  bool _menuTabLoaded = false;

  /// Called when user switches tabs — lazy-loads data for Menu and Sales tabs
  void _onTabChanged(int newTab) {
    setState(() => _activeTab = newTab);

    if (newTab == 1 && !_menuTabLoaded) {
      _menuTabLoaded = true;
      _fetchMenuItems();
    } else if (newTab == 2) {
      _fetchSalesSummary();
      _fetchSalesOrders();
    }
  }

  /// Statuses that should NOT trigger a chime sound (terminal/non-actionable)
  static const _silentStatuses = {'CANCELLED', 'REJECTED', 'DELIVERED', 'FAILED', 'REFUNDED'};

  /// Checks if an order belongs strictly to the currently active restaurant console
  bool _isOrderForThisOutlet(dynamic restaurantId, [dynamic restaurantName]) {
    // If outlet not assigned yet, do NOT match anything to prevent leaking cross-outlet or grocery data
    if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
      return false;
    }
    if (_assignedRestaurantId == 'ALL') {
      return true;
    }

    final rId = (restaurantId ?? '').toString().trim().toLowerCase();
    final rName = (restaurantName ?? '').toString().toLowerCase().trim();
    final myId = (_assignedRestaurantId ?? '').toLowerCase().trim();
    final myName = (_restaurantName).toLowerCase().trim();

    // Pure grocery orders have no restaurant ID and no restaurant name
    if (rId.isEmpty && rName.isEmpty) return false;
    if (rName == 'grocery' || rName.contains('dark store') || rName == 'fastkirana mart') return false;

    // 1. Direct ID match (REST-101, CUID, UUID, slug)
    if (rId.isNotEmpty && rId == myId) return true;

    // 2. Dynamic lookup via RestaurantRegistry
    final myRest = RestaurantRegistry.find(myId);
    final targetRest = RestaurantRegistry.find(rId) ?? (rName.isNotEmpty ? RestaurantRegistry.find(rName) : null);
    if (myRest != null && targetRest != null && myRest.id.toLowerCase() == targetRest.id.toLowerCase()) {
      return true;
    }

    // 3. Specific name match (only if not generic default)
    if (myName.isNotEmpty && myName != 'restaurant console' && myName != 'kitchen console') {
      if (rName.isNotEmpty && (rName == myName || rName.contains(myName) || myName.contains(rName))) {
        return true;
      }
    }

    return false;
  }

  void _initSupabaseRealtime() {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      // Clean up existing subscriptions before creating new ones
      if (_restaurantOrdersChannel != null) {
        SupabaseService.unsubscribe(_restaurantOrdersChannel);
        _restaurantOrdersChannel = null;
      }
      if (_restaurantBroadcastChannel != null) {
        SupabaseService.unsubscribe(_restaurantBroadcastChannel);
        _restaurantBroadcastChannel = null;
      }

      // 1. Database table changes (Listen to orders changes with strict outlet isolation)
      _restaurantOrdersChannel = supabase
          .channel('public:restaurant_orders_channel_${_assignedRestaurantId ?? 'default'}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL')
                ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'restaurantId',
                    value: _assignedRestaurantId!,
                  )
                : null,
            callback: (payload) {
              final newRecord = payload.newRecord;
              final rId = newRecord['restaurantId'];
              final rName = newRecord['restaurantName'] ?? newRecord['shopName'];
              final belongsToThisOutlet = _isOrderForThisOutlet(rId, rName);

              // STRICT OUTLET ISOLATION:
              // If order belongs to a different outlet or grocery, DO NOT DO ANYTHING!
              if (!belongsToThisOutlet) {
                return;
              }

              // Always sync order list silently for OUR outlet
              _fetchOrders(silent: true);

              // Only play chime if the new status is actionable (not cancelled/rejected/delivered)
              final newStatus = (newRecord['status'] ?? '').toString().toUpperCase();
              if (newStatus.isNotEmpty && _silentStatuses.contains(newStatus)) {
                // Order was cancelled/rejected/delivered — stop alarm instead of playing chime
                _syncAlarmStateWithOrders(_orders);
                return;
              }

              if (newStatus == 'PENDING' || newStatus == 'PLACED') {
                _playChime();
              }
            },
          );
      _restaurantOrdersChannel?.subscribe();

      // 2. Direct broadcast channel for instant KOT and order sync across devices
      final broadcastChannelName = (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty)
          ? 'restaurant-orders-live-$_assignedRestaurantId'
          : 'restaurant-orders-live';
      _restaurantBroadcastChannel = supabase
          .channel(broadcastChannelName)
          .onBroadcast(
            event: 'reprint-kot',
            callback: (payload) {
              final rId = payload['restaurantId'];
              final rName = payload['restaurantName'] ?? payload['shopName'];
              if (!_isOrderForThisOutlet(rId, rName)) return;
              _fetchOrders(silent: true);
            },
          )
          .onBroadcast(
            event: 'new_order',
            callback: (payload) {
              final rId = payload['restaurantId'];
              final rName = payload['restaurantName'] ?? payload['shopName'];
              final belongsToThisOutlet = _isOrderForThisOutlet(rId, rName);

              // STRICT OUTLET ISOLATION:
              if (!belongsToThisOutlet) {
                return; // Do NOT fetch orders, do NOT chime!
              }

              _fetchOrders(silent: true);
              _playChime();
            },
          );
      _restaurantBroadcastChannel?.subscribe();
    } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
  }

  Future<void> _playChime() async {
    try {
      HapticFeedback.heavyImpact();
      try {
        await _audioPlayer.stop();
        // Play local asset audio for zero latency and offline reliability
        await _audioPlayer.play(
          AssetSource('sounds/order_chime.mp3'),
          volume: 1.0,
        );
      } catch (e) {
        // Fallback to device system alert sound
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e, _) {
      LoggerService.error('RestaurantDashboard: audio chime error', e);
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _startPendingAlarm() {
    if (_isPlayingAlarm) return;
    _isPlayingAlarm = true;
    if (mounted) setState(() {});

    // Play immediately
    _playChime();

    // Repeat every 3 seconds continuously until confirmed or accepted
    _pendingAlarmTimer?.cancel();
    _pendingAlarmTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final hasPending = _orders.any((o) {
        final st = (o['status'] ?? '').toString().toUpperCase();
        final assignedChef = o['assignedChefId'] ?? o['assignedChef'];
        return st == 'PENDING' || (st == 'CONFIRMED' && (assignedChef == null || assignedChef.toString().isEmpty));
      });
      if (!hasPending) {
        _stopPendingAlarm();
      } else {
        _playChime();
      }
    });
  }

  void _stopPendingAlarm() {
    _pendingAlarmTimer?.cancel();
    _pendingAlarmTimer = null;
    if (_isPlayingAlarm) {
      _isPlayingAlarm = false;
      try {
        _audioPlayer.stop();
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  void _syncAlarmStateWithOrders(List<Map<String, dynamic>> orders) {
    final hasPending = orders.any((o) {
      final st = (o['status'] ?? '').toString().toUpperCase();
      final assignedChef = o['assignedChefId'] ?? o['assignedChef'];
      return st == 'PENDING' || (st == 'CONFIRMED' && (assignedChef == null || assignedChef.toString().isEmpty));
    });
    if (hasPending) {
      _startPendingAlarm();
    } else {
      _stopPendingAlarm();
    }
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final dio = ref.read(dioProvider);
      final primaryUrl = _assignedRestaurantId != null
          ? '/api/restaurant-dashboard/orders?restaurantId=$_assignedRestaurantId&status=live&limit=100'
          : '/api/restaurant-dashboard/orders?status=live&limit=100';

      Response response;
      try {
        response = await dio.get(primaryUrl);
      } catch (e) { LoggerService.error('RestaurantDashboard: silent catch', e);
        // Fallback: Use picker/orders endpoint (which already only returns PENDING/CONFIRMED)
        final fallbackUrl = _assignedRestaurantId != null
            ? '/api/picker/orders?type=restaurant&restaurantId=$_assignedRestaurantId'
            : '/api/picker/orders?type=restaurant';
        response = await dio.get(fallbackUrl);
      }
      
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data is List ? response.data : (response.data['orders'] ?? []);
        List<Map<String, dynamic>> parsed = list.map((e) => Map<String, dynamic>.from(e)).toList();

        // If picker API was empty, try fallback
        if (parsed.isEmpty && _assignedRestaurantId != null) {
          try {
            final fbRes = await dio.get('/api/restaurant-dashboard/orders?restaurantId=$_assignedRestaurantId&limit=100');
            if (fbRes.statusCode == 200 && fbRes.data != null) {
              final fbList = fbRes.data is List ? fbRes.data : (fbRes.data['orders'] ?? []);
              if (fbList.isNotEmpty) {
                parsed = fbList.map((e) => Map<String, dynamic>.from(e)).toList();
              }
            }
          } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
        }

        // Filter out pure grocery orders & unpaid online orders (Restaurant only prepares COD or PAID orders)
        parsed = parsed.where((o) {
          final oType = (o['orderType'] ?? '').toString().toUpperCase();
          if (oType == 'GROCERY') return false;
          final status = (o['status'] ?? '').toString().toUpperCase();
          if (status == 'ADMIN_PENDING') return false;
          final rId = (o['restaurantId'] ?? o['restaurant']?['id'] ?? '').toString().trim();
          if (rId.isEmpty) return false;

          final paymentMethod = (o['paymentMethod'] ?? '').toString().toUpperCase();
          final paymentStatus = (o['paymentStatus'] ?? '').toString().toUpperCase();
          final isCod = paymentMethod == 'COD';
          final isPaid = paymentStatus == 'PAID';
          if (!isCod && !isPaid) return false;

          return true;
        }).toList();

        // Ensure ID-wise outlet filtering
        if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
          parsed = parsed.where((o) {
            final rId = o['restaurantId'] ?? o['restaurant']?['id'];
            final rName = o['restaurantName'] ?? o['shopName'];
            return _isOrderForThisOutlet(rId, rName);
          }).toList();
        }

        // Check for pending orders & trigger/stop continuous alarm
        final newPending = parsed.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'PENDING').map((o) => o['id'].toString()).toSet();
        _knownPendingOrderIds.addAll(newPending);

        _syncAlarmStateWithOrders(parsed);

        _cachedOrders = parsed;
        if (mounted) {
          setState(() {
            _orders = parsed;
          });
        }
      }
    } catch (e) {
      debugPrint('[Restaurant Orders Fetch Error]: $e');
    } finally {
      _isFetchingOrders = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMenuItems() async {
    try {
      final dio = ref.read(dioProvider);
      final url = _assignedRestaurantId != null
          ? '/api/restaurant-dashboard/products?restaurantId=$_assignedRestaurantId'
          : '/api/restaurant-dashboard/products';
      final res = await dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final List prods = res.data['products'] ?? [];
        final parsedItems = prods.map((e) => Map<String, dynamic>.from(e)).toList();
        parsedItems.sort((a, b) {
          final secA = (a['menuSection'] ?? (a['category'] is Map ? a['category']['name'] : null) ?? '').toString().toLowerCase();
          final secB = (b['menuSection'] ?? (b['category'] is Map ? b['category']['name'] : null) ?? '').toString().toLowerCase();
          final secComp = secA.compareTo(secB);
          if (secComp != 0) return secComp;
          return compareProductMapsSystematic(a, b, inStockFirst: false);
        });
        if (mounted) {
          setState(() {
            _menuItems = parsedItems;
            if (res.data['restaurant'] != null && res.data['restaurant']['name'] != null) {
              _restaurantName = res.data['restaurant']['name'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[Restaurant Menu Fetch Error]: $e');
    }
  }

  Future<void> _fetchSalesSummary() async {
    try {
      final dio = ref.read(dioProvider);
      final url = _assignedRestaurantId != null
          ? '/api/restaurant-dashboard/stats?restaurantId=$_assignedRestaurantId'
          : '/api/restaurant-dashboard/stats';
      final res = await dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        if (mounted) {
          setState(() {
            _salesSummary = Map<String, dynamic>.from(res.data);
            if (res.data['commissionRate'] != null) {
              final rawComm = res.data['commissionRate'];
              _commissionRate = (rawComm is num) ? rawComm.toDouble() : (double.tryParse(rawComm.toString()) ?? 15.0);
            }
            if (res.data['restaurantName'] != null && res.data['restaurantName'].toString().isNotEmpty) {
              _restaurantName = res.data['restaurantName'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[Restaurant Stats Fetch Error]: $e');
    }
  }

  /// Fetch ALL orders (including DELIVERED) for the Sales tab - separate from live queue
  Future<void> _fetchSalesOrders({DateTime? startDate, DateTime? endDate}) async {
    try {
      final dio = ref.read(dioProvider);
      final params = <String>[];
      if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
        params.add('restaurantId=$_assignedRestaurantId');
      }
      if (startDate != null) {
        params.add('startDate=${DateFormat('yyyy-MM-dd').format(startDate)}');
      }
      if (endDate != null) {
        params.add('endDate=${DateFormat('yyyy-MM-dd').format(endDate)}');
      }
      final queryStr = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = '/api/restaurant-dashboard/orders$queryStr';
      final res = await dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final dynamic raw = res.data;
        List list;
        if (raw is Map && raw['orders'] is List) {
          list = raw['orders'];
        } else if (raw is List) {
          list = raw;
        } else {
          list = [];
        }
        final parsed = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        // Filter by current outlet using robust matcher
        List<Map<String, dynamic>> filtered = parsed;
        if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
          filtered = parsed.where((o) {
            final rId = o['restaurantId'] ?? o['restaurant']?['id'];
            final rName = o['restaurantName'] ?? o['shopName'];
            return _isOrderForThisOutlet(rId, rName);
          }).toList();
        }

        if (mounted) {
          setState(() {
            _salesOrders = filtered;
            // Set commission rate from API response (real DB value)
            if (raw is Map && raw['commissionRate'] is num) {
              _commissionRate = (raw['commissionRate'] as num).toDouble();
            }
            if (raw is Map && raw['restaurantName'] != null && raw['restaurantName'].toString().isNotEmpty) {
              _restaurantName = raw['restaurantName'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[Sales Orders Fetch Error]: $e');
    }
  }

  Future<void> _updateOrderStatus(String orderId, String nextStatus, {int? prepTime}) async {
    HapticFeedback.selectionClick();

    // 1. Instant Optimistic UI Update (0ms)
    setState(() {
      final index = _orders.indexWhere((o) => (o['id'] ?? '').toString() == orderId || (o['readableId'] ?? '').toString() == orderId);
      if (index != -1) {
        _orders[index]['status'] = nextStatus;
      }
      _updatingOrderId = orderId;
    });
    _saveLocalCachedOrders(_orders);
    _syncAlarmStateWithOrders(_orders);

    if (mounted) {
      if (nextStatus == 'CONFIRMED') {
        AppToast.showSuccess(
          context,
          'Order Accepted! 👨‍🍳',
          subtitle: _isDeviceOffline ? 'Saved offline. Cooking started.' : 'Kitchen timer set and cooking started.',
        );
      } else if (nextStatus == 'PACKED') {
        AppToast.showSuccess(
          context,
          'Food Ready for Pickup! 🥡',
          subtitle: _isDeviceOffline ? 'Saved offline. Rider will be notified when online.' : 'Rider notified to collect the package.',
        );
      } else {
        AppToast.showSuccess(
          context,
          'Order status updated to $nextStatus',
        );
      }
    }

    try {
      if (_isDeviceOffline) {
        throw Exception('Offline');
      }

      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{'status': nextStatus};
      if (prepTime != null) {
        body['prepTime'] = prepTime;
      }

      await NetworkRetryHelper.retry(
        operationName: 'update_order_status',
        action: () => dio.patch('/api/orders/$orderId', data: body),
      );

      // Background sync to Supabase and OrderRepository cache
      try {
        final sb = SupabaseService.client;
        if (sb != null) {
          await sb.from('orders').update({
            'status': nextStatus,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', orderId);
        }
      } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }

      try {
        final parsed = OrderStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == nextStatus.toUpperCase(),
          orElse: () => OrderStatus.pending,
        );
        await OrderRepository(dio).updateOrderStatus(orderId, parsed);
      } catch (e, _) { LoggerService.error('RestaurantDashboard: silent catch', e); }
    } catch (e) {
      // Offline fallback: enqueue action for automatic flush
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueRestaurant,
        action: 'UPDATE_ORDER_STATUS',
        payload: {
          'orderId': orderId,
          'nextStatus': nextStatus,
          if (prepTime != null) 'prepTime': prepTime,
        },
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _toggleItemAvailability(Map<String, dynamic> item) async {
    final bool currentStatus = item['isAvailable'] ?? true;
    final bool newStatus = !currentStatus;
    final String itemId = item['id'].toString();

    // Optimistic UI update
    setState(() {
      final index = _menuItems.indexWhere((p) => p['id'].toString() == itemId);
      if (index != -1) {
        _menuItems[index]['isAvailable'] = newStatus;
      }
    });
    _saveLocalCachedMenu(_menuItems);
    HapticFeedback.lightImpact();

    try {
      if (_isDeviceOffline) {
        throw Exception('Offline');
      }

      final dio = ref.read(dioProvider);
      await NetworkRetryHelper.retry(
        operationName: 'toggle_item_availability',
        action: () => dio.patch(
          '/api/restaurant-dashboard/products/$itemId',
          data: {'isAvailable': newStatus},
          options: Options(
            headers: {
              'x-user-role': 'RESTAURANT_OWNER',
              if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty)
                'x-restaurant-id': _assignedRestaurantId,
            },
          ),
        ),
      );
      if (mounted) {
        if (newStatus) {
          AppToast.showSuccess(
            context,
            '${item['name']} is now IN STOCK 🟢',
            subtitle: 'Available for customers to order',
          );
        } else {
          AppToast.showWarning(
            context,
            '${item['name']} marked OUT OF STOCK 🔴 (86)',
            subtitle: 'Hidden from customer menu for today',
          );
        }
      }
    } catch (e) { LoggerService.error('RestaurantDashboard: silent catch', e);
      // Enqueue offline action if network unavailable
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueRestaurant,
        action: 'TOGGLE_MENU_STOCK',
        payload: {
          'itemId': itemId,
          'isAvailable': newStatus,
        },
      );
      if (mounted) {
        AppToast.showSuccess(
          context,
          '${item['name']} updated offline 📴',
          subtitle: 'Will sync to customer menu when online',
        );
      }
    }
  }

  void _openAddDishModal() {
    HapticFeedback.selectionClick();
    AddRestaurantProductModal.show(
      context: context,
      restaurantId: _assignedRestaurantId ?? (RestaurantRegistry.all.isNotEmpty ? RestaurantRegistry.all.first.id : ''),
      restaurantName: _restaurantName,
      onProductAdded: () {
        _fetchMenuItems();
      },
    );
  }

  void _openEditDishModal(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    EditRestaurantProductModal.show(
      context: context,
      item: item,
      restaurantId: _assignedRestaurantId ?? '',
      onProductUpdated: () {
        _fetchMenuItems();
      },
      onProductDeleted: () {
        _fetchMenuItems();
      },
    );
  }

  void _showPrepTimeModal(Map<String, dynamic> order) {
    RestaurantPrepTimeModal.show(
      context: context,
      order: order,
      onConfirm: (prepMinutes) {
        _updateOrderStatus(order['id'].toString(), 'CONFIRMED', prepTime: prepMinutes);
      },
    );
  }



  void _showKOTPrintModal(Map<String, dynamic> order) {
    final user = ref.read(authProvider).valueOrNull;
    final isAdmin = user?.role.toUpperCase() == 'ADMIN';
    RestaurantKotModal.show(
      context: context,
      order: order,
      isAdmin: isAdmin,
      defaultOutletName: _restaurantName,
    );
  }


  void _showOutletSwitcherModal() {
    RestaurantOutletSwitcherModal.show(
      context: context,
      availableOutlets: _availableOutlets,
      assignedRestaurantId: _assignedRestaurantId,
      onOutletSelected: (outlet) {
        final newId = outlet['id'] ?? '';
        final newName = outlet['name'] ?? _restaurantName;

        // Stop alarm for previous outlet and clear pending IDs
        _stopPendingAlarm();
        _knownPendingOrderIds.clear();

        setState(() {
          _assignedRestaurantId = newId;
          _restaurantName = newName;
          _commissionRate = _getCommissionRateForOutlet(newId, newName);
          _orders = [];
          _salesOrders = [];
          _menuItems = [];
          _isLoading = true;
        });

        // Persist active outlet ID for notification and data isolation
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('assigned_restaurant_id', newId);
        });

        // Load cached data specifically isolated for this new outlet
        _loadLocalCachedData();

        // Reconnect realtime channels and notification topics for the new outlet
        _initSupabaseRealtime();
        _initNotificationSubscriptions();

        _fetchOrders();
        _fetchMenuItems();
        _fetchSalesSummary();
        _fetchSalesOrders();
      },
    );
  }

  void _showQuick86BottomSheet() {
    RestaurantQuick86Sheet.show(
      context: context,
      menuItems: _menuItems,
      onToggleItemAvailability: _toggleItemAvailability,
    );
  }


  void _handleBackPress() {
    HapticFeedback.lightImpact();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.role.toUpperCase() == 'ADMIN';
    
    final pendingCount = _orders.where((o) => o['status'] == 'PENDING').length;
    final activeOrders = _orders.where((o) => o['status'] == 'CONFIRMED' || o['status'] == 'PREPARING').length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: bgMain,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          leadingWidth: 40,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: slateDark),
            onPressed: _handleBackPress,
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: isAdmin ? _showOutletSwitcherModal : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.rose50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDesignSystem.rose200),
                    ),
                    child: Center(child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15)))),
                  ),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _restaurantName,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14.5),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: primaryRed),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isStoreOpen ? brandGreen : primaryRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isStoreOpen ? 'STORE OPEN' : 'STORE CLOSED',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 8.5),
                              fontWeight: FontWeight.w900,
                              color: _isStoreOpen ? brandGreen : primaryRed,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            // 🟢 Online / Paused Quick Toggle Pill
            Bounceable(
              onTap: () {
                HapticFeedback.mediumImpact();
                _handleStoreOpenToggle(!_isStoreOpen);
                AppToast.showSuccess(
                  context,
                  !_isStoreOpen ? 'Kitchen is now ONLINE 🟢' : 'Kitchen is PAUSED 🔴',
                  subtitle: !_isStoreOpen ? 'Accepting customer food orders' : 'New incoming orders paused temporarily',
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isStoreOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isStoreOpen ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isStoreOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isStoreOpen ? 'ONLINE' : 'PAUSED',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w900,
                        color: _isStoreOpen ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // More Options Dropdown Menu (Clean, Uncluttered)
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert_rounded, size: 18, color: slateDark),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              offset: const Offset(0, 42),
              onSelected: (val) async {
                if (val == 'sound') {
                  _playChime();
                  AppToast.showSuccess(context, 'Sound Alert Tested! 🔔', subtitle: 'Loud volume verified');
                } else if (val == 'quick86') {
                  _showQuick86BottomSheet();
                } else if (val == 'refresh') {
                  _fetchOrders();
                  _fetchMenuItems();
                  AppToast.showSuccess(context, 'Refreshed Live Kitchen Queue');
                } else if (val == 'logout') {
                  final nav = Navigator.of(context);
                  final confirm = await AppConfirmationDialog.showLogout(
                    context: context,
                    title: 'Log Out of Kitchen?',
                    subtitle: 'Are you sure you want to log out from Kitchen Console?',
                    accountNote: 'KOT queue and kitchen preparation lists remain synchronized.',
                    confirmLabel: 'Log Out',
                  );
                  if (confirm == true) {
                    if (!mounted) return;
                    _stopPendingAlarm();
                    _autoRefreshTimer?.cancel();
                    _audioPlayer.stop();
                    nav.pushNamedAndRemoveUntil('/login', (route) => false);
                    unawaited(ref.read(authProvider.notifier).logout());
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'sound',
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, size: 18, color: brandAmber),
                      const SizedBox(width: 10),
                      Text('Test Ringtone', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'quick86',
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: primaryRed),
                      const SizedBox(width: 10),
                      Text('Quick 86 / Out of Stock', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 18, color: AppDesignSystem.blue600),
                      const SizedBox(width: 10),
                      Text('Manual Refresh (${_refreshCountdown}s)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18, color: primaryRed),
                      const SizedBox(width: 10),
                      Text('Log Out', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryRed)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            if (_isDeviceOffline)
              ConnectivityBanner(
                onRetry: () {
                  _fetchOrders();
                  _fetchMenuItems();
                },
              ),

            RestaurantMetricsBar(
              isPlayingAlarm: _isPlayingAlarm,
              pendingCount: pendingCount,
              activeOrders: activeOrders,
              onMuteAlarm: _stopPendingAlarm,
            ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryRed))
                : _activeTab == 0
                    ? _buildLiveOrdersTab()
                    : _activeTab == 1
                        ? RestaurantMenuCatalogTab(
                            menuItems: _menuItems,
                            restaurantName: _restaurantName,
                            onAddDish: _openAddDishModal,
                            onToggleAvailability: _toggleItemAvailability,
                            onEditDish: _openEditDishModal,
                          )
                        : _activeTab == 2
                            ? RestaurantSalesReportTab(
                                salesOrders: _salesOrders,
                                salesSummary: _salesSummary,
                                commissionRate: _commissionRate,
                                primaryRed: primaryRed,
                                brandGreen: brandGreen,
                                slateDark: slateDark,
                                slateMuted: slateMuted,
                                slateBorder: slateBorder,
                                onDateRangeChanged: (start, end) {
                                  _fetchSalesOrders(startDate: start, endDate: end);
                                },
                              )
                            : _buildStoreSettingsTab(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, 'Orders', Icons.receipt_long_rounded, badgeCount: pendingCount),
                _buildNavItem(1, 'Menu', Icons.restaurant_menu_rounded),
                _buildNavItem(2, 'Earnings', Icons.bar_chart_rounded),
                _buildNavItem(3, 'Kitchen', Icons.tune_rounded),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _activeTab == 1
          ? FloatingActionButton.extended(
              backgroundColor: primaryRed,
              elevation: 4,
              onPressed: _openAddDishModal,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                'Add Dish',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            )
          : null,
    ),
  );
  }

  Widget _buildNavItem(int index, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.selectionClick();
          _onTabChanged(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFEF2F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: primaryRed,
                child: Icon(
                  icon,
                  size: 21,
                  color: isSelected ? primaryRed : slateMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? primaryRed : slateMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String key, String label, int count, IconData icon, {bool isAlert = false}) {
    final isSelected = _selectedStatusFilter == key;
    return Bounceable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStatusFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAlert ? AppDesignSystem.primary : slateDark)
              : (isAlert ? AppDesignSystem.rose50 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isAlert ? AppDesignSystem.primary : slateMuted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isAlert ? AppDesignSystem.primary : slateDark),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isAlert ? AppDesignSystem.primary : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : (isAlert ? Colors.white : slateDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrdersTab() {
    const liveStatuses = {'PENDING', 'CONFIRMED', 'PREPARING', 'PACKED', 'READY', 'OUT_FOR_DELIVERY'};
    final allLive = _orders.where((o) => liveStatuses.contains((o['status'] ?? '').toString().toUpperCase())).toList();
    final newCount = _orders.where((o) => (o['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
    final cookingCount = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toUpperCase();
      return s == 'CONFIRMED' || s == 'PREPARING';
    }).length;
    final readyCount = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toUpperCase();
      return s == 'PACKED' || s == 'READY' || s == 'OUT_FOR_DELIVERY';
    }).length;

    final filtered = allLive.where((o) {
      final s = (o['status'] ?? '').toString().toUpperCase();
      if (_selectedStatusFilter == 'ALL') return true;
      if (_selectedStatusFilter == 'PENDING') return s == 'PENDING';
      if (_selectedStatusFilter == 'PREPARING') return s == 'CONFIRMED' || s == 'PREPARING';
      if (_selectedStatusFilter == 'PACKED') return s == 'PACKED' || s == 'READY' || s == 'OUT_FOR_DELIVERY';
      return true;
    }).toList();

    return Column(
      children: [
        // Quick Status Filter Pills Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChip('ALL', 'All Live', allLive.length, Icons.all_inbox_rounded),
                const SizedBox(width: 8),
                _buildStatusChip('PENDING', 'New Orders', newCount, Icons.notifications_active_rounded, isAlert: newCount > 0),
                const SizedBox(width: 8),
                _buildStatusChip('PREPARING', 'Cooking', cookingCount, Icons.outdoor_grill_rounded),
                const SizedBox(width: 8),
                _buildStatusChip('PACKED', 'Ready', readyCount, Icons.check_circle_rounded),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: slateBorder),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(color: AppDesignSystem.slate100, shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_outline, size: 44, color: slateMuted),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _selectedStatusFilter == 'ALL'
                              ? 'No active orders right now'
                              : 'No $_selectedStatusFilter orders',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: slateDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'New incoming orders for $_restaurantName will appear here',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: slateMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchOrders(),
                  color: primaryRed,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final order = filtered[idx];
                      final orderId = (order['id'] ?? '').toString();
                      return RestaurantOrderCardView(
                        order: order,
                        isUpdating: _updatingOrderId == orderId,
                        onReject: () => _updateOrderStatus(orderId, 'CANCELLED'),
                        onAcceptAndCook: () => _showPrepTimeModal(order),
                        onMarkReady: () => _updateOrderStatus(orderId, 'PACKED'),
                        onEditOrder: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => OrderEditModal(
                              order: order,
                              isRestaurant: true,
                              restaurantId: _assignedRestaurantId ?? order['restaurantId']?.toString(),
                              onOrderUpdated: () => _fetchOrders(silent: true),
                            ),
                          );
                        },
                        onPrintKot: () => _showKOTPrintModal(order),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStoreSettingsTab() {
    return RestaurantSettingsTab(
      isStoreOpen: _isStoreOpen,
      isBusyMode: _isBusyMode,
      openTime: _openTime,
      closeTime: _closeTime,
      onToggleStoreOpen: _handleStoreOpenToggle,
      onToggleBusyMode: _handleBusyModeToggle,
      onUpdateTimings: _handleTimingsUpdate,
    );
  }

  Future<void> _handleTimingsUpdate(String open, String close) async {
    setState(() {
      _openTime = open;
      _closeTime = close;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletKey = _assignedRestaurantId ?? 'default';
      await prefs.setString('open_time_$outletKey', open);
      await prefs.setString('close_time_$outletKey', close);

      if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
        final dio = ref.read(dioProvider);
        await dio.patch('/api/restaurants/$_assignedRestaurantId', data: {
          'openTime': open,
          'closeTime': close,
        });

        // Update local in-memory registry so client reflects immediately
        final reg = RestaurantRegistry.find(_assignedRestaurantId!);
        if (reg != null) {
          RestaurantRegistry.register(
            reg.copyWith(openTime: open, closeTime: close),
          );
        }

        // Also update Supabase direct if available
        final sb = SupabaseService.client;
        if (sb != null) {
          try {
            await sb.from('restaurants').update({
              'openTime': open,
              'closeTime': close,
            }).eq('id', _assignedRestaurantId!);
          } catch (_) {}
        }
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          'Restaurant Timings Updated 🕒',
          subtitle: 'Open: ${RestaurantScheduleHelper.formatMinutesTo12h(RestaurantScheduleHelper.parseTimeStringToMinutes(open) ?? 600)} — Close: ${RestaurantScheduleHelper.formatMinutesTo12h(RestaurantScheduleHelper.parseTimeStringToMinutes(close) ?? 1380)}',
        );
      }
    } catch (e) {
      LoggerService.error('Restaurant timings update error: $e');
    }
  }

  Future<void> _handleStoreOpenToggle(bool val) async {
    setState(() => _isStoreOpen = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletKey = _assignedRestaurantId ?? 'default';
      await prefs.setBool('store_open_$outletKey', val);
      
      if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
        final dio = ref.read(dioProvider);
        await dio.patch('/api/restaurants/$_assignedRestaurantId', data: {'isOpen': val});
        if (val) {
          try {
            await dio.post('/api/admin/store-status', data: {
              'restaurantOpen': true,
              'cafeOpen': true,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      LoggerService.error('Store open toggle error: $e');
    }
  }

  Future<void> _handleBusyModeToggle(bool val) async {
    setState(() => _isBusyMode = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletKey = _assignedRestaurantId ?? 'default';
      await prefs.setBool('busy_mode_$outletKey', val);
      
      if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
        final dio = ref.read(dioProvider);
        await dio.patch('/api/restaurants/$_assignedRestaurantId', data: {
          'discountBadge': val ? 'HIGH RUSH' : null,
        });
      }
    } catch (e) {
      LoggerService.error('Busy mode toggle error: $e');
    }
  }
}