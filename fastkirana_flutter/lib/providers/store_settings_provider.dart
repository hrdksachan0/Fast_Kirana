import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/store_settings.dart';

final storeSettingsProvider = FutureProvider<StoreSettings>((ref) async {
  final dio = ref.read(dioProvider);
  
  // 1. Try /api/settings
  try {
    final response = await dio.get('/api/settings');
    if (response.data != null && response.data is Map) {
      return StoreSettings.fromJson(Map<String, dynamic>.from(response.data));
    }
  } catch (_) {}

  // 2. Try /api/public/settings
  try {
    final response = await dio.get('/api/public/settings');
    if (response.data != null && response.data is Map) {
      return StoreSettings.fromJson(Map<String, dynamic>.from(response.data));
    }
  } catch (_) {}

  // 3. Fallback to default Ghatampur quick commerce store settings
  return StoreSettings();
});
