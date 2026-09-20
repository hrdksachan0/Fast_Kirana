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

    if (speedKmh <= 0) speedKmh = 22.0;

    int estMinutes = ((currentDistanceKm / speedKmh) * 60).round() + 3;
    
    if (estMinutes < 2) estMinutes = 2;
    if (estMinutes > 45) estMinutes = 45;

    return estMinutes;
  }

  static double adaptiveJitterThreshold(double speedKmh) {
    if (speedKmh < 5.0) return 2.0;
    if (speedKmh <= 20.0) return 5.0;
    return 15.0;
  }
}
