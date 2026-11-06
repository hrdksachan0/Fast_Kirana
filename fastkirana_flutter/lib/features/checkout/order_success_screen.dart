import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/routes/app_router.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../orders/order_tracking_screen.dart';
import '../../core/services/customer_sound_service.dart';
import '../../core/services/logger_service.dart';

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

      // Smooth auto-redirect to live tracking after 5 seconds per user command
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_secondsRemaining > 1) {
            _secondsRemaining--;
          } else {
            timer.cancel();
          }
        });
      });

      _autoRedirectTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
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
    if (!mounted) return;
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    HapticFeedback.mediumImpact();
    final effectiveOrder = _liveOrder ?? widget.order;
    final trackingId = effectiveOrder?.id ?? effectiveOrder?.readableId ?? widget.orderId ?? '';
    try {
      // Ultra-smooth Material FadeThrough transition (550ms) per user request
      Navigator.pushReplacement(
        context,
        FadeThroughRoute(
          page: OrderTrackingScreen(
            orderId: trackingId,
            initialOrder: effectiveOrder,
          ),
          transitionDurationOverride: const Duration(milliseconds: 550),
        ),
      );
    } catch (_) {
      AppRouter.navigatorKey.currentState?.pushReplacement(
        FadeThroughRoute(
          page: OrderTrackingScreen(
            orderId: trackingId,
            initialOrder: effectiveOrder,
          ),
          transitionDurationOverride: const Duration(milliseconds: 550),
        ),
      );
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
    final displayId = widget.orderId ?? widget.order?.id ?? widget.order?.readableId;
    if (displayId == null || displayId.isEmpty) return;

    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.getOrder(displayId);
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

  @override
  Widget build(BuildContext context) {
    final effectiveOrder = _liveOrder ?? widget.order;
    final rawDisplayId = widget.orderId ??
        effectiveOrder?.readableId ??
        effectiveOrder?.id ??
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanId = rawDisplayId.replaceFirst('#', '').replaceFirst('FK-', '');
    final displayId = '#FK-$cleanId';

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
            // Delicate Celebration Confetti (Only on Success, drops softly)
            if (!isFailed)
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                  Color(0xFF34D399),
                  Color(0xFF38BDF8),
                  Color(0xFFFBBF24),
                ],
                numberOfParticles: 24, // Clean & delicate, does not cover text
                gravity: 0.18,
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. HERO ANIMATED BADGE (Enlarged 106px Badge + Outer Breathing Halo + Self-Drawing Tick/Cross)
                      ScaleTransition(
                        scale: _checkScaleAnim,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            final scale = _pulseAnim.value;
                            final haloColor = isFailed
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981);

                            return Container(
                              width: 142 * scale,
                              height: 142 * scale,
                              decoration: BoxDecoration(
                                color: haloColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: haloColor.withValues(alpha: 0.22),
                                    blurRadius: 32 * scale,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 106,
                                  height: 106,
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
                                        color: haloColor.withValues(alpha: 0.38),
                                        blurRadius: 22,
                                        offset: const Offset(0, 8),
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
                                              strokeWidth: 5.5,
                                            ),
                                            size: const Size(50, 50),
                                          );
                                        }
                                        return CustomPaint(
                                          painter: _AnimatedCheckmarkPainter(
                                            progress: _checkDrawController.value,
                                            color: Colors.white,
                                            strokeWidth: 5.5,
                                          ),
                                          size: const Size(52, 52),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. HERO TITLE & ANIMATED WORDS (Clean & Reassuring)
                      FadeTransition(
                        opacity: _heroFadeAnim,
                        child: SlideTransition(
                          position: _heroSlideAnim,
                          child: Column(
                            children: [
                              Text(
                                isFailed ? 'Payment Failed' : 'Congratulations!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: Responsive.scaledFontSize(context, 26),
                                  fontWeight: FontWeight.w900,
                                  color: isFailed ? const Color(0xFFDC2626) : slateDark,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isFailed
                                    ? (widget.failureReason ??
                                        'Your money was not deducted. Your cart items are completely safe.')
                                    : 'Store has started packing your order',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w500,
                                  color: isFailed ? const Color(0xFF991B1B) : slateMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. SLEEK SINGLE-LINE METADATA CHIP
                      FadeTransition(
                        opacity: _contentFadeAnim,
                        child: SlideTransition(
                          position: _contentSlideAnim,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
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
                                 GestureDetector(
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
                                       Text(
                                         _isCopied ? 'Copied!' : displayId,
                                         style: GoogleFonts.jetBrainsMono(
                                           fontSize: Responsive.scaledFontSize(context, 12),
                                           fontWeight: FontWeight.w800,
                                           color: _isCopied ? const Color(0xFF16A34A) : slateDark,
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

                      const SizedBox(height: 28),

                      // 4. ACTION BUTTONS (Option 2 Centered Layout)
                      FadeTransition(
                        opacity: _contentFadeAnim,
                        child: SlideTransition(
                          position: _contentSlideAnim,
                          child: Column(
                            children: [
                              if (!isFailed) ...[
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
