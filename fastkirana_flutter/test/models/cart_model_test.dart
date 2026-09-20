import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';

void main() {
  group('Cart & CartItem Model Tests', () {
    final mockProduct1 = Product(
      id: 'prod_apple',
      name: 'Shimla Apple 1kg',
      slug: 'shimla-apple-1kg',
      mrp: 180.0,
      price: 140.0,
      discount: 40.0,
      unit: '1 kg',
      stock: 30,
      minStock: 5,
      costPrice: 110.0,
      isAvailable: true,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      tags: ['fruits'],
      createdAt: DateTime(2026, 9, 1),
    );

    final mockProduct2 = Product(
      id: 'prod_mango',
      name: 'Alphonso Mango 1kg',
      slug: 'alphonso-mango-1kg',
      mrp: 250.0,
      price: 200.0,
      discount: 50.0,
      unit: '1 kg',
      stock: 15,
      minStock: 2,
      costPrice: 160.0,
      isAvailable: true,
      isFlashDeal: true,
      isTopPick: false,
      isBestSeller: false,
      sortOrder: 2,
      tags: ['fruits'],
      createdAt: DateTime(2026, 9, 1),
    );

    test('CartItem calculates lineTotal correctly', () {
      final item = CartItem(
        id: 'cart_item_1',
        cartId: 'cart_001',
        productId: mockProduct1.id,
        product: mockProduct1,
        quantity: 3,
        selectedVariant: 'Medium',
        notes: 'Select fresh ones',
      );

      expect(item.lineTotal, 420.0); // 140 * 3
      expect(item.quantity, 3);
      expect(item.selectedVariant, 'Medium');
      expect(item.notes, 'Select fresh ones');
    });

    test('Cart calculates subtotal and item count correctly', () {
      final item1 = CartItem(
        id: 'cart_item_1',
        cartId: 'cart_001',
        productId: mockProduct1.id,
        product: mockProduct1,
        quantity: 2,
      );

      final item2 = CartItem(
        id: 'cart_item_2',
        cartId: 'cart_001',
        productId: mockProduct2.id,
        product: mockProduct2,
        quantity: 1,
      );

      final cart = Cart(
        id: 'cart_001',
        userId: 'user_456',
        items: [item1, item2],
        appliedCouponCode: 'TASTY50',
        couponDiscount: 50.0,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      expect(cart.subtotal, 480.0); // (140 * 2) + (200 * 1) = 280 + 200 = 480
      expect(cart.totalItems, 3); // 2 + 1
      expect(cart.appliedCouponCode, 'TASTY50');
      expect(cart.couponDiscount, 50.0);
    });
  });
}
