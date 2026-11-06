import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blinkit / Zepto style animated delivery bag with peeking farm-fresh fruits
/// and official FastMinute high-resolution speed 'F' logo badge.
class BlinkitAnimatedBag extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onCycleTap;

  const BlinkitAnimatedBag({
    super.key,
    this.title = '100% Farm-Fresh Fruits & Vegetables',
    this.subtitle = 'Delivered fresh at your doorstep with superfast delivery',
    this.onCycleTap,
  });

  @override
  State<BlinkitAnimatedBag> createState() => _BlinkitAnimatedBagState();
}

class _BlinkitAnimatedBagState extends State<BlinkitAnimatedBag>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bagBounce;
  late Animation<double> _bagSquashX;
  late Animation<double> _bagSquashY;
  late Animation<double> _fruitsFloat;
  late Animation<double> _shadowScale;
  late Animation<double> _shadowOpacity;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Squash & Stretch Bounce Curve
    _bagBounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -38.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -16.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -16.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -6.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 13,
      ),
    ]).animate(_bounceController);

    // Horizontal Squash (scaleX)
    _bagSquashX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.00)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_bounceController);

    // Vertical Squash (scaleY)
    _bagSquashY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.85)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.00)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_bounceController);

    // Peeking fruits lag & secondary bounce
    _fruitsFloat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -8.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -8.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_bounceController);

    // Shadow scale & opacity
    _shadowScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.70, end: 1.20)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.20, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.00)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_bounceController);

    _shadowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: 0.28)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.28, end: 0.16)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.16, end: 0.24)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.24, end: 0.20)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Center Stage: Delivery Bag + Peeking Fruits
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Dynamic Ground Shadow
                  Positioned(
                    bottom: 8,
                    child: Transform.scale(
                      scaleX: _shadowScale.value,
                      scaleY: _shadowScale.value * 0.45,
                      child: Container(
                        width: 140,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B)
                              .withValues(alpha: _shadowOpacity.value),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),

                  // 2. Physics Bouncing Bag & Peeking Fruits
                  Positioned(
                    bottom: 24,
                    child: Transform.translate(
                      offset: Offset(0, _bagBounce.value),
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(
                          _bagSquashX.value,
                          _bagSquashY.value,
                          1.0,
                        ),
                        child: _buildBagWithFruits(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Tagline & Superfast delivery text (Clean typography, NO "10 MINS")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Shimmer Loading Progress Indicator
            _buildShimmerIndicator(),

            const SizedBox(height: 28),

            // Clean FastMinute Branding at Bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'FASTMINUTE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Builds the delivery bag with arched handles, peeking fruits, and the official 'F' logo
  Widget _buildBagWithFruits() {
    return SizedBox(
      width: 150,
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // A. Peeking Fruits (Behind Bag Front, Floats Gently)
          Positioned(
            top: 14,
            child: Transform.translate(
              offset: Offset(0, _fruitsFloat.value),
              child: const _PeekingFruitsWidget(),
            ),
          ),

          // B. Arched Handle
          Positioned(
            top: 26,
            child: Container(
              width: 58,
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF991B1B), // Deep maroon handle
                  width: 5.5,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
            ),
          ),

          // C. Bag Front Body
          Positioned(
            bottom: 0,
            child: Container(
              width: 140,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEF4444), // Vibrant Red
                    Color(0xFFDC2626), // Classic Brand Red
                    Color(0xFFB91C1C), // Deep Bottom Red
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle top rim highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // OFFICIAL FASTMINUTE SPEED 'F' LOGO BADGE
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/brand/fastminute_logo_hq.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Resilient fallback to branded speed F if image missing
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'F',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Subtle bottom edge gradient crease
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                      ),
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

  /// Shimmer loading bar
  Widget _buildShimmerIndicator() {
    return Container(
      width: 140,
      height: 4.5,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shimmerX = (_bounceController.value * 2.2 - 0.6) * constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: shimmerX,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * 0.45,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFFE11D48),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Farm Fresh Fruits peeking out from the bag:
/// Bananas 🍌, Crisp Gala Apple 🍎, Farm Carrot 🥕, Nagpur Orange 🍊
class _PeekingFruitsWidget extends StatelessWidget {
  const _PeekingFruitsWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Ripe Yellow Bananas (Tilted Left)
          Positioned(
            left: 2,
            bottom: 4,
            child: Transform.rotate(
              angle: -0.22,
              child: const _BananaGraphic(size: 42),
            ),
          ),

          // 2. Crisp Gala Apple with Green Leaf (Center-Left)
          Positioned(
            left: 36,
            bottom: 6,
            child: Transform.rotate(
              angle: -0.08,
              child: const _AppleGraphic(size: 40),
            ),
          ),

          // 3. Farm Carrot with Green Foliage (Center-Right Peeking High)
          Positioned(
            right: 36,
            bottom: 12,
            child: Transform.rotate(
              angle: 0.18,
              child: const _CarrotGraphic(size: 42),
            ),
          ),

          // 4. Nagpur Orange with Fresh Leaf (Right)
          Positioned(
            right: 4,
            bottom: 4,
            child: Transform.rotate(
              angle: 0.12,
              child: const _OrangeGraphic(size: 38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vector Drawn Apple Graphic
class _AppleGraphic extends StatelessWidget {
  final double size;
  const _AppleGraphic({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ApplePainter(),
      ),
    );
  }
}

class _ApplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Stem
    final stemPaint = Paint()
      ..color = const Color(0xFF78350F)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stemPath = Path()
      ..moveTo(w * 0.50, h * 0.30)
      ..quadraticBezierTo(w * 0.54, h * 0.15, w * 0.60, h * 0.10);
    canvas.drawPath(stemPath, stemPaint);

    // Green Leaf
    final leafPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    final leafPath = Path()
      ..moveTo(w * 0.52, h * 0.20)
      ..quadraticBezierTo(w * 0.70, h * 0.12, w * 0.75, h * 0.22)
      ..quadraticBezierTo(w * 0.62, h * 0.28, w * 0.52, h * 0.20);
    canvas.drawPath(leafPath, leafPaint);

    // Apple Body (Juicy Red Gradient)
    final applePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.2),
        radius: 0.8,
        colors: [
          Color(0xFFF87171), // Highlight
          Color(0xFFDC2626), // Main red
          Color(0xFF991B1B), // Shadow
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.2, w, h * 0.8));

    final bodyPath = Path()
      ..moveTo(w * 0.5, h * 0.35)
      ..cubicTo(w * 0.35, h * 0.24, w * 0.08, h * 0.28, w * 0.08, h * 0.55)
      ..cubicTo(w * 0.08, h * 0.82, w * 0.38, h * 0.98, w * 0.5, h * 0.98)
      ..cubicTo(w * 0.62, h * 0.98, w * 0.92, h * 0.82, w * 0.92, h * 0.55)
      ..cubicTo(w * 0.92, h * 0.28, w * 0.65, h * 0.24, w * 0.5, h * 0.35)
      ..close();

    canvas.drawPath(bodyPath, applePaint);

    // Specular Highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(w * 0.30, h * 0.45);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.14, height: h * 0.24),
      shinePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector Drawn Banana Bundle Graphic
class _BananaGraphic extends StatelessWidget {
  final double size;
  const _BananaGraphic({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.05,
      height: size,
      child: CustomPaint(
        painter: _BananaPainter(),
      ),
    );
  }
}

class _BananaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bananaPaint = Paint()
      ..color = const Color(0xFFFACC15) // Banana Yellow
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFCA8A04) // Darker ridge
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemTipPaint = Paint()
      ..color = const Color(0xFF65A30D) // Greenish tip
      ..style = PaintingStyle.fill;

    // Curved Banana Shape
    final bananaPath = Path()
      ..moveTo(w * 0.12, h * 0.88)
      ..quadraticBezierTo(w * 0.25, h * 0.40, w * 0.85, h * 0.22)
      ..lineTo(w * 0.88, h * 0.26)
      ..quadraticBezierTo(w * 0.42, h * 0.52, w * 0.30, h * 0.94)
      ..close();

    canvas.drawPath(bananaPath, bananaPaint);
    canvas.drawPath(bananaPath, strokePaint);

    // Inner Ridge line
    final ridgePath = Path()
      ..moveTo(w * 0.20, h * 0.88)
      ..quadraticBezierTo(w * 0.38, h * 0.46, w * 0.82, h * 0.24);
    canvas.drawPath(ridgePath, strokePaint);

    // Green Tip
    canvas.drawCircle(Offset(w * 0.87, h * 0.24), 2.5, stemTipPaint);

    // Brown bottom stalk
    final bottomPaint = Paint()..color = const Color(0xFF78350F);
    canvas.drawCircle(Offset(w * 0.13, h * 0.89), 2.2, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector Drawn Nagpur Orange Graphic
class _OrangeGraphic extends StatelessWidget {
  final double size;
  const _OrangeGraphic({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrangePainter(),
      ),
    );
  }
}

class _OrangePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Little Green Leaf
    final leafPaint = Paint()..color = const Color(0xFF16A34A);
    final leafPath = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..quadraticBezierTo(w * 0.65, h * 0.12, w * 0.70, h * 0.22)
      ..quadraticBezierTo(w * 0.58, h * 0.28, w * 0.50, h * 0.22);
    canvas.drawPath(leafPath, leafPaint);

    // Orange Body (Vibrant Radial Gradient)
    final orangePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.2),
        radius: 0.75,
        colors: [
          Color(0xFFFED7AA), // Light highlight
          Color(0xFFFB923C), // Bright orange
          Color(0xFFEA580C), // Deep orange
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.15, w, h * 0.85));

    final radius = (w * 0.44);
    final center = Offset(w * 0.50, h * 0.58);
    canvas.drawCircle(center, radius, orangePaint);

    // Texture dots
    final dotPaint = Paint()..color = const Color(0xFFC2410C).withValues(alpha: 0.35);
    canvas.drawCircle(Offset(center.dx - 6, center.dy + 4), 1.0, dotPaint);
    canvas.drawCircle(Offset(center.dx + 7, center.dy + 8), 1.0, dotPaint);
    canvas.drawCircle(Offset(center.dx + 2, center.dy - 6), 1.0, dotPaint);

    // Specular Highlight
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.42);
    canvas.save();
    canvas.translate(center.dx - 6, center.dy - 6);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.12, height: h * 0.20),
      shinePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector Drawn Farm Carrot Graphic
class _CarrotGraphic extends StatelessWidget {
  final double size;
  const _CarrotGraphic({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.75,
      height: size,
      child: CustomPaint(
        painter: _CarrotPainter(),
      ),
    );
  }
}

class _CarrotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green Foliage / Leaves
    final foliagePaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leaf1 = Path()
      ..moveTo(w * 0.5, h * 0.28)
      ..quadraticBezierTo(w * 0.3, h * 0.12, w * 0.2, h * 0.05);
    final leaf2 = Path()
      ..moveTo(w * 0.5, h * 0.28)
      ..quadraticBezierTo(w * 0.52, h * 0.08, w * 0.5, h * 0.02);
    final leaf3 = Path()
      ..moveTo(w * 0.5, h * 0.28)
      ..quadraticBezierTo(w * 0.68, h * 0.12, w * 0.8, h * 0.06);

    canvas.drawPath(leaf1, foliagePaint);
    canvas.drawPath(leaf2, foliagePaint);
    canvas.drawPath(leaf3, foliagePaint);

    // Carrot Body (Tapered cone)
    final carrotPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFB923C),
          Color(0xFFF97316),
          Color(0xFFEA580C),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, h * 0.25, w, h * 0.75));

    final bodyPath = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..quadraticBezierTo(w * 0.5, h * 0.25, w * 0.68, h * 0.28)
      ..quadraticBezierTo(w * 0.62, h * 0.68, w * 0.52, h * 0.96)
      ..quadraticBezierTo(w * 0.48, h * 0.96, w * 0.38, h * 0.68)
      ..close();

    canvas.drawPath(bodyPath, carrotPaint);

    // Ridge lines
    final ridgePaint = Paint()
      ..color = const Color(0xFFC2410C)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.40, h * 0.44), Offset(w * 0.60, h * 0.44), ridgePaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.60), Offset(w * 0.58, h * 0.60), ridgePaint);
    canvas.drawLine(Offset(w * 0.46, h * 0.76), Offset(w * 0.54, h * 0.76), ridgePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
