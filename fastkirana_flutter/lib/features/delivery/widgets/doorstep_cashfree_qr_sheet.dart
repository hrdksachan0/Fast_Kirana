import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/customer_sound_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../providers/store_settings_provider.dart';

/// Doorstep Dynamic UPI QR Bottom Sheet with Auto-Detection, Virtual Soundbox & Fallback Control
class DoorstepCashfreeQrSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;
  final String orderNum;
  final double total;
  final Future<void> Function(Map<String, dynamic> extra) onConfirmPaid;

  const DoorstepCashfreeQrSheet({
    super.key,
    required this.order,
    required this.orderId,
    required this.orderNum,
    required this.total,
    required this.onConfirmPaid,
  });

  @override
  ConsumerState<DoorstepCashfreeQrSheet> createState() => _DoorstepCashfreeQrSheetState();
}

class _DoorstepCashfreeQrSheetState extends ConsumerState<DoorstepCashfreeQrSheet> with TickerProviderStateMixin {
  int _selectedTab = 0; // 0: ⚡ Auto-Verify (Razorpay QR), 1: 🏦 Normal UPI (Fallback)
  bool _isLoading = true;
  bool _isPaid = false;
  String _razorpayQrUrl = '';
  String _directUpiQrUrl = '';
  String _qrImageUrl = '';
  String _upiVpa = '';
  bool _isCombined = false;
  double _combinedTotal = 0.0;
  String _displayId = '';
  String _riderName = '';
  Timer? _pollTimer;
  Timer? _autoCompleteTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isCompleting = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _successController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successScaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeOutQuad),
    );

    _initInstantFallbackQr();
    _fetchQrData();
    _startPolling();
    _subscribeRealtime();
  }

  void _initInstantFallbackQr() {
    try {
      final settings = ref.read(storeSettingsProvider).valueOrNull;
      final vpa = settings?.storeUpiVpa.isNotEmpty == true ? settings!.storeUpiVpa : '7054470303-2@ibl';
      final payee = Uri.encodeComponent('FastMinute');
      final note = Uri.encodeComponent('Order #${widget.orderNum}');
      final upiUri = 'upi://pay?pa=$vpa&pn=$payee&am=${widget.total.toStringAsFixed(2)}&cu=INR&tn=$note';
      final fallbackQr = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiUri)}';

      _qrImageUrl = fallbackQr;
      _directUpiQrUrl = fallbackQr;
      _upiVpa = vpa;
    } catch (_) {}
  }

  void _subscribeRealtime() {
    try {
      final sb = SupabaseService.client;
      if (sb == null) return;
      final chName = 'order-payment-${widget.orderId}';
      _realtimeChannel = sb.channel(chName);
      _realtimeChannel!.onBroadcast(
        event: 'PAYMENT_RECEIVED',
        callback: (payload) {
          debugPrint('[DoorstepQR] Realtime PAYMENT_RECEIVED broadcast caught: $payload');
          if (mounted && !_isPaid) {
            _onPaymentReceived();
          }
        },
      ).subscribe();
    } catch (e) {
      debugPrint('[DoorstepQR] Error subscribing to Supabase realtime: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    _pollTimer?.cancel();
    _autoCompleteTimer?.cancel();
    if (_realtimeChannel != null) {
      SupabaseService.unsubscribe(_realtimeChannel);
    }
    super.dispose();
  }

  double get _effectiveTotal => _combinedTotal > 0 ? _combinedTotal : widget.total;
  String get _effectiveDisplayId => _displayId.isNotEmpty ? _displayId : widget.orderNum;

  Future<void> _fetchQrData() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/delivery/orders/${widget.orderId}/qr?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null && mounted) {
        final data = res.data;
        final status = data['paymentStatus']?.toString().toUpperCase();
        setState(() {
          _razorpayQrUrl = data['razorpayQrUrl']?.toString() ?? '';
          _directUpiQrUrl = data['directUpiQrUrl']?.toString() ?? '';
          _qrImageUrl = data['qrImageUrl']?.toString() ?? '';
          _upiVpa = data['upiVpa']?.toString() ?? '';
          _isCombined = data['isCombined'] == true;
          _combinedTotal = (data['combinedTotal'] as num?)?.toDouble() ??
              (data['amount'] as num?)?.toDouble() ??
              widget.total;
          _displayId = data['readableId']?.toString() ?? widget.orderNum;
          _riderName = data['riderName']?.toString() ?? '';
          _isLoading = false;
        });

        if (status == 'PAID' && !_isPaid) {
          _onPaymentReceived();
        }
      }
    } catch (e) {
      if (mounted) {
        final settings = ref.read(storeSettingsProvider).valueOrNull;
        final vpa = settings?.storeUpiVpa.isNotEmpty == true ? settings!.storeUpiVpa : '7054470303-2@ibl';
        final payee = Uri.encodeComponent('FastMinute');
        final note = Uri.encodeComponent('Order #${widget.orderNum}');
        final upiUri = 'upi://pay?pa=$vpa&pn=$payee&am=${widget.total.toStringAsFixed(2)}&cu=INR&tn=$note';
        final fallbackQr = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiUri)}';

        setState(() {
          _qrImageUrl = fallbackQr;
          _directUpiQrUrl = fallbackQr;
          _upiVpa = vpa;
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/api/delivery/orders/${widget.orderId}/qr?t=${DateTime.now().millisecondsSinceEpoch}');
        if (res.statusCode == 200 && res.data != null && mounted) {
          final status = res.data['paymentStatus']?.toString().toUpperCase();
          if (status == 'PAID') {
            timer.cancel();
            _onPaymentReceived();
          }
        }
      } catch (_) {}
    });
  }

  void _onPaymentReceived() {
    if (_isPaid) return;
    _pollTimer?.cancel();
    try {
      _pulseController.stop();
      _successController.forward(from: 0.0);
    } catch (_) {}

    // 1. Double Celebratory Vibration (Haptic Pulse)
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 140), () {
        HapticFeedback.heavyImpact();
      });
    } catch (_) {}

    // 2. Play Audio Alert / Soundbox Chime through phone speaker
    try {
      CustomerSoundService.instance.playOrderSuccessSound(isOnline: true);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isPaid = true;
      });

      // Snappy auto-complete delivery for zero-friction rider experience
      _autoCompleteTimer?.cancel();
      _autoCompleteTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && _isPaid && !_isCompleting) {
          _completeDelivery();
        }
      });
    }
  }

  Future<void> _completeDelivery() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    _autoCompleteTimer?.cancel();
    try {
      await widget.onConfirmPaid({
        'paymentMethod': 'ONLINE',
        'paymentStatus': 'PAID',
        'paymentCollectedBy': 'ONLINE',
        'isRiderCash': false,
        'notes': 'Paid via Doorstep Razorpay QR (Verified)',
      });
    } catch (e) {
      debugPrint('[DoorstepQR] Complete delivery error: $e');
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRzpQr = _razorpayQrUrl.isNotEmpty && _razorpayQrUrl.startsWith('http');
    final activeQr = _selectedTab == 0
        ? (hasRzpQr ? _razorpayQrUrl : (_directUpiQrUrl.isNotEmpty ? _directUpiQrUrl : _qrImageUrl))
        : (_directUpiQrUrl.isNotEmpty ? _directUpiQrUrl : _qrImageUrl);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isPaid ? 'Payment Confirmed' : 'Doorstep Payment',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w900,
                            color: _isPaid ? AppDesignSystem.emerald700 : AppDesignSystem.slate900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isPaid ? AppDesignSystem.green100 : AppDesignSystem.emerald50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isPaid ? AppDesignSystem.green200 : AppDesignSystem.emerald200,
                            ),
                          ),
                          child: Text(
                            _isPaid ? 'PAID ✅' : 'RAZORPAY ⚡',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w900,
                              color: _isPaid ? AppDesignSystem.green700 : AppDesignSystem.emerald700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #$_effectiveDisplayId • ₹${_effectiveTotal.toStringAsFixed(0)}${_riderName.isNotEmpty ? " • 🛵 $_riderName" : ""}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate900),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Combined Order Highlight Banner
          if (_isCombined) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignSystem.emerald50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.emerald200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 16, color: AppDesignSystem.emerald700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📦 Combined Order (Grocery + Kitchen) • Collect ₹${_effectiveTotal.toStringAsFixed(0)} for Both',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.emerald800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Display: PAID Screen OR QR Code with Fallback Tabs
          if (_isPaid) ...[
            AnimatedBuilder(
              animation: _successController,
              builder: (context, child) {
                return ScaleTransition(
                  scale: _successScaleAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF86EFAC), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.success.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Animated Expanding Ripple Ring + Checkmark
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 1.0 + (0.45 * _rippleAnimation.value),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppDesignSystem.success.withValues(alpha: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0)),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: AppDesignSystem.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppDesignSystem.success.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.check_rounded, color: Colors.white, size: 40),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Payment Verified! 🎉',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 17),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF14532D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_effectiveTotal.toStringAsFixed(0)} received via Razorpay ⚡',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🚀', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                'Collect ₹0 Cash from Customer',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isCompleting ? null : _completeDelivery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.success,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
                shadowColor: AppDesignSystem.success.withValues(alpha: 0.4),
              ),
              child: _isCompleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Complete Delivery ✅',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ] else ...[
            // Tab Selector: ⚡ Auto-Verify vs 🏦 Normal UPI
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _selectedTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 14, color: AppDesignSystem.emerald600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Auto-Verify ⚡',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: _selectedTab == 0 ? AppDesignSystem.emerald800 : AppDesignSystem.slate600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _selectedTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 13, color: AppDesignSystem.slate600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Normal UPI 🏦',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: _selectedTab == 1 ? AppDesignSystem.slate900 : AppDesignSystem.slate600,
                                ),
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

            // QR Card with Animated Radar Glow
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final glow = (_selectedTab == 0 && !_isPaid) ? _pulseAnimation.value : 0.0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0
                        ? AppDesignSystem.emerald50.withValues(alpha: 0.22 + 0.15 * glow)
                        : AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedTab == 0
                          ? Color.lerp(AppDesignSystem.emerald300, AppDesignSystem.emerald600, glow)!
                          : AppDesignSystem.slate200,
                      width: 1.5 + (0.5 * glow),
                    ),
                    boxShadow: _selectedTab == 0
                        ? [
                            BoxShadow(
                              color: AppDesignSystem.emerald600.withValues(alpha: 0.06 + 0.12 * glow),
                              blurRadius: 14 * (0.8 + 0.4 * glow),
                              spreadRadius: 1 * glow,
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                );
              },
              child: Column(
                children: [
                  if (_isLoading && activeQr.isEmpty) ...[
                    const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppDesignSystem.success),
                            SizedBox(height: 14),
                            Text(
                              'Generating Secure Razorpay QR...',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppDesignSystem.slate900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_selectedTab == 0 && !hasRzpQr && !_isLoading) ...[
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 48, color: AppDesignSystem.slate500),
                            const SizedBox(height: 8),
                            Text(
                              'Auto-Verify QR Unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please use Normal UPI tab to accept payment',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppDesignSystem.slate600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _selectedTab = 1),
                              icon: const Icon(Icons.account_balance_rounded, size: 14),
                              label: const Text('Switch to Normal UPI 🏦'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppDesignSystem.slate900,
                                foregroundColor: Colors.white,
                                textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_isLoading && activeQr.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.emerald50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDesignSystem.emerald200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.emerald600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Connecting Razorpay auto-verify...',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.emerald800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: activeQr.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(activeQr.split(',').last),
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2_rounded, size: 100, color: AppDesignSystem.slate500),
                                )
                              : CachedNetworkImage(
                                  imageUrl: activeQr,
                                  width: 240,
                                  height: 240,
                                  placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: AppDesignSystem.success)),
                                  errorWidget: (c, u, e) => const Icon(Icons.qr_code_2_rounded, size: 100, color: AppDesignSystem.slate500),
                                ),
                        ),
                        // Animated Radar Laser Sweep (Only when Auto-Verify is listening)
                        if (_selectedTab == 0 && !_isLoading && !_isPaid)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: 24 + (192 * _pulseController.value),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    AppDesignSystem.emerald400.withValues(alpha: 0.28),
                                    AppDesignSystem.emerald600.withValues(alpha: 0.55),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_selectedTab == 1 || hasRzpQr) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedTab == 0
                          ? 'Amount ₹${_effectiveTotal.toStringAsFixed(0)} is pre-locked. Scan with GPay, PhonePe, Paytm or Cred'
                          : 'Normal Store UPI: Customer manually enters ₹${_effectiveTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: _selectedTab == 0 ? AppDesignSystem.emerald800 : AppDesignSystem.slate600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_selectedTab == 1 && _upiVpa.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Store VPA: $_upiVpa',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Auto-Checking Indicator (Only when dynamic QR is active)
            if (_selectedTab == 0 && hasRzpQr) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignSystem.green100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.emerald600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-checking Razorpay payment every 2s...',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.emerald700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Emergency Manual Confirm Button (Active on Normal Fallback or if required)
            ElevatedButton(
              onPressed: () async {
                await widget.onConfirmPaid({
                  'paymentMethod': _selectedTab == 0 ? 'ONLINE' : 'UPI',
                  'paymentStatus': 'PAID',
                  'paymentCollectedBy': 'ONLINE',
                  'isRiderCash': false,
                  'notes': _selectedTab == 0
                      ? 'Paid via Doorstep Razorpay QR scan'
                      : 'Paid via Doorstep Fallback Store UPI scan',
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTab == 0 ? AppDesignSystem.emerald600 : AppDesignSystem.slate800,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Confirm Customer Paid ₹${_effectiveTotal.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
