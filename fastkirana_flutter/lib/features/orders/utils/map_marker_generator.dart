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

  /// 🛵 Uber/Swiggy-Grade Top-Down Vector Delivery Bike (True Directional Heading Marker)
  /// Features: Headlight projection beam, aerodynamic chassis, rider helmet, delivery box, and dual wheels
  static Future<BitmapDescriptor> createRiderMarkerBitmap([BuildContext? context]) async {
    const cacheKey = 'vector_rider_bike_topdown_v1';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = Size(46.0, 46.0);
    final marker = await _renderCanvasToBitmap(size, (canvas, sz) {
      const center = Offset(23.0, 23.0);

      // ── 1. Dynamic Headlight Projection Beam (Points forward / UP in 0° heading) ──
      final lightBeamPath = Path()
        ..moveTo(center.dx - 4.0, center.dy - 12.0)
        ..lineTo(center.dx - 11.0, 2.0)
        ..lineTo(center.dx + 11.0, 2.0)
        ..lineTo(center.dx + 4.0, center.dy - 12.0)
        ..close();

      final lightBeamPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - 10.0),
          Offset(center.dx, 1.0),
          [
            const Color(0xFF10B981).withValues(alpha: 0.35),
            const Color(0xFF10B981).withValues(alpha: 0.0),
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(lightBeamPath, lightBeamPaint);

      // ── 2. Soft Realistic Contact Shadow Beneath Bike ──
      final bikeShadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(0, 1.5), width: 15.0, height: 32.0),
          const Radius.circular(7.5),
        ),
        bikeShadow,
      );

      // ── 3. Bike Main Chassis / Body (Top-Down Aerodynamic Contour) ──
      // Main Body Base (Midnight Slate with fine white accent stroke)
      final chassisPath = Path()
        ..moveTo(center.dx, center.dy - 15.5) // Front nose tip
        ..cubicTo(center.dx + 4.5, center.dy - 13.0, center.dx + 6.0, center.dy - 5.0, center.dx + 6.0, center.dy + 3.0)
        ..cubicTo(center.dx + 6.0, center.dy + 9.0, center.dx + 5.5, center.dy + 14.5, center.dx, center.dy + 15.0) // Tail
        ..cubicTo(center.dx - 5.5, center.dy + 14.5, center.dx - 6.0, center.dy + 9.0, center.dx - 6.0, center.dy + 3.0)
        ..cubicTo(center.dx - 6.0, center.dy - 5.0, center.dx - 4.5, center.dy - 13.0, center.dx, center.dy - 15.5)
        ..close();

      // Body Outer White Stroke (Ensures perfect contrast on any map background)
      canvas.drawPath(
        chassisPath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke,
      );

      // Body Core Fill (Sleek dark gradient)
      canvas.drawPath(
        chassisPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy - 15.0),
            Offset(center.dx, center.dy + 15.0),
            [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          )
          ..style = PaintingStyle.fill,
      );

      // ── 4. Front & Rear Tires (Visible Top Profile) ──
      final tirePaint = Paint()..color = const Color(0xFF020617)..style = PaintingStyle.fill;
      // Front Tire
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy - 13.0), width: 2.8, height: 7.0),
          const Radius.circular(1.4),
        ),
        tirePaint,
      );
      // Rear Tire
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy + 13.0), width: 3.2, height: 7.0),
          const Radius.circular(1.6),
        ),
        tirePaint,
      );

      // ── 5. Front Handlebars & Side Mirrors ──
      final barPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      // Handlebar cross bar
      canvas.drawLine(
        Offset(center.dx - 8.5, center.dy - 9.0),
        Offset(center.dx + 8.5, center.dy - 9.0),
        barPaint,
      );
      // Dual Handlebar Grips
      final gripPaint = Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx - 8.5, center.dy - 9.0), 1.8, gripPaint);
      canvas.drawCircle(Offset(center.dx + 8.5, center.dy - 9.0), 1.8, gripPaint);

      // ── 6. Front Headlight LED Beacon (Bright Emerald Point) ──
      canvas.drawCircle(
        Offset(center.dx, center.dy - 14.0),
        2.2,
        Paint()..color = const Color(0xFF34D399)..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy - 14.0),
        1.1,
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );

      // ── 7. Rider Helmet & Shoulders (Centered Vector Figure) ──
      // Shoulders / Arms
      final riderBodyPaint = Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy - 3.5), width: 11.5, height: 5.5),
          const Radius.circular(2.5),
        ),
        riderBodyPaint,
      );

      // Helmet (Signature FastMinute Emerald with White Racing Stripe)
      final helmetPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - 4.5, center.dy - 4.5),
          Offset(center.dx + 4.5, center.dy + 4.5),
          [const Color(0xFF10B981), const Color(0xFF047857)],
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(center.dx, center.dy - 3.5), 4.5, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(center.dx, center.dy - 3.5), 3.8, helmetPaint);

      // Helmet Visor / Face Direction (Pointing forward / UP)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy - 5.5), width: 4.8, height: 1.8),
          const Radius.circular(0.8),
        ),
        Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.fill,
      );

      // ── 8. FastMinute Delivery Bag (Rear Carrier Box) ──
      // Delivery Box White Border
      final boxRect = Rect.fromCenter(center: Offset(center.dx, center.dy + 6.0), width: 10.5, height: 8.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(2.4)),
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
      // Delivery Box Core (FastMinute Brand Red / Emerald Contrast)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy + 6.0), width: 9.0, height: 7.0),
          const Radius.circular(1.8),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx, center.dy + 3.0),
            Offset(center.dx, center.dy + 9.0),
            [const Color(0xFFE20A22), const Color(0xFFB91C1C)], // FastMinute Red
          )
          ..style = PaintingStyle.fill,
      );
      // Delivery Box Logo Dot
      canvas.drawCircle(
        Offset(center.dx, center.dy + 6.0),
        1.3,
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
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
