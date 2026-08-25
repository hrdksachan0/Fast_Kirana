import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../data/models/store_settings.dart';

final storeSettingsProvider = FutureProvider<StoreSettings>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/settings');
    if (response.data != null && response.data is Map) {
      return StoreSettings.fromJson(Map<String, dynamic>.from(response.data));
    }
  } catch (e) {
    // fallback default settings
  }
  return StoreSettings();
});
