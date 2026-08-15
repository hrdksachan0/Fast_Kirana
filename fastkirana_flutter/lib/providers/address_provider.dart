import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/address.dart';
import '../data/repositories/address_repository.dart';
import '../core/network/api_client.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.read(dioProvider));
});

final addressesProvider = FutureProvider<List<Address>>((ref) async {
  final repo = ref.watch(addressRepositoryProvider);
  return repo.getAddresses();
});
