import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/address.dart';
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
      state = AsyncValue.data(addresses);
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
}

final addressesProvider = StateNotifierProvider.autoDispose<AddressesNotifier, AsyncValue<List<Address>>>((ref) {
  final notifier = AddressesNotifier(ref.watch(addressRepositoryProvider));
  ref.keepAlive();
  return notifier;
});

// Active chosen address for delivery / header
final selectedAddressProvider = StateProvider<Address?>((ref) {
  final addressesAsync = ref.watch(addressesProvider);
  return addressesAsync.when(
    data: (addresses) {
      if (addresses.isEmpty) return null;
      return addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
