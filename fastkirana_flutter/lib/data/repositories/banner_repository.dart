import 'package:dio/dio.dart';
import '../models/banner.dart';
import '../../core/network/api_client.dart';

class BannerRepository {
  final Dio dio;
  BannerRepository(this.dio);

  Future<List<Banner>> getBanners({String? type}) async {
    try {
      final response = await dio.get(
        '/api/banners',
        queryParameters: {
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final data = response.data;
      if (data is List) {
        return data.map((json) => Banner.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
