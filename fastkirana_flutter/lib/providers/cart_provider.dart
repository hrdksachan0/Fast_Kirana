import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart.dart';
import '../data/models/product.dart';
import '../data/repositories/cart_repository.dart';
import '../core/network/api_client.dart';

final cartRepoProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(dioProvider));
});

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  final CartRepository repository;
  final String userId;

  CartNotifier(this.repository, this.userId) : super(const AsyncValue.loading()) {
    loadCart();
  }

  Future<void> loadCart() async {
    try {
      final cart = await repository.getCart(userId);
      state = AsyncValue.data(cart);
    } catch (e) {
      final localItems = await repository.getLocalCart();
      state = AsyncValue.data(_createMockCart(localItems));
    }
  }

  Future<void> addItem(String productId, int quantity) async {
    try {
      await repository.addItem(userId, productId, quantity);
      await loadCart();
    } catch (_) {
      final currentCart = state.value ?? _createMockCart([]);
      final items = List<CartItem>.from(currentCart.items);
      final existingIndex = items.indexWhere((i) => i.productId == productId);

      if (existingIndex >= 0) {
        final item = items[existingIndex];
        items[existingIndex] = CartItem(
          id: item.id,
          cartId: item.cartId,
          productId: item.productId,
          product: item.product,
          quantity: item.quantity + quantity,
        );
      } else {
        items.add(CartItem(
          id: 'item_$productId',
          cartId: 'cart_local',
          productId: productId,
          product: Product(
            id: productId,
            name: 'FastKirana Item',
            slug: 'item-$productId',
            categoryId: 'cat_demo',
            price: 49.0,
            mrp: 70.0,
            discount: 30.0,
            imageUrl: null,
            unit: '1 unit',
            stock: 10,
            isAvailable: true,
            tags: const [],
            minStock: 1,
            costPrice: 35.0,
            isFlashDeal: false,
            isTopPick: true,
            isBestSeller: false,
            sortOrder: 0,
            createdAt: DateTime.now(),
          ),
          quantity: quantity,
        ));
      }
      await repository.saveLocalCart(items);
      state = AsyncValue.data(_createMockCart(items));
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    try {
      await repository.updateItem(itemId, quantity);
      await loadCart();
    } catch (_) {
      final currentCart = state.value ?? _createMockCart([]);
      final items = List<CartItem>.from(currentCart.items);
      final idx = items.indexWhere((i) => i.id == itemId);
      if (idx >= 0) {
        if (quantity <= 0) {
          items.removeAt(idx);
        } else {
          final item = items[idx];
          items[idx] = CartItem(
            id: item.id,
            cartId: item.cartId,
            productId: item.productId,
            product: item.product,
            quantity: quantity,
          );
        }
      }
      await repository.saveLocalCart(items);
      state = AsyncValue.data(_createMockCart(items));
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await repository.removeItem(itemId);
      await loadCart();
    } catch (_) {
      final currentCart = state.value ?? _createMockCart([]);
      final items = List<CartItem>.from(currentCart.items)..removeWhere((i) => i.id == itemId);
      await repository.saveLocalCart(items);
      state = AsyncValue.data(_createMockCart(items));
    }
  }

  Future<void> applyCoupon(String code) async {
    try {
      await repository.applyCoupon(code);
      await loadCart();
    } catch (_) {
      final currentCart = state.value ?? _createMockCart([]);
      state = AsyncValue.data(Cart(
        id: currentCart.id,
        userId: currentCart.userId,
        items: currentCart.items,
        appliedCouponCode: code,
        couponDiscount: 50.0,
        createdAt: currentCart.createdAt,
        updatedAt: DateTime.now(),
      ));
    }
  }

  Cart _createMockCart(List<CartItem> items) {
    return Cart(
      id: 'cart_local',
      userId: userId,
      items: items,
      couponDiscount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  return CartNotifier(
    ref.read(cartRepoProvider),
    'user_placeholder',
  );
});