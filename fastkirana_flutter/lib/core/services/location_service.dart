import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../data/models/address.dart';
import '../../data/models/product.dart';
import '../../data/models/store_hub.dart';
import '../../data/models/store_settings.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/location_drift_sheet.dart';

class LocationDetails {
  final double latitude;
  final double longitude;
  final String houseNo;
  final String street;
  final String area;
  final String city;
  final String pincode;
  final String formattedAddress;
  final double distanceKm;
  final bool isServiceable;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.houseNo,
    required this.street,
    required this.area,
    required this.city,
    required this.pincode,
    required this.formattedAddress,
    required this.distanceKm,
    required this.isServiceable,
  });
}

/// Real-Time Dynamic Delivery ETA & Surge Metadata
class DynamicEtaInfo {
  final int minMinutes;
  final int maxMinutes;
  final String displayLabel;
  final bool isRushHour;
  final bool isHighDemand;
  final double surgeMultiplier;

  const DynamicEtaInfo({
    required this.minMinutes,
    required this.maxMinutes,
    required this.displayLabel,
    this.isRushHour = false,
    this.isHighDemand = false,
    this.surgeMultiplier = 1.0,
  });
}

class DeliveryTierInfo {
  final double distanceKm;
  final double deliveryFee;
  final double baseFee;
  final double surgeFee;
  final double freeDeliveryThreshold;
  final bool isServiceable;
  final String tierName;
  final String freeDeliveryLabel;
  final String feeDescription;
  final DynamicEtaInfo eta;

  const DeliveryTierInfo({
    required this.distanceKm,
    required this.deliveryFee,
    required this.baseFee,
    this.surgeFee = 0.0,
    required this.freeDeliveryThreshold,
    required this.isServiceable,
    required this.tierName,
    required this.freeDeliveryLabel,
    required this.feeDescription,
    this.eta = const DynamicEtaInfo(minMinutes: 10, maxMinutes: 15, displayLabel: '10-15 mins'),
  });
}

class LocationService {
  static const double maxDeliveryRadiusKm = 5.0; // FastKirana delivery zone radius (Strict 5.0 km)

