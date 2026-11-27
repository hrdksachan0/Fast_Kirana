import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' show Options;
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/customer_sound_service.dart';
import '../../../core/services/supabase_service.dart';

/// Doorstep Dynamic UPI QR Bottom Sheet (Strict Razorpay Auto-Verification Only)
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
  bool _isLoading = true;
  bool _isPaid = false;
  bool _isCheckingStatus = false;
  bool _isManualChecking = false;
  String _statusHint = 'Soundbox listening live...';
  String _razorpayQrUrl = '';
  String _razorpayQrId = '';
  bool _isCombined = false;
  double _combinedTotal = 0.0;
  String _displayId = '';
  String _riderName = '';
  Timer? _pollTimer;
  Timer? _autoCompleteTimer;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _realtimeChannelByNum;
  bool _isCompleting = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _scanBeamController;
  late final AnimationController _successController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    _scanBeamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

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

    _fetchQrData();
    _startPolling();
    _subscribeRealtime();
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

      if (widget.orderNum.isNotEmpty && widget.orderNum != widget.orderId) {
        final numCh = 'order-payment-${widget.orderNum}';
        _realtimeChannelByNum = sb.channel(numCh);
        _realtimeChannelByNum!.onBroadcast(
          event: 'PAYMENT_RECEIVED',
          callback: (payload) {
            debugPrint('[DoorstepQR] Realtime PAYMENT_RECEIVED (readableId) caught: $payload');
            if (mounted && !_isPaid) {
              _onPaymentReceived();
            }
          },
        ).subscribe();
      }
    } catch (e) {
      debugPrint('[DoorstepQR] Error subscribing to Supabase realtime: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanBeamController.dispose();
    _successController.dispose();
    _pollTimer?.cancel();
    _autoCompleteTimer?.cancel();
    if (_realtimeChannel != null) {
      SupabaseService.unsubscribe(_realtimeChannel);
    }
    if (_realtimeChannelByNum != null) {
      SupabaseService.unsubscribe(_realtimeChannelByNum);
    }
    super.dispose();
  }

  double get _effectiveTotal => _combinedTotal > 0 ? _combinedTotal : widget.total;
  String get _effectiveDisplayId => _displayId.isNotEmpty ? _displayId : widget.orderNum;

  Future<void> _fetchQrData() async {
    if (mounted && !_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/delivery/orders/${widget.orderId}/qr?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null && mounted) {
        final data = res.data;
        final status = data['paymentStatus']?.toString().toUpperCase();
        setState(() {
          _razorpayQrUrl = data['razorpayQrUrl']?.toString() ?? '';
          _razorpayQrId = data['razorpayQrId']?.toString() ?? '';
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
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _razorpayQrUrl = '';
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkPaymentStatusOnce() async {
    if (!mounted || _isPaid || _isCheckingStatus) return _isPaid;
    _isCheckingStatus = true;
    try {
      final dio = ref.read(dioProvider);
      final qrQuery = _razorpayQrId.isNotEmpty ? '&qrId=${Uri.encodeComponent(_razorpayQrId)}' : '';
      final res = await dio.get(
        '/api/delivery/orders/${widget.orderId}/qr-status?t=${DateTime.now().millisecondsSinceEpoch}$qrQuery',
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (res.statusCode == 200 && res.data != null && mounted) {
        final status = res.data['paymentStatus']?.toString().toUpperCase();
        if (status == 'PAID' || res.data['paid'] == true) {
          _pollTimer?.cancel();
          _onPaymentReceived();
          return true;
        }
      }
    } catch (_) {
    } finally {
      _isCheckingStatus = false;
    }
    return false;
  }

  Future<void> _manualVerifyPayment() async {
    if (!mounted || _isPaid || _isManualChecking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isManualChecking = true;
      _statusHint = 'Checking Razorpay...';
    });
    final paid = await _checkPaymentStatusOnce();
    if (mounted && !paid) {
      setState(() {
        _isManualChecking = false;
        _statusHint = 'Still listening live...';
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }
      await _checkPaymentStatusOnce();
    });
  }

  void _onPaymentReceived() {
    if (_isPaid) return;
    _pollTimer?.cancel();
    try {
      _pulseController.stop();
      _scanBeamController.stop();
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

  Widget _buildEqualizerBars() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final t = _pulseController.value;
        final heights = [
          5.0 + 9.0 * (0.5 + 0.5 * (t * 2 - 1).abs()),
          5.0 + 9.0 * (1.0 - (t - 0.35).abs()).clamp(0.0, 1.0),
          5.0 + 9.0 * (1.0 - (t - 0.65).abs()).clamp(0.0, 1.0),
          5.0 + 9.0 * (1.0 - t),
        ];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: heights
              .map(
                (h) => Container(
                  width: 2.5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRzpQr = _razorpayQrUrl.isNotEmpty &&
        (_razorpayQrUrl.startsWith('http') || _razorpayQrUrl.startsWith('data:image'));
    final activeQr = hasRzpQr ? _razorpayQrUrl : '';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x4034D399), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Compact Top Bar (Hero Amount + Locked Pill + Order Meta + Close)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '₹${_effectiveTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 22),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _isPaid ? const Color(0xFF16A34A) : const Color(0x2810B981),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isPaid ? const Color(0xFF4ADE80) : const Color(0x5534D399),
                        ),
                      ),
                      child: Text(
                        _isPaid ? 'PAID ✅' : '🔒 LOCKED',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _isPaid ? Colors.white : const Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '#$_effectiveDisplayId${_riderName.isNotEmpty ? " · $_riderName" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(Icons.close_rounded, color: Color(0xFFCBD5E1), size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Combined Order Highlight Banner
          if (_isCombined) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1F10B981),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4534D399)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 15, color: Color(0xFF34D399)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Combined Order (Grocery + Kitchen) • Collect ₹${_effectiveTotal.toStringAsFixed(0)} for Both',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFA7F3D0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Display: PAID Celebration OR Midnight OLED White QR Island
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
                          color: AppDesignSystem.success.withValues(alpha: 0.28),
                          blurRadius: 26,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
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
                                    color: AppDesignSystem.success.withValues(
                                      alpha: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                                    ),
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
                          '₹${_effectiveTotal.toStringAsFixed(0)} received via Razorpay UPI ⚡',
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
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isCompleting ? null : _completeDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppDesignSystem.success.withValues(alpha: 0.4),
                ),
                child: _isCompleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Complete Delivery ✅',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // Glowing Pure-White QR Island (High-Contrast Night-Scan POS)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final glow = _pulseAnimation.value;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0x6610B981),
                        const Color(0xCC34D399),
                        glow,
                      )!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14 + 0.14 * glow),
                        blurRadius: 24 + 8 * glow,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Column(
                children: [
                  if (_isLoading && !hasRzpQr) ...[
                    // Premium Shimmer Skeleton Loader while Razorpay QR generates
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 232,
                          height: 232,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Color.lerp(
                              const Color(0xFFF1F5F9),
                              const Color(0xFFE2E8F0),
                              _pulseAnimation.value,
                            ),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Generating Locked QR...',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else if (!hasRzpQr && !_isLoading) ...[
                    SizedBox(
                      width: 232,
                      height: 224,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 48, color: AppDesignSystem.slate500),
                            const SizedBox(height: 8),
                            Text(
                              'Auto-Verify QR Unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Retry QR or collect Cash (COD) via slide-to-deliver',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppDesignSystem.slate600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchQrData,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Crisp Zoomed QR + Subtle Animated Emerald Scan Beam
                    SizedBox(
                      width: 236,
                      height: 236,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: activeQr.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(activeQr.split(',').last),
                                    width: 236,
                                    height: 236,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 100,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  )
                                : ClipRect(
                                    child: Transform.scale(
                                      scale: 1.28,
                                      alignment: const Alignment(0.0, 0.02),
                                      child: CachedNetworkImage(
                                        imageUrl: activeQr,
                                        width: 236,
                                        height: 236,
                                        fit: BoxFit.fitWidth,
                                        alignment: const Alignment(0.0, 0.03),
                                        placeholder: (c, u) => const SizedBox(
                                          width: 236,
                                          height: 236,
                                          child: Center(
                                            child: CircularProgressIndicator(color: Color(0xFF059669)),
                                          ),
                                        ),
                                        errorWidget: (c, u, e) => const Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 100,
                                          color: AppDesignSystem.slate500,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          // Animated Laser Scan Beam
                          AnimatedBuilder(
                            animation: _scanBeamController,
                            builder: (context, _) {
                              return Positioned(
                                left: 8,
                                right: 8,
                                top: 10 + (_scanBeamController.value * 214),
                                child: IgnorePointer(
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xD910B981),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x8810B981),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'GPay · PhonePe · Paytm · BHIM UPI',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Soundbox Equalizer Status Bar + Full-Width 54px Neon-Emerald Verify CTA
            if (hasRzpQr) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1A10B981),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4034D399)),
                ),
                child: Row(
                  children: [
                    _buildEqualizerBars(),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _isManualChecking ? 'Checking Razorpay live...' : _statusHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFA7F3D0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AUTO',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF34D399),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x5510B981),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isManualChecking ? null : _manualVerifyPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isManualChecking
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF022C22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Checking Razorpay...',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14.5),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF022C22),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, color: Color(0xFF022C22), size: 22),
                              const SizedBox(width: 6),
                              Text(
                                'Verify Payment Now',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 15),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF022C22),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
