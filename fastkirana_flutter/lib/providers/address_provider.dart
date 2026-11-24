import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import '../core/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/address.dart';
import '../data/models/checkout_draft.dart';
import '../data/repositories/address_repository.dart';
import '../core/network/api_client.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.read(dioProvider));
});

class AddressesNotifier extends StateNotifier<AsyncValue<List<Address>>> {
  final AddressRepository _repo;

  AddressesNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    state = const AsyncValue.loading();
    try {
      final addresses = await _repo.getAddresses();
      final filtered = addresses
          .where((a) => !a.label.toUpperCase().startsWith('STORE_PICKUP'))
          .toList();
      if (mounted) state = AsyncValue.data(filtered);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<Address> addAddress(Map<String, dynamic> data) async {
    final newAddress = await _repo.createAddress(data);
    await loadAddresses();
    return newAddress;
  }

  Future<Address> updateAddress(Map<String, dynamic> data) async {
    final updated = await _repo.updateAddress(data);
    await loadAddresses();
    return updated;
  }

  Future<void> deleteAddress(String id) async {
    await _repo.deleteAddress(id);
    await loadAddresses();
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final addressesProvider = StateNotifierProvider.autoDispose<AddressesNotifier, AsyncValue<List<Address>>>((ref) {
  // Watch authProvider so whenever login state changes (login, switch user, logout),
  // addresses are automatically refreshed immediately!
  ref.watch(authProvider);
  final notifier = AddressesNotifier(ref.watch(addressRepositoryProvider));
  ref.keepAlive();
  return notifier;
});

// Active chosen address for delivery / header
class SelectedAddressNotifier extends StateNotifier<Address?> {
  final Ref _ref;
  String? _persistedAddressId;
  bool _manualSelectionInSession = false;

  SelectedAddressNotifier(this._ref) : super(LocationService.cachedAddress) {
    _init();
  }

  static double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static bool isDarkstoreFallbackPin(double? lat, double? lng) {
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return true;
    // Ghatampur Central Hub default fallback coordinates
    return _haversineMeters(lat, lng, 26.1534185, 80.1714024) <= 50.0;
  }

  Future<void> _tryAutoSelectNearest(List<Address> addresses) async {
    if (_manualSelectionInSession || addresses.length < 2) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) return;
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );

      Address? nearest;
      double bestMeters = 500.0; // Strictly within 500m radius
      for (final addr in addresses) {
        if (isDarkstoreFallbackPin(addr.latitude, addr.longitude)) continue;
        final d = _haversineMeters(pos.latitude, pos.longitude, addr.latitude!, addr.longitude!);
        if (d < bestMeters) {
          bestMeters = d;
          nearest = addr;
        }
      }

      if (nearest != null && mounted && !_manualSelectionInSession && state?.id != nearest.id) {
        super.state = nearest;
        await LocationService.saveCachedAddress(nearest);
      }
    } catch (_) {
      // Silent fallback if GPS unavailable
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _persistedAddressId = prefs.getString('user_selected_address_id');
      if (state == null) {
        if (LocationService.cachedAddress != null) {
          state = LocationService.cachedAddress;
        } else {
          await LocationService.loadCachedAddress();
          if (LocationService.cachedAddress != null) {
            state = LocationService.cachedAddress;
          }
        }
      }
    } catch (e) {
      debugPrint('SelectedAddressNotifier _init error: $e');
    }

    // Keep active selection intact when addresses list loads from network
    _ref.listen<AsyncValue<List<Address>>>(addressesProvider, (prev, next) {
      next.whenData((addresses) {
        if (addresses.isEmpty) return;

        // 1. If user previously selected an address ID, preserve that exact address
        final targetId = _persistedAddressId ?? state?.id;
        if (targetId != null) {
          final matched = addresses.cast<Address?>().firstWhere(
            (a) => a?.id == targetId,
            orElse: () => null,
          );
          if (matched != null) {
            super.state = matched;
            LocationService.saveCachedAddress(matched);
            unawaited(_tryAutoSelectNearest(addresses));
            return;
          }
        }

        // 2. If an address is already actively selected in state, DO NOT clobber it
        if (state != null) {
          unawaited(_tryAutoSelectNearest(addresses));
          return;
        }

        // 3. Fallback: Default address
        final def = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        super.state = def;
        LocationService.saveCachedAddress(def);
        unawaited(_tryAutoSelectNearest(addresses));
      });
    });
  }

  @override
  set state(Address? value) {
    super.state = value;
    if (value != null) {
      _manualSelectionInSession = true;
      _persistAndSync(value);
    } else {
      _persistedAddressId = null;
      SharedPreferences.getInstance().then((prefs) => prefs.remove('user_selected_address_id')).catchError((_) => false);
    }
  }

  Future<void> selectAddress(Address addr) async {
    _manualSelectionInSession = true;
    super.state = addr;
    await _persistAndSync(addr);
  }

  Future<void> _persistAndSync(Address addr) async {
    _persistedAddressId = addr.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_selected_address_id', addr.id);
      await LocationService.saveCachedAddress(addr);

      // Clear any stale checkout draft so checkout uses this newly selected address
      await CheckoutDraft.clearAcceptedDraft();

      // Sync isDefault flag with server in background
      unawaited(_ref.read(addressRepositoryProvider).setAddressAsDefault(addr.id));
    } catch (e) {
      debugPrint('Error persisting selected address: $e');
    }
  }
}

final selectedAddressProvider = StateNotifierProvider<SelectedAddressNotifier, Address?>((ref) {
  return SelectedAddressNotifier(ref);
});

/// Ephemeral feedback notifier to show transient confirmation in Header (DoorDash/Instacart style)
class LocationFeedbackNotifier extends StateNotifier<String?> {
  Timer? _timer;

  LocationFeedbackNotifier() : super(null);

  void trigger(String feedback) {
    final clean = feedback.trim();
    if (clean.isEmpty || !RegExp(r'\d').hasMatch(clean)) return;
    _timer?.cancel();
    state = clean;
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        state = null;
      }
    });
  }

  void clear() {
    _timer?.cancel();
    if (mounted) state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final recentLocationFeedbackProvider =
    StateNotifierProvider<LocationFeedbackNotifier, String?>((ref) {
  return LocationFeedbackNotifier();
});

/// Backward-compatible helper that delegates to LocationFeedbackNotifier
void showLocationFeedback(WidgetRef ref, String feedbackText) {
  ref.read(recentLocationFeedbackProvider.notifier).trigger(feedbackText);
}

