import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/store_hub.dart';
import 'store_hub_provider.dart';
import 'product_provider.dart';
import 'restaurant_provider.dart';

enum HubStatus {
  serviceable,
  comingSoon,
  outsideZone,
}

class HubAvailabilityInfo {
  final StoreHub hub;
  final double distanceKm;
  final bool isServiceable;
  final int groceryCount;
  final int restaurantCount;
  final HubStatus status;

  const HubAvailabilityInfo({
    required this.hub,
    required this.distanceKm,
    required this.isServiceable,
    required this.groceryCount,
    required this.restaurantCount,
    required this.status,
  });

  bool get isComingSoon => status == HubStatus.comingSoon;
  bool get isOutsideZone => status == HubStatus.outsideZone;
  bool get isServiceableWithItems => status == HubStatus.serviceable;

  bool get hasGrocery => groceryCount > 0;
  bool get hasRestaurants => restaurantCount > 0;
  bool get isHybridFoodOnly => isServiceable && groceryCount == 0 && restaurantCount > 0;
  bool get isHybridGroceryOnly => isServiceable && groceryCount > 0 && restaurantCount == 0;
}

final hubAvailabilityProvider = Provider<HubAvailabilityInfo>((ref) {
  final nearestResult = ref.watch(nearestHubResultProvider);
  final hub = nearestResult.hub;
  final isServiceable = nearestResult.isServiceable;
  final distanceKm = nearestResult.distanceKm;

  // 1. Outside all active delivery zones
  if (!isServiceable) {
    return HubAvailabilityInfo(
      hub: hub,
      distanceKm: distanceKm,
      isServiceable: false,
      groceryCount: 0,
      restaurantCount: 0,
      status: HubStatus.outsideZone,
    );
  }

  // 2. Inside zone: evaluate live grocery and restaurant counts
  final catalogAsync = ref.watch(homeProductCatalogProvider);
  final restaurantsAsync = ref.watch(homeRestaurantsProvider);

  final groceryCount = catalogAsync.valueOrNull?.length ?? 0;
  final restaurantCount = restaurantsAsync.valueOrNull?.length ?? 0;

  // While initially loading catalog, avoid flashing Coming Soon prematurely
  final isCatalogLoading = catalogAsync.isLoading && catalogAsync.valueOrNull == null;
  final isRestaurantsLoading = restaurantsAsync.isLoading && restaurantsAsync.valueOrNull == null;
  if (isCatalogLoading || isRestaurantsLoading) {
    return HubAvailabilityInfo(
      hub: hub,
      distanceKm: distanceKm,
      isServiceable: true,
      groceryCount: 1, // graceful interim placeholder
      restaurantCount: 1,
      status: HubStatus.serviceable,
    );
  }

  // If inside zone but currently zero grocery products and zero restaurants in this hub
  final isComingSoon = groceryCount == 0 && restaurantCount == 0;

  return HubAvailabilityInfo(
    hub: hub,
    distanceKm: distanceKm,
    isServiceable: true,
    groceryCount: groceryCount,
    restaurantCount: restaurantCount,
    status: isComingSoon ? HubStatus.comingSoon : HubStatus.serviceable,
  );
});
