import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/store_settings.dart';
import 'store_hub_provider.dart';

final storeSettingsProvider = FutureProvider<StoreSettings>((ref) async {
  final dio = ref.read(dioProvider);
  final hub = ref.watch(currentStoreHubProvider);
  final storeId = hub.id;
  
  // 1. Try /api/settings with storeId
  try {
    final response = await dio.get('/api/settings', queryParameters: {
      if (storeId.isNotEmpty) 'storeId': storeId,
    });
    if (response.data != null && response.data is Map) {
      return StoreSettings.fromJson(Map<String, dynamic>.from(response.data));
    }
  } catch (e, st) { LoggerService.error('StoreSettingsProvider: /api/settings fetch failed', e, st); }

  // 2. Try /api/public/settings with storeId
  try {
    final response = await dio.get('/api/public/settings', queryParameters: {
      if (storeId.isNotEmpty) 'storeId': storeId,
    });
    if (response.data != null && response.data is Map) {
      return StoreSettings.fromJson(Map<String, dynamic>.from(response.data));
    }
  } catch (e, st) { LoggerService.error('StoreSettingsProvider: /api/public/settings fetch failed', e, st); }

  // 3. Fallback to default quick commerce store settings
  return const StoreSettings();
});
