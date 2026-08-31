import 'package:dio/dio.dart';
import '../models/coupon.dart';

class CouponRepository {
  final Dio dio;
  CouponRepository(this.dio);

  Future<List<Coupon>> getCoupons() async {
    try {
      final response = await dio.get('/api/coupons');
      final data = response.data;
      if (data is List) {
        return data.map((json) => Coupon.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
