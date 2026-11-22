import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Blinkit / Zepto Grade Ultra-Crisp Vector Map Markers Generator
/// Pure Canvas Vector Art — Ultra-compact, elegant, zero-clutter, exact logical scaling.
class MapMarkerGenerator {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> _renderCanvasToBitmap(
    Size size,
    void Function(Canvas, Size) painter, {
    double scale = 3.0,
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
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: scale,
      width: size.width,
      height: size.height,
    );
  }

  /// 🏠 Luxury Home Destination Marker (Compact 34x42 Vector Teardrop Pin)
  static Future<BitmapDescriptor> createHomeMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_home_pin_v4';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(34.0, 42.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(17.0, 15.0);
      const color = Color(0xFFE11D48); // Rose Crimson (Zepto/Blinkit destination red)

      // 1. Soft Ambient Radial Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(center.translate(0, 1.5), 14.0, shadowPaint);

      // 2. Teardrop Needle Pin Path (Needle tip lands at 17.0, 39.5)
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 14.5))
        ..moveTo(7.5, 22.0)
        ..lineTo(26.5, 22.0)
        ..lineTo(17.0, 39.5)
        ..close();

      // Draw Pure White Base / Border
      canvas.drawPath(pinPath, Paint()..color = Colors.white..style = PaintingStyle.fill);

      // Draw Colored Outline Rim
      canvas.drawPath(
        pinPath,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      // Draw Core Colored Circle Fill
      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 12, center.dy - 12),
          Offset(center.dx + 12, center.dy + 12),
          [const Color(0xFFF43F5E), const Color(0xFFBE123C)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12.0, corePaint);

      // 3. Pure Vector House Icon (Crisp White Silhouette)
      final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Roof triangle with sharp peak
      final roofPath = Path()
        ..moveTo(center.dx, center.dy - 6.5)
        ..lineTo(center.dx + 6.8, center.dy - 0.5)
        ..lineTo(center.dx - 6.8, center.dy - 0.5)
        ..close();
      canvas.drawPath(roofPath, whitePaint);

      // Chimney
      canvas.drawRect(Rect.fromLTWH(center.dx + 3.2, center.dy - 6.0, 1.6, 3.5), whitePaint);

      // House body
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 4.8, center.dy - 0.5, 9.6, 7.0),
        const Radius.circular(0.8),
      );
      canvas.drawRRect(bodyRect, whitePaint);

      // Door cutout (Crimson)
      final doorPaint = Paint()
        ..color = const Color(0xFFBE123C)
        ..style = PaintingStyle.fill;
      final doorRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 1.5, center.dy + 2.0, 3.0, 4.5),
        const Radius.circular(0.6),
      );
      canvas.drawRRect(doorRect, doorPaint);
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🏪 Luxury Store / Darkstore Marker (Compact 34x42 Vector Storefront Pin)
  static Future<BitmapDescriptor> createStoreMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_store_pin_v4';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(34.0, 42.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(17.0, 15.0);
      const color = Color(0xFF059669); // Emerald Green

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(center.translate(0, 1.5), 14.0, shadowPaint);

      // Pin Path
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 14.5))
        ..moveTo(7.5, 22.0)
        ..lineTo(26.5, 22.0)
        ..lineTo(17.0, 39.5)
        ..close();

      canvas.drawPath(pinPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawPath(
        pinPath,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 12, center.dy - 12),
          Offset(center.dx + 12, center.dy + 12),
          [const Color(0xFF10B981), const Color(0xFF047857)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12.0, corePaint);

      // Vector Store Awning & Door
      final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Awning
      final awning = Path()
        ..moveTo(center.dx - 6.5, center.dy - 5.0)
        ..lineTo(center.dx + 6.5, center.dy - 5.0)
        ..lineTo(center.dx + 5.5, center.dy - 0.5)
        ..lineTo(center.dx - 5.5, center.dy - 0.5)
        ..close();
      canvas.drawPath(awning, whitePaint);

      // Pillars & Base
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 5.5, center.dy - 0.5, 11.0, 6.5), const Radius.circular(0.8)),
        whitePaint,
      );

      // Door Cutout
      canvas.drawRect(
        Rect.fromLTWH(center.dx - 1.8, center.dy + 1.8, 3.6, 4.2),
        Paint()..color = const Color(0xFF047857),
      );
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🍽️ Luxury Kitchen / Restaurant Marker (Compact 34x42 Vector Dining Cloche Pin)
  static Future<BitmapDescriptor> createKitchenMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_kitchen_pin_v4';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(34.0, 42.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(17.0, 15.0);
      const color = Color(0xFF7C3AED); // Royal Violet

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(center.translate(0, 1.5), 14.0, shadowPaint);

      // Pin Path
      final pinPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 14.5))
        ..moveTo(7.5, 22.0)
        ..lineTo(26.5, 22.0)
        ..lineTo(17.0, 39.5)
        ..close();

      canvas.drawPath(pinPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawPath(
        pinPath,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 12, center.dy - 12),
          Offset(center.dx + 12, center.dy + 12),
          [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12.0, corePaint);

      // Vector Luxury Dining Cloche / Cover
      final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Handle at top
      canvas.drawCircle(Offset(center.dx, center.dy - 5.5), 1.5, whitePaint);

      // Dome
      final dome = Path()
        ..addArc(Rect.fromLTWH(center.dx - 6.0, center.dy - 4.5, 12.0, 8.0), 3.14159, 3.14159)
        ..close();
      canvas.drawPath(dome, whitePaint);

      // Serving Platter Base Tray
      final trayRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 7.5, center.dy - 0.2, 15.0, 2.2),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(trayRect, whitePaint);
    });

    _cache[cacheKey] = marker;
    return marker;
  }

  /// 🛵 Sleek 3D Delivery Rider Marker (Compact 38x38 Pulsing Emerald Badge)
  static Future<BitmapDescriptor> createRiderMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_rider_marker_v4';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(38.0, 38.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(19.0, 19.0);

      // 1. Soft Drop Shadow
      final shadowPaint = Paint()
        ..color = const Color(0xFF059669).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(center, 16.5, shadowPaint);

      // 2. White Outer Rim
      canvas.drawCircle(center, 15.5, Paint()..color = Colors.white..style = PaintingStyle.fill);

      // 3. Crisp Emerald Accent Border
      canvas.drawCircle(
        center,
        15.5,
        Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      // 4. Emerald Core Circle
      final corePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(8, 8),
          const Offset(30, 30),
          [const Color(0xFF10B981), const Color(0xFF047857)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 13.0, corePaint);

      // 5. Directional Pointer Arrow Beacon (Top)
      final arrowPaint = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(19.0, 1.0)
        ..lineTo(22.5, 5.5)
        ..lineTo(15.5, 5.5)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      // 6. Vector Motor-Scooter Icon (Crisp White Geometric Shapes)
      final bikePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

      // Wheels
      canvas.drawCircle(const Offset(14.5, 22.5), 2.8, bikePaint);
      canvas.drawCircle(const Offset(14.5, 22.5), 1.4, Paint()..color = const Color(0xFF047857));

      canvas.drawCircle(const Offset(23.5, 22.5), 2.8, bikePaint);
      canvas.drawCircle(const Offset(23.5, 22.5), 1.4, Paint()..color = const Color(0xFF047857));

      // Scooter Chassis
      final bodyPath = Path()
        ..moveTo(14.5, 21.5)
        ..lineTo(19.0, 21.5)
        ..lineTo(22.0, 16.5)
        ..lineTo(20.0, 16.5)
        ..lineTo(18.0, 19.0)
        ..lineTo(14.5, 19.0)
        ..close();
      canvas.drawPath(bodyPath, bikePaint);

      // Handlebar
      canvas.drawRect(const Rect.fromLTWH(20.5, 14.5, 1.5, 3.2), bikePaint);
      canvas.drawCircle(const Offset(21.2, 14.5), 1.2, bikePaint);

      // Delivery Box on Back
      final boxRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12.5, 16.0, 4.8, 4.2),
        const Radius.circular(0.8),
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
