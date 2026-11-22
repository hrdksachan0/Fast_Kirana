import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Blinkit / Zepto Grade Ultra-Crisp Vector Map Markers Generator
/// Pure Canvas Vector Art — Zero low-res emojis, 2.5x Retina supersampling.
class MapMarkerGenerator {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> _renderCanvasToBitmap(
    Size size,
    void Function(Canvas, Size) painter, {
    double scale = 2.5,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    canvas.scale(scale);
    painter(canvas, size);
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage((size.width * scale).toInt(), (size.height * scale).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  /// 🏠 Luxury Home Destination Marker (Vector House + Apple/Zepto 3D Teardrop Pin)
  static Future<BitmapDescriptor> createHomeMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_home_pin_v3';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(58.0, 72.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(29.0, 26.0);
      const color = Color(0xFFE11D48); // Rose Crimson (Zepto/Blinkit destination red)

      // 1. Soft Ambient Radial Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(center.translate(0, 3), 20, shadowPaint);

      // 2. Teardrop Needle Pin Path
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 21))
        ..moveTo(21.0, 39.0)
        ..lineTo(37.0, 39.0)
        ..lineTo(29.0, 56.0)
        ..close();

      // Draw Pure White Base / Border
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawPath(pinPath, whitePaint);

      // Draw Colored Outline Rim
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pinPath, borderPaint);

