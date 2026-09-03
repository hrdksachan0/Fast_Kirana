import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Supported Contextual Themes for FastKirana Transitions
enum TransitionContextType {
  grocery,      // Fresh fruits, milk, kraft bag, green sparkles
  cafe,         // Gourmet burger, fries, steaming latte, food coral
  essentials,   // Smartwatch, electric trimmer, earbuds, cyan glow (Blinkit-plus style)
  checkout,     // Delivery box, lightning badge, GPS pin, gold amber
  storeFinder,  // Radar scanner, delivery scooter, map pin, indigo
}

/// ─────────────────────────────────────────────────────────────────────────────
/// ULTRA-SMOOTH CONTEXTUAL BRAND TRANSITION SCREEN
/// Features:
/// - Distinct custom 3D-styled vector illustrations per context
/// - Multi-layered independent floating physics (different sin/cos speeds)
/// - Interactive finger touch 3D tilt
/// - Pulsing live status pill & dynamic contextual taglines
/// ─────────────────────────────────────────────────────────────────────────────
class ContextualBrandTransitionScreen extends StatefulWidget {
  final TransitionContextType contextType;
  final String? customTitle;
  final String? customSubtitle;
  final VoidCallback? onFinished;
  final Duration? autoDismissDuration;

  const ContextualBrandTransitionScreen({
    super.key,
    this.contextType = TransitionContextType.grocery,
    this.customTitle,
    this.customSubtitle,
    this.onFinished,
    this.autoDismissDuration,
  });

  @override
  State<ContextualBrandTransitionScreen> createState() => _ContextualBrandTransitionScreenState();
}

