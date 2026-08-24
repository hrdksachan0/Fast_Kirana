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
  static const double maxDeliveryRadiusKm = 15.0; // FastKirana delivery zone radius

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
}
