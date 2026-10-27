import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Zepto / Blinkit Grade Sleek Map Markers Generator
class MapMarkerGenerator {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> _renderCanvasToBitmap(Size size, void Function(Canvas, Size) painter) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    painter(canvas, size);
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  /// Sleek 3D Delivery Rider Marker (Pulsing Emerald Badge with Motor-Scooter)
  static Future<BitmapDescriptor> createRiderMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'rider_marker_v2';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(64.0, 64.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(32, 32);

      // 1. Soft Drop Shadow
      final shadowPaint = Paint()
        ..color = const Color(0xFF059669).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, 26, shadowPaint);

      // 2. White Outer Rim
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 24, whitePaint);

      // 3. Crisp Emerald Accent Border
      final borderPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 24, borderPaint);

      // 4. Emerald Core Circle
      final corePaint = Paint()
        ..color = const Color(0xFF047857)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 20, corePaint);

      // 5. White Direction Arrow
      final arrowPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(32, 3)
        ..lineTo(37, 10)
        ..lineTo(27, 10)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      // 6. Scooter Icon (Emoji or Vector)
      final emojiPainter = TextPainter(
        text: const TextSpan(
          text: '🛵',
          style: TextStyle(fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      emojiPainter.paint(canvas, Offset(32 - emojiPainter.width / 2, 32 - emojiPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// Sleek Modern Destination / Store Pin (Teardrop Needle Pin like Zepto)
  static Future<BitmapDescriptor> createCustomMarkerBitmap({
    BuildContext? context,
    required String label,
    required String emoji,
    required Color color,
  }) async {
    final cacheKey = 'custom_pin_v2_${label}_$emoji';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(56.0, 68.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(28, 25);

      // 1. Soft Drop Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center.translate(0, 3), 20, shadowPaint);

      // 2. Teardrop Pin Path (Needle points straight down to exact doorstep)
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 21))
        ..moveTo(20, 38)
        ..lineTo(36, 38)
        ..lineTo(28, 54)
        ..close();

      // Draw white base
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawPath(pinPath, whitePaint);

      // Draw colored outline
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pinPath, borderPaint);

      // Draw colored inner circle
      final innerCirclePaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16, innerCirclePaint);

      // 3. Emoji icon centered inside
      final emojiPainter = TextPainter(
        text: TextSpan(
          text: emoji,
          style: const TextStyle(fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      emojiPainter.paint(canvas, Offset(28 - emojiPainter.width / 2, 25 - emojiPainter.height / 2));

      // 4. Pill Label at top/bottom
      final labelBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final labelRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 55, 40, 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(labelRRect, labelBgPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: label.toUpperCase(),
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(28 - labelPainter.width / 2, 61 - labelPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  static Future<Map<String, BitmapDescriptor>> initCustomMarkers([BuildContext? context]) async {
    final results = await Future.wait([
      createCustomMarkerBitmap(
        label: 'STORE',
        emoji: '🏪',
        color: const Color(0xFF059669),
        context: context,
      ),
      createCustomMarkerBitmap(
        label: 'KITCHEN',
        emoji: '🍽️',
        color: const Color(0xFF7C3AED),
        context: context,
      ),
      createRiderMarkerBitmap(context),
      createCustomMarkerBitmap(
        label: 'HOME',
        emoji: '🏠',
        color: const Color(0xFFE11D48),
        context: context,
      ),
    ]);

    return {
      'store': results[0],
      'restaurant': results[1],
      'rider': results[2],
      'customer': results[3],
    };
  }
}
