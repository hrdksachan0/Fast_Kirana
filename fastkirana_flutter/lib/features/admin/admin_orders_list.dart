import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/services/admin_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/store_settings_provider.dart';
import '../orders/order_detail_screen.dart';

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

  List<Order> _allOrders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _liveSyncTimer;
  RealtimeChannel? _realtimeOrdersChannel;

  static const Color primaryRed = Color(0xFFE20A22);

  final Set<String> _printedKOTOrders = {};

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

  @override
  void initState() {
    super.initState();
    _fetchAdminOrders();

    // 1. Ultra-fast WebSocket Realtime Connection (0ms instant sync)
    _realtimeOrdersChannel = SupabaseService.subscribeToAllOrdersRealtime(
      onOrderChange: (record) {
        debugPrint('[Admin WebSocket] Live order update event: ${record['id']}');
        _silentFetchAdminOrders();
      },
    );

    // 2. Periodic sync timer every 4 seconds
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _silentFetchAdminOrders();
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    SupabaseService.unsubscribe(_realtimeOrdersChannel);
    super.dispose();
  }

  Future<void> _fetchAdminOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final List<Order> loaded = [];

      // 1. Direct High-Performance Supabase Realtime Database Query (Fetches all live and history orders)
      final sb = SupabaseService.client;
      if (sb != null) {
        try {
          final res = await sb
              .from('orders')
              .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)')
              .order('createdAt', ascending: false)
              .limit(100);

          if (res is List) {
            for (final j in res) {
              if (j is Map<String, dynamic>) {
                try {
                  loaded.add(Order.fromJson(j));
                } catch (e) {
                  debugPrint('Order parse error: $e');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Supabase orders fetch error: $e');
        }
      }

      // 2. Fetch from /api/admin/orders
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
            try {
              final o = Order.fromJson(j);
              if (!loaded.any((x) => x.id == o.id || (x.readableId != null && x.readableId == o.readableId))) {
                loaded.add(o);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 3. Fetch from /api/orders
      try {
        final response = await dio.get('/api/orders', queryParameters: {'limit': 100});
        final data = response.data;
        List rawList = [];
        if (data is Map && data['orders'] is List) {
          rawList = data['orders'];
        } else if (data is List) {
          rawList = data;
        }
        for (final j in rawList) {
          if (j is Map<String, dynamic>) {
            try {
              final o = Order.fromJson(j);
              if (!loaded.any((x) => x.id == o.id || (x.readableId != null && x.readableId == o.readableId))) {
                loaded.add(o);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 4. Merge locally cached orders
      try {
        final repo = OrderRepository(dio);
        final local = await repo.getOrders('');
        for (final o in local) {
          if (!loaded.any((x) => x.id == o.id || (x.readableId != null && x.readableId == o.readableId))) {
            loaded.add(o);
          }
        }
      } catch (_) {}

      final mergedOrders = _mergeCombinedOrders(loaded);

      if (mounted) {
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
      for (final sub in subOrders) {
        if (sub.items != null) {
          allItems.addAll(sub.items!);
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
    try {
      final dio = ref.read(dioProvider);
      final List<Order> loaded = [];

      // 1. Direct Supabase Query
      final sb = SupabaseService.client;
      if (sb != null) {
        try {
          final res = await sb
              .from('orders')
              .select('*, order_items(*), customer:users!orders_userId_fkey(name,phone)')
              .order('createdAt', ascending: false)
              .limit(100);

          if (res is List) {
            for (final j in res) {
              if (j is Map<String, dynamic>) {
                try {
                  loaded.add(Order.fromJson(j));
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      // 2. Fetch from /api/admin/orders
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
            try {
              final o = Order.fromJson(j);
              if (!loaded.any((x) => x.id == o.id || (x.readableId != null && x.readableId == o.readableId))) {
                loaded.add(o);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 3. Merge locally cached orders
      try {
        final repo = OrderRepository(dio);
        final local = await repo.getOrders('');
        for (final o in local) {
          if (!loaded.any((x) => x.id == o.id || (x.readableId != null && x.readableId == o.readableId))) {
            loaded.add(o);
          }
        }
      } catch (_) {}

      if (loaded.isNotEmpty) {
        final mergedOrders = _mergeCombinedOrders(loaded);
        if (mounted) {
          setState(() {
            _allOrders = mergedOrders;
          });
        }
      }
    } catch (_) {}
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

      // 1. Direct update to Supabase (all sub-orders if combined)
      final List<String> idsToUpdate = (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty)
          ? order.subOrders!.map((s) => s.id).toList()
          : [order.id];

      final sb = SupabaseService.client;
      if (sb != null) {
        for (final id in idsToUpdate) {
          try {
            await sb.from('orders').update({
              'status': statusUpper,
              'updatedAt': DateTime.now().toIso8601String(),
            }).eq('id', id);
          } catch (_) {}
        }
      }

      // 2. Update via REST API
      for (final id in idsToUpdate) {
        try {
          await OrderRepository(ref.read(dioProvider)).updateOrderStatus(id, newStatus);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.readableId ?? order.id} marked as ${newStatus.displayName}!'),
            backgroundColor: _getStatusColor(newStatus),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAdminOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

    final sb = SupabaseService.client;
    if (sb != null) {
      for (final id in idsToAssign) {
        var cleanId = id.trim();
        if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
        try {
          await sb.from('orders').update({
            'deliveryUserId': riderId,
            'status': 'SHIPPED',
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', cleanId);
        } catch (_) {}
      }
    }

    for (final id in idsToAssign) {
      var cleanId = id.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
      try {
        await ref.read(dioProvider).patch('/api/orders/$cleanId', data: {
          'deliveryUserId': riderId,
          'status': 'SHIPPED',
        });
      } catch (_) {}
    }

    _fetchAdminOrders();

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
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatOrderDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _generateKOTText(Order order) {
    final itemsList = order.items ?? [];
    final formattedItems = itemsList.isNotEmpty
        ? itemsList.map((i) {
            final variant = (i.selectedVariant != null && i.selectedVariant!.isNotEmpty)
                ? ' (${i.selectedVariant})'
                : '';
            final note = (order.notes?.trim().isNotEmpty == true)
                ? '\n       📝 Note: ${order.notes!.trim()}'
                : '';
            return '[${i.quantity}x]   ${i.name}$variant$note';
          }).join('\n')
        : '[1x]   Food Items';

    final outletName = (order.shopName?.trim().isNotEmpty == true)
        ? order.shopName!.trim()
        : 'FastKirana Kitchen';

    final orderId = order.readableId ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id);

    final now = DateTime.now();
    final diffMins = now.difference(order.createdAt).inMinutes;
    final elapsedStr = diffMins > 0 ? ' ($diffMins min ago)' : ' (Just now)';
    final timeStr = '${_formatOrderDate(order.createdAt)}, ${_formatOrderTime(order.createdAt)}$elapsedStr';

    return '''========================================
              FASTKIRANA
     KITCHEN ORDER TICKET (KOT)
========================================
Order ID : #$orderId
Time     : $timeStr
Outlet   : $outletName
----------------------------------------
QTY    ITEM
----------------------------------------
$formattedItems
----------------------------------------
     ⚡ Ghatampur Hub Kitchen Slip
========================================''';
  }

  Future<void> _sendRemoteKOT(Order order) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _printedKOTOrders.add(order.id);
      if (order.readableId != null) _printedKOTOrders.add(order.readableId!);
    });

    var cleanId = order.id.trim();
    if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

    // 1. Supabase Realtime Broadcast & DB update
    final sb = SupabaseService.client;
    if (sb != null) {
      try {
        await sb.from('orders').update({
          'kot_printed': true,
          'kot_sent': true,
          'kotPrintedAt': DateTime.now().toIso8601String(),
        }).eq('id', cleanId);

        // Broadcast to Kitchen POS printer / PC
        await sb.channel('kitchen_kot_print').sendBroadcastMessage(
          event: 'print_kot',
          payload: {
            'orderId': order.readableId ?? order.id,
            'kotText': _generateKOTText(order),
            'shopName': order.shopName ?? 'Kitchen',
            'printedAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (_) {}
    }

    // 2. Dio API endpoint
    try {
      await ref.read(dioProvider).post('/api/admin/orders/$cleanId/kot', data: {
        'printed': true,
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🖨️ KOT sent to Kitchen Printer! Status: KOT ✓',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendWhatsAppKOT(Order order) async {
    HapticFeedback.lightImpact();
    final kotMessage = _generateKOTText(order);

    final settings = ref.read(storeSettingsProvider).valueOrNull;
    final targetPhone = (settings?.adminWhatsappPhone ?? '7054470303').replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$targetPhone?text=${Uri.encodeComponent(kotMessage)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(kotMessage, subject: 'KOT Slip #${order.readableId ?? order.id}');
    }
  }

  Color _getStatusColor(OrderStatus? status) {
    if (status == null) return const Color(0xFF64748B);
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF0284C7);
      case OrderStatus.packed:
        return const Color(0xFF7C3AED);
      case OrderStatus.shipped:
        return const Color(0xFFEA580C);
      case OrderStatus.delivered:
        return const Color(0xFF16A34A);
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Orders',
                    style: GoogleFonts.inter(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Live Auto-Sync (Every 3s)',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
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
                            iconColor: const Color(0xFF059669),
                            bgColor: const Color(0xFFECFDF5),
                            borderColor: const Color(0xFFA7F3D0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Card 2: Today's Net Sales
                        Expanded(
                          child: _buildStatCard(
                            title: "Today's Net Sales",
                            value: '₹${todayNetSales.toInt()}',
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF0D9488),
                            bgColor: const Color(0xFFF0FDFA),
                            borderColor: const Color(0xFF99F6E4),
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
                            iconColor: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                            borderColor: const Color(0xFFBFDBFE),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Card 4: Active Orders
                        Expanded(
                          child: _buildStatCard(
                            title: 'Active Orders',
                            value: '$activeOrderCount',
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFFEA580C),
                            bgColor: const Color(0xFFFFF7ED),
                            borderColor: const Color(0xFFFED7AA),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFF475569)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by Order ID, customer, phone...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
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
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF475569)),
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
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 4. Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryRed))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
                            const SizedBox(height: 10),
                            Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
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
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
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
                    color: Colors.black.withOpacity(0.06),
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
                  ? (index == 0 ? primaryRed : const Color(0xFF0F172A))
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (index == 0 ? primaryRed : const Color(0xFF0F172A))
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (index == 0 ? primaryRed.withOpacity(0.12) : const Color(0xFFE2E8F0))
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? (index == 0 ? primaryRed : const Color(0xFF0F172A))
                      : const Color(0xFF64748B),
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
                color: isLive ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? primaryRed.withOpacity(0.2) : const Color(0xFFE2E8F0),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  isLive ? Icons.bolt_rounded : Icons.history_toggle_off_rounded,
                  size: 34,
                  color: isLive ? primaryRed : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLive ? 'No Active Live Orders' : 'No Order History Yet',
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLive
                  ? 'New customer orders placed in Ghatampur will appear here automatically every 3 seconds.'
                  : 'Delivered and past completed orders will be archived here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
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
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? primaryRed : const Color(0xFF0F172A),
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
    final custPhone = order.customerPhone?.isNotEmpty == true ? order.customerPhone! : '7054470303';
    final custAddr = order.customerAddress?.isNotEmpty == true
        ? order.customerAddress!
        : 'Ghatampur Market, UP 209206';
    final itemsList = order.items ?? [];
    final isLive = _isLiveOrder(order);
    final isKOTPrinted = _printedKOTOrders.contains(order.id) ||
        (order.readableId != null && _printedKOTOrders.contains(order.readableId));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive ? statusColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
          width: isLive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Order ID, Total, Status Header & Details Action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_rounded, size: 18, color: statusColor),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${order.readableId ?? order.id}',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (order.isCombined) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
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
                                        fontSize: 9,
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
                        Text(
                          '${order.paymentMethod.displayName} · ${_formatOrderTime(order.createdAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.total.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: primaryRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            order.status.displayName.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: OrderDetailScreen(order: order)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sub-outlets Breakdown Strip for Combined Orders
          if (order.isCombined && order.subOrders != null && order.subOrders!.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFFAF5FF),
              child: Row(
                children: [
                  const Text('📦 Outlets: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B21A8))),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: order.subOrders!.map((sub) {
                        final rid = sub.readableId ?? '';
                        final isRest = rid.toUpperCase().endsWith('-R') || sub.restaurantId != null;
                        final outletIcon = isRest ? '🍽️' : '🛒';
                        final outletTitle = isRest ? (sub.shopName ?? 'Restaurant') : 'Dark Store';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Text(
                            '$outletIcon $outletTitle: ${sub.status.displayName}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Customer Contact Details Box
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 15, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          Text(
                            custName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            custPhone,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              custAddr,
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons: Call & WhatsApp
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _whatsappCustomer(custPhone, order.readableId ?? order.id),
                      icon: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A), size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: itemsList.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity}x ${item.name}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEA580C),
                ),
              ),
            ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 3.4 Rider Assignment Dropdown / Selector
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            color: const Color(0xFFFAFAFA),
            child: Row(
              children: [
                Text(
                  'RIDER:',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
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
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (order.deliveryBoyName?.toLowerCase().contains('aryan') == true)
                            ? 'ARYAN'
                            : ((order.deliveryBoyName?.isNotEmpty == true) ? 'STORE_PARTNER' : 'UNASSIGNED'),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF475569), size: 20),
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: Colors.white,
                        items: [
                          DropdownMenuItem(
                            value: 'UNASSIGNED',
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                Text(
                                  'Unassigned · Tap to assign',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ARYAN',
                            child: Row(
                              children: [
                                const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF0284C7)),
                                const SizedBox(width: 6),
                                Text(
                                  'Aryan (+91 8112849854)',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF0284C7)),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'STORE_PARTNER',
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF16A34A)),
                                const SizedBox(width: 6),
                                Text(
                                  'Store Partner (Self Delivery)',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
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
            color: const Color(0xFFFAFAFA),
            child: Row(
              children: [
                Text(
                  'STATUS:',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
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
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.06),
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
                              color: Color(0xFFD97706),
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.confirmed,
                            child: _StatusDropdownItem(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Confirmed',
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.packed,
                            child: _StatusDropdownItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Packed / Ready',
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.shipped,
                            child: _StatusDropdownItem(
                              icon: Icons.delivery_dining_rounded,
                              label: 'On the Way (Out for Delivery)',
                              color: Color(0xFFEA580C),
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.delivered,
                            child: _StatusDropdownItem(
                              icon: Icons.task_alt_rounded,
                              label: 'Delivered',
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.cancelled,
                            child: _StatusDropdownItem(
                              icon: Icons.cancel_outlined,
                              label: 'Cancelled',
                              color: Color(0xFFDC2626),
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

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 4. The 2 Main Order Actions: 🖨️ Send KOT (Remote) & 💬 WhatsApp KOT
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                // Option 1: 🖨️ Send KOT / 🖨️ KOT ✓
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _sendRemoteKOT(order),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isKOTPrinted ? const Color(0xFFDCFCE7) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isKOTPrinted ? const Color(0xFF86EFAC) : const Color(0xFFBBF7D0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isKOTPrinted ? Icons.check_circle_rounded : Icons.print_rounded,
                            size: 16,
                            color: const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isKOTPrinted ? 'KOT ✓' : 'Send KOT',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF15803D),
                            ),
                          ),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF0F172A)),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp KOT',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Icon(icon, size: 20, color: iconColor),
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
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}