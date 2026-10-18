import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fastminute_flutter/core/config/app_config.dart';
import 'package:fastminute_flutter/core/services/logger_service.dart';

class RoutePolylineService {
  static final Map<String, List<LatLng>> _routeCache = {};

  /// Decodes Google Maps encoded polyline algorithm into a List<LatLng>
  static List<LatLng> decodeGooglePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  /// Fetches driving polyline between start and end using 3-tier fallback:
  /// 1. In-memory cache
  /// 2. Open-source OSRM routing (Free)
  /// 3. Google Maps Directions API (Fallback)
  /// 4. Backend Directions Proxy (/api/directions)
  static Future<List<LatLng>?> fetchRoadRoute({
    required LatLng start,
    required LatLng end,
    Dio? backendDio,
  }) async {
    final cacheKey = '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}->${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}';
    if (_routeCache.containsKey(cacheKey)) {
      final cached = _routeCache[cacheKey]!;
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    final dio = Dio();

    // 1. OSRM routing
    try {
      final osrmUrl = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await dio.get(osrmUrl).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes.first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          if (coordinates != null && coordinates.isNotEmpty) {
            final points = <LatLng>[];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
            if (points.isNotEmpty) {
              _routeCache[cacheKey] = points;
              return points;
            }
          }
        }
      }
    } catch (e) {
      LoggerService.info('OSRM route fetch unavailable, attempting fallback: $e');
    }

    // 2. Google Maps Directions API
    if (AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final gmapsUrl = 'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=${AppConfig.googleMapsApiKey}';
        final response = await dio.get(gmapsUrl).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.data != null) {
          final routes = response.data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final overview = routes.first['overview_polyline'] as Map<String, dynamic>?;
            final pointsStr = overview?['points'] as String?;
            if (pointsStr != null && pointsStr.isNotEmpty) {
              final decodedPoints = decodeGooglePolyline(pointsStr);
              if (decodedPoints.isNotEmpty) {
                _routeCache[cacheKey] = decodedPoints;
                return decodedPoints;
              }
            }
          }
        }
      } catch (e) {
        LoggerService.error('Google Directions API fallback error', e);
      }
    }

    // 3. Backend Directions Proxy (/api/directions)
    if (backendDio != null) {
      try {
        final res = await backendDio.get('/api/directions', queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
        }).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200 && res.data != null) {
          final pointsData = res.data['points'] as List?;
          if (pointsData != null && pointsData.isNotEmpty) {
            final points = <LatLng>[];
            for (final p in pointsData) {
              if (p is List && p.length >= 2) {
                points.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
              } else if (p is Map && p['lat'] != null && p['lng'] != null) {
                points.add(LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()));
              }
            }
            if (points.isNotEmpty) {
              _routeCache[cacheKey] = points;
              return points;
            }
          }
        }
      } catch (e) {
        LoggerService.error('Backend directions proxy fallback error', e);
      }
    }

    return null;
  }
}
