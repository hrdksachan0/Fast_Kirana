import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

enum OrderStatus {
  pending,
  confirmed,
  packed,
  shipped,
  delivered,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.shipped:
        return 'On the Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.amber;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.packed:
        return Colors.indigo;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}

enum PaymentMethod {
  cod,
  upi,
  card;

  String get displayName {
    switch (this) {
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card / Wallet';
    }
  }
}

@JsonSerializable()
class Order {
  final String id;
  final String? readableId;
  final String userId;
  final String addressId;
  final String? restaurantId;
  final OrderStatus status;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double taxes;
  final double miscFee;
  final double total;
  final PaymentMethod paymentMethod;
  final String paymentStatus;
  final DateTime? estimatedDelivery;
  final String? deliveryPhoto;
  final String? deliveryMethod;
  final String? shopName;
  final String? shopPhone;
  final String? notes;
  final String? couponCode;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? packedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    this.readableId,
    required this.userId,
    required this.addressId,
    this.restaurantId,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.taxes,
    required this.miscFee,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.estimatedDelivery,
    this.deliveryPhoto,
    this.deliveryMethod,
    this.shopName,
    this.shopPhone,
    this.notes,
    this.couponCode,
    required this.createdAt,
    this.confirmedAt,
    this.packedAt,
    this.shippedAt,
    this.deliveredAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) =>
      _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}

@JsonSerializable()
class OrderItem {
  final String id;
  final String? productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? selectedVariant;

  OrderItem({
    required this.id,
    this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.selectedVariant,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  double get lineTotal => price * quantity;
}