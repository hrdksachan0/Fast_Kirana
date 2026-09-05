import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/services/admin_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/kot_print_service.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/store_settings_provider.dart';
import '../../core/theme/responsive.dart';
import '../orders/order_detail_screen.dart';
import '../delivery/widgets/connectivity_banner.dart';
import '../common/order_edit_modal.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminOrdersScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  // 0 = Live Orders, 1 = Order History
  int _selectedTab = 0;
  String _liveSubFilter = 'ALL';
  String _historySubFilter = 'ALL';
  String _searchQuery = '';

  static List<Order> _cachedOrders = [];
  List<Order> _allOrders = _cachedOrders;
  bool _isLoading = _cachedOrders.isEmpty;

  static const String _diskAdminOrdersKey = 'cached_admin_orders_v2';

  Future<void> _loadDiskOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskAdminOrdersKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded.map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
        if (list.isNotEmpty && _allOrders.isEmpty) {
          _cachedOrders = list;
          setState(() {
            _allOrders = list;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[AdminOrdersList] disk load error: $e');
    }
  }

  Future<void> _saveDiskOrders(List<Order> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep most recent 100 orders on disk
      final toSave = orders.take(100).map((o) => o.toJson()).toList();
      await prefs.setString(_diskAdminOrdersKey, jsonEncode(toSave));
    } catch (e) {
      debugPrint('[AdminOrdersList] disk save error: $e');
    }
  }
  String? _error;
  Timer? _liveSyncTimer;
  Timer? _searchDebounce;
  RealtimeChannel? _realtimeOrdersChannel;
  bool _isFetchingAdmin = false;

  static const Color primaryRed = AppDesignSystem.primary;

  final Set<String> _printedKOTOrders = {};
  final Set<String> _sendingKOTOrderIds = {};

  final List<String> _liveStatusFilters = [
    'ALL',
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

  @override
  void initState() {
    super.initState();
    _initConnectivityAndOfflineQueue();

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
          debugPrint('[Admin WebSocket] Live order update event: ${record['id']}');
          _silentFetchAdminOrders();
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

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _searchDebounce?.cancel();
    SupabaseService.unsubscribe(_realtimeOrdersChannel);
    super.dispose();
  }

  Future<void> _fetchAdminOrders() async {
    if (_isFetchingAdmin) return;
    _isFetchingAdmin = true;

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
            final res = await sb
                .from('orders')
                .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)')
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
                        }
                    } catch (e) {
            debugPrint('Supabase orders fetch error: $e');
          }
        }(),
        // Source 2: REST API
        () async {
          try {
            final response = await dio.get(
              '/api/admin/orders',
              queryParameters: {'limit': 100},
              options: Options(headers: {
                'x-user-role': 'ADMIN',
                'x-user-phone': '7054470303',
              }),
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
                try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
              }
            }
          } catch (e) {
            debugPrint('REST orders fetch error: $e');
          }
        }(),
      ]);

      final mergedOrders = _mergeCombinedOrders(loaded);
      _cachedOrders = mergedOrders;

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
            final key = (item.id != null && item.id!.isNotEmpty)
                ? item.id!
                : '${item.name.toLowerCase().trim()}_${item.selectedVariant?.toLowerCase().trim() ?? ""}_${item.notes?.toLowerCase().trim() ?? ""}';
            if (seenItemKeys.add(key)) {
              allItems.add(item);
            }
          }
        }
      }

      final combinedTotal = subOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.total,
      );

      OrderStatus combinedStatus(List<OrderStatus> statuses) {
        final active = statuses.where((s) => s != OrderStatus.cancelled).toList();
        if (active.isEmpty) return OrderStatus.cancelled;
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
        final rid = o.readableId ?? '';
        final isRest = rid.toUpperCase().endsWith('-R') || o.restaurantId != null;
        final name = o.shopName?.trim();
        if (name != null && name.isNotEmpty) return name;
        return isRest ? '🍽️ Restaurant' : '🛒 Dark Store';
      }).toList();

      final merged = primary.copyWith(
        readableId: baseReadableId.isNotEmpty ? baseReadableId : primary.readableId,
        items: allItems,
        total: combinedTotal,
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
            final res = await sb
                .from('orders')
                .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)')
                .order('createdAt', ascending: false)
                .limit(100);
            for (final j in res) {
              try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
                        }
                    } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
        }(),
        // 2. REST API
        () async {
          try {
            final response = await dio.get(
              '/api/admin/orders',
              queryParameters: {'limit': 100},
              options: Options(headers: {
                'x-user-role': 'ADMIN',
                'x-user-phone': '7054470303',
              }),
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
                try { addUnique(Order.fromJson(j)); } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
              }
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
        }(),
        // 3. Local cached orders
        () async {
          try {
            final repo = OrderRepository(dio);
            final local = await repo.getOrders('');
            for (final o in local) {
              addUnique(o);
            }
          } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); }
        }(),
      ]);

      if (loaded.isNotEmpty) {
        final mergedOrders = _mergeCombinedOrders(loaded);
        _cachedOrders = mergedOrders;
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
        }
      }
    } catch (e, _) { LoggerService.error('AdminOrdersList: silent catch', e); } finally {
      _isFetchingAdmin = false;
    }
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    HapticFeedback.heavyImpact();
    try {
      final statusUpper = newStatus.name.toUpperCase();

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
      final statusUpper = newStatus.name.toUpperCase();

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

  void _showSubstitutionModal(Order order, OrderItem item) {
    final repController = TextEditingController();
    final custPhone = order.customerPhone ?? '';
    final custName = order.customerName ?? 'Customer';
    final orderId = order.readableId ?? order.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppDesignSystem.slate300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusCancelled,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppDesignSystem.red600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Out-of-Stock Replacement',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                      ),
                      Text(
                        'Order #$orderId • Customer: $custName',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.rose50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.rose200),
              ),
              child: Row(
                children: [
                  Text('❌', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unavailable Item: ${item.name} (${item.quantity}x)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.rose800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'SUGGESTED REPLACEMENT:',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w800, color: AppDesignSystem.slate600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: repController,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. Britannia Brown Bread 400g / Taaza 500ml',
                hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: AppDesignSystem.slate400),
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.green600, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                final replacement = repController.text.trim();
                if (replacement.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter replacement item name', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                  );
                  return;
                }
                Navigator.pop(ctx);
                AdminNotificationService.sendSubstitutionWhatsApp(
                  customerPhone: custPhone,
                  customerName: custName,
                  orderId: orderId,
                  unavailableItem: item.name,
                  suggestedReplacement: replacement,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.green600,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Send Substitution via WhatsApp ➔',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSuperOrderEditModal(Order order) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderEditModal(
        order: {
          'id': order.id,
          'readableId': order.readableId ?? order.id,
          'items': (order.items ?? []).map((it) => {
            'productId': it.productId ?? it.id,
            'name': it.name,
            'price': it.price,
            'quantity': it.quantity,
            'imageUrl': it.imageUrl,
            'selectedVariant': it.selectedVariant,
            'notes': it.notes,
          }).toList(),
          'restaurantId': order.restaurantId,
          'user': {
            'phone': order.customerPhone,
            'name': order.customerName,
          },
        },
        isRestaurant: order.restaurantId != null && order.restaurantId!.isNotEmpty,
        isAdmin: true,
        restaurantId: order.restaurantId,
        onOrderUpdated: () {
          _fetchAdminOrders();
        },
      ),
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
      Order? restSub;
      for (final s in order.subOrders!) {
        final rid = (s.readableId ?? '').toUpperCase();
        if (rid.endsWith('-R') ||
            s.restaurantId != null ||
            (s.shopName != null && s.shopName!.toLowerCase().contains('restaurant')) ||
            (s.shopName != null && s.shopName!.toLowerCase().contains('wedson')) ||
            (s.shopName != null && s.shopName!.toLowerCase().contains('as '))) {
          restSub = s;
          break;
        }
      }

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
    HapticFeedback.lightImpact();
    final whatsappMessage = AdminNotificationService.formatRestaurantKOTMessage(order);

    final settings = ref.read(storeSettingsProvider).valueOrNull;
    final targetPhone = (settings?.adminWhatsappPhone ?? '7054470303').replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$targetPhone?text=${Uri.encodeComponent(whatsappMessage)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(whatsappMessage, subject: 'FastKirana Kitchen Order #${order.readableId ?? order.id}');
    }
  }

  Color _getStatusColor(OrderStatus? status) {
    if (status == null) return AppDesignSystem.slate500;
    switch (status) {
      case OrderStatus.pending:
        return AppDesignSystem.warning;
      case OrderStatus.confirmed:
        return AppDesignSystem.cyan600;
      case OrderStatus.packed:
        return AppDesignSystem.violet600;
      case OrderStatus.shipped:
        return AppDesignSystem.orange600;
      case OrderStatus.delivered:
        return AppDesignSystem.green600;
      case OrderStatus.cancelled:
        return AppDesignSystem.red600;
    }
  }

  bool _isLiveOrder(Order order) {
    return order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.packed ||
        order.status == OrderStatus.shipped;
  }

  List<Order> _getFilteredOrders() {
    List<Order> list = [];
    if (_selectedTab == 0) {
      // Live Tab
      list = _allOrders.where(_isLiveOrder).toList();
      if (_liveSubFilter != 'ALL') {
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
    final liveCount = _allOrders.where(_isLiveOrder).length;
    final historyCount = _allOrders.where((o) => !_isLiveOrder(o)).length;
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

          // 1. Dashboard Stats Cards (Exact 2x2 Grid Matching Web App Logic)
          Builder(
            builder: (context) {
              // Exact Indian Standard Time (IST - UTC+5:30) start of day calculation
              final nowUtc = DateTime.now().toUtc();
              final istNow = nowUtc.add(const Duration(hours: 5, minutes: 30));
              final istStartOfDay = DateTime.utc(istNow.year, istNow.month, istNow.day).subtract(const Duration(hours: 5, minutes: 30));

              final todayOrders = _allOrders.where((o) =>
                o.createdAt.isAfter(istStartOfDay) &&
                (o.deliveryMethod?.toUpperCase() != 'RETAIL')
              ).toList();

              // Today's Sales: sum of all non-cancelled orders placed today
              final todaySales = todayOrders
                  .where((o) => o.status != OrderStatus.cancelled)
                  .fold<double>(0.0, (sum, o) => sum + o.total);

              // Today's Net Sales: sum of DELIVERED orders placed today
              final todayNetSales = todayOrders
                  .where((o) => o.status == OrderStatus.delivered)
                  .fold<double>(0.0, (sum, o) => sum + o.total);

              // Today's Orders count
              final todayOrdersCount = todayOrders.length;

              // Active Orders count: all live queue orders (not delivered and not cancelled)
              final activeOrderCount = _allOrders.where((o) =>
                o.status != OrderStatus.delivered &&
                o.status != OrderStatus.cancelled
              ).length;

              return Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Card 1: Today's Sales
                        Expanded(
                          child: _buildStatCard(
                            title: "Today's Sales",
                            value: '₹${todaySales.toInt()}',
                            icon: Icons.currency_rupee_rounded,
                            iconColor: AppDesignSystem.emerald600,
                            bgColor: AppDesignSystem.green50,
                            borderColor: AppDesignSystem.emerald200,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Card 2: Net Sales
                        Expanded(
                          child: _buildStatCard(
                            title: "Net Sales",
                            value: '₹${todayNetSales.toInt()}',
                            icon: Icons.trending_up_rounded,
                            iconColor: AppDesignSystem.teal600,
                            bgColor: AppDesignSystem.teal50,
                            borderColor: AppDesignSystem.teal300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Card 3: Today's Orders
                        Expanded(
                          child: _buildStatCard(
                            title: "Today's Orders",
                            value: '$todayOrdersCount',
                            icon: Icons.shopping_bag_outlined,
                            iconColor: AppDesignSystem.blue600,
                            bgColor: AppDesignSystem.blue50,
                            borderColor: AppDesignSystem.blue200,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Card 4: Active Orders
                        Expanded(
                          child: _buildStatCard(
                            title: 'Active Orders',
                            value: '$activeOrderCount',
                            icon: Icons.bolt_rounded,
                            iconColor: AppDesignSystem.orange600,
                            bgColor: AppDesignSystem.orange50,
                            borderColor: AppDesignSystem.orange300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Primary Tab Switcher (Live vs History with modern iOS-style segmented control)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMainTabButton(
                      index: 0,
                      label: 'Live Orders',
                      count: liveCount,
                      icon: Icons.bolt_rounded,
                      isSelected: _selectedTab == 0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildMainTabButton(
                      index: 1,
                      label: 'Order History',
                      count: historyCount,
                      icon: Icons.history_rounded,
                      isSelected: _selectedTab == 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Modern Pretty Search Field with Instant Clear
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.slate600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _searchQuery = val.toLowerCase().trim());
                        });
                      },
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate900,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by Order ID, customer, phone...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchQuery = ''),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.slate200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppDesignSystem.slate600),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Status Sub-filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: (_selectedTab == 0 ? _liveStatusFilters : _historyStatusFilters).map((status) {
                  final currentFilter = _selectedTab == 0 ? _liveSubFilter : _historySubFilter;
                  final isSelected = currentFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_selectedTab == 0) {
                              _liveSubFilter = status;
                            } else {
                              _historySubFilter = status;
                            }
                          });
                        }
                      },
                      label: Text(
                        status == 'ALL' ? (_selectedTab == 0 ? 'All Live' : 'All History') : status,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? Colors.white : AppDesignSystem.slate600,
                        ),
                      ),
                      selectedColor: AppDesignSystem.slate900,
                      backgroundColor: AppDesignSystem.slate100,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate200,
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
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
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: primaryRed,
                            onRefresh: _fetchAdminOrders,
                            child: ListView.builder(
                              cacheExtent: 600,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: displayOrders.length,
                              itemBuilder: (context, index) {
                                final order = displayOrders[index];
                                return _buildAdminOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTab = index;
          _searchQuery = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
              size: 15,
              color: isSelected
                  ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                  : AppDesignSystem.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                    : AppDesignSystem.slate500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (index == 0 ? primaryRed.withValues(alpha: 0.12) : AppDesignSystem.slate200)
                    : AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                      : AppDesignSystem.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isLive = _selectedTab == 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isLive ? AppDesignSystem.statusCancelled : AppDesignSystem.slate100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? primaryRed.withValues(alpha: 0.2) : AppDesignSystem.slate200,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  isLive ? Icons.bolt_rounded : Icons.history_toggle_off_rounded,
                  size: 34,
                  color: isLive ? primaryRed : AppDesignSystem.slate500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLive ? 'No Active Live Orders' : 'No Order History Yet',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 15.5),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLive
                  ? 'New customer orders placed in Ghatampur will appear here automatically every 3 seconds.'
                  : 'Delivered and past completed orders will be archived here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12),
                color: AppDesignSystem.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _fetchAdminOrders();
              },
              icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
              label: Text(
                'Check Database / Refresh',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? primaryRed : AppDesignSystem.slate900,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'Customer';
    final custPhone = (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty && order.customerPhone != '7054470303')
        ? order.customerPhone!.trim()
        : (order.addressRaw?['phone']?.toString().isNotEmpty == true
            ? order.addressRaw!['phone'].toString().trim()
            : (order.customerPhone?.isNotEmpty == true ? order.customerPhone! : 'Not Available'));
    final custAddr = order.customerAddress?.trim().isNotEmpty == true
        ? order.customerAddress!.trim()
        : (order.addressRaw?['address']?.toString().trim().isNotEmpty == true
            ? order.addressRaw!['address'].toString().trim()
            : 'No address provided');
    final rawItems = order.items ?? [];
    final List<OrderItem> itemsList = [];
    final seenCardItemKeys = <String>{};
    for (final item in rawItems) {
      final key = (item.id != null && item.id!.isNotEmpty)
          ? item.id!
          : '${item.name.toLowerCase().trim()}_${item.selectedVariant?.toLowerCase().trim() ?? ""}_${item.notes?.toLowerCase().trim() ?? ""}';
      if (seenCardItemKeys.add(key)) {
        itemsList.add(item);
      }
    }
    final isLive = _isLiveOrder(order);
    final isKOTPrinted = _printedKOTOrders.contains(order.id) ||
        (order.readableId != null && _printedKOTOrders.contains(order.readableId));
    final isKOTSending = _sendingKOTOrderIds.contains(order.id) ||
        (order.readableId != null && _sendingKOTOrderIds.contains(order.readableId));
    final isPickup = (order.deliveryMethod ?? '').toUpperCase().contains('PICKUP') ||
        (order.deliveryMethod ?? '').toUpperCase().contains('TAKEAWAY');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive ? statusColor.withValues(alpha: 0.4) : AppDesignSystem.slate200,
          width: isLive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Order ID, Total, Status Header & Details Action
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () {
              Navigator.push(
                context,
                FadeSlideRoute(page: OrderDetailScreen(order: order)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_rounded, size: 18, color: statusColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '#${order.readableId ?? order.id}',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 15),
                                          fontWeight: FontWeight.w900,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPickup ? AppDesignSystem.statusPending : AppDesignSystem.green100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isPickup ? AppDesignSystem.warning : AppDesignSystem.emerald200,
                                            width: 1.1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(isPickup ? '🚶‍♂️' : '🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                            const SizedBox(width: 3),
                                            Text(
                                              isPickup ? 'SELF PICKUP' : 'DELIVERY',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                                fontWeight: FontWeight.w900,
                                                color: isPickup ? AppDesignSystem.amber700 : AppDesignSystem.green700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (order.isCombined) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [AppDesignSystem.violet600, AppDesignSystem.fuchsia600],
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                                              const SizedBox(width: 3),
                                              Text(
                                                'COMBINED',
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.scaledFontSize(context, 9),
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final isOnline = order.paymentMethod != PaymentMethod.cod || order.paymentStatus.toUpperCase() == 'PAID';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isOnline ? AppDesignSystem.green100 : AppDesignSystem.statusPending,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: isOnline ? AppDesignSystem.emerald200 : AppDesignSystem.yellow200,
                                            width: 0.9,
                                          ),
                                        ),
                                        child: Text(
                                          isOnline ? '✅ ONLINE PAID' : '💵 COD',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w900,
                                            color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.amber700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatOrderTime(order.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                              if (!order.isCombined) ...[
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    final shop = order.shopName;
                                    final rid = (order.readableId ?? '').toUpperCase();
                                    final isRest = (shop != null && (shop.toLowerCase().contains('restaurant') || shop.toLowerCase().contains('wedson') || shop.toLowerCase().contains('as ') || shop.toLowerCase().contains('bal'))) ||
                                        rid.endsWith('-R') ||
                                        order.restaurantId != null;
                                    final outletName = (shop != null && shop.isNotEmpty && shop != 'null') 
                                        ? shop 
                                        : (isRest ? 'Wedson Restaurant' : 'FastKirana Dark Store');

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRest ? AppDesignSystem.violet50 : AppDesignSystem.green50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isRest ? AppDesignSystem.violet300 : AppDesignSystem.green200,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(isRest ? '🍽️' : '🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                          const SizedBox(width: 4),
                                          Text(
                                            outletName,
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 10.5),
                                              fontWeight: FontWeight.w800,
                                              color: isRest ? AppDesignSystem.statusShippedText : AppDesignSystem.green800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${order.total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16.5),
                          fontWeight: FontWeight.w900,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          order.status.displayName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Sub-outlets Breakdown Strip for Combined Orders
          if (order.isCombined && order.subOrders != null && order.subOrders!.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppDesignSystem.violet50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📦 OUTLET STATUSES (Tap to toggle):',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w900, color: AppDesignSystem.statusShippedText, letterSpacing: 0.3),
                      ),
                      if (order.status != OrderStatus.packed)
                        GestureDetector(
                          onTap: () => _updateOrderStatus(order, OrderStatus.packed),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.violet600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⚡ Pack All',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: order.subOrders!.map((sub) {
                      final rid = sub.readableId ?? '';
                      final isRest = rid.toUpperCase().endsWith('-R') || sub.restaurantId != null;
                      final outletIcon = isRest ? '🍽️' : '🛒';
                      final outletTitle = isRest ? (sub.shopName ?? 'Restaurant') : 'Dark Store (Grocery)';
                      final isPacked = sub.status == OrderStatus.packed || sub.status == OrderStatus.shipped || sub.status == OrderStatus.delivered;

                      return GestureDetector(
                        onTap: () {
                          final nextStatus = isPacked ? OrderStatus.confirmed : OrderStatus.packed;
                          _updateSubOrderStatus(order, sub, nextStatus);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPacked ? AppDesignSystem.green100 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isPacked ? AppDesignSystem.emerald200 : AppDesignSystem.violet300, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(outletIcon, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                              const SizedBox(width: 5),
                              Text(
                                '$outletTitle: ',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w800, color: AppDesignSystem.indigo950),
                              ),
                              Text(
                                sub.status.displayName.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: isPacked ? AppDesignSystem.green600 : AppDesignSystem.fuchsia600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isPacked ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                size: 12,
                                color: isPacked ? AppDesignSystem.green600 : AppDesignSystem.fuchsia600,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // 2. Customer Contact Details Box
          Container(
            color: AppDesignSystem.slate50,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: AppDesignSystem.slate600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              custName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppDesignSystem.slate500),
                          const SizedBox(width: 6),
                          Text(
                            custPhone,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.slate600,
                            ),
                          ),
                        ],
                      ),
                      if (isPickup) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.statusPending,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.yellow200),
                          ),
                          child: Row(
                            children: [
                              Text('🚶‍♂️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'STORE PICKUP — Customer will collect at counter',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.amber700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1.0),
                              child: Icon(Icons.location_on_outlined, size: 13, color: AppDesignSystem.slate500),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                custAddr,
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate500, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Action Buttons: Call & WhatsApp
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _whatsappCustomer(custPhone, order.readableId ?? order.id),
                      icon: const Icon(Icons.chat_rounded, color: AppDesignSystem.green600, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppDesignSystem.green100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _callCustomer(custPhone),
                      icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Ordered Items List
          if (itemsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ITEMS (${itemsList.length}):',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: itemsList.map((item) {
                      return GestureDetector(
                        onTap: () => _showSubstitutionModal(order, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.quantity}x ${item.name}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignSystem.slate700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.swap_horiz_rounded, size: 12, color: AppDesignSystem.slate400),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          if (order.notes?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Note: ${order.notes}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.orange600,
                ),
              ),
            ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          if (isPickup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: AppDesignSystem.amber50,
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 16, color: AppDesignSystem.amber700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store Self-Pickup Order — No Delivery Partner Required',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.amber700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // 3.4 Rider Assignment Dropdown / Selector
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              color: AppDesignSystem.background,
              child: Row(
                children: [
                  Text(
                    'RIDER:',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppDesignSystem.slate300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: (order.deliveryBoyName?.toLowerCase().contains('aryan') == true)
                              ? 'ARYAN'
                              : ((order.deliveryBoyName?.isNotEmpty == true) ? 'STORE_PARTNER' : 'UNASSIGNED'),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppDesignSystem.slate600, size: 20),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: Colors.white,
                          items: [
                            DropdownMenuItem(
                              value: 'UNASSIGNED',
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 15, color: AppDesignSystem.slate400),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Unassigned · Tap to assign',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'ARYAN',
                              child: Row(
                                children: [
                                  const Icon(Icons.two_wheeler_rounded, size: 16, color: AppDesignSystem.cyan600),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Aryan (+91 8112849854)',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.cyan600),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'STORE_PARTNER',
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 15, color: AppDesignSystem.green600),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Store Partner (Self Delivery)',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.green700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              if (val == 'ARYAN') {
                                _assignRider(order, 'rider_aryan_1', 'Aryan', '+918112849854');
                              } else if (val == 'STORE_PARTNER') {
                                _assignRider(order, 'store_admin_self', 'Store Partner', '+917054470303');
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3.5 Order Status Dropdown Selector
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: AppDesignSystem.background,
            child: Row(
              children: [
                Text(
                  'STATUS:',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<OrderStatus>(
                        value: order.status,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: statusColor, size: 22),
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: OrderStatus.pending,
                            child: _StatusDropdownItem(
                              icon: Icons.schedule_rounded,
                              label: 'Placed (Pending)',
                              color: AppDesignSystem.amber600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.confirmed,
                            child: _StatusDropdownItem(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Confirmed',
                              color: AppDesignSystem.cyan600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.packed,
                            child: _StatusDropdownItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Packed / Ready',
                              color: AppDesignSystem.violet600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.shipped,
                            child: _StatusDropdownItem(
                              icon: Icons.delivery_dining_rounded,
                              label: 'On the Way (Out for Delivery)',
                              color: AppDesignSystem.orange600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.delivered,
                            child: _StatusDropdownItem(
                              icon: Icons.task_alt_rounded,
                              label: 'Delivered',
                              color: AppDesignSystem.green600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.cancelled,
                            child: _StatusDropdownItem(
                              icon: Icons.cancel_outlined,
                              label: 'Cancelled',
                              color: AppDesignSystem.red600,
                            ),
                          ),
                        ],
                        onChanged: (newStatus) {
                          if (newStatus != null && newStatus != order.status) {
                            HapticFeedback.mediumImpact();
                            _updateOrderStatus(order, newStatus);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // 3.5 Superpower Action: Edit Order / Add & Swap Items (⚡)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openSuperOrderEditModal(order),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      'Edit Items & Swap (Superpower)',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. The 2 Main Order Actions: 🖨️ Send KOT (Remote) & 💬 WhatsApp KOT
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                // Option 1: 🖨️ Send KOT / ⏳ Printing... / 🖨️ KOT ✓
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: (isKOTSending || isKOTPrinted) ? null : () => _sendRemoteKOT(order),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isKOTSending
                            ? AppDesignSystem.statusPending // Yellow amber loading
                            : (isKOTPrinted ? AppDesignSystem.green100 : AppDesignSystem.green50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isKOTSending
                              ? AppDesignSystem.yellow200
                              : (isKOTPrinted ? AppDesignSystem.emerald200 : AppDesignSystem.green200),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isKOTSending) ...[
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.amber600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sending KOT...',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.amber700,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              isKOTPrinted ? Icons.check_circle_rounded : Icons.print_rounded,
                              size: 16,
                              color: AppDesignSystem.green600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isKOTPrinted ? 'KOT Sent ✓' : 'Send KOT',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.green700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Option 2: 💬 WhatsApp KOT
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _sendWhatsAppKOT(order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppDesignSystem.slate900),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp KOT',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate500,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 17),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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

class _StatusDropdownItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusDropdownItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 12.5),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}