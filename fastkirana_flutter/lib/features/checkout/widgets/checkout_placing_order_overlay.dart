import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-Page Ultra-Smooth Zepto & Blinkit Style Order Placement Screen
/// Featuring the 100% authentic FastMinute Speed-F emblem inside a dynamic kinetic badge.
/// Covers the entire viewport with zero bleed-through and full edge-case protection.
class CheckoutPlacingOrderOverlay extends StatefulWidget {
  final double? totalAmount;
  final bool isCod;
  final VoidCallback? onCancel;

  const CheckoutPlacingOrderOverlay({
    super.key,
    this.totalAmount,
    this.isCod = false,
    this.onCancel,
  });

  @override
  State<CheckoutPlacingOrderOverlay> createState() => _CheckoutPlacingOrderOverlayState();
}

class _CheckoutPlacingOrderOverlayState extends State<CheckoutPlacingOrderOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _speedLinesController;
  late final AnimationController _bounceController;
  late final AnimationController _entranceController;

  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _entranceFade;

  Timer? _waitTimer;
  Timer? _cancelTimer;
  bool _isTakingLonger = false;
  bool _canCancel = false;

  @override
  void initState() {
    super.initState();

    // Haptic feedback on entrance
    HapticFeedback.mediumImpact();

    // 1. Entrance Fade
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();

    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    // 2. Pulse Radar Rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseScale = Tween<double>(begin: 0.85, end: 1.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
    _pulseOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // 3. Levitation Spring Float
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
    );

    // 4. Speed Wind Particles
    _speedLinesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    // 5. Wait & Cancel Edge-case Timers (Safe recovery if server is slow)
    _waitTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isTakingLonger = true);
    });
    _cancelTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _canCancel = true);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _cancelTimer?.cancel();
    _pulseController.dispose();
    _speedLinesController.dispose();
    _bounceController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceFade,
      child: Material(
        color: Colors.white,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFAFAFA),
                Color(0xFFF1F5F9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // 1. Top Brand Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE20A22).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                            color: Color(0xFFE20A22),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '⚡ FASTMINUTE EXPRESS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB91C1C),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 2. Central High-Velocity Hero: Authentic Speed-F Emblem Badge
                  SizedBox(
                    width: 200,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Speed Particles Canvas (Sweeping behind the badge)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _speedLinesController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _SpeedLinesPainter(
                                  progress: _speedLinesController.value,
                                  lineColor: const Color(0xFFE20A22).withValues(alpha: 0.45),
                                ),
                              );
                            },
                          ),
                        ),

                        // Outer Radar Pulse Ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: _pulseScale.value,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE20A22).withValues(alpha: _pulseOpacity.value),
                                    width: 2.2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Soft Ambient Center Glow
                        Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),

                        // Floating Dynamic Shadow
                        Positioned(
                          bottom: 12,
                          child: AnimatedBuilder(
                            animation: _bounceAnimation,
                            builder: (context, _) {
                              final factor = (1.0 - (_bounceAnimation.value / 12)).clamp(0.6, 1.2);
                              return Container(
                                width: 75 * factor,
                                height: 8 * factor,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.14 * factor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            },
                          ),
                        ),

                        // Floating Circular Badge with 100% Exact Official White Logo
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(0, _bounceAnimation.value),
                              child: Container(
                                width: 106,
                                height: 106,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE20A22), Color(0xFFBE123C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 3.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE20A22).withValues(alpha: 0.42),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(19),
                                child: Center(
                                  child: Image.asset(
                                    'assets/brand/white_logo_cropped.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Simple & Natural Typography
                  Text(
                    'Placing Your Order...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting with store & reserving freshest stock',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Live Reassurance Status Pill (Edge-Case Adaptive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isTakingLonger ? const Color(0xFFFEF3C7) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isTakingLonger ? const Color(0xFFFDE68A) : const Color(0xFFFEEBC8),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _isTakingLonger ? const Color(0xFFD97706) : const Color(0xFFE20A22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTakingLonger
                              ? 'Securely reserving freshest stock at store...'
                              : 'Reserving freshest items in store...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isTakingLonger ? const Color(0xFF92400E) : const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 12s Cancel Safe Recovery
                  if (_canCancel && widget.onCancel != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onCancel!();
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: Text(
                        'Taking too long? Cancel & Return to Cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],

                  // 5. Amount & Payment Chip
                  if (widget.totalAmount != null && widget.totalAmount! > 0) ...[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isCod ? Icons.payments_outlined : Icons.credit_card_rounded,
                            size: 16,
                            color: widget.isCod ? const Color(0xFFD97706) : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total Bill: ₹${widget.totalAmount!.toInt()} • ${widget.isCod ? 'Cash on Delivery' : 'Online Payment'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(flex: 3),

                  // 6. Security & Don't Press Back Advisory
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '100% Secure & Verified Express Checkout',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Please do not press back or close the app',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for animated horizontal speed wind lines behind the badge
class _SpeedLinesPainter extends CustomPainter {
  final double progress;
  final Color lineColor;

  _SpeedLinesPainter({required this.progress, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lines = [
      {'y': size.height * 0.28, 'speed': 1.1, 'len': 26.0, 'thick': 2.0},
      {'y': size.height * 0.44, 'speed': 0.8, 'len': 36.0, 'thick': 2.4},
      {'y': size.height * 0.62, 'speed': 1.3, 'len': 22.0, 'thick': 1.8},
      {'y': size.height * 0.76, 'speed': 0.9, 'len': 30.0, 'thick': 2.0},
    ];

    for (final line in lines) {
      final y = line['y'] as double;
      final speed = line['speed'] as double;
      final len = line['len'] as double;
      final thick = line['thick'] as double;

      final cycle = (progress * speed) % 1.0;
      final startX = (1.0 - cycle) * (size.width + len * 2) - len;
      final endX = startX + len;

      paint.strokeWidth = thick;
      final alphaFactor = math.sin(cycle * math.pi).clamp(0.0, 1.0);
      paint.color = lineColor.withValues(alpha: alphaFactor * 0.65);

      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
