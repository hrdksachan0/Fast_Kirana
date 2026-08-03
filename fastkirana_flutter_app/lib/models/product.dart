class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final String categorySlug;
  final double price;
  final double? originalPrice;
  final String unit;
  final String imageUrl;
  final bool isAvailable;
  final int stock;
  final int discount;
  final bool isBestSeller;
  final bool isFlashDeal;
  final bool isTopPick;
  final List<String>? tags;
  final List<Variant>? variants;
  final double? rating;
  final int? reviewCount;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    this.categorySlug = '',
    required this.price,
    this.originalPrice,
    required this.unit,
    required this.imageUrl,
    this.isAvailable = true,
    this.stock = 0,
    this.discount = 0,
    this.isBestSeller = false,
    this.isFlashDeal = false,
    this.isTopPick = false,
    this.tags,
    this.variants,
    this.rating,
    this.reviewCount,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category']?['name'] ?? json['category_name'] ?? 'General',
      categorySlug: json['category']?['slug'] ?? json['category_slug'] ?? '',
      price: _toDouble(json['price']),
      originalPrice: json['mrp'] != null ? _toDouble(json['mrp']) : (json['original_price'] != null ? _toDouble(json['original_price']) : null),
      unit: json['unit'] ?? '1 unit',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? 'https://via.placeholder.com/300',
      isAvailable: json['is_available'] ?? json['isAvailable'] ?? true,
      stock: json['stock'] ?? 0,
      discount: json['discount'] ?? 0,
      isBestSeller: json['is_best_seller'] ?? json['isBestSeller'] ?? false,
      isFlashDeal: json['is_flash_deal'] ?? json['isFlashDeal'] ?? false,
      isTopPick: json['is_top_pick'] ?? json['isTopPick'] ?? false,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      variants: json['variants'] != null ? (json['variants'] as List).map((v) => Variant.fromJson(v)).toList() : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      reviewCount: json['review_count'],
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get displayPrice => '₹${price.toInt()}';
  String get displayMrp => originalPrice != null ? '₹${originalPrice!.toInt()}' : '';
  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  int get calculatedDiscount {
    if (originalPrice == null || originalPrice! <= 0) return 0;
    return ((originalPrice! - price) / originalPrice! * 100).round();
  }
}

class Variant {
  final String id;
  final String name;
  final double price;
  final double? mrp;
  final String unit;
  final int stock;

  Variant({
    required this.id,
    required this.name,
    required this.price,
    this.mrp,
    required this.unit,
    required this.stock,
  });

  factory Variant.fromJson(Map<String, dynamic> json) {
    return Variant(
      id: json['id']?.toString() ?? json['name'] ?? '',
      name: json['name'] ?? '',
      price: Product._toDouble(json['price']),
      mrp: json['mrp'] != null ? Product._toDouble(json['mrp']) : null,
      unit: json['unit'] ?? '',
      stock: json['stock'] ?? 0,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? parentId;
  final int sortOrder;
  final int? productCount;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.parentId,
    this.sortOrder = 0,
    this.productCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? json['slug'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'],
      parentId: json['parentId']?.toString(),
      sortOrder: json['sortOrder'] ?? 0,
      productCount: json['_count']?['products'],
    );
  }
}

class Banner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? link;
  final int sortOrder;
  final bool isActive;

  Banner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.link,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? '',
      link: json['link'] ?? json['url'],
      sortOrder: json['sortOrder'] ?? 0,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }
}
