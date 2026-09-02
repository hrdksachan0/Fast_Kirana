import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';
import 'package:fastkirana_flutter/core/utils/restaurant_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CartNotifier> makeNotifier() async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET') {
          return handler.resolve(Response(
            data: {
              'id': 'cart_stub', 'userId': 'u', 'items': [],
              'couponDiscount': 0.0,
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
            requestOptions: RequestOptions(path: options.path),
          ));
        }
        return handler.next(options);
      },
    ));
    return CartNotifier(CartRepository(dio));
  }

  group('isRestaurantProduct / isCafeProduct', () {
    test('groceries return false', () {
      final p = Product(
        id: 'g1', name: 'Amul Butter', slug: 'amul', categoryId: 'dairy',
        mrp: 275, price: 260, discount: 5, unit: '500g', stock: 20,
        isAvailable: true, tags: const ['dairy', 'butter'],
        minStock: 2, costPrice: 240, isFlashDeal: false,
        isTopPick: true, isBestSeller: true, sortOrder: 1,
        createdAt: DateTime.now(),
      );
      expect(isRestaurantProduct(p), isFalse);
      expect(isCafeProduct(p), isFalse);
    });

    test('restaurant products return true', () {
      final p = Product(
        id: 'w1', name: 'Paneer Butter Masala', slug: 'pbm',
        categoryId: 'restaurant-food', restaurantId: outletWedsonId,
        mrp: 220, price: 200, discount: 9, unit: '1 plate', stock: 50,
        isAvailable: true,
        tags: const ['wedson', 'restaurant', 'curry'],
        minStock: 0, costPrice: 150, isFlashDeal: false,
        isTopPick: false, isBestSeller: true, sortOrder: 2,
        createdAt: DateTime.now(),
      );
      expect(isRestaurantProduct(p), isTrue);
      expect(isCafeProduct(p), isTrue);
    });

    test('cafe tag triggers restaurant detection', () {
      final p = Product(
        id: 'c1', name: 'Cold Coffee', slug: 'cold-coffee',
        categoryId: 'beverages',
        mrp: 80, price: 65, discount: 18, unit: '200ml', stock: 30,
        isAvailable: true, tags: const ['cafe'],
        minStock: 5, costPrice: 40, isFlashDeal: false,
        isTopPick: false, isBestSeller: false, sortOrder: 3,
        createdAt: DateTime.now(),
      );
      expect(isRestaurantProduct(p), isTrue);
    });
  });

  group('CartNotifier.addProduct', () {
    test('adds product and updates state', () async {
      final notifier = await makeNotifier();
      final p = _makeGrocery('p1', 'Test Item', 10);

      final added = notifier.addProduct(p);
      expect(added, isTrue);
      final items = notifier.state.value?.items;
      expect(items?.length, 1);
      expect(items?.first.quantity, 1);
    });

    test('rejects when stock limit reached', () async {
      final notifier = await makeNotifier();
      final p = _makeGrocery('p2', 'Limited Item', 2);

      expect(notifier.addProduct(p, 1), isTrue);
      expect(notifier.addProduct(p, 1), isTrue);
      expect(notifier.addProduct(p, 1), isFalse);
    });
  });

  group('CartNotifier.checkRestaurantConflict', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('grocery item causes no conflict with restaurant dish', () async {
      final notifier = await makeNotifier();
      final grocery = _makeGrocery('g1', 'Bread', 10);
      final dish = Product(
        id: 'd1', name: 'Pizza', slug: 'pizza', categoryId: 'restaurant-food',
        restaurantId: outletAsRestaurantId,
        mrp: 200, price: 180, discount: 10, unit: '1', stock: 10,
        isAvailable: true, tags: const ['as-restaurant'], minStock: 1,
        costPrice: 120, isFlashDeal: false, isTopPick: false,
        isBestSeller: false, sortOrder: 1, createdAt: DateTime.now(),
      );

      notifier.addProduct(grocery);
      expect(notifier.checkRestaurantConflict(dish), isNull);
    });

    test('detects conflict between different restaurants', () async {
      final notifier = await makeNotifier();
      final wedson = Product(
        id: 'w1', name: 'Paneer', slug: 'paneer',
        categoryId: 'restaurant-food', restaurantId: outletWedsonId,
        mrp: 220, price: 200, discount: 9, unit: '1 plate', stock: 50,
        isAvailable: true, tags: const ['wedson'], minStock: 0,
        costPrice: 150, isFlashDeal: false, isTopPick: false,
        isBestSeller: true, sortOrder: 2, createdAt: DateTime.now(),
      );
      final asDish = Product(
        id: 'a1', name: 'Burger', slug: 'burger',
        categoryId: 'restaurant-food', restaurantId: outletAsRestaurantId,
        mrp: 120, price: 100, discount: 16, unit: '1', stock: 20,
        isAvailable: true, tags: const ['as-restaurant'], minStock: 1,
        costPrice: 60, isFlashDeal: false, isTopPick: false,
        isBestSeller: false, sortOrder: 1, createdAt: DateTime.now(),
      );

      notifier.addProduct(wedson);
      expect(notifier.checkRestaurantConflict(asDish), isNotNull);
    });
  });

  group('CartNotifier.decrement', () {
    test('removes item when quantity reaches 0', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = await makeNotifier();
      final p = _makeGrocery('p3', 'DeleteMe', 5);
      notifier.addProduct(p, 1);
      expect(notifier.state.value?.items.length, 1);

      await notifier.decrement(p.id);
      expect(notifier.state.value?.items.length, 0);
    });
  });

  group('CartNotifier.clearRestaurantItems', () {
    test('keeps groceries, removes restaurant items', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = await makeNotifier();
      // loadCart runs asynchronously; let it finish
      await Future.delayed(const Duration(milliseconds: 100));

      final grocery = _makeGrocery('g2', 'Milk', 20);
      final dish = Product(
        id: 'd2', name: 'Chowmein', slug: 'chowmein',
        categoryId: 'restaurant-food', restaurantId: outletAsRestaurantId,
        mrp: 150, price: 130, discount: 13, unit: '1 plate', stock: 20,
        isAvailable: true, tags: const ['as-restaurant'], minStock: 1,
        costPrice: 80, isFlashDeal: false, isTopPick: false,
        isBestSeller: false, sortOrder: 1, createdAt: DateTime.now(),
      );

      notifier.addProduct(grocery, 2);
      notifier.addProduct(dish, 1);
      await notifier.clearRestaurantItems();

      final items = notifier.state.value?.items;
      expect(items?.length, 1);
      expect(items?.first.product.id, 'g2');
    });
  });
}

/// Helper to build a minimal grocery Product
Product _makeGrocery(String id, String name, int stock) => Product(
      id: id, name: name, slug: name.toLowerCase(), categoryId: 'grocery',
      mrp: 100, price: 80, discount: 20, unit: '1pc', stock: stock,
      isAvailable: true, tags: const [], minStock: 1, costPrice: 60,
      isFlashDeal: false, isTopPick: false, isBestSeller: false,
      sortOrder: 1, createdAt: DateTime.now(),
    );
