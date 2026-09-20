import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/data/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product correctly parses from and serializes to JSON', () {
      final json = {
        'id': 'prod_milk_01',
        'name': 'Amul Taaza Milk 500ml',
        'slug': 'amul-taaza-milk-500ml',
        'description': 'Pasteurised toned milk pouches',
        'imageUrl': 'https://example.com/amul_milk.jpg',
        'categoryId': 'cat_dairy',
        'restaurantId': null,
        'mrp': 28.0,
        'price': 27.0,
        'discount': 1.0,
        'unit': '500 ml',
        'stock': 45,
        'isAvailable': true,
        'tags': ['dairy', 'milk', 'breakfast'],
        'isFlashDeal': true,
        'isTopPick': true,
        'isBestSeller': true,
        'sortOrder': 1,
        'costPrice': 24.5,
        'barcode': '8901262010054',
        'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      };

      final product = Product.fromJson(json);

      expect(product.id, 'prod_milk_01');
      expect(product.name, 'Amul Taaza Milk 500ml');
      expect(product.slug, 'amul-taaza-milk-500ml');
      expect(product.mrp, 28.0);
      expect(product.price, 27.0);
      expect(product.discount, 1.0);
      expect(product.unit, '500 ml');
      expect(product.stock, 45);
      expect(product.isAvailable, true);
      expect(product.isFlashDeal, true);
      expect(product.isTopPick, true);
      expect(product.isBestSeller, true);
      expect(product.barcode, '8901262010054');
      expect(product.tags, contains('dairy'));

      final serialized = product.toJson();
      expect(serialized['id'], 'prod_milk_01');
      expect(serialized['name'], 'Amul Taaza Milk 500ml');
      expect(serialized['price'], 27.0);
      expect(serialized['barcode'], '8901262010054');
    });

    test('Product handles variants and addons correctly', () {
      final json = {
        'id': 'prod_pizza_01',
        'name': 'Farmhouse Pizza',
        'slug': 'farmhouse-pizza',
        'mrp': 299.0,
        'price': 249.0,
        'discount': 50.0,
        'unit': '1 pc',
        'stock': 100,
        'isAvailable': true,
        'variants': [
          {
            'id': 'var_reg',
            'name': 'Regular (7 inch)',
            'price': 249.0,
            'mrp': 299.0,
            'isAvailable': true,
          },
          {
            'id': 'var_med',
            'name': 'Medium (10 inch)',
            'price': 449.0,
            'mrp': 499.0,
            'isAvailable': true,
          }
        ],
        'addons': [
          {
            'title': 'Extra Cheese',
            'required': false,
            'maxSelect': 1,
            'items': [
              {
                'name': 'Cheese Burst',
                'price': 60.0,
              }
            ]
          }
        ],
        'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      };

      final product = Product.fromJson(json);

      expect(product.variants, isNotNull);
      expect(product.variants!.length, 2);
      expect(product.variants![0].name, 'Regular (7 inch)');
      expect(product.variants![1].price, 449.0);

      expect(product.addons, isNotNull);
      expect(product.addons!.length, 1);
      expect(product.addons![0].title, 'Extra Cheese');
      expect(product.addons![0].items[0].name, 'Cheese Burst');
      expect(product.addons![0].items[0].price, 60.0);
    });

    test('Product parses numeric fields safely with fallbacks', () {
      final json = {
        'id': 'prod_fallback',
        'name': 'Test Item',
        'slug': 'test-item',
        'mrp': '50',
        'price': '45',
        'stock': '20',
        'discount': null,
        'unit': 'piece',
      };

      final product = Product.fromJson(json);

      expect(product.mrp, 50.0);
      expect(product.price, 45.0);
      expect(product.stock, 20);
      expect(product.discount, 0.0);
    });
  });
}
