import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'dart:convert';

class Product {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? categoryId;
  final String? restaurantId;
  final double mrp;
  final double price;
  final double discount;
  final String unit;
  final int stock;
  final bool isAvailable;
  final List<String> tags;
  final List<ProductVariant>? variants;
  final List<AddonGroup>? addons;
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
  final String? menuSection;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.restaurantId,
    required this.mrp,
    required this.price,
    required this.discount,
    required this.unit,
    required this.stock,
    required this.isAvailable,
    required this.tags,
    this.variants,
    this.addons,
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
    this.menuSection,
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
    } catch (e) { LoggerService.error('Product: error', e);
      parsedCreated = DateTime.now();
    }

    DateTime? parsedExpiry;
    if (json['expiryDate'] != null) {
      try {
        parsedExpiry = DateTime.parse(json['expiryDate'].toString());
      } catch (e, _) { LoggerService.error('Product: error', e); }
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
      categoryId: json['categoryId']?.toString(),
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
      variants: _parseVariantsFromJson(json['variants'], double.tryParse(json['price']?.toString() ?? '0') ?? 0, double.tryParse(json['mrp']?.toString() ?? '0') ?? 0, int.tryParse(json['stock']?.toString() ?? '0') ?? 0, json['unit']?.toString() ?? ''),
      addons: _parseAddonsFromJson(json['addons']),
      minStock: int.tryParse(json['minStock']?.toString() ?? '0') ?? 0,
      expiryDate: parsedExpiry,
      costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
      location: json['location']?.toString(),
      isFlashDeal: json['isFlashDeal'] == true || json['is_flash_deal'] == true || tagsList.any((t) => ['flash deal', 'flashdeal', 'flash-deal', 'flash', 'deal'].contains(t.toLowerCase())),
      isTopPick: json['isTopPick'] == true || json['is_top_pick'] == true || json['trending'] == true || json['isTrending'] == true || tagsList.any((t) => ['top-pick', 'toppick', 'top pick', 'trending', 'featured'].contains(t.toLowerCase())),
      isBestSeller: json['isBestSeller'] == true || json['is_best_seller'] == true || json['bestseller'] == true || json['isBestseller'] == true || tagsList.any((t) => ['bestseller', 'best seller', 'best-seller', 'popular', 'star'].contains(t.toLowerCase())),
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
      menuSection: json['menuSection']?.toString() ?? json['sectionTitle']?.toString() ?? json['sectionId']?.toString(),
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
        'variants': variants?.map((v) => v.toJson()).toList(),
        'addons': addons?.map((a) => a.toJson()).toList(),
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
        'menuSection': menuSection,
      };

  bool get isInStock => stock > 0 && isAvailable;
  double get savings => mrp - price;
  int get discountPercentage => discount.toInt();

  List<ProductVariant> get parsedVariants => variants ?? [];
  List<AddonGroup> get parsedAddons => addons ?? [];

  static List<ProductVariant>? _parseVariantsFromJson(
    dynamic raw,
    double defaultPrice,
    double defaultMrp,
    int defaultStock,
    String defaultUnit,
  ) {
    if (raw == null) return null;
    dynamic listData = raw;
    if (raw is String) {
      try {
        listData = jsonDecode(raw);
      } catch (e) {
        LoggerService.error('Product: variants json error', e);
        return null;
      }
    }
    if (listData is List) {
      final list = listData.map((v) {
        if (v is Map) {
          final vMap = Map<String, dynamic>.from(v);
          final p = double.tryParse(vMap['price']?.toString() ?? '') ?? defaultPrice;
          final m = double.tryParse(vMap['mrp']?.toString() ?? '') ?? (p > 0 ? p : defaultMrp);
          final s = int.tryParse(vMap['stock']?.toString() ?? '') ?? defaultStock;
          return ProductVariant(
            name: vMap['name']?.toString() ?? vMap['unit']?.toString() ?? defaultUnit,
            price: p,
            mrp: m,
            stock: s,
          );
        } else if (v is String) {
          return ProductVariant(name: v, price: defaultPrice, mrp: defaultMrp, stock: defaultStock);
        }
        return ProductVariant(name: v.toString(), price: defaultPrice, mrp: defaultMrp, stock: defaultStock);
      }).toList();
      list.sort((a, b) => a.price.compareTo(b.price));
      return list;
    }
    return null;
  }

  static List<AddonGroup>? _parseAddonsFromJson(dynamic raw) {
    if (raw == null) return null;
    dynamic listData = raw;
    if (raw is String) {
      try {
        listData = jsonDecode(raw);
      } catch (e) {
        return null;
      }
    }
    if (listData is List) {
      return listData.map((g) {
        if (g is Map) {
          return AddonGroup.fromJson(Map<String, dynamic>.from(g));
        }
        return null;
      }).whereType<AddonGroup>().toList();
    }
    return null;
  }

  bool get isTrending =>
      isTopPick ||
      tags.any((t) =>
          t.toLowerCase() == 'trending' ||
          t.toLowerCase() == 'popular' ||
          t.toLowerCase() == 'toppick' ||
          t.toLowerCase() == 'top pick' ||
          t.toLowerCase() == 'top-pick' ||
          t.toLowerCase() == 'featured' ||
          t.toLowerCase() == 'hot');

  bool get isBestsellerProduct =>
      isBestSeller ||
      tags.any((t) =>
          t.toLowerCase() == 'bestseller' ||
          t.toLowerCase() == 'best seller' ||
          t.toLowerCase() == 'best-seller' ||
          t.toLowerCase() == 'star');

  bool get isFlashDealProduct =>
      isFlashDeal ||
      discount >= 15 ||
      tags.any((t) =>
          t.toLowerCase() == 'flash deal' ||
          t.toLowerCase() == 'flashdeal' ||
          t.toLowerCase() == 'flash-deal' ||
          t.toLowerCase() == 'flash' ||
          t.toLowerCase() == 'deal' ||
          t.toLowerCase() == 'super-saver');

  bool get isOrganic =>
      tags.any((t) =>
          t.toLowerCase() == 'organic' ||
          t.toLowerCase() == 'natural' ||
          t.toLowerCase() == 'pure' ||
          t.toLowerCase() == 'farm-fresh');

  bool get isNewArrival =>
      tags.any((t) =>
          t.toLowerCase() == 'new' ||
          t.toLowerCase() == 'new-arrival' ||
          t.toLowerCase() == 'new arrival' ||
          t.toLowerCase() == 'fresh-arrival') ||
      createdAt.isAfter(DateTime.now().subtract(const Duration(days: 45)));

  bool get isMustTry =>
      tags.any((t) =>
          t.toLowerCase() == 'must try' ||
          t.toLowerCase() == 'must-try' ||
          t.toLowerCase() == 'chef special' ||
          t.toLowerCase() == 'chef-special' ||
          t.toLowerCase() == 'special');
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