class _ContextualBrandTransitionScreenState extends State<ContextualBrandTransitionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _floatController1;
  late AnimationController _floatController2;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _scaleAnim;

  Offset _touchTilt = Offset.zero;

  @override
  void initState() {
    super.initState();

    // 1. Entry Animation (Spring Fade & Scale Up)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    );

    // 2. Primary Floating Physics Controller (2.4s period)
    _floatController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 3. Secondary Off-sync Floating Physics Controller (1.7s period)
    _floatController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    // 4. Ambient Aura & Sparkle Pulse Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _entryController.forward();

    // Auto-dismiss handling if duration provided
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
    _entryController.dispose();
    _floatController1.dispose();
    _floatController2.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Configuration helpers based on context type
  Color get _accentColor {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return const Color(0xFF16A34A); // Emerald green
      case TransitionContextType.cafe:
        return const Color(0xFFE20A22); // FastKirana Red / Coral
      case TransitionContextType.essentials:
        return const Color(0xFF0284C7); // Cyan / Electric Blue
      case TransitionContextType.checkout:
        return const Color(0xFFD97706); // Amber Gold
      case TransitionContextType.storeFinder:
        return const Color(0xFF6366F1); // Indigo Purple
    }
  }

  Color get _glowColor {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return const Color(0xFFDCFCE7);
      case TransitionContextType.cafe:
        return const Color(0xFFFFE4E6);
      case TransitionContextType.essentials:
        return const Color(0xFFE0F2FE);
      case TransitionContextType.checkout:
        return const Color(0xFFFEF3C7);
      case TransitionContextType.storeFinder:
        return const Color(0xFFEEF2FF);
    }
  }



  String get _defaultTitle {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return 'Fresh groceries,\ndelivered to your doorstep!';
      case TransitionContextType.cafe:
        return 'Hot & fresh food from\nnearby restaurants delivered!';
      case TransitionContextType.essentials:
        return 'Everything you need,\ndelivered at your doorstep!';
      case TransitionContextType.checkout:
        return 'Confirming order & routing\nto nearest delivery partner...';
      case TransitionContextType.storeFinder:
        return 'Finding nearest dark store\nwith freshest live stock...';
    }
  }

  String get _subBrandTag {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return 'FASTKIRANA GROCERY EXPRESS';
      case TransitionContextType.cafe:
        return 'NEARBY RESTAURANTS';
      case TransitionContextType.essentials:
        return 'FASTKIRANA QUICK COMMERCE';
      case TransitionContextType.checkout:
        return 'FASTKIRANA PRIORITY FULFILLMENT';
      case TransitionContextType.storeFinder:
        return 'FASTKIRANA REALTIME RADAR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _touchTilt = Offset(
            (details.localPosition.dx - MediaQuery.of(context).size.width / 2) / 300,
            (details.localPosition.dy - MediaQuery.of(context).size.height / 2) / 300,
          );
        });
      },
      onPanEnd: (_) {
        setState(() {
          _touchTilt = Offset.zero;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _entryController,
              _floatController1,
              _floatController2,
              _pulseController,
            ]),
            builder: (context, _) {
              final f1 = math.sin(_floatController1.value * math.pi) * 6.0;
              final f2 = math.cos(_floatController2.value * math.pi) * 5.0;
              final pulse = _pulseController.value;

              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          const Spacer(flex: 5),

                          // 3D Floating Vector Scene with Touch Parallax
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // perspective
                              ..rotateX(-_touchTilt.dy * 0.15)
                              ..rotateY(_touchTilt.dx * 0.15),
                            child: _buildContextScene(f1, f2, pulse),
                          ),

                          const SizedBox(height: 36),

                          // 3. Editorial Clean Modern Typography (Blinkit-plus style)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              widget.customTitle ?? _defaultTitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 21),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                height: 1.38,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),

                          if (widget.customSubtitle != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                widget.customSubtitle!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],

                          const Spacer(flex: 5),

                          // 4. Subtle Minimalist FastKirana Brand Spine at Bottom
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _subBrandTag,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFCBD5E1),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds context-specific layered vector scenes
  Widget _buildContextScene(double f1, double f2, double pulse) {
    return SizedBox(
      width: 200,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Aura Glow (Pulsing)
          Container(
            width: 150 + 10 * pulse,
            height: 150 + 10 * pulse,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _glowColor.withOpacity(0.7),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.06 * pulse),
                  blurRadius: 40,
                  spreadRadius: 15,
                ),
              ],
            ),
          ),

          // Micro sparkles
          Positioned(
            top: 14 + f2 * 0.4,
            right: 22,
            child: Opacity(
              opacity: 0.3 + 0.7 * pulse,
              child: Icon(Icons.auto_awesome, size: 16, color: _accentColor.withOpacity(0.9)),
            ),
          ),
          Positioned(
            bottom: 24 + f1 * 0.4,
            left: 20,
            child: Opacity(
              opacity: 0.3 + 0.6 * (1.0 - pulse),
              child: Icon(Icons.star_rounded, size: 14, color: _accentColor.withOpacity(0.7)),
            ),
          ),

          // Layer 1: Back floating item (Float 1)
          Transform.translate(
            offset: Offset(0, -f1),
            child: _buildSpecificBackIllustration(),
          ),

          // Layer 2: Center/Front floating item (Float 2 - off sync for 3D realism)
          Transform.translate(
            offset: Offset(0, f2),
            child: _buildSpecificFrontIllustration(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificBackIllustration() {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _GroceryBackPainter(),
        );
      case TransitionContextType.cafe:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _CafeBackPainter(),
        );
      case TransitionContextType.essentials:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _EssentialsBackPainter(),
        );
      case TransitionContextType.checkout:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _CheckoutBackPainter(),
        );
      case TransitionContextType.storeFinder:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _StoreFinderBackPainter(),
        );
    }
  }

  Widget _buildSpecificFrontIllustration() {
    switch (widget.contextType) {
      case TransitionContextType.grocery:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _GroceryFrontPainter(),
        );
      case TransitionContextType.cafe:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _CafeFrontPainter(),
        );
      case TransitionContextType.essentials:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _EssentialsFrontPainter(),
        );
      case TransitionContextType.checkout:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _CheckoutFrontPainter(),
        );
      case TransitionContextType.storeFinder:
        return CustomPaint(
          size: const Size(160, 140),
          painter: _StoreFinderFrontPainter(),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. GROCERY PAINTERS (Kraft Bag, Milk Bottle, Fresh Mango & Leaves)
// ─────────────────────────────────────────────────────────────────────────────
class _GroceryBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Milk Carton (Left)
    final milkX = center.dx - 32;
    final milkY = center.dy - 12;
    final milkBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(milkX, milkY + 12), width: 30, height: 44),
      const Radius.circular(5),
    );
    canvas.drawRRect(milkBody, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawRRect(milkBody, Paint()..color = const Color(0xFFE20822).withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Blue milk band
    final band = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset(milkX, milkY + 14), width: 30, height: 14),
    );
    canvas.drawRRect(band, Paint()..color = const Color(0xFF38BDF8));

    // Gable top
    final roof = Path()
      ..moveTo(milkX - 15, milkY - 10)
      ..lineTo(milkX, milkY - 22)
      ..lineTo(milkX + 15, milkY - 10)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF0284C7));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroceryFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Kraft Eco Bag
    final bagPath = Path()
      ..moveTo(center.dx - 28, center.dy - 6)
      ..lineTo(center.dx + 28, center.dy - 6)
      ..lineTo(center.dx + 23, center.dy + 30)
      ..lineTo(center.dx - 23, center.dy + 30)
      ..close();
    canvas.drawPath(bagPath, Paint()..color = const Color(0xFFD97706).withOpacity(0.9));

    // Bag Lip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 7), width: 58, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFB45309),
    );

    // FastKirana Red Logo Badge
    canvas.drawCircle(Offset(center.dx, center.dy + 12), 9, Paint()..color = const Color(0xFFE20A22));
    final fPaint = Paint()..color = Colors.white..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - 2, center.dy + 7), Offset(center.dx - 2, center.dy + 17), fPaint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 8), Offset(center.dx + 3, center.dy + 8), fPaint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 12), Offset(center.dx + 2, center.dy + 12), fPaint);

    // Golden Alphonso Mango (Right)
    final mangoX = center.dx + 24;
    final mangoY = center.dy + 14;
    final mangoPath = Path()
      ..moveTo(mangoX - 5, mangoY - 7)
      ..cubicTo(mangoX + 15, mangoY - 9, mangoX + 15, mangoY + 11, mangoX, mangoY + 9)
      ..cubicTo(mangoX - 13, mangoY + 7, mangoX - 13, mangoY - 5, mangoX - 5, mangoY - 7)
      ..close();
    canvas.drawPath(mangoPath, Paint()..color = const Color(0xFFF59E0B));

    // Leaf
    final leaf = Path()
      ..moveTo(mangoX - 3, mangoY - 6)
      ..quadraticBezierTo(mangoX - 10, mangoY - 12, mangoX - 5, mangoY - 14)
      ..quadraticBezierTo(mangoX, mangoY - 10, mangoX - 3, mangoY - 6);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF22C55E));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. CAFE / FOOD PAINTERS (Steaming Coffee, Gourmet Burger, Fries)
