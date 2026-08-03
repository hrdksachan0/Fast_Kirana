class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double? originalPrice;
  final String unit;
  final String imageUrl;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    required this.unit,
    required this.imageUrl,
    this.isAvailable = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      unit: json['unit'] ?? '1 unit',
      imageUrl: json['image_url'] ?? 'https://via.placeholder.com/150',
      isAvailable: json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'original_price': originalPrice,
      'unit': unit,
      'image_url': imageUrl,
      'is_available': isAvailable,
    };
  }
}
