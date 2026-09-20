import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../providers/auth_provider.dart';
import '../common/order_edit_modal.dart';
import 'widgets/add_picker_product_modal.dart';
import 'widgets/order_recipient_helper.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/app_confirmation_dialog.dart';

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
  List<Map<String, dynamic>> _orders = _cachedPickerOrders;

  static const String _diskPickerOrdersKey = 'cached_picker_orders_v2';

  String _resolveItemImageUrl(dynamic item) {
    if (item == null || item is! Map) return '';
    final rawImg = item['imageUrl'] ??
        item['image'] ??
        item['image_url'] ??
        (item['product'] is Map ? (item['product']['imageUrl'] ?? item['product']['image'] ?? item['product']['image_url']) : null);
    if (rawImg == null) return '';
    final str = rawImg.toString().trim();
    if (str.isEmpty) return '';
    if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:image')) {
      return str;
    }
    if (str.startsWith('/')) {
      return 'https://www.fastkirana.in$str';
    }
    return '${AppConfig.apiBaseUrl}/$str';
  }

  String _itemEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk') || lower.contains('dahi') || lower.contains('curd')) return '🥛';
    if (lower.contains('bread') || lower.contains('pav')) return '🍞';
    if (lower.contains('egg') || lower.contains('anda')) return '🥚';
    if (lower.contains('butter') || lower.contains('ghee')) return '🧈';
    if (lower.contains('cheese') || lower.contains('paneer')) return '🧀';
    if (lower.contains('apple') || lower.contains('seb')) return '🍎';
    if (lower.contains('banana') || lower.contains('kela')) return '🍌';
    if (lower.contains('potato') || lower.contains('aloo')) return '🥔';
    if (lower.contains('onion') || lower.contains('pyaz')) return '🧅';
    if (lower.contains('tomato') || lower.contains('tamatar')) return '🍅';
    if (lower.contains('oil') || lower.contains('tel')) return '🛢️';
    if (lower.contains('rice') || lower.contains('chawal')) return '🌾';
    if (lower.contains('atta') || lower.contains('flour')) return '🌾';
    if (lower.contains('dal') || lower.contains('pulse')) return '🥣';
    if (lower.contains('maggi') || lower.contains('noodle')) return '🍜';
    if (lower.contains('biscuit') || lower.contains('cookie')) return '🍪';
    if (lower.contains('chips') || lower.contains('kurkure') || lower.contains('namkeen')) return '🍟';
    if (lower.contains('coke') || lower.contains('pepsi') || lower.contains('drink') || lower.contains('juice')) return '🥤';
    if (lower.contains('ice cream') || lower.contains('dessert')) return '🍦';
    if (lower.contains('soap') || lower.contains('shampoo') || lower.contains('wash')) return '🧼';
    return '📦';
  }

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
    NotificationService().registerDeviceToken(ref.read(dioProvider), role: 'PICKER');

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
    if (_isFetching) return;
    _isFetching = true;

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
      _isFetching = false;
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

  void _showLogoutDialog() async {
    final confirm = await AppConfirmationDialog.showLogout(
      context: context,
      title: 'Log Out of Picker?',
      subtitle: 'Are you sure you want to log out from the Picker Console?',
      accountNote: 'Assigned orders and current pick items will stay intact.',
      confirmLabel: 'Log Out',
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      unawaited(ref.read(authProvider.notifier).logout());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _orders.where((o) => o['status'] == 'PENDING' || o['status'] == 'CONFIRMED' || o['status'] == 'PREPARING').length;
    final packedCount = _orders.where((o) => o['status'] == 'PACKED').length;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: slateDark),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            if (!Navigator.canPop(context)) const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA), width: 1.1),
              ),
              child: const Icon(Icons.inventory_2_rounded, size: 18, color: brandOrange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Picker',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: brandGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Packing Station',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w500,
                      color: slateMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Refresh & Sync Action Pill
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              _fetchPickerOrders();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isRefreshing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8, color: brandOrange),
                        )
                      : const Icon(Icons.sync_rounded, size: 13, color: slateMuted),
                  const SizedBox(width: 3),
                  Text(
                    _isRefreshing ? '...' : 'Sync',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 19, color: slateMuted),
            tooltip: 'Logout',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Sub-Header Metric Strip
          _buildMetricStrip(pendingCount, packedCount),

          const Divider(height: 1, color: slateBorder),

          // Orders List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: brandOrange))
                : _orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _fetchPickerOrders(),
                        color: brandOrange,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
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
      floatingActionButton: Bounceable(
        onTap: _openAddGroceryModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEA580C), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: brandOrange.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                'Add Grocery Item',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricStrip(int pendingCount, int packedCount) {
    final bool hasPending = pendingCount > 0;
    final bool hasPacked = packedCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // Pending to Pack Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasPending
                          ? [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)]
                          : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPending ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
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
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: hasPending
                              ? brandOrange.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                          size: 17,
                          color: hasPending ? brandOrange : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$pendingCount',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 18),
                                fontWeight: FontWeight.w900,
                                color: hasPending ? brandOrange : slateDark,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hasPending ? 'To Pack' : 'Queue Clear',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w700,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Ready for Rider Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasPacked
                          ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                          : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPacked ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
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
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: hasPacked
                              ? brandGreen.withValues(alpha: 0.15)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasPacked ? Icons.delivery_dining_rounded : Icons.inventory_2_outlined,
                          size: 17,
                          color: hasPacked ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$packedCount',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 18),
                                fontWeight: FontWeight.w900,
                                color: hasPacked ? const Color(0xFF047857) : slateDark,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hasPacked ? 'Packed' : 'Pickup Rack',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w700,
                                  color: hasPacked ? const Color(0xFF047857) : slateMuted,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Celebratory Glowing Badge
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFFD1FAE5), Color(0xFFECFDF5), Colors.white],
                stops: [0.3, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: brandGreen.withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: brandGreen.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 24),

          // Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'All Orders Packed!',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 20),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              const Text('🎉', style: TextStyle(fontSize: 20)),
            ],
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 8),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your packing station is 100% caught up. Incoming orders will stream in automatically in real time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                color: slateMuted,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 20),

          // Realtime Listening Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: brandGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening for live incoming orders',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w700,
                    color: slateDark,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 28),

          // Quick Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bounceable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _fetchPickerOrders();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 16, color: slateDark),
                      const SizedBox(width: 6),
                      Text(
                        'Check Now',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w700,
                          color: slateDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Bounceable(
                onTap: _openAddGroceryModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: brandOrange),
                      const SizedBox(width: 6),
                      Text(
                        'Add Item',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: brandOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 36),

          // Warehouse fulfillment tip card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fulfillment Pro-Tip',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: slateDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Marking orders as "Packed" instantly notifies delivery riders for swift pickup and keeps dispatch under 10 minutes.',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: slateMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
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

    final recipient = OrderRecipientDetails.fromOrder(order);
    final String customerName = recipient.recipientName;

    final String status = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final bool isPackedStatus = status == 'PACKED';

    final pickedSet = _pickedItemIds[orderId] ?? {};
    final bool allItemsPicked = isPackedStatus || (items.isNotEmpty && pickedSet.length >= items.length);
    final bool isUpdating = _updatingOrderId == orderId;
    final double progressFraction = isPackedStatus ? 1.0 : (items.isEmpty ? 0.0 : (pickedSet.length / items.length).clamp(0.0, 1.0));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPackedStatus ? const Color(0xFF10B981) : (allItemsPicked ? brandGreen : const Color(0xFFE2E8F0)),
          width: isPackedStatus || allItemsPicked ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPackedStatus || allItemsPicked)
                ? brandGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header (Zero-Overflow Wrap & Price)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isPackedStatus ? const Color(0xFF064E3B) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$readableId',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isPackedStatus ? const Color(0xFF047857) : (allItemsPicked ? brandGreen : brandOrange)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isPackedStatus ? const Color(0xFF047857) : (allItemsPicked ? brandGreen : brandOrange)).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isPackedStatus
                              ? '📦 PACKED • READY'
                              : (allItemsPicked ? 'ALL ITEMS READY' : '${pickedSet.length}/${items.length} PICKED'),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w900,
                            color: isPackedStatus ? const Color(0xFF047857) : (allItemsPicked ? brandGreen : brandOrange),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${total.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Picking Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPackedStatus ? const Color(0xFF059669) : (allItemsPicked ? brandGreen : brandOrange),
                ),
                minHeight: 5,
              ),
            ),

            const SizedBox(height: 10),

            // Customer Info & Out of stock edit button (Zero-Overflow)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(recipient.isOrderForSomeone ? '🎁' : '👤', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerName,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: recipient.isOrderForSomeone ? const Color(0xFFC2410C) : slateMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recipient.isOrderForSomeone) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDBA74), width: 0.6),
                          ),
                          child: Text(
                            'For Other',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 8.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (!isPackedStatus)
                  Bounceable(
                    onTap: () {
                      final rawRestId = order['restaurantId']?.toString() ?? order['restaurant_id']?.toString();
                      final rawShopName = (order['shopName'] ?? order['shop_name'])?.toString();
                      final rId = (order['readableId']?.toString() ?? '').toUpperCase();
                      final isRestOrder = (rawRestId != null && rawRestId.isNotEmpty && rawRestId != 'null') ||
                          rId.endsWith('-R') ||
                          rId.contains('-R-') ||
                          (order['orderType']?.toString().toUpperCase() == 'RESTAURANT') ||
                          (rawShopName != null && RestaurantRegistry.find(rawShopName) != null) ||
                          items.any((it) {
                            final itName = (it is Map ? it['name'] : null)?.toString();
                            final itRestId = (it is Map ? (it['restaurantId'] ?? it['restaurant_id']) : null)?.toString();
                            return (itRestId != null && itRestId.isNotEmpty && itRestId != 'null') ||
                                RestaurantRegistry.isFoodDishName(itName);
                          });

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => OrderEditModal(
                          order: order,
                          isRestaurant: isRestOrder,
                          restaurantId: rawRestId ?? (rawShopName != null ? RestaurantRegistry.find(rawShopName)?.id : null),
                          onOrderUpdated: () => _fetchPickerOrders(silent: true),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                            'Edit / OOS',
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

            const Divider(height: 18, color: slateBorder),

            // Picking Items Checklist
            ...items.map((item) {
              final String itemId = (item['id'] ?? item['productId'] ?? '').toString();
              final String name = (item['name'] ?? item['title'] ?? 'Grocery Item').toString();
              final int qty = (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
              final num unitPrice = (item['price'] is num)
                  ? (item['price'] as num)
                  : (num.tryParse(item['price']?.toString() ?? '0') ?? 0);
              final num lineTotal = (item['total'] is num)
                  ? (item['total'] as num)
                  : (unitPrice * qty);
              final bool isPicked = isPackedStatus || pickedSet.contains(itemId);
              final String? variant = item['selectedVariant'] ?? item['variant'] ?? item['unit'];
              final String imgUrl = _resolveItemImageUrl(item);

              return Bounceable(
                onTap: isPackedStatus ? null : () => _toggleItemPicked(orderId, itemId),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPicked ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPicked ? const Color(0xFFA7F3D0) : slateBorder,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Picking Checkbox
                      Icon(
                        isPicked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: isPicked ? brandGreen : slateMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 8),

                      // 2. Product Photo Thumbnail (48x48 rounded container)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPicked ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Center(
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 1.8),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Center(
                                      child: Text(
                                        _itemEmoji(name),
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _itemEmoji(name),
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. Quantity Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPicked ? const Color(0xFFD1FAE5) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPicked ? const Color(0xFFA7F3D0) : slateBorder,
                          ),
                        ),
                        child: Text(
                          '${qty}x',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w900,
                            color: isPicked ? const Color(0xFF047857) : brandOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 4. Product Name & Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w700,
                                color: isPicked ? slateMuted : slateDark,
                                decoration: isPicked ? TextDecoration.lineThrough : null,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (variant != null && variant.toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                variant.toString().trim(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                              ),
                            ] else if (unitPrice > 0 && qty > 1) ...[
                              const SizedBox(height: 1),
                              Text(
                                '₹${unitPrice.toInt()} each',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 5. Total Price Pill
                      if (lineTotal > 0 || unitPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '₹${lineTotal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w800,
                              color: isPicked ? slateMuted : const Color(0xFF0F172A),
                              decoration: isPicked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),

            // Action Button (Responsive Layout)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPackedStatus
                      ? const Color(0xFF059669)
                      : (allItemsPicked ? brandGreen : brandOrange),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (isUpdating || isPackedStatus) ? null : () => _markOrderAsPacked(orderId),
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPackedStatus
                                ? Icons.inventory_2_rounded
                                : (allItemsPicked ? Icons.check_circle_rounded : Icons.inventory_2_rounded),
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isPackedStatus
                                    ? 'Packed • Waiting for Rider 🛵'
                                    : (allItemsPicked
                                        ? 'Complete & Notify Rider 🛵'
                                        : 'Mark Packed & Notify Rider 🛵'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                              ),
                            ),
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
