import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart.dart';
import '../data/models/product.dart';
import '../data/repositories/cart_repository.dart';
import '../core/network/api_client.dart';
import '../core/utils/restaurant_utils.dart';

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

  /// Check if adding this product causes a conflict with dishes already in cart from another restaurant.
  /// Returns the name of the conflicting restaurant if conflict exists, otherwise null.
  String? checkRestaurantConflict(Product product) {
    // 1. Grocery items can mix freely with anything
    if (!isCafeProduct(product)) {
      return null;
    }

    final currentCart = state.value;
    if (currentCart == null || currentCart.items.isEmpty) {
      return null;
    }

    final newOutlet = getOutletName(product);

    // 2. Look for any existing restaurant items
    for (final item in currentCart.items) {
      if (isCafeProduct(item.product)) {
        final existOutlet = getOutletName(item.product);
        if (newOutlet != existOutlet) {
          return existOutlet;
        }
      }
    }

    return null;
  }

  /// Get current restaurant name from items in cart, if any
  String? get currentRestaurantName {
    final currentCart = state.value;
    if (currentCart == null) return null;
    final restaurantItem = currentCart.items.cast<CartItem?>().firstWhere(
      (i) => i != null && isCafeProduct(i.product),
      orElse: () => null,
    );
    if (restaurantItem != null) {
      return getOutletName(restaurantItem.product);
    }
    return null;
  }

  /// Get number of grocery items in cart
  int get groceryItemsCount {
    final currentCart = state.value;
    if (currentCart == null) return 0;
    return currentCart.items.where((i) => !isCafeProduct(i.product)).fold(0, (sum, i) => sum + i.quantity);
  }

  /// Get number of restaurant dishes in cart
  int get restaurantItemsCount {
    final currentCart = state.value;
    if (currentCart == null) return 0;
    return currentCart.items.where((i) => isCafeProduct(i.product)).fold(0, (sum, i) => sum + i.quantity);
  }

  /// Add real Product to cart with instant UI update
  /// Add real Product to cart with instant UI update
  /// Returns true if added successfully, false if exceeds available stock.
  bool addProduct(Product product, [int quantity = 1, String? selectedVariant]) {
    final currentCart = state.value ?? _buildCartFromItems([]);
    final items = List<CartItem>.from(currentCart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    final maxStock = product.stock > 0 ? product.stock : 999;
    final currentQty = idx >= 0 ? items[idx].quantity : 0;
    final targetQty = currentQty + quantity;

    if (targetQty > maxStock) {
      return false; // Reached stock limit
    }

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id,
        cartId: item.cartId,
        productId: product.id,
        product: product,
        quantity: targetQty,
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
    state = AsyncValue.data(_buildCartFromItems(
      items,
      couponCode: currentCart.appliedCouponCode,
      discount: currentCart.couponDiscount,
    ));
    repository.saveLocalCart(items);
    repository.syncCart(items);
    return true;
  }

  /// Clear ONLY dishes from the previous restaurant — keep all grocery items intact!
  Future<void> clearRestaurantItems() async {
    final currentCart = state.value;
    if (currentCart == null) return;

    final groceryItems = currentCart.items.where((i) => !isCafeProduct(i.product)).toList();
    state = AsyncValue.data(_buildCartFromItems(
      groceryItems,
      couponCode: currentCart.appliedCouponCode,
      discount: currentCart.couponDiscount,
    ));
    await repository.saveLocalCart(groceryItems);
    repository.syncCart(groceryItems);
  }

  /// Atomically clear old restaurant items and add the new restaurant product
  Future<void> replaceRestaurantItemsWith(Product product, [int quantity = 1, String? selectedVariant]) async {
    final currentCart = state.value ?? _buildCartFromItems([]);
    // Keep only grocery items
    final items = currentCart.items.where((i) => !isCafeProduct(i.product)).toList();

    // Add new restaurant item
    items.add(CartItem(
      id: 'item_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      cartId: 'cart_active',
      productId: product.id,
      product: product,
      quantity: quantity,
      selectedVariant: selectedVariant,
    ));

    state = AsyncValue.data(_buildCartFromItems(
      items,
      couponCode: currentCart.appliedCouponCode,
      discount: currentCart.couponDiscount,
    ));
    await repository.saveLocalCart(items);
    repository.syncCart(items);
  }

  /// Increment product quantity (returns false if stock limit reached)
  bool increment(Product product) {
    return addProduct(product, 1);
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

      state = AsyncValue.data(_buildCartFromItems(
        items,
        couponCode: currentCart.appliedCouponCode,
        discount: currentCart.couponDiscount,
      ));
      await repository.saveLocalCart(items);
      repository.syncCart(items);
    }
  }

  /// Update item quantity directly
  bool updateQuantity(String productId, int quantity, [int? maxStock]) {
    if (quantity <= 0) {
      removeItem(productId);
      return true;
    } else {
      final currentCart = state.value;
      if (currentCart == null) return false;
      final items = List<CartItem>.from(currentCart.items);
      final idx = items.indexWhere((i) => i.productId == productId || i.id == productId || i.product.id == productId);
      if (idx >= 0) {
        final item = items[idx];
        final effectiveStock = maxStock ?? (item.product.stock > 0 ? item.product.stock : 999);
        if (quantity > effectiveStock) {
          return false;
        }
        items[idx] = CartItem(
          id: item.id,
          cartId: item.cartId,
          productId: item.productId,
          product: item.product,
          quantity: quantity,
          selectedVariant: item.selectedVariant,
        );
        state = AsyncValue.data(_buildCartFromItems(
          items,
          couponCode: currentCart.appliedCouponCode,
          discount: currentCart.couponDiscount,
        ));
        repository.saveLocalCart(items);
        repository.syncCart(items);
        return true;
      }
      return false;
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String productId) async {
    final currentCart = state.value;
    if (currentCart == null) return;

    final items = currentCart.items.where((i) => i.productId != productId && i.id != productId && i.product.id != productId).toList();
    state = AsyncValue.data(_buildCartFromItems(
      items,
      couponCode: currentCart.appliedCouponCode,
      discount: currentCart.couponDiscount,
    ));
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
