import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Real-time blinking Diwali Fairy Lights (Jhalaar) for Blinkit/Swiggy style header.
/// 
/// 4-Phase Festive Rhythm:
/// - Phase 1 (0.00 -> 0.25): 1-0-1-0 Alternating Chaser (Odd bulbs ON at 100%, Even dim at 12%)
/// - Phase 2 (0.25 -> 0.50): 0-1-0-1 Alternating Chaser (Even bulbs ON at 100%, Odd dim at 12%)
/// - Phase 3 (0.50 -> 0.80): PURI SAATH JALEIN! (All bulbs blaze together at 100% full brightness with dynamic diamond star sparkles!)
/// - Phase 4 (0.80 -> 1.00): Soft rhythmic breathing wave returning into Phase 1
/// 
/// Palettes:
/// - 'crimson': Deep Royal Crimson Ruby Red & Brilliant Shining Gold (Option 3)
/// - 'multi': Blinkit Multi-Color (Hot Pink, Cyan Electric, Pure Gold, Emerald Green, Radiant Red, Royal Violet)
/// - 'amber': Warm White & Amber Pearl
/// - 'gold': Pure Golden Yellow (Peeli Diwali Roshni)
class FestiveFairyLights extends StatefulWidget {
  final double height;
  final String palette;

  const FestiveFairyLights({
    super.key,
    this.height = 24.0,
    this.palette = 'crimson',
  });

  @override
  State<FestiveFairyLights> createState() => _FestiveFairyLightsState();
}

class _FestiveFairyLightsState extends State<FestiveFairyLights>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 2.4s cycle for authentic Diwali ladi chaser rhythm
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _DiwaliLadiPainter(
              progress: _controller.value,
              palette: widget.palette,
            ),
          );
        },
      ),
    );
  }
}

class _DiwaliLadiPainter extends CustomPainter {
  final double progress;
  final String palette;

  _DiwaliLadiPainter({
    required this.progress,
    this.palette = 'crimson',
  });

  // Base Cord & Sockets
  static const Color wireColor = Color(0xFF2D4A22); // Deep garland green cord
  static const Color wireGold = Color(0xFFD97706);  // Gold spiral twist
  static const Color socketColor = Color(0xFF92400E); // Brass socket

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    if (width <= 0) return;

    // 1. Hanging festoon cord with natural droop catenaries
    final wirePaint = Paint()
      ..color = wireColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final wireGlint = Paint()
      ..color = wireGold.withValues(alpha: 0.5)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final wirePath = Path();
    wirePath.moveTo(0, 3.0);

    final numSwoops = (width / 80).clamp(3, 7).toInt();
    final swoopWidth = width / numSwoops;

    for (int i = 0; i < numSwoops; i++) {
      final sX = i * swoopWidth;
      final eX = (i + 1) * swoopWidth;
      final mX = sX + swoopWidth / 2;
      wirePath.quadraticBezierTo(mX, 13.0, eX, 3.0);
    }

    canvas.drawPath(wirePath, wirePaint);
    canvas.drawPath(wirePath, wireGlint);

    // 2. Distribute bulbs evenly along the wire
    final numBulbs = (width / 22).clamp(10, 28).toInt();
    final bulbSpacing = width / (numBulbs + 1);

    final double cycle = progress;
    final bool isPhase3 = cycle >= 0.50 && cycle < 0.80;

