import 'package:json_annotation/json_annotation.dart';
import 'product.dart';

part 'cart.g.dart';

@JsonSerializable()
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

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemToJson(this);

  double get lineTotal => product.price * quantity;
}

@JsonSerializable()
class Cart {
  final String id;
  final String userId;
  final List<CartItem> items;
  final String? appliedCouponCode;
  final double couponDiscount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cart({
    required this.id,
    required this.userId,
    required this.items,
    this.appliedCouponCode,
    required this.couponDiscount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) =>
      _$CartFromJson(json);
  Map<String, dynamic> toJson() => _$CartToJson(this);

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity);

  double get mrpTotal =>
      items.fold(0, (sum, item) => sum + (item.product.mrp * item.quantity));

  double get savings => mrpTotal - subtotal;
}