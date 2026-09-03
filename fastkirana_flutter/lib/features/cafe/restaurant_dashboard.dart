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
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/kot_print_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../core/utils/app_toast.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/live_clock_badge.dart';
import '../../providers/auth_provider.dart';

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

class _RestaurantDashboardState extends ConsumerState<RestaurantDashboard> {
  int _activeTab = 0; // 0: Live Orders, 1: Quick 86 Menu, 2: Sales Report, 3: Settings
  static List<Map<String, dynamic>> _cachedOrders = [];
  bool _isLoading = _cachedOrders.isEmpty;
  bool _isRefreshing = false;
  bool _isStoreOpen = true;
  bool _isBusyMode = false;
  int _refreshCountdown = 20;

  List<Map<String, dynamic>> _orders = _cachedOrders;
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _salesOrders = []; // All orders (incl. delivered) for Sales tab
  Map<String, dynamic> _salesSummary = {};
  
  Timer? _autoRefreshTimer;
  Timer? _menuSearchDebounce;
  bool _isFetchingOrders = false;
  String _restaurantName = 'Restaurant Console';
  String? _assignedRestaurantId;
  String? _updatingOrderId;
  double _commissionRate = 25.0;

  double _getCommissionRateForOutlet(String? restId, String? restName) {
    final id = (restId ?? '').toLowerCase().trim();
    final name = (restName ?? '').toLowerCase().trim();
    if (id == outletWedsonId || id.contains('wedson') || name.contains('wedson')) {
      return 25.0;
    }
    if (id == outletAsRestaurantId || id.contains('as') || name.contains('a.s') || name.contains('as-')) {
      return 25.0;
    }
    if (id == outletBalUdyanId || id.contains('bal') || name.contains('bal') || name.contains('udyan')) {
      return 20.0;
    }
    return 25.0;
  }

  final Set<String> _knownPendingOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedStatusFilter = 'ALL'; // ALL, PENDING, CONFIRMED, PACKED, COMPLETED
  String _selectedSalesPeriod = 'TODAY'; // TODAY, YESTERDAY, WEEK, MONTH, ALL

  // Menu Search & Filter State
  String _menuSearchQuery = '';
  String _menuStockFilter = 'ALL'; // ALL, IN_STOCK, OUT_STOCK
  final TextEditingController _menuSearchController = TextEditingController();

  // Dynamic Theme Colors
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandAmber = Color(0xFFF59E0B);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color cardBg = Colors.white;
  static const Color bgMain = Color(0xFFF8FAFC);

  final List<Map<String, String>> _availableOutlets = [
    {'id': outletWedsonId, 'name': 'Wedson Restaurant'},
    {'id': outletAsRestaurantId, 'name': 'A.S. Restaurant'},
    {'id': outletBalUdyanId, 'name': 'Bal Udyan Restaurant'},
  ];

  @override
  void initState() {
    super.initState();
    _initOutletDetails();

    // 60-second background refresh.
    // Supabase Realtime (below) handles instant pushes — this is just a safety net.
    // Guard inside _fetchOrders prevents overlap with Realtime-triggered fetches.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || _isFetchingOrders) return;
      _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _menuSearchDebounce?.cancel();
    _audioPlayer.dispose();
    _menuSearchController.dispose();
    super.dispose();
  }

