import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/responsive.dart';

class MapMarkerGenerator {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> _renderCanvasToBitmap(Size size, void Function(Canvas, Size) painter) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    painter(canvas, size);
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createRiderMarkerBitmap(BuildContext context) async {
    const cacheKey = 'rider_marker';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(96.0, 96.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(48, 48);

      final shadowPaint = Paint()
        ..color = const Color(0xFFEA580C).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, 38, shadowPaint);

      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 34, whitePaint);

      final borderPaint = Paint()
        ..color = const Color(0xFFEA580C)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 34, borderPaint);

      final arrowPaint = Paint()
        ..color = const Color(0xFFEA580C)
        ..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(48, 6)
        ..lineTo(54, 16)
        ..lineTo(42, 16)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      final emojiPainter = TextPainter(
        text: TextSpan(
          text: '🛵',
          style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26)),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      emojiPainter.paint(canvas, Offset(48 - emojiPainter.width / 2, 48 - emojiPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  static Future<BitmapDescriptor> createCustomMarkerBitmap({
    required BuildContext context,
    required String label,
    required String emoji,
    required Color color,
  }) async {
    final cacheKey = 'custom_${label}_$emoji';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(100.0, 110.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(50, 42);

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center.translate(0, 4), 32, shadowPaint);

      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 32, whitePaint);

      final pinPath = Path()
        ..moveTo(38, 64)
        ..lineTo(62, 64)
        ..lineTo(50, 84)
        ..close();
      canvas.drawPath(pinPath, whitePaint);

      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 32, borderPaint);
      canvas.drawPath(pinPath, borderPaint);

      final emojiPainter = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26)),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      emojiPainter.paint(canvas, Offset(50 - emojiPainter.width / 2, 42 - emojiPainter.height / 2));

      final labelBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final labelRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 86, 64, 18),
        const Radius.circular(9),
      );
      canvas.drawRRect(labelRRect, labelBgPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: Responsive.scaledFontSize(context, 9.5),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(50 - labelPainter.width / 2, 95 - labelPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  static Future<Map<String, BitmapDescriptor>> initCustomMarkers(BuildContext context) async {
    final storeMarkerIcon = await createCustomMarkerBitmap(
      context: context,
      label: 'STORE',
      emoji: '🏪',
      color: const Color(0xFF16A34A),
    );
    final restaurantMarkerIcon = await createCustomMarkerBitmap(
      context: context,
      label: 'FOOD',
      emoji: '🍽️',
      color: const Color(0xFF7C3AED),
    );
    final riderMarkerIcon = await createRiderMarkerBitmap(context);
    final customerMarkerIcon = await createCustomMarkerBitmap(
      context: context,
      label: 'HOME',
      emoji: '🏠',
      color: const Color(0xFFDC2626),
    );
    return {
      'store': storeMarkerIcon,
      'restaurant': restaurantMarkerIcon,
      'rider': riderMarkerIcon,
      'customer': customerMarkerIcon,
    };
  }
}
