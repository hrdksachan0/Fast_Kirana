import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/routes/page_transitions.dart';
import '../core/services/location_service.dart';
import '../core/theme/responsive.dart';
import '../features/cart/cart_screen.dart';
import '../providers/cart_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Universal Apple Watch Style Radial Gauge Painter
// ─────────────────────────────────────────────────────────────────────────────

class _CartRadialGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  final bool isFreeDelivery;

  const _CartRadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 2.8,
    this.isFreeDelivery = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc with luxury gradient sweep
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: 2 * math.pi,
          colors: isFreeDelivery
              ? const [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF10B981)]
              : const [Color(0xFFE20A22), Color(0xFFFF385C), Color(0xFFE20A22)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final sweepAngle = (2 * math.pi) * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CartRadialGaugePainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor ||
      old.isFreeDelivery != isFreeDelivery;
}

// ─────────────────────────────────────────────────────────────────────────────
// Universal Floating Cart Bar (Compact, Sleek & Pixel-Perfect)
// ─────────────────────────────────────────────────────────────────────────────

class FloatingCartBar extends ConsumerStatefulWidget {
  final double bottomOffset;

  const FloatingCartBar({
    super.key,
    this.bottomOffset = 16.0,
  });

  @override
  ConsumerState<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends ConsumerState<FloatingCartBar> {
  bool _isPressed = false;

  void _navigateToCart() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;

    if (cart == null || cart.totalItems == 0) {
      return const SizedBox.shrink();
    }

    final total = cart.subtotal;
    final itemCount = cart.totalItems;
    final tier = ref.watch(deliveryTierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = (screenWidth * 0.92).clamp(280.0, 410.0);

    final isFreeDelivery = tier.deliveryFee == 0;
    final remainingForFree = (tier.freeDeliveryThreshold - total).clamp(0.0, tier.freeDeliveryThreshold).toInt();
    final targetProgress = tier.freeDeliveryThreshold > 0
        ? (total / tier.freeDeliveryThreshold).clamp(0.0, 1.0)
        : 1.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: widget.bottomOffset,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: barWidth,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, animValue, child) {
              return Transform.translate(
                offset: Offset(0, (1 - animValue) * 24),
                child: Opacity(
                  opacity: animValue.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  // 1. Crisp Edge Outline Shadow (kinare kinare dark contour taaki white background me mix na ho)
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                  // 2. Tight Contact Contour Shadow
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  // 3. Subtle FastMinute Crimson Ambient Glow
                  BoxShadow(
                    color: const Color(0xFFE20A22).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                    children: [
                      // 1. Sleek Compact Radial Progress Gauge with Elastic Scooter Bounce
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(end: targetProgress),
                        builder: (context, animProgress, _) {
                          return SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(36, 36),
                                  painter: _CartRadialGaugePainter(
                                    progress: animProgress,
                                    trackColor: const Color(0xFFF1F5F9),
                                    progressColor: isFreeDelivery
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFE20A22),
                                    strokeWidth: 2.8,
                                    isFreeDelivery: isFreeDelivery,
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isFreeDelivery
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                    boxShadow: isFreeDelivery
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                              blurRadius: 5,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey('scooter_$itemCount'),
                                      tween: Tween<double>(begin: 0.8, end: 1.0),
                                      duration: const Duration(milliseconds: 380),
                                      curve: Curves.elasticOut,
                                      builder: (context, scale, child) => Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                      child: const Text(
                                        '🛵',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // 2. Minimalist Center Info with Clean Formatting (No Truncation)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _navigateToCart,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, anim) => SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.25),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: FadeTransition(opacity: anim, child: child),
                                    ),
                                    child: Text(
                                      '₹${total.toInt()}',
                                      key: ValueKey('price_${total.toInt()}'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, anim) => ScaleTransition(
                                      scale: anim,
                                      child: child,
                                    ),
                                    child: Text(
                                      '• $itemCount ${itemCount == 1 ? "item" : "items"}',
                                      key: ValueKey('count_$itemCount'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              if (!tier.isServiceable)
                                Text(
                                  '⚠️ Outside 5.0 km Hub',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE11D48),
                                  ),
                                )
                              else if (isFreeDelivery)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 10.5, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Free Delivery Unlocked',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Add ₹$remainingForFree for FREE Delivery',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE20A22),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 3. Compact FastMinute Crimson Gradient Button
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isPressed = true),
                        onTapUp: (_) => setState(() => _isPressed = false),
                        onTapCancel: () => setState(() => _isPressed = false),
                        onTap: _navigateToCart,
                        child: AnimatedScale(
                          scale: _isPressed ? 0.94 : 1.0,
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFE20A22), Color(0xFFB30013)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: _isPressed ? 0.20 : 0.38),
                                  blurRadius: _isPressed ? 5 : 10,
                                  offset: Offset(0, _isPressed ? 1.5 : 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Cart',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                AnimatedSlide(
                                  offset: _isPressed ? const Offset(0.18, 0) : Offset.zero,
                                  duration: const Duration(milliseconds: 140),
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.24),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 9.5,
                                        color: Colors.white,
                                      ),
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
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
