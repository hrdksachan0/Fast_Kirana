import 'package:flutter/material.dart';

class KitchenOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? selectedVariant;
  final String? notes;
  final String? imageUrl;

  const KitchenOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.selectedVariant,
    this.notes,
    this.imageUrl,
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) {
    return KitchenOrderItem(
      id: (json['id'] ?? json['productId'] ?? '').toString(),
      name: (json['name'] ?? json['productName'] ?? json['title'] ?? 'Food Item').toString(),
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0),
      selectedVariant: json['selectedVariant']?.toString() ?? json['variant']?.toString(),
      notes: json['notes']?.toString() ?? json['instruction']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'price': price,
    if (selectedVariant != null) 'selectedVariant': selectedVariant,
    if (notes != null) 'notes': notes,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

class KitchenOrder {
  final String id;
  final String readableId;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double total;
  final double subtotal;
  final List<KitchenOrderItem> items;
  final String? notes;
  final String? cookingInstruction;
  final DateTime createdAt;
  final String? shopName;
  final String? restaurantId;
  final String customerName;
  final String customerPhone;
  final String? customerAddress;
  final String deliveryMethod;
  final bool isKotPrinted;
  final Map<String, dynamic> rawJson;

  const KitchenOrder({
    required this.id,
    required this.readableId,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.subtotal,
    required this.items,
    this.notes,
    this.cookingInstruction,
    required this.createdAt,
    this.shopName,
    this.restaurantId,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress,
    this.deliveryMethod = 'DELIVERY',
    this.isKotPrinted = false,
    required this.rawJson,
  });

  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';
  bool get isCod => paymentMethod.toUpperCase() == 'COD';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isPreparing => status.toUpperCase() == 'CONFIRMED' || status.toUpperCase() == 'PREPARING';
  bool get isReady => status.toUpperCase() == 'PACKED' || status.toUpperCase() == 'READY';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  int get elapsedMinutes => DateTime.now().difference(createdAt).inMinutes;

  String get displayId {
    if (readableId.isNotEmpty) {
      return readableId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
    }
    return id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
      case 'PREPARING':
        return Colors.blue;
      case 'PACKED':
      case 'READY':
        return Colors.indigo;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['orderItems'] ?? [];
    List<KitchenOrderItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => i is Map<String, dynamic> ? KitchenOrderItem.fromJson(i) : null)
          .whereType<KitchenOrderItem>()
          .toList();
    }

    DateTime parsedDate;
    try {
      final rawDate = json['createdAt'] ?? json['created_at'];
      parsedDate = rawDate != null ? DateTime.parse(rawDate.toString()).toLocal() : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawUser = json['user'];
    final userName = (json['customerName'] ?? (rawUser is Map ? rawUser['name'] : null) ?? json['userName'] ?? 'Customer').toString();
    final userPhone = (json['customerPhone'] ?? (rawUser is Map ? rawUser['phone'] : null) ?? json['userPhone'] ?? '').toString();

    final addressObj = json['address'];
    final customerAddr = (json['customerAddress'] ??
        (addressObj is Map ? '${addressObj['houseNo'] ?? ''} ${addressObj['street'] ?? ''} ${addressObj['area'] ?? ''}' : null) ??
        '').toString().trim();

    return KitchenOrder(
      id: (json['id'] ?? '').toString(),
      readableId: (json['readableId'] ?? json['readable_id'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'COD').toString().toUpperCase(),
      paymentStatus: (json['paymentStatus'] ?? json['payment_status'] ?? 'PENDING').toString().toUpperCase(),
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : (double.tryParse(json['total']?.toString() ?? '0') ?? 0.0),
      subtotal: (json['subtotal'] is num) ? (json['subtotal'] as num).toDouble() : (double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0),
      items: parsedItems,
      notes: json['notes']?.toString(),
      cookingInstruction: json['cookingInstruction']?.toString() ?? json['instruction']?.toString(),
      createdAt: parsedDate,
      shopName: json['shopName']?.toString() ?? (json['restaurant'] is Map ? json['restaurant']['name'] : null)?.toString(),
      restaurantId: json['restaurantId']?.toString() ?? (json['restaurant'] is Map ? json['restaurant']['id'] : null)?.toString(),
      customerName: userName,
      customerPhone: userPhone,
      customerAddress: customerAddr.isNotEmpty ? customerAddr : null,
      deliveryMethod: (json['deliveryMethod'] ?? 'DELIVERY').toString().toUpperCase(),
      isKotPrinted: json['kotPrinted'] == true,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson;
}
