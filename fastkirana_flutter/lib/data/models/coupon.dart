import 'package:json_annotation/json_annotation.dart';

part 'coupon.g.dart';

enum DiscountType { flat, percent }

@JsonSerializable()
class Coupon {
  final String id;
  final String code;
  final DiscountType discountType;
  final double value;
  final double minOrder;
  final double maxDiscount;
  final String? categoryId;
  final String? restaurantId;
  final bool isActive;
  final DateTime expiresAt;

  Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    required this.minOrder,
    required this.maxDiscount,
    this.categoryId,
    this.restaurantId,
    required this.isActive,
    required this.expiresAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    DiscountType parseDiscountType(dynamic val) {
      if (val == null) return DiscountType.flat;
      final str = val.toString().toLowerCase();
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
      isActive: json['isActive'] == true || json['isActive'] == 1 || json['isActive'] == 'true',
      expiresAt: parseDate(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'discountType': discountType == DiscountType.percent ? 'PERCENT' : 'FLAT',
    'value': value,
    'minOrder': minOrder,
    'maxDiscount': maxDiscount,
    'categoryId': categoryId,
    'restaurantId': restaurantId,
    'isActive': isActive,
    'expiresAt': expiresAt.toIso8601String(),
  };

  bool get isValid {
    final now = DateTime.now();
    return isActive && expiresAt.isAfter(now);
  }
}