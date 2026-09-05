import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/store_hub.dart';
import '../core/services/supabase_service.dart';
import '../core/network/api_client.dart';
import 'address_provider.dart';

/// Fetches all active store hubs from Supabase / REST API
final activeStoreHubsProvider = FutureProvider<List<StoreHub>>((ref) async {
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
  } catch (_) {}

  // Fallback to Dio REST
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/stores/hubs');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data is List ? response.data : response.data['hubs'];
      if (list is List && list.isNotEmpty) {
        return list.map((json) => StoreHub.fromJson(Map<String, dynamic>.from(json))).toList();
      }
    }
  } catch (_) {}

  // Offline default fallback
  return [StoreHub.defaultGhatampur];
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

  final hubs = hubsAsync.valueOrNull ?? [StoreHub.defaultGhatampur];
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

  for (final hub in hubs) {
    final distMeters = Geolocator.distanceBetween(
      hub.latitude,
      hub.longitude,
      customerLat,
      customerLng,
    );
    final distKm = distMeters / 1000.0;
    if (distKm < minDistanceKm) {
      minDistanceKm = distKm;
      nearest = hub;
    }
  }

  final isServiceable = minDistanceKm <= nearest.deliveryRadiusKm;

  return NearestHubResult(
    hub: nearest,
    distanceKm: minDistanceKm,
    isServiceable: isServiceable,
  );
});

/// Current active Store Hub the user is browsing
final currentStoreHubProvider = Provider<StoreHub>((ref) {
  return ref.watch(nearestHubResultProvider).hub;
});
