import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight 60-FPS Ambient Golden Sparkle & Petal Canvas (CanvasUI)
/// Renders subtle floating stardust particles and drifting rose petals
/// to give the Gifting Boutique a luxury, magical atmosphere like festive monsoon rain.
class GiftingSparkleCanvas extends StatefulWidget {
  final Widget child;
  final bool isPaused;

  const GiftingSparkleCanvas({
    super.key,
    required this.child,
    this.isPaused = false,
  });

  @override
  State<GiftingSparkleCanvas> createState() => _GiftingSparkleCanvasState();
}

class _GiftingSparkleCanvasState extends State<GiftingSparkleCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SparkleParticle> _particles;
  final math.Random _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particles = List.generate(24, (i) {
      return _SparkleParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1.5 + _random.nextDouble() * 3.5,
        speed: 0.15 + _random.nextDouble() * 0.35,
        phase: _random.nextDouble() * math.pi * 2,
        isPetal: i % 4 == 0,
        opacity: 0.25 + _random.nextDouble() * 0.55,
      );
    });
  }

  @override
  void didUpdateWidget(covariant GiftingSparkleCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && _controller.isAnimating) {
      _controller.stop();
    } else if (!widget.isPaused && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SparklePainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SparkleParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  final bool isPetal;
  final double opacity;

  const _SparkleParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.isPetal,
    required this.opacity,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_SparkleParticle> particles;
  final double progress;

  _SparklePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final goldPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final petalPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.fill;

    // Constrain particles to top 420px of screen where banner & header live
    final effectiveHeight = math.min(size.height, 460.0);

    for (final p in particles) {
      // Smooth continuous vertical drift
      final currentY = ((p.y + progress * p.speed) % 1.0) * effectiveHeight;
      // Gentle horizontal sway
      final currentX = (p.x * size.width) +
          math.sin((progress * math.pi * 2) + p.phase) * (p.isPetal ? 18.0 : 8.0);

      // Pulsing shimmer opacity
      final shimmer = (math.sin((progress * math.pi * 4) + p.phase) + 1.0) / 2.0;
      final currentOpacity = (p.opacity * (0.35 + 0.65 * shimmer)).clamp(0.0, 1.0);

      if (p.isPetal) {
        petalPaint.color = const Color(0xFFE11D48).withValues(alpha: currentOpacity * 0.45);
        canvas.save();
        canvas.translate(currentX, currentY);
        canvas.rotate((progress * math.pi * 2 + p.phase) * 0.4);
        final petalRect = Rect.fromCenter(
          center: Offset.zero,
          width: p.size * 2.2,
          height: p.size * 1.4,
        );
        canvas.drawOval(petalRect, petalPaint);
        canvas.restore();
      } else {
        // Golden Star / Diamond Sparkle
        goldPaint.color = const Color(0xFFFFDF73).withValues(alpha: currentOpacity * 0.75);

        // 4-point Diamond Stardust
        final path = Path();
        final s = p.size;
        path.moveTo(currentX, currentY - s * 1.4);
        path.lineTo(currentX + s * 0.6, currentY);
        path.lineTo(currentX, currentY + s * 1.4);
        path.lineTo(currentX - s * 0.6, currentY);
        path.close();

        canvas.drawPath(path, goldPaint);

        // Micro center glow dot
        goldPaint.color = Colors.white.withValues(alpha: currentOpacity * 0.9);
        canvas.drawCircle(Offset(currentX, currentY), s * 0.35, goldPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
