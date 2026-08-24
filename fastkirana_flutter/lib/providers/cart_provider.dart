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

  CartNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCart();
  }

  Cart _buildCartFromItems(List<CartItem> items, {String? couponCode, double discount = 0.0}) {
    return Cart(
      id: 'cart_active',
      userId: 'user_active',
      items: items,
      appliedCouponCode: couponCode,
      couponDiscount: discount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> loadCart() async {
    try {
      final localItems = await repository.getLocalCart();
      if (localItems.isNotEmpty) {
        state = AsyncValue.data(_buildCartFromItems(localItems));
      } else {
        state = AsyncValue.data(_buildCartFromItems([]));
      }

      // Try background sync from server if connected
      try {
        final serverCart = await repository.getCart();
        if (serverCart.items.isNotEmpty) {
          state = AsyncValue.data(serverCart);
          await repository.saveLocalCart(serverCart.items);
        }
      } catch (_) {}
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  int getQuantity(String productId) {
    final cart = state.value;
    if (cart == null) return 0;
    final item = cart.items.cast<CartItem?>().firstWhere(
      (i) => i?.productId == productId || i?.product.id == productId,
      orElse: () => null,
    );
    return item?.quantity ?? 0;
  }

  /// Add real Product to cart with instant UI update
  Future<void> addProduct(Product product, [int quantity = 1, String? selectedVariant]) async {
    final currentCart = state.value ?? _buildCartFromItems([]);
    final items = List<CartItem>.from(currentCart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id,
        cartId: item.cartId,
        productId: product.id,
        product: product,
        quantity: item.quantity + quantity,
        selectedVariant: selectedVariant ?? item.selectedVariant,
      );
    } else {
      items.add(CartItem(
        id: 'item_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
        cartId: 'cart_active',
        productId: product.id,
        product: product,
        quantity: quantity,
        selectedVariant: selectedVariant,
      ));
    }

    // Instant optimistic state update
    state = AsyncValue.data(_buildCartFromItems(items));
    await repository.saveLocalCart(items);
    repository.syncCart(items);
  }

  /// Increment product quantity
  Future<void> increment(Product product) async {
    await addProduct(product, 1);
  }

  /// Decrement product quantity (removes when reaches 0)
  Future<void> decrement(String productId) async {
    final currentCart = state.value;
    if (currentCart == null) return;

    final items = List<CartItem>.from(currentCart.items);
    final idx = items.indexWhere((i) => i.productId == productId || i.product.id == productId);

    if (idx >= 0) {
      final item = items[idx];
      if (item.quantity <= 1) {
        items.removeAt(idx);
      } else {
        items[idx] = CartItem(
          id: item.id,
          cartId: item.cartId,
          productId: item.productId,
          product: item.product,
          quantity: item.quantity - 1,
          selectedVariant: item.selectedVariant,
        );
      }

      state = AsyncValue.data(_buildCartFromItems(items));
      await repository.saveLocalCart(items);
      repository.syncCart(items);
    }
  }

  /// Update item quantity directly
  Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(productId);
    } else {
      final currentCart = state.value;
      if (currentCart == null) return;
      final items = List<CartItem>.from(currentCart.items);
      final idx = items.indexWhere((i) => i.productId == productId || i.id == productId);
      if (idx >= 0) {
        final item = items[idx];
        items[idx] = CartItem(
          id: item.id,
          cartId: item.cartId,
          productId: item.productId,
          product: item.product,
          quantity: quantity,
          selectedVariant: item.selectedVariant,
        );
        state = AsyncValue.data(_buildCartFromItems(items));
        await repository.saveLocalCart(items);
        repository.syncCart(items);
      }
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String productId) async {
    final currentCart = state.value;
    if (currentCart == null) return;

    final items = currentCart.items.where((i) => i.productId != productId && i.id != productId && i.product.id != productId).toList();
    state = AsyncValue.data(_buildCartFromItems(items));
    await repository.saveLocalCart(items);
    repository.syncCart(items);
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    state = AsyncValue.data(_buildCartFromItems([]));
    await repository.saveLocalCart([]);
    repository.clearCart();
  }

  /// Backward compatible addItem
  Future<void> addItem(String productId, int quantity) async {
    // If only productId provided without Product model
    final currentCart = state.value;
    if (currentCart != null) {
      final existing = currentCart.items.cast<CartItem?>().firstWhere((i) => i?.productId == productId, orElse: () => null);
      if (existing != null) {
        await updateQuantity(productId, existing.quantity + quantity);
        return;
      }
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  final repo = ref.watch(cartRepoProvider);
  return CartNotifier(repo);
});
