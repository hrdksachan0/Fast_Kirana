import 'dart:convert';

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

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> tagsList = [];
    if (json['tags'] is List) {
      tagsList = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String) {
      tagsList = (json['tags'] as String)
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('"', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    DateTime parsedCreated;
    try {
      parsedCreated = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedExpiry;
    if (json['expiryDate'] != null) {
      try {
        parsedExpiry = DateTime.parse(json['expiryDate'].toString());
      } catch (_) {}
    }

    final mrpVal = double.tryParse(json['mrp']?.toString() ?? '0') ?? 0.0;
    final priceVal = double.tryParse(json['price']?.toString() ?? '0') ?? mrpVal;
    final discountVal = double.tryParse(json['discount']?.toString() ?? '0') ??
        (mrpVal > priceVal && mrpVal > 0 ? ((mrpVal - priceVal) / mrpVal * 100) : 0.0);

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Product',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      categoryId: json['categoryId']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString(),
      mrp: mrpVal,
      price: priceVal,
      discount: discountVal,
      unit: (json['unit'] != null && json['unit'].toString().trim().isNotEmpty)
          ? json['unit'].toString()
          : '1 unit',
      stock: int.tryParse(json['stock']?.toString() ?? '999') ?? 999,
      isAvailable: json['isAvailable'] != false,
      tags: tagsList,
      variants: json['variants'],
      minStock: int.tryParse(json['minStock']?.toString() ?? '0') ?? 0,
      expiryDate: parsedExpiry,
      costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
      location: json['location']?.toString(),
      isFlashDeal: json['isFlashDeal'] == true || json['is_flash_deal'] == true,
      isTopPick: json['isTopPick'] == true || json['is_top_pick'] == true || json['trending'] == true || json['isTrending'] == true,
      isBestSeller: json['isBestSeller'] == true || json['is_best_seller'] == true || json['bestseller'] == true || json['isBestseller'] == true,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
      availableStartTime: json['availableStartTime']?.toString(),
      availableEndTime: json['availableEndTime']?.toString(),
      barcode: json['barcode']?.toString(),
      createdAt: parsedCreated,
      category: json['category'] is Map<String, dynamic>
          ? CategoryInfo.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      restaurant: json['restaurant'] is Map<String, dynamic>
          ? RestaurantInfo.fromJson(json['restaurant'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'imageUrl': imageUrl,
        'categoryId': categoryId,
        'restaurantId': restaurantId,
        'mrp': mrp,
        'price': price,
        'discount': discount,
        'unit': unit,
        'stock': stock,
        'isAvailable': isAvailable,
        'tags': tags,
        'variants': variants,
        'minStock': minStock,
        'expiryDate': expiryDate?.toIso8601String(),
        'costPrice': costPrice,
        'location': location,
        'isFlashDeal': isFlashDeal,
        'isTopPick': isTopPick,
        'isBestSeller': isBestSeller,
        'sortOrder': sortOrder,
        'availableStartTime': availableStartTime,
        'availableEndTime': availableEndTime,
        'barcode': barcode,
        'createdAt': createdAt.toIso8601String(),
        'category': category?.toJson(),
        'restaurant': restaurant?.toJson(),
      };

  bool get isInStock => stock > 0 && isAvailable;
  double get savings => mrp - price;
  int get discountPercentage => discount.toInt();

  List<ProductVariant> get parsedVariants {
    if (variants == null) return [];
    dynamic listData = variants;
    if (variants is String) {
      try {
        listData = jsonDecode(variants as String);
      } catch (_) {
        return [];
      }
    }
    if (listData is List) {
      return listData.map((v) {
        if (v is Map) {
          final vMap = Map<String, dynamic>.from(v);
          final p = double.tryParse(vMap['price']?.toString() ?? '') ?? price;
          final m = double.tryParse(vMap['mrp']?.toString() ?? '') ?? (p > 0 ? p : mrp);
          final s = int.tryParse(vMap['stock']?.toString() ?? '') ?? stock;
          return ProductVariant(
            name: vMap['name']?.toString() ?? vMap['unit']?.toString() ?? unit,
            price: p,
            mrp: m,
            stock: s,
          );
        } else if (v is String) {
          return ProductVariant(name: v, price: price, mrp: mrp, stock: stock);
        }
        return ProductVariant(name: v.toString(), price: price, mrp: mrp, stock: stock);
      }).toList();
    }
    return [];
  }

  bool get isTrending =>
      isTopPick ||
      tags.any((t) =>
          t.toLowerCase() == 'trending' ||
          t.toLowerCase() == 'popular' ||
          t.toLowerCase() == 'toppick' ||
          t.toLowerCase() == 'top pick');

  bool get isBestsellerProduct =>
      isBestSeller ||
      tags.any((t) =>
          t.toLowerCase() == 'bestseller' ||
          t.toLowerCase() == 'best seller' ||
          t.toLowerCase() == 'best-seller');

  bool get isFlashDealProduct =>
      isFlashDeal ||
      tags.any((t) =>
          t.toLowerCase() == 'flash deal' ||
          t.toLowerCase() == 'flashdeal' ||
          t.toLowerCase() == 'flash-deal');
}

class ProductVariant {
  final String name;
  final double price;
  final double mrp;
  final int stock;

  ProductVariant({
    required this.name,
    required this.price,
    required this.mrp,
    this.stock = 999,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'mrp': mrp,
        'stock': stock,
      };
}

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

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'imageUrl': imageUrl,
      };
}

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

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) => RestaurantInfo(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
        bannerUrl: json['bannerUrl']?.toString(),
        rating: double.tryParse(json['rating']?.toString() ?? '4.5') ?? 4.5,
        deliveryTime: json['deliveryTime']?.toString() ?? 'Fast Delivery',
        isOpen: json['isOpen'] != false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'rating': rating,
        'deliveryTime': deliveryTime,
        'isOpen': isOpen,
      };
}