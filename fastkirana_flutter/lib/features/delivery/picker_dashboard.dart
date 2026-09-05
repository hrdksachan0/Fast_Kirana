import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/live_clock_badge.dart';
import '../common/order_edit_modal.dart';
import 'widgets/add_picker_product_modal.dart';

class PickerDashboard extends ConsumerStatefulWidget {
  const PickerDashboard({super.key});

  @override
  ConsumerState<PickerDashboard> createState() => _PickerDashboardState();
}

class _PickerDashboardState extends ConsumerState<PickerDashboard> {
  static List<Map<String, dynamic>> _cachedPickerOrders = [];
  late bool _isLoading = _cachedPickerOrders.isEmpty;
  bool _isRefreshing = false;
  bool _isFetching = false;
  int _refreshCountdown = 30;
  List<Map<String, dynamic>> _orders = _cachedPickerOrders;

  static const String _diskPickerOrdersKey = 'cached_picker_orders_v2';

  Future<void> _loadDiskPickerOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskPickerOrdersKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (list.isNotEmpty && _orders.isEmpty) {
          _cachedPickerOrders = list;
          setState(() {
            _orders = list;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[PickerDashboard] disk load error: $e');
    }
  }

  Future<void> _saveDiskPickerOrders(List<Map<String, dynamic>> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskPickerOrdersKey, jsonEncode(orders));
    } catch (e) {
      debugPrint('[PickerDashboard] disk save error: $e');
    }
  }
  final Map<String, Set<String>> _pickedItemIds = {}; // orderId -> Set of picked itemIds
  String? _updatingOrderId;
  Timer? _autoRefreshTimer;

  static const Color brandOrange = Color(0xFFEA580C);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color bgMain = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadDiskPickerOrders();
    _fetchPickerOrders();
    _initSupabaseRealtime();

    // 30-second calm background refresh (without 1-second full-screen rebuilds)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isFetching) return;
      _fetchPickerOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _initSupabaseRealtime() {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      supabase
          .channel('public:picker_orders_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              _fetchPickerOrders(silent: true);
              HapticFeedback.heavyImpact();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _fetchPickerOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/picker/orders?t=${DateTime.now().millisecondsSinceEpoch}');
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data is List ? response.data : (response.data['orders'] ?? []);
        if (mounted) {
          final filtered = list
              .map((e) => Map<String, dynamic>.from(e))
              .where((o) {
                final s = o['status']?.toString().toUpperCase();
                return s != 'CANCELLED' && s != 'DELIVERED';
              })
              .toList();
          _cachedPickerOrders = filtered;
          _saveDiskPickerOrders(filtered);
          setState(() {
            _orders = filtered;
          });
        }
      }
    } catch (e) {
      debugPrint('[Picker Orders Fetch Error]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _markOrderAsPacked(String orderId) async {
    setState(() => _updatingOrderId = orderId);
    HapticFeedback.mediumImpact();

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch('/api/orders/$orderId', data: {'status': 'PACKED'});
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📦 Order Packed! Rider notified for pickup.', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              backgroundColor: brandGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchPickerOrders(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark order as packed', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  void _toggleItemPicked(String orderId, String itemId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_pickedItemIds.containsKey(orderId)) {
        _pickedItemIds[orderId] = {};
      }
      if (_pickedItemIds[orderId]!.contains(itemId)) {
        _pickedItemIds[orderId]!.remove(itemId);
      } else {
        _pickedItemIds[orderId]!.add(itemId);
      }
    });
  }

  void _openAddGroceryModal() {
    HapticFeedback.selectionClick();
    AddPickerProductModal.show(
      context: context,
      onProductAdded: () {
        _fetchPickerOrders();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _orders.where((o) => o['status'] == 'PENDING' || o['status'] == 'CONFIRMED').length;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: slateDark),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 18))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Picker Dashboard',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Warehouse Item Packing',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: slateMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Bounceable(
            onTap: _openAddGroceryModal,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: brandOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Add Item',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange))
                : Text('$_refreshCountdown' 's', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: slateMuted)),
            onPressed: () => _fetchPickerOrders(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: slateMuted),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out from Picker Console?'),
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
                _buildMetric('Orders to Pack', '$pendingCount', pendingCount > 0 ? brandOrange : slateDark, isAlert: pendingCount > 0),
                const SizedBox(width: 10),
                _buildLiveClockMetric(),
              ],
            ),
          ),
          const Divider(height: 1, color: slateBorder),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: brandOrange))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                              child: const Icon(Icons.check_circle_outline, size: 48, color: slateMuted),
                            ),
                            const SizedBox(height: 16),
                            Text('All Orders Packed! 🎉', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark)),
                            const SizedBox(height: 4),
                            Text('New orders to pick will appear here automatically', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchPickerOrders(),
                        color: brandOrange,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _orders.length,
                          itemBuilder: (context, idx) {
                            final order = _orders[idx];
                            return _buildPickerOrderCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandOrange,
        elevation: 4,
        onPressed: _openAddGroceryModal,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
        label: Text(
          'Add Grocery Item',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLiveClockMetric() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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
              fontSize: Responsive.scaledFontSize(context, 13),
              showSeconds: false,
            ),
            Text('Live Clock', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w700, color: slateMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color col, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? const Color(0xFFFED7AA) : slateBorder),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: col), maxLines: 1),
            Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w700, color: slateMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOrderCard(Map<String, dynamic> order) {
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

    final pickedSet = _pickedItemIds[orderId] ?? {};
    final bool allItemsPicked = items.isNotEmpty && pickedSet.length >= items.length;
    final bool isUpdating = _updatingOrderId == orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: allItemsPicked ? brandGreen : slateBorder, width: allItemsPicked ? 1.5 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#$readableId',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (allItemsPicked ? brandGreen : brandOrange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        allItemsPicked ? 'ALL ITEMS READY' : '${pickedSet.length}/${items.length} PICKED',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: allItemsPicked ? brandGreen : brandOrange),
                      ),
                    ),
                  ],
                ),
                Text('₹${total.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('👤 Customer: $customerName', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateMuted)),
                Bounceable(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => OrderEditModal(
                        order: order,
                        isRestaurant: false,
                        onOrderUpdated: () => _fetchPickerOrders(silent: true),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 14, color: AppDesignSystem.slate700),
                        const SizedBox(width: 4),
                        Text(
                          'Edit / Out of Stock',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: slateBorder),

            // Picking Items Checklist
            ...items.map((item) {
              final String itemId = (item['id'] ?? item['productId'] ?? '').toString();
              final String name = (item['name'] ?? 'Grocery Item').toString();
              final int qty = (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
              final bool isPicked = pickedSet.contains(itemId);

              return Bounceable(
                onTap: () => _toggleItemPicked(orderId, itemId),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPicked ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isPicked ? const Color(0xFFA7F3D0) : slateBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPicked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: isPicked ? brandGreen : slateMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: slateBorder)),
                        child: Text('${qty}x', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w900, color: brandOrange)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: isPicked ? slateMuted : slateDark,
                            decoration: isPicked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: allItemsPicked ? brandGreen : brandOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isUpdating ? null : () => _markOrderAsPacked(orderId),
                child: isUpdating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Mark as Packed & Notify Rider 🛵',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}