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

  factory Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);
  Map<String, dynamic> toJson() => _$CouponToJson(this);

  bool get isValid {
    final now = DateTime.now();
    return isActive && expiresAt.isAfter(now);
  }
}