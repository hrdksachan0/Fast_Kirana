import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/gifting_store_config.dart';

final giftingStoreConfigProvider =
    FutureProvider<GiftingStoreConfigModel>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    Response? response;
    // 1. Try web storefront endpoint (always live with dynamic config)
    try {
      response = await dio.get(
        '/api/gifting-store',
        options: Options(
          extra: {'override_base_url': 'https://www.fastminute.in'},
        ),
      );
    } catch (_) {
      // 2. Fallback to primary API endpoint
      response = await dio.get('/api/gifting-store');
    }

    final data = response.data;
    if (data is Map) {
      return GiftingStoreConfigModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
  } catch (e, st) {
    LoggerService.error('giftingStoreConfigProvider fetch error', e, st);
  }

  // Graceful fallback to default configuration
  return const GiftingStoreConfigModel(occasions: GiftingStoreConfigModel.defaultOccasions);
});
