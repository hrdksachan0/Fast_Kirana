import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

/// Pure Native Vector FastKirana Logo (100% Exact Web Vector Replica)
class FastKiranaLogoWidget extends StatelessWidget {
  final double size;

  const FastKiranaLogoWidget({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (140 / 120),
      height: size,
      child: CustomPaint(
        painter: FastKiranaLogoPainter(),
      ),
    );
  }
}

class FastKiranaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / 120.0;
    canvas.scale(scale);

    final Paint redPaint = Paint()
      ..color = const Color(0xFFE20A22)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Left Speed Lines
    canvas.drawRRect(
      RRect.fromLTRBR(8, 44, 30, 50.5, const Radius.circular(3.25)),
      redPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0.5, 58, 30, 64.5, const Radius.circular(3.25)),
      redPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(8, 72, 30, 78.5, const Radius.circular(3.25)),
      redPaint,
    );
    canvas.drawCircle(const Offset(2, 61.25), 3, redPaint);

    // 2. Main Red Solid Rounded Square Container
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 10, 100, 100),
        const Radius.circular(28),
      ),
      redPaint,
    );

    // 3. Clean Bold Italic Sans-Serif Block 'F' in White
    final Path fPath = Path()
      ..moveTo(62, 32)
      ..lineTo(98, 32)
      ..lineTo(95, 46)
      ..lineTo(75.5, 46)
      ..lineTo(73.4, 56)
      ..lineTo(89, 56)
      ..lineTo(86.5, 68)
      ..lineTo(71, 68)
      ..lineTo(66.8, 88)
      ..lineTo(50.2, 88)
      ..close();

    canvas.drawPath(fPath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Legacy BrandLogo Wrapper for backward compatibility
class BrandLogo extends StatelessWidget {
  final double size;
  final bool withText;
  final bool variant;
  final bool useImageLogo;

  const BrandLogo({
    super.key,
    this.size = 36,
    this.withText = false,
    this.variant = false,
    this.useImageLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!withText) {
      return FastKiranaLogoWidget(size: size);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FastKiranaLogoWidget(size: size),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Fast',
                style: GoogleFonts.inter(
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE20A22),
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Kirana',
                style: GoogleFonts.inter(
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w900,
                  color: variant ? AppDesignSystem.textPrimary : const Color(0xFF7C0617),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}