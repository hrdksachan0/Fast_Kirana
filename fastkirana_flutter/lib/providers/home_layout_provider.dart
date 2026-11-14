import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/home_layout_config.dart';

final homeLayoutConfigProvider =
    FutureProvider<HomeLayoutConfigModel>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get('/api/home-layout');
    if (response.data != null && response.data is Map) {
      return HomeLayoutConfigModel.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    }
  } catch (e, st) {
    LoggerService.error('homeLayoutConfigProvider fetch error', e, st);
  }

  // Graceful fallback to default Blinkit-style sequence
  return const HomeLayoutConfigModel();
});
