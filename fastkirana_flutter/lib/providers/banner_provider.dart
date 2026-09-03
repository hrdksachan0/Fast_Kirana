import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/banner.dart';
import '../data/repositories/banner_repository.dart';
import '../core/network/api_client.dart';

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(ref.read(dioProvider));
});

final bannersProvider = FutureProvider.family<List<Banner>, String?>((ref, type) async {
  ref.keepAlive();
  final repo = ref.watch(bannerRepositoryProvider);
  return repo.getBanners(type: type);
});
