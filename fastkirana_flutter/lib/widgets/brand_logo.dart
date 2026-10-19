import 'package:fastminute_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-Crisp Pure Native Vector FastKirana Brand Logo
///
/// Renders a red-gradient rounded square with white speed lines and a bold
/// italic "F" — matching the official brand reference exactly.
///
/// The widget maintains a **fixed 1:1 aspect ratio** at the given [size].
/// All internal geometry scales proportionally from a 100×100 design grid.
class FastKiranaLogoWidget extends StatelessWidget {
  final double size;

  const FastKiranaLogoWidget({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/brand/fastkirana_app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          size: Size(size, size),
          painter: FastKiranaLogoPainter(),
        ),
      ),
    );
  }
}

class FastKiranaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final double scale = s / 100.0;
    canvas.save();
    // Center the 100×100 design inside the actual widget
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(scale);

    // ──────────────── 1. Red Gradient Background ────────────────
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEF2D3A), Color(0xFFC0111F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final RRect bg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(22),
    );

    // Subtle shadow behind the logo
    final Paint shadowPaint = Paint()
      ..color = const Color(0xFFB30013).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(bg.shift(const Offset(0, 2)), shadowPaint);

    canvas.drawRRect(bg, bgPaint);

    // ──────────────── White Paint (shared) ────────────────
    final Paint white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // ──────────────── 2. Speed Lines (4 rounded pills) ────────────────
    // 4 horizontal white pills on the left, staggered for motion effect.
    // Designed to sit left of the F, vertically centered in the icon.
    const double lineH = 5.5;
    const double lineR = 2.75;

    // [x, y, width] — staggered x-offsets create the italic-slant motion feel
    const lines = [
      [15.0, 30.0, 16.0], // top — shortest, furthest right
      [11.0, 39.5, 22.0], // second — longer
      [9.0,  49.0, 25.0], // third — longest
      [13.0, 58.5, 18.0], // bottom — shorter again
    ];

    for (final l in lines) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(l[0], l[1], l[2], lineH),
          const Radius.circular(lineR),
        ),
        white,
      );
    }

    // ──────────────── 3. Bold Italic "F" with curved swoosh ────────────────
    // The "F" occupies roughly x:36–82, y:18–84 on the 100×100 grid.
    // Features: thick bold strokes, italic lean (~8°), rounded top-right,
    // and a smooth swoosh curve at the bottom of the vertical stem.

    final Path fPath = Path();

    // --- Top bar ---
    // Start at top-left of the stem
    fPath.moveTo(50, 18);
    // Across the top
    fPath.lineTo(78, 18);
    // Rounded top-right corner
    fPath.quadraticBezierTo(82, 18, 81, 22);
    // Down the right edge of top bar
    fPath.lineTo(78, 31);
    // Left along bottom of top bar to inner corner
    fPath.lineTo(60, 31);

    // --- Middle crossbar ---
    // Down the stem to crossbar top
    fPath.lineTo(58, 41);
    // Right along crossbar top
    fPath.lineTo(74, 41);
    // Rounded right end
    fPath.quadraticBezierTo(76, 41, 75.5, 43);
    // Down to crossbar bottom
    fPath.lineTo(73, 50);
    // Left along crossbar bottom
    fPath.lineTo(56, 50);

    // --- Vertical stem going down with swoosh ---
    // Continue stem down
    fPath.lineTo(50, 70);

    // Swoosh curve at the bottom — the signature brand element
    // Curves left and down, then hooks back
    fPath.quadraticBezierTo(48, 78, 43, 82);
    fPath.quadraticBezierTo(38, 86, 35, 82);
    fPath.quadraticBezierTo(32, 78, 36, 74);
    fPath.quadraticBezierTo(39, 70, 42, 62);

    // --- Left edge of stem going back up ---
    fPath.lineTo(46, 50);
    fPath.lineTo(46, 41);
    fPath.lineTo(46, 31);
    fPath.lineTo(44, 18);

    fPath.close();

    canvas.drawPath(fPath, white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Brand Logo with optional Brand Text
class BrandLogo extends StatelessWidget {
  final double size;
  final bool withText;
  final Color? textColor;

  const BrandLogo({
    super.key,
    this.size = 36,
    this.withText = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!withText) {
      return FastKiranaLogoWidget(size: size);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FastKiranaLogoWidget(size: size),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FastMinute',
              style: GoogleFonts.inter(
                fontSize: size * 0.58,
                fontWeight: FontWeight.w900,
                color: textColor ?? AppDesignSystem.slate900,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            Text(
              'EXPRESS DELIVERY',
              style: GoogleFonts.inter(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}