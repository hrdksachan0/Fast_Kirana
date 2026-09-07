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

// ─── Mixins ────────────────────────────────────────────────────────────────

/// Shared cart builder and initial load logic.
mixin _CartBuilder on StateNotifier<AsyncValue<Cart>> {
  Cart buildCart(List<CartItem> items, {String? couponCode, double discount = 0.0}) {
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

  Future<void> loadCart(CartRepository repo) async {
    try {
      final localItems = await repo.getLocalCart();
      if (localItems.isNotEmpty) {
        state = AsyncValue.data(buildCart(localItems));
      } else {
        state = AsyncValue.data(buildCart([]));
      }
      try {
        final serverCart = await repo.getCart();
        if (serverCart.items.isNotEmpty) {
          state = AsyncValue.data(serverCart);
          await repo.saveLocalCart(serverCart.items);
        }
      } catch (e, st) { LoggerService.error('CartProvider: background cart sync failed', e, st); }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Read-only queries on the current cart state.
mixin _CartQueries on StateNotifier<AsyncValue<Cart>> {
  Cart? get _cart => state.value;

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
}

/// Conflict resolution: clear or swap restaurant items.
mixin _CartConflictResolution on StateNotifier<AsyncValue<Cart>> {
  Future<void> clearRestaurantItems(CartRepository repo) async {
    final cart = _currentCart;
    if (cart == null) return;
    final groceryItems = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    _setState(groceryItems, cart);
    await repo.saveLocalCart(groceryItems);
    repo.syncCart(groceryItems);
  }

  Future<void> replaceRestaurantItemsWith(CartRepository repo, Product product, {int quantity = 1, String? selectedVariant}) async {
    final cart = _currentCart ?? _emptyCart;
    final items = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    items.add(_newCartItem(product, quantity, selectedVariant));
    _setState(items, cart);
    await repo.saveLocalCart(items);
    repo.syncCart(items);
  }

  Future<void> showConflictAndReplace(BuildContext context, WidgetRef ref, Product product) async {
    final repo = ref.read(cartRepoProvider);
    CartConflictDialog.show(
      context,
      product: product,
      existingOutletName: currentRestaurantName ?? '',
      groceryItemsCount: groceryItemsCount,
      onConfirm: () => replaceRestaurantItemsWith(repo, product, quantity: 1),
    );
  }
}

/// Item CRUD: add, increment, decrement, remove, update, clear.
mixin _CartCrud on StateNotifier<AsyncValue<Cart>> {
  Cart? get _currentCart;
  Cart get _emptyCart;

  void _setState(List<CartItem> items, Cart oldCart) {
    state = AsyncValue.data(_buildCartFromItems_(items, couponCode: oldCart.appliedCouponCode, discount: oldCart.couponDiscount));
  }

  Cart _buildCartFromItems_(List<CartItem> items, {String? couponCode, double discount = 0.0}) {
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

  bool addProduct(CartRepository repo, Product product, [int quantity = 1, String? selectedVariant]) {
    final cart = _currentCart ?? _emptyCart;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    final maxStock = product.stock > 0 ? product.stock : 999;
    final currentQty = idx >= 0 ? items[idx].quantity : 0;
    final targetQty = currentQty + quantity;

    if (targetQty > maxStock) return false;

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id, cartId: item.cartId, productId: product.id, product: product,
        quantity: targetQty, selectedVariant: selectedVariant ?? item.selectedVariant,
      );
    } else {
      items.add(_newCartItem(product, quantity, selectedVariant));
    }

    state = AsyncValue.data(_buildCartFromItems_(items, couponCode: cart.appliedCouponCode, discount: cart.couponDiscount));
    repo.saveLocalCart(items);
    repo.syncCart(items);
    return true;
  }

  Future<void> increment(CartRepository repo, Product product) async {
    final cart = _currentCart;
    if (cart == null) return;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id, cartId: item.cartId, productId: item.productId, product: item.product,
        quantity: item.quantity + 1, selectedVariant: item.selectedVariant,
      );
      _setState(items, cart);
      await repo.saveLocalCart(items);
      repo.syncCart(items);
    } else {
      items.add(_newCartItem(product, 1, null));
      _setState(items, cart);
      await repo.saveLocalCart(items);
      repo.syncCart(items);
    }
  }

  Future<void> decrement(CartRepository repo, String productId) async {
    final cart = _currentCart;
    if (cart == null) return;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == productId || i.product.id == productId);

    if (idx >= 0) {
      final item = items[idx];
      if (item.quantity <= 1) {
        items.removeAt(idx);
      } else {
        items[idx] = CartItem(
          id: item.id, cartId: item.cartId, productId: item.productId, product: item.product,
          quantity: item.quantity - 1, selectedVariant: item.selectedVariant,
        );
      }
      _setState(items, cart);
      await repo.saveLocalCart(items);
      repo.syncCart(items);
    }
  }

  bool updateQuantity(CartRepository repo, String productId, int quantity, [int? maxStock]) {
    if (quantity <= 0) {
      removeItem(repo, productId);
      return true;
    }
    final cart = _currentCart;
    if (cart == null) return false;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == productId || i.id == productId || i.product.id == productId);
    if (idx >= 0) {
      final item = items[idx];
      final effectiveStock = maxStock ?? (item.product.stock > 0 ? item.product.stock : 999);
      if (quantity > effectiveStock) return false;
      items[idx] = CartItem(
        id: item.id, cartId: item.cartId, productId: item.productId, product: item.product,
        quantity: quantity, selectedVariant: item.selectedVariant,
      );
      _setState(items, cart);
      repo.saveLocalCart(items);
      repo.syncCart(items);
      return true;
    }
    return false;
  }

  Future<void> removeItem(CartRepository repo, String productId) async {
    final cart = _currentCart;
    if (cart == null) return;
    final items = cart.items.where((i) => i.productId != productId && i.id != productId && i.product.id != productId).toList();
    _setState(items, cart);
    await repo.saveLocalCart(items);
    repo.syncCart(items);
  }

  Future<void> clearCart(CartRepository repo) async {
    state = AsyncValue.data(_emptyCart);
    await repo.saveLocalCart([]);
    repo.clearCart();
  }

  Future<void> syncPending(CartRepository repo) async {
    await repo.syncPendingCartIfNeeded();
  }
}

// ─── CartNotifier ──────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<AsyncValue<Cart>> with _CartBuilder, _CartQueries, _CartConflictResolution, _CartCrud {
  final CartRepository repository;

  CartNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCart(repository);
  }

  @override
  Cart? get _currentCart => state.value;

  @override
  Cart get _emptyCart => buildCart([]);

  /// Backward-compatible wrapper used by AddToCartButton
  Future<void> addItem(String productId, int quantity) async {
    final cart = state.value;
    if (cart != null) {
      final existing = cart.items.cast<CartItem?>().firstWhere((i) => i?.productId == productId, orElse: () => null);
      if (existing != null) {
        updateQuantity(repository, productId, existing.quantity + quantity);
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
