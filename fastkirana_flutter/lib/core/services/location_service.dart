import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/app_config.dart';

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

class LocationService {
  static const double maxDeliveryRadiusKm = 5.0; // FastKirana delivery zone radius (Strict 5.0 km)

  /// Distance-tiered delivery fee & free delivery threshold calculation
  /// • 0 to 2 km: ₹25 fee — FREE above ₹199
  /// • 2 to 3 km: ₹35 fee — FREE above ₹299
  /// • 3 to 5 km: ₹50 fee — FREE above ₹399
  /// • > 5 km: Unserviceable
  static ({double deliveryFee, double freeDeliveryThreshold, bool isServiceable, String tierName}) getDeliveryTier(double distanceKm, double subtotal) {
    if (distanceKm <= 2.0) {
      final fee = subtotal >= 199.0 ? 0.0 : 25.0;
      return (deliveryFee: fee, freeDeliveryThreshold: 199.0, isServiceable: true, tierName: '0 to 2 km (Local Zone)');
    } else if (distanceKm <= 3.0) {
      final fee = subtotal >= 299.0 ? 0.0 : 35.0;
      return (deliveryFee: fee, freeDeliveryThreshold: 299.0, isServiceable: true, tierName: '2 to 3 km (Suburban Area)');
    } else if (distanceKm <= 5.0) {
      final fee = subtotal >= 399.0 ? 0.0 : 50.0;
      return (deliveryFee: fee, freeDeliveryThreshold: 399.0, isServiceable: true, tierName: '3 to 5 km (Extended Area)');
    } else {
      return (deliveryFee: 0.0, freeDeliveryThreshold: 499.0, isServiceable: false, tierName: 'Outside 5.0 km (Out of Zone)');
    }
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
  static Future<LocationDetails> getAddressFromCoordinates(double lat, double lng) async {
    String houseNo = '';
    String street = '';
    String area = 'Ghatampur';
    String city = 'Kanpur Nagar';
    String pincode = '209206';
    String formatted = 'Ghatampur Market, UP 209206';

    try {
      if (!kIsWeb) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          houseNo = place.subThoroughfare ?? place.name ?? '';
          street = place.thoroughfare ?? '';
          area = place.subLocality?.isNotEmpty == true ? place.subLocality! : (place.locality ?? 'Ghatampur');
          city = place.locality ?? place.administrativeArea ?? 'Kanpur Nagar';
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

    final distanceMeters = Geolocator.distanceBetween(
      AppConfig.darkstoreLat,
      AppConfig.darkstoreLng,
      lat,
      lng,
    );
    final distanceKm = distanceMeters / 1000.0;
    final isServiceable = distanceKm <= maxDeliveryRadiusKm;

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
  static Future<LocationDetails?> fetchCurrentLocationDetails() async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    return await getAddressFromCoordinates(pos.latitude, pos.longitude);
  }
}
