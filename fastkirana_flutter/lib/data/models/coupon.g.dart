// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Coupon _$CouponFromJson(Map<String, dynamic> json) => Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: $enumDecode(_$DiscountTypeEnumMap, json['discountType']),
      value: (json['value'] as num).toDouble(),
      minOrder: (json['minOrder'] as num).toDouble(),
      maxDiscount: (json['maxDiscount'] as num).toDouble(),
      categoryId: json['categoryId'] as String?,
      restaurantId: json['restaurantId'] as String?,
      isActive: json['isActive'] as bool,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$CouponToJson(Coupon instance) => <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'discountType': _$DiscountTypeEnumMap[instance.discountType]!,
      'value': instance.value,
      'minOrder': instance.minOrder,
      'maxDiscount': instance.maxDiscount,
      'categoryId': instance.categoryId,
      'restaurantId': instance.restaurantId,
      'isActive': instance.isActive,
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

const _$DiscountTypeEnumMap = {
  DiscountType.flat: 'flat',
  DiscountType.percent: 'percent',
};
