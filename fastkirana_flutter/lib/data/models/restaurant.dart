import 'dart:convert';

class Restaurant {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? address;
  final String? city;
  final String? phone;
  final String? logoUrl;
  final String? bannerUrl;
  final List<String> cuisineTags;
  final double rating;
  final int totalRatings;
  final String deliveryTime;
  final String priceForTwo;
  final bool isPureVeg;
  final bool isOpen;
  final String? openTime;
  final String? closeTime;
  final bool? isClosedBySchedule;
  final bool? isClosedByOwner;
  final String? formattedScheduleStr;
  final String? discountOffer;
  final String? discountBadge;
  final int sortOrder;
  final List<dynamic>? menuSections;
  final double? lat;
  final double? lng;
  final int activeOrdersCount;
  final String? ownerPhone;
  final double? commissionRate;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.address,
    this.city,
    this.phone,
    this.logoUrl,
    this.bannerUrl,
    this.cuisineTags = const [],
    this.rating = 4.5,
    this.totalRatings = 120,
    this.deliveryTime = 'Hot & Fresh',
    this.priceForTwo = '₹250 for two',
    this.isPureVeg = false,
    this.isOpen = true,
    this.openTime,
    this.closeTime,
    this.isClosedBySchedule,
    this.isClosedByOwner,
    this.formattedScheduleStr,
    this.discountOffer,
    this.discountBadge,
    this.sortOrder = 0,
    this.menuSections,
    this.lat,
    this.lng,
    this.activeOrdersCount = 0,
    this.ownerPhone,
    this.commissionRate,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['cuisineTags'] is List) {
      tags = (json['cuisineTags'] as List).map((e) => e.toString()).toList();
    } else if (json['cuisineTags'] is String) {
      tags = (json['cuisineTags'] as String)
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    double? parseLat() {
      if (json['lat'] != null) return double.tryParse(json['lat'].toString());
      if (json['latitude'] != null) return double.tryParse(json['latitude'].toString());
      return null;
    }

    double? parseLng() {
      if (json['lng'] != null) return double.tryParse(json['lng'].toString());
      if (json['longitude'] != null) return double.tryParse(json['longitude'].toString());
      return null;
    }

    String parseAddress() {
      final addr = json['address']?.toString().trim();
      if (addr != null && addr.isNotEmpty && addr != 'null') return addr;
      return 'Ghatampur Market, UP';
    }

    List<dynamic>? parseMenuSections() {
      if (json['menuSections'] is List) return json['menuSections'] as List<dynamic>;
      if (json['menuSections'] is String && (json['menuSections'] as String).trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(json['menuSections'] as String);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      return null;
    }

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Restaurant',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      address: parseAddress(),
      city: json['city']?.toString() ?? 'Ghatampur',
      phone: json['phone']?.toString(),
      ownerPhone: (json['ownerPhone'] ?? json['phone'])?.toString(),
      commissionRate: double.tryParse(json['commissionRate']?.toString() ?? ''),
      logoUrl: json['logoUrl']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      cuisineTags: tags,
      rating: (json['rating'] != null) ? double.tryParse(json['rating'].toString()) ?? 0.0 : 0.0,
      totalRatings: json['reviewCount'] != null
          ? int.tryParse(json['reviewCount'].toString()) ?? 0
          : (json['totalRatings'] != null ? int.tryParse(json['totalRatings'].toString()) ?? 0 : 0),
      deliveryTime: json['deliveryTime']?.toString() ?? 'Hot & Fresh',
      priceForTwo: json['priceForTwo']?.toString() ?? '₹250 for two',
      isPureVeg: json['isPureVeg'] == true,
      isOpen: json['isOpen'] != false,
      openTime: json['openTime']?.toString(),
      closeTime: json['closeTime']?.toString(),
      isClosedBySchedule: json['isClosedBySchedule'] == true,
      isClosedByOwner: json['isClosedByOwner'] == true,
      formattedScheduleStr: json['formattedScheduleStr']?.toString(),
      discountOffer: json['discountOffer']?.toString(),
      discountBadge: json['discountBadge']?.toString(),
      sortOrder: json['sortOrder'] != null ? int.tryParse(json['sortOrder'].toString()) ?? 0 : 0,
      menuSections: parseMenuSections(),
      lat: parseLat(),
      lng: parseLng(),
      activeOrdersCount: json['activeOrdersCount'] != null ? int.tryParse(json['activeOrdersCount'].toString()) ?? 0 : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'address': address,
        'city': city,
        'phone': phone,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'cuisineTags': cuisineTags,
        'rating': rating,
        'totalRatings': totalRatings,
        'deliveryTime': deliveryTime,
        'priceForTwo': priceForTwo,
        'isPureVeg': isPureVeg,
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
        'isClosedBySchedule': isClosedBySchedule,
        'isClosedByOwner': isClosedByOwner,
        'formattedScheduleStr': formattedScheduleStr,
        'discountOffer': discountOffer,
        'discountBadge': discountBadge,
        'sortOrder': sortOrder,
        'menuSections': menuSections,
      };

  Restaurant copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? logoUrl,
    String? bannerUrl,
    List<String>? cuisineTags,
    double? rating,
    int? totalRatings,
    String? deliveryTime,
    dynamic priceForTwo,
    bool? isPureVeg,
    bool? isOpen,
    String? openTime,
    String? closeTime,
    bool? isClosedBySchedule,
    bool? isClosedByOwner,
    String? formattedScheduleStr,
    String? discountOffer,
    String? discountBadge,
    int? sortOrder,
    List<String>? menuSections,
    double? lat,
    double? lng,
    int? activeOrdersCount,
    String? ownerPhone,
    double? commissionRate,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      cuisineTags: cuisineTags ?? this.cuisineTags,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      priceForTwo: priceForTwo != null ? priceForTwo.toString() : this.priceForTwo,
      isPureVeg: isPureVeg ?? this.isPureVeg,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isClosedBySchedule: isClosedBySchedule ?? this.isClosedBySchedule,
      isClosedByOwner: isClosedByOwner ?? this.isClosedByOwner,
      formattedScheduleStr: formattedScheduleStr ?? this.formattedScheduleStr,
      discountOffer: discountOffer ?? this.discountOffer,
      discountBadge: discountBadge ?? this.discountBadge,
      sortOrder: sortOrder ?? this.sortOrder,
      menuSections: menuSections ?? this.menuSections,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      commissionRate: commissionRate ?? this.commissionRate,
    );
  }
}
