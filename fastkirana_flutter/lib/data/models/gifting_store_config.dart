import 'package:flutter/material.dart';

class GiftingHamperModel {
  final String id;
  final String name;
  final String tagline;
  final double price;
  final double mrp;
  final String badge;
  final String imageUrl;
  final List<String> bundledProductIds;
  final bool isActive;
  final int sortOrder;

  const GiftingHamperModel({
    required this.id,
    required this.name,
    this.tagline = '',
    required this.price,
    required this.mrp,
    this.badge = '✨ CURATED DUO',
    this.imageUrl = '',
    this.bundledProductIds = const [],
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GiftingHamperModel.fromJson(Map<String, dynamic> json) {
    final rawBundle = json['bundledProductIds'];
    final bundleList = rawBundle is List
        ? rawBundle.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return GiftingHamperModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      badge: json['badge']?.toString() ?? '✨ CURATED DUO',
      imageUrl: json['imageUrl']?.toString() ?? '',
      bundledProductIds: bundleList,
      isActive: json['isActive'] ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tagline': tagline,
        'price': price,
        'mrp': mrp,
        'badge': badge,
        'imageUrl': imageUrl,
        'bundledProductIds': bundledProductIds,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}

class GiftingOccasionModel {
  final String id;
  final String label;
  final String title;
  final String imageUrl;
  final String emoji;
  final List<String> tags;
  final List<String> productIds;
  final bool isActive;
  final int sortOrder;

  const GiftingOccasionModel({
    required this.id,
    required this.label,
    required this.title,
    this.imageUrl = '',
    this.emoji = '🎁',
    this.tags = const [],
    this.productIds = const [],
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GiftingOccasionModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((e) => e.toString().toLowerCase().trim()).toList()
        : <String>[];

    final rawProducts = json['productIds'];
    final productsList = rawProducts is List
        ? rawProducts.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return GiftingOccasionModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎁',
      tags: tagsList,
      productIds: productsList,
      isActive: json['isActive'] ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'title': title,
        'imageUrl': imageUrl,
        'emoji': emoji,
        'tags': tags,
        'productIds': productIds,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
}

class GiftingStoreConfigModel {
  final bool enabled;
  final String bannerTitle;
  final String bannerSubtitle;
  final String bannerImageUrl;
  final String gradientStartHex;
  final String gradientEndHex;
  final List<GiftingOccasionModel> occasions;
  final List<GiftingHamperModel> hampers;

  const GiftingStoreConfigModel({
    this.enabled = true,
    this.bannerTitle = 'Gifting Store',
    this.bannerSubtitle = 'Curated by FastMinute',
    this.bannerImageUrl = '',
    this.gradientStartHex = '#E89E90',
    this.gradientEndHex = '#CD7564',
    this.occasions = const [],
    this.hampers = const [],
  });

  Color get gradientStart => _hexToColor(gradientStartHex, const Color(0xFFE89E90));
  Color get gradientEnd => _hexToColor(gradientEndHex, const Color(0xFFCD7564));

  static Color _hexToColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  factory GiftingStoreConfigModel.fromJson(Map<String, dynamic> json) {
    final rawOccasions = json['occasions'];
    final occasionsList = rawOccasions is List
        ? rawOccasions
            .whereType<Map<String, dynamic>>()
            .map((e) => GiftingOccasionModel.fromJson(e))
            .toList()
        : <GiftingOccasionModel>[];

    occasionsList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final rawHampers = json['hampers'];
    final hampersList = rawHampers is List
        ? rawHampers
            .whereType<Map<String, dynamic>>()
            .map((e) => GiftingHamperModel.fromJson(e))
            .toList()
        : <GiftingHamperModel>[];

    hampersList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return GiftingStoreConfigModel(
      enabled: json['enabled'] ?? true,
      bannerTitle: json['bannerTitle']?.toString() ?? 'Gifting Store',
      bannerSubtitle: json['bannerSubtitle']?.toString() ?? 'Curated by FastMinute',
      bannerImageUrl: json['bannerImageUrl']?.toString() ?? '',
      gradientStartHex: json['gradientStart']?.toString() ?? '#E89E90',
      gradientEndHex: json['gradientEnd']?.toString() ?? '#CD7564',
      occasions: occasionsList.isNotEmpty ? occasionsList : defaultOccasions,
      hampers: hampersList,
    );
  }

  static const List<GiftingOccasionModel> defaultOccasions = [
    GiftingOccasionModel(
      id: 'occ_birthday',
      label: 'Birthday',
      title: 'Birthday Specials',
      imageUrl: '',
      emoji: '🎈',
      tags: ['birthday', 'gift', 'cake', 'chocolate'],
      productIds: [],
      isActive: true,
      sortOrder: 1,
    ),
    GiftingOccasionModel(
      id: 'occ_anniversary',
      label: 'Anniversary',
      title: 'Anniversary Hampers',
      imageUrl: '',
      emoji: '🧸',
      tags: ['anniversary', 'gift', 'romantic', 'cake'],
      productIds: [],
      isActive: true,
      sortOrder: 2,
    ),
    GiftingOccasionModel(
      id: 'occ_cakes',
      label: 'Cakes',
      title: 'Cakes & Bakery',
      imageUrl: '',
      emoji: '🎂',
      tags: ['cake', 'bakery', 'pastry'],
      productIds: [],
      isActive: true,
      sortOrder: 3,
    ),
    GiftingOccasionModel(
      id: 'occ_chocolates',
      label: 'Chocolates',
      title: 'Luxury Chocolates',
      imageUrl: '',
      emoji: '🍫',
      tags: ['chocolate', 'gift', 'sweet'],
      productIds: [],
      isActive: true,
      sortOrder: 4,
    ),
    GiftingOccasionModel(
      id: 'occ_mithai',
      label: 'Mithai',
      title: 'Royal Mithai',
      imageUrl: '',
      emoji: '🍯',
      tags: ['mithai', 'sweets', 'traditional'],
      productIds: [],
      isActive: true,
      sortOrder: 5,
    ),
    GiftingOccasionModel(
      id: 'occ_dry_fruits',
      label: 'Dry Fruits',
      title: 'Festive Hampers',
      imageUrl: '',
      emoji: '🎁',
      tags: ['dry-fruit', 'nut', 'hamper', 'festive'],
      productIds: [],
      isActive: true,
      sortOrder: 6,
    ),
  ];
}
