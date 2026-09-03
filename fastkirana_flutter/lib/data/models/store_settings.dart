import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_settings.freezed.dart';

@freezed
class StoreSettings with _$StoreSettings {
  const StoreSettings._();

  const factory StoreSettings({
    @Default(5.0) double miscFee,
    @Default('Packaging charge') String miscFeeLabel,
    @Default(25.0) double deliveryFee,
    @Default(199.0) double groceryFreeDeliveryThreshold,
    @Default(199.0) double cafeFreeDeliveryThreshold,
    @Default(199.0) double combinedFreeDeliveryThreshold,
    @Default(199.0) double freeDeliveryThreshold,
    @Default(0.0) double surgeCharge,
    @Default(0.0) double minOrderValue,
    @Default(5.0) double deliveryRadiusKm,
    @Default('209206') String serviceablePincode,
    @Default(true) bool groceryMartOpen,
    @Default(true) bool cafeOpen,
    @Default(true) bool restaurantOpen,
    @Default('Fast') String avgDeliveryTime,
    @Default('7054470303') String adminWhatsappPhone,
    @Default('+917054470303') String contactPhone,
    @Default('8112849854') String supportPhone,
    @Default({}) Map<String, dynamic> raw,
  }) = _StoreSettings;

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