// ─────────────────────────────────────────────────────────────────────────────
class _CafeBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // French Fries Box (Right)
    final fryX = center.dx + 28;
    final fryY = center.dy + 4;
    final cup = Path()
      ..moveTo(fryX - 14, fryY - 4)
      ..lineTo(fryX + 14, fryY - 4)
      ..lineTo(fryX + 10, fryY + 24)
      ..lineTo(fryX - 10, fryY + 24)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0xFFE20A22));

    // Fries Sticks
    final fryPaint = Paint()..color = const Color(0xFFFBBF24)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(fryX - 7, fryY - 4), Offset(fryX - 9, fryY - 18), fryPaint);
    canvas.drawLine(Offset(fryX - 1, fryY - 4), Offset(fryX - 1, fryY - 22), fryPaint);
    canvas.drawLine(Offset(fryX + 5, fryY - 4), Offset(fryX + 6, fryY - 19), fryPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CafeFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 - 8, size.height / 2 + 10);

    // Burger Bottom Bun
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 12), width: 48, height: 10),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFF59E0B),
    );

    // Patty
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 5), width: 50, height: 7),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF78350F),
    );

    // Melted Cheese
    final cheese = Path()
      ..moveTo(center.dx - 24, center.dy + 3)
      ..lineTo(center.dx + 24, center.dy + 3)
      ..lineTo(center.dx + 14, center.dy + 8)
      ..lineTo(center.dx - 4, center.dy + 3)
      ..lineTo(center.dx - 16, center.dy + 9)
      ..close();
    canvas.drawPath(cheese, Paint()..color = const Color(0xFFFBBF24));

    // Top Dome Bun
    final topBun = Path()
      ..moveTo(center.dx - 24, center.dy - 3)
      ..quadraticBezierTo(center.dx, center.dy - 24, center.dx + 24, center.dy - 3)
      ..close();
    canvas.drawPath(topBun, Paint()..color = const Color(0xFFF59E0B));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. ESSENTIALS & TECH PAINTERS (Blinkit-Plus: Smartwatch, Electric Trimmer, Earbuds)