  Future<void> _initOutletDetails() async {
    // 1. Initial args
    if (widget.initialRestaurantId != null && widget.initialRestaurantId!.isNotEmpty) {
      _assignedRestaurantId = widget.initialRestaurantId;
      if (widget.initialRestaurantName != null && widget.initialRestaurantName!.isNotEmpty) {
        _restaurantName = widget.initialRestaurantName!;
      }
    }

    // 2. Logged in user profile & assigned restaurant
    final user = ref.read(authProvider).valueOrNull;

    if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
      if (user?.assignedRestaurantId != null && user!.assignedRestaurantId!.isNotEmpty) {
        _assignedRestaurantId = user.assignedRestaurantId;
      } else {
        final prefs = await SharedPreferences.getInstance();
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

    // Fallback default
    if (_assignedRestaurantId == null || _assignedRestaurantId!.isEmpty) {
      _assignedRestaurantId = outletWedsonId;
      _restaurantName = 'Wedson Restaurant';
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
  }

  // Lazy tab loading flags
  bool _menuTabLoaded = false;
  bool _salesTabLoaded = false;

  /// Called when user switches tabs — lazy-loads data for Menu and Sales tabs
  void _onTabChanged(int newTab) {
    setState(() => _activeTab = newTab);

    if (newTab == 1 && !_menuTabLoaded) {
      _menuTabLoaded = true;
      _fetchMenuItems();
    } else if (newTab == 2 && !_salesTabLoaded) {
      _salesTabLoaded = true;
      _fetchSalesSummary();
      _fetchSalesOrders();
    }
  }

  void _initSupabaseRealtime() {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      // 1. Database table changes
      supabase
          .channel('public:restaurant_orders_channel_${_assignedRestaurantId ?? 'all'}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              _fetchOrders(silent: true);
              _playChime();
            },
          )
          .subscribe();

      // 2. Direct broadcast channel for instant KOT sync across devices
      supabase
          .channel('restaurant-orders-live')
          .onBroadcast(
            event: 'reprint-kot',
            callback: (payload) {
              _fetchOrders(silent: true);
              _playChime();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _playChime() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;

    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final dio = ref.read(dioProvider);
      final primaryUrl = _assignedRestaurantId != null
          ? '/api/restaurant-dashboard/orders?restaurantId=$_assignedRestaurantId&status=live&limit=100'
          : '/api/restaurant-dashboard/orders?status=live&limit=100';

      Response response;
      try {
        response = await dio.get(primaryUrl);
      } catch (_) {
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
          } catch (_) {}
        }

        // Ensure ID-wise outlet filtering
        if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty && _assignedRestaurantId != 'ALL') {
          parsed = parsed.where((o) {
            final rId = (o['restaurantId'] ?? o['restaurant']?['id'] ?? '').toString();
            final rName = (o['restaurantName'] ?? o['shopName'] ?? '').toString().toLowerCase();
            
            if (rId.isNotEmpty) {
              if (rId == _assignedRestaurantId) return true;
              if (_assignedRestaurantId == outletWedsonId && (rId == 'wedson' || rId == 'wedson-restaurant')) return true;
              if (_assignedRestaurantId == outletAsRestaurantId && (rId == 'as-restaurant' || rId == 'as-cafe')) return true;
              if (_assignedRestaurantId == outletBalUdyanId && (rId == 'bal-udyan-restaurant' || rId == 'bal-udyan')) return true;
            }

            if (_assignedRestaurantId == outletWedsonId && rName.contains('wedson')) return true;
            if (_assignedRestaurantId == outletAsRestaurantId && (rName.contains('as ') || rName.contains('a.s') || rName.contains('as-'))) return true;
            if (_assignedRestaurantId == outletBalUdyanId && (rName.contains('bal') || rName.contains('udyan'))) return true;

            return false;
          }).toList();
        }

        // Check for new pending orders
        final newPending = parsed.where((o) => o['status'] == 'PENDING').map((o) => o['id'].toString()).toSet();
        final brandNew = newPending.difference(_knownPendingOrderIds);
        if (brandNew.isNotEmpty) {
          _playChime();
        }
        _knownPendingOrderIds.addAll(newPending);

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
          _isRefreshing = false;
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
        if (mounted) {
          setState(() {
            _menuItems = prods.map((e) => Map<String, dynamic>.from(e)).toList();
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
  Future<void> _fetchSalesOrders() async {
    try {
      final dio = ref.read(dioProvider);
      final url = _assignedRestaurantId != null
          ? '/api/restaurant-dashboard/orders?restaurantId=$_assignedRestaurantId'
          : '/api/restaurant-dashboard/orders';
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

        // Filter by current outlet
        List<Map<String, dynamic>> filtered = parsed;
        if (_assignedRestaurantId != null && _assignedRestaurantId!.isNotEmpty) {
          filtered = parsed.where((o) {
            final rId = (o['restaurantId'] ?? '').toString();
            return rId == _assignedRestaurantId;
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

    if (mounted) {
      if (nextStatus == 'CONFIRMED') {
        AppToast.showSuccess(
          context,
          'Order Accepted! 👨‍🍳',
          subtitle: 'Kitchen timer set and cooking started.',
        );
      } else if (nextStatus == 'PACKED') {
        AppToast.showSuccess(
          context,
          'Food Ready for Pickup! 🥡',
          subtitle: 'Rider notified to collect the package.',
        );
      } else {
        AppToast.showSuccess(
          context,
          'Order status updated to $nextStatus',
        );
      }
    }

    try {
      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{'status': nextStatus};
      if (prepTime != null) {
        body['prepTime'] = prepTime;
      }

      await dio.patch('/api/orders/$orderId', data: body);

      // Background sync to Supabase and OrderRepository cache
      try {
        final sb = SupabaseService.client;
        if (sb != null) {
          await sb.from('orders').update({
            'status': nextStatus,
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', orderId);
        }
      } catch (_) {}

      try {
        final parsed = OrderStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == nextStatus.toUpperCase(),
          orElse: () => OrderStatus.pending,
        );
        await OrderRepository(dio).updateOrderStatus(orderId, parsed);
      } catch (_) {}
    } catch (e) {
      debugPrint('[Restaurant status update error]: $e');
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
    HapticFeedback.lightImpact();

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/api/restaurant-dashboard/products/$itemId', data: {'isAvailable': newStatus});
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
    } catch (_) {
      // Revert optimistic update
      if (mounted) {
        setState(() {
          final index = _menuItems.indexWhere((p) => p['id'].toString() == itemId);
          if (index != -1) {
            _menuItems[index]['isAvailable'] = currentStatus;
          }
        });
      }
    }
  }

  void _showPrepTimeModal(Map<String, dynamic> order) {
    final orderId = order['id'].toString();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        int selectedTime = 15;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Accept Order & Cooking Time',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: slateMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select estimated cooking time to notify customer & rider:',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: slateMuted),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [15, 25, 35, 45].map((time) {
                      final isSelected = selectedTime == time;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Bounceable(
                            onTap: () {
                              setModalState(() => selectedTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryRed : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? primaryRed : slateBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$time',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 18),
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? Colors.white : slateDark,
                                    ),
                                  ),
                                  Text(
                                    'MINS',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateOrderStatus(orderId, 'CONFIRMED', prepTime: selectedTime);
                      },
                      child: Text(
                        'Confirm & Start Cooking ($selectedTime Mins) ➔',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _generateKitchenWhatsAppMessage(Map<String, dynamic> order) {
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final List items = KotPrintService.extractRestaurantItems(order);

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        orderDate = DateTime.parse(order['createdAt'].toString()).toLocal();
      } catch (_) {}
    }
    final timeStr = DateFormat('hh:mm a').format(orderDate);

    final String deliveryMethod = (order['deliveryMethod'] ?? 'DELIVERY').toString().toUpperCase();
    final String typeStr = (deliveryMethod == 'PICKUP' || deliveryMethod == 'SELF_PICKUP')
        ? '🚶 Self Pickup (Customer Takeaway)'
        : '🛵 Doorstep Delivery (Rider Pickup)';

    final outletName = (order['shopName'] != null && order['shopName'].toString().isNotEmpty)
        ? order['shopName'].toString()
        : _restaurantName;

    final buffer = StringBuffer();
    buffer.writeln('🍽️ *FASTKIRANA KITCHEN ORDER*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 *Order Token:* #$readableId');
    buffer.writeln('⏰ *Order Time:* $timeStr');
    buffer.writeln('📦 *Type:* $typeStr');
    buffer.writeln('🏪 *Outlet:* $outletName');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *ITEMS TO PREPARE:*\n');

    int totalQty = 0;
    for (int idx = 0; idx < items.length; idx++) {
      final i = items[idx];
      final name = (i['name'] ?? 'Food Item').toString();
      final qty = (i['quantity'] is num) ? (i['quantity'] as num).toInt() : (int.tryParse(i['quantity']?.toString() ?? '1') ?? 1);
      totalQty += qty;
      final variant = (i['selectedVariant'] != null && i['selectedVariant'].toString().isNotEmpty)
          ? ' (${i['selectedVariant']})'
          : '';
      final itemNote = (i['notes'] != null && i['notes'].toString().isNotEmpty)
          ? ' [Note: ${i['notes']}]'
          : '';
      buffer.writeln('${idx + 1}. $name$variant$itemNote  ➜  *Qty: $qty*');
    }

    if (items.isEmpty) {
      buffer.writeln('1. Food Items  ➜  *Qty: 1*');
      totalQty = 1;
    }

    buffer.writeln('\n🔢 *Total Items to Pack:* $totalQty items');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    final customerNote = (order['notes'] ?? order['customerNote'] ?? '').toString().trim();
    if (customerNote.isNotEmpty && customerNote != 'null') {
      buffer.writeln('📝 *Customer Note:* $customerNote');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('👨‍🍳 *Chef Note:* Kripya fresh prepare karein aur safely pack karein');

    return buffer.toString();
  }

  String _generateKOTText(Map<String, dynamic> order) {
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    // Extract restaurant items strictly (omit grocery items on combined orders)
    final List items = KotPrintService.extractRestaurantItems(order);

    final formattedItems = items.isNotEmpty
        ? items.map((i) {
            final name = (i['name'] ?? 'Food Item').toString();
            final qty = (i['quantity'] is num) ? (i['quantity'] as num).toInt() : (int.tryParse(i['quantity']?.toString() ?? '1') ?? 1);
            final variant = (i['selectedVariant'] != null && i['selectedVariant'].toString().isNotEmpty)
                ? ' (${i['selectedVariant']})'
                : '';
            final note = (i['notes'] != null && i['notes'].toString().isNotEmpty)
                ? '\n      * Note: ${i['notes']}'
                : '';
            final qtyStr = '$qty'.padRight(2);
            return '$qtyStr x  $name$variant$note';
          }).join('\n')
        : '1  x  Kitchen Food';

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (_) {}
    }
    final rawCustName = (order['userName'] ?? (order['user'] is Map ? order['user']['name'] : null) ?? order['customerName'])?.toString().trim();
    final custName = rawCustName != null && rawCustName.isNotEmpty ? ' | $rawCustName' : '';
    final printTimeStr = DateFormat('dd MMM  hh:mm a').format(DateTime.now());
    final typeStr = (order['deliveryMethod'] ?? 'DELIVERY').toString();

    return '''======================================
            FASTKIRANA KOT
======================================
TOKEN : #$readableId$custName
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

  void _showKOTPrintModal(Map<String, dynamic> order) {
    HapticFeedback.mediumImpact();
    final kotText = _generateKOTText(order);
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final user = ref.read(authProvider).valueOrNull;
    final isAdmin = user?.role.toUpperCase() == 'ADMIN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.print_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kitchen Order Ticket (KOT)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15.5), fontWeight: FontWeight.w900, color: slateDark)),
                          Text('Order #$readableId-R · Bluetooth / POS Print', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: slateMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // KOT Ticket Receipt View
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  kotText,
                  style: GoogleFonts.robotoMono(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  // 1. Primary Print Thermal POS (For Restaurant Console)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(ctx);
                        KotPrintService.printKOTReceipt(context, order);
                      },
                      icon: const Icon(Icons.print_rounded, size: 17, color: Colors.white),
                      label: Text('Print KOT (Thermal POS)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  // 2. Admin Only: Send Remote Broadcast to Web Kitchen Console
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Bounceable(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(ctx);

                        final extractedItems = KotPrintService.extractRestaurantItems(order);
                        final custName = (order['userName'] ?? (order['user'] is Map ? order['user']['name'] : null) ?? order['customerName'])?.toString();

                        KotPrintService.sendRemoteKOTToKitchen(
                          orderId: orderId,
                          readableId: order['readableId']?.toString() ?? orderId,
                          shopName: _restaurantName,
                          customerName: custName,
                          items: extractedItems,
                          deliveryMethod: order['deliveryMethod']?.toString() ?? 'DELIVERY',
                          notes: order['notes']?.toString(),
                          kotText: kotText,
                        );

                        if (context.mounted) {
                          AppToast.showSuccess(
                            context,
                            'KOT Sent to Kitchen! 👨‍🍳',
                            subtitle: 'Order #${order['readableId'] ?? orderId} sent to kitchen',
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                            const SizedBox(width: 4),
                            Text('Kitchen', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // 3. WhatsApp Kitchen Share
                  Bounceable(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final whatsappText = _generateKitchenWhatsAppMessage(order);
                      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(whatsappText)}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        await Clipboard.setData(ClipboardData(text: whatsappText));
                        if (mounted) {
                          AppToast.showInfo(
                            context,
                            'Kitchen Order Copied! 📋',
                            subtitle: 'Ready to share on WhatsApp',
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('💬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOutletSwitcherModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch Restaurant Console',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
              ),
              Text(
                'View orders and menu catalog for selected food outlet:',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted),
              ),
              const SizedBox(height: 16),
              ..._availableOutlets.map((outlet) {
                final isSelected = _assignedRestaurantId == outlet['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isSelected ? primaryRed : slateBorder, width: isSelected ? 1.5 : 1),
                    ),
                    tileColor: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                    ),
                    title: Text(
                      outlet['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: isSelected ? primaryRed : slateDark,
                      ),
                    ),
                    subtitle: Text(
                      'FastKirana Food Kitchen · Live Outlet',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: primaryRed) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _assignedRestaurantId = outlet['id'];
                        _restaurantName = outlet['name'] ?? _restaurantName;
                        _commissionRate = _getCommissionRateForOutlet(_assignedRestaurantId, _restaurantName);
                      });
                      _fetchOrders();
                      _fetchMenuItems();
                      _fetchSalesSummary();
                      _fetchSalesOrders();
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showQuick86BottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = _menuItems.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            final inStockCount = _menuItems.where((p) => p['isAvailable'] == true).length;
            final outStockCount = _menuItems.length - inStockCount;

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick 86 / Stock Controls',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
                              ),
                              Text(
                                'Toggle sold-out dishes instantly',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: slateMuted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    // Summary Pills
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Column(
                                children: [
                                  Text('$inStockCount', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: brandGreen)),
                                  Text('In Stock', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w700, color: brandGreen)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Column(
                                children: [
                                  Text('$outStockCount', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: primaryRed)),
                                  Text('Out of Stock (86)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w700, color: primaryRed)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (v) => setModalState(() => searchQuery = v),
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search menu dishes...',
                            hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: slateMuted),
                            prefixIcon: const Icon(Icons.search, size: 18, color: slateMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: slateBorder),
                    // Items List
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: slateBorder),
                        itemBuilder: (context, idx) {
                          final item = filteredItems[idx];
                          final isAvailable = item['isAvailable'] ?? true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: slateBorder),
                                  ),
                                  child: const Center(child: Text('🍲', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18)))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w800, color: slateDark),
                                      ),
                                      Text(
                                        '₹${item['price'] ?? 0}',
                                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isAvailable,
                                  activeColor: brandGreen,
                                  onChanged: (val) {
                                    setModalState(() {
                                      item['isAvailable'] = val;
                                    });
                                    _toggleItemAvailability(item);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: const Center(child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15)))),
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
            // Stock / Menu Items Quick Manager
            Bounceable(
              onTap: _showQuick86BottomSheet,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 15, color: primaryRed),
              ),
            ),
            // Live Sync Timer Indicator
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_refreshCountdown}s',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: slateMuted),
              ),
            ),
            // Logout Button
            Bounceable(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to log out from Kitchen Console?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, size: 15, color: slateMuted),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // Sub-Header Metric Strip
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: Colors.white,
              child: Row(
                children: [
                  _buildHeaderMetric('New Orders', '$pendingCount', pendingCount > 0 ? primaryRed : slateDark, isAlert: pendingCount > 0),
                  const SizedBox(width: 10),
                  _buildHeaderMetric('Cooking Now', '$activeOrders', brandAmber),
                  const SizedBox(width: 10),
                  _buildHeaderLiveClock(),
                ],
              ),
            ),
            const Divider(height: 1, color: slateBorder),

            // Main Tabs Segmented Control
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Live Orders', Icons.restaurant_menu),
                    const SizedBox(width: 8),
                    _buildTabButton(1, 'Menu', Icons.menu_book_rounded),
                    const SizedBox(width: 8),
                    _buildTabButton(2, 'Sales & Payouts', Icons.currency_rupee_rounded),
                    const SizedBox(width: 8),
                    _buildTabButton(3, 'Settings', Icons.tune_rounded),
                  ],
                ),
              ),
            ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryRed))
                : _activeTab == 0
                    ? _buildLiveOrdersTab()
                    : _activeTab == 1
                        ? _buildMenuCatalogTab()
                        : _activeTab == 2
                            ? _buildSalesReportTab()
                            : _buildStoreSettingsTab(),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildHeaderLiveClock() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          children: [
            LiveDigitalClockBadge(
              backgroundColor: Colors.transparent,
              borderColor: Colors.transparent,
              textColor: slateDark,
              iconColor: slateMuted,
              fontSize: Responsive.scaledFontSize(context, 12),
              showSeconds: false,
            ),
            Text('Live Time', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w700, color: slateMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value, Color col, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? const Color(0xFFFECDD3) : slateBorder),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: col), maxLines: 1),
            Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w700, color: slateMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Bounceable(
      onTap: () {
        HapticFeedback.selectionClick();
        _onTabChanged(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryRed : slateBorder),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryRed.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : slateMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: isSelected ? Colors.white : slateDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrdersTab() {
    const liveStatuses = {'PENDING', 'CONFIRMED', 'PREPARING', 'PACKED', 'READY', 'OUT_FOR_DELIVERY'};
    final filtered = _orders.where((o) {
      final status = (o['status'] ?? '').toString().toUpperCase();
      // Only show live orders (exclude DELIVERED, CANCELLED, COMPLETED)
      if (!liveStatuses.contains(status)) return false;
      if (_selectedStatusFilter == 'ALL') return true;
      return status == _selectedStatusFilter;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, size: 44, color: slateMuted),
              ),
              const SizedBox(height: 14),
              Text('No active orders right now', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: slateDark)),
              const SizedBox(height: 6),
              Text(
                'New incoming orders for $_restaurantName will appear here',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: slateMuted, height: 1.35),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchOrders(),
      color: primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: filtered.length,
        itemBuilder: (context, idx) {
          final order = filtered[idx];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String status = (order['status'] ?? 'PENDING').toString();
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final dynamic rawItems = order['items'];
    final List items = (rawItems is List) ? rawItems : [];

    final num total = (order['total'] is num)
        ? (order['total'] as num)
        : (num.tryParse(order['total']?.toString() ?? '0') ?? 0);

    final dynamic rawUser = order['user'];
    final Map<String, dynamic> user = (rawUser is Map<String, dynamic>) ? rawUser : {};
    final String customerName = (user['name'] ?? 'Customer').toString();
    final assignedRider = order['assignedPicker'] ?? order['assignedRider'];

    Color statusBadgeColor = primaryRed;
    String statusLabel = 'NEW ORDER';
    if (status == 'CONFIRMED' || status == 'PREPARING') {
      statusBadgeColor = brandAmber;
      statusLabel = 'IN PREP';
    } else if (status == 'PACKED' || status == 'READY') {
      statusBadgeColor = brandGreen;
      statusLabel = 'READY FOR PICKUP';
    } else if (status == 'OUT_FOR_DELIVERY') {
      statusBadgeColor = const Color(0xFF3B82F6);
      statusLabel = 'DISPATCHED';
    }

    final isPending = status == 'PENDING';
    final isUpdating = _updatingOrderId == orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? primaryRed : slateBorder, width: isPending ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isPending ? primaryRed.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Builder(
              builder: (context) {
                final isPickup = (order['deliveryMethod'] ?? '').toString().toUpperCase().contains('PICKUP') ||
                    (order['deliveryMethod'] ?? '').toString().toUpperCase().contains('TAKEAWAY');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#$readableId',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPickup ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPickup ? const Color(0xFFF59E0B) : const Color(0xFF86EFAC),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(isPickup ? '🚶‍♂️' : '🛵', style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 9.5))),
                                  const SizedBox(width: 3),
                                  Text(
                                    isPickup ? 'SELF PICKUP' : 'DELIVERY',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9),
                                      fontWeight: FontWeight.w900,
                                      color: isPickup ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBadgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusBadgeColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: statusBadgeColor),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${total.toInt()}',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                        ),
                      ],
                    ),
                    if (isPickup) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📍', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                            const SizedBox(width: 3),
                            Text(
                              'Customer will collect takeaway at counter (No Rider)',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 6),

            // Customer Name & Direct Action Buttons (KOT & Call)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: slateMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerName,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Bounceable(
                      onTap: () => _showKOTPrintModal(order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text('KOT', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w900, color: const Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items List
            ...items.map((item) {
              final String name = (item['name'] ?? 'Dish').toString();
              final int qty = (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
              final String? notes = item['notes']?.toString();
              final String? variant = item['selectedVariant']?.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4)),
                      child: Text('${qty}x', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: slateDark),
                          ),
                          if (variant != null && variant.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(variant, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: brandAmber)),
                            ),
                          if (notes != null && notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('📝 $notes', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, color: brandAmber)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Assigned Rider Status
            if (assignedRider != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rider: ${assignedRider['name'] ?? 'Assigned'}',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: const Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: Bounceable(
                      onTap: isUpdating ? null : () => _updateOrderStatus(orderId, 'CANCELLED'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Center(
                          child: Text('Reject', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: primaryRed)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Bounceable(
                      onTap: isUpdating ? null : () => _showPrepTimeModal(order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: isUpdating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Accept & Cook ⏱️', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (status == 'CONFIRMED' || status == 'PREPARING')
              Row(
                children: [
                  Expanded(
                    child: Bounceable(
                      onTap: isUpdating ? null : () => _updateOrderStatus(orderId, 'PACKED'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: brandGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: isUpdating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Mark Food as Ready 🥡', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: () => _showKOTPrintModal(order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              )
            else if (status == 'PACKED' || status == 'READY')
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Center(
                        child: Text('Waiting for Rider Pickup 🛵', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: brandGreen)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: () => _showKOTPrintModal(order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCatalogTab() {
    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 48, color: slateMuted),
            const SizedBox(height: 12),
            Text('No menu items loaded', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w800, color: slateDark)),
            const SizedBox(height: 4),
            Text('Dishes for $_restaurantName will appear here', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
          ],
        ),
      );
    }

    final query = _menuSearchQuery.trim().toLowerCase();
    final inStockCount = _menuItems.where((p) => p['isAvailable'] == true).length;
    final outStockCount = _menuItems.length - inStockCount;

    // Filter items by search query and stock filter
    final filteredItems = _menuItems.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final category = (item['category'] is Map ? item['category']['name'] : '').toString().toLowerCase();
      final priceStr = (item['price'] ?? '').toString();

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          category.contains(query) ||
          priceStr.contains(query);

      if (!matchesQuery) return false;

      final isAvailable = item['isAvailable'] ?? true;
      if (_menuStockFilter == 'IN_STOCK') return isAvailable == true;
      if (_menuStockFilter == 'OUT_STOCK') return isAvailable == false;
      return true;
    }).toList();

    return Column(
      children: [
        // ─── 1. Premium Search Bar & Filter Header ──────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          color: bgMain,
          child: Column(
            children: [
              // Modern Search Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _menuSearchQuery.isNotEmpty ? primaryRed : const Color(0xFFE2E8F0),
                    width: _menuSearchQuery.isNotEmpty ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _menuSearchController,
                  onChanged: (val) {
                    _menuSearchDebounce?.cancel();
                    _menuSearchDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _menuSearchQuery = val);
                    });
                  },
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600, color: slateDark),
                  decoration: InputDecoration(
                    hintText: 'Search dish name, price or category...',
                    hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _menuSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _menuSearchController.clear();
                              setState(() {
                                _menuSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips (All, In Stock, 86 / Out of Stock)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMenuFilterChip(
                      label: 'All Dishes (${_menuItems.length})',
                      isSelected: _menuStockFilter == 'ALL',
                      color: slateDark,
                      onTap: () => setState(() => _menuStockFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _buildMenuFilterChip(
                      label: '🟢 In Stock ($inStockCount)',
                      isSelected: _menuStockFilter == 'IN_STOCK',
                      color: const Color(0xFF15803D),
                      onTap: () => setState(() => _menuStockFilter = 'IN_STOCK'),
                    ),
                    const SizedBox(width: 8),
                    _buildMenuFilterChip(
                      label: '🔴 86 / Out of Stock ($outStockCount)',
                      isSelected: _menuStockFilter == 'OUT_STOCK',
                      color: primaryRed,
                      onTap: () => setState(() => _menuStockFilter = 'OUT_STOCK'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── 2. Dishes List / Empty State ─────────────────────────────────────
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No dishes found',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _menuSearchQuery.isNotEmpty
                              ? 'No items match "$_menuSearchQuery"'
                              : 'No dishes match selected stock filter',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: slateMuted),
                          textAlign: TextAlign.center,
                        ),
                        if (_menuSearchQuery.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              _menuSearchController.clear();
                              setState(() {
                                _menuSearchQuery = '';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: slateDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: Text(
                              'Clear Search',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, idx) {
                    final item = filteredItems[idx];
                    final isAvailable = item['isAvailable'] ?? true;
                    final num price = (item['price'] is num)
                        ? (item['price'] as num)
                        : (num.tryParse(item['price']?.toString() ?? '0') ?? 0);

                    final String name = item['name']?.toString() ?? 'Dish';
                    final String? imageUrl = (item['images'] is List && (item['images'] as List).isNotEmpty)
                        ? item['images'][0].toString()
                        : item['image']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isAvailable ? const Color(0xFFF1F5F9) : const Color(0xFFFEE2E2),
                          width: isAvailable ? 1.2 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Dish Thumbnail / Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isAvailable ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAvailable ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (imageUrl != null && imageUrl.trim().isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Text('🍲', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('🍲', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dish Info & Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 14),
                                    fontWeight: FontWeight.w800,
                                    color: isAvailable ? slateDark : const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '₹${price.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: FontWeight.w900,
                                        color: isAvailable ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAvailable ? 'LIVE' : '86 • OFF',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9.5),
                                          fontWeight: FontWeight.w900,
                                          color: isAvailable ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Availability Switch
                          Switch.adaptive(
                            value: isAvailable,
                            activeColor: brandGreen,
                            activeTrackColor: const Color(0xFF86EFAC),
                            inactiveThumbColor: const Color(0xFF94A3B8),
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                            onChanged: (_) => _toggleItemAvailability(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Bounceable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11.5),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesReportTab() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final filteredOrdersList = _salesOrders.where((o) {
      final status = o['status']?.toString().toUpperCase() ?? '';
      if (status == 'CANCELLED') return false;
      final dt = DateTime.tryParse(o['createdAt']?.toString() ?? '');
      if (dt == null) return true;

      switch (_selectedSalesPeriod) {
        case 'YESTERDAY':
          return dt.isAfter(yesterdayStart) && dt.isBefore(todayStart);
        case 'WEEK':
          return dt.isAfter(weekStart);
        case 'MONTH':
          return dt.isAfter(monthStart);
        case 'ALL':
          return true;
        case 'TODAY':
        default:
          return dt.isAfter(todayStart);
      }
    }).toList();

    double calculatedGrossSales = 0.0;
    for (final o in filteredOrdersList) {
      final dynamic rawItems = o['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        double orderFoodSum = 0.0;
        for (final it in rawItems) {
          final num p = (it['price'] is num) ? (it['price'] as num) : (num.tryParse(it['price']?.toString() ?? '0') ?? 0);
          final int q = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
          orderFoodSum += (p * q).toDouble();
        }
        calculatedGrossSales += orderFoodSum;
      } else {
        final num sub = (o['subtotal'] is num) ? (o['subtotal'] as num) : (num.tryParse(o['subtotal']?.toString() ?? '0') ?? 0);
        if (sub > 0) {
          calculatedGrossSales += sub.toDouble();
        } else {
          final num tot = (o['total'] is num) ? (o['total'] as num) : (num.tryParse(o['total']?.toString() ?? '0') ?? 0);
          final num del = (o['deliveryFee'] is num) ? (o['deliveryFee'] as num) : (num.tryParse(o['deliveryFee']?.toString() ?? '0') ?? 0);
          final num misc = (o['miscFee'] is num) ? (o['miscFee'] as num) : (num.tryParse(o['miscFee']?.toString() ?? '0') ?? 0);
          calculatedGrossSales += math.max(0.0, (tot - del - misc).toDouble());
        }
      }
    }

    final num apiTotalSales = (_salesSummary['totalSales'] is num)
        ? (_salesSummary['totalSales'] as num)
        : (num.tryParse(_salesSummary['totalSales']?.toString() ?? '0') ?? 0);

    final double totalSales = (_selectedSalesPeriod == 'TODAY' && calculatedGrossSales == 0 && apiTotalSales > 0)
        ? apiTotalSales.toDouble()
        : calculatedGrossSales;

    final int ordersCount = filteredOrdersList.length;
    final double commPercent = _commissionRate;

    final double commissionDeduction = totalSales * (commPercent / 100.0);
    final double netProfit = math.max(0.0, totalSales - commissionDeduction);

    String periodTitle = "Today's Net Settlement";
    if (_selectedSalesPeriod == 'YESTERDAY') periodTitle = "Yesterday's Net Settlement";
    else if (_selectedSalesPeriod == 'WEEK') periodTitle = "Last 7 Days Net Settlement";
    else if (_selectedSalesPeriod == 'MONTH') periodTitle = "This Month's Net Settlement";
    else if (_selectedSalesPeriod == 'ALL') periodTitle = "All Time Net Settlement";
    final periods = [
      {'id': 'TODAY', 'label': 'Today'},
      {'id': 'YESTERDAY', 'label': 'Yesterday'},
      {'id': 'WEEK', 'label': 'Last 7 Days'},
      {'id': 'MONTH', 'label': 'This Month'},
      {'id': 'ALL', 'label': 'All Time'},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date-wise Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: periods.map((p) {
                final isSel = _selectedSalesPeriod == p['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedSalesPeriod = p['id']!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? primaryRed : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? primaryRed : slateBorder),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        p['label']!,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: isSel ? Colors.white : slateDark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Net Settlement Highlight Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryRed, Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: primaryRed.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(periodTitle, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('₹${netProfit.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 28), fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Food Sales: ₹${totalSales.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('Orders: $ordersCount', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Settlement Breakdown
          Text('Settlement Breakdown', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Food Item Sales (Gross)',
            '₹${totalSales.toStringAsFixed(2)}',
            slateDark,
          ),
          _buildSummaryRow(
            'Platform Commission (${commPercent.toInt()}%)',
            commissionDeduction > 0 ? '-₹${commissionDeduction.toStringAsFixed(2)}' : '-${commPercent.toInt()}%',
            primaryRed,
          ),
          _buildSummaryRow(
            'Net Payable Settlement',
            '₹${netProfit.toStringAsFixed(2)}',
            brandGreen,
          ),
          const SizedBox(height: 22),

          // 4. Settled Orders for this period
          if (filteredOrdersList.isNotEmpty) ...[
            Text('Orders in this Period ($ordersCount)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark)),
            const SizedBox(height: 10),
            ...filteredOrdersList.map((o) {
              final String id = (o['id'] ?? '').toString();
              final rawReadable = o['readableId'];
              final String displayId = (rawReadable != null && rawReadable.toString().isNotEmpty)
                  ? '#$rawReadable-R'
                  : '#${id.length > 4 ? id.substring(id.length - 4) : id}-R';
              final num tot = (o['total'] is num) ? (o['total'] as num) : (num.tryParse(o['total']?.toString() ?? '0') ?? 0);
              final dynamic rawItems = o['items'];
              final List items = (rawItems is List) ? rawItems : [];
              double orderFoodSum = 0.0;
              if (items.isNotEmpty) {
                for (final it in items) {
                  final num p = (it['price'] is num) ? (it['price'] as num) : (num.tryParse(it['price']?.toString() ?? '0') ?? 0);
                  final int q = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
                  orderFoodSum += (p * q).toDouble();
                }
              } else {
                orderFoodSum = tot.toDouble();
              }
              final String itemsDesc = items.isNotEmpty
                  ? items.map((i) => '${i['quantity'] ?? 1}x ${i['name'] ?? 'Dish'}').join(', ')
                  : 'Food Items';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: slateBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 18, color: slateDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(displayId, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: slateDark)),
                              Text('₹${orderFoodSum.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: brandGreen)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(itemsDesc, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_outlined, size: 44, color: slateMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text('No Settled Orders Found', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: slateDark)),
                  const SizedBox(height: 4),
                  Text('Delivered restaurant orders will appear here.', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String val, Color valColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: slateBorder)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: slateDark)),
          Text(val, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: valColor)),
        ],
      ),
    );
  }

  Widget _buildStoreSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          title: Text('Store Open Status', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: slateDark)),
          subtitle: Text(_isStoreOpen ? 'Accepting online orders' : 'Closed for online orders', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
          value: _isStoreOpen,
          activeColor: brandGreen,
          onChanged: (val) {
            setState(() => _isStoreOpen = val);
            HapticFeedback.lightImpact();
          },
        ),
        const Divider(height: 1, color: slateBorder),
        SwitchListTile.adaptive(
          title: Text('Busy Mode (+15m prep delay)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: slateDark)),
          subtitle: Text('Adds extra cooking time during rush', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
          value: _isBusyMode,
          activeColor: brandAmber,
          onChanged: (val) {
            setState(() => _isBusyMode = val);
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }
}