class AddonItem {
  final String name;
  final double price;

  AddonItem({required this.name, required this.price});

  factory AddonItem.fromJson(Map<String, dynamic> json) => AddonItem(
    name: json['name']?.toString() ?? '',
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
  );

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}

class AddonGroup {
  final String title;
  final bool required;
  final int maxSelect;
  final List<AddonItem> items;

  AddonGroup({
    required this.title,
    this.required = false,
    this.maxSelect = 5,
    required this.items,
  });

  factory AddonGroup.fromJson(Map<String, dynamic> json) => AddonGroup(
    title: json['title']?.toString() ?? '',
    required: json['required'] == true,
    maxSelect: int.tryParse(json['maxSelect']?.toString() ?? '5') ?? 5,
    items: (json['items'] as List?)
        ?.map((e) => AddonItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'required': required,
    'maxSelect': maxSelect,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class CategoryInfo {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? parentId;

  CategoryInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.parentId,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'imageUrl': imageUrl,
        'parentId': parentId,
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
  final double? lat;
  final double? lng;
  final double? deliveryRadiusKm;
  final String? address;
  final String? discountOffer;

  RestaurantInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.bannerUrl,
    required this.rating,
    required this.deliveryTime,
    required this.isOpen,
    this.lat,
    this.lng,
    this.deliveryRadiusKm,
    this.address,
    this.discountOffer,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) {
    final lower = (json['name'] ?? json['slug'] ?? '').toString().toLowerCase();

    double? parseLat() {
      if (json['lat'] != null) return double.tryParse(json['lat'].toString());
      if (json['latitude'] != null) return double.tryParse(json['latitude'].toString());
      if (lower.contains('bal udyan') || lower.contains('birshibpur')) return 26.1468042;
      if (lower.contains('as') || lower.contains('a.s') || lower.contains('palika')) return 26.1494833;
      if (lower.contains('wedson') || lower.contains('hamirpur')) return 26.147862;
      if (lower.contains('pari') || lower.contains('dairy')) return 26.1484783;
      return null;
    }

    double? parseLng() {
      if (json['lng'] != null) return double.tryParse(json['lng'].toString());
      if (json['longitude'] != null) return double.tryParse(json['longitude'].toString());
      if (lower.contains('bal udyan') || lower.contains('birshibpur')) return 80.1773979;
      if (lower.contains('as') || lower.contains('a.s') || lower.contains('palika')) return 80.1672394;
      if (lower.contains('wedson') || lower.contains('hamirpur')) return 80.172482;
      if (lower.contains('pari') || lower.contains('dairy')) return 80.1667542;
      return null;
    }

    return RestaurantInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '4.5') ?? 4.5,
      deliveryTime: json['deliveryTime']?.toString() ?? 'Fast Delivery',
      isOpen: json['isOpen'] != false,
      lat: parseLat(),
      lng: parseLng(),
      deliveryRadiusKm: double.tryParse(json['deliveryRadiusKm']?.toString() ?? '5.0') ?? 5.0,
      address: json['address']?.toString(),
      discountOffer: json['discountOffer']?.toString() ?? json['offer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'rating': rating,
        'deliveryTime': deliveryTime,
        'isOpen': isOpen,
        'lat': lat,
        'lng': lng,
        'deliveryRadiusKm': deliveryRadiusKm,
        'address': address,
        'discountOffer': discountOffer,
      };
}