  /// Calculate distance in km from an origin location (e.g. restaurant or darkstore hub) to customer coordinates.
  /// If [originLat] and [originLng] are provided (e.g. from a restaurant), measures from that point.
  /// Otherwise defaults to the active darkstore hub coords in AppConfig.
  static double getDistanceKm(
    double lat,
    double lng, {
    double? originLat,
    double? originLng,
  }) {
    final startLat = (originLat != null && originLat != 0.0) ? originLat : AppConfig.darkstoreLat;
    final startLng = (originLng != null && originLng != 0.0) ? originLng : AppConfig.darkstoreLng;

    final distanceMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      lat,
      lng,
    );
    return distanceMeters / 1000.0;
  }

  /// Real-Time Dynamic ETA & Elastic Surge Pricing Algorithm
  /// Combines:
  /// - Base prep time: 5 mins (Grocery) or 15 mins (Restaurant/Cafe)
  /// - Real-time darkstore queue factor: (pendingOrders / activePickers) * 1.2 mins
  /// - Urban transit velocity: 18 km/h with lunch/dinner traffic coefficient (1.0x to 1.35x)
  static DynamicEtaInfo calculateDynamicEta({
    required double distanceKm,
    int pendingOrders = 0,
    int activePickers = 2,
    bool isRestaurant = false,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final hour = currentTime.hour;

    // Peak rush periods in Indian cities: Lunch (12:30 - 14:30) & Dinner (19:30 - 22:30)
    final isLunchRush = hour >= 12 && hour <= 14;
    final isDinnerRush = hour >= 19 && hour <= 22;
    final isRushHour = isLunchRush || isDinnerRush;

    final trafficMultiplier = isDinnerRush ? 1.35 : (isLunchRush ? 1.20 : 1.0);

    // 1. Preparation Time
    final basePrepMinutes = isRestaurant ? 15 : 5;

    // 2. Queue Waiting Delay
    final pickers = activePickers > 0 ? activePickers : 2;
    final queueDelayMinutes = ((pendingOrders / pickers) * 1.2).ceil();

    // 3. Transit Travel Time (Average 18 km/h two-wheeler speed in urban traffic)
    final rawTransitMinutes = (distanceKm / 18.0) * 60.0 * trafficMultiplier;
    final transitMinutes = max(3, rawTransitMinutes.ceil());

    // 4. Total ETA calculation
    final totalExpectedMinutes = basePrepMinutes + queueDelayMinutes + transitMinutes;
    final minMinutes = max(8, (totalExpectedMinutes * 0.85).round());
    final maxMinutes = max(minMinutes + 4, (totalExpectedMinutes * 1.15).round());

    final isHighDemand = pendingOrders > 15 || isDinnerRush;
    final surgeMultiplier = isHighDemand ? 1.25 : 1.0;

    String label;
    if (minMinutes <= 10) {
      label = '8-12 mins';
    } else if (isHighDemand) {
      label = '$minMinutes-$maxMinutes mins (High Demand)';
    } else {
      label = '$minMinutes-$maxMinutes mins';
    }

    return DynamicEtaInfo(
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      displayLabel: label,
      isRushHour: isRushHour,
      isHighDemand: isHighDemand,
      surgeMultiplier: surgeMultiplier,
    );
  }

  /// Distance-tiered delivery fee & free delivery threshold calculation:
  /// • Tier 1 (0 to 2 km): dynamic fee (default ₹25) + dynamic surge fee — FREE Delivery on orders above threshold (default ₹199)
  /// • Tier 2 (2 to 3 km): dynamic fee (default ₹35) + dynamic surge fee — FREE Delivery on orders above threshold (default ₹299)
  /// • Tier 3 (3 to max radius km): dynamic fee (default ₹50) + dynamic surge fee — FREE Delivery on orders above threshold (default ₹399)
  /// • Outside hub delivery radius: Not serviceable.
  static DeliveryTierInfo getDeliveryTier(
    double distanceKm,
    double subtotal, {
    double? maxRadius,
    StoreSettings? settings,
    String? storeName,
    int pendingOrders = 0,
    bool isRestaurant = false,
  }) {
    final dynamicEta = calculateDynamicEta(
      distanceKm: distanceKm,
      pendingOrders: pendingOrders,
      isRestaurant: isRestaurant,
    );

    final radius = maxRadius ?? settings?.deliveryRadiusKm ?? maxDeliveryRadiusKm;
    final baseSurgeFee = settings?.surgeCharge ?? 0.0;
    final surgeFee = (baseSurgeFee * dynamicEta.surgeMultiplier).roundToDouble();

    final tier1Fee = settings?.deliveryFeeTier1 ?? 25.0;
    final tier1Threshold = settings?.deliveryThresholdTier1 ?? 199.0;

    final tier2Fee = settings?.deliveryFeeTier2 ?? 35.0;
    final tier2Threshold = settings?.deliveryThresholdTier2 ?? 299.0;

    final tier3Fee = settings?.deliveryFeeTier3 ?? 50.0;
    final tier3Threshold = settings?.deliveryThresholdTier3 ?? 399.0;

    final resolvedStoreName = (storeName?.isNotEmpty == true)
        ? storeName!
        : (settings?.storeName.isNotEmpty == true
            ? settings!.storeName
            : (settings?.trustCityName.isNotEmpty == true ? settings!.trustCityName : ''));

    final cityLabel = resolvedStoreName.isNotEmpty ? '$resolvedStoreName ' : '';

    if (distanceKm > radius) {
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: 0.0,
        baseFee: 0.0,
        surgeFee: 0.0,
        freeDeliveryThreshold: tier3Threshold + 100.0,
        isServiceable: false,
        tierName: 'Outside ${radius.toInt()} km (Out of Zone)',
        freeDeliveryLabel: 'Outside delivery zone',
        feeDescription: 'Delivery is currently limited to a maximum of ${radius.toStringAsFixed(1)} km from our central hub.',
        eta: dynamicEta,
      );
    }

    if (distanceKm <= 2.0) {
      final isFree = subtotal >= tier1Threshold;
      final totalFee = isFree ? 0.0 : (tier1Fee + surgeFee);
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: totalFee,
        baseFee: tier1Fee,
        surgeFee: surgeFee,
        freeDeliveryThreshold: tier1Threshold,
        isServiceable: true,
        tierName: '0 to 2 km (${cityLabel}Zone)',
        freeDeliveryLabel: 'FREE Delivery above ₹${tier1Threshold.toInt()}',
        feeDescription: surgeFee > 0
            ? '₹${totalFee.toInt()} fee (₹${tier1Fee.toInt()} + ₹${surgeFee.toInt()} surge, FREE above ₹${tier1Threshold.toInt()})'
            : '₹${tier1Fee.toInt()} fee (FREE above ₹${tier1Threshold.toInt()})',
        eta: dynamicEta,
      );
    } else if (distanceKm <= 3.0) {
      final isFree = subtotal >= tier2Threshold;
      final totalFee = isFree ? 0.0 : (tier2Fee + surgeFee);
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: totalFee,
        baseFee: tier2Fee,
        surgeFee: surgeFee,
        freeDeliveryThreshold: tier2Threshold,
        isServiceable: true,
        tierName: '2 to 3 km (Suburban Area)',
        freeDeliveryLabel: 'FREE Delivery above ₹${tier2Threshold.toInt()}',
        feeDescription: surgeFee > 0
            ? '₹${totalFee.toInt()} fee (₹${tier2Fee.toInt()} + ₹${surgeFee.toInt()} surge, FREE above ₹${tier2Threshold.toInt()})'
            : '₹${tier2Fee.toInt()} fee (FREE above ₹${tier2Threshold.toInt()})',
        eta: dynamicEta,
      );
    } else if (distanceKm <= 5.0) {
      final isFree = subtotal >= tier3Threshold;
      final totalFee = isFree ? 0.0 : (tier3Fee + surgeFee);
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: totalFee,
        baseFee: tier3Fee,
        surgeFee: surgeFee,
        freeDeliveryThreshold: tier3Threshold,
        isServiceable: true,
        tierName: '3 to 5 km (Extended Area)',
        freeDeliveryLabel: 'FREE Delivery above ₹${tier3Threshold.toInt()}',
        feeDescription: surgeFee > 0
            ? '₹${totalFee.toInt()} fee (₹${tier3Fee.toInt()} + ₹${surgeFee.toInt()} surge, FREE above ₹${tier3Threshold.toInt()})'
            : '₹${tier3Fee.toInt()} fee (FREE above ₹${tier3Threshold.toInt()})',
        eta: dynamicEta,
      );
    } else if (distanceKm <= radius) {
      final extraKm = (distanceKm - 5.0).ceil();
      final perKmFee = settings?.deliveryFeePerKmBeyond5km ?? 10.0;
      final longDistanceFee = tier3Fee + (extraKm * perKmFee);
      final longDistanceThreshold = tier3Threshold + (extraKm * 50.0);
      final isFree = subtotal >= longDistanceThreshold;
      final totalFee = isFree ? 0.0 : (longDistanceFee + surgeFee);
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: totalFee,
        baseFee: longDistanceFee,
        surgeFee: surgeFee,
        freeDeliveryThreshold: longDistanceThreshold,
        isServiceable: true,
        tierName: '5 to ${radius.toInt()} km (Long Distance)',
        freeDeliveryLabel: 'FREE Delivery above ₹${longDistanceThreshold.toInt()}',
        feeDescription: surgeFee > 0
            ? '₹${totalFee.toInt()} fee (₹${longDistanceFee.toInt()} + ₹${surgeFee.toInt()} surge, FREE above ₹${longDistanceThreshold.toInt()})'
            : '₹${longDistanceFee.toInt()} fee (FREE above ₹${longDistanceThreshold.toInt()})',
        eta: dynamicEta,
      );
    } else {
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: 0.0,
        baseFee: 0.0,
        surgeFee: 0.0,
        freeDeliveryThreshold: tier3Threshold + 100.0,
        isServiceable: false,
        tierName: 'Outside ${radius.toInt()} km (Out of Zone)',
        freeDeliveryLabel: 'Outside delivery zone',
        feeDescription: 'Delivery is currently limited to a maximum of ${radius.toStringAsFixed(1)} km from our central hub.',
        eta: dynamicEta,
      );
    }
  }

  /// Convenience: calculate tier directly from an Address object with optional custom origin (e.g. restaurant)
  static DeliveryTierInfo getTierForAddress(
    Address? address,
    double subtotal, {
    double? originLat,
    double? originLng,
    double? maxRadius,
    StoreSettings? settings,
    String? storeName,
    int pendingOrders = 0,
    bool isRestaurant = false,
  }) {
    if (address == null || address.latitude == null || address.longitude == null || (address.latitude == 0.0 && address.longitude == 0.0)) {
      return getDeliveryTier(1.0, subtotal, maxRadius: maxRadius, settings: settings, storeName: storeName, pendingOrders: pendingOrders, isRestaurant: isRestaurant);
    }
    final dist = getDistanceKm(
      address.latitude!,
      address.longitude!,
      originLat: originLat,
      originLng: originLng,
    );
    return getDeliveryTier(dist, subtotal, maxRadius: maxRadius, settings: settings, storeName: storeName, pendingOrders: pendingOrders, isRestaurant: isRestaurant);
  }

  /// Check & request location permission, then fetch current GPS location
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to structured address details
  static Future<LocationDetails> getAddressFromCoordinates(
    double lat,
    double lng, {
    StoreHub? nearestHub,
  }) async {
    // Resolve nearest hub if not explicitly passed
    StoreHub hub = nearestHub ?? StoreHub.defaultGhatampur;
    if (nearestHub == null) {
      double minD = double.infinity;
      for (final h in StoreHub.defaultHubs) {
        final d = Geolocator.distanceBetween(h.latitude, h.longitude, lat, lng) / 1000.0;
        if (d < minD) {
          minD = d;
          hub = h;
        }
      }
    }

    final hubCity = hub.city;
    String houseNo = '';
    String street = '';
    String area = hubCity;
    String city = hubCity;
    String pincode = hub.city.toLowerCase().contains('akbarpur') ? '224122' : '209206';
    String formatted = '$hubCity Market, UP';

    try {
      if (!kIsWeb) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          houseNo = place.subThoroughfare ?? place.name ?? '';
          street = place.thoroughfare ?? '';
          area = place.subLocality?.isNotEmpty == true ? place.subLocality! : (place.locality ?? hubCity);
          city = place.locality ?? place.administrativeArea ?? hubCity;
          pincode = place.postalCode ?? (hub.city.toLowerCase().contains('akbarpur') ? '224122' : '209206');

          final parts = [
            if (houseNo.isNotEmpty) houseNo,
            if (street.isNotEmpty) street,
            if (area.isNotEmpty) area,
            if (city.isNotEmpty) city,
            if (pincode.isNotEmpty) pincode,
          ];
          formatted = parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }

    final distanceKm = getDistanceKm(lat, lng, originLat: hub.latitude, originLng: hub.longitude);
    final isServiceable = distanceKm <= hub.deliveryRadiusKm;

    return LocationDetails(
      latitude: lat,
      longitude: lng,
      houseNo: houseNo,
      street: street,
      area: area,
      city: city,
      pincode: pincode,
      formattedAddress: formatted,
      distanceKm: distanceKm,
      isServiceable: isServiceable,
    );
  }

  /// Convenience method to get full current location details in one call
  static Future<LocationDetails?> fetchCurrentLocationDetails({StoreHub? nearestHub}) async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    return await getAddressFromCoordinates(pos.latitude, pos.longitude, nearestHub: nearestHub);
  }

  /// Background bootstrap method on app launch (Blinkit / Zepto style)
  /// Checks if location permission is granted / requestable and automatically
  /// updates selectedAddressProvider with live GPS coords if no custom address was selected.
  static Future<void> bootstrapUserLocation(WidgetRef ref) async {
    try {
      // 1. If user already has an active chosen address or saved addresses, don't override
      final currentAddress = ref.read(selectedAddressProvider);
      if (currentAddress != null &&
          currentAddress.id != 'hub_active_default' &&
          !currentAddress.id.startsWith('addr_bootstrap_gps_')) {
        return;
      }

      // Check if location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return;

      // Check permission state without triggering aggressive blocking prompts if permanently denied
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Fetch position with 6-second quick timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );

      final details = await getAddressFromCoordinates(position.latitude, position.longitude);

      // Create a transient address representing user's current GPS location
      final gpsAddress = Address(
        id: 'addr_bootstrap_gps_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current',
        label: 'Current Location',
        houseNo: details.houseNo,
        street: details.street,
        area: details.area,
        city: details.city,
        pincode: details.pincode,
        latitude: details.latitude,
        longitude: details.longitude,
        isDefault: true,
      );

      ref.read(selectedAddressProvider.notifier).state = gpsAddress;
      debugPrint('📍 Auto-GPS Bootstrap completed: ${details.area}, ${details.city} (${position.latitude}, ${position.longitude})');
    } catch (e) {
      debugPrint('Auto-GPS Bootstrap notice: $e');
    }
  }

  static DateTime? _lastDriftCheckTime;

  /// Zepto / Blinkit Silent Background Location Drift Detection
  /// Silently pings GPS coordinate on app open/resume (100% free hardware GPS).
  /// If customer is > 600m away from their selected address, shows a friendly prompt.
  static Future<void> checkLocationDriftAndPrompt(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Cooldown throttle (at most once every 10 minutes to avoid spamming)
      final now = DateTime.now();
      if (_lastDriftCheckTime != null && now.difference(_lastDriftCheckTime!).inMinutes < 10) {
        return;
      }
      _lastDriftCheckTime = now;

      // 2. Check location services availability
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      // 3. Fast silent GPS fetch (3.5s timeout)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      final selectedAddress = ref.read(selectedAddressProvider);
      if (selectedAddress?.latitude == null || selectedAddress?.longitude == null) {
        return;
      }

      // 4. Calculate drift distance in km
      final driftMeters = Geolocator.distanceBetween(
        selectedAddress!.latitude!,
        selectedAddress.longitude!,
        position.latitude,
        position.longitude,
      );
      final driftKm = driftMeters / 1000.0;

      // 5. If user is within 600m of saved address, they are in the same area -> DO NOTHING
      if (driftKm < 0.6) {
        return;
      }

      // 6. User drifted > 600m -> reverse geocode and show subtle bottom sheet
      final newDetails = await getAddressFromCoordinates(position.latitude, position.longitude);

      if (context.mounted) {
        await LocationDriftSheet.show(
          context,
          newGpsDetails: newDetails,
          previousAddress: selectedAddress,
          driftDistanceKm: driftKm,
        );
      }
    } catch (e) {
      debugPrint('Silent Location Drift check notice: $e');
    }
  }
}

