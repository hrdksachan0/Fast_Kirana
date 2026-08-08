// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartItem _$CartItemFromJson(Map<String, dynamic> json) => CartItem(
      id: json['id'] as String,
      cartId: json['cartId'] as String,
      productId: json['productId'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      selectedVariant: json['selectedVariant'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$CartItemToJson(CartItem instance) => <String, dynamic>{
      'id': instance.id,
      'cartId': instance.cartId,
      'productId': instance.productId,
      'product': instance.product,
      'quantity': instance.quantity,
      'selectedVariant': instance.selectedVariant,
      'notes': instance.notes,
    };

Cart _$CartFromJson(Map<String, dynamic> json) => Cart(
      id: json['id'] as String,
      userId: json['userId'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      appliedCouponCode: json['appliedCouponCode'] as String?,
      couponDiscount: (json['couponDiscount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$CartToJson(Cart instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'items': instance.items,
      'appliedCouponCode': instance.appliedCouponCode,
      'couponDiscount': instance.couponDiscount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
