class DeliveryOrderUser {
  final String id;
  final String? name;
  final String? phone;
  final String? email;

  const DeliveryOrderUser({
    required this.id,
    this.name,
    this.phone,
    this.email,
  });

  factory DeliveryOrderUser.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['fullName']?.toString(),
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
  };
}

class DeliveryOrderAddress {
  final String? fullAddress;
  final String? landmark;
  final String? city;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  const DeliveryOrderAddress({
    this.fullAddress,
    this.landmark,
    this.city,
    this.pincode,
    this.latitude,
    this.longitude,
  });

  factory DeliveryOrderAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderAddress(
      fullAddress: json['fullAddress']?.toString() ?? json['addressLine1']?.toString() ?? json['address']?.toString(),
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString(),
      pincode: json['pincode']?.toString() ?? json['postalCode']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (fullAddress != null) 'fullAddress': fullAddress,
    if (landmark != null) 'landmark': landmark,
    if (city != null) 'city': city,
    if (pincode != null) 'pincode': pincode,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

class DeliveryOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? image;
  final Map<String, dynamic>? extra;

  const DeliveryOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
    this.extra,
  });

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      image: json['image']?.toString() ?? json['imageUrl']?.toString(),
      extra: json['extra'] is Map ? Map<String, dynamic>.from(json['extra'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'price': price,
    if (image != null) 'image': image,
    if (extra != null) 'extra': extra,
  };
}

class DeliveryOrder {
  final String id;
  final String? readableId;
  final String? combinedId;
  final String status;
  final double total;
  final double deliveryFee;
  final String paymentMethod;
  final String paymentStatus;
  final DeliveryOrderUser? user;
  final DeliveryOrderAddress? address;
  final List<DeliveryOrderItem> items;
  final Map<String, dynamic>? restaurant;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  const DeliveryOrder({
    required this.id,
    this.readableId,
    this.combinedId,
    required this.status,
    required this.total,
    required this.deliveryFee,
    required this.paymentMethod,
    required this.paymentStatus,
    this.user,
    this.address,
    this.items = const [],
    this.restaurant,
    this.createdAt,
    this.raw = const {},
  });

  bool get isCodOrder => paymentMethod.toUpperCase() == 'COD';
  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';
  String get displayId => readableId ?? (id.length > 8 ? id.substring(0, 8) : id);
  String get formattedTotal => '₹';
  String get customerPhone => user?.phone ?? '';
  String get customerName => user?.name ?? 'Customer';
  String get fullAddressText => address?.fullAddress ?? 'No address provided';

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    DeliveryOrderUser? parsedUser;
    if (json['user'] is Map) {
      parsedUser = DeliveryOrderUser.fromJson(Map<String, dynamic>.from(json['user'] as Map));
    }

    DeliveryOrderAddress? parsedAddress;
    if (json['address'] is Map) {
      parsedAddress = DeliveryOrderAddress.fromJson(Map<String, dynamic>.from(json['address'] as Map));
    }

    List<DeliveryOrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map>()
          .map((i) => DeliveryOrderItem.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    }

    DateTime? parsedDate;
    if (json['createdAt'] != null) {
      parsedDate = DateTime.tryParse(json['createdAt'].toString());
    }

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      readableId: json['readableId']?.toString(),
      combinedId: json['combinedId']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      user: parsedUser,
      address: parsedAddress,
      items: parsedItems,
      restaurant: json['restaurant'] is Map ? Map<String, dynamic>.from(json['restaurant'] as Map) : null,
      createdAt: parsedDate,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw.isNotEmpty ? raw : {
    'id': id,
    if (readableId != null) 'readableId': readableId,
    if (combinedId != null) 'combinedId': combinedId,
    'status': status,
    'total': total,
    'deliveryFee': deliveryFee,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    if (user != null) 'user': user!.toJson(),
    if (address != null) 'address': address!.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    if (restaurant != null) 'restaurant': restaurant,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
