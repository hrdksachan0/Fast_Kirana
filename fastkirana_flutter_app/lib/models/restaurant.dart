class Restaurant {
  final String id;
  final String name;
  final String slug;
  final double rating;
  final String deliveryTime;
  final String cuisines;
  final bool isPureVeg;
  final String imageUrl;
  final String address;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.rating,
    required this.deliveryTime,
    required this.cuisines,
    this.isPureVeg = false,
    required this.imageUrl,
    required this.address,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      deliveryTime: json['delivery_time'] ?? '25-30 mins',
      cuisines: json['cuisines'] ?? 'North Indian, Fast Food',
      isPureVeg: json['is_pure_veg'] ?? false,
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400',
      address: json['address'] ?? 'Main Market',
    );
  }
}
