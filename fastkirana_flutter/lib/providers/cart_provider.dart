import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart.dart';
import '../data/models/product.dart';
import '../data/repositories/cart_repository.dart';
import '../core/network/api_client.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/app_connectivity.dart';

// ─── Providers ─────────────────────────────────────────────────────────────

final cartRepoProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(dioProvider));
});

// ─── CartNotifier ──────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  final CartRepository repository;

  CartNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCart();
  }

  Cart? get _cart => state.value;

  Cart _buildCart(List<CartItem> items, {String? couponCode, double discount = 0.0}) {
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

  Cart _emptyCart() => _buildCart([]);

  void _setState(List<CartItem> items, Cart? oldCart) {
    state = AsyncValue.data(
      _buildCart(
        items,
        couponCode: oldCart?.appliedCouponCode,
        discount: oldCart?.couponDiscount ?? 0.0,
      ),
    );
  }

  CartItem _newCartItem(Product product, int quantity, String? selectedVariant) {
    return CartItem(
      id: 'item_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      cartId: 'cart_active',
      productId: product.id,
      product: product,
      quantity: quantity,
      selectedVariant: selectedVariant,
    );
  }

  // ─── Queries ───────────────────────────────────────────────────────────────

  int getQuantity(String productId) {
    final cart = _cart;
    if (cart == null) return 0;
    final item = cart.items.cast<CartItem?>().firstWhere(
      (i) => i?.productId == productId || i?.product.id == productId,
      orElse: () => null,
    );
    return item?.quantity ?? 0;
  }

  String? checkRestaurantConflict(Product product) {
    if (!isCafeProduct(product)) return null;
    final cart = _cart;
    if (cart == null || cart.items.isEmpty) return null;
    final newOutlet = getOutletName(product);
    for (final item in cart.items) {
      if (isCafeProduct(item.product)) {
        final existOutlet = getOutletName(item.product);
        if (newOutlet != existOutlet) return existOutlet;
      }
    }
    return null;
  }

  String? get currentRestaurantName {
    final cart = _cart;
    if (cart == null) return null;
    final item = cart.items.cast<CartItem?>().firstWhere(
      (i) => i != null && isCafeProduct(i.product),
      orElse: () => null,
    );
    if (item != null) return getOutletName(item.product);
    return null;
  }

  int get groceryItemsCount {
    final cart = _cart;
    if (cart == null) return 0;
    return cart.items.where((i) => !isCafeProduct(i.product)).fold(0, (sum, i) => sum + i.quantity);
  }

  int get restaurantItemsCount {
    final cart = _cart;
    if (cart == null) return 0;
    return cart.items.where((i) => isCafeProduct(i.product)).fold(0, (sum, i) => sum + i.quantity);
  }

  // ─── Mutations ─────────────────────────────────────────────────────────────

  Future<void> loadCart([CartRepository? repo]) async {
    final r = repo ?? repository;
    try {
      final localItems = await r.getLocalCart();
      if (localItems.isNotEmpty) {
        state = AsyncValue.data(_buildCart(localItems));
      } else {
        state = AsyncValue.data(_emptyCart());
      }
      try {
        final serverCart = await r.getCart();
        if (serverCart.items.isNotEmpty) {
          state = AsyncValue.data(serverCart);
          await r.saveLocalCart(serverCart.items);
        }
      } catch (e, st) {
        LoggerService.error('CartProvider: background cart sync failed', e, st);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  bool addProduct(Product product, [int quantity = 1, String? selectedVariant]) {
    final cart = _cart ?? _emptyCart();
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    final maxStock = product.stock > 0 ? product.stock : 999;
    final currentQty = idx >= 0 ? items[idx].quantity : 0;
    final targetQty = currentQty + quantity;

    if (targetQty > maxStock) return false;

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
      items.add(_newCartItem(product, quantity, selectedVariant));
    }

    _setState(items, cart);
    repository.saveLocalCart(items);
    repository.syncCart(items);
    return true;
  }

  Future<void> increment(Product product) async {
    final cart = _cart;
    if (cart == null) return;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id,
        cartId: item.cartId,
        productId: item.productId,
        product: item.product,
        quantity: item.quantity + 1,
        selectedVariant: item.selectedVariant,
      );
      _setState(items, cart);
      await repository.saveLocalCart(items);
      repository.syncCart(items);
    } else {
      items.add(_newCartItem(product, 1, null));
      _setState(items, cart);
      await repository.saveLocalCart(items);
      repository.syncCart(items);
    }
  }

  Future<void> decrement(String productId) async {
    final cart = _cart;
    if (cart == null) return;
    final items = List<CartItem>.from(cart.items);
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
      _setState(items, cart);
      await repository.saveLocalCart(items);
      repository.syncCart(items);
    }
  }

  bool updateQuantity(String productId, int quantity, [int? maxStock]) {
    if (quantity <= 0) {
      removeItem(productId);
      return true;
    }
    final cart = _cart;
    if (cart == null) return false;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == productId || i.id == productId || i.product.id == productId);
    if (idx >= 0) {
      final item = items[idx];
      final effectiveStock = maxStock ?? (item.product.stock > 0 ? item.product.stock : 999);
      if (quantity > effectiveStock) return false;
      items[idx] = CartItem(
        id: item.id,
        cartId: item.cartId,
        productId: item.productId,
        product: item.product,
        quantity: quantity,
        selectedVariant: item.selectedVariant,
      );
      _setState(items, cart);
      repository.saveLocalCart(items);
      repository.syncCart(items);
      return true;
    }
    return false;
  }

  Future<void> removeItem(String productId) async {
    final cart = _cart;
    if (cart == null) return;
    final items = cart.items.where((i) => i.productId != productId && i.id != productId && i.product.id != productId).toList();
    _setState(items, cart);
    await repository.saveLocalCart(items);
    repository.syncCart(items);
  }

  Future<void> clearCart() async {
    state = AsyncValue.data(_emptyCart());
    await repository.saveLocalCart([]);
    repository.clearCart();
  }

  Future<void> clearRestaurantItems() async {
    final cart = _cart;
    if (cart == null) return;
    final groceryItems = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    _setState(groceryItems, cart);
    await repository.saveLocalCart(groceryItems);
    repository.syncCart(groceryItems);
  }

  Future<void> replaceRestaurantItemsWith(Product product, [int quantity = 1, String? selectedVariant]) async {
    final cart = _cart ?? _emptyCart();
    final items = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    items.add(_newCartItem(product, quantity, selectedVariant));
    _setState(items, cart);
    await repository.saveLocalCart(items);
    repository.syncCart(items);
  }

  Future<void> syncPending([CartRepository? repo]) async {
    final r = repo ?? repository;
    await r.syncPendingCartIfNeeded();
  }

  Future<void> syncPendingCart([CartRepository? repo]) => syncPending(repo);

  /// Backward-compatible wrapper used by AddToCartButton
  Future<void> addItem(String productId, int quantity) async {
    final cart = state.value;
    if (cart != null) {
      final existing = cart.items.cast<CartItem?>().firstWhere((i) => i?.productId == productId, orElse: () => null);
      if (existing != null) {
        updateQuantity(productId, existing.quantity + quantity);
      }
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  final repo = ref.watch(cartRepoProvider);
  final notifier = CartNotifier(repo);

  ref.listen<AppConnectivityObserver>(connectivityProvider, (previous, next) {
    if (next.isOnline) notifier.syncPending(repo);
  });

  return notifier;
});
