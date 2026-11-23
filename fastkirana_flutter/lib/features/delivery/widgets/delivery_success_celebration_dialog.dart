import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/customer_sound_service.dart';

/// 1.5-Second Cheerful Green Tick Delivery Completion Overlay
/// Features:
/// - Smooth scale-spring & pulse check animation
/// - Soft double tactile haptic pulse
/// - Pleasant confirmation sound
/// - 1.5-second self-dismissing lifecycle
class DeliverySuccessCelebrationDialog extends StatefulWidget {
  final String orderNum;
  final double amount;
  final String paymentMethod; // 'CASH', 'ONLINE', 'SPLIT'

  const DeliverySuccessCelebrationDialog({
    super.key,
    required this.orderNum,
    required this.amount,
    this.paymentMethod = 'ONLINE',
  });

  static Future<void> show(
    BuildContext context, {
    required String orderNum,
    required double amount,
    String paymentMethod = 'ONLINE',
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => DeliverySuccessCelebrationDialog(
        orderNum: orderNum,
        amount: amount,
        paymentMethod: paymentMethod,
      ),
    );
  }

  @override
  State<DeliverySuccessCelebrationDialog> createState() => _DeliverySuccessCelebrationDialogState();
}

class _DeliverySuccessCelebrationDialogState extends State<DeliverySuccessCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkProgress;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _checkProgress = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    // Soft tactile haptic pulses
    _triggerTactileHaptics();

    // Audio cue
    try {
      CustomerSoundService.instance.playOrderSuccessSound(
        isOnline: widget.paymentMethod != 'CASH',
      );
    } catch (_) {}

    // Auto dismiss after 1.5 seconds (1500 ms)
    _dismissTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  void _triggerTactileHaptics() {
    try {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 160), () {
        HapticFeedback.lightImpact();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.emerald600.withOpacity(0.22),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Glowing Check Circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer soft ripple aura
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.emerald50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppDesignSystem.emerald200,
                          width: 2,
                        ),
                      ),
                    ),
                    // Inner emerald core
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppDesignSystem.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4010B981),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _checkProgress,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _AnimatedCheckPainter(_checkProgress.value),
                            child: const SizedBox(width: 76, height: 76),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Cheerful Title
                Text(
                  'Delivered Successfully! 🚀',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 16.5),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Order subtitle
                Text(
                  'Order #${widget.orderNum} • ₹${widget.amount.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.emerald700,
                  ),
                ),
                const SizedBox(height: 12),

                // Mode pill (Cash / Split / Online)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.paymentMethod == 'SPLIT'
                        ? '✂️ Split Payment Collected'
                        : widget.paymentMethod == 'CASH'
                            ? '💵 Cash In Hand Added'
                            : '⚡ Verified Online Payment',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom high-fps smooth path stroke painter for the checkmark
class _AnimatedCheckPainter extends CustomPainter {
  final double progress;

  _AnimatedCheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Checkmark keypoints (p1 -> p2 -> p3)
    final p1 = Offset(w * 0.28, h * 0.52);
    final p2 = Offset(w * 0.44, h * 0.68);
    final p3 = Offset(w * 0.74, h * 0.36);

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (progress < 0.45) {
      // First leg (p1 -> p2)
      final t = progress / 0.45;
      final cur = Offset.lerp(p1, p2, t)!;
      path.lineTo(cur.dx, cur.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      // Second leg (p2 -> p3)
      final t = (progress - 0.45) / 0.55;
      final cur = Offset.lerp(p2, p3, t)!;
      path.lineTo(cur.dx, cur.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
