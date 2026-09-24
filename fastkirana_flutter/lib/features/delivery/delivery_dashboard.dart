import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/network/api_client.dart';
import '../../core/services/rider_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/order_item_helper.dart';
import '../../data/models/restaurant.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../providers/auth_provider.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/delivery_header.dart';
import 'widgets/doorstep_cashfree_qr_sheet.dart';
import 'widgets/delivery_payment_sheet.dart';
import 'widgets/delivery_wallet_tab.dart';
import 'widgets/delivery_history_tab.dart';
import 'widgets/delivery_orders_tab.dart';
import '../common/widgets/battery_optimization_dialog.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/app_confirmation_dialog.dart';

class DeliveryDashboard extends ConsumerStatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  ConsumerState<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends ConsumerState<DeliveryDashboard>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  static List<Map<String, dynamic>> _cachedDeliveryOrders = [];
  late bool _isLoading = _cachedDeliveryOrders.isEmpty;
  int _activeTab = 0; // 0: Deliveries, 1: Cash Wallet, 2: History
  int _pendingSyncCount = 0;

  List<Map<String, dynamic>> _orders = _cachedDeliveryOrders;


  Map<String, dynamic>? _walletInfo;
  Timer? _autoRefreshTimer;
  final int _refreshCountdown = 30;
  String? _updatingOrderId;
  String? _currentUserId;
  String _userName = 'Partner';
  String? _assignedStoreId;
  String? _assignedStoreName;

  late ConfettiController _confettiController;
  final RiderLocationService _locationService = RiderLocationService();

  bool _isDarkMode = false;
  bool _isDeviceOffline = false;
  final Set<String> _knownOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _connectivitySubscription;
  RealtimeChannel? _ordersRealtimeChannel;

  // Dynamic Theme Colors (Supporting AMOLED Dark Mode & Light Mode)
  Color get bgMain => _isDarkMode ? AppDesignSystem.darkNavy : AppDesignSystem.slate50;
  Color get cardBg => _isDarkMode ? AppDesignSystem.darkNavyCard : Colors.white;
  Color get cardSubtle => _isDarkMode ? AppDesignSystem.darkNavySubtle : AppDesignSystem.slate50;
  Color get borderCol => _isDarkMode ? AppDesignSystem.darkNavyBorder : AppDesignSystem.slate200;
  Color get textMain => _isDarkMode ? AppDesignSystem.slate100 : AppDesignSystem.slate900;
  Color get textMuted => _isDarkMode ? AppDesignSystem.slate400 : AppDesignSystem.slate500;

  bool _isFetchingOrders = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _loadUserInfo();
    _loadPersistedOfflineCache();
    _initConnectivityAndOfflineQueue();
    _initOrdersRealtime();
    _hydrateRestaurants();
    _fetchOrders();
    _fetchWallet();

    NotificationService().registerDeviceToken(ref.read(dioProvider), role: 'DELIVERY');

    // Immediately request GPS / Location permission as soon as Rider opens dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RiderLocationService.requestPermissions();
      BatteryOptimizationDialog.showIfNecessary(context);
    });

    // 30-second calm background refresh (without 1-second full-screen rebuilds)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isFetchingOrders) return;
      _fetchOrders(silent: true);
      _fetchWallet();
    });
  }

  void _initOrdersRealtime() {
    try {
      _ordersRealtimeChannel = SupabaseService.subscribeToAllOrdersRealtime(
        onOrderChange: (record) {
          if (!mounted) return;
          final orderId = record['id']?.toString() ?? '';
          final newStatus = record['status']?.toString() ?? '';
          debugPrint('[DeliveryDashboard] Realtime order change detected: order=$orderId status=$newStatus');
          _fetchOrders(silent: true);
        },
      );
    } catch (e) {
      debugPrint('[DeliveryDashboard] Realtime order subscription error: $e');
    }
  }

  void _initConnectivityAndOfflineQueue() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (mounted) {
        final wasOffline = _isDeviceOffline;
        setState(() => _isDeviceOffline = isOffline);
        if (wasOffline && !isOffline) {
          _flushOfflineQueue();
        }
      }
    });
  }

  Future<void> _loadPersistedOfflineCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_delivery_orders_json');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted && _orders.isEmpty && list.isNotEmpty) {
          setState(() {
            _orders = list;
            _isLoading = false;
          });
        }
      }
      final pending = await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery);
      if (mounted) {
        setState(() => _pendingSyncCount = pending);
      }
      if (!_isDeviceOffline && pending > 0) {
        _flushOfflineQueue();
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] _loadPersistedOfflineCache error: $e');
    }
  }

  Future<void> _savePersistedOrders(List<Map<String, dynamic>> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitized = orders.map((o) => Map<String, dynamic>.from(o)).toList();
      await prefs.setString('cached_delivery_orders_json', jsonEncode(sanitized));
      _cachedDeliveryOrders = orders;
    } catch (e) {
      debugPrint('[DeliveryDashboard] _savePersistedOrders error: $e');
    }
  }

  Future<void> _flushOfflineQueue() async {
    try {
      final pendingBefore = await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery);
      if (pendingBefore == 0) return;

      final dio = ref.read(dioProvider);

      final syncedCount = await OfflineSyncService.flushQueue(
        OfflineSyncService.queueDelivery,
        (actionItem) async {
          final payload = actionItem['payload'] is Map
              ? Map<String, dynamic>.from(actionItem['payload'] as Map)
              : <String, dynamic>{};
          final orderId = payload['orderId']?.toString();
          final newStatus = payload['newStatus']?.toString();
          final extra = payload['extra'] is Map ? Map<String, dynamic>.from(payload['extra']) : null;
          final userId = payload['userId']?.toString() ?? _currentUserId ?? 'delivery_1';

          if (orderId == null || newStatus == null) return true;

          final response = await dio.patch(
            '/api/orders/$orderId',
            data: {
              'status': newStatus,
              'deliveryUserId': userId,
              if (newStatus == 'DELIVERED') 'paymentStatus': 'PAID',
              if (extra != null) ...extra,
            },
            options: Options(
              headers: {
                'x-user-id': userId,
                'x-user-role': 'DELIVERY',
              },
            ),
          );

          return response.statusCode == 200 || response.statusCode == 204;
        },
      );

      final pendingAfter = await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery);
      if (mounted) {
        setState(() => _pendingSyncCount = pendingAfter);
      }

      if (syncedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  '✅ $syncedCount offline action(s) synced to server!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        );
        _fetchOrders(silent: true);
        _fetchWallet();
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Offline queue flush error: $e');
    }
  }

  /// Hydrates RestaurantRegistry dynamically from Supabase & API
  Future<void> _hydrateRestaurants() async {
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        final List<dynamic> data = await sb.from('restaurants').select('*');
        final list = data
            .map((json) => Restaurant.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        if (list.isNotEmpty) {
          RestaurantRegistry.registerAll(list);
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] hydrateRestaurants Supabase error: $e');
    }

    try {
      final repo = RestaurantRepository(ref.read(dioProvider));
      final list = await repo.getRestaurants(forceRefresh: true);
      if (list.isNotEmpty && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] hydrateRestaurants REST error: $e');
    }
  }

  Future<void> _enqueueOfflineAction(String orderId, String newStatus, Map<String, dynamic>? extra) async {
    try {
      await OfflineSyncService.enqueueAction(
        queueName: OfflineSyncService.queueDelivery,
        action: 'UPDATE_STATUS',
        payload: {
          'orderId': orderId,
          'newStatus': newStatus,
          'extra': extra,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final pending = await OfflineSyncService.getPendingCount(OfflineSyncService.queueDelivery);
      if (mounted) {
        setState(() => _pendingSyncCount = pending);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Mode: Action saved locally. Will auto-sync when online ($pending pending).',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: Responsive.scaledFontSize(context, 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Enqueue offline action error: $e');
    }
  }

  void _checkAndTriggerNewOrderAlert(List<Map<String, dynamic>> ordersList) {
    final pending = ordersList.where((o) {
      if (!['CONFIRMED', 'PREPARING', 'PACKED', 'PENDING'].contains(o['status'])) return false;
      if (_isSelfPickupOrder(o)) return false;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        final dId = o['deliveryUserId']?.toString();
        if (dId != null && dId.isNotEmpty && dId != _currentUserId) return false;
      }
      return true;
    }).toList();
    if (pending.isEmpty) return;

    final currentIds = pending.map((o) => o['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

    if (_knownOrderIds.isNotEmpty) {
      final newIds = currentIds.difference(_knownOrderIds);
      if (newIds.isNotEmpty) {
        final newOrder = pending.firstWhere((o) => newIds.contains(o['id']?.toString()), orElse: () => pending.first);
        _playNewOrderSoundAndAlert(newOrder);
      }
    }
    _knownOrderIds.addAll(currentIds);
  }

  Future<void> _playNewOrderSoundAndAlert(Map<String, dynamic> newOrder) async {
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();

      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(
          AssetSource('sounds/order_chime.mp3'),
          volume: 1.0,
        );
      } catch (e) {
        LoggerService.error('DeliveryDashboard: silent catch', e);
        await SystemSound.play(SystemSoundType.alert);
      }

      if (mounted) {
        final orderNum = newOrder['readableId'] ?? 'Order';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignSystem.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🛵 Naya Order Aaya! #$orderNum',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: Responsive.scaledFontSize(context, 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Audio alert error: $e');
    }
  }

  void _toggleDarkMode() async {
    HapticFeedback.mediumImpact();
    final updated = !_isDarkMode;
    setState(() => _isDarkMode = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rider_dark_mode', updated);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    if (_ordersRealtimeChannel != null) {
      SupabaseService.unsubscribe(_ordersRealtimeChannel);
    }
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDark = prefs.getBool('rider_dark_mode') ?? false;
    if (mounted) {
      setState(() => _isDarkMode = savedDark);
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null && currentUser.name != null && currentUser.name!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userName = currentUser.name!.split(' ').first;
          _currentUserId = currentUser.id;
        });
      }
      return;
    }

    final rawUser = prefs.getString('user_data');
    if (rawUser != null) {
      try {
        final decoded = jsonDecode(rawUser);
        final name = decoded['name'] ?? decoded['fullName'] ?? decoded['user_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          if (mounted) setState(() => _userName = name.toString().trim().split(' ').first);
        }
        if (decoded['id'] != null) {
          _currentUserId = decoded['id'].toString();
        }
      } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
    } else {
      final name = prefs.getString('user_name');
      if (name != null && name.trim().isNotEmpty) {
        if (mounted) setState(() => _userName = name.trim().split(' ').first);
      }
    }
    if (mounted) {
      setState(() {
        _currentUserId ??= prefs.getString('user_id') ?? prefs.getString('delivery_user_id');
        _assignedStoreId ??= prefs.getString('rider_store_id');
        _assignedStoreName ??= prefs.getString('rider_store_name');
      });
    }
  }

  bool _isSelfPickupOrder(Map<String, dynamic> o) {
    final method = (o['deliveryMethod'] ?? '').toString().toUpperCase().trim();
    final addressId = (o['addressId'] ?? '').toString().trim();
    final orderType = (o['orderType'] ?? '').toString().toUpperCase().trim();
    final notes = (o['notes'] ?? '').toString().toUpperCase().trim();

    return method == 'PICKUP' ||
        method == 'SELF_PICKUP' ||
        method == 'TAKEAWAY' ||
        method == 'STORE_PICKUP' ||
        addressId == 'STORE_PICKUP' ||
        orderType == 'PICKUP' ||
        orderType == 'SELF_PICKUP' ||
        orderType == 'TAKEAWAY' ||
        notes.contains('SELF PICKUP') ||
        notes.contains('STORE PICKUP');
  }

  /// Fetch 100% Real Live Orders from Database
  Future<void> _fetchOrders({bool silent = false}) async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        List<dynamic> data;
        try {
          var query = sb
              .from('orders')
              .select('*, order_items(*), addresses(*), restaurant:restaurants(*), user:users!orders_userId_fkey(name,phone)');
          
          if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty) {
            query = query.or('storeId.eq.$_assignedStoreId,storeId.is.null');
          }

          data = await query
              .order('createdAt', ascending: false)
              .limit(50);
        } catch (queryErr) {
          debugPrint('[DeliveryDashboard] Supabase orders with restaurant join failed: $queryErr');
          var fallbackQuery = sb
              .from('orders')
              .select('*, order_items(*), addresses(*), user:users!orders_userId_fkey(name,phone)');
          if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty) {
            fallbackQuery = fallbackQuery.or('storeId.eq.$_assignedStoreId,storeId.is.null');
          }
          data = await fallbackQuery
              .order('createdAt', ascending: false)
              .limit(50);
        }

        final parsed = data
            .map((o) {
              final map = Map<String, dynamic>.from(o as Map);
              final rawItems = (map['order_items'] as List<dynamic>?) ?? [];
              map['items'] = rawItems.map((it) {
                if (it is Map) {
                  final itMap = Map<String, dynamic>.from(it);
                  final resolved = OrderItemHelper.resolveImageUrl(itMap);
                  if (resolved.isNotEmpty) {
                    itMap['imageUrl'] ??= resolved;
                    itMap['image'] ??= resolved;
                  }
                  return itMap;
                }
                return it;
              }).toList();
              map['address'] = map['addresses'];
              if (map['restaurant'] != null && map['restaurant'] is Map) {
                try {
                  final r = Restaurant.fromJson(Map<String, dynamic>.from(map['restaurant'] as Map));
                  RestaurantRegistry.register(r);
                } catch (_) {}
              }
              return map;
            })
            .where((o) => !_isSelfPickupOrder(o))
            .toList();

        if (parsed.isNotEmpty && mounted) {
          final merged = _mergeCombinedOrders(parsed);
          setState(() {
            _orders = merged;
            _isLoading = false;
          });

          _savePersistedOrders(merged);
          _checkAndTriggerNewOrderAlert(merged);
          _manageGpsTrackingLifecycle(merged);
          _calculateWalletFromOrders(parsed); // wallet uses un-merged for accurate per-order COD total
          _isFetchingOrders = false;
          return;
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Supabase direct query: $e');
    }

    // Fallback to Dio REST API
    try {
      final dio = ref.read(dioProvider);
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      final userId = prefs.getString('user_id') ?? '';

      final response = await dio.get(
        '/api/delivery/orders',
        queryParameters: {
          if (userId.isNotEmpty) 'userId': userId,
          if (phone.isNotEmpty) 'phone': phone,
          if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty) 'storeId': _assignedStoreId,
        },
        options: Options(
          headers: {
            'x-user-id': userId.isNotEmpty ? userId : 'delivery_1',
            'x-user-role': 'DELIVERY',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data is List ? response.data : (response.data['orders'] ?? []);
        final parsed = list
            .map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              if (map['items'] is List) {
                final rawItems = map['items'] as List<dynamic>;
                map['items'] = rawItems.map((it) {
                  if (it is Map) {
                    final itMap = Map<String, dynamic>.from(it);
                    final resolved = OrderItemHelper.resolveImageUrl(itMap);
                    if (resolved.isNotEmpty) {
                      itMap['imageUrl'] ??= resolved;
                      itMap['image'] ??= resolved;
                    }
                    return itMap;
                  }
                  return it;
                }).toList();
              }
              if (map['restaurant'] != null && map['restaurant'] is Map) {
                try {
                  final r = Restaurant.fromJson(Map<String, dynamic>.from(map['restaurant'] as Map));
                  RestaurantRegistry.register(r);
                } catch (_) {}
              }
              return map;
            })
            .where((o) => !_isSelfPickupOrder(o))
            .toList();
        final merged = _mergeCombinedOrders(parsed);

        if (mounted) {
          setState(() {
            _orders = merged;
            _isLoading = false;
          });

          _savePersistedOrders(merged);
          _checkAndTriggerNewOrderAlert(merged);
          _manageGpsTrackingLifecycle(merged);
          _calculateWalletFromOrders(parsed);
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] REST fetch error: $e');
    } finally {
      _isFetchingOrders = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Merge sub-orders that share a combinedId into one combined order card.
  /// Solo orders (no combinedId) pass through unchanged.
  List<Map<String, dynamic>> _mergeCombinedOrders(List<Map<String, dynamic>> orders) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<Map<String, dynamic>> soloOrders = [];

    for (final o in orders) {
      final cid = o['combinedId']?.toString();
      if (cid != null && cid.trim().isNotEmpty) {
        groups.putIfAbsent(cid, () => []).add(o);
      } else {
        soloOrders.add(o);
      }
    }

    final List<Map<String, dynamic>> result = [...soloOrders];

    for (final entry in groups.entries) {
      final subOrders = entry.value;
      if (subOrders.length == 1) {
        result.add(subOrders.first);
        continue;
      }

      // Pick the "primary" sub-order (prefer grocery -G, else first)
      final primary = subOrders.firstWhere(
        (o) => (o['readableId'] ?? '').toString().endsWith('-G'),
        orElse: () => subOrders.first,
      );

      // Merge items from all sub-orders with restaurant context preservation
      final allItems = <dynamic>[];
      for (final sub in subOrders) {
        final subRestId = sub['restaurantId']?.toString() ?? sub['restaurant_id']?.toString();
        final subShopName = sub['shopName']?.toString() ?? sub['shop_name']?.toString();
        final rawSubItems = (sub['items'] as List<dynamic>?) ?? [];
        for (final item in rawSubItems) {
          if (item is Map) {
            final itemMap = Map<String, dynamic>.from(item);
            final resolved = OrderItemHelper.resolveImageUrl(itemMap);
            if (resolved.isNotEmpty) {
              itemMap['imageUrl'] ??= resolved;
              itemMap['image'] ??= resolved;
            }
            if (subRestId != null && itemMap['restaurantId'] == null) {
              itemMap['restaurantId'] = subRestId;
            }
            if (subShopName != null && itemMap['shopName'] == null) {
              itemMap['shopName'] = subShopName;
            }
            allItems.add(itemMap);
          } else {
            allItems.add(item);
          }
        }
      }

      // Compute combined total
      final combinedTotal = subOrders.fold<double>(
        0.0, (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0.0),
      );

      // Determine combined status (lowest progress wins)
      String combinedStatus(List<String> statuses) {
        final active = statuses.where((s) => s != 'CANCELLED').toList();
        if (active.isEmpty) return 'CANCELLED';
        if (active.contains('PENDING')) return 'PENDING';
        if (active.contains('CONFIRMED')) return 'CONFIRMED';
        if (active.contains('PREPARING')) return 'PREPARING';
        if (active.contains('PACKED')) return 'PACKED';
        if (active.contains('SHIPPED')) return 'SHIPPED';
        return 'DELIVERED';
      }

      final statuses = subOrders.map((o) => (o['status'] ?? 'CONFIRMED').toString().toUpperCase()).toList();

      // Build base readableId (strip -G/-R suffix)
      final baseId = (primary['readableId'] ?? '').toString().replaceAll(RegExp(r'-[GR]\d*$', caseSensitive: false), '');

      // Determine payment:
      // An order is only PAID if ALL sub-orders have paymentStatus == 'PAID'
      final allSubOrdersPaid = subOrders.every((o) {
        final ps = (o['paymentStatus'] ?? '').toString().toUpperCase().trim();
        return ps == 'PAID';
      });

      final anyCod = subOrders.any((o) {
        final pm = (o['paymentMethod'] ?? '').toString().toUpperCase().trim();
        return pm == 'COD' || pm.isEmpty;
      });

      // Build sub-order type labels for display
      final subLabels = subOrders.map((o) {
        final rid = (o['readableId'] ?? '').toString();
        final rawRestId = o['restaurantId']?.toString() ?? o['restaurant_id']?.toString();
        final rawShopName = (o['shopName'] ?? o['shop_name'])?.toString();
        final isRest = rid.endsWith('-R') ||
            rid.contains('-R-') ||
            o['orderType'] == 'RESTAURANT' ||
            (rawRestId != null && rawRestId.isNotEmpty && rawRestId != 'null') ||
            (rawShopName != null && RestaurantRegistry.find(rawShopName) != null);
        final name = (rawShopName != null && rawShopName.isNotEmpty && rawShopName != 'FastKirana Dark Store' && rawShopName != 'FastKirana Store')
            ? rawShopName
            : (RestaurantRegistry.getName(rawRestId) ?? 'Restaurant');
        return isRest ? '🍽️ $name' : '🛒 Grocery';
      }).toList();

      final merged = Map<String, dynamic>.from(primary);
      merged['id'] = primary['id']; // keep primary id for status updates
      merged['readableId'] = baseId;
      merged['items'] = allItems;
      merged['total'] = combinedTotal;
      merged['status'] = combinedStatus(statuses);
      merged['paymentMethod'] = anyCod ? 'COD' : (primary['paymentMethod'] ?? 'UPI');
      merged['paymentStatus'] = allSubOrdersPaid ? 'PAID' : (primary['paymentStatus'] ?? 'PENDING');
      merged['isCombined'] = true;
      merged['subOrders'] = subOrders;
      merged['subOrderIds'] = subOrders.map((o) => o['id']?.toString()).where((id) => id != null).toList();
      merged['subLabels'] = subLabels;
      merged['shopName'] = subLabels.join(' + ');

      result.add(merged);
    }

    // Sort by createdAt descending
    result.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return result;
  }

  void _calculateWalletFromOrders(List<Map<String, dynamic>> ordersList) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final todayCodOrders = ordersList.where((o) {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        final dId = o['deliveryUserId']?.toString();
        if (dId != null && dId.isNotEmpty && dId != _currentUserId) return false;
      }
      final pm = (o['paymentMethod'] ?? '').toString().toUpperCase().trim();
      final isOnlinePaid = pm == 'UPI' || pm == 'ONLINE' || pm == 'RAZORPAY';
      final isCod = (pm == 'COD' || pm.isEmpty) && !isOnlinePaid;
      final isPaid = o['paymentStatus'] == 'PAID' || o['status'] == 'DELIVERED';
      final createdStr = o['createdAt']?.toString();
      final created = createdStr != null ? DateTime.tryParse(createdStr) : null;
      final isToday = created != null && created.isAfter(todayStart);
      return isCod && isPaid && isToday;
    }).toList();

    final totalCash = todayCodOrders.fold<double>(0.0, (sum, o) {
      return sum + ((o['total'] as num?)?.toDouble() ?? 0.0);
    });

    setState(() {
      _walletInfo = {
        'wallet': {
          'cashInHand': totalCash,
          'cashLimit': 10000.0,
          'isLocked': totalCash >= 10000.0,
          'isWarning': totalCash >= 7500.0,
        },
        'todayCodOrders': todayCodOrders,
      };
    });
  }

  Future<void> _fetchWallet() async {
    try {
      final dio = ref.read(dioProvider);
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      final userId = prefs.getString('user_id') ?? '';

      final response = await dio.get(
        '/api/delivery/wallet',
        queryParameters: {
          if (userId.isNotEmpty) 'userId': userId,
          if (phone.isNotEmpty) 'phone': phone,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _walletInfo = Map<String, dynamic>.from(response.data);
            final rider = response.data['rider'];
            if (rider is Map && rider['name'] != null) {
              final rName = rider['name'].toString().trim();
              if (rName.isNotEmpty && rName != 'Partner') {
                _userName = rName.split(' ').first;
              }
            }
            if (rider is Map && rider['id'] != null) {
              _currentUserId ??= rider['id'].toString();
            }
            if (rider is Map) {
              if (rider['assignedStoreId'] != null && rider['assignedStoreId'].toString().isNotEmpty) {
                _assignedStoreId = rider['assignedStoreId'].toString();
                prefs.setString('rider_store_id', _assignedStoreId!);
              }
              final sName = rider['storeName'] ?? rider['assignedStoreName'];
              if (sName != null && sName.toString().isNotEmpty) {
                _assignedStoreName = sName.toString();
                prefs.setString('rider_store_name', _assignedStoreName!);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Fetch wallet error: $e');
    }
  }

  void _manageGpsTrackingLifecycle(List<Map<String, dynamic>> ordersList) {
    final activeShipped = ordersList.where((o) {
      if (o['status'] != 'SHIPPED') return false;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        final dId = o['deliveryUserId']?.toString();
        return dId == null || dId == _currentUserId;
      }
      return true;
    }).toList();

    if (activeShipped.isNotEmpty && _isOnline) {
      final activeOrder = activeShipped.first;
      final orderId = activeOrder['id']?.toString() ?? '';
      final readableId = activeOrder['readableId']?.toString();
      final relatedIds = (activeOrder['subOrderIds'] is List)
          ? (activeOrder['subOrderIds'] as List).map((e) => e.toString()).toList()
          : <String>[];
      final riderId = _currentUserId ?? 'rider_current';

      if (!_locationService.isTracking || _locationService.activeOrderId != orderId) {
        _locationService.startTracking(
          orderId: orderId,
          readableId: readableId,
          relatedOrderIds: relatedIds,
          riderId: riderId,
          dioClient: ref.read(dioProvider),
        );
      }
    } else {
      if (_locationService.isTracking) {
        _locationService.stopTracking();
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, {Map<String, dynamic>? extra}) async {
    setState(() => _updatingOrderId = orderId);
    HapticFeedback.mediumImpact();

    // 1. Instant offline handling (0ms lag in elevator/basement)
    if (_isDeviceOffline) {
      setState(() {
        for (final o in _orders) {
          if (o['id'] == orderId || (o['subOrderIds'] is List && (o['subOrderIds'] as List).contains(orderId))) {
            o['status'] = newStatus;
          }
        }
      });
      _savePersistedOrders(_orders);
      await _enqueueOfflineAction(orderId, newStatus, extra);
      if (mounted) setState(() => _updatingOrderId = null);
      return;
    }

    try {
      final dio = ref.read(dioProvider);

      // Find the order to determine if COD and if combined
      Map<String, dynamic>? matchingOrder;
      for (final o in _orders) {
        if (o['id'] == orderId || o['readableId'] == orderId) {
          matchingOrder = o;
          break;
        }
        if (o['subOrderIds'] is List && (o['subOrderIds'] as List).contains(orderId)) {
          matchingOrder = o;
          break;
        }
      }
      final safeOrder = matchingOrder ?? <String, dynamic>{};
      final isCod = safeOrder['paymentMethod'] == 'COD';
      final isCombined = safeOrder['isCombined'] == true;
      final subOrderIds = (safeOrder['subOrderIds'] as List<dynamic>?)?.cast<String>() ?? [];

      // Build the list of order IDs to update
      final partnerId = extra?['partnerOrderId']?.toString();
      final idsToUpdate = isCombined && subOrderIds.isNotEmpty
          ? subOrderIds
          : ((partnerId != null && partnerId.isNotEmpty && partnerId != orderId) ? [orderId, partnerId] : [orderId]);

      bool anySuccess = false;

      // Smart Batch API optimization for FastKirana FastAPI
      if (extra?['isBatch'] == true && idsToUpdate.length > 1 && newStatus == 'SHIPPED') {
        try {
          final bRes = await dio.post('/api/delivery/batch/accept', data: {'orderIds': idsToUpdate});
          if (bRes.statusCode == 200) {
            anySuccess = true;
          }
        } catch (_) {}
      }

      for (int i = 0; i < idsToUpdate.length; i++) {
        final currentId = idsToUpdate[i];

        // For COD combined orders, only send cashAmount on the first sub-order to avoid double-counting in wallet
        final isFirstSub = i == 0;

        // Find the individual sub-order total for accurate wallet
        double subTotal = (safeOrder['total'] as num?)?.toDouble() ?? 0.0;
        bool subIsCod = isCod;

        if (isCombined && safeOrder['subOrders'] is List) {
          for (final s in (safeOrder['subOrders'] as List)) {
            if (s is Map && s['id']?.toString() == currentId) {
              subTotal = (s['total'] as num?)?.toDouble() ?? 0.0;
              subIsCod = s['paymentMethod'] == 'COD';
              break;
            }
          }
        }

        final isOnlineExtra = extra?['paymentMethod'] == 'UPI' || extra?['paymentMethod'] == 'ONLINE' || extra?['paymentCollectedBy'] == 'ONLINE' || extra?['isRiderCash'] == false;
        final effectivePayMethod = isOnlineExtra ? 'UPI' : (subIsCod ? 'COD' : 'ONLINE');

        try {
          final response = await dio.patch(
            '/api/orders/$currentId',
            data: {
              'status': newStatus,
              if (_currentUserId != null) 'deliveryUserId': _currentUserId,
              if (newStatus == 'DELIVERED') 'paymentStatus': 'PAID',
              if (newStatus == 'DELIVERED') 'paymentMethod': effectivePayMethod,
              if (newStatus == 'DELIVERED' && subIsCod && !isOnlineExtra)
                'isRiderCash': true,
              if (newStatus == 'DELIVERED' && subIsCod && !isOnlineExtra)
                'paymentCollectedBy': 'RIDER',
              if (newStatus == 'DELIVERED' && subIsCod && !isOnlineExtra)
                'cashAmount': subTotal,
              if (newStatus == 'DELIVERED' && isOnlineExtra)
                'isRiderCash': false,
              if (newStatus == 'DELIVERED' && isOnlineExtra)
                'paymentCollectedBy': 'ONLINE',
              // Only spread extra on the first sub-order (avoid duplicate deliveryPhoto etc.)
              if (isFirstSub) ...?extra,
            },
            options: Options(
              headers: {
                'x-user-id': _currentUserId ?? 'delivery_1',
                'x-user-role': 'DELIVERY',
              },
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            anySuccess = true;
          }
        } catch (subErr) {
          debugPrint('[DeliveryDashboard] Sub-order $currentId update error: $subErr');
        }
      }

      if (anySuccess) {
        if (newStatus == 'DELIVERED') {
          _confettiController.play();
          HapticFeedback.heavyImpact();
          _locationService.stopTracking();
        } else if (newStatus == 'SHIPPED') {
          HapticFeedback.heavyImpact();
          final matching = _orders.firstWhere(
            (o) => o['id'] == orderId,
            orElse: () => <String, dynamic>{'id': orderId},
          );
          _locationService.startTracking(
            orderId: orderId,
            readableId: matching['readableId']?.toString(),
            relatedOrderIds: (matching['subOrderIds'] is List)
                ? (matching['subOrderIds'] as List).map((e) => e.toString()).toList()
                : null,
            riderId: _currentUserId ?? 'rider_current',
            dioClient: dio,
          );
        }

        // Re-fetch orders (also recalculates local wallet from order data)
        await _fetchOrders(silent: true);
        // Fetch authoritative wallet from server (RiderWallet table) — this is the source of truth
        await _fetchWallet();
      } else {
        // Enqueue offline action and optimistically update local UI
        await _enqueueOfflineAction(orderId, newStatus, extra);
        setState(() {
          for (final o in _orders) {
            if (o['id'] == orderId || (o['subOrderIds'] is List && (o['subOrderIds'] as List).contains(orderId))) {
              o['status'] = newStatus;
            }
          }
        });
        _savePersistedOrders(_orders);
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Status update error: $e');
      // Save offline on network failure
      await _enqueueOfflineAction(orderId, newStatus, extra);
      setState(() {
        for (final o in _orders) {
          if (o['id'] == orderId || (o['subOrderIds'] is List && (o['subOrderIds'] as List).contains(orderId))) {
            o['status'] = newStatus;
          }
        }
      });
      _savePersistedOrders(_orders);
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  void _openGoogleMapsNavigation(double lat, double lng, String label, {String? address}) async {
    Uri uri;
    Uri fallbackUri;

    if (lat != 0.0 && lng != 0.0 && lat >= 20.0) {
      uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      final query = Uri.encodeComponent('${address?.isNotEmpty == true ? address : label}, Ghatampur, UP');
      uri = Uri.parse('google.navigation:q=$query&mode=d');
      fallbackUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Navigation launcher error: $e');
    }
  }

  void _showDoorstepUpiQrModal(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DoorstepCashfreeQrSheet(
        order: order,
        orderId: orderId,
        orderNum: orderNum.toString(),
        total: total,
        onConfirmPaid: (extra) async {
          Navigator.pop(ctx);
          await _updateOrderStatus(orderId, 'DELIVERED', extra: extra);
        },
      ),
    );
  }

  /// Modal Matching Exact WebApp Flow (Screenshots 1, 2, 3, 4)
  void _showDeliveryConfirmationModal(Map<String, dynamic> order, double lat, double lng) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final rawPayStatus = (order['paymentStatus'] ?? '').toString().toUpperCase().trim();
    final isAlreadyPaid = rawPayStatus == 'PAID';
    final isCod = !isAlreadyPaid; // If not yet PAID, rider must collect payment before delivering!
    final wallet = _walletInfo?['wallet'] ?? {};
    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 10000.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryPaymentSheet(
        order: order,
        orderNum: orderNum,
        total: total,
        isCod: isCod,
        cashInHand: cashInHand,
        cashLimit: cashLimit,
        lat: lat,
        lng: lng,
        onConfirmDelivery: (extra) async {
          Navigator.pop(ctx);
          await _updateOrderStatus(orderId, 'DELIVERED', extra: extra);
        },
        onOpenDoorstepQr: () {
          Navigator.pop(ctx);
          _showDoorstepUpiQrModal(order);
        },
      ),
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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final activeDeliveries = _orders
        .where((o) {
          if (o['status'] != 'SHIPPED' || _isSelfPickupOrder(o)) return false;
          if (_currentUserId != null && _currentUserId!.isNotEmpty) {
            final dId = o['deliveryUserId']?.toString();
            return dId == null || dId == _currentUserId;
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['shippedAt']?.toString() ?? a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['shippedAt']?.toString() ?? b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return aDate.compareTo(bDate); // Oldest picked-up on top
      });

    final pendingPickups = _orders
        .where((o) {
          if (!['CONFIRMED', 'PREPARING', 'PACKED', 'PENDING'].contains(o['status']) || _isSelfPickupOrder(o)) {
            return false;
          }
          if (_currentUserId != null && _currentUserId!.isNotEmpty) {
            final dId = o['deliveryUserId']?.toString();
            if (dId != null && dId.isNotEmpty && dId != _currentUserId) {
              return false;
            }
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return aDate.compareTo(bDate); // Oldest order on top (FIFO)
      });

    final completedToday = _orders.where((o) {
      if (o['status'] != 'DELIVERED' || _isSelfPickupOrder(o)) return false;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        final dId = o['deliveryUserId']?.toString();
        if (dId != null && dId.isNotEmpty && dId != _currentUserId) {
          return false;
        }
      }
      final dateStr = o['deliveredAt'] ?? o['createdAt'];
      if (dateStr == null) return false;
      final dt = DateTime.tryParse(dateStr.toString())?.toLocal();
      if (dt == null) return false;
      return dt.isAfter(todayStart) || dt.isAtSameMomentAs(todayStart);
    }).toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['deliveredAt']?.toString() ?? a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['deliveredAt']?.toString() ?? b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate); // Most recently completed on top
      });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: bgMain,
        body: Stack(
          children: [
            Column(
              children: [
                if (_isDeviceOffline || _pendingSyncCount > 0)
                  SafeArea(
                    bottom: false,
                    child: ConnectivityBanner(
                      isOffline: _isDeviceOffline,
                      pendingCount: _pendingSyncCount,
                      onRetry: () {
                        if (!_isDeviceOffline) {
                          _flushOfflineQueue();
                        }
                      },
                    ),
                  ),

                DeliveryHeader(
                  isOnline: _isOnline,
                  isDarkMode: _isDarkMode,
                  userName: _userName,
                  storeName: _assignedStoreName,
                  refreshCountdown: _refreshCountdown,
                  activeTab: _activeTab,
                  onBack: _handleBackPress,
                  onToggleOnline: () {
                    setState(() => _isOnline = !_isOnline);
                    if (!_isOnline) {
                      _locationService.stopTracking();
                    } else {
                      _manageGpsTrackingLifecycle(_orders);
                    }
                  },
                  onToggleDarkMode: _toggleDarkMode,
                  onRefresh: () async {
                    if (!_isDeviceOffline) {
                      await _flushOfflineQueue();
                    }
                    await _fetchOrders(silent: true);
                    await _fetchWallet();
                  },
                  onLogout: () async {
                    final confirm = await AppConfirmationDialog.showLogout(
                      context: context,
                      title: 'Log Out of Rider Console?',
                      subtitle: 'Are you sure you want to log out from Rider Console?',
                      accountNote: 'Your active shift and completed deliveries will remain saved.',
                      confirmLabel: 'Log Out',
                    );
                    if (confirm == true && context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      unawaited(ref.read(authProvider.notifier).logout());
                    }
                  },
                  onTabChanged: (index) => setState(() => _activeTab = index),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppDesignSystem.success))
                      : IndexedStack(
                          index: _activeTab,
                          children: [
                            DeliveryOrdersTab(
                              activeDeliveries: activeDeliveries,
                              pendingPickups: pendingPickups,
                              updatingOrderId: _updatingOrderId,
                              onOpenNavigation: _openGoogleMapsNavigation,
                              onShowDoorstepQr: _showDoorstepUpiQrModal,
                              onShowConfirmation: _showDeliveryConfirmationModal,
                              onUpdateStatus: _updateOrderStatus,
                            ),
                            DeliveryWalletTab(
                              walletInfo: _walletInfo,
                              isOnline: _isOnline,
                              onToggleOnline: (val) {
                                setState(() => _isOnline = val);
                                if (!val) {
                                  _locationService.stopTracking();
                                } else {
                                  _manageGpsTrackingLifecycle(_orders);
                                }
                              },
                            ),
                            DeliveryHistoryTab(completed: completedToday),
                          ],
                        ),
                ),
              ],
            ),

            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [AppDesignSystem.green700, AppDesignSystem.primary, AppDesignSystem.blue600, AppDesignSystem.warning],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



