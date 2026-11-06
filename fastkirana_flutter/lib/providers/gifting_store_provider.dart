import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/gifting_store_config.dart';

final giftingStoreConfigProvider =
    FutureProvider<GiftingStoreConfigModel>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get('/api/gifting-store');
    if (response.data != null && response.data is Map) {
      return GiftingStoreConfigModel.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    }
  } catch (e, st) {
    LoggerService.error('giftingStoreConfigProvider fetch error', e, st);
  }

  // Graceful fallback to default configuration
  return const GiftingStoreConfigModel(occasions: GiftingStoreConfigModel.defaultOccasions);
});
