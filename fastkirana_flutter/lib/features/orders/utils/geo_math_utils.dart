import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeoMathUtils {
  static double getHaversineDistance(LatLng pos1, LatLng pos2) {
    const p = 0.017453292519943295; // Math.PI / 180
    const c = math.cos;
    final a = 0.5 -
        c((pos2.latitude - pos1.latitude) * p) / 2 +
        c(pos1.latitude * p) * c(pos2.latitude * p) * (1 - c((pos2.longitude - pos1.longitude) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  static double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
  }

  static double interpolateHeading(double startHeading, double targetHeading, double progress) {
    double deltaHeading = targetHeading - startHeading;
    if (deltaHeading > 180) deltaHeading -= 360;
    if (deltaHeading < -180) deltaHeading += 360;
    return (startHeading + deltaHeading * progress) % 360;
  }

  /// Mathematical orthogonal projection of a GPS coordinate onto a road segment [segStart -> segEnd].
  /// Uses spherical longitudinal cosine projection for millimeter precision on road surfaces.
  static ({LatLng point, double distanceMeters, double bearing}) projectOnSegment({
    required LatLng point,
    required LatLng segStart,
    required LatLng segEnd,
  }) {
    final x0 = point.longitude;
    final y0 = point.latitude;
    final x1 = segStart.longitude;
    final y1 = segStart.latitude;
    final x2 = segEnd.longitude;
    final y2 = segEnd.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      final d = getHaversineDistance(point, segStart) * 1000.0;
      return (point: segStart, distanceMeters: d, bearing: 0.0);
    }

    final latRad = (y1 + y2) * math.pi / 360.0;
    final cosLat = math.cos(latRad);

    final scaledDx = dx * cosLat;
    final scaledDy = dy;
    final scaledPx = (x0 - x1) * cosLat;
    final scaledPy = y0 - y1;

    final scaledLenSq = scaledDx * scaledDx + scaledDy * scaledDy;
    double t = 0.0;
    if (scaledLenSq > 0) {
      t = (scaledPx * scaledDx + scaledPy * scaledDy) / scaledLenSq;
      t = t.clamp(0.0, 1.0);
    }

    final projLat = y1 + t * dy;
    final projLng = x1 + t * dx;
    final projPoint = LatLng(projLat, projLng);

    final distanceMeters = getHaversineDistance(point, projPoint) * 1000.0;
    final bearing = calculateBearing(y1, x1, y2, x2);

    return (
      point: projPoint,
      distanceMeters: distanceMeters,
      bearing: bearing,
    );
  }

  /// Snaps a raw GPS point to the nearest road polyline segment (Blinkit/Uber zero-cost road snapping).
  /// If rider is within [snapThresholdMeters] (default 38m), snaps directly onto the road geometry.
  /// If rider deviates beyond 38m (turns into an unmapped alley/shortcut), preserves raw point.
  static ({LatLng snappedPoint, double bearing, bool wasSnapped, double distanceMeters, int segmentIndex}) snapToRoadPolyline({
    required LatLng rawPoint,
    required List<LatLng> polyline,
    double snapThresholdMeters = 38.0,
  }) {
    if (polyline.length < 2) {
      return (
        snappedPoint: rawPoint,
        bearing: 0.0,
        wasSnapped: false,
        distanceMeters: 0.0,
        segmentIndex: -1,
      );
    }

    double minDistance = double.infinity;
    LatLng bestPoint = rawPoint;
    double bestBearing = 0.0;
    int bestSegmentIndex = -1;

    // Step 1: Fast bounding box scan to evaluate only relevant segments
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];

      final latMin = math.min(p1.latitude, p2.latitude) - 0.0006;
      final latMax = math.max(p1.latitude, p2.latitude) + 0.0006;
      final lngMin = math.min(p1.longitude, p2.longitude) - 0.0006;
      final lngMax = math.max(p1.longitude, p2.longitude) + 0.0006;

      if (rawPoint.latitude < latMin || rawPoint.latitude > latMax ||
          rawPoint.longitude < lngMin || rawPoint.longitude > lngMax) {
        continue;
      }

      final proj = projectOnSegment(
        point: rawPoint,
        segStart: p1,
        segEnd: p2,
      );

      if (proj.distanceMeters < minDistance) {
        minDistance = proj.distanceMeters;
        bestPoint = proj.point;
        bestBearing = proj.bearing;
        bestSegmentIndex = i;
      }
    }

    // Step 2: Fallback scan across all segments if bounding box pruned all
    if (minDistance == double.infinity) {
      for (int i = 0; i < polyline.length - 1; i++) {
        final proj = projectOnSegment(
          point: rawPoint,
          segStart: polyline[i],
          segEnd: polyline[i + 1],
        );
        if (proj.distanceMeters < minDistance) {
          minDistance = proj.distanceMeters;
          bestPoint = proj.point;
          bestBearing = proj.bearing;
          bestSegmentIndex = i;
        }
      }
    }

    if (minDistance <= snapThresholdMeters) {
      return (
        snappedPoint: bestPoint,
        bearing: bestBearing,
        wasSnapped: true,
        distanceMeters: minDistance,
        segmentIndex: bestSegmentIndex,
      );
    }

    return (
      snappedPoint: rawPoint,
      bearing: bestBearing,
      wasSnapped: false,
      distanceMeters: minDistance,
      segmentIndex: bestSegmentIndex,
    );
  }

  static final List<Map<String, dynamic>> _gpsHistory = [];

  static int estimateEtaWeightedAverage(LatLng currentPosition, LatLng destination, double currentDistanceKm) {
    final now = DateTime.now();
    _gpsHistory.add({
      'pos': currentPosition,
      'time': now,
    });

    if (_gpsHistory.length > 5) {
      _gpsHistory.removeAt(0);
    }

    double speedKmh = 22.0;

    if (_gpsHistory.length >= 3) {
      double totalDistance = 0.0;
      double totalTimeHours = 0.0;

      for (int i = 1; i < _gpsHistory.length; i++) {
        final prev = _gpsHistory[i - 1];
        final curr = _gpsHistory[i];
        
        final dist = getHaversineDistance(prev['pos'] as LatLng, curr['pos'] as LatLng);
        final timeHours = (curr['time'] as DateTime).difference(prev['time'] as DateTime).inMilliseconds / 3600000.0;
        
        if (timeHours > 0) {
          totalDistance += dist;
          totalTimeHours += timeHours;
        }
      }

      if (totalTimeHours > 0) {
        speedKmh = totalDistance / totalTimeHours;
      }
    }

    // Guard against stationary / red-light / GPS-drift speeds (e.g. 1.6 km/h -> 43 mins for 1.1 km!)
    // City two-wheeler average is ~18-24 km/h; clamp unrealistic spikes too.
    if (speedKmh < 12.0 || !speedKmh.isFinite) {
      speedKmh = 20.0;
    } else if (speedKmh > 40.0) {
      speedKmh = 35.0;
    }

    int estMinutes = ((currentDistanceKm / speedKmh) * 60).round() + 2;

    // Distance-proportional sanity ceiling so 1 km never shows > 9 mins
    final maxSaneForDistance = math.max(8, (currentDistanceKm * 5.5).ceil() + 3);
    if (estMinutes < 2) estMinutes = 2;
    if (estMinutes > maxSaneForDistance) estMinutes = maxSaneForDistance;
    if (estMinutes > 45) estMinutes = 45;

    return estMinutes;
  }

  static double adaptiveJitterThreshold(double speedKmh) {
    if (speedKmh < 5.0) return 2.0;
    if (speedKmh <= 20.0) return 5.0;
    return 15.0;
  }
}
