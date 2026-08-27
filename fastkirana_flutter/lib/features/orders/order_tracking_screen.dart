import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../profile/add_review_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Order? _order;
  bool _isLoading = true;
  Timer? _pollTimer;
  HttpClientRequest? _sseRequest;
  bool _sseConnected = false;
  Timer? _sseReconnectTimer;
  StreamSubscription<String>? _sseLineSubscription;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  /// SSE endpoint on Next.js (Railway) — same backend that handles order REST APIs.
  /// Admin status changes are broadcast via SSE so we get real-time updates here.
  static const String _sseEndpoint = '/api/sse/orders';
  String get _sseUrl => '$_sseEndpoint?id=${widget.orderId}';

  @override
  void initState() {
    super.initState();
    _fetchLiveOrder();
    _connectSSE();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _silentPollOrder();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sseReconnectTimer?.cancel();
    _closeSSE();
    super.dispose();
  }

  void _closeSSE() {
    _sseLineSubscription?.cancel();
    _sseLineSubscription = null;
    _sseRequest = null;
    _sseConnected = false;
  }

  Future<void> _connectSSE() async {
    if (mounted) setState(() {});
    try {
      final dio = ref.read(dioProvider);
      final baseOptions = dio.options;

      final fullUrl = Uri.parse(baseOptions.baseUrl + _sseUrl);
      final client = HttpClient();
      final request = await client.getUrl(fullUrl);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close();

      if (response.statusCode == 200) {
        _sseConnected = true;
        if (mounted) setState(() {});

        _sseLineSubscription = response
            .transform(const Utf8Decoder())
            .transform(const LineSplitter())
            .listen(
              (line) => _handleSseLine(line),
              onDone: () {
                debugPrint('SSE connection closed');
                _sseConnected = false;
                if (mounted) setState(() {});
                _scheduleSseReconnect();
              },
              onError: (error) {
                debugPrint('SSE error: $error');
                _sseConnected = false;
                if (mounted) setState(() {});
                _scheduleSseReconnect();
              },
            );
      } else {
        debugPrint('SSE rejected: HTTP ${response.statusCode}');
        _sseConnected = false;
        if (mounted) setState(() {});
        _scheduleSseReconnect();
      }
    } catch (e) {
      debugPrint('SSE connection failed: $e');
      _sseConnected = false;
      if (mounted) setState(() {});
      _scheduleSseReconnect();
    }
  }

  void _handleSseLine(String line) {
    if (line.startsWith('data:')) {
      final dataStr = line.substring(5).trim();
      if (dataStr.isEmpty) return;
      try {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        debugPrint('SSE data: $data');
        final serverStatus = data['status']?.toString().toLowerCase();
        if (serverStatus != null && mounted) {
          OrderStatus? newStatus;
          try { newStatus = OrderStatus.values.firstWhere((e) => e.name.toLowerCase() == serverStatus); } catch (_) {}
          if (_order == null || _order!.status != newStatus) {
            _fetchLiveOrder();
          }
        }
      } catch (e) {
        debugPrint('SSE parse error: $e');
      }
    }
  }

  void _scheduleSseReconnect() {
    _sseReconnectTimer?.cancel();
    _sseReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _connectSSE();
    });
  }

  Future<void> _silentPollOrder() async {
    if (_sseConnected) return;
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.getOrder(widget.orderId);
      if (mounted && order != null) {
        setState(() { _order = order; });
      }
    } catch (_) {}
  }

  Future<void> _fetchLiveOrder() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.getOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getStatusStep(OrderStatus? status) {
    if (status == null) return 1;
    switch (status) {
      case OrderStatus.pending: return 0;
      case OrderStatus.confirmed: return 1;
      case OrderStatus.packed: return 2;
      case OrderStatus.shipped: return 3;
      case OrderStatus.delivered: return 4;
      case OrderStatus.cancelled: return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStep = _getStatusStep(_order?.status);
    final isDelivered = _order?.status == OrderStatus.delivered || statusStep >= 4;
    final isPaid = _order?.paymentStatus == 'PAID';
    final displayNum = _order?.displayId ?? (_order?.readableId ?? widget.orderId);
    final cleanDisplayId = '#${displayNum.replaceAll('#', '').replaceAll('FK-', '').trim()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Your Delivery',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              cleanDisplayId,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: slateMuted),
            ),
          ],
        ),
        actions: [
          // WebSocket live indicator
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _sseConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _sseConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sseConnected ? const Color(0xFF00A344) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _sseConnected ? 'LIVE' : 'SYNC',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: _sseConnected ? const Color(0xFF059669) : const Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: slateDark),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchLiveOrder();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandGreen))
          : ResponsiveContainer(
              maxWidth: Responsive.defaultMaxContentWidth,
              fillHeight: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isPaid && !isDelivered && _order?.deliveryMethod != 'PICKUP') ...[
                      _buildPayOnlineCard(),
                      const SizedBox(height: 12),
                    ],
                    _buildTrackingHeroCard(statusStep, isDelivered, cleanDisplayId),
                    const SizedBox(height: 12),
                    if (_order?.deliveryMethod != 'PICKUP') ...[
                      _buildDeliveryDestinationCard(),
                      const SizedBox(height: 12),
                    ] else ...[
                      _buildPickupLocationCard(),
                      const SizedBox(height: 12),
                    ],
                    _buildOrderReceiptCard(),
                    const SizedBox(height: 14),
                    if (isDelivered) ...[
                      _buildReviewCard(),
                      const SizedBox(height: 12),
                    ],
                    _buildSupportFooter(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPayOnlineCard() {
    final grandTotal = _order?.total ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00A344).withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A344).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PAY ONLINE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF00A344), letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 11, color: Color(0xFF16A34A)),
                    const SizedBox(width: 3),
                    Text('Instant & Secure', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Pay ₹${grandTotal.toInt()} Online',
              style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 3),
          Text(
            'Order is currently set to Cash on Delivery. You can pay online using Google Pay, PhonePe, Paytm, BHIM, UPI or Cards.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), height: 1.3),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: brandGreen,
                  content: const Text('Opening secure Razorpay UPI payment gateway...'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00A344), Color(0xFF008736)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: const Color(0xFF00A344).withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text('Pay ₹${grandTotal.toInt()} Online Now',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingHeroCard(int statusStep, bool isDelivered, String cleanDisplayId) {
    String statusTitle = 'Order Confirmed';
    String statusDesc = 'Your order has been received and is being prepared fresh.';
    Color statusBadgeColor = const Color(0xFF2563EB);
    Color statusBadgeBg = const Color(0xFFEFF6FF);
    String statusBadgeText = 'CONFIRMED';

    if (isDelivered) {
      statusTitle = 'Order Delivered';
      statusDesc = 'Package handed over safely at your delivery address.';
      statusBadgeColor = const Color(0xFF16A34A);
      statusBadgeBg = const Color(0xFFDCFCE7);
      statusBadgeText = 'DELIVERED';
    } else if (statusStep >= 3) {
      statusTitle = 'Rider On The Way';
      statusDesc = 'Your delivery partner has picked up the order and is on the way.';
      statusBadgeColor = const Color(0xFF2563EB);
      statusBadgeBg = const Color(0xFFEFF6FF);
      statusBadgeText = 'OUT FOR DELIVERY';
    } else if (statusStep == 2) {
      statusTitle = 'Order Packed & Sealed';
      statusDesc = 'Items packed and assigned to delivery partner.';
      statusBadgeColor = const Color(0xFFD97706);
      statusBadgeBg = const Color(0xFFFEF3C7);
      statusBadgeText = 'PACKED';
    }

    final destination = _order?.customerAddress ?? 'Ghatampur Express Zone';
    final riderName = _order?.deliveryBoyName ?? 'Delivery Partner Assigned';
    final riderPhone = _order?.deliveryBoyPhone ?? '+917054470303';
    final cleanPhone = riderPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: slateDark, borderRadius: BorderRadius.circular(6)),
                child: Text(cleanDisplayId,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBadgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(statusBadgeText,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: statusBadgeColor, letterSpacing: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Delivery to: $destination',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(statusTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: slateDark, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(statusDesc, style: GoogleFonts.inter(fontSize: 12, color: slateMuted, height: 1.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: primaryRed),
                    const SizedBox(width: 4),
                    Text(isDelivered ? 'Delivered' : 'Estimated: 10-15 min',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: primaryRed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildHorizontalStepper(statusStep, isDelivered),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBAE6FD))),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 13, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('We will notify you when your order gets closer to your doorstep',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildStoreProgressCard(),
          const SizedBox(height: 12),
          _buildDeliveryExecutiveCard(riderName, cleanPhone),
        ],
      ),
    );
  }

  Widget _buildHorizontalStepper(int statusStep, bool isDelivered) {
    return Row(
      children: [
        _buildStepperNode(label: 'Placed', icon: Icons.check_rounded, isCompleted: statusStep >= 0, isActive: statusStep == 0),
        _buildStepperLine(statusStep >= 1),
        _buildStepperNode(label: 'Preparing', icon: Icons.inventory_2_outlined, isCompleted: statusStep >= 1, isActive: statusStep == 1 || statusStep == 2),
        _buildStepperLine(statusStep >= 3),
        _buildStepperNode(label: 'On The Way', icon: Icons.two_wheeler_rounded, isCompleted: statusStep >= 3, isActive: statusStep == 3, isRedAccent: statusStep == 3),
        _buildStepperLine(statusStep >= 4),
        _buildStepperNode(label: 'Delivered', icon: Icons.done_all_rounded, isCompleted: isDelivered || statusStep >= 4, isActive: isDelivered),
      ],
    );
  }

  Widget _buildStepperNode({required String label, required IconData icon, required bool isCompleted, required bool isActive, bool isRedAccent = false}) {
    Color circleColor = const Color(0xFFF1F5F9);
    Color iconColor = const Color(0xFF94A3B8);
    if (isRedAccent) { circleColor = primaryRed; iconColor = Colors.white; }
    else if (isCompleted || isActive) { circleColor = const Color(0xFF00A344); iconColor = Colors.white; }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: circleColor,
            boxShadow: isActive ? [BoxShadow(color: circleColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))] : null,
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              color: isActive ? (isRedAccent ? primaryRed : const Color(0xFF00A344)) : (isCompleted ? slateDark : slateMuted),
            )),
      ],
    );
  }

  Widget _buildStepperLine(bool isCompleted) {
    return Expanded(
      child: Container(height: 2.5, margin: const EdgeInsets.only(bottom: 16), color: isCompleted ? const Color(0xFF00A344) : const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildStoreProgressCard() {
    final shopName = _order?.shopName?.isNotEmpty == true ? _order!.shopName! : 'FastKirana Darkstore';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3E8FF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text('STORE PREPARATION PROGRESS',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF7E22CE), letterSpacing: 0.4)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(4)),
                child: Text('1 DELIVERY',
                    style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF6B21A8))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE9D5FF))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 15, color: Color(0xFF7E22CE)),
                    const SizedBox(width: 6),
                    Text(shopName, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: slateDark)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                  child: Text('PACKED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryExecutiveCard(String riderName, String cleanPhone) {
    const defaultRiderName = 'Delivery Partner (FastKirana Express)';
    const defaultRiderPhone = '+91 96965 03759';
    const defaultRiderTel = '+919696503759';

    final effectiveName = riderName.isNotEmpty && riderName != 'Delivery Partner Assigned'
        ? riderName
        : defaultRiderName;
    final effectivePhone = cleanPhone.isNotEmpty && cleanPhone != '7054470303'
        ? cleanPhone
        : defaultRiderTel;
    final displayPhone = effectivePhone.startsWith('+91')
        ? '+91 ${effectivePhone.replaceFirst('+91', '').trim()}'
        : '+91 $effectivePhone';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                ),
                child: const Center(
                  child: Text('🛵', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DELIVERY PARTNER ASSIGNED',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF15803D),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF15803D)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectiveName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                      ),
                    ),
                    Text(
                      'Official FastKirana Rider • $displayPhone',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              launchUrl(Uri.parse('tel:$effectivePhone'));
            },
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A344), Color(0xFF008736)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A344).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Call Rider ($displayPhone)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDestinationCard() {
    final destination = (_order?.customerAddress != null && _order!.customerAddress!.trim().isNotEmpty)
        ? _order!.customerAddress!
        : 'Ghatampur Delivery Zone, Kanpur Nagar - 209206';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: primaryRed, size: 16),
              const SizedBox(width: 6),
              Text(
                'Delivery Destination',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            destination,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              final query = Uri.encodeComponent(destination);
              launchUrl(
                Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.navigation_outlined, size: 14, color: Color(0xFF047857)),
                  const SizedBox(width: 6),
                  Text(
                    'Locate Delivery Address on Google Maps',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text('Pickup Counter: FastKirana Darkstore',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF92400E))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Station Road Market, Ghatampur • Show Order ID at counter',
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB45309))),
        ],
      ),
    );
  }

  Widget _buildOrderReceiptCard() {
    final items = _order?.items ?? [];
    final subtotal = _order?.subtotal ?? 0.0;
    final deliveryFee = _order?.deliveryFee ?? 0.0;
    final miscFee = _order?.miscFee ?? 5.0;
    final discount = _order?.discount ?? 0.0;
    final grandTotal = _order?.total ?? (subtotal + deliveryFee + miscFee - discount);
    final isPaid = _order?.paymentStatus == 'PAID';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('ORDER RECEIPT',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark, letterSpacing: 0.3)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                child: Text(isPaid ? 'PAYMENT: ONLINE (PAID)' : 'PAYMENT: COD (CASH ON DELIVERY)',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FASTKIRANA GROCERY & RESTAURANT',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: slateMuted, letterSpacing: 0.4)),
                Text('${items.length} ${items.length == 1 ? 'ITEM' : 'ITEMS'}',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: slateMuted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Row(
              children: [
                const Text('', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${item.name}${item.quantity > 1 ? ' x ${item.quantity}' : ''}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('₹${(item.price * item.quantity).toInt()}',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: slateDark)),
              ],
            ),
          )),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildReceiptRow('Subtotal', '₹${subtotal.toInt()}'),
          const SizedBox(height: 5),
          _buildReceiptRow('Delivery Charge', deliveryFee == 0.0 ? 'FREE' : '₹${deliveryFee.toInt()}', isFree: deliveryFee == 0.0),
          const SizedBox(height: 5),
          _buildReceiptRow('Packaging & Handling Fee', '₹${miscFee.toInt()}'),
          if (discount > 0) ...[
            const SizedBox(height: 5),
            _buildReceiptRow('Discount', '-₹${discount.toInt()}', isDiscount: true),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GRAND TOTAL',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark, letterSpacing: 0.3)),
              Text('₹${grandTotal.toInt()}',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: primaryRed, letterSpacing: -0.3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: (isFree || isDiscount) ? FontWeight.w800 : FontWeight.w700,
              color: isFree ? const Color(0xFF16A34A) : (isDiscount ? primaryRed : slateDark),
            )),
      ],
    );
  }

  Widget _buildReviewCard() {
    return GestureDetector(
      onTap: () {
        final firstItemName = (_order?.items?.isNotEmpty == true) ? _order!.items!.first.name : 'FastKirana Order';
        Navigator.push(context, FadeSlideRoute(page: AddReviewScreen(productName: firstItemName, restaurantId: _order?.restaurantId)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(
          children: [
            const Text('', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How was your order experience?',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E))),
                  Text('Leave a review to help us serve you better',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFB45309))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF92400E)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.headset_mic_outlined, size: 16, color: slateMuted),
              const SizedBox(width: 8),
              Text('Need help with this order?', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: slateDark)),
            ],
          ),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:+917054470303')),
            child: Text('Call Support',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: brandGreen)),
          ),
        ],
      ),
    );
  }
}
