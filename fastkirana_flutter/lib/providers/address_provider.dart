import 'dart:async';
import 'package:flutter/foundation.dart';
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
      state = AsyncValue.data(filtered);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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

  SelectedAddressNotifier(this._ref) : super(LocationService.cachedAddress) {
    _init();
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
            return;
          }
        }

        // 2. If an address is already actively selected in state, DO NOT clobber it
        if (state != null) {
          return;
        }

        // 3. Fallback: Default address
        final def = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        super.state = def;
        LocationService.saveCachedAddress(def);
      });
    });
  }

  @override
  set state(Address? value) {
    super.state = value;
    if (value != null) {
      _persistAndSync(value);
    } else {
      _persistedAddressId = null;
      SharedPreferences.getInstance().then((prefs) => prefs.remove('user_selected_address_id')).catchError((_) {});
    }
  }

  Future<void> selectAddress(Address addr) async {
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
