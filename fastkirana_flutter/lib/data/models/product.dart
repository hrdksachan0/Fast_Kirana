import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String categoryId;
  final String? restaurantId;
  final double mrp;
  final double price;
  final double discount;
  final String unit;
  final int stock;
  final bool isAvailable;
  final List<String> tags;
  final dynamic variants;
  final int minStock;
  final DateTime? expiryDate;
  final double costPrice;
  final String? location;
  final bool isFlashDeal;
  final bool isTopPick;
  final bool isBestSeller;
  final int sortOrder;
  final String? availableStartTime;
  final String? availableEndTime;
  final String? barcode;
  final DateTime createdAt;
  final CategoryInfo? category;
  final RestaurantInfo? restaurant;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    required this.categoryId,
    this.restaurantId,
    required this.mrp,
    required this.price,
    required this.discount,
    required this.unit,
    required this.stock,
    required this.isAvailable,
    required this.tags,
    this.variants,
    required this.minStock,
    this.expiryDate,
    required this.costPrice,
    this.location,
    required this.isFlashDeal,
    required this.isTopPick,
    required this.isBestSeller,
    required this.sortOrder,
    this.availableStartTime,
    this.availableEndTime,
    this.barcode,
    required this.createdAt,
    this.category,
    this.restaurant,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  bool get isInStock => stock > 0 && isAvailable;
  double get savings => mrp - price;
  int get discountPercentage => discount.toInt();
}

@JsonSerializable()
class CategoryInfo {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;

  CategoryInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) =>
      _$CategoryInfoFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryInfoToJson(this);
}

@JsonSerializable()
class RestaurantInfo {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? bannerUrl;
  final double rating;
  final String deliveryTime;
  final bool isOpen;

  RestaurantInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.bannerUrl,
    required this.rating,
    required this.deliveryTime,
    required this.isOpen,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) =>
      _$RestaurantInfoFromJson(json);
  Map<String, dynamic> toJson() => _$RestaurantInfoToJson(this);
}