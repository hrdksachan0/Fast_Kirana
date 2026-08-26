class StoreSettings {
  final double miscFee;
  final String miscFeeLabel;
  final double deliveryFee;
  final double groceryFreeDeliveryThreshold;
  final double cafeFreeDeliveryThreshold;
  final double combinedFreeDeliveryThreshold;
  final double freeDeliveryThreshold;
  final double surgeCharge;
  final double minOrderValue;
  final double deliveryRadiusKm;
  final String serviceablePincode;
  final bool groceryMartOpen;
  final bool cafeOpen;
  final bool restaurantOpen;
  final String avgDeliveryTime;
  final String adminWhatsappPhone;
  final String contactPhone;
  final String supportPhone;
  final Map<String, dynamic> raw;

  StoreSettings({
    this.miscFee = 5.0,
    this.miscFeeLabel = 'Packaging charge',
    this.deliveryFee = 25.0,
    this.groceryFreeDeliveryThreshold = 199.0,
    this.cafeFreeDeliveryThreshold = 199.0,
    this.combinedFreeDeliveryThreshold = 199.0,
    this.freeDeliveryThreshold = 199.0,
    this.surgeCharge = 0.0,
    this.minOrderValue = 0.0,
    this.deliveryRadiusKm = 5.0,
    this.serviceablePincode = '209206',
    this.groceryMartOpen = true,
    this.cafeOpen = true,
    this.restaurantOpen = true,
    this.avgDeliveryTime = 'Fast',
    this.adminWhatsappPhone = '7054470303',
    this.contactPhone = '+917054470303',
    this.supportPhone = '8112849854',
    this.raw = const {},
  });

  factory StoreSettings.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      return val.toString().toLowerCase() == 'true';
    }

    final gThresh = parseDouble(json['grocery_free_delivery_threshold'], 199.0);
    final cThresh = parseDouble(json['cafe_free_delivery_threshold'], 199.0);
    final combThresh = parseDouble(json['combined_free_delivery_threshold'], 199.0);
    final fallbackThresh = parseDouble(json['free_delivery_threshold'], combThresh);

    return StoreSettings(
      miscFee: parseDouble(json['misc_fee'], 5.0),
      miscFeeLabel: json['misc_fee_label']?.toString().isNotEmpty == true
          ? json['misc_fee_label'].toString()
          : 'Packaging charge',
      deliveryFee: parseDouble(json['delivery_fee'], 25.0),
      groceryFreeDeliveryThreshold: gThresh,
      cafeFreeDeliveryThreshold: cThresh,
      combinedFreeDeliveryThreshold: combThresh,
      freeDeliveryThreshold: fallbackThresh,
      surgeCharge: parseDouble(json['surge_charge'], 0.0),
      minOrderValue: parseDouble(json['min_order_value'], 0.0),
      deliveryRadiusKm: parseDouble(json['delivery_radius'] ?? json['max_delivery_radius'], 5.0),
      serviceablePincode: json['serviceable_pincode']?.toString() ?? '209206',
      groceryMartOpen: parseBool(json['grocery_mart_open'], true),
      cafeOpen: parseBool(json['cafe_open'], true),
      restaurantOpen: parseBool(json['restaurant_open'], true),
      avgDeliveryTime: json['avg_delivery_time']?.toString() ?? 'Fast',
      adminWhatsappPhone: json['admin_whatsapp_phone']?.toString().isNotEmpty == true
          ? json['admin_whatsapp_phone'].toString()
          : (json['admin_phone']?.toString().isNotEmpty == true
              ? json['admin_phone'].toString()
              : '7054470303'),
      contactPhone: json['contact_phone']?.toString() ?? '+917054470303',
      supportPhone: json['support_phone']?.toString() ?? '8112849854',
      raw: json,
    );
  }

  String get trustCityName =>
      raw['trust_city_name']?.toString() ??
      raw['city_name']?.toString() ??
      raw['serviceable_city']?.toString() ??
      'Ghatampur';

  String get trustBadge1 =>
      raw['trust_badge_1']?.toString() ??
      raw['trust_city_name']?.toString() ??
      'Ghatampur';

  String get trustBadge2 =>
      raw['trust_badge_2']?.toString() ??
      raw['varieties_count']?.toString() ??
      '50+';

  String get trustBadge3 =>
      raw['trust_badge_3']?.toString() ??
      raw['happy_customers']?.toString() ??
      '1000+';
}
