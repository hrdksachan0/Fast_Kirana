import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/rider_location_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../providers/auth_provider.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/delivery_header.dart';

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
  bool _isRefreshing = false;
  int _activeTab = 0; // 0: Deliveries, 1: Cash Wallet, 2: History

  List<Map<String, dynamic>> _orders = _cachedDeliveryOrders;

  static const String _diskDeliveryOrdersKey = 'cached_delivery_orders_v2';

  Future<void> _loadDiskDeliveryOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskDeliveryOrdersKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (list.isNotEmpty && _orders.isEmpty) {
          _cachedDeliveryOrders = list;
          setState(() {
            _orders = list;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] disk load error: $e');
    }
  }

  Future<void> _saveDiskDeliveryOrders(List<Map<String, dynamic>> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = orders.take(50).toList();
      await prefs.setString(_diskDeliveryOrdersKey, jsonEncode(toSave));
    } catch (e) {
      debugPrint('[DeliveryDashboard] disk save error: $e');
    }
  }
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

  // Dynamic Theme Colors (Supporting AMOLED Dark Mode & Light Mode)
  Color get bgMain => _isDarkMode ? AppDesignSystem.darkNavy : AppDesignSystem.slate50;
  Color get cardBg => _isDarkMode ? AppDesignSystem.darkNavyCard : Colors.white;
  Color get cardSubtle => _isDarkMode ? AppDesignSystem.darkNavySubtle : AppDesignSystem.slate50;
  Color get borderCol => _isDarkMode ? AppDesignSystem.darkNavyBorder : AppDesignSystem.slate200;
  Color get textMain => _isDarkMode ? AppDesignSystem.slate100 : AppDesignSystem.slate900;
  Color get textMuted => _isDarkMode ? AppDesignSystem.slate400 : AppDesignSystem.slate500;

  static const Color emeraldGreen = AppDesignSystem.emeraldBrand;
  static const Color emeraldDark = AppDesignSystem.emeraldDark;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;

  bool _isFetchingOrders = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _loadUserInfo();
    _initConnectivityAndOfflineQueue();
    _fetchOrders();
    _fetchWallet();

    // Immediately request GPS / Location permission as soon as Rider opens dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RiderLocationService.requestPermissions();
    });

    // 30-second calm background refresh (without 1-second full-screen rebuilds)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isFetchingOrders) return;
      _fetchOrders(silent: true);
      _fetchWallet();
    });
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

  Future<void> _flushOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_delivery_queue');
      if (queueJson == null || queueJson.isEmpty) return;

      final List<dynamic> queue = jsonDecode(queueJson);
      if (queue.isEmpty) return;

      final dio = ref.read(dioProvider);
      int syncedCount = 0;

      for (final item in queue) {
        try {
          final orderId = item['orderId']?.toString();
          final newStatus = item['newStatus']?.toString();
          final extra = item['extra'] is Map ? Map<String, dynamic>.from(item['extra']) : null;
          if (orderId != null && newStatus != null) {
            await dio.patch(
              '/api/orders/$orderId',
              data: {
                'status': newStatus,
                if (_currentUserId != null) 'deliveryUserId': _currentUserId,
                if (newStatus == 'DELIVERED') 'paymentStatus': 'PAID',
                if (extra != null) ...extra,
              },
              options: Options(
                headers: {
                  'x-user-id': _currentUserId ?? 'delivery_1',
                  'x-user-role': 'DELIVERY',
                },
              ),
            );
            syncedCount++;
          }
        } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
      }

      await prefs.remove('offline_delivery_queue');

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
                Text('✅ $syncedCount offline action(s) synced to server!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
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

  Future<void> _enqueueOfflineAction(String orderId, String newStatus, Map<String, dynamic>? extra) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_delivery_queue');
      final List<dynamic> queue = queueJson != null ? jsonDecode(queueJson) : [];
      queue.add({
        'orderId': orderId,
        'newStatus': newStatus,
        'extra': extra,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString('offline_delivery_queue', jsonEncode(queue));

      if (mounted) {
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
                  child: Text('Network offline! Action saved locally. Will auto-sync when online.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: Responsive.scaledFontSize(context, 12))),
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
    final pending = ordersList.where((o) => ['CONFIRMED', 'PREPARING', 'PACKED', 'PENDING'].contains(o['status'])).toList();
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
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        var query = sb
            .from('orders')
            .select('*, order_items(*), addresses(*), user:users!orders_userId_fkey(name,phone)');
        
        if (_assignedStoreId != null && _assignedStoreId!.isNotEmpty) {
          query = query.or('storeId.eq.$_assignedStoreId,storeId.is.null');
        }

        final List<dynamic> data = await query
            .order('createdAt', ascending: false)
            .limit(50);

        final parsed = data
            .map((o) {
              final map = Map<String, dynamic>.from(o);
              map['items'] = (map['order_items'] as List<dynamic>?) ?? [];
              map['address'] = map['addresses'];
              return map;
            })
            .where((o) => !_isSelfPickupOrder(o))
            .toList();

        final merged = _mergeCombinedOrders(parsed);

        if (mounted) {
          setState(() {
            _orders = merged;
            _isLoading = false;
            _isRefreshing = false;
          });

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
            .map((e) => Map<String, dynamic>.from(e))
            .where((o) => !_isSelfPickupOrder(o))
            .toList();
        final merged = _mergeCombinedOrders(parsed);

        if (mounted) {
          setState(() {
            _orders = merged;
            _isLoading = false;
            _isRefreshing = false;
          });

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
          _isRefreshing = false;
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

      // Merge items from all sub-orders
      final allItems = <dynamic>[];
      for (final sub in subOrders) {
        allItems.addAll((sub['items'] as List<dynamic>?) ?? []);
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

      // Determine payment: if ANY sub is COD, the combined is COD
      final anyCod = subOrders.any((o) => o['paymentMethod'] == 'COD');

      // Build sub-order type labels for display
      final subLabels = subOrders.map((o) {
        final rid = (o['readableId'] ?? '').toString();
        final isRest = rid.endsWith('-R') || o['orderType'] == 'RESTAURANT' || o['restaurantId'] != null;
        return isRest ? '🍽️ Restaurant' : '🛒 Grocery';
      }).toList();

      final merged = Map<String, dynamic>.from(primary);
      merged['id'] = primary['id']; // keep primary id for status updates
      merged['readableId'] = baseId;
      merged['items'] = allItems;
      merged['total'] = combinedTotal;
      merged['status'] = combinedStatus(statuses);
      merged['paymentMethod'] = anyCod ? 'COD' : (primary['paymentMethod'] ?? 'ONLINE');
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
      final isCod = o['paymentMethod'] == 'COD';
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
    final activeShipped = ordersList.where((o) => o['status'] == 'SHIPPED').toList();

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
      final idsToUpdate = isCombined && subOrderIds.isNotEmpty ? subOrderIds : [orderId];

      bool anySuccess = false;

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

        try {
          final response = await dio.patch(
            '/api/orders/$currentId',
            data: {
              'status': newStatus,
              if (_currentUserId != null) 'deliveryUserId': _currentUserId,
              if (newStatus == 'DELIVERED') 'paymentStatus': 'PAID',
              if (newStatus == 'DELIVERED' && subIsCod && (extra?['paymentMethod'] != 'UPI'))
                'isRiderCash': true,
              if (newStatus == 'DELIVERED' && subIsCod && (extra?['paymentMethod'] != 'UPI'))
                'paymentCollectedBy': 'RIDER',
              if (newStatus == 'DELIVERED' && subIsCod && (extra?['paymentMethod'] != 'UPI'))
                'cashAmount': subTotal,
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
    const upiVpa = '7054470303-2@ibl';
    final payeeName = Uri.encodeComponent('FastKirana Store');
    final note = Uri.encodeComponent('Payment for Order #$orderNum');
    final amount = total.toStringAsFixed(2);
    final upiUri = 'upi://pay?pa=$upiVpa&pn=$payeeName&am=$amount&cu=INR&tn=$note';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiUri)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: slateBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doorstep UPI QR Collection',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark)),
                    Text('Order #$orderNum • ₹${total.toInt()}',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateMuted)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: slateDark),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: slateBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: qrUrl,
                      width: 220,
                      height: 220,
                      placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: brandGreen)),
                      errorWidget: (c, u, e) => const Icon(Icons.qr_code_2_rounded, size: 100, color: slateMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Scan via Google Pay, PhonePe, Paytm or any UPI App',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: slateMuted),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateOrderStatus(orderId, 'DELIVERED', extra: {
                  'paymentMethod': 'UPI',
                  'paymentStatus': 'PAID',
                  'notes': 'Paid via Doorstep QR scan',
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandGreen,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Confirm Customer Paid ₹${total.toInt()} via QR',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal Matching Exact WebApp Flow (Screenshots 1, 2, 3, 4)
  void _showDeliveryConfirmationModal(Map<String, dynamic> order, double lat, double lng) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final isCod = order['paymentMethod'] == 'COD';
    final wallet = _walletInfo?['wallet'] ?? {};
    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 10000.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeliveryPaymentSheet(
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
        .where((o) => o['status'] == 'SHIPPED' && !_isSelfPickupOrder(o))
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['shippedAt']?.toString() ?? a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['shippedAt']?.toString() ?? b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return aDate.compareTo(bDate); // Oldest picked-up on top
      });

    final pendingPickups = _orders
        .where((o) => ['CONFIRMED', 'PREPARING', 'PACKED', 'PENDING'].contains(o['status']) && !_isSelfPickupOrder(o))
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return aDate.compareTo(bDate); // Oldest order on top (FIFO)
      });

    final completedToday = _orders.where((o) {
      if (o['status'] != 'DELIVERED' || _isSelfPickupOrder(o)) return false;
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
                if (_isDeviceOffline)
                  const SafeArea(
                    bottom: false,
                    child: ConnectivityBanner(),
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
                  onRefresh: () => _fetchOrders(silent: true),
                  onLogout: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to log out from Rider Console?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.red600),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
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
                            _buildDeliveriesTab(activeDeliveries, pendingPickups),
                            _buildWalletTab(),
                            _buildHistoryTab(completedToday),
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

  /// Tab 0: Deliveries
  Widget _buildDeliveriesTab(List<Map<String, dynamic>> activeDeliveries, List<Map<String, dynamic>> pendingPickups) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: OUT FOR DELIVERY
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppDesignSystem.emeraldBrand,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.two_wheeler_rounded, size: 14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'OUT FOR DELIVERY',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeDeliveries.isEmpty)
            _buildEmptyOutForDeliveryCard()
          else
            ...activeDeliveries.map((o) => _buildActiveDeliveryCard(o)),

          const SizedBox(height: 22),

          // Section 2: READY FOR PICKUP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.violet600,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.inventory_2_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'READY FOR PICKUP',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignSystem.violet200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pendingPickups.length} Orders',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.violet600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (pendingPickups.isEmpty)
            _buildEmptyPendingPickupCard()
          else
            ...pendingPickups.map((o) => _buildPickupCard(o)),
        ],
      ),
    );
  }

  Widget _buildEmptyOutForDeliveryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 32))),
          const SizedBox(height: 10),
          Text(
            'No orders out for delivery',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 14),
              fontWeight: FontWeight.w900,
              color: slateDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Accept new pickup orders from below to start delivering.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w500,
              color: slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPendingPickupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
      ),
      child: Center(
        child: Text(
          'No pickup orders waiting at store right now.',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Pickup Order Card (Matching Screenshot 1)
  Widget _buildPickupCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final isFood = (order['orderType'] == 'RESTAURANT') || (order['restaurantId'] != null) || orderNum.contains('-R');
    final outlet = getOutletLocation(
      restaurantId: order['restaurantId']?.toString(),
      shopName: order['shopName']?.toString(),
      orderType: order['orderType']?.toString(),
      rawOrder: order,
    );
    final shopName = outlet.name;
    final status = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final customer = order['user'] is Map ? order['user'] : {'name': 'Customer', 'phone': null};
    final address = order['address'] is Map ? order['address'] : null;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final rawPayMethod = (order['paymentMethod'] ?? '').toString().toUpperCase().trim();
    final rawPayStatus = (order['paymentStatus'] ?? '').toString().toUpperCase().trim();
    final isOnlineMethod = rawPayMethod == 'UPI' || rawPayMethod == 'ONLINE' || rawPayMethod == 'RAZORPAY' || rawPayMethod == 'CARD' || rawPayMethod == 'WALLET';
    final isPaid = rawPayStatus == 'PAID' || (isOnlineMethod && rawPayMethod != 'COD');
    final isCod = !isPaid && (rawPayMethod == 'COD' || rawPayMethod.isEmpty);
    final items = (order['items'] as List<dynamic>?) ?? [];
    final lat = (address?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng = (address?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
    final isUpdating = _updatingOrderId == orderId;

    final customerName = (address?['name']?.toString().trim().isNotEmpty == true)
        ? address!['name'].toString().trim()
        : (customer['name']?.toString() ?? 'Customer');
    final customerPhone = (address?['phone']?.toString().trim().isNotEmpty == true)
        ? address!['phone'].toString().trim()
        : (customer['phone']?.toString().trim() ?? '');
    final avatarLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C';

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
    }
    final orderTimeStr = DateFormat('hh:mm a').format(orderDate);

    String deliverAddress = '';
    if (address != null) {
      if (address['formattedAddress'] != null && address['formattedAddress'].toString().trim().isNotEmpty) {
        deliverAddress = address['formattedAddress'].toString().trim();
      } else {
        final parts = [
          address['houseNo'],
          address['street'],
          address['area'],
          address['landmark'],
          address['city'],
          address['pincode'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
         .map((p) => p.toString().trim())
         .toList();
        deliverAddress = parts.isNotEmpty ? parts.join(', ') : '';
      }
    }
    if (deliverAddress.isEmpty) deliverAddress = 'Ghatampur, Kanpur Nagar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFood ? AppDesignSystem.rose100 : AppDesignSystem.teal100,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Colored Highlight Line
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isFood ? AppDesignSystem.rose500 : AppDesignSystem.emeraldBrand,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order ID + FOOD pill | Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$orderNum',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        if (isFood) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusCancelled,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                const SizedBox(width: 3),
                                Text(
                                  'FOOD',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.red600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: status == 'PACKED'
                            ? AppDesignSystem.green100
                            : (status == 'PREPARING' ? AppDesignSystem.statusPending : AppDesignSystem.blue50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'PACKED'
                              ? AppDesignSystem.emerald200
                              : (status == 'PREPARING' ? AppDesignSystem.yellow200 : AppDesignSystem.blue200),
                        ),
                      ),
                      child: Text(
                        status == 'PACKED' ? 'PACKED • READY' : status,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: status == 'PACKED'
                              ? AppDesignSystem.green700
                              : (status == 'PREPARING' ? AppDesignSystem.amber700 : AppDesignSystem.blue700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: outlet.isRestaurant ? AppDesignSystem.violet50 : AppDesignSystem.green50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: outlet.isRestaurant ? AppDesignSystem.violet200 : AppDesignSystem.green200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(outlet.isRestaurant ? '🍽️' : '🏪', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outlet.name,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w800,
                                color: outlet.isRestaurant ? AppDesignSystem.statusShippedText : AppDesignSystem.green800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              outlet.address,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), color: AppDesignSystem.slate500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Bounceable(
                        onTap: () => _openGoogleMapsNavigation(outlet.lat, outlet.lng, outlet.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: outlet.isRestaurant ? AppDesignSystem.violet300 : AppDesignSystem.emerald200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_rounded, size: 12, color: outlet.isRestaurant ? AppDesignSystem.violet600 : AppDesignSystem.green700),
                              const SizedBox(width: 3),
                              Text(
                                'Go Store',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: outlet.isRestaurant ? AppDesignSystem.violet600 : AppDesignSystem.green700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Customer Info Box with Order Received Time
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate100),
                  ),
                  child: Row(
                    children: [
                      // Letter Avatar
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.info,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13),
                                      fontWeight: FontWeight.w800,
                                      color: slateDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.blue50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 9, color: AppDesignSystem.blue600),
                                      const SizedBox(width: 2.5),
                                      Text(
                                        orderTimeStr,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.blue700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (customerPhone.isNotEmpty)
                              Text(
                                customerPhone.startsWith('+') ? customerPhone : '+91$customerPhone',
                                style: GoogleFonts.robotoMono(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action button: Direct Call (Google Maps is prominently available below)
                      Bounceable(
                        onTap: () {
                          if (customerPhone.isNotEmpty) {
                            launchUrl(Uri.parse('tel:$customerPhone'));
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                          ),
                          child: const Center(
                            child: Icon(Icons.phone_outlined, size: 18, color: AppDesignSystem.blue600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Pickup & Deliver Routes Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppDesignSystem.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('PICKUP: ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              shopName,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppDesignSystem.info, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('DELIVER: ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              deliverAddress,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 📍 1-Tap Turn-by-Turn Google Maps Navigation Banner
                Bounceable(
                  onTap: () => _openGoogleMapsNavigation(lat, lng, customerName, address: deliverAddress),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppDesignSystem.emerald700, AppDesignSystem.success],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Navigate in Google Maps ➔',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Items List (Clean vertical list for delivery boy to check all products)
                if (items.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.slate100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: AppDesignSystem.indigo700),
                                const SizedBox(width: 5),
                                Text(
                                  'ITEMS TO PICK UP (${items.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.indigo900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.indigo50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1))} qty',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: AppDesignSystem.indigo700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...items.map((item) {
                          final title = item['title'] ?? item['name'] ?? 'Item';
                          final qty = item['quantity'] ?? 1;
                          final price = (item['price'] as num?)?.toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.slate200),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                if (price != null && price > 0)
                                  Text(
                                    '₹${(price * (qty is num ? qty : 1)).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w800,
                                      color: slateMuted,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const Divider(height: 1, color: AppDesignSystem.slate100),
                const SizedBox(height: 10),

                // Footer: Total Value | Action Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL ORDER VALUE',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 8.5), fontWeight: FontWeight.w800, color: slateMuted),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${total.toInt()}',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCod ? AppDesignSystem.statusPending : AppDesignSystem.green100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCod ? AppDesignSystem.yellow200 : AppDesignSystem.emerald200,
                                  ),
                                ),
                                child: Text(
                                  isCod ? '💵 COD' : '✅ PAID',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w900,
                                    color: isCod ? AppDesignSystem.amber700 : AppDesignSystem.green700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(isCod ? '🔥' : '💳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  isCod ? 'Collect ₹${total.toInt()} Cash' : 'Paid Online',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: isCod ? AppDesignSystem.amber600 : AppDesignSystem.emerald600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Button
                    if (status == 'PREPARING' || status == 'CONFIRMED')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusPending,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppDesignSystem.yellow200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: AppDesignSystem.amber600),
                                const SizedBox(width: 4),
                                Text(
                                  'Preparing in Kitchen...',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.amber600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Bounceable(
                            onTap: () => _updateOrderStatus(orderId, 'SHIPPED'),
                            child: Text(
                              'Food Ready? Pick Up',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.emerald600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Bounceable(
                        onTap: isUpdating ? null : () => _updateOrderStatus(orderId, 'SHIPPED'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.indigo700,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppDesignSystem.indigo700.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUpdating)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              else ...[
                                const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  'Pick Up Order ➔',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Active Out-for-Delivery Card
  Widget _buildActiveDeliveryCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final customer = order['user'] is Map ? order['user'] : {'name': 'Customer', 'phone': null};
    final address = order['address'] is Map ? order['address'] : null;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final rawPayMethod = (order['paymentMethod'] ?? '').toString().toUpperCase().trim();
    final rawPayStatus = (order['paymentStatus'] ?? '').toString().toUpperCase().trim();
    final isOnlineMethod = rawPayMethod == 'UPI' || rawPayMethod == 'ONLINE' || rawPayMethod == 'RAZORPAY' || rawPayMethod == 'CARD' || rawPayMethod == 'WALLET';
    final isPaid = rawPayStatus == 'PAID' || (isOnlineMethod && rawPayMethod != 'COD');
    final isCod = !isPaid && (rawPayMethod == 'COD' || rawPayMethod.isEmpty);
    final items = (order['items'] as List<dynamic>?) ?? [];
    final lat = (address?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng = (address?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
    final isUpdating = _updatingOrderId == orderId;

    final customerName = (address?['name']?.toString().trim().isNotEmpty == true)
        ? address!['name'].toString().trim()
        : (customer['name']?.toString() ?? 'Customer');
    final customerPhone = (address?['phone']?.toString().trim().isNotEmpty == true)
        ? address!['phone'].toString().trim()
        : (customer['phone']?.toString().trim() ?? '');
    final avatarLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C';

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
    }
    final orderTimeStr = DateFormat('hh:mm a').format(orderDate);

    String deliverAddress = '';
    if (address != null) {
      if (address['formattedAddress'] != null && address['formattedAddress'].toString().trim().isNotEmpty) {
        deliverAddress = address['formattedAddress'].toString().trim();
      } else {
        final parts = [
          address['houseNo'],
          address['street'],
          address['area'],
          address['landmark'],
          address['city'],
          address['pincode'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
         .map((p) => p.toString().trim())
         .toList();
        deliverAddress = parts.isNotEmpty ? parts.join(', ') : '';
      }
    }
    if (deliverAddress.isEmpty) deliverAddress = 'Ghatampur, Kanpur Nagar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppDesignSystem.emerald200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.success.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ambient Green Top Strip
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.emerald600]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.green100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'STOP #1 • ACTIVE DROP',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                    ),
                    Text(
                      '#$orderNum',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: slateDark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer details with Order Time & Call Action Button
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: AppDesignSystem.info, shape: BoxShape.circle),
                        child: Center(
                          child: Text(avatarLetter,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.blue50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 9, color: AppDesignSystem.blue600),
                                      const SizedBox(width: 2.5),
                                      Text(
                                        orderTimeStr,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.blue700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (customerPhone.isNotEmpty)
                              Text(
                                customerPhone.startsWith('+') ? customerPhone : '+91 $customerPhone',
                                style: GoogleFonts.robotoMono(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Call Button
                      Bounceable(
                        onTap: () {
                          if (customerPhone.isNotEmpty) {
                            final cleanPhone = customerPhone.replaceAll(' ', '').trim();
                            launchUrl(Uri.parse('tel:$cleanPhone'));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer phone number not available')),
                            );
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                          ),
                          child: const Center(
                            child: Icon(Icons.phone_outlined, size: 18, color: AppDesignSystem.blue600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 📍 1-Tap Turn-by-Turn Google Maps Navigation Banner
                Bounceable(
                  onTap: () => _openGoogleMapsNavigation(lat, lng, customerName, address: deliverAddress),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppDesignSystem.emerald700, AppDesignSystem.success],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Navigate in Google Maps ➔',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Delivery Address Row
                if (deliverAddress.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusCancelled,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.red200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppDesignSystem.red600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            deliverAddress,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.statusCancelledText,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                // Items List (Clean vertical list for delivery boy to check all products)
                if (items.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.slate100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: AppDesignSystem.emerald600),
                                const SizedBox(width: 5),
                                Text(
                                  'ITEMS IN THIS DROP (${items.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.statusDeliveredText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.green100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1))} qty',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: AppDesignSystem.green700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...items.map((item) {
                          final title = item['title'] ?? item['name'] ?? 'Item';
                          final qty = item['quantity'] ?? 1;
                          final price = (item['price'] as num?)?.toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.slate200),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                if (price != null && price > 0)
                                  Text(
                                    '₹${(price * (qty is num ? qty : 1)).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w800,
                                      color: slateMuted,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Payment Status Highlight Strip (Crystal Clear for Rider)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCod ? AppDesignSystem.statusPending : AppDesignSystem.green100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCod ? AppDesignSystem.yellow200 : AppDesignSystem.emerald200,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(isCod ? '💵' : '💳', style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCod ? 'CASH ON DELIVERY' : 'PAID ONLINE (PREPAID)',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  color: isCod ? const Color(0xFFD97706) : AppDesignSystem.statusDeliveredText,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                isCod ? 'Collect ₹${total.toInt()} cash from customer' : '₹0 to collect • Payment already done',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: isCod ? const Color(0xFF78350F) : AppDesignSystem.statusDeliveredText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '₹${total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: isCod ? const Color(0xFF78350F) : AppDesignSystem.statusDeliveredText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons: Doorstep UPI QR + Delivered
                Row(
                  children: [
                    if (isCod) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDoorstepUpiQrModal(order),
                          icon: const Icon(Icons.qr_code_rounded, size: 16, color: AppDesignSystem.blue600),
                          label: Text('Doorstep QR',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.blue600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppDesignSystem.blue300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUpdating ? null : () => _showDeliveryConfirmationModal(order, lat, lng),
                        icon: isUpdating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isCod ? 'Collect ₹${total.toInt()} & Deliver' : 'Mark Delivered',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Cash Wallet (Matching Screenshot 2)
  Widget _buildWalletTab() {
    final wallet = _walletInfo?['wallet'] ?? {};
    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 10000.0;
    final capacityPercent = ((cashInHand / math.max(1.0, cashLimit)) * 100).clamp(0, 100).toInt();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // White Hero Card with 27% Capacity Gauge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pill Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusPending,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.yellow200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppDesignSystem.amber700),
                      const SizedBox(width: 6),
                      Text(
                        'CASH IN HAND (जेब में नकद)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.amber700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                Text(
                  '₹${cashInHand.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 38),
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 18),

                // Circular Donut Progress Arc
                CustomPaint(
                  size: const Size(130, 130),
                  painter: DonutCapacityPainter(
                    percent: capacityPercent / 100.0,
                    trackColor: AppDesignSystem.slate100,
                    progressColor: AppDesignSystem.success,
                  ),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$capacityPercent%',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 24),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'CAPACITY',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w800,
                              color: slateMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Active & Eligible Status Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.green50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.emerald200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppDesignSystem.emerald600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Active & Eligible: Full COD order capacity available.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.statusDeliveredText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🚨 On Duty / Off Duty Interactive Toggle Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isOnline ? AppDesignSystem.emerald200 : AppDesignSystem.rose200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? AppDesignSystem.success : AppDesignSystem.rose500).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _isOnline ? AppDesignSystem.green100 : AppDesignSystem.statusCancelled,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isOnline ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                            color: _isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'ON DUTY (ड्यूटी चालू)' : 'OFF DUTY (ड्यूटी बंद)',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: _isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                              ),
                            ),
                            Text(
                              _isOnline ? 'Receiving live delivery orders' : 'Orders redirected to other riders',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: _isOnline,
                        activeColor: AppDesignSystem.success,
                        activeTrackColor: AppDesignSystem.green200,
                        inactiveTrackColor: AppDesignSystem.rose200,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          setState(() => _isOnline = val);
                          if (!val) {
                            _locationService.stopTracking();
                          } else {
                            _manageGpsTrackingLifecycle(_orders);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isOnline ? AppDesignSystem.green50 : AppDesignSystem.rose50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isOnline ? AppDesignSystem.green200 : AppDesignSystem.rose200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isOnline ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: _isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isOnline
                              ? 'Aap online hain. Store se new orders aate hi aapko pickup notification milegi.'
                              : 'Off duty hone par new orders doosre active delivery partners ke paas transfer ho jayenge.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: _isOnline ? AppDesignSystem.green800 : AppDesignSystem.statusCancelledText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 2: History (100% Real Live Completed Orders)
  Widget _buildHistoryTab(List<Map<String, dynamic>> completed) {
    const dailyTarget = 5;
    final totalCount = completed.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Goal Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Gauge Ring
                CustomPaint(
                  size: const Size(64, 64),
                  painter: DonutCapacityPainter(
                    percent: math.min(1.0, totalCount / dailyTarget),
                    trackColor: AppDesignSystem.slate100,
                    progressColor: AppDesignSystem.success,
                    strokeWidth: 6,
                  ),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalCount',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 18),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                          Text(
                            '/ $dailyTarget',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w700,
                              color: slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY GOAL',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: slateMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(totalCount >= dailyTarget ? '🏆' : '🎯', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                          const SizedBox(width: 4),
                          Text(
                            totalCount >= dailyTarget ? 'Milestone Bonus Achieved!' : '$totalCount of $dailyTarget Completed',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w900,
                              color: totalCount >= dailyTarget ? AppDesignSystem.emerald600 : slateDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        totalCount >= dailyTarget ? 'Great hustle today! 🎉' : 'Complete ${dailyTarget - totalCount} more for bonus',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section Title
          Row(
            children: [
              Text(
                "TODAY'S COMPLETED DELIVERIES",
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.green700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (completed.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Center(
                child: Text(
                  'No completed deliveries recorded yet.',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...List.generate(completed.length, (idx) {
              final item = completed[idx];
              final orderId = item['id']?.toString() ?? '';
              final orderNum = item['readableId'] ?? orderId.substring(0, math.min(6, orderId.length));
              final totalAmt = (item['total'] as num?)?.toInt() ?? 0;
              final isCod = item['paymentMethod'] == 'COD';
              final userObj = item['user'] is Map ? item['user'] : null;
              final userName = userObj?['name'] ?? item['userName'] ?? 'Customer';
              final addrObj = item['address'] is Map ? item['address'] : null;
              String addr = '';
              if (addrObj != null) {
                if (addrObj['formattedAddress'] != null && addrObj['formattedAddress'].toString().trim().isNotEmpty) {
                  addr = addrObj['formattedAddress'].toString().trim();
                } else {
                  final parts = [
                    addrObj['houseNo'],
                    addrObj['street'],
                    addrObj['area'],
                    addrObj['landmark'],
                    addrObj['city'],
                    addrObj['pincode'],
                  ].where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
                   .map((p) => p.toString().trim())
                   .toList();
                  addr = parts.isNotEmpty ? parts.join(', ') : '';
                }
              }
              if (addr.isEmpty) addr = 'Ghatampur, Kanpur Nagar';
              final isLast = idx == completed.length - 1;

              String timeStr = 'Today';
              if (item['deliveredAt'] != null || item['createdAt'] != null) {
                try {
                  final dt = DateTime.parse(item['deliveredAt'] ?? item['createdAt']).toLocal();
                  timeStr = DateFormat('h:mm a').format(dt);
                } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Timeline line + dot
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 14),
                            decoration: const BoxDecoration(
                              color: AppDesignSystem.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppDesignSystem.emerald200,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '#$orderNum',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 11, color: slateMuted),
                                        const SizedBox(width: 3),
                                        Text(
                                          timeStr,
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 10.5),
                                            fontWeight: FontWeight.w600,
                                            color: slateMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '₹$totalAmt',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isCod ? AppDesignSystem.statusPending : AppDesignSystem.green100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isCod ? '💵 COD' : '💳 ONLINE',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 8.5),
                                          fontWeight: FontWeight.w900,
                                          color: isCod ? AppDesignSystem.amber700 : AppDesignSystem.green700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                      Text(
                                        addr,
                                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.green100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Delivered ✅',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.green700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Custom Donut Ring Painter for 27% Capacity Gauge
class DonutCapacityPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  DonutCapacityPainter({
    required this.percent,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Background full track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * percent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutCapacityPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Exact 1:1 Delivery Payment & Handover Modal (Matching Screenshots 1, 2, 3, 4)
class _DeliveryPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderNum;
  final double total;
  final bool isCod;
  final double cashInHand;
  final double cashLimit;
  final double lat;
  final double lng;
  final Function(Map<String, dynamic> extra) onConfirmDelivery;
  final VoidCallback onOpenDoorstepQr;

  const _DeliveryPaymentSheet({
    required this.order,
    required this.orderNum,
    required this.total,
    required this.isCod,
    required this.cashInHand,
    required this.cashLimit,
    required this.lat,
    required this.lng,
    required this.onConfirmDelivery,
    required this.onOpenDoorstepQr,
  });

  @override
  State<_DeliveryPaymentSheet> createState() => _DeliveryPaymentSheetState();
}

class _DeliveryPaymentSheetState extends State<_DeliveryPaymentSheet> {
  String _step = 'choose';
  late TextEditingController _cashReceivedController;
  late TextEditingController _cashPortionController;
  bool _hasSplitOnline = false;

  @override
  void initState() {
    super.initState();
    _cashReceivedController = TextEditingController(text: widget.total.toInt().toString());
    _cashPortionController = TextEditingController();
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _cashPortionController.dispose();
    super.dispose();
  }

  List<int> _getQuickPresets(int total) {
    final List<int> presets = [total];
    for (final r in [10, 50, 100, 500]) {
      final rounded = (total / r).ceil() * r;
      if (!presets.contains(rounded) && rounded <= total + 700) {
        presets.add(rounded);
      }
    }
    for (final note in [500, 1000, 2000]) {
      if (!presets.contains(note) && note > total && note <= total + 1500) {
        presets.add(note);
      }
    }
    return presets.take(6).toList();
  }

  List<int> _getSplitPresets(int total) {
    final List<int> presets = [];
    for (final s in [100, 200, 300, 500]) {
      if (s < total) {
        presets.add(s);
      }
    }
    return presets.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: widget.isCod ? _buildCodContent() : _buildPrepaidContent(),
    );
  }

  // 1. PREPAID HANDOVER MODAL (Screenshot 1)
  Widget _buildPrepaidContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppDesignSystem.success, AppDesignSystem.emerald600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.success.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26))),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Confirm Parcel Handover',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Order #${widget.orderNum} • ',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.emerald600),
            ),
            Text(
              '₹${widget.total.toInt()}',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: AppDesignSystem.emerald600),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppDesignSystem.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
          ),
          child: Text(
            'Kya aapne customer ko parcel safely handover kar diya hai?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600, color: AppDesignSystem.slate600, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppDesignSystem.slate200, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w800, color: AppDesignSystem.slate500)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => widget.onConfirmDelivery({
                  'deliveryLat': widget.lat,
                  'deliveryLng': widget.lng,
                  'paymentStatus': 'PAID',
                  'isRiderCash': false,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.emeraldBrand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text('Yes, Delivered ✅', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. COD MODAL (Screenshots 2, 3, 4)
  Widget _buildCodContent() {
    final orderTotalInt = widget.total.toInt();
    final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
    final changeToGive = math.max(0.0, cashReceived - widget.total);
    final cashPortion = double.tryParse(_cashPortionController.text) ?? 0.0;
    final netCashInHand = _hasSplitOnline ? cashPortion : math.min(cashReceived, widget.total);
    final onlinePortion = _hasSplitOnline ? math.max(0.0, widget.total - cashPortion) : 0.0;
    final walletAfter = widget.cashInHand + netCashInHand;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppDesignSystem.success, AppDesignSystem.emerald600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.success.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '₹',
                style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Payment Collection',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
          ),
          const SizedBox(height: 3),
          Text(
            'Order #${widget.orderNum} • Collect: ₹$orderTotalInt',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate600),
          ),
          const SizedBox(height: 16),

          // STEP 1: Choice Screen (Screenshot 2)
          if (_step == 'choose') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppDesignSystem.slate500),
                  const SizedBox(width: 8),
                  Text(
                    'Jeb mein: ₹${widget.cashInHand.toInt()}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate700),
                  ),
                  Text(
                    ' | ',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate300),
                  ),
                  Text(
                    'Limit: ₹${widget.cashLimit.toInt()}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Option 1: Cash Liya (कैश लिया)
            InkWell(
              onTap: () {
                setState(() {
                  _step = 'cash-calc';
                  _hasSplitOnline = false;
                  _cashReceivedController.text = orderTotalInt.toString();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.amber50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.yellow200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusPending,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('💵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Liya (कैश लिया)',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer ne cash diya — poora ya kuch',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: AppDesignSystem.stone500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppDesignSystem.amber600, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Online Mila (ऑनलाइन मिला)
            InkWell(
              onTap: () => widget.onOpenDoorstepQr(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.green200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.green100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('📱', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Mila (ऑनलाइन मिला)',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.green700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Poora GPay / PhonePe / UPI se aaya',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: AppDesignSystem.stone500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('UPI', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.slate400),
              ),
            ),
          ]

          // STEP 2: Cash Calculator (Screenshots 3 & 4)
          else ...[
            if (!_hasSplitOnline) ...[
              // Full Cash Input (Screenshot 3)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.amber50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.yellow200, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTOMER NE KITNA DIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.warning, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashReceivedController.text.isEmpty ? '0' : _cashReceivedController.text,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _getQuickPresets(orderTotalInt).map((preset) {
                        final isSelected = cashReceived.toInt() == preset;
                        final label = preset == orderTotalInt
                            ? '₹$preset exact'
                            : (preset >= 1000 ? '₹$preset note' : '₹$preset');
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _cashReceivedController.text = preset.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppDesignSystem.warning : AppDesignSystem.statusPending,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppDesignSystem.amber600 : AppDesignSystem.yellow200),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppDesignSystem.amber700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Received', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                        Text('₹${cashReceived.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900)),
                      ],
                    ),
                    if (changeToGive > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🔄 Change wapas do', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.rose600)),
                          Text('-₹${changeToGive.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.rose600)),
                        ],
                      ),
                    ],
                    const Divider(height: 16, color: AppDesignSystem.slate200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💰 Jeb mein rahega (Net Cash)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.amber700)),
                        Text('₹${netCashInHand.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppDesignSystem.slate400),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate400)),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Split Option Link
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasSplitOnline = true;
                    _cashPortionController.text = (orderTotalInt ~/ 2).toString();
                  });
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppDesignSystem.violet600),
                label: Text(
                  'Kuch cash + kuch online mila? (Split)',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.violet600),
                ),
              ),
            ] else ...[
              // Split Input (Screenshot 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.violet50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.violet200, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CASH MEIN KITNA LIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w900, color: AppDesignSystem.violet600, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.violet600, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashPortionController.text.isEmpty ? '0' : _cashPortionController.text,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _getSplitPresets(orderTotalInt).map((preset) {
                        final isSelected = cashPortion.toInt() == preset;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _cashPortionController.text = preset.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppDesignSystem.violet600 : AppDesignSystem.statusShipped,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppDesignSystem.violet700 : AppDesignSystem.violet200),
                            ),
                            child: Text(
                              '₹$preset cash',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppDesignSystem.violet600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Split Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Collected', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.amber700)),
                        Text('₹${cashPortion.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📱 Online Received', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.green700)),
                        Text('₹${onlinePortion.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.green700)),
                      ],
                    ),
                    const Divider(height: 16, color: AppDesignSystem.slate200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.slate900)),
                        Text('₹$orderTotalInt', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppDesignSystem.slate400),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate400)),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Back to full cash
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasSplitOnline = false;
                    _cashReceivedController.text = orderTotalInt.toString();
                  });
                },
                child: Text(
                  '← Poora cash mein liya (no split)',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons: Back + Confirm
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _step = 'choose';
                        _hasSplitOnline = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppDesignSystem.slate200, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('← Back', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.slate500)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final effectiveCash = _hasSplitOnline ? cashPortion : widget.total;
                      widget.onConfirmDelivery({
                        'deliveryLat': widget.lat,
                        'deliveryLng': widget.lng,
                        'paymentMethod': 'COD',
                        'paymentStatus': 'PAID',
                        'isRiderCash': effectiveCash > 0,
                        'paymentCollectedBy': 'RIDER',
                        'cashAmount': effectiveCash,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.emeraldBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Confirm ✅', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
