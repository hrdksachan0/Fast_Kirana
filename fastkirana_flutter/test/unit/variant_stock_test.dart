import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/product.dart';

void main() {
  group('Variant Stock Precision Tests', () {
    test('isInStock is false when all variants have stock 0 even if top stock is 999', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Test Milk',
        'slug': 'test-milk',
        'price': 30,
        'mrp': 35,
        'stock': 999, // Parent default/stock
        'isAvailable': true,
        'variants': [
          {'name': '500ml', 'price': 30, 'mrp': 35, 'stock': 0},
          {'name': '1L', 'price': 60, 'mrp': 70, 'stock': 0},
        ],
      });

      expect(product.isInStock, isFalse);
    });

    test('isInStock is true when at least one variant has stock > 0', () {
      final product = Product.fromJson({
        'id': 'p2',
        'name': 'Test Bread',
        'slug': 'test-bread',
        'price': 25,
        'mrp': 30,
        'stock': 0, // Parent stock 0
        'isAvailable': true,
        'variants': [
          {'name': 'Small', 'price': 25, 'mrp': 30, 'stock': 0},
          {'name': 'Large', 'price': 45, 'mrp': 50, 'stock': 10},
        ],
      });

      expect(product.isInStock, isTrue);
    });

    test('getStockForVariant returns specific variant stock, not top-level stock', () {
      final product = Product.fromJson({
        'id': 'p3',
        'name': 'Paneer Butter Masala',
        'slug': 'paneer-butter-masala',
        'price': 180,
        'mrp': 200,
        'stock': 100, // Top product says 100
        'isAvailable': true,
        'variants': [
          {'name': 'Half', 'price': 100, 'mrp': 120, 'stock': 0}, // Out of stock
          {'name': 'Full', 'price': 180, 'mrp': 200, 'stock': 5}, // 5 in stock
        ],
      });

      expect(product.getStockForVariant('Half'), equals(0));
      expect(product.isVariantInStock('Half'), isFalse);

      expect(product.getStockForVariant('Full'), equals(5));
      expect(product.isVariantInStock('Full'), isTrue);
    });

    test('variant parsing marks explicit out_of_stock or isAvailable: false as stock 0', () {
      final json = {
        'id': 'p4',
        'name': 'Cold Drink',
        'slug': 'cold-drink',
        'price': 40,
        'mrp': 40,
        'stock': 50,
        'isAvailable': true,
        'variants': [
          {'name': 'Can 250ml', 'price': 40, 'mrp': 40, 'stock': 10, 'isAvailable': true},
          {'name': 'Bottle 500ml', 'price': 60, 'mrp': 60, 'stock': 20, 'isAvailable': false},
          {'name': 'Bottle 1L', 'price': 90, 'mrp': 90, 'status': 'out_of_stock'},
        ],
      };

      final product = Product.fromJson(json);
      expect(product.getStockForVariant('Can 250ml'), equals(10));
      expect(product.getStockForVariant('Bottle 500ml'), equals(0));
      expect(product.getStockForVariant('Bottle 1L'), equals(0));
    });
  });
}
