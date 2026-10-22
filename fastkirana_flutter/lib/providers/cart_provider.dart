import 'dart:async';
import 'package:flutter/services.dart';
import 'package:fastminute_flutter/core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart.dart';
import '../data/models/product.dart';
import '../data/repositories/cart_repository.dart';
import '../core/network/api_client.dart';
import '../core/config/app_config.dart';
import '../core/utils/restaurant_utils.dart';
import '../core/utils/app_connectivity.dart';

// ─── Providers ─────────────────────────────────────────────────────────────

final cartRepoProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(dioProvider));
});

// ─── CartNotifier ──────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  final CartRepository repository;

  int _cartVersion = 0;
  int _lastClearVersion = 0;
  Timer? _debounceSyncTimer;

  int get cartVersion => _cartVersion;
  int get lastClearVersion => _lastClearVersion;

  CartNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadCart();
  }

  Cart? get _cart => state.value;

  Cart _buildCart(List<CartItem> items, {String? couponCode, double discount = 0.0, String? hubId}) {
    final effectiveHub = hubId ?? _cart?.hubId ?? (AppConfig.darkstoreId.isNotEmpty ? AppConfig.darkstoreId : null);
    return Cart(
      id: 'cart_active',
      userId: 'user_active',
      items: items,
      appliedCouponCode: couponCode,
      couponDiscount: discount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hubId: effectiveHub,
    );
  }

  Cart _emptyCart({String? hubId}) => _buildCart([], hubId: hubId);

  void _setState(List<CartItem> items, Cart? oldCart, {String? hubId}) {
    state = AsyncValue.data(
      _buildCart(
        items,
        couponCode: oldCart?.appliedCouponCode,
        discount: oldCart?.couponDiscount ?? 0.0,
        hubId: hubId ?? oldCart?.hubId,
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

  int _lastAcknowledgedVersion = 0;
  int get lastAcknowledgedVersion => _lastAcknowledgedVersion;
  bool _isSyncing = false;
  List<CartItem>? _latestPendingItems;

  /// Monotonic sequence sync queue:
  /// Immediately increments local cart version and debounces server sync by 300ms.
  /// Serializes whole-cart writes so older requests never overwrite newer snapshots.
  void _scheduleDebouncedSync(List<CartItem> items) async {
    _debounceSyncTimer?.cancel();
    _cartVersion++;
    _latestPendingItems = items;
    final capturedKey = await repository.getPendingSyncKeyForCurrentScope();
    await repository.setPendingSync(true, targetKey: capturedKey);

    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(milliseconds: 300), () async {
      await _flushPendingSync(capturedKey);
    });
  }

  Future<void> _flushPendingSync([String? capturedKey]) async {
    if (_isSyncing) {
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    final itemsToSync = _latestPendingItems;
    final versionToSync = _cartVersion;
    if (itemsToSync == null) return;
    if (_lastAcknowledgedVersion >= versionToSync) return;

    _isSyncing = true;
    final targetKey = capturedKey ?? await repository.getPendingSyncKeyForCurrentScope();
    try {
      final isClearIntent = itemsToSync.isEmpty && _lastClearVersion == versionToSync;
      final success = await repository.syncCart(
        itemsToSync,
        targetSyncKey: targetKey,
        clearPendingOnSuccess: false,
        isExplicitClear: isClearIntent,
      );
      if (success) {
        _lastAcknowledgedVersion = versionToSync;
        if (_cartVersion == versionToSync) {
          await repository.setPendingSync(false, targetKey: targetKey);
        } else {
          await repository.setPendingSync(true, targetKey: targetKey);
        }
      }
    } catch (e, st) {
      LoggerService.error('CartProvider: serialized sync failed for version $versionToSync', e, st);
    } finally {
      _isSyncing = false;
      // Only flush if newer edits occurred while this attempt was in flight
      if (_cartVersion > versionToSync && _latestPendingItems != null) {
        _flushPendingSync();
      }
    }
  }


  @override
  void dispose() {
    _debounceSyncTimer?.cancel();
    super.dispose();
  }


  /// Checks if the cart is bound to a different darkstore hub than the target hubId.
  String? checkHubConflict(String newHubId) {
    final cart = _cart;
    if (cart == null || cart.items.isEmpty) return null;
    final existingHub = cart.hubId;
    if (existingHub != null && existingHub.isNotEmpty && existingHub != newHubId) {
      final hasGrocery = cart.items.any((i) => !isCafeProduct(i.product));
      if (hasGrocery) return existingHub;
    }
    return null;
  }

  /// Revalidates cart items when switching to a new store hub.
  Future<void> revalidateCartForHub(String newHubId) async {
    final cart = _cart;
    if (cart == null || cart.items.isEmpty) return;

    state = AsyncValue.data(
      cart.copyWith(hubId: newHubId),
    );
    await repository.saveLocalCart(cart.items);
  }

  // ─── Queries ───────────────────────────────────────────────────────────────

  int getQuantity(String productId) {
    final cart = _cart;
    if (cart == null) return 0;
    return cart.items.where((i) {
      return i.productId == productId ||
          i.product.id == productId ||
          i.productId.startsWith('${productId}_') ||
          i.product.id.startsWith('${productId}_');
    }).fold(0, (sum, i) => sum + i.quantity);
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
    final initialVersion = _cartVersion;
    try {
      final localItems = await r.getLocalCart();
      // If user performed in-memory mutations while getLocalCart was awaiting, merge without losing either
      if (_cartVersion > initialVersion || _latestPendingItems != null) {
        // If user explicitly cleared the cart, preserve clear intent without resurrecting items
        if (_lastClearVersion > initialVersion || (_latestPendingItems != null && _latestPendingItems!.isEmpty)) {
          return;
        }
        if (localItems.isNotEmpty) {
          final currentCart = _cart;
          final currentItems = currentCart?.items ?? [];
          final merged = List<CartItem>.from(currentItems);
          bool hasChanges = false;
          for (final loc in localItems) {
            final locVar = loc.selectedVariant != null && loc.selectedVariant!.isNotEmpty ? loc.selectedVariant : null;
            final existingIdx = merged.indexWhere((cur) {
              final curVar = cur.selectedVariant != null && cur.selectedVariant!.isNotEmpty ? cur.selectedVariant : null;
              final sameBase = cur.productId == loc.productId || cur.product.id == loc.productId || cur.product.id == loc.product.id;
              return sameBase && curVar == locVar;
            });
            if (existingIdx >= 0) {
              final existing = merged[existingIdx];
              if (existing.id == loc.id) {
                // Exact same item snapshot already in memory (e.g. written by this instance before getLocalCart resolved)
                continue;
              }
              final combinedQty = existing.quantity + loc.quantity;
              merged[existingIdx] = CartItem(
                id: existing.id,
                cartId: existing.cartId,
                productId: existing.productId,
                product: existing.product,
                quantity: combinedQty,
                selectedVariant: existing.selectedVariant,
                notes: existing.notes ?? loc.notes,
              );
              hasChanges = true;
            } else {
              merged.add(loc);
              hasChanges = true;
            }
          }
          if (hasChanges) {
  
            _cartVersion++;
            state = AsyncValue.data(_buildCart(merged));
            await r.saveLocalCart(merged);
            _scheduleDebouncedSync(merged);
          }
        }
        return;
      }
      if (localItems.isNotEmpty) {
        state = AsyncValue.data(_buildCart(localItems));
      } else {
        state = AsyncValue.data(_emptyCart());
      }

      final hasPending = await r.hasPendingSync();
      if (hasPending) {
        if (_cartVersion > initialVersion || _latestPendingItems != null) {
          return;
        }
        // Local has unsynced offline edits! Reconcile through the versioned queue rather than unversioned sync
        try {
          final targetKey = await r.getPendingSyncKeyForCurrentScope();
          if (_cartVersion > initialVersion || _latestPendingItems != null) {
            return;
          }

          if (localItems.isNotEmpty) {
  
            _cartVersion++;
            _latestPendingItems = localItems;
            await _flushPendingSync(targetKey);
  
            return;
          } else {
            // Local items are empty - reset pending sync flag to avoid wiping out server cart
            await r.setPendingSync(false, targetKey: targetKey);
          }

        } catch (e, st) {
          LoggerService.error('CartProvider: background reconciliation of pending offline cart failed', e, st);
        }
        return;
      }

      try {
        final serverCart = await r.getCart();
        // Guard against startup race: only hydrate from server if local has no items and no mutations occurred
        if (localItems.isEmpty && serverCart.items.isNotEmpty && (_latestPendingItems == null || _latestPendingItems!.isEmpty)) {
          state = AsyncValue.data(serverCart);
          await r.saveLocalCart(serverCart.items);
        }
      } catch (e, st) {
        LoggerService.error('CartProvider: background cart sync failed', e, st);
      }
    } catch (e, st) {
      if (_cartVersion == initialVersion && _latestPendingItems == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }


  bool addProduct(Product product, [int quantity = 1, String? selectedVariant]) {
    HapticFeedback.lightImpact();
    final cart = _cart ?? _emptyCart();
    final items = List<CartItem>.from(cart.items);
    final targetVariantKey = selectedVariant != null && selectedVariant.isNotEmpty ? selectedVariant : null;
    final idx = items.indexWhere((i) {
      final sameBase = i.productId == product.id || i.product.id == product.id;
      final sameVariant = (i.selectedVariant == null && targetVariantKey == null) ||
          (i.selectedVariant == targetVariantKey);
      return sameBase && sameVariant;
    });

    final maxStock = product.getStockForVariant(targetVariantKey);
    final currentQty = idx >= 0 ? items[idx].quantity : 0;
    final targetQty = currentQty + quantity;

    if (maxStock <= 0 || targetQty > maxStock) return false;

    if (idx >= 0) {
      final item = items[idx];
      items[idx] = CartItem(
        id: item.id,
        cartId: item.cartId,
        productId: item.productId,
        product: product,
        quantity: targetQty,
        selectedVariant: targetVariantKey ?? item.selectedVariant,
      );
    } else {
      items.add(_newCartItem(product, quantity, targetVariantKey));
    }

    _setState(items, cart);
    repository.saveLocalCart(items);
    _scheduleDebouncedSync(items);
    return true;
  }

  Future<void> increment(Product product) async {
    final cart = _cart;
    if (cart == null || !product.isAvailable) return;
    final items = List<CartItem>.from(cart.items);
    final idx = items.indexWhere((i) => i.productId == product.id || i.product.id == product.id);

    if (idx >= 0) {
      final item = items[idx];
      final maxStock = product.getStockForVariant(item.selectedVariant);
      if (maxStock > 0 && item.quantity >= maxStock) {
        HapticFeedback.heavyImpact();
        return;
      }
      HapticFeedback.selectionClick();
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
      _scheduleDebouncedSync(items);
    } else {
      if (product.stock <= 0) return;
      HapticFeedback.selectionClick();
      items.add(_newCartItem(product, 1, null));
      _setState(items, cart);
      await repository.saveLocalCart(items);
      _scheduleDebouncedSync(items);
    }
  }

  Future<void> decrement(String productId) async {
    HapticFeedback.selectionClick();
    final cart = _cart;
    if (cart == null) return;
    final items = List<CartItem>.from(cart.items);
    int idx = items.indexWhere((i) => i.productId == productId || i.id == productId || i.product.id == productId);

    // Fallback 1: If base product ID was passed, find its variant item
    if (idx < 0) {
      idx = items.indexWhere((i) => i.productId.startsWith('${productId}_') || i.product.id.startsWith('${productId}_'));
    }
    // Fallback 2: If variant product ID was passed, find its base item
    if (idx < 0 && productId.contains('_')) {
      final baseId = productId.split('_').first;
      idx = items.indexWhere((i) => i.productId == baseId || i.product.id == baseId);
    }

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
      _scheduleDebouncedSync(items);
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
      final itemMaxStock = item.product.getStockForVariant(item.selectedVariant);
      final effectiveStock = maxStock ?? itemMaxStock;
      if (effectiveStock <= 0 || quantity > effectiveStock) return false;
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
      _scheduleDebouncedSync(items);
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
    _scheduleDebouncedSync(items);
  }

  Future<void> clearCart({String? orderId}) async {
    final backupCart = _cart;
    _debounceSyncTimer?.cancel();
    _cartVersion++;
    _lastClearVersion = _cartVersion;
    _latestPendingItems = [];
    state = AsyncValue.data(_emptyCart());
    try {
      final saved = await repository.saveLocalCart([], appliedOrderId: orderId);
      if (!saved) {
        throw Exception('Failed to persist cleared cart');
      }
      final targetKey = await repository.getPendingSyncKeyForCurrentScope();
      await repository.setPendingSync(true, targetKey: targetKey);
      await _flushPendingSync(targetKey);
    } catch (e) {
      if (backupCart != null) {
        _cartVersion++;
        _latestPendingItems = backupCart.items;
        state = AsyncValue.data(backupCart);
      }
      rethrow;
    }
  }

  /// Removes only items matching the accepted checkout draft from the cart,
  /// preserving any newer items added to the cart while payment was in-flight.
  Future<void> removeDraftItems(List<Map<String, dynamic>> draftItems, {String? orderId}) async {
    final cart = _cart;
    if (cart == null || cart.items.isEmpty) return;

    final currentItems = List<CartItem>.from(cart.items);
    for (final draftItem in draftItems) {
      final pId = draftItem['productId']?.toString();
      final draftQty = (draftItem['quantity'] as num?)?.toInt() ?? 1;
      final variant = draftItem['selectedVariant']?.toString();

      final idx = currentItems.indexWhere((i) {
        final matchesProduct = i.productId == pId || i.product.id == pId;
        if (!matchesProduct) return false;
        if (variant != null && variant.isNotEmpty) {
          return i.selectedVariant == variant ||
              (i.selectedVariant == null && (variant == i.product.unit || variant.isEmpty));
        }
        return i.selectedVariant == null ||
            (i.product.unit.isNotEmpty && i.selectedVariant == i.product.unit);
      });

      if (idx != -1) {
        final existing = currentItems[idx];
        if (existing.quantity <= draftQty) {
          currentItems.removeAt(idx);
        } else {
          currentItems[idx] = existing.copyWith(quantity: existing.quantity - draftQty);
        }
      }
    }

    final backupItems = List<CartItem>.from(cart.items);
    _debounceSyncTimer?.cancel();
    _cartVersion++;
    _latestPendingItems = currentItems;
    _setState(currentItems, cart);
    try {
      final saved = await repository.saveLocalCart(currentItems, appliedOrderId: orderId);
      if (!saved) {
        throw Exception('Failed to persist cart with applied delta');
      }
      final targetKey = await repository.getPendingSyncKeyForCurrentScope();
      await repository.setPendingSync(true, targetKey: targetKey);
      await _flushPendingSync(targetKey);
    } catch (e) {
      _cartVersion++;
      _latestPendingItems = backupItems;
      _setState(backupItems, cart);
      rethrow;
    }
  }

  Future<void> clearRestaurantItems() async {
    final cart = _cart;
    if (cart == null) return;
    final groceryItems = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    _setState(groceryItems, cart);
    await repository.saveLocalCart(groceryItems);
    _scheduleDebouncedSync(groceryItems);
  }

  Future<void> replaceRestaurantItemsWith(Product product, [int quantity = 1, String? selectedVariant]) async {
    final maxStock = product.getStockForVariant(selectedVariant);
    if (maxStock <= 0) return;
    final cart = _cart ?? _emptyCart();
    final items = cart.items.where((i) => !isCafeProduct(i.product)).toList();
    final effectiveQty = quantity > maxStock ? maxStock : quantity;
    items.add(_newCartItem(product, effectiveQty, selectedVariant));
    _setState(items, cart);
    await repository.saveLocalCart(items);
    _scheduleDebouncedSync(items);
  }

  Future<void> syncPending([CartRepository? repo]) async {
    _debounceSyncTimer?.cancel();
    final r = repo ?? repository;
    final pending = await r.hasPendingSync();
    if (!pending) return;

    final localItems = await r.getLocalCart();
    _cartVersion++;
    _latestPendingItems = localItems;
    final targetKey = await r.getPendingSyncKeyForCurrentScope();
    await _flushPendingSync(targetKey);
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
