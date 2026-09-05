import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-Crisp Pure Native Vector FastKirana Brand Logo
class FastKiranaLogoWidget extends StatelessWidget {
  final double size;

  const FastKiranaLogoWidget({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (135 / 110),
      height: size,
      child: CustomPaint(
        isComplex: true,
        willChange: false,
        painter: FastKiranaLogoPainter(),
      ),
    );
  }
}

class FastKiranaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / 110.0;
    canvas.scale(scale);

    final Paint redPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppDesignSystem.primary, AppDesignSystem.red400],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, 135, 110))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Left Speed Lines (3 dynamic sleek pills)
    // Top Line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 38, 22, 6.5),
        const Radius.circular(3.25),
      ),
      redPaint,
    );
    // Middle Line (Longest)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 52, 28, 7.5),
        const Radius.circular(3.75),
      ),
      redPaint,
    );
    // Bottom Line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 66, 20, 6.5),
        const Radius.circular(3.25),
      ),
      redPaint,
    );

    // 2. Main Red Squircle with soft shadow & rounded corners
    final RRect squircle = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 5, 100, 100),
      const Radius.circular(26),
    );

    // Soft Shadow
    final Paint shadowPaint = Paint()
      ..color = AppDesignSystem.primary.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(squircle.shift(const Offset(0, 4)), shadowPaint);

    // Main Body
    canvas.drawRRect(squircle, redPaint);

    // 3. Bold Dynamic Italic 'F'
    final Path fPath = Path()
      ..moveTo(63, 26) // Top Left
      ..lineTo(98, 26) // Top Right
      ..lineTo(94.5, 41) // Top Bar bottom right
      ..lineTo(76.5, 41) // Top Bar inner corner
      ..lineTo(74.2, 51.5) // Middle Bar top left
      ..lineTo(90, 51.5) // Middle Bar right
      ..lineTo(87, 64) // Middle Bar bottom right
      ..lineTo(71.5, 64) // Middle Bar inner corner
      ..lineTo(66.5, 85) // Bottom right
      ..lineTo(51.5, 85) // Bottom left
      ..close();

    canvas.drawPath(fPath, whitePaint);
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
              'FastKirana',
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