/// Provider that calculates the dynamic distance tier for the currently selected address & cart
final deliveryTierProvider = Provider<DeliveryTierInfo>((ref) {
  final cart = ref.watch(cartProvider);
  final subtotal = cart.valueOrNull?.subtotal ?? 0.0;
  final items = cart.valueOrNull?.items ?? [];

  // Check if cart contains restaurant food items
  RestaurantInfo? restaurant;
  for (final item in items) {
    if (item.product.restaurant != null &&
        item.product.restaurant!.lat != null &&
        item.product.restaurant!.lng != null) {
      restaurant = item.product.restaurant;
      break;
    }
  }

  final settings = ref.watch(storeSettingsProvider).valueOrNull;

  if (restaurant != null && restaurant.lat != null && restaurant.lng != null) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final userLat = selectedAddress?.latitude;
    final userLng = selectedAddress?.longitude;

    if (userLat != null && userLng != null && (userLat != 0.0 || userLng != 0.0)) {
      final dist = LocationService.getDistanceKm(
        userLat,
        userLng,
        originLat: restaurant.lat,
        originLng: restaurant.lng,
      );
      return LocationService.getDeliveryTier(
        dist,
        subtotal,
        maxRadius: restaurant.deliveryRadiusKm,
        settings: settings,
        storeName: restaurant.name,
      );
    } else {
      return LocationService.getDeliveryTier(
        1.0,
        subtotal,
        maxRadius: restaurant.deliveryRadiusKm,
        settings: settings,
        storeName: restaurant.name,
      );
    }
  }

  final nearestResult = ref.watch(nearestHubResultProvider);
  final radius = nearestResult.hub.deliveryRadiusKm;
  return LocationService.getDeliveryTier(
    nearestResult.distanceKm,
    subtotal,
    maxRadius: radius,
    settings: settings,
    storeName: nearestResult.hub.name,
  );
});
