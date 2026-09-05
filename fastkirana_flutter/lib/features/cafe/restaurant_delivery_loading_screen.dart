import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RestaurantDeliveryLoadingScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  final Duration? autoDismissDuration;

  const RestaurantDeliveryLoadingScreen({
    super.key,
    this.onFinished,
    this.autoDismissDuration,
  });

  @override
  State<RestaurantDeliveryLoadingScreen> createState() => _RestaurantDeliveryLoadingScreenState();
}

class _RestaurantDeliveryLoadingScreenState extends State<RestaurantDeliveryLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _steamController;

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _steamAnim;

  @override
  void initState() {
    super.initState();

    // 1. Initial Smooth Fade-in & Slide Entry Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    // 2. Gentle Floating/Breathing Animation for Illustration
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 3. Subtle Steam Drift Animation
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _steamAnim = CurvedAnimation(
      parent: _steamController,
      curve: Curves.linear,
    );

    _fadeController.forward();

    // Optional Auto-dismiss timer if requested
    if (widget.autoDismissDuration != null) {
      Future.delayed(widget.autoDismissDuration!, () {
        if (mounted) {
          widget.onFinished?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _steamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeController, _floatController, _steamController]),
          builder: (context, _) {
            return Opacity(
              opacity: _fadeAnim.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      // Generous Top Whitespace
                      const Spacer(flex: 5),

                      // Floating Cute Vector Food Illustration
                      Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: _buildFoodIllustration(),
                      ),

                      const SizedBox(height: 38),

                      // Centered 2-Line Promotional Text in Rounded Light-Gray Typography
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                          'Hot & fresh food from\nnearby restaurants delivered!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 22),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.slate400, // Soft rounded light-gray
                            height: 1.35,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),

                      // Generous Middle/Bottom Whitespace
                      const Spacer(flex: 5),

                      // Subtle FastKirana Branding at Bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppDesignSystem.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'NEARBY RESTAURANTS',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate300, // Very subtle & minimal
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Small cute modern vector food scene (Takeaway meal box, burger & fries with steam)
  Widget _buildFoodIllustration() {
    return SizedBox(
      width: 170,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Soft Pastel Glow Backdrop Circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignSystem.rose50alt,
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.rose500alt.withValues(alpha: 0.04),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // 2. Rising Animated Steam Wisps
          Positioned(
            top: 6,
            child: CustomPaint(
              size: const Size(60, 24),
              painter: _SteamPainter(progress: _steamAnim.value),
            ),
          ),

          // 3. Custom Cute Vector Food Composition
          CustomPaint(
            size: const Size(150, 130),
            painter: _CuteFoodVectorPainter(),
          ),
        ],
      ),
    );
  }
}

