// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      categoryId: json['categoryId'] as String,
      restaurantId: json['restaurantId'] as String?,
      mrp: (json['mrp'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      unit: json['unit'] as String,
      stock: (json['stock'] as num).toInt(),
      isAvailable: json['isAvailable'] as bool,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      variants: json['variants'],
      minStock: (json['minStock'] as num).toInt(),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      costPrice: (json['costPrice'] as num).toDouble(),
      location: json['location'] as String?,
      isFlashDeal: json['isFlashDeal'] as bool,
      isTopPick: json['isTopPick'] as bool,
      isBestSeller: json['isBestSeller'] as bool,
      sortOrder: (json['sortOrder'] as num).toInt(),
      availableStartTime: json['availableStartTime'] as String?,
      availableEndTime: json['availableEndTime'] as String?,
      barcode: json['barcode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: json['category'] == null
          ? null
          : CategoryInfo.fromJson(json['category'] as Map<String, dynamic>),
      restaurant: json['restaurant'] == null
          ? null
          : RestaurantInfo.fromJson(json['restaurant'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'categoryId': instance.categoryId,
      'restaurantId': instance.restaurantId,
      'mrp': instance.mrp,
      'price': instance.price,
      'discount': instance.discount,
      'unit': instance.unit,
      'stock': instance.stock,
      'isAvailable': instance.isAvailable,
      'tags': instance.tags,
      'variants': instance.variants,
      'minStock': instance.minStock,
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'costPrice': instance.costPrice,
      'location': instance.location,
      'isFlashDeal': instance.isFlashDeal,
      'isTopPick': instance.isTopPick,
      'isBestSeller': instance.isBestSeller,
      'sortOrder': instance.sortOrder,
      'availableStartTime': instance.availableStartTime,
      'availableEndTime': instance.availableEndTime,
      'barcode': instance.barcode,
      'createdAt': instance.createdAt.toIso8601String(),
      'category': instance.category,
      'restaurant': instance.restaurant,
    };

CategoryInfo _$CategoryInfoFromJson(Map<String, dynamic> json) => CategoryInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$CategoryInfoToJson(CategoryInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'imageUrl': instance.imageUrl,
    };

RestaurantInfo _$RestaurantInfoFromJson(Map<String, dynamic> json) =>
    RestaurantInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      deliveryTime: json['deliveryTime'] as String,
      isOpen: json['isOpen'] as bool,
    );

Map<String, dynamic> _$RestaurantInfoToJson(RestaurantInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'logoUrl': instance.logoUrl,
      'bannerUrl': instance.bannerUrl,
      'rating': instance.rating,
      'deliveryTime': instance.deliveryTime,
      'isOpen': instance.isOpen,
    };
