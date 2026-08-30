import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/responsive.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/rider_location_service.dart';
import '../../widgets/brand_button.dart';

class DeliveryDashboard extends ConsumerStatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  ConsumerState<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends ConsumerState<DeliveryDashboard> with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _activeTabIndex = 0; // 0: Deliveries, 1: Wallet, 2: History

  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _walletInfo;
  Timer? _autoRefreshTimer;
  int _refreshCountdown = 30;
  String? _updatingOrderId;
  String? _currentUserId;

  late TabController _tabController;
  late ConfettiController _confettiController;
  final RiderLocationService _locationService = RiderLocationService();

  static const Color brandGreen = Color(0xFF00A344);
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _activeTabIndex = _tabController.index);
    });

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadUserInfo();
    _fetchOrders();
    _fetchWallet();

    // 30-second periodic auto-refresh countdown
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id') ?? prefs.getString('delivery_user_id') ?? 'rider_1';
    });
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    else setState(() => _isRefreshing = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/delivery/orders');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> raw = response.data is List ? response.data : (response.data['orders'] ?? []);
        final parsed = raw.map((e) => Map<String, dynamic>.from(e)).toList();

        if (mounted) {
          setState(() {
            _orders = parsed;
            _isLoading = false;
            _isRefreshing = false;
          });

          _manageGpsTrackingLifecycle(parsed);
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Fetch orders error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchWallet() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/delivery/wallet');
      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _walletInfo = Map<String, dynamic>.from(response.data);
          });
        }
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Fetch wallet error: $e');
    }
  }

  /// Automatically start or stop GPS location streaming based on active SHIPPED deliveries
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

  /// Update Order Status (e.g. PACKED -> SHIPPED, or SHIPPED -> DELIVERED)
  Future<void> _updateOrderStatus(String orderId, String newStatus, {Map<String, dynamic>? extra}) async {
    setState(() => _updatingOrderId = orderId);
    HapticFeedback.mediumImpact();

    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'status': newStatus,
        if (extra != null) ...extra,
      };

      final res = await dio.patch('/api/orders/$orderId', data: payload);
      if (res.statusCode == 200) {
        if (newStatus == 'DELIVERED') {
          _confettiController.play();
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Order marked DELIVERED successfully!'),
              backgroundColor: brandGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (newStatus == 'SHIPPED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛵 Order Picked Up! Live GPS tracking is now ACTIVE.'),
              backgroundColor: Color(0xFF2563EB),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        await _fetchOrders(silent: true);
        await _fetchWallet();
      }
    } catch (e) {
      debugPrint('[DeliveryDashboard] Status update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  /// Open Google Maps Turn-by-Turn Navigation
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

  /// Show Doorstep Dynamic UPI QR Modal
  void _showDoorstepUpiQrModal(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final upiVpa = '7054470303@paytm';
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
                    Text('Doorstep UPI QR Collection', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark)),
                    Text('Order #$orderNum • ₹${total.toInt()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: slateMuted)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: slateDark),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // QR Display Card
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
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: slateMuted), textAlign: TextAlign.center),
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

  @override
  Widget build(BuildContext context) {
    final activeDeliveries = _orders.where((o) => o['status'] == 'SHIPPED').toList();
    final pendingPickups = _orders.where((o) => ['CONFIRMED', 'PREPARING', 'PACKED'].contains(o['status'])).toList();
    final completedToday = _orders.where((o) => o['status'] == 'DELIVERED').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isOnline ? Icons.two_wheeler_rounded : Icons.do_not_disturb_on_rounded,
                color: _isOnline ? brandGreen : primaryRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rider Operations',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark),
                ),
                Text(
                  _isOnline ? 'Online • Auto-refresh in ${_refreshCountdown}s' : 'Offline',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: slateMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Online Toggle Switch
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _isOnline,
              activeColor: brandGreen,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _isOnline = val);
                if (!val) {
                  _locationService.stopTracking();
                } else {
                  _manageGpsTrackingLifecycle(_orders);
                }
              },
            ),
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: brandGreen))
                : const Icon(Icons.refresh_rounded, color: slateDark),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchOrders();
              _fetchWallet();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: brandGreen,
          unselectedLabelColor: slateMuted,
          indicatorColor: brandGreen,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Deliveries (${activeDeliveries.length + pendingPickups.length})'),
            const Tab(text: 'Wallet & COD'),
            Tab(text: 'History (${completedToday.length})'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: brandGreen))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Active Deliveries & Pending Pickups
                    _buildDeliveriesTab(activeDeliveries, pendingPickups),

                    // Tab 2: Wallet & COD Summary
                    _buildWalletTab(),

                    // Tab 3: History
                    _buildHistoryTab(completedToday),
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
    );
  }

  /// Tab 1: Deliveries & Pickups
  Widget _buildDeliveriesTab(List<Map<String, dynamic>> activeDeliveries, List<Map<String, dynamic>> pendingPickups) {
    if (!_isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.power_settings_new_rounded, size: 56, color: slateMuted),
              const SizedBox(height: 12),
              Text('You are currently Offline', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark)),
              const SizedBox(height: 4),
              Text('Switch the toggle above to go online and receive delivery tasks.', style: GoogleFonts.inter(fontSize: 12, color: slateMuted), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (activeDeliveries.isEmpty && pendingPickups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.done_all_rounded, size: 48, color: brandGreen),
              ),
              const SizedBox(height: 16),
              Text('No Active Deliveries Right Now', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark)),
              const SizedBox(height: 4),
              Text('New orders will appear here automatically when packed by the store.', style: GoogleFonts.inter(fontSize: 12, color: slateMuted), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Active Out-For-Delivery Orders
          if (activeDeliveries.isNotEmpty) ...[
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: primaryRed, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('ACTIVE DELIVERIES (${activeDeliveries.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: slateDark, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 10),
            ...activeDeliveries.map((order) => _buildActiveDeliveryCard(order)),
            const SizedBox(height: 18),
          ],

          // Section 2: Pending Pickups from Store
          if (pendingPickups.isNotEmpty) ...[
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('READY FOR PICKUP (${pendingPickups.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: slateDark, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 10),
            ...pendingPickups.map((order) => _buildPendingPickupCard(order)),
          ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE20A22).withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: slateDark, borderRadius: BorderRadius.circular(6)),
                child: Text('#$orderNum', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCod ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isCod ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  isCod ? 'COLLECT COD: ₹${total.toInt()}' : 'PAID ONLINE (PREPAID)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isCod ? const Color(0xFFB45309) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Info Row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(21)),
                child: const Center(child: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer['name'] ?? 'Customer', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: slateDark)),
                    Text(customer['phone'] ?? 'No phone provided', style: GoogleFonts.inter(fontSize: 11.5, color: slateMuted)),
                  ],
                ),
              ),
              if (customer['phone'] != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.phone_rounded, color: brandGreen, size: 18),
                  ),
                  onPressed: () => launchUrl(Uri.parse('tel:${customer['phone']}')),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Address & Navigation Launcher
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: slateBorder)),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: primaryRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address?['formattedAddress'] ?? '${address?['houseNo'] ?? ''} ${address?['street'] ?? ''} ${address?['area'] ?? 'Ghatampur'}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: slateDark, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => _openGoogleMapsNavigation(lat, lng, customer['name'] ?? 'Customer'),
                  icon: const Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                  label: Text('Navigate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Doorstep QR (if COD) & Mark Delivered
          Row(
            children: [
              if (isCod) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDoorstepUpiQrModal(order),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 15, color: Color(0xFF2563EB)),
                    label: Text('Show UPI QR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _updateOrderStatus(orderId, 'DELIVERED', extra: {
                            'deliveryLat': lat,
                            'deliveryLng': lng,
                          }),
                  icon: isUpdating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                  label: Text(
                    isCod ? 'Delivered (Cash Collected)' : 'Mark Delivered',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pending Pickup Card from Store/Warehouse
  Widget _buildPendingPickupCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final shopName = order['shopName'] ?? 'FastKirana Store';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final items = (order['items'] as List<dynamic>?) ?? [];
    final isUpdating = _updatingOrderId == orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #$orderNum', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800, color: slateDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                child: Text('READY FOR PICKUP', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFFB45309))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(shopName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark)),
          Text('${items.length} items • ₹${total.toInt()} bill value', style: GoogleFonts.inter(fontSize: 11.5, color: slateMuted)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isUpdating
                ? null
                : () => _updateOrderStatus(orderId, 'SHIPPED', extra: {
                      'deliveryUserId': _currentUserId,
                    }),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isUpdating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Pick Up & Start Delivery (Activate GPS)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Tab 2: Rider Wallet & COD Management
  Widget _buildWalletTab() {
    final wallet = _walletInfo?['wallet'] ?? {};
    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 2000.0;
    final isLocked = wallet['isLocked'] == true;
    final isWarning = wallet['isWarning'] == true;
    final todayCodOrders = (_walletInfo?['todayCodOrders'] as List<dynamic>?) ?? [];
    final recentDeposits = (_walletInfo?['recentDeposits'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Limit Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLocked
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : (isWarning ? [const Color(0xFFF59E0B), const Color(0xFFD97706)] : [const Color(0xFF0F172A), const Color(0xFF1E293B)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cash in Hand', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('LIMIT ₹${cashLimit.toInt()}', style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('₹${cashInHand.toInt()}', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: math.min(1.0, cashInHand / math.max(1.0, cashLimit)),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(isLocked ? Colors.white : (isWarning ? const Color(0xFFFDE68A) : brandGreen)),
                    minHeight: 6,
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(height: 10),
                  Text('⚠️ Limit Exceeded: Deposit cash at dark store hub to accept more COD orders.',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Today's COD Deliveries
          Text("Today's COD Collections (${todayCodOrders.length})", style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 10),
          if (todayCodOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: slateBorder)),
              child: Center(child: Text('No COD cash collected today yet.', style: GoogleFonts.inter(fontSize: 12, color: slateMuted))),
            )
          else
            ...todayCodOrders.map((o) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: slateBorder)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${o['readableId'] ?? o['id']}', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark)),
                      Text('₹${(o['total'] as num).toInt()}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: brandGreen)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  /// Tab 3: History & Daily Performance
  Widget _buildHistoryTab(List<Map<String, dynamic>> completed) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Overview Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: slateBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Completed Today', style: GoogleFonts.inter(fontSize: 11, color: slateMuted)),
                      const SizedBox(height: 4),
                      Text('${completed.length}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: slateDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: slateBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Earnings', style: GoogleFonts.inter(fontSize: 11, color: slateMuted)),
                      const SizedBox(height: 4),
                      Text('₹${completed.length * 45}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: brandGreen)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Delivered Orders', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 10),
          ...completed.map((order) {
            final orderId = order['id']?.toString() ?? '';
            final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
            final total = (order['total'] as num?)?.toDouble() ?? 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: slateBorder)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #$orderNum', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800, color: slateDark)),
                      Text(order['shopName'] ?? 'FastKirana', style: GoogleFonts.inter(fontSize: 11, color: slateMuted)),
                    ],
                  ),
                  Text('₹${total.toInt()}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}