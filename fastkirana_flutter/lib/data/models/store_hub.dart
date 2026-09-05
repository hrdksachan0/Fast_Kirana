class StoreHub {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double deliveryRadiusKm;
  final bool isActive;
  final bool groceryOpen;
  final String city;

  const StoreHub({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.deliveryRadiusKm = 5.0,
    this.isActive = true,
    this.groceryOpen = true,
    this.city = 'Ghatampur',
  });

  factory StoreHub.fromJson(Map<String, dynamic> json) {
    return StoreHub(
      id: json['id']?.toString() ?? 'hub-209206',
      name: json['name']?.toString() ?? 'Ghatampur Hub',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 26.1534185,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.1714024,
      deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
      isActive: json['isActive'] ?? true,
      groceryOpen: json['groceryOpen'] ?? true,
      city: json['city']?.toString() ?? json['name']?.toString() ?? 'Ghatampur',
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
      };

  static const StoreHub defaultGhatampur = StoreHub(
    id: 'hub-209206',
    name: 'Ghatampur Central Hub',
    latitude: 26.1534185,
    longitude: 80.1714024,
    deliveryRadiusKm: 5.0,
    isActive: true,
    groceryOpen: true,
    city: 'Ghatampur',
  );
}
