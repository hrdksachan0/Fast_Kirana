// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      id: json['id'] as String,
      readableId: json['readableId'] as String?,
      userId: json['userId'] as String,
      addressId: json['addressId'] as String,
      restaurantId: json['restaurantId'] as String?,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      deliveryFee: (json['deliveryFee'] as num).toDouble(),
      taxes: (json['taxes'] as num).toDouble(),
      miscFee: (json['miscFee'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
      paymentStatus: json['paymentStatus'] as String,
      estimatedDelivery: json['estimatedDelivery'] == null
          ? null
          : DateTime.parse(json['estimatedDelivery'] as String),
      deliveryPhoto: json['deliveryPhoto'] as String?,
      deliveryMethod: json['deliveryMethod'] as String?,
      shopName: json['shopName'] as String?,
      shopPhone: json['shopPhone'] as String?,
      notes: json['notes'] as String?,
      couponCode: json['couponCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      packedAt: json['packedAt'] == null
          ? null
          : DateTime.parse(json['packedAt'] as String),
      shippedAt: json['shippedAt'] == null
          ? null
          : DateTime.parse(json['shippedAt'] as String),
      deliveredAt: json['deliveredAt'] == null
          ? null
          : DateTime.parse(json['deliveredAt'] as String),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'id': instance.id,
      'readableId': instance.readableId,
      'userId': instance.userId,
      'addressId': instance.addressId,
      'restaurantId': instance.restaurantId,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'subtotal': instance.subtotal,
      'discount': instance.discount,
      'deliveryFee': instance.deliveryFee,
      'taxes': instance.taxes,
      'miscFee': instance.miscFee,
      'total': instance.total,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'paymentStatus': instance.paymentStatus,
      'estimatedDelivery': instance.estimatedDelivery?.toIso8601String(),
      'deliveryPhoto': instance.deliveryPhoto,
      'deliveryMethod': instance.deliveryMethod,
      'shopName': instance.shopName,
      'shopPhone': instance.shopPhone,
      'notes': instance.notes,
      'couponCode': instance.couponCode,
      'createdAt': instance.createdAt.toIso8601String(),
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'packedAt': instance.packedAt?.toIso8601String(),
      'shippedAt': instance.shippedAt?.toIso8601String(),
      'deliveredAt': instance.deliveredAt?.toIso8601String(),
      'items': instance.items,
    };

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.confirmed: 'confirmed',
  OrderStatus.packed: 'packed',
  OrderStatus.shipped: 'shipped',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cod: 'cod',
  PaymentMethod.upi: 'upi',
  PaymentMethod.card: 'card',
};

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
      id: json['id'] as String,
      productId: json['productId'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      selectedVariant: json['selectedVariant'] as String?,
    );

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'name': instance.name,
      'price': instance.price,
      'quantity': instance.quantity,
      'imageUrl': instance.imageUrl,
      'selectedVariant': instance.selectedVariant,
    };
