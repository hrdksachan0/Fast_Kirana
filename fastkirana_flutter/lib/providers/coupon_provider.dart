import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/coupon.dart';
import '../data/repositories/coupon_repository.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(ref.read(dioProvider));
});

final couponsProvider = FutureProvider<List<Coupon>>((ref) async {
  final repo = ref.watch(couponRepositoryProvider);
  return repo.getCoupons();
});
