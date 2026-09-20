import 'product.dart';

class CartItem {
  final String id;
  final String cartId;
  final String productId;
  final Product product;
  final int quantity;
  final String? selectedVariant;
  final String? notes;

  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.product,
    required this.quantity,
    this.selectedVariant,
    this.notes,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String? ?? '',
        cartId: json['cartId'] as String? ?? '',
        productId: json['productId'] as String? ?? '',
        product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        selectedVariant: json['selectedVariant'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cartId': cartId,
        'productId': productId,
        'product': product.toJson(),
        'quantity': quantity,
        'selectedVariant': selectedVariant,
        'notes': notes,
      };

  double get lineTotal => product.price * quantity;
}

class Cart {
  final String id;
  final String userId;
  final List<CartItem> items;
  final String? appliedCouponCode;
  final double couponDiscount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hubId; // 🏬 Bound store hub fulfillment ID

  Cart({
    required this.id,
    required this.userId,
    required this.items,
    this.appliedCouponCode,
    required this.couponDiscount,
    required this.createdAt,
    required this.updatedAt,
    this.hubId,
  });

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        id: json['id'] as String? ?? 'cart_active',
        userId: json['userId'] as String? ?? 'user_active',
        items: json['items'] != null
            ? (json['items'] as List<dynamic>)
                .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : [],
        appliedCouponCode: json['appliedCouponCode'] as String?,
        couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        hubId: json['hubId']?.toString() ?? json['storeId']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'items': items.map((i) => i.toJson()).toList(),
        if (appliedCouponCode != null) 'appliedCouponCode': appliedCouponCode,
        'couponDiscount': couponDiscount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (hubId != null) 'hubId': hubId,
      };

  Cart copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    String? appliedCouponCode,
    double? couponDiscount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? hubId,
    bool clearCoupon = false,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      appliedCouponCode: clearCoupon ? null : (appliedCouponCode ?? this.appliedCouponCode),
      couponDiscount: clearCoupon ? 0.0 : (couponDiscount ?? this.couponDiscount),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hubId: hubId ?? this.hubId,
    );
  }

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity);

  double get mrpTotal =>
      items.fold(0, (sum, item) => sum + (item.product.mrp * item.quantity));

  double get savings => mrpTotal - subtotal;
}