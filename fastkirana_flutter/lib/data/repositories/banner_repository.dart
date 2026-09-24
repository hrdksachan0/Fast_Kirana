import 'dart:convert';
import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banner.dart';

class BannerRepository {
  final Dio dio;
  static const _diskBannersPrefix = 'cached_promo_banners_v15_';
  static final Map<String, List<Banner>> _inMemoryBanners = {};
  static final Map<String, DateTime> _inMemoryBannersLastFetch = {};
  static const _bannerTTLMinutes = 2; // Auto re-fetch every 2 minutes max

  BannerRepository(this.dio);

  static const List<Banner> defaultGroceryBanners = [];
  static const List<Banner> defaultFoodBanners = [];
  static List<Banner> get defaultBanners => defaultGroceryBanners;

  /// Clear all banner caches (in-memory and disk)
  static Future<void> invalidateCache() async {
    _inMemoryBanners.clear();
    _inMemoryBannersLastFetch.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_diskBannersPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<List<Banner>> getBanners({String? type, String? storeId, bool forceRefresh = false}) async {
    final key = '${type ?? "all"}_${storeId ?? "global"}';
    final lastTime = _inMemoryBannersLastFetch[key];
    final isMemFresh = lastTime != null && DateTime.now().difference(lastTime).inMinutes < _bannerTTLMinutes;

    // 1. In-memory cache hit (only if fresh and not forceRefresh)
    if (!forceRefresh && isMemFresh && _inMemoryBanners.containsKey(key)) {
      return _inMemoryBanners[key]!;
    }

    // 2. Disk cache hit (instant 0ms hydration + async background refresh)
    if (!forceRefresh) {
      final diskBanners = await _loadBannersFromDisk(key);
      if (diskBanners != null) {
        _inMemoryBanners[key] = diskBanners;
        _inMemoryBannersLastFetch[key] = DateTime.now();
        _fetchFromNetwork(type: type, storeId: storeId);
        return diskBanners;
      }
    }

    // 3. Network fetch (first load, pull-to-refresh, or expired TTL)
    final networkBanners = await _fetchFromNetwork(type: type, storeId: storeId);
    if (networkBanners != null) {
      _inMemoryBanners[key] = networkBanners;
      _inMemoryBannersLastFetch[key] = DateTime.now();
      return networkBanners;
    }

    // Zero banners fallback: Return empty list so carousel completely collapses
    return const [];
  }

  Future<List<Banner>?> _fetchFromNetwork({String? type, String? storeId}) async {
    final key = '${type ?? "all"}_${storeId ?? "global"}';
    try {
      final response = await dio.get(
        '/api/banners',
        queryParameters: {
          if (type != null && type.isNotEmpty) 'type': type,
          if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
          'platform': 'mobile',
        },
      );
      final data = response.data;
      if (data is List) {
        final banners = data.map((json) => Banner.fromJson(json as Map<String, dynamic>)).toList();
        _inMemoryBanners[key] = banners;
        await _saveBannersToDisk(key, banners);
        return banners;
      }
    } catch (e, st) {
      LoggerService.error('BannerRepository: _fetchFromNetwork failed', e, st);
    }
    return null;
  }

  static Future<List<Banner>?> _loadBannersFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_diskBannersPrefix$key');
      if (raw == null) return null;
      if (raw.trim().isEmpty) return const [];
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((j) => Banner.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveBannersToDisk(String key, List<Banner> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = banners.map((b) => b.toJson()).toList();
      await prefs.setString('$_diskBannersPrefix$key', jsonEncode(jsonList));
    } catch (e) {
      LoggerService.error('BannerRepository: disk save failed', e);
    }
  }
}
