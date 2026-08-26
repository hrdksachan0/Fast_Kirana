import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/core/utils/restaurant_utils.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:dio/dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Restaurant Utility & Conflict Tests', () {
    final groceryItem = Product(
      id: 'g1',
      name: 'Amul Butter 500g',
      slug: 'amul-butter',
      categoryId: 'dairy-breakfast',
      mrp: 275,
      price: 260,
      discount: 5,
      unit: '500g',
      stock: 20,
      isAvailable: true,
      tags: ['dairy', 'butter'],
      minStock: 2,
      costPrice: 240,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    );

    final wedsonDish = Product(
      id: 'w1',
      name: 'Paneer Butter Masala',
      slug: 'paneer-butter-masala',
      categoryId: 'restaurant-food',
      restaurantId: outletWedsonId,
      mrp: 220,
      price: 200,
      discount: 9,
      unit: '1 plate',
      stock: 50,
      isAvailable: true,
      tags: ['wedson', 'restaurant', 'curry'],
      minStock: 0,
      costPrice: 150,
      isFlashDeal: false,
      isTopPick: false,
      isBestSeller: true,
      sortOrder: 2,
      createdAt: DateTime.now(),
    );

    final balUdyanDish = Product(
      id: 'b1',
      name: 'Dal Makhani Special',
      slug: 'dal-makhani-special',
      categoryId: 'restaurant-food',
      restaurantId: outletBalUdyanId,
      mrp: 180,
      price: 160,
      discount: 11,
      unit: '1 plate',
      stock: 50,
      isAvailable: true,
      tags: ['bal-udyan', 'restaurant', 'dal'],
      minStock: 0,
      costPrice: 120,
      isFlashDeal: false,
      isTopPick: false,
      isBestSeller: false,
      sortOrder: 3,
      createdAt: DateTime.now(),
    );

    test('isCafeProduct correctly identifies food vs grocery', () {
      expect(isCafeProduct(groceryItem), isFalse);
      expect(isCafeProduct(wedsonDish), isTrue);
      expect(isCafeProduct(balUdyanDish), isTrue);
    });

    test('getOutletName returns correct outlet name', () {
      expect(getOutletName(wedsonDish), 'Wedson Restaurant');
      expect(getOutletName(balUdyanDish), 'Bal Udyan Restaurant');
    });

    test('CartNotifier handles conflict, keeping grocery items safe', () async {
      final notifier = CartNotifier(CartRepository(Dio()));
      // Allow initial loadCart to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Add grocery item
      await notifier.addProduct(groceryItem, 2);
      expect(notifier.state.value?.items.length, 1);
      expect(notifier.groceryItemsCount, 2);

      // 2. Add Wedson dish - No conflict because cart has only grocery items
      expect(notifier.checkRestaurantConflict(wedsonDish), isNull);
      await notifier.addProduct(wedsonDish, 1);
      expect(notifier.state.value?.items.length, 2);
      expect(notifier.groceryItemsCount, 2);
      expect(notifier.restaurantItemsCount, 1);
      expect(notifier.currentRestaurantName, 'Wedson Restaurant');

      // 3. Check conflict when trying to add Bal Udyan dish
      final conflict = notifier.checkRestaurantConflict(balUdyanDish);
      expect(conflict, 'Wedson Restaurant');

      // 4. Resolve conflict by replacing restaurant items (switching restaurant)
      await notifier.replaceRestaurantItemsWith(balUdyanDish, 1);

      // Verify grocery item remained safe and restaurant switched to Bal Udyan
      expect(notifier.state.value?.items.length, 2);
      expect(notifier.groceryItemsCount, 2);
      expect(notifier.restaurantItemsCount, 1);
      expect(notifier.currentRestaurantName, 'Bal Udyan Restaurant');

      final items = notifier.state.value!.items;
      expect(items.any((i) => i.productId == groceryItem.id), isTrue);
      expect(items.any((i) => i.productId == balUdyanDish.id), isTrue);
      expect(items.any((i) => i.productId == wedsonDish.id), isFalse);
    });
  });
}
