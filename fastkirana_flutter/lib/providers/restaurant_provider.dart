import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/restaurant.dart';
import '../data/models/product.dart';
import '../data/repositories/restaurant_repository.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(ref.watch(dioProvider));
});

final selectedCuisineProvider = StateProvider<String>((ref) => 'all');
final pureVegFilterProvider = StateProvider<bool>((ref) => false);
final offersFilterProvider = StateProvider<bool>((ref) => false);
final ratingFilterProvider = StateProvider<bool>((ref) => false);
final restaurantSearchQueryProvider = StateProvider<String>((ref) => '');

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurants();
});

final filteredRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final cuisine = ref.watch(selectedCuisineProvider);
  final pureVeg = ref.watch(pureVegFilterProvider);
  final offersOnly = ref.watch(offersFilterProvider);
  final ratingOnly = ref.watch(ratingFilterProvider);
  final search = ref.watch(restaurantSearchQueryProvider).toLowerCase().trim();

  return restaurantsAsync.when(
    data: (restaurants) {
      return restaurants.where((r) {
        // Cuisine filter
        if (cuisine != 'all' && cuisine != 'specials') {
          final matchesCuisine = r.cuisineTags.any(
            (tag) => tag.toLowerCase().contains(cuisine.toLowerCase()),
          );
          if (!matchesCuisine) return false;
        }

        // Pure veg filter
        if (pureVeg && !r.isPureVeg) {
          return false;
        }

        // Offers filter
        if (offersOnly && (r.discountOffer == null || r.discountOffer!.isEmpty)) {
          return false;
        }

        // Rating filter (4.5+)
        if (ratingOnly && r.rating < 4.5) {
          return false;
        }

        // Search query filter
        if (search.isNotEmpty) {
          final matchesName = r.name.toLowerCase().contains(search);
          final matchesAddress = (r.address ?? '').toLowerCase().contains(search);
          final matchesTag = r.cuisineTags.any((t) => t.toLowerCase().contains(search));
          if (!matchesName && !matchesAddress && !matchesTag) return false;
        }

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final restaurantMenuProvider = FutureProvider.family<List<Product>, String>((ref, restaurantId) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurantMenu(restaurantId);
});
