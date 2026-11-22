import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/design_system.dart';
import '../../core/routes/app_router.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../orders/order_tracking_screen.dart';
import '../../core/services/customer_sound_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/app_url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ultra-Premium Centered Order Success & Payment Failed Screen
/// Option 2 (Emerald Trust Glow) with Enlarged Checkmark (106px), Animated Words,
/// and complete Payment Failed edge-case handling.
class OrderSuccessScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final double totalAmount;
  final String deliveryAddress;
  final String paymentMethod;
  final Order? order;
  final bool isPaymentFailed;
  final String? failureReason;

  const OrderSuccessScreen({
    super.key,
    this.orderId,
    this.totalAmount = 0.0,
    this.deliveryAddress = 'Delivery Address',
    this.paymentMethod = 'COD',
    this.order,
    this.isPaymentFailed = false,
    this.failureReason,
  });

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  late ConfettiController _confettiController;
  late AnimationController _animController;
  late AnimationController _pulseController;
  late AnimationController _checkDrawController;

  late Animation<double> _checkScaleAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _heroFadeAnim;
  late Animation<Offset> _heroSlideAnim;
  late Animation<double> _contentFadeAnim;
  late Animation<Offset> _contentSlideAnim;

  Order? _liveOrder;
  bool _isCopied = false;
  Timer? _syncTimer;
  Timer? _autoRedirectTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 5;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final bool initialFailed = widget.isPaymentFailed ||
        widget.order?.status == OrderStatus.cancelled ||
        widget.order?.paymentStatus.toUpperCase() == 'FAILED';

    // 1. Confetti Celebration (Delicate, never covers text)
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 2200));

    // 2. Entrance Staggered Controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 3. Checkmark / Cross Self-Drawing Controller (500ms duration, starts at 220ms)
    _checkDrawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _checkDrawController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final currentOrder = _liveOrder ?? widget.order;
        final bool isNowFailed = widget.isPaymentFailed ||
            currentOrder?.status == OrderStatus.cancelled ||
            currentOrder?.paymentStatus.toUpperCase() == 'FAILED';

        if (!isNowFailed) {
          _confettiController.play();
          HapticFeedback.heavyImpact();
          final online = _isOnlinePayment();
          CustomerSoundService.instance.playOrderSuccessSound(isOnline: online);
        } else {
          HapticFeedback.vibrate();
        }
      }
    });

    // 4. Ambient Breathing Halo Pulse Controller (2000ms loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      ),
    );

    _heroFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOut),
      ),
    );
    _heroSlideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _contentFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
      ),
    );
    _contentSlideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();

    // Start drawing checkmark smoothly after pop-in
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _checkDrawController.forward();
    });

    if (initialFailed) {
      HapticFeedback.vibrate();
    } else {
      // 5. Live polling backend every 3s to reflect fulfillment changes
      _fetchLiveOrderStatus();
      _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveOrderStatus());

      // Guaranteed 5-second countdown to auto-redirect
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _hasNavigated) {
          timer.cancel();
          return;
        }
        if (_secondsRemaining > 1) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          setState(() {
            _secondsRemaining = 0;
          });
          timer.cancel();
          _navigateToTracking();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    _confettiController.dispose();
    _checkDrawController.dispose();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  void _navigateToTracking() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    _syncTimer?.cancel();

    HapticFeedback.mediumImpact();
    final effectiveOrder = _liveOrder ?? widget.order;
    final trackingId = effectiveOrder?.id ?? effectiveOrder?.readableId ?? widget.orderId ?? '';

    final trackingRoute = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => OrderTrackingScreen(
        orderId: trackingId,
        initialOrder: effectiveOrder,
      ),
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeIn,
          ),
          child: child,
        );
      },
    );

    try {
      Navigator.of(context).pushReplacement(trackingRoute);
    } catch (_) {
      AppRouter.navigatorKey.currentState?.pushReplacement(trackingRoute);
    }
  }

  void _handleBackOrHome() {
    _syncTimer?.cancel();
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    HapticFeedback.lightImpact();
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  void _handleReturnToCart() {
    _syncTimer?.cancel();
    HapticFeedback.mediumImpact();
    try {
      Navigator.of(context).pop();
    } catch (_) {
      AppRouter.navigatorKey.currentState?.pop();
    }
  }

  Future<void> _fetchLiveOrderStatus() async {
    if (!mounted) return;
    final rawId = widget.orderId ?? widget.order?.id ?? widget.order?.readableId;
    if (rawId == null || rawId.isEmpty) return;

    final cleanId = rawId.replaceAll('#', '').replaceAll('FK-', '').trim();

    try {
      final repo = OrderRepository(ref.read(dioProvider));
      var order = await repo.getOrder(cleanId);
      order ??= await repo.getOrder(rawId);
      if (order != null && mounted) {
        setState(() {
          _liveOrder = order;
        });
      }
    } catch (e, _) {
      LoggerService.error('OrderSuccessScreen: fetch live order failed', e);
    }
  }

  bool _isOnlinePayment() {
    final effectiveOrder = _liveOrder ?? widget.order;
    if (effectiveOrder != null) {
      if (effectiveOrder.paymentMethod == PaymentMethod.upi ||
          effectiveOrder.paymentMethod == PaymentMethod.wallet) {
        return true;
      }
      final pStatus = effectiveOrder.paymentStatus.toUpperCase();
      if (pStatus == 'PAID' || pStatus == 'SUCCESS' || pStatus == 'COMPLETED') {
        return true;
      }
    }
    final raw = widget.paymentMethod.toUpperCase().trim();
    return raw.contains('PAID') ||
        raw.contains('UPI') ||
        raw.contains('ONLINE') ||
        raw.contains('WALLET') ||
        raw.contains('CASHFREE') ||
        raw.contains('RAZORPAY') ||
        raw.contains('CARD') ||
        raw.contains('NETBANKING');
  }

  String _formatAmount(double amt) {
    if (amt <= 0) return '0';
    return amt.truncateToDouble() == amt ? amt.toStringAsFixed(0) : amt.toStringAsFixed(2);
  }

  bool _isGiftOrder(Order? order) {
    if (order == null) return false;
    final notes = order.notes ?? '';
    return notes.contains('Gift Note') ||
        notes.contains('🎁') ||
        notes.contains('SECRET GIFT') ||
        notes.contains('Order for:') ||
        notes.contains('[SEND LIVE TRACKING LINK');
  }

  Future<void> _shareGiftCardFromSuccess(Order order) async {
    HapticFeedback.lightImpact();
    final notes = order.notes ?? '';
    String recipient = '';
    final toMatch = RegExp(r'🎁 Order for:\s*(.*?)(?:\(|\||$)').firstMatch(notes);
    if (toMatch != null && toMatch.group(1) != null) {
      recipient = toMatch.group(1)!.trim();
    }
    if (recipient.isEmpty) {
      recipient = order.customerName?.trim().isNotEmpty == true ? order.customerName!.trim() : 'Someone Special';
    }

    String giftNote = '';
    final noteMatch = RegExp(r'💌 Gift Note:\s*(.*?)(?:\||$)').firstMatch(notes);
    if (noteMatch != null && noteMatch.group(1) != null) {
      giftNote = noteMatch.group(1)!.trim();
    }

    final trackingUrl = 'https://fastminute.in/order/${order.id}/track';
    final sender = (order.customerName != null && order.customerName!.trim().isNotEmpty)
        ? order.customerName!.trim()
        : 'A loved one';
    final noteSnippet = giftNote.isNotEmpty ? '\n💌 *Personal Note:* "$giftNote"' : '';

    final shareText = '🎁 *Surprise Gift Delivery for $recipient!* ✨\n\n'
        'From: *$sender*$noteSnippet\n\n'
        '📍 *Track your live surprise delivery:* \n$trackingUrl\n\n'
        '🚀 *FastMinute Express Delivery* — Arriving soon!\n'
        '(Complimentary handwritten message card • Prices & invoice 100% hidden)';

    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
    final success = await AppUrlLauncher.launchSafely(
      Uri.parse(whatsappUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!success) {
      await Share.share(shareText, subject: '🎁 Surprise Gift Delivery from FastMinute');
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOrder = _liveOrder ?? widget.order;

    // Resolve clean, human-friendly Order ID (e.g. #4095 or #4092-R)
    String resolveCleanOrderId() {
      // 1. Highest priority: readableId from live/fetched Order object (e.g. '4095' or '#4095')
      final readable = effectiveOrder?.readableId?.trim();
      if (readable != null &&
          readable.isNotEmpty &&
          !readable.toLowerCase().contains('ord') &&
          readable.length <= 10) {
        final clean = readable.replaceAll('#', '').replaceAll('FK-', '').trim();
        if (clean.isNotEmpty) return '#$clean';
      }

      // 2. If widget.orderId is already a short clean readable ID (not an internal Cashfree/Razorpay string)
      if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
        final wId = widget.orderId!.trim();
        if (!wId.toLowerCase().contains('ord') && wId.length <= 10) {
          final clean = wId.replaceAll('#', '').replaceAll('FK-', '').trim();
          if (clean.isNotEmpty) return '#$clean';
        }
      }

      // 3. If effectiveOrder.displayId is available and clean
      if (effectiveOrder != null) {
        final disp = effectiveOrder.displayId;
        if (!disp.toLowerCase().contains('ord') && disp.length <= 10) {
          return '#$disp';
        }
      }

      // 4. Fallback for internal gateway/cashfree order strings (e.g. 'order_U2wpJDbkW0MCqt' or 'ord_478fcfeaa5bf42e1a56d')
      final raw = widget.orderId ?? effectiveOrder?.id ?? '';
      if (raw.isNotEmpty) {
        final clean = raw
            .replaceAll('#', '')
            .replaceAll('FK-', '')
            .replaceAll('order_', '')
            .replaceAll('ord_', '')
            .replaceAll('_', '')
            .trim();
        final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 4) {
          return '#${digits.substring(digits.length - 4)}';
        }
        if (clean.length >= 4) {
          return '#${clean.substring(clean.length - 4).toUpperCase()}';
        }
        return '#$clean';
      }

      return '#${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    final displayId = resolveCleanOrderId();

    final effectiveAmount = effectiveOrder?.total ?? widget.totalAmount;
    final amountFormatted = _formatAmount(effectiveAmount);

    final currentStatus = effectiveOrder?.status ?? OrderStatus.confirmed;
    final bool isFailed = widget.isPaymentFailed ||
        currentStatus == OrderStatus.cancelled ||
        effectiveOrder?.paymentStatus.toUpperCase() == 'FAILED';
    final isOnline = _isOnlinePayment();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFailed) {
          _handleReturnToCart();
        } else {
          _handleBackOrHome();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Minimalist Luxury CRED-Style Celebration Confetti (Delicate silk flakes, never blocks text)
            if (!isFailed)
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 16,
                gravity: 0.15,
                emissionFrequency: 0.03,
                maxBlastForce: 18,
                minBlastForce: 8,
                minimumSize: const Size(5, 3),
                maximumSize: const Size(9, 5),
                colors: const [
                  Color(0xFFF59E0B), // Warm Gold
                  Color(0xFF10B981), // Emerald
                  Color(0xFF3B82F6), // Royal Blue
                  Color(0xFFF43F5E), // Rose Coral
                  Color(0xFF8B5CF6), // Violet Silk
                  Color(0xFFFCD34D), // Champagne Gold
                ],
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. HERO ANIMATED BADGE (Clean 80px Badge, Zero pixelation/banding, perfectly zoomed out)
                      ScaleTransition(
                        scale: _checkScaleAnim,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            final scale = _pulseAnim.value;
                            final haloColor = isFailed
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981);

                            return Transform.scale(
                              scale: 0.97 + (0.03 * scale),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isFailed
                                        ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                                        : const [Color(0xFF10B981), Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: haloColor.withValues(alpha: 0.28),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: _checkDrawController,
                                    builder: (context, _) {
                                      if (isFailed) {
                                        return CustomPaint(
                                          painter: _AnimatedCrossPainter(
                                            progress: _checkDrawController.value,
                                            color: Colors.white,
                                            strokeWidth: 4.2,
                                          ),
                                          size: const Size(38, 38),
                                        );
                                      }
                                      return CustomPaint(
                                        painter: _AnimatedCheckmarkPainter(
                                          progress: _checkDrawController.value,
                                          color: Colors.white,
                                          strokeWidth: 4.2,
                                        ),
                                        size: const Size(40, 40),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. HERO TITLE & ANIMATED WORDS (Zoomed out, Clean & Reassuring)
                      FadeTransition(
                        opacity: _heroFadeAnim,
                        child: SlideTransition(
                          position: _heroSlideAnim,
                          child: Column(
                            children: [
                              Text(
                                isFailed ? 'Payment Failed' : 'Order Placed Successfully! 🛒',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: Responsive.scaledFontSize(context, 22),
                                  fontWeight: FontWeight.w900,
                                  color: isFailed ? const Color(0xFFDC2626) : slateDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isFailed
                                    ? (widget.failureReason ??
                                        'Your money was not deducted. Your cart items are completely safe.')
                                    : 'Your order is confirmed & store has started packing',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w500,
                                  color: isFailed ? const Color(0xFF991B1B) : slateMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3. SLEEK SINGLE-LINE METADATA CHIP
                      FadeTransition(
                        opacity: _contentFadeAnim,
                        child: SlideTransition(
                          position: _contentSlideAnim,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 32,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isFailed ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                                width: 1.1,
                              ),
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
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      await Clipboard.setData(ClipboardData(text: displayId));
                                      if (mounted) {
                                        setState(() => _isCopied = true);
                                        Future.delayed(const Duration(seconds: 2), () {
                                          if (mounted) setState(() => _isCopied = false);
                                        });
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _isCopied ? 'Copied!' : displayId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: Responsive.scaledFontSize(context, 12),
                                              fontWeight: FontWeight.w800,
                                              color: _isCopied ? const Color(0xFF16A34A) : slateDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                          size: 13,
                                          color: _isCopied ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹$amountFormatted',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w900,
                                    color: slateDark,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isFailed
                                        ? const Color(0xFFFEE2E2)
                                        : (isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isFailed ? 'FAILED' : (isOnline ? 'PAID' : 'COD'),
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10),
                                      fontWeight: FontWeight.w900,
                                      color: isFailed
                                          ? const Color(0xFFDC2626)
                                          : (isOnline ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3.1 COD REASSURANCE BANNER
                      if (!isFailed && !isOnline) ...[
                        FadeTransition(
                          opacity: _contentFadeAnim,
                          child: SlideTransition(
                            position: _contentSlideAnim,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('💵', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      effectiveOrder?.isCombined == true
                                          ? 'Pay ₹$amountFormatted cash or UPI to rider at doorstep (single payment)'
                                          : 'Keep ₹$amountFormatted ready in cash or UPI upon delivery',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11.5),
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3.2 COMBINED MULTI-OUTLET BREAKDOWN CARD
                      if (!isFailed &&
                          effectiveOrder?.isCombined == true &&
                          effectiveOrder?.subOrders != null &&
                          effectiveOrder!.subOrders!.length > 1) ...[
                        FadeTransition(
                          opacity: _contentFadeAnim,
                          child: SlideTransition(
                            position: _contentSlideAnim,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.hub_rounded, size: 13, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 5),
                                          Text(
                                            'COMBINED ORDER (2 OUTLETS)',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 10),
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF2563EB),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '1 Delivery Route',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 10.5),
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...effectiveOrder.subOrders!.map((sub) {
                                    final isRest = sub.restaurantId != null ||
                                        (sub.readableId != null && sub.readableId!.toUpperCase().endsWith('-R'));
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFF1F5F9)),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(isRest ? '🍽️' : '🏪', style: const TextStyle(fontSize: 14)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sub.shopName ?? (isRest ? 'Restaurant' : 'FastMinute Darkstore'),
                                                  style: GoogleFonts.inter(
                                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                                    fontWeight: FontWeight.w700,
                                                    color: slateDark,
                                                  ),
                                                ),
                                                Text(
                                                  isRest ? 'Kitchen preparing food' : 'Store packing items',
                                                  style: GoogleFonts.inter(
                                                    fontSize: Responsive.scaledFontSize(context, 10),
                                                    color: slateMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (sub.readableId != null)
                                            Text(
                                              '#${sub.readableId}',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const SizedBox(height: 14),

                      // 4. ACTION BUTTONS (Option 2 Centered Layout)
                      FadeTransition(
                        opacity: _contentFadeAnim,
                        child: SlideTransition(
                          position: _contentSlideAnim,
                          child: Column(
                            children: [
                              if (!isFailed) ...[
                                if (_isGiftOrder(effectiveOrder)) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (effectiveOrder != null) {
                                        _shareGiftCardFromSuccess(effectiveOrder);
                                      }
                                    },
                                    child: Container(
                                      height: 48,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('🎁', style: TextStyle(fontSize: 16)),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Share Surprise Card with Tracking',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                // Primary Action: Track Live Order Status
                                GestureDetector(
                                  onTap: _navigateToTracking,
                                  child: Container(
                                    height: 52,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.location_searching_rounded, color: Colors.white, size: 19),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Track Live Order Status • ${_secondsRemaining}s',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 14.5),
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Auto-redirecting to live tracking in ${_secondsRemaining}s...',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w600,
                                        color: slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Secondary Action: Continue Shopping
                                GestureDetector(
                                  onTap: _handleBackOrHome,
                                  child: Container(
                                    height: 48,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Continue Shopping 🛍️',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Failure Primary Action: Choose COD / Retry
                                GestureDetector(
                                  onTap: _handleReturnToCart,
                                  child: Container(
                                    height: 52,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE20A22), Color(0xFFFF3B30)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryRed.withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Retry with COD or Another UPI',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 14.5),
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Failure Secondary Action: Return to Cart
                                GestureDetector(
                                  onTap: _handleReturnToCart,
                                  child: Container(
                                    height: 48,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Return to Cart 🛒',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
    );
  }
}

/// Animated Vector Checkmark Painter (Emerald Trust Glow)
class _AnimatedCheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _AnimatedCheckmarkPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 5.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.20, size.height * 0.52);
    path.lineTo(size.width * 0.42, size.height * 0.74);
    path.lineTo(size.width * 0.80, size.height * 0.28);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(0.0, (sum, m) => sum + m.length);
    final targetLength = totalLength * progress.clamp(0.0, 1.0);

    var currentDist = 0.0;
    for (final metric in metrics) {
      if (targetLength > currentDist) {
        final lengthToExtract = math.min(targetLength - currentDist, metric.length);
        final extractedPath = metric.extractPath(0.0, lengthToExtract);
        canvas.drawPath(extractedPath, paint);
      }
      currentDist += metric.length;
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Animated Vector Cross Painter (Payment Failed Edge-Case)
class _AnimatedCrossPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _AnimatedCrossPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 5.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = progress.clamp(0.0, 0.5) * 2.0;

    // Line 1: Top-Left to Bottom-Right
    final start1 = Offset(size.width * 0.28, size.height * 0.28);
    final end1 = Offset(size.width * 0.72, size.height * 0.72);
    canvas.drawLine(start1, Offset.lerp(start1, end1, p1)!, paint);

    // Line 2: Top-Right to Bottom-Left
    if (progress > 0.5) {
      final p2 = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
      final start2 = Offset(size.width * 0.72, size.height * 0.28);
      final end2 = Offset(size.width * 0.28, size.height * 0.72);
      canvas.drawLine(start2, Offset.lerp(start2, end2, p2)!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedCrossPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
