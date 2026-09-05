import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GroceryDeliveryLoadingScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  final Duration? autoDismissDuration;

  const GroceryDeliveryLoadingScreen({
    super.key,
    this.onFinished,
    this.autoDismissDuration,
  });

  @override
  State<GroceryDeliveryLoadingScreen> createState() => _GroceryDeliveryLoadingScreenState();
}

class _GroceryDeliveryLoadingScreenState extends State<GroceryDeliveryLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _sparkleController;

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _sparkleAnim;

  @override
  void initState() {
    super.initState();

    // 1. Smooth Fade-in & Slide-Up Entry Animation
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

    // 3. Subtle Freshness Sparkle Pulse
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _sparkleAnim = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();

    // Optional Auto-dismiss timer if configured
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
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeController, _floatController, _sparkleController]),
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

                      // Floating Cute Vector Grocery Illustration
                      Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: _buildGroceryIllustration(),
                      ),

                      const SizedBox(height: 38),

                      // Centered 2-Line Promotional Text in Rounded Light-Gray Typography
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                          'Fresh groceries,\ndelivered to your doorstep!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 22),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.slate400, // Rounded modern light-gray
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
                              color: AppDesignSystem.green600, // Fresh grocery green accent dot
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'FASTKIRANA GROCERY EXPRESS',
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

  /// Small cute modern vector grocery scene (Milk carton, Alfonso mango, leafy greens & grocery bag)
  Widget _buildGroceryIllustration() {
    return SizedBox(
      width: 170,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Soft Pastel Glow Backdrop Circle (Fresh Emerald/Mint tint)
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignSystem.green50,
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.success.withValues(alpha: 0.04),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // 2. Freshness Sparkle Twinkles
          Positioned(
            top: 10,
            right: 20,
            child: Opacity(
              opacity: 0.4 + 0.6 * _sparkleAnim.value,
              child: const Icon(Icons.auto_awesome, size: 16, color: AppDesignSystem.amber400),
            ),
          ),
          Positioned(
            top: 28,
            left: 18,
            child: Opacity(
              opacity: 0.3 + 0.5 * (1.0 - _sparkleAnim.value),
              child: const Icon(Icons.star_rounded, size: 13, color: AppDesignSystem.emerald400),
            ),
          ),

          // 3. Custom Vector Grocery Composition Painter
          CustomPaint(
            size: const Size(150, 130),
            painter: _CuteGroceryVectorPainter(),
          ),
        ],
      ),
    );
  }
}