    for (int i = 0; i < numBulbs; i++) {
      final x = (i + 1) * bulbSpacing;

      // Calculate wire Y
      final swoopIndex = (x / swoopWidth).floor().clamp(0, numSwoops - 1);
      final localX = (x - swoopIndex * swoopWidth) / swoopWidth;
      final wireY = 3.0 + 4 * 10.0 * localX * (1.0 - localX);
      final bulbY = wireY + 7.0;

      // Small vertical hanging stem
      canvas.drawLine(
        Offset(x, wireY),
        Offset(x, wireY + 3.0),
        Paint()
          ..color = wireColor
          ..strokeWidth = 1.2,
      );

      // Brass socket
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, wireY + 3.5), width: 3.6, height: 2.2),
          const Radius.circular(0.8),
        ),
        Paint()..color = socketColor,
      );

      // Intensity Calculation across the 4 Phases
      double intensity;
      if (cycle < 0.25) {
        // Phase 1: 1-0-1-0 (Odd bulbs ON, Even bulbs dim)
        intensity = (i % 2 == 0) ? 1.0 : 0.12;
      } else if (cycle < 0.50) {
        // Phase 2: 0-1-0-1 (Even bulbs ON, Odd bulbs dim)
        intensity = (i % 2 == 1) ? 1.0 : 0.12;
      } else if (isPhase3) {
        // Phase 3: PURI SAATH JALEIN! (All bulbs glowing at full 100% brightness!)
        intensity = 1.0;
      } else {
        // Phase 4: Soft rhythmic breathing wave transition
        final wave = math.sin((cycle - 0.80) / 0.20 * math.pi);
        intensity = 0.35 + 0.65 * wave;
      }

      // Resolve Bulb Colors based on Palette
      Color activeColor;
      Color haloColor;

      if (palette == 'crimson' || palette.contains('crimson')) {
        // Option 3: Deep Royal Crimson Ruby Red & Shining Gold
        if (i % 2 == 0) {
          activeColor = const Color(0xFFE11D48); // Vivid Ruby Crimson
          haloColor = const Color(0xFFFB7185);   // Ruby Prakash Halo
        } else {
          activeColor = const Color(0xFFFFD600); // Brilliant Shining Gold
          haloColor = const Color(0xFFFBBF24);   // Gold Prakash Halo
        }
      } else if (palette == 'multi' || palette.contains('multi')) {
        // 🌈 Blinkit Multi-Color (Pink, Cyan, Golden, Green, Red, Violet)
        const multiColors = [
          Color(0xFFEC4899), // Hot Pink
          Color(0xFF06B6D4), // Cyan Electric
          Color(0xFFFFD600), // Pure Gold
          Color(0xFF22C55E), // Emerald Green
          Color(0xFFDC2626), // Radiant Red
          Color(0xFFA855F7), // Royal Violet
        ];
        activeColor = multiColors[i % multiColors.length];
        haloColor = activeColor;
      } else if (palette == 'amber' || palette.contains('amber')) {
        // Warm White & Amber Pearl
        if (i % 2 == 0) {
          activeColor = const Color(0xFFFFFBEB);
          haloColor = const Color(0xFFFEF3C7);
        } else {
          activeColor = const Color(0xFFFFB74D);
          haloColor = const Color(0xFFFBBF24);
        }
      } else {
        // Pure Golden-Yellow (Peeli Diwali Roshni)
        activeColor = (i % 3 == 0)
            ? const Color(0xFFFFD600)
            : (i % 3 == 1)
                ? const Color(0xFFFFB300)
                : const Color(0xFFFF9100);
        haloColor = const Color(0xFFFBBF24);
      }

      // A. Big Radiant Prakash Halo (Glow)
      if (intensity > 0.35) {
        // In Phase 3, expand radiant halo by +30% for full festive blaze
        final baseHalo = isPhase3 ? 9.5 : 7.0;
        final glowRadius = baseHalo + 6.5 * intensity;
        final glowOpacity = isPhase3 ? 0.45 : (0.35 * intensity);
        final glowPaint = Paint()
          ..color = haloColor.withValues(alpha: glowOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(Offset(x, bulbY), glowRadius, glowPaint);
      }

      // B. Mid Warm Colored Aura
      final midPaint = Paint()
        ..color = activeColor.withValues(alpha: (isPhase3 ? 0.65 : 0.55) * intensity);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, bulbY), width: 7.2, height: 9.6),
        midPaint,
      );

      // C. Golden / Crimson Bulb Teardrop Body
      final bulbPaint = Paint()
        ..color = Color.lerp(activeColor, const Color(0xFFFFFBEB), 0.32 * intensity)!;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, bulbY), width: 4.8, height: 7.2),
        bulbPaint,
      );

      // D. Hotspot Core (Burning bright filament)
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: (isPhase3 ? 1.0 : 0.92) * intensity);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x - 0.6, bulbY - 1.2), width: 2.2, height: 3.4),
        corePaint,
      );

      // E. Diamond Star Sparkles (Puri Saath Jalein + Peak Intensity)
      if (isPhase3) {
        // Dynamic shimmering diamond sparkle on ALL bulbs during Phase 3
        final phaseProgress = (cycle - 0.50) / 0.30;
        final twinkle = 0.82 + 0.32 * math.sin((phaseProgress * 6 * math.pi) + (i * 0.9));
        final starSize = (4.8 * twinkle).clamp(3.0, 6.2);
        _drawDiamondStar(canvas, Offset(x, bulbY), starSize, activeColor, 1.0);
      } else if (intensity > 0.85) {
        // In Phase 1 & 2, active glowing bulbs get a graceful diamond sparkle
        _drawDiamondStar(canvas, Offset(x, bulbY), 3.2, activeColor, 0.85);
      }
    }
  }

  /// Draws a high-end 4-pointed diamond star sparkle with center glint and diagonal micro-rays
  void _drawDiamondStar(
    Canvas canvas,
    Offset center,
    double size,
    Color glowTint,
    double opacity,
  ) {
    final x = center.dx;
    final y = center.dy;

    // 1. Four-Point Diamond Polygon with smooth curved flares
    final diamondPath = Path();
    diamondPath.moveTo(x, y - size);
    diamondPath.quadraticBezierTo(x, y, x + size, y);
    diamondPath.quadraticBezierTo(x, y, x, y + size);
    diamondPath.quadraticBezierTo(x, y, x - size, y);
    diamondPath.quadraticBezierTo(x, y, x, y - size);
    diamondPath.close();

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.95 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, fillPaint);

    // 2. Soft Tinted Prakash Halo matching bulb color
    final haloPaint = Paint()
      ..color = glowTint.withValues(alpha: (0.60 * opacity).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);
    canvas.drawCircle(center, size * 0.75, haloPaint);

    // 3. Four Diagonal Micro-Flares (X-Rays at 45°)
    final diagSize = size * 0.45;
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.80 * opacity).clamp(0.0, 1.0))
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - diagSize, y - diagSize), Offset(x + diagSize, y + diagSize), rayPaint);
    canvas.drawLine(Offset(x + diagSize, y - diagSize), Offset(x - diagSize, y + diagSize), rayPaint);

    // 4. Center Radiant Glint Core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: (1.0 * opacity).clamp(0.0, 1.0));
    canvas.drawCircle(center, 1.2, corePaint);
  }

  @override
  bool shouldRepaint(covariant _DiwaliLadiPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.palette != palette;
  }
}
