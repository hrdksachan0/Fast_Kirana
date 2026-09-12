import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../data/models/address.dart';
import '../../data/models/product.dart';
import '../../data/models/store_hub.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_hub_provider.dart';

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

class DeliveryTierInfo {
  final double distanceKm;
  final double deliveryFee;
  final double baseFee;
  final double freeDeliveryThreshold;
  final bool isServiceable;
  final String tierName;
  final String freeDeliveryLabel;
  final String feeDescription;

  const DeliveryTierInfo({
    required this.distanceKm,
    required this.deliveryFee,
    required this.baseFee,
    required this.freeDeliveryThreshold,
    required this.isServiceable,
    required this.tierName,
    required this.freeDeliveryLabel,
    required this.feeDescription,
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

  /// Distance-tiered delivery fee & free delivery threshold calculation:
  /// • 0 to 2 km (Local Ghatampur): ₹25 delivery fee — FREE Delivery on orders above ₹199!
  /// • 2 to 3 km (Suburban Area): ₹35 delivery fee — FREE Delivery on orders above ₹299!
  /// • 3 to 5 km (Extended Area): ₹50 delivery fee — FREE Delivery on orders above ₹399!
  /// • Outside hub delivery radius: Not serviceable.
  ///
  /// If [hub] is provided, its [deliveryRadiusKm] determines the serviceability
  /// boundary. Otherwise falls back to [maxDeliveryRadiusKm].
  static DeliveryTierInfo getDeliveryTier(double distanceKm, double subtotal, {double? maxRadius}) {
    final radius = maxRadius ?? maxDeliveryRadiusKm;
    if (distanceKm <= 2.0) {
      final isFree = subtotal >= 199.0;
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: isFree ? 0.0 : 25.0,
        baseFee: 25.0,
        freeDeliveryThreshold: 199.0,
        isServiceable: true,
        tierName: '0 to 2 km (Local Ghatampur)',
        freeDeliveryLabel: 'FREE Delivery above ₹199',
        feeDescription: '₹25 fee (FREE above ₹199)',
      );
    } else if (distanceKm <= 3.0) {
      final isFree = subtotal >= 299.0;
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: isFree ? 0.0 : 35.0,
        baseFee: 35.0,
        freeDeliveryThreshold: 299.0,
        isServiceable: true,
        tierName: '2 to 3 km (Suburban Area)',
        freeDeliveryLabel: 'FREE Delivery above ₹299',
        feeDescription: '₹35 fee (FREE above ₹299)',
      );
    } else if (distanceKm <= radius) {
      final isFree = subtotal >= 399.0;
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: isFree ? 0.0 : 50.0,
        baseFee: 50.0,
        freeDeliveryThreshold: 399.0,
        isServiceable: true,
        tierName: '3 to ${radius.toInt()} km (Extended Area)',
        freeDeliveryLabel: 'FREE Delivery above ₹399',
        feeDescription: '₹50 fee (FREE above ₹399)',
      );
    } else {
      return DeliveryTierInfo(
        distanceKm: distanceKm,
        deliveryFee: 0.0,
        baseFee: 0.0,
        freeDeliveryThreshold: 499.0,
        isServiceable: false,
        tierName: 'Outside ${radius.toInt()} km (Out of Zone)',
        freeDeliveryLabel: 'Outside delivery zone',
        feeDescription: 'Delivery is currently limited to a maximum of ${radius.toStringAsFixed(1)} km from our central hub.',
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
  }) {
    if (address == null || address.latitude == null || address.longitude == null || (address.latitude == 0.0 && address.longitude == 0.0)) {
      return getDeliveryTier(1.0, subtotal, maxRadius: maxRadius);
    }
    final dist = getDistanceKm(
      address.latitude!,
      address.longitude!,
      originLat: originLat,
      originLng: originLng,
    );
    return getDeliveryTier(dist, subtotal, maxRadius: maxRadius);
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
    final hubCity = nearestHub?.city ?? 'Ghatampur';
    String houseNo = '';
    String street = '';
    String area = hubCity;
    String city = hubCity;
    String pincode = '209206';
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
          pincode = place.postalCode ?? '209206';

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

    final distanceKm = getDistanceKm(lat, lng);
    final isServiceable = distanceKm <= (nearestHub?.deliveryRadiusKm ?? maxDeliveryRadiusKm);

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
      return LocationService.getDeliveryTier(dist, subtotal, maxRadius: restaurant.deliveryRadiusKm);
    } else {
      return LocationService.getDeliveryTier(1.0, subtotal, maxRadius: restaurant.deliveryRadiusKm);
    }
  }

  final nearestResult = ref.watch(nearestHubResultProvider);
  final radius = nearestResult.hub.deliveryRadiusKm;
  return LocationService.getDeliveryTier(nearestResult.distanceKm, subtotal, maxRadius: radius);
});
