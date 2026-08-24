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

  static OrderStatus _parseStatus(dynamic val) {
    if (val == null) return OrderStatus.pending;
    final str = val.toString().toLowerCase().trim();
    if (str.contains('confirm')) return OrderStatus.confirmed;
    if (str.contains('pack')) return OrderStatus.packed;
    if (str.contains('ship') || str.contains('way') || str.contains('out')) return OrderStatus.shipped;
    if (str.contains('deliver')) return OrderStatus.delivered;
    if (str.contains('cancel')) return OrderStatus.cancelled;
    return OrderStatus.pending;
  }

  static PaymentMethod _parsePaymentMethod(dynamic val) {
    if (val == null) return PaymentMethod.cod;
    final str = val.toString().toLowerCase().trim();
    if (str.contains('upi')) return PaymentMethod.upi;
    if (str.contains('card') || str.contains('wallet') || str.contains('online')) return PaymentMethod.card;
    return PaymentMethod.cod;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> itemsList = [];
    if (json['items'] is List) {
      itemsList = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((itemJson) => OrderItem.fromJson(itemJson))
          .toList();
    }

    return Order(
      id: json['id']?.toString() ?? '',
      readableId: json['readableId']?.toString(),
      userId: json['userId']?.toString() ?? '',
      addressId: json['addressId']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString(),
      status: _parseStatus(json['status']),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0.0,
      miscFee: (json['miscFee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      estimatedDelivery: json['estimatedDelivery'] != null ? DateTime.tryParse(json['estimatedDelivery'].toString()) : null,
      deliveryPhoto: json['deliveryPhoto']?.toString(),
      deliveryMethod: json['deliveryMethod']?.toString(),
      shopName: json['shopName']?.toString(),
      shopPhone: json['shopPhone']?.toString(),
      notes: json['notes']?.toString(),
      couponCode: json['couponCode']?.toString(),
      createdAt: json['createdAt'] != null ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()) : DateTime.now(),
      confirmedAt: json['confirmedAt'] != null ? DateTime.tryParse(json['confirmedAt'].toString()) : null,
      packedAt: json['packedAt'] != null ? DateTime.tryParse(json['packedAt'].toString()) : null,
      shippedAt: json['shippedAt'] != null ? DateTime.tryParse(json['shippedAt'].toString()) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt'].toString()) : null,
      items: itemsList,
    );
  }

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

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      name: json['name']?.toString() ?? 'Product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: json['imageUrl']?.toString(),
      selectedVariant: json['selectedVariant']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  double get lineTotal => price * quantity;
}