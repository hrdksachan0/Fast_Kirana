import 'package:geolocator/geolocator.dart';

class StoreHub {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double deliveryRadiusKm;
  final bool isActive;
  final bool groceryOpen;
  final String city;
  final double surgeCharge;
  final List<List<double>>? polygonGeoJson; // Array of [lat, lng] coordinates

  const StoreHub({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.deliveryRadiusKm = 5.0,
    this.isActive = true,
    this.groceryOpen = true,
    this.city = 'Ghatampur',
    this.surgeCharge = 0.0,
    this.polygonGeoJson,
  });

  factory StoreHub.fromJson(Map<String, dynamic> json) {
    List<List<double>>? parsedPolygon;
    final rawPolygon = json['deliveryPolygon'] ?? json['delivery_polygon'];
    if (rawPolygon is List && rawPolygon.length >= 3) {
      try {
        parsedPolygon = rawPolygon.map<List<double>>((point) {
          if (point is List && point.length >= 2) {
            return [(point[0] as num).toDouble(), (point[1] as num).toDouble()];
          } else if (point is Map) {
            final lat = (point['lat'] ?? point['latitude'] as num?)?.toDouble() ?? 0.0;
            final lng = (point['lng'] ?? point['longitude'] as num?)?.toDouble() ?? 0.0;
            return [lat, lng];
          }
          return [0.0, 0.0];
        }).toList();
      } catch (_) {}
    }

    return StoreHub(
      id: json['id']?.toString() ?? 'hub-209206',
      name: json['name']?.toString() ?? 'Ghatampur Hub',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 26.1534185,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.1714024,
      deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
      isActive: json['isActive'] ?? true,
      groceryOpen: json['groceryOpen'] ?? true,
      city: json['city']?.toString() ?? json['name']?.toString() ?? 'Ghatampur',
      surgeCharge: (json['surgeCharge'] as num?)?.toDouble() ??
          (json['surge_charge'] as num?)?.toDouble() ??
          0.0,
      polygonGeoJson: parsedPolygon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'deliveryRadiusKm': deliveryRadiusKm,
        'isActive': isActive,
        'groceryOpen': groceryOpen,
        'city': city,
        'surgeCharge': surgeCharge,
        if (polygonGeoJson != null) 'deliveryPolygon': polygonGeoJson,
      };

  /// Evaluates whether the customer's coordinates fall inside this hub's active delivery boundary.
  /// Uses Ray-Casting Point-in-Polygon (PIP) if a polygon is configured;
  /// otherwise falls back to radial Euclidean distance (deliveryRadiusKm).
  bool isPointInsideGeofence(double lat, double lng) {
    if (polygonGeoJson != null && polygonGeoJson!.length >= 3) {
      bool inside = false;
      final poly = polygonGeoJson!;
      int j = poly.length - 1;

      for (int i = 0; i < poly.length; i++) {
        final xi = poly[i][0], yi = poly[i][1];
        final xj = poly[j][0], yj = poly[j][1];

        final intersect = ((yi > lng) != (yj > lng)) &&
            (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
        j = i;
      }
      return inside;
    }

    final meters = Geolocator.distanceBetween(latitude, longitude, lat, lng);
    return meters <= (deliveryRadiusKm * 1000.0);
  }

  static const StoreHub defaultGhatampur = StoreHub(
    id: 'hub-209206',
    name: 'Ghatampur Central Hub',
    latitude: 26.1534185,
    longitude: 80.1714024,
    deliveryRadiusKm: 5.0,
    isActive: true,
    groceryOpen: true,
    city: 'Ghatampur',
    surgeCharge: 0.0,
  );

  static const StoreHub defaultAkbarpur = StoreHub(
    id: 'hub-224122',
    name: 'Akbarpur Express Hub',
    latitude: 26.4380,
    longitude: 82.5400,
    deliveryRadiusKm: 5.0,
    isActive: true,
    groceryOpen: true,
    city: 'Akbarpur',
    surgeCharge: 0.0,
  );

  static const List<StoreHub> defaultHubs = [
    defaultGhatampur,
    defaultAkbarpur,
  ];
}
