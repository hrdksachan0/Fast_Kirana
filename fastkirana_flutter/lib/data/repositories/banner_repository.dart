import 'dart:convert';
import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banner.dart';

class BannerRepository {
  final Dio dio;
  static const _diskBannersKey = 'cached_promo_banners';
  static List<Banner>? _inMemoryBanners;

  BannerRepository(this.dio);

  static final List<Banner> defaultBanners = [
    const Banner(
      id: 'default-1',
      title: 'Fast Delivery in Ghatampur',
      description: 'Milk, Fruits, Vegetables, Snacks & more',
      code: '',
      gradient: 'from-rose-500 via-rose-500 to-orange-400',
      type: 'express-delivery',
      linkUrl: '/category/fruits-vegetables',
      sortOrder: 0,
      isActive: true,
    ),
    const Banner(
      id: 'default-2',
      title: 'Farm Fresh Vegetables & Fruits',
      description: 'Directly sourced from local farms. Handpicked for premium quality.',
      code: '',
      gradient: 'from-emerald-600 via-emerald-500 to-teal-400',
      type: 'fresh',
      linkUrl: '/category/fruits-vegetables',
      sortOrder: 1,
      isActive: true,
    ),
    const Banner(
      id: 'default-3',
      title: 'Super Savings Everyday!',
      description: 'Best wholesale prices on fruits, veggies, dairy, and snacks.',
      code: '',
      gradient: 'from-rose-600 via-rose-500 to-orange-400',
      type: 'first-order',
      linkUrl: '/category/dairy-breakfast',
      sortOrder: 2,
      isActive: true,
    ),
  ];

  Future<List<Banner>> getBanners({String? type, bool forceRefresh = false}) async {
    // 1. In-memory cache hit
    if (!forceRefresh && _inMemoryBanners != null && _inMemoryBanners!.isNotEmpty) {
      return _inMemoryBanners!;
    }

    // 2. Disk cache hit (instant 0ms hydration)
    if (!forceRefresh) {
      final diskBanners = await _loadBannersFromDisk();
      if (diskBanners != null && diskBanners.isNotEmpty) {
        _inMemoryBanners = diskBanners;
        return diskBanners;
      }
    }

    // 3. Network fetch
    try {
      final response = await dio.get(
        '/api/banners',
        queryParameters: {
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final data = response.data;
      if (data is List) {
        final banners = data.map((json) => Banner.fromJson(json as Map<String, dynamic>)).toList();
        if (banners.isNotEmpty) {
          _inMemoryBanners = banners;
          _saveBannersToDisk(banners);
          return banners;
        }
      }
    } catch (e, st) {
      LoggerService.error('BannerRepository: getBanners failed', e, st);
    }

    // 4. Disk cache fallback on network failure
    final diskBanners = await _loadBannersFromDisk();
    if (diskBanners != null && diskBanners.isNotEmpty) {
      _inMemoryBanners = diskBanners;
      return diskBanners;
    }

    // 5. Default static banners matching web app
    _inMemoryBanners = defaultBanners;
    return defaultBanners;
  }

  static Future<List<Banner>?> _loadBannersFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskBannersKey);
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((j) => Banner.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveBannersToDisk(List<Banner> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = banners.map((b) => b.toJson()).toList();
      await prefs.setString(_diskBannersKey, jsonEncode(jsonList));
    } catch (e) {
      LoggerService.error('BannerRepository: disk save failed', e);
    }
  }
}
