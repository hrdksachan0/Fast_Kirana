import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/rider_location_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/brand_logo.dart';
import '../../providers/auth_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeliveryDashboard extends ConsumerStatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  ConsumerState<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends ConsumerState<DeliveryDashboard>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _activeTab = 0; // 0: Deliveries, 1: Cash Wallet, 2: History

  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _walletInfo;
  Timer? _autoRefreshTimer;
  Timer? _clockTimer;
  int _refreshCountdown = 38;
  String _currentTime = '';
  String? _updatingOrderId;
  String? _currentUserId;
  String _userName = 'Partner';

  late ConfettiController _confettiController;
  final RiderLocationService _locationService = RiderLocationService();

  bool _isDarkMode = false;
  bool _isDeviceOffline = false;
  final Set<String> _knownOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _connectivitySubscription;

  // Dynamic Theme Colors (Supporting AMOLED Dark Mode & Light Mode)
  Color get bgMain => _isDarkMode ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
  Color get cardBg => _isDarkMode ? const Color(0xFF131C2E) : Colors.white;
  Color get cardSubtle => _isDarkMode ? const Color(0xFF1A263D) : const Color(0xFFF8FAFC);
  Color get borderCol => _isDarkMode ? const Color(0xFF23324D) : const Color(0xFFE2E8F0);
  Color get textMain => _isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textMuted => _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static const Color emeraldGreen = Color(0xFF00965E);
  static const Color emeraldDark = Color(0xFF045D38);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _loadUserInfo();
    _initConnectivityAndOfflineQueue();
    _fetchOrders();
    _fetchWallet();

    // 30-second periodic auto-refresh countdown
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_refreshCountdown <= 1) {
          _refreshCountdown = 30;
          _fetchOrders(silent: true);
          _fetchWallet();
        } else {
          _refreshCountdown--;
        }
      });
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
        } catch (_) {}
      }

      await prefs.remove('offline_delivery_queue');

      if (syncedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
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
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Network offline! Action saved locally. Will auto-sync when online.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12)),
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
        await _audioPlayer.play(
          UrlSource('https://cdn.pixabay.com/download/audio/2022/03/15/audio_24a4c58cf3.mp3?filename=notification-sound-7062.mp3'),
          volume: 1.0,
        );
      } catch (_) {
        SystemSound.play(SystemSoundType.alert);
      }

      if (mounted) {
        final orderNum = newOrder['readableId'] ?? 'Order';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
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

  void _updateClock() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(now);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _clockTimer?.cancel();
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
      } catch (_) {}
    } else {
      final name = prefs.getString('user_name');
      if (name != null && name.trim().isNotEmpty) {
        if (mounted) setState(() => _userName = name.trim().split(' ').first);
      }
    }
    if (mounted) {
      setState(() {
        _currentUserId ??= prefs.getString('user_id') ?? prefs.getString('delivery_user_id');
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
    if (!silent) setState(() => _isLoading = true);
    else setState(() => _isRefreshing = true);

    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        final List<dynamic> data = await sb
            .from('orders')
            .select('*, order_items(*), addresses(*), user:users!orders_userId_fkey(name,phone)')
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
        },
        options: Options(
          headers: {
            'x-user-id': userId.isNotEmpty ? userId : 'delivery_1',
            'x-user-role': 'DELIVERY',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> raw = response.data is List ? response.data : (response.data['orders'] ?? []);
        final parsed = raw
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
      merged['shopName'] = '${subLabels.join(' + ')}';

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
      final riderId = _currentUserId ?? 'rider_current';

      if (!_locationService.isTracking || _locationService.activeOrderId != orderId) {
        _locationService.startTracking(
          orderId: orderId,
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
          _locationService.startTracking(
            orderId: orderId,
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

  void _openGoogleMapsNavigation(double lat, double lng, String label) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

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
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark)),
                    Text('Order #$orderNum • ₹${total.toInt()}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: slateMuted)),
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
                color: const Color(0xFFF8FAFC),
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
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: slateMuted),
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
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
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
      Navigator.pushReplacementNamed(context, '/home');
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
              // 🔴 Realtime Offline Alert Banner (Network Drop Resilience)
              if (_isDeviceOffline)
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: const BoxDecoration(color: Color(0xFFDC2626)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'No Internet • Offline Mode (Actions will auto-sync)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Emerald Green Partner Header Container (Full bleed SafeArea)
              _buildPartnerHeader(),

              // 3. Tab Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: brandGreen))
                    : IndexedStack(
                        index: _activeTab,
                        children: [
                          // Tab 0: Deliveries
                          _buildDeliveriesTab(activeDeliveries, pendingPickups),

                          // Tab 1: Cash Wallet
                          _buildWalletTab(),

                          // Tab 2: History
                          _buildHistoryTab(completedToday),
                        ],
                      ),
              ),
            ],
          ),

          // Confetti overlay on delivery completion
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Color(0xFF00A344), Color(0xFFE20A22), Color(0xFF2563EB), Color(0xFFF59E0B)],
            ),
          ),
        ],
      ),
    ),
  );
  }

  /// 2. Emerald Green Partner Header Container
  Widget _buildPartnerHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00965E), Color(0xFF007A48), Color(0xFF045D38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            children: [
              // Row 1: Status Bar (Back Button + Online pill + Clock pill + Dark Mode + Refresh button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  Bounceable(
                    onTap: _handleBackPress,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Online Pill
                  Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isOnline = !_isOnline);
                      if (!_isOnline) {
                        _locationService.stopTracking();
                      } else {
                        _manageGpsTrackingLifecycle(_orders);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isOnline ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _isOnline ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Live Clock Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _currentTime.isNotEmpty ? _currentTime : '12:00:00 PM',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Dark Mode Theme Toggle Button (Battery Saver)
                  Bounceable(
                    onTap: _toggleDarkMode,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Circular Refresh Button
                  Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _fetchOrders();
                      _fetchWallet();
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: _isRefreshing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Partner Profile & Greeting
              Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting().toUpperCase()} · DELIVERY PARTNER',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.82),
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _userName,
                                style: GoogleFonts.inter(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('👋', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sync Indicator (Sleek Compact Pill)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_refreshCountdown}s',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Segmented Tab Bar (Deliveries | Cash Wallet | History)
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF02462A),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab(index: 0, label: 'Deliveries', icon: Icons.local_shipping_rounded),
                    _buildSegmentTab(index: 1, label: 'Cash Wallet', icon: Icons.account_balance_wallet_rounded),
                    _buildSegmentTab(index: 2, label: 'History', icon: Icons.check_circle_outline_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab({required int index, required String label, required IconData icon}) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFF007A48) : Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF007A48) : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
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
                  color: Color(0xFF00965E),
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
                  fontSize: 13,
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
                      color: Color(0xFF7C3AED),
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
                      fontSize: 13,
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
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pendingPickups.length} Orders',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7C3AED),
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
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🛵', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            'No orders out for delivery',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: slateDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Accept new pickup orders from below to start delivering.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
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
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: Center(
        child: Text(
          'No pickup orders waiting at store right now.',
          style: GoogleFonts.inter(fontSize: 12, color: slateMuted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Pickup Order Card (Matching Screenshot 1)
  Widget _buildPickupCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final isFood = (order['orderType'] == 'RESTAURANT') || (order['restaurantId'] != null) || orderNum.contains('-R');
    final shopName = order['shopName'] ?? (isFood ? 'A.S. Restaurant' : 'FastKirana Dark Store');
    final status = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final customer = order['user'] is Map ? order['user'] : {'name': 'Customer', 'phone': null};
    final address = order['address'] is Map ? order['address'] : null;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final isCod = order['paymentMethod'] == 'COD';
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

    String deliverAddress = address?['formattedAddress'] ??
        '${address?['houseNo'] ?? ''} ${address?['street'] ?? ''} ${address?['area'] ?? 'Jawahar Nagar'}'.trim();
    if (deliverAddress.isEmpty) deliverAddress = 'Jawahar Nagar, Ghatampur';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFood ? const Color(0xFFFCE7F3) : const Color(0xFFCCFBF1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
              color: isFood ? const Color(0xFFF43F5E) : const Color(0xFF00965E),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        if (isFood) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Text('🍽️', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 3),
                                Text(
                                  'FOOD',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFDC2626),
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
                            ? const Color(0xFFDCFCE7)
                            : (status == 'PREPARING' ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'PACKED'
                              ? const Color(0xFF86EFAC)
                              : (status == 'PREPARING' ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                        ),
                      ),
                      child: Text(
                        status == 'PACKED' ? 'PACKED • READY' : status,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: status == 'PACKED'
                              ? const Color(0xFF15803D)
                              : (status == 'PREPARING' ? const Color(0xFFB45309) : const Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  shopName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: slateMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Info Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      // Letter Avatar
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.inter(
                              fontSize: 15,
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
                            Text(
                              customerName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customerPhone.isNotEmpty)
                              Text(
                                customerPhone.startsWith('+') ? customerPhone : '+91$customerPhone',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Action buttons: Maps + Phone
                      Bounceable(
                        onTap: () => _openGoogleMapsNavigation(lat, lng, customerName),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF15803D)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Bounceable(
                        onTap: () {
                          if (customerPhone.isNotEmpty) {
                            launchUrl(Uri.parse('tel:$customerPhone'));
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('PICKUP: ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              shopName,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('DELIVER: ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              deliverAddress,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 5),
                                Text(
                                  'ITEMS TO PICK UP (${items.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF4338CA),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1))} qty',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
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
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                if (price != null && price > 0)
                                  Text(
                                    '₹${(price * (qty is num ? qty : 1)).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
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

                const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: slateMuted),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${total.toInt()}',
                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: slateDark),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCod ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCod ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Text(
                                  isCod ? '💵 COD' : '✅ PAID',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isCod ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(isCod ? '🔥' : '💳', style: const TextStyle(fontSize: 10)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  isCod ? 'Collect ₹${total.toInt()} Cash' : 'Paid Online',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isCod ? const Color(0xFFD97706) : const Color(0xFF059669),
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
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text(
                                  'Preparing in Kitchen...',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD97706),
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
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
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
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
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
                                    fontSize: 12,
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
    final isCod = order['paymentMethod'] == 'COD';
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

    String deliverAddress = address?['formattedAddress'] ??
        '${address?['houseNo'] ?? ''} ${address?['street'] ?? ''} ${address?['area'] ?? 'Jawahar Nagar'}'.trim();
    if (deliverAddress.isEmpty) deliverAddress = 'Jawahar Nagar, Ghatampur';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
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
              gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
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
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'STOP #1 • ACTIVE DROP',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    Text(
                      '#$orderNum',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer details with Navigate & Call Action Buttons
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                      child: Center(
                        child: Text(avatarLetter,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (customerPhone.isNotEmpty)
                            Bounceable(
                              onTap: () {
                                final cleanPhone = customerPhone.replaceAll(' ', '').trim();
                                launchUrl(Uri.parse('tel:$cleanPhone'));
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_rounded, size: 10, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      customerPhone.startsWith('+') ? customerPhone : '+91 $customerPhone',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2563EB),
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Action Buttons: Navigate + Call
                    Bounceable(
                      onTap: () => _openGoogleMapsNavigation(lat, lng, customerName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('Navigate',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
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
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF15803D)),
                            const SizedBox(width: 3),
                            Text('Call',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Items List (Clean vertical list for delivery boy to check all products)
                if (items.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 5),
                                Text(
                                  'ITEMS IN THIS DROP (${items.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF065F46),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1))} qty',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
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
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                if (price != null && price > 0)
                                  Text(
                                    '₹${(price * (qty is num ? qty : 1)).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
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

                // Action Buttons: Doorstep UPI QR + Delivered
                Row(
                  children: [
                    if (isCod) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDoorstepUpiQrModal(order),
                          icon: const Icon(Icons.qr_code_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: Text('Doorstep QR',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF93C5FD)),
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
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
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
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Text(
                        'CASH IN HAND (जेब में नकद)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB45309),
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
                    fontSize: 38,
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
                    trackColor: const Color(0xFFF1F5F9),
                    progressColor: const Color(0xFF10B981),
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
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'CAPACITY',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
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
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20, color: Color(0xFF059669)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Active & Eligible: Full COD order capacity available.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
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
                color: _isOnline ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withValues(alpha: 0.06),
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
                            color: _isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isOnline ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                            color: _isOnline ? const Color(0xFF15803D) : const Color(0xFFDC2626),
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: _isOnline ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                              ),
                            ),
                            Text(
                              _isOnline ? 'Receiving live delivery orders' : 'Orders redirected to other riders',
                              style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: _isOnline,
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFFBBF7D0),
                        inactiveThumbColor: const Color(0xFFEF4444),
                        inactiveTrackColor: const Color(0xFFFECDD3),
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
                    color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isOnline ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: _isOnline ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isOnline
                              ? 'Aap online hain. Store se new orders aate hi aapko pickup notification milegi.'
                              : 'Off duty hone par new orders doosre active delivery partners ke paas transfer ho jayenge.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isOnline ? const Color(0xFF166534) : const Color(0xFF991B1B),
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
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
                    trackColor: const Color(0xFFF1F5F9),
                    progressColor: const Color(0xFF10B981),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                          Text(
                            '/ $dailyTarget',
                            style: GoogleFonts.inter(
                              fontSize: 9,
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
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: slateMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(totalCount >= dailyTarget ? '🏆' : '🎯', style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            totalCount >= dailyTarget ? 'Milestone Bonus Achieved!' : '$totalCount of $dailyTarget Completed',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: totalCount >= dailyTarget ? const Color(0xFF059669) : slateDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        totalCount >= dailyTarget ? 'Great hustle today! 🎉' : 'Complete ${dailyTarget - totalCount} more for bonus',
                        style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w500),
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF15803D),
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
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Center(
                child: Text(
                  'No completed deliveries recorded yet.',
                  style: GoogleFonts.inter(fontSize: 12, color: slateMuted, fontWeight: FontWeight.w600),
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
              final addr = addrObj?['formattedAddress'] ?? addrObj?['street'] ?? 'Ghatampur';
              final isLast = idx == completed.length - 1;

              String timeStr = 'Today';
              if (item['deliveredAt'] != null || item['createdAt'] != null) {
                try {
                  final dt = DateTime.parse(item['deliveredAt'] ?? item['createdAt']).toLocal();
                  timeStr = DateFormat('h:mm a').format(dt);
                } catch (_) {}
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
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFF86EFAC),
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
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
                                        fontSize: 12.5,
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
                                            fontSize: 10.5,
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isCod ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isCod ? '💵 COD' : '💳 ONLINE',
                                        style: GoogleFonts.inter(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: isCod ? const Color(0xFFB45309) : const Color(0xFF15803D),
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                      Text(
                                        addr,
                                        style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Delivered ✅',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF15803D),
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
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('📦', style: TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Confirm Parcel Handover',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Order #${widget.orderNum} • ',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
            ),
            Text(
              '₹${widget.total.toInt()}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          ),
          child: Text(
            'Kya aapne customer ko parcel safely handover kar diya hai?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569), height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
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
                  backgroundColor: const Color(0xFF00965E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text('Yes, Delivered ✅', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white)),
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
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '₹',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Payment Collection',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          Text(
            'Order #${widget.orderNum} • Collect: ₹$orderTotalInt',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 16),

          // STEP 1: Choice Screen (Screenshot 2)
          if (_step == 'choose') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Jeb mein: ₹${widget.cashInHand.toInt()}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                  ),
                  Text(
                    ' | ',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                  ),
                  Text(
                    'Limit: ₹${widget.cashLimit.toInt()}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
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
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('💵', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Liya (कैश लिया)',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFB45309)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer ne cash diya — poora ya kuch',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF78716C)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFD97706), size: 22),
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
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('📱', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Mila (ऑनलाइन मिला)',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF15803D)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Poora GPay / PhonePe / UPI se aaya',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF78716C)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('UPI', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
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
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
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
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTOMER NE KITNA DIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFFB45309), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashReceivedController.text.isEmpty ? '0' : _cashReceivedController.text,
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
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
                              color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFFB45309),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Received', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                        Text('₹${cashReceived.toInt()}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    if (changeToGive > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🔄 Change wapas do', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48))),
                          Text('-₹${changeToGive.toInt()}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFFE11D48))),
                        ],
                      ),
                    ],
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💰 Jeb mein rahega (Net Cash)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFB45309))),
                        Text('₹${netCashInHand.toInt()}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFB45309))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
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
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF7C3AED)),
                label: Text(
                  'Kuch cash + kuch online mila? (Split)',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED)),
                ),
              ),
            ] else ...[
              // Split Input (Screenshot 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CASH MEIN KITNA LIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF7C3AED), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashPortionController.text.isEmpty ? '0' : _cashPortionController.text,
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
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
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE9D5FF)),
                            ),
                            child: Text(
                              '₹$preset cash',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF7C3AED),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Collected', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                        Text('₹${cashPortion.toInt()}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFFB45309))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📱 Online Received', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF15803D))),
                        Text('₹${onlinePortion.toInt()}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF15803D))),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                        Text('₹$orderTotalInt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
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
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
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
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('← Back', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
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
                      backgroundColor: const Color(0xFF00965E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Confirm ✅', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white)),
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
