import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';
import 'package:fastkirana_flutter/core/services/location_service.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:fastkirana_flutter/data/repositories/wishlist_repository.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';
import 'package:fastkirana_flutter/providers/wishlist_provider.dart';
import 'package:fastkirana_flutter/providers/store_settings_provider.dart';
import 'package:fastkirana_flutter/widgets/product_card.dart';
import 'package:fastkirana_flutter/widgets/floating_cart_bar.dart';
import 'package:fastkirana_flutter/features/home/widgets/delivery_mode_header.dart';

class FakeCartNotifier extends CartNotifier {
  FakeCartNotifier(Cart cart) : super(CartRepository(Dio())) {
    state = AsyncValue.data(cart);
  }

  @override
  Future<void> loadCart([CartRepository? repo]) async {}
}

class FakeWishlistNotifier extends WishlistNotifier {
  FakeWishlistNotifier() : super(WishlistRepository(Dio())) {
    state = [];
  }

  @override
  Future<void> loadWishlist() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const smallPhoneSize = Size(360, 640);
  const largePhoneSize = Size(412, 915);

  final testGroceryProduct = Product(
    id: 'prod_amul_milk',
    name: 'Amul Taaza Homogenised Toned Milk 1 L',
    slug: 'amul-taaza-milk-1l',
    description: 'Fresh and nutritious toned milk',
    price: 68.0,
    mrp: 74.0,
    discount: 8,
    stock: 25,
    unit: '1 L',
    categoryId: 'dairy-breakfast',
    isAvailable: true,
    tags: ['milk', 'dairy', 'veg', 'bestseller'],
    minStock: 5,
    costPrice: 60.0,
    isFlashDeal: false,
    isTopPick: true,
    isBestSeller: true,
    sortOrder: 1,
    createdAt: DateTime.now(),
  );

  final testFoodProduct = Product(
    id: 'prod_cafe_pizza',
    name: 'Paneer Makhani Cheese Burst Pizza (Regular)',
    slug: 'paneer-makhani-pizza',
    description: 'Delicious hot pizza with fresh paneer',
    price: 249.0,
    mrp: 299.0,
    discount: 16,
    stock: 50,
    unit: 'Serves 1-2',
    categoryId: 'restaurant-food',
    restaurantId: 'REST-102',
    isAvailable: true,
    tags: ['pizza', 'veg', 'bogo', 'cheese'],
    minStock: 0,
    costPrice: 180.0,
    isFlashDeal: false,
    isTopPick: false,
    isBestSeller: true,
    sortOrder: 2,
    createdAt: DateTime.now(),
  );

  group('Responsive Layouts & Overflow Regression Tests', () {
    testWidgets('ProductCard renders without overflow on small mobile (360x640)', (tester) async {
      await tester.binding.setSurfaceSize(smallPhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final emptyCart = Cart(
        id: 'test_cart',
        userId: 'u1',
        items: [],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeSettingsProvider.overrideWith((ref) => Future.value(const StoreSettings())),
            cartProvider.overrideWith((ref) => FakeCartNotifier(emptyCart)),
            wishlistProvider.overrideWith((ref) => FakeWishlistNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  child: ProductCard(product: testGroceryProduct),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Small screen ProductCard should have zero layout overflows');
      expect(find.text('₹68'), findsOneWidget);
      expect(find.text('ADD'), findsOneWidget);
    });

    testWidgets('ProductCard renders food with badges without overflow on large display (412x915)', (tester) async {
      await tester.binding.setSurfaceSize(largePhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final emptyCart = Cart(
        id: 'test_cart',
        userId: 'u1',
        items: [],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeSettingsProvider.overrideWith((ref) => Future.value(const StoreSettings())),
            cartProvider.overrideWith((ref) => FakeCartNotifier(emptyCart)),
            wishlistProvider.overrideWith((ref) => FakeWishlistNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  child: ProductCard(product: testFoodProduct),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Large screen ProductCard should have zero layout overflows');
      expect(find.text('₹249'), findsOneWidget);
      expect(find.text('ADD'), findsOneWidget);
    });

    testWidgets('DeliveryModeHeader adapts to 360w without overflow in both Grocery and Cafe modes', (tester) async {
      await tester.binding.setSurfaceSize(smallPhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool mode = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryModeHeader(
              isGrocerySelected: mode,
              onModeChanged: (val) => mode = val,
              activeLocationTitle: 'Ghatampur Center, Kanpur',
              activeLocationSubtitle: 'Delivering to Home in 10-15 mins',
              onLocationTap: () {},
              onSearchTap: () {},
              onVoiceSearchTap: () {},
              onNotificationsTap: () {},
              currentSearchPlaceholder: 'Search "milk, butter, snacks"',
              unreadNotificationsCount: 2,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'DeliveryModeHeader should not overflow on 360w screen');
      expect(find.text('Ghatampur Center, Kanpur'), findsOneWidget);
    });

    testWidgets('FloatingCartBar displays cleanly without overflow when items are in cart', (tester) async {
      await tester.binding.setSurfaceSize(smallPhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final activeCart = Cart(
        id: 'cart_1',
        userId: 'u1',
        items: [
          CartItem(
            id: 'item_1',
            cartId: 'cart_1',
            productId: testGroceryProduct.id,
            product: testGroceryProduct,
            quantity: 2,
          ),
        ],
        couponDiscount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartProvider.overrideWith((ref) => FakeCartNotifier(activeCart)),
            deliveryTierProvider.overrideWithValue(const DeliveryTierInfo(
              distanceKm: 1.2,
              deliveryFee: 0.0,
              baseFee: 20.0,
              freeDeliveryThreshold: 100.0,
              isServiceable: true,
              tierName: 'Zone 1',
              freeDeliveryLabel: 'Free Delivery',
              feeDescription: 'Zero delivery fee applied',
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  FloatingCartBar(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'FloatingCartBar should render with zero layout overflows');
      expect(find.text('View Cart'), findsOneWidget);
    });
  });
}
