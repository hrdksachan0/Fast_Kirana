import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cart.dart';
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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(String productId, int quantity) async {
    await repository.addItem(userId, productId, quantity);
    await loadCart();
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    await repository.updateItem(itemId, quantity);
    await loadCart();
  }

  Future<void> removeItem(String itemId) async {
    await repository.removeItem(itemId);
    await loadCart();
  }

  Future<void> applyCoupon(String code) async {
    await repository.applyCoupon(code);
    await loadCart();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  return CartNotifier(
    ref.read(cartRepoProvider),
    'user_placeholder', // Replace with actual user ID
  );
});