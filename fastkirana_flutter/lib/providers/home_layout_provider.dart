import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/services/logger_service.dart';
import '../data/models/home_layout_config.dart';

const String _kHomeLayoutCacheKey = 'cached_home_layout_v1';
HomeLayoutConfigModel? _preloadedHomeLayout;

/// Synchronous getter for Frame-0 Bento rendering
HomeLayoutConfigModel? get preloadedHomeLayoutConfig => _preloadedHomeLayout;

/// Warm up cached Bento / Home layout sequence from disk during main() cold start (<20ms)
Future<void> preloadHomeLayoutDiskCache() async {
  if (_preloadedHomeLayout != null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHomeLayoutCacheKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      _preloadedHomeLayout = HomeLayoutConfigModel.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    }
  } catch (e) {
    LoggerService.error('preloadHomeLayoutDiskCache error', e);
  }
}

final homeLayoutConfigProvider =
    FutureProvider<HomeLayoutConfigModel>((ref) async {
  ref.keepAlive();
  final dio = ref.read(dioProvider);

  Future<HomeLayoutConfigModel?> fetchAndCache() async {
    try {
      final response = await dio.get('/api/home-layout');
      if (response.data != null && response.data is Map) {
        final rawMap = Map<String, dynamic>.from(response.data as Map);
        final parsed = HomeLayoutConfigModel.fromJson(rawMap);
        _preloadedHomeLayout = parsed;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kHomeLayoutCacheKey, jsonEncode(rawMap));
        } catch (_) {}
        return parsed;
      }
    } catch (e, st) {
      LoggerService.error('homeLayoutConfigProvider fetch error', e, st);
    }
    return null;
  }

  // 1. SWR 0ms cache hit: return disk-preloaded layout immediately and refresh silently in background
  if (_preloadedHomeLayout == null) {
    await preloadHomeLayoutDiskCache();
  }
  if (_preloadedHomeLayout != null) {
    unawaited(fetchAndCache());
    return _preloadedHomeLayout!;
  }

  // 2. First-ever cold start: fetch from network or fall back to Blinkit-style default sequence
  return await fetchAndCache() ?? const HomeLayoutConfigModel();
});
