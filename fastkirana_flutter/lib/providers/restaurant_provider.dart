import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/restaurant.dart';
import '../data/models/product.dart';
import '../data/repositories/restaurant_repository.dart';

import 'package:geolocator/geolocator.dart';
import '../core/config/app_config.dart';
import '../core/utils/restaurant_utils.dart';
import '../providers/address_provider.dart';
import '../providers/store_settings_provider.dart';
import '../providers/store_hub_provider.dart';

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

/// Dynamic restaurant list for Home Screen, scoped to active city hub & sorted nearest-first
final homeRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final address = ref.watch(selectedAddressProvider);
  final settings = ref.watch(storeSettingsProvider).valueOrNull;
  final hub = ref.watch(currentStoreHubProvider);

  return restaurantsAsync.whenData((restaurants) {
    final hubCity = hub.city.toLowerCase().trim();
    // 1. City / Geo Scoped Filtering
    final list = restaurants.where((r) {
      if (r.city != null && r.city!.trim().isNotEmpty) {
        final rCity = r.city!.toLowerCase().trim();
        return rCity.contains(hubCity) || hubCity.contains(rCity);
      }
      if (r.lat != null && r.lng != null) {
        final dist = Geolocator.distanceBetween(hub.latitude, hub.longitude, r.lat!, r.lng!) / 1000.0;
        return dist <= 25.0;
      }
      return hubCity.contains('ghatampur');
    }).toList();

    final userLat = (address?.latitude != null && address!.latitude != 0.0)
        ? address.latitude!
        : hub.latitude;
    final userLng = (address?.longitude != null && address!.longitude != 0.0)
        ? address.longitude!
        : hub.longitude;

    list.sort((a, b) {
      // Open restaurants first
      final aOpen = RestaurantScheduleHelper.isRestaurantOpen(restaurant: a, storeSettings: settings);
      final bOpen = RestaurantScheduleHelper.isRestaurantOpen(restaurant: b, storeSettings: settings);
      if (aOpen != bOpen) {
        return aOpen ? -1 : 1;
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
  final settings = ref.watch(storeSettingsProvider).valueOrNull;
  final hub = ref.watch(currentStoreHubProvider);

  return restaurantsAsync.when(
    data: (restaurants) {
      final hubCity = hub.city.toLowerCase().trim();
      final filtered = restaurants.where((r) {
        // City / Geo Scoped Filtering
        if (r.city != null && r.city!.trim().isNotEmpty) {
          final rCity = r.city!.toLowerCase().trim();
          if (!rCity.contains(hubCity) && !hubCity.contains(rCity)) return false;
        } else if (!hubCity.contains('ghatampur')) {
          if (r.lat != null && r.lng != null) {
            final dist = Geolocator.distanceBetween(hub.latitude, hub.longitude, r.lat!, r.lng!) / 1000.0;
            if (dist > 25.0) return false;
          } else {
            return false;
          }
        }

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
        final aOpen = RestaurantScheduleHelper.isRestaurantOpen(restaurant: a, storeSettings: settings);
        final bOpen = RestaurantScheduleHelper.isRestaurantOpen(restaurant: b, storeSettings: settings);
        if (aOpen != bOpen) {
          return aOpen ? -1 : 1;
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

final restaurantAddonsProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getDarkstoreAddonRecommendations();
});
