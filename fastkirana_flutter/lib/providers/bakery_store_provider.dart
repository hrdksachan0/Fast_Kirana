import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/bakery_store_config.dart';

final bakeryStoreConfigProvider =
    FutureProvider<BakeryStoreConfigModel>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get('/api/bakery-store');
    if (response.data != null && response.data is Map) {
      return BakeryStoreConfigModel.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    }
  } catch (e, st) {
    LoggerService.error('bakeryStoreConfigProvider fetch error', e, st);
  }

  // Graceful fallback to default configuration
  return const BakeryStoreConfigModel(tabs: BakeryStoreConfigModel.defaultTabs);
});