/// Custom Vector Painter for cute flat-design takeaway meal box, burger, fries & pizza
class _CuteFoodVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);

    // ─── 1. Soft Ground Shadow ───
    final shadowPaint = Paint()
      ..color = AppDesignSystem.slate100
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 38), width: 110, height: 16),
      shadowPaint,
    );

    // ─── 2. Cute Food Delivery Box (Back-Left) ───
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx - 28, center.dy + 6), width: 56, height: 48),
      const Radius.circular(10),
    );
    final boxPaint = Paint()..color = AppDesignSystem.rose100alt;
    canvas.drawRRect(boxRect, boxPaint);

    final boxLid = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx - 28, center.dy - 18), width: 62, height: 12),
      const Radius.circular(6),
    );
    final boxLidPaint = Paint()..color = AppDesignSystem.rose300;
    canvas.drawRRect(boxLid, boxLidPaint);

    // Small FastKirana Brand Tag on Box
    final badgePaint = Paint()..color = AppDesignSystem.primary;
    canvas.drawCircle(Offset(center.dx - 28, center.dy + 6), 9, badgePaint);
    final innerBadgePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(center.dx - 28, center.dy + 6), 4, innerBadgePaint);

    // ─── 3. Crispy French Fries Cup (Back-Right) ───
    final friesCupPath = Path()
      ..moveTo(center.dx + 20, center.dy - 2)
      ..lineTo(center.dx + 48, center.dy - 2)
      ..lineTo(center.dx + 44, center.dy + 34)
      ..lineTo(center.dx + 24, center.dy + 34)
      ..close();
    final friesCupPaint = Paint()..color = AppDesignSystem.primary;
    canvas.drawPath(friesCupPath, friesCupPaint);

    // Fries Sticks
    final fryPaint = Paint()
      ..color = AppDesignSystem.amber400
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx + 25, center.dy - 2), Offset(center.dx + 23, center.dy - 16), fryPaint);
    canvas.drawLine(Offset(center.dx + 31, center.dy - 2), Offset(center.dx + 31, center.dy - 22), fryPaint);
    canvas.drawLine(Offset(center.dx + 37, center.dy - 2), Offset(center.dx + 38, center.dy - 19), fryPaint);
    canvas.drawLine(Offset(center.dx + 43, center.dy - 2), Offset(center.dx + 45, center.dy - 14), fryPaint);

    // ─── 4. Cute Juicy Burger (Foreground Center) ───
    final burgerX = center.dx + 2;
    final burgerY = center.dy + 14;

    // Bottom Bun
    final bottomBun = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset(burgerX, burgerY + 18), width: 54, height: 12),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    final bunPaint = Paint()..color = AppDesignSystem.warning;
    canvas.drawRRect(bottomBun, bunPaint);

    // Patty
    final patty = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(burgerX, burgerY + 10), width: 56, height: 8),
      const Radius.circular(4),
    );
    final pattyPaint = Paint()..color = AppDesignSystem.amber900;
    canvas.drawRRect(patty, pattyPaint);

    // Melted Cheese Corner
    final cheesePath = Path()
      ..moveTo(burgerX - 26, burgerY + 7)
      ..lineTo(burgerX + 26, burgerY + 7)
      ..lineTo(burgerX + 16, burgerY + 13)
      ..lineTo(burgerX - 6, burgerY + 7)
      ..lineTo(burgerX - 18, burgerY + 14)
      ..close();
    final cheesePaint = Paint()..color = AppDesignSystem.amber400;
    canvas.drawPath(cheesePath, cheesePaint);

    // Crisp Green Lettuce Wavy Strip
    final lettucePaint = Paint()
      ..color = AppDesignSystem.lime500
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final lettucePath = Path()
      ..moveTo(burgerX - 25, burgerY + 5)
      ..quadraticBezierTo(burgerX - 15, burgerY + 1, burgerX - 5, burgerY + 5)
      ..quadraticBezierTo(burgerX + 5, burgerY + 9, burgerX + 15, burgerY + 5)
      ..quadraticBezierTo(burgerX + 20, burgerY + 2, burgerX + 25, burgerY + 5);
    canvas.drawPath(lettucePath, lettucePaint);

    // Juicy Red Tomato Slice
    final tomato = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(burgerX, burgerY + 1), width: 50, height: 6),
      const Radius.circular(3),
    );
    final tomatoPaint = Paint()..color = AppDesignSystem.danger;
    canvas.drawRRect(tomato, tomatoPaint);

    // Top Dome Bun
    final topBun = Path()
      ..moveTo(burgerX - 26, burgerY - 1)
      ..quadraticBezierTo(burgerX, burgerY - 26, burgerX + 26, burgerY - 1)
      ..close();
    canvas.drawPath(topBun, bunPaint);

    // White Sesame Seeds on Top Bun
    final seedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(
      ui.PointMode.points,
      [
        Offset(burgerX - 12, burgerY - 10),
        Offset(burgerX - 4, burgerY - 15),
        Offset(burgerX + 6, burgerY - 14),
        Offset(burgerX + 14, burgerY - 9),
        Offset(burgerX + 2, burgerY - 7),
      ],
      seedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for rising animated steam curves
class _SteamPainter extends CustomPainter {
  final double progress;
  _SteamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final steamPaint = Paint()
      ..color = AppDesignSystem.rose300.withValues(alpha: 0.55 * (1.0 - progress * 0.4))
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final yOffset = -progress * 14;

    // Steam Line 1
    final path1 = Path();
    path1.moveTo(14, 22 + yOffset);
    path1.cubicTo(10, 14 + yOffset, 18, 8 + yOffset, 14, 0 + yOffset);
    canvas.drawPath(path1, steamPaint);

    // Steam Line 2
    final path2 = Path();
    path2.moveTo(30, 24 + yOffset);
    path2.cubicTo(35, 16 + yOffset, 26, 9 + yOffset, 31, 0 + yOffset);
    canvas.drawPath(path2, steamPaint);

    // Steam Line 3
    final path3 = Path();
    path3.moveTo(46, 21 + yOffset);
    path3.cubicTo(42, 13 + yOffset, 50, 7 + yOffset, 46, 0 + yOffset);
    canvas.drawPath(path3, steamPaint);
  }

  @override
  bool shouldRepaint(covariant _SteamPainter oldDelegate) => oldDelegate.progress != progress;
}