      // Draw Core Colored Circle Fill
      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 16, center.dy - 16),
          Offset(center.dx + 16, center.dy + 16),
          [const Color(0xFFF43F5E), const Color(0xFFBE123C)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16.5, corePaint);

      // 3. Pure Vector House Icon (Crisp White Geometric Silhouette)
      final iconPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Roof triangle with sharp peak
      final roofPath = Path()
        ..moveTo(center.dx, center.dy - 9.0)
        ..lineTo(center.dx + 9.5, center.dy - 1.0)
        ..lineTo(center.dx - 9.5, center.dy - 1.0)
        ..close();
      canvas.drawPath(roofPath, iconPaint);

      // Chimney
      final chimney = Rect.fromLTWH(center.dx + 4.5, center.dy - 8.0, 2.5, 5.0);
      canvas.drawRect(chimney, iconPaint);

      // House body
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 6.5, center.dy - 1.0, 13.0, 10.0),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(bodyRect, iconPaint);

      // Door cutout (Crimson)
      final doorPaint = Paint()
        ..color = const Color(0xFFBE123C)
        ..style = PaintingStyle.fill;
      final doorRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 2.0, center.dy + 2.5, 4.0, 6.5),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(doorRect, doorPaint);

      // 4. Sleek Floating Pill Label ("HOME")
      final pillRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(8.0, 58.0, 42.0, 13.0),
        const Radius.circular(6.5),
      );
      // Pill shadow
      canvas.drawRRect(pillRect, Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
      // Pill body
      canvas.drawRRect(pillRect, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawRRect(pillRect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);

      final labelPainter = TextPainter(
        text: const TextSpan(
          text: 'HOME',
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(29.0 - labelPainter.width / 2, 64.5 - labelPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🏪 Luxury Store / Darkstore Marker (Vector Storefront + Emerald 3D Teardrop Pin)
  static Future<BitmapDescriptor> createStoreMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_store_pin_v3';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(58.0, 72.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(29.0, 26.0);
      const color = Color(0xFF059669); // Emerald Green

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(center.translate(0, 3), 20, shadowPaint);

      // Pin Path
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 21))
        ..moveTo(21.0, 39.0)
        ..lineTo(37.0, 39.0)
        ..lineTo(29.0, 56.0)
        ..close();

      canvas.drawPath(pinPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawPath(pinPath, Paint()..color = color..strokeWidth = 2.4..style = PaintingStyle.stroke);

      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 16, center.dy - 16),
          Offset(center.dx + 16, center.dy + 16),
          [const Color(0xFF10B981), const Color(0xFF047857)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16.5, corePaint);

      // Vector Store Awning & Door
      final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Awning
      final awning = Path()
        ..moveTo(center.dx - 9.0, center.dy - 6.5)
        ..lineTo(center.dx + 9.0, center.dy - 6.5)
        ..lineTo(center.dx + 7.5, center.dy - 0.5)
        ..lineTo(center.dx - 7.5, center.dy - 0.5)
        ..close();
      canvas.drawPath(awning, whitePaint);

      // Pillars & Base
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 7.5, center.dy - 0.5, 15.0, 9.0), const Radius.circular(1.0)),
        whitePaint,
      );

      // Door Cutout
      canvas.drawRect(
        Rect.fromLTWH(center.dx - 2.5, center.dy + 2.0, 5.0, 6.5),
        Paint()..color = const Color(0xFF047857),
      );

      // Pill Label ("STORE")
      final pillRect = RRect.fromRectAndRadius(const Rect.fromLTWH(8.0, 58.0, 42.0, 13.0), const Radius.circular(6.5));
      canvas.drawRRect(pillRect, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawRRect(pillRect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);

      final labelPainter = TextPainter(
        text: const TextSpan(
          text: 'STORE',
          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.6),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(29.0 - labelPainter.width / 2, 64.5 - labelPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🍽️ Luxury Kitchen / Restaurant Marker (Vector Cutlery + Royal Violet 3D Pin)
  static Future<BitmapDescriptor> createKitchenMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_kitchen_pin_v3';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(58.0, 72.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(29.0, 26.0);
      const color = Color(0xFF7C3AED); // Royal Violet

      // Shadow
      final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.26)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(center.translate(0, 3), 20, shadowPaint);

      // Pin Path
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 21))
        ..moveTo(21.0, 39.0)
        ..lineTo(37.0, 39.0)
        ..lineTo(29.0, 56.0)
        ..close();

      canvas.drawPath(pinPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawPath(pinPath, Paint()..color = color..strokeWidth = 2.4..style = PaintingStyle.stroke);

      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 16, center.dy - 16),
          Offset(center.dx + 16, center.dy + 16),
          [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16.5, corePaint);

      // Vector Dining Plate & Cutlery
      final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8;
      canvas.drawCircle(center, 6.0, whitePaint);

      // Fork Left
      final forkPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(center.dx - 9.0, center.dy - 5.5, 1.6, 11.0), forkPaint);
      canvas.drawRect(Rect.fromLTWH(center.dx - 10.2, center.dy - 5.5, 4.0, 3.0), forkPaint);

      // Knife Right
      canvas.drawRect(Rect.fromLTWH(center.dx + 7.5, center.dy - 5.5, 1.6, 11.0), forkPaint);

      // Pill Label ("KITCHEN")
      final pillRect = RRect.fromRectAndRadius(const Rect.fromLTWH(6.0, 58.0, 46.0, 13.0), const Radius.circular(6.5));
      canvas.drawRRect(pillRect, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawRRect(pillRect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);

      final labelPainter = TextPainter(
        text: const TextSpan(
          text: 'KITCHEN',
          style: TextStyle(fontSize: 7.2, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(29.0 - labelPainter.width / 2, 64.5 - labelPainter.height / 2));
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🛵 Sleek 3D Delivery Rider Marker (Pulsing Emerald Badge with Vector Motor-Scooter)
  static Future<BitmapDescriptor> createRiderMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_rider_marker_v3';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(64.0, 64.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(32.0, 32.0);

      // 1. Soft Drop Shadow
      final shadowPaint = Paint()
        ..color = const Color(0xFF059669).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(center, 27, shadowPaint);

      // 2. White Outer Rim
      canvas.drawCircle(center, 24.5, Paint()..color = Colors.white..style = PaintingStyle.fill);

      // 3. Crisp Emerald Accent Border
      canvas.drawCircle(
        center,
        24.5,
        Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke,
      );

      // 4. Emerald Core Circle
      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(12, 12),
          const Offset(52, 52),
          [const Color(0xFF10B981), const Color(0xFF047857)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 20.5, corePaint);

      // 5. Directional Pointer Arrow Beacon (Top)
      final arrowPaint = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(32.0, 2.5)
        ..lineTo(37.5, 9.5)
        ..lineTo(26.5, 9.5)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      // 6. Vector Motor-Scooter Icon (Crisp White Geometric Shapes)
      final bikePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Wheels (Circles with hollow center)
      canvas.drawCircle(const Offset(24.5, 36.5), 4.2, bikePaint);
      canvas.drawCircle(const Offset(24.5, 36.5), 2.2, Paint()..color = const Color(0xFF047857));

      canvas.drawCircle(const Offset(39.5, 36.5), 4.2, bikePaint);
      canvas.drawCircle(const Offset(39.5, 36.5), 2.2, Paint()..color = const Color(0xFF047857));

      // Scooter Chassis & Body
      final bodyPath = Path()
        ..moveTo(24.5, 35.0)
        ..lineTo(32.0, 35.0)
        ..lineTo(37.0, 27.0)
        ..lineTo(33.0, 27.0)
        ..lineTo(30.0, 31.0)
        ..lineTo(24.5, 31.0)
        ..close();
      canvas.drawPath(bodyPath, bikePaint);

      // Handlebar
      canvas.drawRect(const Rect.fromLTWH(34.5, 23.5, 2.2, 5.0), bikePaint);
      canvas.drawCircle(const Offset(35.5, 23.5), 2.0, bikePaint);

      // Delivery Box on Back
      final boxRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(21.5, 26.0, 7.5, 6.5),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(boxRect, bikePaint);
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// Backward compatible generic factory
  static Future<BitmapDescriptor> createCustomMarkerBitmap({
    BuildContext? context,
    required String label,
    required String emoji,
    required Color color,
  }) async {
    final l = label.toUpperCase();
    if (l.contains('HOME')) {
      return createHomeMarkerBitmap(context);
    } else if (l.contains('STORE') || l.contains('DARKSTORE') || l.contains('HUB')) {
      return createStoreMarkerBitmap(context);
    } else if (l.contains('KITCHEN') || l.contains('REST')) {
      return createKitchenMarkerBitmap(context);
    }
    return createHomeMarkerBitmap(context);
  }

  static Future<Map<String, BitmapDescriptor>> initCustomMarkers([BuildContext? context]) async {
    final results = await Future.wait([
      createStoreMarkerBitmap(context),
      createKitchenMarkerBitmap(context),
      createRiderMarkerBitmap(context),
      createHomeMarkerBitmap(context),
    ]);

    return {
      'store': results[0],
      'restaurant': results[1],
      'rider': results[2],
      'customer': results[3],
    };
  }
}