// ─────────────────────────────────────────────────────────────────────────────
class _EssentialsBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Pastel Smartwatch (Left / Pink-Peach modern claymorphism)
    final watchX = center.dx - 30;
    final watchY = center.dy - 2;

    // Watch Strap
    final strap = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(watchX, watchY), width: 14, height: 62),
      const Radius.circular(7),
    );
    canvas.drawRRect(strap, Paint()..color = const Color(0xFFFFD1D5));

    // Watch Dial Body
    final dial = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(watchX, watchY), width: 32, height: 36),
      const Radius.circular(9),
    );
    canvas.drawRRect(dial, Paint()..color = const Color(0xFFFFF0F2));
    canvas.drawRRect(dial, Paint()..color = const Color(0xFFFDA4AF)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Watch Screen Glass
    final screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(watchX, watchY), width: 22, height: 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(screen, Paint()..color = const Color(0xFF1E293B));

    // Time Indicator on Watch (10:00)
    final timePaint = Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(watchX, watchY), Offset(watchX, watchY - 5), timePaint);
    canvas.drawLine(Offset(watchX, watchY), Offset(watchX + 4, watchY), timePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EssentialsFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Electric Grooming Trimmer (Right / Cyan-Mint modern claymorphism)
    final trimX = center.dx + 20;
    final trimY = center.dy + 4;

    // Trimmer Body
    final trimmerBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(trimX, trimY + 8), width: 28, height: 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(trimmerBody, Paint()..color = const Color(0xFF67E8F9));

    // Power Button on Trimmer
    canvas.drawCircle(Offset(trimX, trimY + 12), 4, Paint()..color = const Color(0xFF06B6D4));

    // Blade Head Top (Teeth Comb)
    final blade = Path()
      ..moveTo(trimX - 15, trimY - 16)
      ..lineTo(trimX + 15, trimY - 16)
      ..lineTo(trimX + 13, trimY - 26)
      ..lineTo(trimX - 13, trimY - 26)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFF22D3EE));

    // Comb Teeth
    final toothPaint = Paint()..color = const Color(0xFF0891B2)..strokeWidth = 1.5;
    for (int i = -10; i <= 10; i += 4) {
      canvas.drawLine(Offset(trimX + i.toDouble(), trimY - 17), Offset(trimX + i.toDouble(), trimY - 25), toothPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CHECKOUT & DISPATCH PAINTERS (Delivery Box, Lightning ⚡, GPS Pin)
// ─────────────────────────────────────────────────────────────────────────────
class _CheckoutBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // GPS Pin (Top-Right)
    final pinX = center.dx + 30;
    final pinY = center.dy - 20;
    canvas.drawCircle(Offset(pinX, pinY), 10, Paint()..color = const Color(0xFFE20A22));
    canvas.drawCircle(Offset(pinX, pinY), 4, Paint()..color = Colors.white);
    final pinTail = Path()
      ..moveTo(pinX - 8, pinY + 5)
      ..lineTo(pinX, pinY + 18)
      ..lineTo(pinX + 8, pinY + 5)
      ..close();
    canvas.drawPath(pinTail, Paint()..color = const Color(0xFFE20A22));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckoutFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 - 4, size.height / 2 + 6);

    // 3D Delivery Parcel Box
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 8), width: 54, height: 44),
      const Radius.circular(8),
    );
    canvas.drawRRect(boxRect, Paint()..color = const Color(0xFFF59E0B));

    // Box Tape Strip
    final tape = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 8), width: 14, height: 44),
      const Radius.circular(2),
    );
    canvas.drawRRect(tape, Paint()..color = const Color(0xFFD97706));

    // Lightning Bolt ⚡ on Box
    final bolt = Path()
      ..moveTo(center.dx + 2, center.dy - 2)
      ..lineTo(center.dx - 5, center.dy + 8)
      ..lineTo(center.dx - 1, center.dy + 8)
      ..lineTo(center.dx - 3, center.dy + 18)
      ..lineTo(center.dx + 5, center.dy + 7)
      ..lineTo(center.dx + 1, center.dy + 7)
      ..close();
    canvas.drawPath(bolt, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. STORE FINDER / REALTIME RADAR PAINTERS (Radar Scanner & Delivery Bike)
// ─────────────────────────────────────────────────────────────────────────────
class _StoreFinderBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Radar Pulse Rings
    final ringPaint = Paint()
      ..color = const Color(0xFF818CF8).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 35, ringPaint);
    canvas.drawCircle(center, 55, ringPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StoreFinderFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Center Pulse Hub
    canvas.drawCircle(center, 18, Paint()..color = const Color(0xFF6366F1));
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF4F46E5));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}