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
  final String? deliveryBoyName;
  final String? deliveryBoyPhone;
  final double? deliveryLat;
  final double? deliveryLng;
  final Map<String, dynamic>? addressRaw;
  final String? notes;
  final String? couponCode;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? packedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final List<OrderItem>? items;
  final String? combinedId;
  final bool isCombined;
  final List<Order>? subOrders;
  final List<String>? subLabels;

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
    this.deliveryBoyName,
    this.deliveryBoyPhone,
    this.deliveryLat,
    this.deliveryLng,
    this.addressRaw,
    this.notes,
    this.couponCode,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.createdAt,
    this.confirmedAt,
    this.packedAt,
    this.shippedAt,
    this.deliveredAt,
    this.items,
    this.combinedId,
    this.isCombined = false,
    this.subOrders,
    this.subLabels,
  });

  ({String? name, String? phone})? get deliveryUser =>
      (deliveryBoyName != null || deliveryBoyPhone != null) ? (name: deliveryBoyName, phone: deliveryBoyPhone) : null;

  ({String label, String formattedAddress, double? lat, double? lng})? get address {
    final rawLat = (addressRaw?['lat'] as num?)?.toDouble() ?? (addressRaw?['latitude'] as num?)?.toDouble() ?? deliveryLat;
    final rawLng = (addressRaw?['lng'] as num?)?.toDouble() ?? (addressRaw?['longitude'] as num?)?.toDouble() ?? deliveryLng;
    final rawAddr = customerAddress ?? (addressRaw?['formattedAddress'] as String?) ?? (addressRaw?['address'] as String?) ?? 'Ghatampur Zone';
    final rawLabel = (addressRaw?['label'] as String?) ?? 'Delivery Location';
    return (
      label: rawLabel,
      formattedAddress: rawAddr,
      lat: rawLat,
      lng: rawLng,
    );
  }

  String get displayId {
    if (readableId != null && readableId!.trim().isNotEmpty) {
      final clean = readableId!.replaceAll('FK-', '').replaceAll('#', '').trim();
      if (clean.isNotEmpty) return clean;
    }
    if (id.startsWith('FK-')) {
      final clean = id.replaceFirst('FK-', '').trim();
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) return digits.substring(digits.length - 4);
      return clean;
    }
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    if (id.length > 4) {
      return id.substring(id.length - 4).toUpperCase();
    }
    return id;
  }

  static OrderStatus parseStatus(dynamic val) {
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
    final rawItems = json['items'] ?? json['order_items'];
    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((itemJson) => OrderItem.fromJson(itemJson))
          .toList();
    }

    String? parseDeliveryBoyName() {
      if (json['deliveryUser'] is Map) return json['deliveryUser']['name']?.toString();
      if (json['deliveryBoy'] is Map) return json['deliveryBoy']['name']?.toString();
      if (json['driver'] is Map) return json['driver']['name']?.toString();
      if (json['rider'] is Map) return json['rider']['name']?.toString();
      return json['deliveryBoyName']?.toString() ??
          json['driverName']?.toString() ??
          json['riderName']?.toString() ??
          json['deliveryPerson']?.toString();
    }

    String? parseDeliveryBoyPhone() {
      if (json['deliveryUser'] is Map) return json['deliveryUser']['phone']?.toString();
      if (json['deliveryBoy'] is Map) return json['deliveryBoy']['phone']?.toString();
      if (json['driver'] is Map) return json['driver']['phone']?.toString();
      if (json['rider'] is Map) return json['rider']['phone']?.toString();
      return json['deliveryBoyPhone']?.toString() ??
          json['driverPhone']?.toString() ??
          json['riderPhone']?.toString() ??
          json['deliveryPhone']?.toString() ??
          json['deliveryBoyContact']?.toString();
    }

    String? parseCustomerAddress() {
      String rawAddr = '';
      if (json['customerAddress'] != null && json['customerAddress'].toString().isNotEmpty) {
        rawAddr = json['customerAddress'].toString();
      } else if (json['address'] is Map) {
        final addr = json['address'] as Map;
        final parts = [
          addr['houseNo'],
          addr['street'],
          addr['area'],
          addr['landmark'],
          addr['city'],
          addr['pincode'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty).map((p) => p.toString().trim()).toList();
        rawAddr = parts.join(', ');
      } else if (json['address'] != null) {
        rawAddr = json['address'].toString();
      }

      if (rawAddr.isEmpty) return null;

      // Clean up stray dots, commas, and empty placeholders (e.g. '.,', ' . ', 'null')
      final cleaned = rawAddr
          .split(',')
          .map((part) => part.replaceAll(RegExp(r'^[.\s,\-]+|[.\s,\-]+$'), '').trim())
          .where((part) => part.isNotEmpty && part != '.' && part != '..' && part != 'null' && part != 'undefined')
          .join(', ');

      return cleaned.isNotEmpty ? cleaned : rawAddr;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      String s = val.toString().trim();
      if (s.isEmpty) return DateTime.now();
      if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
        s = '${s.replaceAll(' ', 'T')}Z';
      }
      final parsed = DateTime.tryParse(s);
      if (parsed == null) return DateTime.now();
      return parsed.toLocal();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      String s = val.toString().trim();
      if (s.isEmpty) return null;
      if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
        s = '${s.replaceAll(' ', 'T')}Z';
      }
      final parsed = DateTime.tryParse(s);
      if (parsed == null) return null;
      return parsed.toLocal();
    }

    String? parseShopName() {
      final explicit = json['shopName']?.toString() ??
          json['restaurantName']?.toString() ??
          (json['restaurant'] is Map ? json['restaurant']['name']?.toString() : null);
      if (explicit != null && explicit.trim().isNotEmpty && explicit != 'null') {
        return explicit.trim();
      }
      final restId = json['restaurantId']?.toString();
      if (restId != null && restId.isNotEmpty && restId != 'null') {
        if (restId == 'cms2p1lyx0001n0idod904lfu' || restId == 'wedson' || restId == 'wedson-restaurant') {
          return 'Wedson Restaurant';
        }
        if (restId == 'cms2p1lap0000n0id8alldboy' || restId == 'as-restaurant' || restId == 'as-cafe') {
          return 'A.S. Restaurant';
        }
        if (restId == 'cmsbhxb6a000304if8kf1cwji' || restId == 'bal-udyan' || restId == 'bal-udyan-restaurant') {
          return 'Bal Udyan Restaurant';
        }
      }
      final rid = (json['readableId']?.toString() ?? '').toUpperCase();
      if (rid.endsWith('-R')) {
        return 'Wedson Restaurant';
      }
      return null;
    }

    return Order(
      id: json['id']?.toString() ?? '',
      readableId: json['readableId']?.toString(),
      userId: json['userId']?.toString() ?? '',
      addressId: json['addressId']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString(),
      status: parseStatus(json['status']),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0.0,
      miscFee: (json['miscFee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      estimatedDelivery: parseNullableDate(json['estimatedDelivery']),
      deliveryPhoto: json['deliveryPhoto']?.toString(),
      deliveryMethod: json['deliveryMethod']?.toString(),
      shopName: parseShopName(),
      shopPhone: json['shopPhone']?.toString(),
      deliveryBoyName: parseDeliveryBoyName(),
      deliveryBoyPhone: parseDeliveryBoyPhone(),
      deliveryLat: (json['deliveryLat'] as num?)?.toDouble() ??
          (json['address'] is Map ? (json['address']['lat'] as num?)?.toDouble() : null),
      deliveryLng: (json['deliveryLng'] as num?)?.toDouble() ??
          (json['address'] is Map ? (json['address']['lng'] as num?)?.toDouble() : null),
      addressRaw: json['address'] is Map ? Map<String, dynamic>.from(json['address']) : null,
      notes: json['notes']?.toString(),
      couponCode: json['couponCode']?.toString(),
      customerName: () {
        if (json['receiverName'] != null && json['receiverName'].toString().trim().isNotEmpty) {
          return json['receiverName'].toString().trim();
        }
        if (json['customerName'] != null && json['customerName'].toString().trim().isNotEmpty) {
          return json['customerName'].toString().trim();
        }
        if (json['customer'] is Map && json['customer']['name'] != null && json['customer']['name'].toString().trim().isNotEmpty) {
          return json['customer']['name'].toString().trim();
        }
        if (json['user'] is Map && json['user']['name'] != null && json['user']['name'].toString().trim().isNotEmpty) {
          return json['user']['name'].toString().trim();
        }
        if (json['userName'] != null && json['userName'].toString().trim().isNotEmpty) {
          return json['userName'].toString().trim();
        }
        return null;
      }(),
      customerPhone: () {
        if (json['receiverPhone'] != null && json['receiverPhone'].toString().trim().isNotEmpty) {
          return json['receiverPhone'].toString().trim();
        }
        if (json['customerPhone'] != null && json['customerPhone'].toString().trim().isNotEmpty) {
          return json['customerPhone'].toString().trim();
        }
        if (json['customer'] is Map && json['customer']['phone'] != null && json['customer']['phone'].toString().trim().isNotEmpty) {
          return json['customer']['phone'].toString().trim();
        }
        if (json['user'] is Map && json['user']['phone'] != null && json['user']['phone'].toString().trim().isNotEmpty) {
          return json['user']['phone'].toString().trim();
        }
        if (json['address'] is Map) {
          final addr = json['address'] as Map;
          if (addr['phone'] != null && addr['phone'].toString().trim().isNotEmpty) return addr['phone'].toString().trim();
          if (addr['contactPhone'] != null && addr['contactPhone'].toString().trim().isNotEmpty) return addr['contactPhone'].toString().trim();
          if (addr['receiverPhone'] != null && addr['receiverPhone'].toString().trim().isNotEmpty) return addr['receiverPhone'].toString().trim();
        }
        if (json['phone'] != null && json['phone'].toString().trim().isNotEmpty) {
          return json['phone'].toString().trim();
        }
        return null;
      }(),
      customerAddress: parseCustomerAddress(),
      createdAt: parseDate(json['createdAt']),
      confirmedAt: parseNullableDate(json['confirmedAt']),
      packedAt: parseNullableDate(json['packedAt']),
      shippedAt: parseNullableDate(json['shippedAt']),
      deliveredAt: parseNullableDate(json['deliveredAt']),
      items: itemsList,
      combinedId: json['combinedId']?.toString(),
      isCombined: json['isCombined'] == true || (json['combinedId'] != null && json['combinedId'].toString().trim().isNotEmpty),
      subOrders: (json['subOrders'] is List)
          ? (json['subOrders'] as List).map((x) => x is Order ? x : Order.fromJson(x)).toList()
          : null,
      subLabels: (json['subLabels'] is List) ? (json['subLabels'] as List).map((x) => x.toString()).toList() : null,
    );
  }

  Order copyWith({
    String? id,
    String? readableId,
    String? userId,
    String? addressId,
    String? restaurantId,
    OrderStatus? status,
    double? subtotal,
    double? discount,
    double? deliveryFee,
    double? taxes,
    double? miscFee,
    double? total,
    PaymentMethod? paymentMethod,
    String? paymentStatus,
    DateTime? estimatedDelivery,
    String? deliveryPhoto,
    String? deliveryMethod,
    String? shopName,
    String? shopPhone,
    String? deliveryBoyName,
    String? deliveryBoyPhone,
    String? notes,
    String? couponCode,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? packedAt,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    List<OrderItem>? items,
    String? combinedId,
    bool? isCombined,
    List<Order>? subOrders,
    List<String>? subLabels,
  }) {
    return Order(
      id: id ?? this.id,
      readableId: readableId ?? this.readableId,
      userId: userId ?? this.userId,
      addressId: addressId ?? this.addressId,
      restaurantId: restaurantId ?? this.restaurantId,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      taxes: taxes ?? this.taxes,
      miscFee: miscFee ?? this.miscFee,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      deliveryPhoto: deliveryPhoto ?? this.deliveryPhoto,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      deliveryBoyName: deliveryBoyName ?? this.deliveryBoyName,
      deliveryBoyPhone: deliveryBoyPhone ?? this.deliveryBoyPhone,
      notes: notes ?? this.notes,
      couponCode: couponCode ?? this.couponCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      packedAt: packedAt ?? this.packedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      items: items ?? this.items,
      combinedId: combinedId ?? this.combinedId,
      isCombined: isCombined ?? this.isCombined,
      subOrders: subOrders ?? this.subOrders,
      subLabels: subLabels ?? this.subLabels,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'readableId': readableId,
    'userId': userId,
    'addressId': addressId,
    'restaurantId': restaurantId,
    'status': status.name.toUpperCase(),
    'subtotal': subtotal,
    'discount': discount,
    'deliveryFee': deliveryFee,
    'taxes': taxes,
    'miscFee': miscFee,
    'total': total,
    'paymentMethod': paymentMethod.name.toUpperCase(),
    'paymentStatus': paymentStatus,
    'estimatedDelivery': estimatedDelivery?.toIso8601String(),
    'deliveryPhoto': deliveryPhoto,
    'deliveryMethod': deliveryMethod,
    'shopName': shopName,
    'shopPhone': shopPhone,
    'notes': notes,
    'couponCode': couponCode,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerAddress': customerAddress,
    'createdAt': createdAt.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'packedAt': packedAt?.toIso8601String(),
    'shippedAt': shippedAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'items': items?.map((i) => i.toJson()).toList(),
  };
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
  final String? notes;

  String? get variant => selectedVariant;

  OrderItem({
    required this.id,
    this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.selectedVariant,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      name: json['name']?.toString() ?? 'Product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: json['imageUrl']?.toString(),
      selectedVariant: json['selectedVariant']?.toString() ?? json['variant']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'imageUrl': imageUrl,
    'selectedVariant': selectedVariant,
    'notes': notes,
  };

  double get lineTotal => price * quantity;
}