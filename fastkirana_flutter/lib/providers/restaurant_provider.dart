import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/restaurant.dart';
import '../data/models/product.dart';
import '../data/repositories/restaurant_repository.dart';

import 'package:geolocator/geolocator.dart';
import '../core/config/app_config.dart';
import '../providers/address_provider.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(ref.watch(dioProvider));
});

final selectedCuisineProvider = StateProvider<String>((ref) => 'all');
final pureVegFilterProvider = StateProvider<bool>((ref) => false);
final offersFilterProvider = StateProvider<bool>((ref) => false);
final ratingFilterProvider = StateProvider<bool>((ref) => false);
final restaurantSearchQueryProvider = StateProvider<String>((ref) => '');

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurants();
});

/// Helper to calculate distance between user's current selected address and a restaurant
double getRestaurantDistanceKm(Restaurant r, double userLat, double userLng) {
  final restLat = r.lat ?? AppConfig.darkstoreLat;
  final restLng = r.lng ?? AppConfig.darkstoreLng;
  final distanceMeters = Geolocator.distanceBetween(userLat, userLng, restLat, restLng);
  return distanceMeters / 1000.0;
}

/// Dynamic restaurant list for Home Screen, sorted nearest-first based on customer's active location
final homeRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final address = ref.watch(selectedAddressProvider);

  return restaurantsAsync.whenData((restaurants) {
    final list = List<Restaurant>.from(restaurants);
    final userLat = (address?.latitude != null && address!.latitude != 0.0)
        ? address.latitude!
        : AppConfig.darkstoreLat;
    final userLng = (address?.longitude != null && address!.longitude != 0.0)
        ? address.longitude!
        : AppConfig.darkstoreLng;

    list.sort((a, b) {
      // Open restaurants first
      if (a.isOpen != b.isOpen) {
        return a.isOpen ? -1 : 1;
      }
      // Nearest distance first
      final distA = getRestaurantDistanceKm(a, userLat, userLng);
      final distB = getRestaurantDistanceKm(b, userLat, userLng);
      return distA.compareTo(distB);
    });

    return list;
  });
});

final filteredRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final cuisine = ref.watch(selectedCuisineProvider);
  final pureVeg = ref.watch(pureVegFilterProvider);
  final offersOnly = ref.watch(offersFilterProvider);
  final ratingOnly = ref.watch(ratingFilterProvider);
  final search = ref.watch(restaurantSearchQueryProvider).toLowerCase().trim();
  final address = ref.watch(selectedAddressProvider);

  return restaurantsAsync.when(
    data: (restaurants) {
      final filtered = restaurants.where((r) {
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

      // Sort nearest-first by customer's location
      final userLat = (address?.latitude != null && address!.latitude != 0.0)
          ? address.latitude!
          : AppConfig.darkstoreLat;
      final userLng = (address?.longitude != null && address!.longitude != 0.0)
          ? address.longitude!
          : AppConfig.darkstoreLng;

      filtered.sort((a, b) {
        if (a.isOpen != b.isOpen) {
          return a.isOpen ? -1 : 1;
        }
        final distA = getRestaurantDistanceKm(a, userLat, userLng);
        final distB = getRestaurantDistanceKm(b, userLat, userLng);
        return distA.compareTo(distB);
      });

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final restaurantMenuProvider = FutureProvider.family<List<Product>, String>((ref, restaurantId) async {
  ref.keepAlive();
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurantMenu(restaurantId);
});

final restaurantReviewsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, restaurantId) async {
  ref.keepAlive();
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurantReviews(restaurantId);
});
