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
  final String? discountOffer;
  final String? discountBadge;
  final int sortOrder;
  final List<dynamic>? menuSections;

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
    this.discountOffer,
    this.discountBadge,
    this.sortOrder = 0,
    this.menuSections,
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

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Restaurant',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      address: json['address']?.toString() ?? 'Ghatampur Market',
      city: json['city']?.toString() ?? 'Ghatampur',
      phone: json['phone']?.toString(),
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
      discountOffer: json['discountOffer']?.toString(),
      discountBadge: json['discountBadge']?.toString(),
      sortOrder: json['sortOrder'] != null ? int.tryParse(json['sortOrder'].toString()) ?? 0 : 0,
      menuSections: json['menuSections'] is List ? json['menuSections'] as List<dynamic> : null,
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
        'discountOffer': discountOffer,
        'discountBadge': discountBadge,
        'sortOrder': sortOrder,
        'menuSections': menuSections,
      };
}
