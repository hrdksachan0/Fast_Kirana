import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product.dart';
import '../data/repositories/wishlist_repository.dart';
import '../core/network/api_client.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.read(dioProvider));
});

class WishlistNotifier extends StateNotifier<List<Product>> {
  final WishlistRepository _repo;

  WishlistNotifier(this._repo) : super([]) {
    loadWishlist();
  }

  Future<void> loadWishlist() async {
    try {
      final items = await _repo.getWishlist();
      state = items;
    } catch (e, st) { LoggerService.error('WishlistProvider: loadWishlist failed', e, st); }
  }

  bool isInWishlist(String productId) {
    return state.any((p) => p.id == productId);
  }

  Future<void> toggleWishlist(Product product) async {
    final exists = isInWishlist(product.id);
    if (exists) {
      state = state.where((p) => p.id != product.id).toList();
      try {
        await _repo.removeFromWishlist(product.id);
      } catch (e) { LoggerService.error('WishlistProvider: removeFromWishlist failed', e);
        // Rollback
        state = [...state, product];
      }
    } else {
      state = [...state, product];
      try {
        await _repo.addToWishlist(product.id);
      } catch (e) { LoggerService.error('WishlistProvider: addToWishlist failed', e);
        // Rollback
        state = state.where((p) => p.id != product.id).toList();
      }
    }
  }
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<Product>>((ref) {
  final repo = ref.watch(wishlistRepositoryProvider);
  return WishlistNotifier(repo);
});
