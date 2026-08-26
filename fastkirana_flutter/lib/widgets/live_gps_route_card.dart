import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveGpsRouteCard extends StatefulWidget {
  final String orderId;
  final String storeName;
  final String destinationAddress;
  final int totalMinutes;
  final bool isDelivered;

  const LiveGpsRouteCard({
    super.key,
    required this.orderId,
    this.storeName = 'FastKirana Darkstore Hub',
    this.destinationAddress = 'Ghatampur Market, UP 209206',
    this.totalMinutes = 12,
    this.isDelivered = false,
  });

  @override
  State<LiveGpsRouteCard> createState() => _LiveGpsRouteCardState();
}

class _LiveGpsRouteCardState extends State<LiveGpsRouteCard> with SingleTickerProviderStateMixin {
  late AnimationController _scooterController;
  late Animation<double> _scooterProgress;

  Timer? _countdownTimer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();

    _remainingSeconds = widget.isDelivered ? 0 : widget.totalMinutes * 60 - 36;

    // Smooth continuous scooter movement along the curve
    _scooterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scooterProgress = CurvedAnimation(
      parent: _scooterController,
      curve: Curves.linear,
    );

    // Live countdown timer ticking down every second
    if (!widget.isDelivered) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_remainingSeconds > 0) {
            setState(() {
              _remainingSeconds--;
            });
          } else {
            timer.cancel();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scooterController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'Arrived at Doorstep!';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final minStr = mins < 10 ? '0$mins' : '$mins';
    final secStr = secs < 10 ? '0$secs' : '$secs';
    return 'Arriving in $minStr:$secStr mins';
  }

  @override
  Widget build(BuildContext context) {
    final countdownText = _formatCountdown(_remainingSeconds);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Luxury Dark Tech Canvas
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Countdown & Live Status Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isDelivered ? const Color(0xFF10B981) : const Color(0xFFE20A22),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isDelivered ? const Color(0xFF10B981) : const Color(0xFFE20A22)).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isDelivered ? 'ORDER DELIVERED' : countdownText,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6)),
                  ),
                  child: Text(
                    '⚡ LIVE GPS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Animated Custom GPS Route Map Canvas
          SizedBox(
            height: 125,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _scooterProgress,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GpsRoutePainter(
                    progress: widget.isDelivered ? 1.0 : _scooterProgress.value,
                    isDelivered: widget.isDelivered,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),

          // 3. Bottom Route Waypoints Info
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('🏬', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.storeName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('🏠', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.destinationAddress,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE2E8F0),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Canvas Painter that renders the glowing curved route polyline,
/// the animated moving delivery scooter 🛵, and pulsing origin/destination nodes.
class _GpsRoutePainter extends CustomPainter {
  final double progress;
  final bool isDelivered;

  _GpsRoutePainter({required this.progress, required this.isDelivered});

  @override
  void paint(Canvas canvas, Size size) {
    final startPoint = Offset(36, size.height * 0.72);
    final endPoint = Offset(size.width - 36, size.height * 0.28);

    // Dynamic S-curve GPS Road Path
    final path = Path();
    path.moveTo(startPoint.dx, startPoint.dy);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.95,
      size.width * 0.65,
      size.height * 0.05,
      endPoint.dx,
      endPoint.dy,
    );

    // 1. Draw Inactive Dark Road
    final roadPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, roadPaint);

    // 2. Draw Active Glowing Green/Crimson Completed Route
    final metrics = path.computeMetrics().first;
    final activeLength = metrics.length * (isDelivered ? 1.0 : (0.2 + progress * 0.65));
    final activePath = metrics.extractPath(0, activeLength);

    final activePaint = Paint()
      ..shader = ui.Gradient.linear(
        startPoint,
        endPoint,
        [const Color(0xFF10B981), const Color(0xFF06B6D4), const Color(0xFFE20A22)],
      )
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);

    // 3. Draw Store Node (Origin 🏬)
    final storePaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(startPoint, 8, storePaint);
    final storeInner = Paint()..color = Colors.white;
    canvas.drawCircle(startPoint, 3.5, storeInner);

    // 4. Draw Home Node (Destination 🏠)
    final homePaint = Paint()..color = const Color(0xFFE20A22);
    canvas.drawCircle(endPoint, 9, homePaint);
    final homeInner = Paint()..color = Colors.white;
    canvas.drawCircle(endPoint, 4, homeInner);

    // 5. Calculate Current Position of Moving Scooter
    final currentPoint = metrics.getTangentForOffset(activeLength)?.position ?? startPoint;

    // Glowing Pulse Halo around Scooter
    final pulsePaint = Paint()
      ..color = const Color(0xFFE20A22).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentPoint, 18, pulsePaint);

    final coreBadge = Paint()..color = const Color(0xFFE20A22);
    canvas.drawCircle(currentPoint, 13, coreBadge);

    // Draw Scooter Icon Text inside badge
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🛵',
        style: TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(currentPoint.dx - textPainter.width / 2, currentPoint.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GpsRoutePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDelivered != isDelivered;
}
