import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/store_hub.dart';
import '../core/services/logger_service.dart';
import '../core/services/supabase_service.dart';
import '../core/network/api_client.dart';
import '../core/config/app_config.dart';
import 'address_provider.dart';

/// Fetches all active store hubs from Supabase / REST API
final activeStoreHubsProvider = FutureProvider<List<StoreHub>>((ref) async {
  // 1. Try Supabase direct (fastest, real-time)
  try {
    final sb = SupabaseService.client;
    if (sb != null) {
      final data = await sb
          .from('dark_stores')
          .select('*')
          .eq('isActive', true);
      if (data.isNotEmpty) {
        return data.map((json) => StoreHub.fromJson(Map<String, dynamic>.from(json))).toList();
      }
    }
  } catch (e, st) {
    LoggerService.error('StoreHubProvider: Supabase fetch failed', e, st);
  }

  // 2. Fallback to Dio REST
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/stores/hubs');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data is List ? response.data : response.data['hubs'];
      if (list is List && list.isNotEmpty) {
        return list.map((json) => StoreHub.fromJson(Map<String, dynamic>.from(json))).toList();
      }
    }
  } catch (e, st) {
    LoggerService.error('StoreHubProvider: REST fetch failed', e, st);
  }

  // 3. Offline default fallback
  return StoreHub.defaultHubs;
});

/// Nearest Hub and Distance Result
class NearestHubResult {
  final StoreHub hub;
  final double distanceKm;
  final bool isServiceable;

  const NearestHubResult({
    required this.hub,
    required this.distanceKm,
    required this.isServiceable,
  });
}

/// Automatically finds the nearest active Store Hub for the customer's selected address
final nearestHubResultProvider = Provider<NearestHubResult>((ref) {
  final hubsAsync = ref.watch(activeStoreHubsProvider);
  final address = ref.watch(selectedAddressProvider);

  final hubs = hubsAsync.valueOrNull ?? StoreHub.defaultHubs;
  if (hubs.isEmpty) {
    return const NearestHubResult(
      hub: StoreHub.defaultGhatampur,
      distanceKm: 0.0,
      isServiceable: true,
    );
  }

  final customerLat = address?.latitude ?? StoreHub.defaultGhatampur.latitude;
  final customerLng = address?.longitude ?? StoreHub.defaultGhatampur.longitude;

  StoreHub nearest = hubs.first;
  double minDistanceKm = double.infinity;
  StoreHub? polygonMatchedHub;

  for (final hub in hubs) {
    if (!hub.isActive) continue;

    final distMeters = Geolocator.distanceBetween(
      hub.latitude,
      hub.longitude,
      customerLat,
      customerLng,
    );
    final distKm = distMeters / 1000.0;

    // 1. Check exact polygon geofence match (ray-casting PIP)
    if (polygonMatchedHub == null &&
        hub.polygonGeoJson != null &&
        hub.polygonGeoJson!.isNotEmpty &&
        hub.isPointInsideGeofence(customerLat, customerLng)) {
      polygonMatchedHub = hub;
    }

    if (distKm < minDistanceKm) {
      minDistanceKm = distKm;
      nearest = hub;
    }
  }

  // If customer is within an active hub's delivery polygon, bind to that hub
  final resolvedHub = polygonMatchedHub ?? nearest;
  final resolvedDistanceKm = (resolvedHub == nearest)
      ? minDistanceKm
      : (Geolocator.distanceBetween(
            resolvedHub.latitude,
            resolvedHub.longitude,
            customerLat,
            customerLng,
          ) /
          1000.0);

  final isServiceable = resolvedHub.isPointInsideGeofence(customerLat, customerLng);

  // Sync AppConfig so all non-provider call sites read the live hub coords.
  AppConfig.updateDarkstore(
    lat: resolvedHub.latitude,
    lng: resolvedHub.longitude,
    address: '${resolvedHub.name}, ${resolvedHub.city}',
    id: resolvedHub.id,
  );

  return NearestHubResult(
    hub: resolvedHub,
    distanceKm: resolvedDistanceKm,
    isServiceable: isServiceable,
  );
});

/// Current active Store Hub the user is browsing
final currentStoreHubProvider = Provider<StoreHub>((ref) {
  return ref.watch(nearestHubResultProvider).hub;
});
