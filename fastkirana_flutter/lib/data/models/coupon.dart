import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon.freezed.dart';

enum DiscountType { flat, percent, bogo, freeDelivery }

@freezed
class Coupon with _$Coupon {
  const Coupon._();

  const factory Coupon({
    required String id,
    required String code,
    required DiscountType discountType,
    @Default(0.0) double value,
    @Default(0.0) double minOrder,
    @Default(0.0) double maxDiscount,
    String? categoryId,
    String? restaurantId,
    String? bogoType,
    String? triggerVariant,
    String? rewardVariant,
    String? badgeText,
    @Default(false) bool autoApply,
    @Default(true) bool isActive,
    required DateTime expiresAt,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    DiscountType parseDiscountType(dynamic val) {
      if (val == null) return DiscountType.flat;
      final str = val.toString().toLowerCase();
      if (str.contains('bogo')) return DiscountType.bogo;
      if (str.contains('free') && str.contains('delivery')) return DiscountType.freeDelivery;
      if (str.contains('percent') || str.contains('%')) return DiscountType.percent;
      return DiscountType.flat;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now().add(const Duration(days: 365));
      final parsed = DateTime.tryParse(val.toString());
      return parsed ?? DateTime.now().add(const Duration(days: 365));
    }

    return Coupon(
      id: json['id']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').toUpperCase(),
      discountType: parseDiscountType(json['discountType']),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      minOrder: (json['minOrder'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (json['maxDiscount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId']?.toString(),
      restaurantId: json['restaurantId']?.toString(),
      bogoType: json['bogoType']?.toString(),
      triggerVariant: json['triggerVariant']?.toString(),
      rewardVariant: json['rewardVariant']?.toString(),
      badgeText: json['badgeText']?.toString(),
      autoApply: json['autoApply'] == true || json['autoApply'] == 1 || json['autoApply'] == 'true',
      isActive: json['isActive'] == true || json['isActive'] == 1 || json['isActive'] == 'true',
      expiresAt: parseDate(json['expiresAt']),
    );
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && expiresAt.isAfter(now);
  }

  bool get isBogo => discountType == DiscountType.bogo;
}