/// Custom Vector Painter for cute flat-design Kraft grocery bag, milk carton, ripe mango & fresh greens
class _CuteGroceryVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);

    // ─── 1. Soft Ground Shadow ───
    final shadowPaint = Paint()
      ..color = AppDesignSystem.slate100
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 38), width: 115, height: 16),
      shadowPaint,
    );

    // ─── 2. Fresh Milk Carton (Back-Left) ───
    final milkX = center.dx - 30;
    final milkY = center.dy - 6;

    // Milk Carton Body
    final milkBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(milkX, milkY + 12), width: 34, height: 46),
      const Radius.circular(5),
    );
    final milkPaint = Paint()..color = AppDesignSystem.slate50;
    canvas.drawRRect(milkBody, milkPaint);

    final milkBorder = Paint()
      ..color = AppDesignSystem.slate200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(milkBody, milkBorder);

    // Blue Band on Milk Carton
    final blueBand = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset(milkX, milkY + 14), width: 34, height: 16),
      topLeft: Radius.zero,
      topRight: Radius.zero,
    );
    final blueBandPaint = Paint()..color = AppDesignSystem.cyan400;
    canvas.drawRRect(blueBand, blueBandPaint);

    // Milk Gable Top (Triangular Roof)
    final roofPath = Path()
      ..moveTo(milkX - 17, milkY - 11)
      ..lineTo(milkX, milkY - 24)
      ..lineTo(milkX + 17, milkY - 11)
      ..close();
    final roofPaint = Paint()..color = AppDesignSystem.cyan600;
    canvas.drawPath(roofPath, roofPaint);

    // ─── 3. Fresh Crisp Greens / Celery (Back-Right) ───
    final greenX = center.dx + 26;
    final greenY = center.dy - 12;

    final leafPaint = Paint()
      ..color = AppDesignSystem.lime500
      ..style = PaintingStyle.fill;

    // Leaf 1
    final leaf1 = Path()
      ..moveTo(greenX, greenY + 20)
      ..quadraticBezierTo(greenX - 14, greenY - 4, greenX - 6, greenY - 16)
      ..quadraticBezierTo(greenX + 4, greenY - 6, greenX, greenY + 20);
    canvas.drawPath(leaf1, leafPaint);

    // Leaf 2 (Darker green)
    final darkLeafPaint = Paint()..color = AppDesignSystem.green600;
    final leaf2 = Path()
      ..moveTo(greenX + 4, greenY + 20)
      ..quadraticBezierTo(greenX + 18, greenY - 2, greenX + 10, greenY - 18)
      ..quadraticBezierTo(greenX - 2, greenY - 6, greenX + 4, greenY + 20);
    canvas.drawPath(leaf2, darkLeafPaint);

    // ─── 4. Eco Kraft Paper Grocery Bag (Center Foreground) ───
    final bagPath = Path()
      ..moveTo(center.dx - 32, center.dy - 6)
      ..lineTo(center.dx + 32, center.dy - 6)
      ..lineTo(center.dx + 27, center.dy + 34)
      ..lineTo(center.dx - 27, center.dy + 34)
      ..close();
    final bagPaint = Paint()..color = AppDesignSystem.amber600.withValues(alpha: 0.85); // Warm kraft paper
    canvas.drawPath(bagPath, bagPaint);

    // Folded top lip of bag
    final bagLip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 7), width: 66, height: 7),
      const Radius.circular(3),
    );
    final bagLipPaint = Paint()..color = AppDesignSystem.amber700;
    canvas.drawRRect(bagLip, bagLipPaint);

    // FastKirana Red Heart / Logo Badge on Bag
    final badgePaint = Paint()..color = AppDesignSystem.primary;
    canvas.drawCircle(Offset(center.dx, center.dy + 14), 10, badgePaint);

    // White 'F' symbol
    final fPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - 2, center.dy + 8), Offset(center.dx - 2, center.dy + 20), fPaint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 9), Offset(center.dx + 4, center.dy + 9), fPaint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 14), Offset(center.dx + 2, center.dy + 14), fPaint);

    // ─── 5. Golden Alfonso Mango & Fresh Apple (Foreground Right) ───
    final mangoX = center.dx + 22;
    final mangoY = center.dy + 20;

    // Mango Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(mangoX, mangoY + 12), width: 28, height: 8),
      shadowPaint,
    );

    // Ripe Golden Mango
    final mangoPaint = Paint()..color = AppDesignSystem.warning;
    final mangoPath = Path()
      ..moveTo(mangoX - 6, mangoY - 8)
      ..cubicTo(mangoX + 16, mangoY - 10, mangoX + 16, mangoY + 12, mangoX, mangoY + 10)
      ..cubicTo(mangoX - 14, mangoY + 8, mangoX - 14, mangoY - 6, mangoX - 6, mangoY - 8)
      ..close();
    canvas.drawPath(mangoPath, mangoPaint);

    // Cute Green Leaf on Mango
    final mangoLeafPaint = Paint()..color = AppDesignSystem.lime500;
    final mangoLeaf = Path()
      ..moveTo(mangoX - 4, mangoY - 7)
      ..quadraticBezierTo(mangoX - 12, mangoY - 14, mangoX - 6, mangoY - 16)
      ..quadraticBezierTo(mangoX, mangoY - 11, mangoX - 4, mangoY - 7);
    canvas.drawPath(mangoLeaf, mangoLeafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

