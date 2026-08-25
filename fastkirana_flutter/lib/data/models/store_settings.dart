class StoreSettings {
  final double miscFee;
  final String miscFeeLabel;
  final double deliveryFee;
  final double freeDeliveryThreshold;
  final double minOrderValue;
  final bool groceryMartOpen;
  final bool cafeOpen;
  final bool restaurantOpen;
  final String avgDeliveryTime;
  final Map<String, dynamic> raw;

  StoreSettings({
    this.miscFee = 5.0,
    this.miscFeeLabel = 'Packaging charge',
    this.deliveryFee = 25.0,
    this.freeDeliveryThreshold = 199.0,
    this.minOrderValue = 0.0,
    this.groceryMartOpen = true,
    this.cafeOpen = true,
    this.restaurantOpen = true,
    this.avgDeliveryTime = '30 min',
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

    return StoreSettings(
      miscFee: parseDouble(json['misc_fee'], 5.0),
      miscFeeLabel: json['misc_fee_label']?.toString().isNotEmpty == true
          ? json['misc_fee_label'].toString()
          : 'Packaging charge',
      deliveryFee: parseDouble(json['delivery_fee'], 25.0),
      freeDeliveryThreshold: parseDouble(
        json['combined_free_delivery_threshold'] ??
            json['grocery_free_delivery_threshold'] ??
            json['cafe_free_delivery_threshold'],
        199.0,
      ),
      minOrderValue: parseDouble(json['min_order_value'], 0.0),
      groceryMartOpen: parseBool(json['grocery_mart_open'], true),
      cafeOpen: parseBool(json['cafe_open'], true),
      restaurantOpen: parseBool(json['restaurant_open'], true),
      avgDeliveryTime: json['avg_delivery_time']?.toString() ?? '30 min',
      raw: json,
    );
  }
}
