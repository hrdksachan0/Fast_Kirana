import 'package:flutter/material.dart';

class PickerOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? selectedVariant;
  final String? imageUrl;
  final String? notes;

  const PickerOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.selectedVariant,
    this.imageUrl,
    this.notes,
  });

  factory PickerOrderItem.fromJson(Map<String, dynamic> json) {
    return PickerOrderItem(
      id: (json['id'] ?? json['productId'] ?? '').toString(),
      name: (json['name'] ?? json['productName'] ?? json['title'] ?? 'Grocery Item').toString(),
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0),
      selectedVariant: json['selectedVariant']?.toString() ?? json['variant']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'price': price,
    if (selectedVariant != null) 'selectedVariant': selectedVariant,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (notes != null) 'notes': notes,
  };
}

class PickerOrder {
  final String id;
  final String readableId;
  final String status;
  final double total;
  final List<PickerOrderItem> items;
  final String customerName;
  final String customerPhone;
  final String? customerAddress;
  final String? notes;
  final DateTime createdAt;
  final Map<String, dynamic> rawJson;

  const PickerOrder({
    required this.id,
    required this.readableId,
    required this.status,
    required this.total,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress,
    this.notes,
    required this.createdAt,
    required this.rawJson,
  });

  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isPacked => status.toUpperCase() == 'PACKED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  int get elapsedMinutes => DateTime.now().difference(createdAt).inMinutes;

  String get displayId {
    if (readableId.isNotEmpty) {
      return readableId.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
    }
    return id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return Colors.blue;
      case 'PACKED':
        return Colors.indigo;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  factory PickerOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['orderItems'] ?? [];
    List<PickerOrderItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => i is Map<String, dynamic> ? PickerOrderItem.fromJson(i) : null)
          .whereType<PickerOrderItem>()
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

    return PickerOrder(
      id: (json['id'] ?? '').toString(),
      readableId: (json['readableId'] ?? json['readable_id'] ?? '').toString(),
      status: (json['status'] ?? 'CONFIRMED').toString().toUpperCase(),
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : (double.tryParse(json['total']?.toString() ?? '0') ?? 0.0),
      items: parsedItems,
      customerName: userName,
      customerPhone: userPhone,
      customerAddress: customerAddr.isNotEmpty ? customerAddr : null,
      notes: json['notes']?.toString(),
      createdAt: parsedDate,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson;
}
