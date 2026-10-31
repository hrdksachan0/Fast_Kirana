import 'dart:convert';
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



import 'package:google_fonts/google_fonts.dart';



import 'package:shared_preferences/shared_preferences.dart';



import '../utils/address_formatter.dart';



import '../../providers/auth_provider.dart';



import '../../providers/product_provider.dart';



import '../../providers/hub_availability_provider.dart';



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



  final StoreHub? nearestHub;



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



    this.nearestHub,



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
  static Address? _cachedAddress;
  static Address? get cachedAddress => _cachedAddress;

  static Future<void> loadCachedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_selected_address_json');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cachedAddress = Address.fromJson(map);
      }
    } catch (e) {
      debugPrint('Error loading cached address: $e');
    }
  }

  static Future<void> saveCachedAddress(Address addr) async {
    try {
      _cachedAddress = addr;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_selected_address_json', jsonEncode(addr.toJson()));
      await prefs.setBool('has_chosen_location', true);
    } catch (e) {
      debugPrint('Error saving cached address: $e');
    }
  }



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



    DateTime? now,



  }) {



    final dynamicEta = calculateDynamicEta(



      distanceKm: distanceKm,



      pendingOrders: pendingOrders,



      isRestaurant: isRestaurant,



      now: now,



    );



    final radius = maxRadius ?? settings?.deliveryRadiusKm ?? maxDeliveryRadiusKm;



    final baseSurgeFee = settings?.surgeCharge ?? 0.0;



    final surgeFee = (baseSurgeFee * dynamicEta.surgeMultiplier).roundToDouble();



    final tier1Fee = settings?.deliveryFeeTier1 ?? 25.0;



    final tier1Threshold = settings?.deliveryThresholdTier1 ?? 149.0;



    final tier2Fee = settings?.deliveryFeeTier2 ?? 35.0;



    final tier2Threshold = settings?.deliveryThresholdTier2 ?? 249.0;



    final tier3Fee = settings?.deliveryFeeTier3 ?? 50.0;



    final tier3Threshold = settings?.deliveryThresholdTier3 ?? 349.0;



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



      final fee = settings?.deliveryFee ?? 25.0;



      return DeliveryTierInfo(



        distanceKm: 0.0,



        deliveryFee: fee,



        baseFee: fee,



        freeDeliveryThreshold: (settings?.freeDeliveryThreshold ?? 199.0),



        isServiceable: false,



        tierName: 'Select Address',



        freeDeliveryLabel: 'Select address to check free delivery',



        feeDescription: 'Please select a delivery address to verify coverage and delivery fee.',



      );



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



      StoreHub? matchedGeofence;



      double minD = double.infinity;



      for (final h in StoreHub.defaultHubs) {



        if (matchedGeofence == null && h.isPointInsideGeofence(lat, lng)) {



          matchedGeofence = h;



        }



        final d = Geolocator.distanceBetween(h.latitude, h.longitude, lat, lng) / 1000.0;



        if (d < minD) {



          minD = d;



          hub = h;



        }



      }



      if (matchedGeofence != null) {



        hub = matchedGeofence;



      }



    }



    final hubCity = hub.city;



    final hubIdPin = RegExp(r'\b\d{6}\b').firstMatch(hub.id)?.group(0);



    String houseNo = '';



    String street = '';



    String area = hubCity;



    String city = hubCity;



    String pincode = hubIdPin ?? (hub.city.toLowerCase().contains('akbarpur') ? '224122' : (hub.city.toLowerCase().contains('pakur') ? '816107' : '209206'));



    String formatted = '$hubCity Market, UP';



    try {



      if (!kIsWeb) {



        final placemarks = await placemarkFromCoordinates(lat, lng);



        if (placemarks.isNotEmpty) {



          final place = placemarks.first;



          final placeName = place.name ?? '';



          final isPlus = AddressFormatter.isPlusCode(placeName);



          houseNo = place.subThoroughfare ?? (isPlus ? '' : placeName);



          street = place.thoroughfare ?? '';



          area = place.subLocality?.isNotEmpty == true ? place.subLocality! : (place.locality ?? hubCity);



          city = place.locality ?? place.administrativeArea ?? hubCity;



          pincode = place.postalCode ?? (hubIdPin ?? (hub.city.toLowerCase().contains('akbarpur') ? '224122' : (hub.city.toLowerCase().contains('pakur') ? '816107' : '209206')));



          final rawParts = [



            if (houseNo.isNotEmpty && !isPlus) houseNo,



            if (street.isNotEmpty && street != houseNo) street,



            if (area.isNotEmpty && area != street) area,



            if (city.isNotEmpty && city != area) city,



            if (pincode.isNotEmpty) pincode,



          ].join(', ');



          formatted = AddressFormatter.formatCleanSingleLine(rawParts, areaFallback: area);



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



      nearestHub: hub,



    );



  }



  /// Convenience method to get full current location details in one call



  static Future<LocationDetails?> fetchCurrentLocationDetails({StoreHub? nearestHub}) async {



    final pos = await getCurrentPosition();



    if (pos == null) return null;



    return await getAddressFromCoordinates(pos.latitude, pos.longitude, nearestHub: nearestHub);



  }



  /// Single source of truth to apply resolved location to app state



  static Future<Address> applyLocationDetails(



    LocationDetails details,



    WidgetRef ref,



  ) async {



    // 1. Sync active dark store hub in AppConfig



    final hub = details.nearestHub ?? StoreHub.defaultGhatampur;



    AppConfig.updateDarkstore(



      lat: hub.latitude,



      lng: hub.longitude,



      address: ', ',



      id: hub.id,



    );



    // 2. Build canonical Address object



    final addr = Address(



      id: 'gps_',



      userId: ref.read(authProvider).value?.id ?? 'current',



      label: 'Current Location',



      houseNo: details.houseNo,



      street: details.street,



      area: details.area.isNotEmpty ? details.area : details.city,



      city: details.city,



      pincode: details.pincode,



      latitude: details.latitude,



      longitude: details.longitude,



      isDefault: true,



    );



    // 3. Update Riverpod provider



    await saveCachedAddress(addr);
    ref.read(selectedAddressProvider.notifier).state = addr;



    // 4. Save to persistent preferences



    final prefs = await SharedPreferences.getInstance();



    await prefs.setBool('has_chosen_location', true);



    // 5. Invalidate catalog & store providers for immediate live stock refresh



    ref.invalidate(homeProductCatalogProvider);



    ref.invalidate(nearestHubResultProvider);



    ref.invalidate(hubAvailabilityProvider);



    return addr;



  }



  /// Swiggy / Zomato Flow: Request permission, handle turned-off GPS, reverse geocode,



  /// connect nearest Store Hub, and auto-set selectedAddressProvider.



  ///



  /// If [silent] is true: Only runs if GPS is ON and permission is ALREADY granted.



  /// If [silent] is false: Prompts to turn on GPS if disabled, requests OS permission,



  /// and prompts for app settings if permanently denied.



  static Future<LocationDetails?> detectAndApplyGpsLocation({



    BuildContext? context,



    required WidgetRef ref,



    bool silent = false,



  }) async {



    try {



      final serviceEnabled = await Geolocator.isLocationServiceEnabled();



      if (!serviceEnabled) {



        if (silent) return null;



        if (context != null && context.mounted) {



          final turnOn = await showDialog<bool>(



            context: context,



            builder: (ctx) => AlertDialog(



              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),



              title: Row(



                children: [



                  Container(



                    padding: const EdgeInsets.all(8),



                    decoration: BoxDecoration(



                      color: const Color(0xFFFEF3C7),



                      borderRadius: BorderRadius.circular(10),



                    ),



                    child: const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 22),



                  ),



                  const SizedBox(width: 10),



                  Expanded(



                    child: Text(



                      'Device location is turned off',



                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),



                    ),



                  ),



                ],



              ),



              content: Text(



                'Please turn on device location to detect your nearest store and deliver live essentials.',



                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),



              ),



              actions: [



                TextButton(



                  onPressed: () => Navigator.pop(ctx, false),



                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),



                ),



                ElevatedButton(



                  onPressed: () => Navigator.pop(ctx, true),



                  style: ElevatedButton.styleFrom(



                    backgroundColor: const Color(0xFFEA580C),



                    foregroundColor: Colors.white,



                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),



                    elevation: 0,



                  ),



                  child: Text('Turn On Location', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),



                ),



              ],



            ),



          );



          if (turnOn == true) {



            await Geolocator.openLocationSettings();



          }



        }



        return null;



      }



      var permission = await Geolocator.checkPermission();



      if (silent) {



        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {



          return null;



        }



      } else {



        if (permission == LocationPermission.denied) {



          permission = await Geolocator.requestPermission();



          if (permission == LocationPermission.denied) {



            return null;



          }



        }



        if (permission == LocationPermission.deniedForever) {



          if (context != null && context.mounted) {



            final openSettings = await showDialog<bool>(



              context: context,



              builder: (ctx) => AlertDialog(



                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),



                title: Text(



                  'Location Permission Required',



                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),



                ),



                content: Text(



                  'Location permission is permanently disabled. Please allow location in App Settings so we can show live stock near you.',



                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),



                ),



                actions: [



                  TextButton(



                    onPressed: () => Navigator.pop(ctx, false),



                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),



                  ),



                  ElevatedButton(



                    onPressed: () => Navigator.pop(ctx, true),



                    style: ElevatedButton.styleFrom(



                      backgroundColor: const Color(0xFFEA580C),



                      foregroundColor: Colors.white,



                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),



                      elevation: 0,



                    ),



                    child: Text('Open App Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),



                  ),



                ],



              ),



            );



            if (openSettings == true) {



              await Geolocator.openAppSettings();



            }



          }



          return null;



        }



      }



      Position? position;
      if (silent) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: silent ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: Duration(seconds: silent ? 4 : 8),
      );



      final details = await getAddressFromCoordinates(position.latitude, position.longitude);



      await applyLocationDetails(details, ref);



      return details;



    } catch (e) {



      debugPrint('detectAndApplyGpsLocation error: ');



      return null;



    }



  }



  /// Background bootstrap method on app launch (Blinkit / Zepto / Swiggy style)



  /// Checks if location permission is already granted and automatically



  /// updates selectedAddressProvider with live GPS coords if no custom address was selected.



  static Future<void> bootstrapUserLocation(WidgetRef ref) async {



    final currentAddress = ref.read(selectedAddressProvider);



    if (currentAddress != null &&



        currentAddress.id != 'hub_active_default' &&



        !currentAddress.id.startsWith('addr_bootstrap_gps_') &&



        !currentAddress.id.startsWith('gps_')) {



      return;



    }



    await detectAndApplyGpsLocation(ref: ref, silent: true);



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