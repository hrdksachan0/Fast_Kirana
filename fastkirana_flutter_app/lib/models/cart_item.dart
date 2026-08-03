class CartItem {
  final Product product;
  int quantity;
  String? notes;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
  });

  double get totalPrice => product.price * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? notes,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}

class Address {
  final String id;
  final String label;
  final String houseNo;
  final String street;
  final String area;
  final String city;
  final String pincode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  Address({
    required this.id,
    required this.label,
    required this.houseNo,
    required this.street,
    required this.area,
    required this.city,
    required this.pincode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? 'Home',
      houseNo: json['house_no'] ?? json['houseNo'] ?? '',
      street: json['street'] ?? '',
      area: json['area'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
    );
  }

  String get fullAddress => '$houseNo, $street, $area, $city - $pincode';
}

class Order {
  final String id;
  final String? readableId;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final List<OrderItem> items;
  final Address? address;

  Order({
    required this.id,
    this.readableId,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    this.estimatedDelivery,
    required this.items,
    this.address,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      readableId: json['readable_id']?.toString(),
      status: json['status'] ?? 'PENDING',
      paymentMethod: json['payment_method'] ?? 'COD',
      paymentStatus: json['payment_status'] ?? 'PENDING',
      subtotal: _toDouble(json['subtotal']),
      discount: _toDouble(json['discount']),
      deliveryFee: _toDouble(json['delivery_fee']),
      total: _toDouble(json['total']),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.tryParse(json['estimated_delivery'])
          : null,
      items: (json['items'] as List?)?.map((i) => OrderItem.fromJson(i)).toList() ?? [],
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
    );
  }

  static double _toDouble(dynamic v) => v != null ? (v is double ? v : (v as num).toDouble()) : 0.0;
}

class OrderItem {
  final String id;
  final String name;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String? unit;

  OrderItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.price,
    required this.quantity,
    this.unit,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? json['product_id']?.toString() ?? '',
      name: json['name'] ?? json['product_name'] ?? '',
      imageUrl: json['image_url'] ?? json['product']?['image_url'],
      price: Order._toDouble(json['price']),
      quantity: json['quantity'] ?? 1,
      unit: json['unit'],
    );
  }

  double get total => price * quantity;
}

class Restaurant {
  final String id;
  final String name;
  final String slug;
  final double rating;
  final String deliveryTime;
  final String cuisines;
  final bool isPureVeg;
  final String imageUrl;
  final String address;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.rating,
    required this.deliveryTime,
    required this.cuisines,
    required this.isPureVeg,
    required this.imageUrl,
    required this.address,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id']?.toString() ?? json['slug'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.0,
      deliveryTime: json['delivery_time'] ?? json['deliveryTime'] ?? '20-30 mins',
      cuisines: json['cuisines'] ?? json['cuisine'] ?? '',
      isPureVeg: json['is_pure_veg'] ?? json['isPureVeg'] ?? false,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? '',
      address: json['address'] ?? '',
    );
  }
}

class Review {
  final String id;
  final String userName;
  final String? userImage;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userName,
    this.userImage,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      userName: json['user']?['name'] ?? json['user_name'] ?? 'Customer',
      userImage: json['user']?['image'],
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class Coupon {
  final String code;
  final String description;
  final double discountAmount;
  final double? minOrderValue;
  final DateTime? validUntil;

  Coupon({
    required this.code,
    required this.description,
    required this.discountAmount,
    this.minOrderValue,
    this.validUntil,
  });
}
