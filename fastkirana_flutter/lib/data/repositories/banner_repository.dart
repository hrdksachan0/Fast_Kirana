import 'dart:convert';
import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banner.dart';

class BannerRepository {
  final Dio dio;
  static const _diskBannersKey = 'cached_promo_banners_v4';
  static List<Banner>? _inMemoryBanners;

  BannerRepository(this.dio);

  static final List<Banner> defaultBanners = [
    const Banner(
      id: 'banner-ghatampur-express',
      title: 'Fast Delivery in Ghatampur',
      description: 'Milk, Fruits, Vegetables, Snacks & more delivered in minutes',
      code: '',
      gradient: 'from-rose-500 via-rose-500 to-orange-400',
      type: 'real-image',
      imageUrl: '/banners/ghatampur-express-real.png',
      linkUrl: '/category/fruits-vegetables',
      sortOrder: 0,
      isActive: true,
    ),
    const Banner(
      id: 'banner-as-restaurant',
      title: 'A.S. Restaurant • Burgers, Pizza & Shakes',
      description: 'Juicy burgers, cheesy loaded pizzas, hot momos & thick shakes',
      code: '',
      gradient: 'from-rose-600 via-red-500 to-amber-500',
      type: 'real-image',
      imageUrl: '/banners/as-restaurant-real.png',
      linkUrl: '/restaurant/as-restaurant',
      sortOrder: 1,
      isActive: true,
    ),
    const Banner(
      id: 'banner-wedson-restaurant',
      title: 'Wedson Restaurant • Royal Indian & Biryani',
      description: 'Aromatic dum biryani, rich paneer curries, tandoori treats & dal makhani',
      code: '',
      gradient: 'from-amber-600 via-orange-500 to-yellow-500',
      type: 'real-image',
      imageUrl: '/banners/wedson-restaurant-real.png',
      linkUrl: '/restaurant/wedson-restaurant',
      sortOrder: 2,
      isActive: true,
    ),
    const Banner(
      id: 'banner-bal-udyan',
      title: 'Bal Udyan Restaurant • Family Meals & Thalis',
      description: 'Homestyle North Indian thalis, special Chinese bites & evening party snacks',
      code: '',
      gradient: 'from-emerald-600 via-teal-500 to-cyan-500',
      type: 'real-image',
      imageUrl: '/banners/bal-udyan-real.png',
      linkUrl: '/restaurant/bal-udyan-restaurant',
      sortOrder: 3,
      isActive: true,
    ),
  ];

  Future<List<Banner>> getBanners({String? type, bool forceRefresh = false}) async {
    // 1. In-memory cache hit
    if (!forceRefresh && _inMemoryBanners != null && _inMemoryBanners!.isNotEmpty) {
      return _inMemoryBanners!;
    }

    // 2. Disk cache hit (instant 0ms hydration + async background refresh)
    if (!forceRefresh) {
      final diskBanners = await _loadBannersFromDisk();
      if (diskBanners != null && diskBanners.isNotEmpty) {
        _inMemoryBanners = diskBanners;
        // Background revalidation to keep disk cache fresh with admin updates
        _fetchFromNetwork(type: type);
        return diskBanners;
      }
    }

    // 3. Network fetch (first load or pull-to-refresh)
    final networkBanners = await _fetchFromNetwork(type: type);
    if (networkBanners != null && networkBanners.isNotEmpty) {
      return networkBanners;
    }

    // 4. Fallback to bundled real banners
    _inMemoryBanners = defaultBanners;
    return defaultBanners;
  }

  Future<List<Banner>?> _fetchFromNetwork({String? type}) async {
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
          await _saveBannersToDisk(banners);
          return banners;
        }
      }
    } catch (e, st) {
      LoggerService.error('BannerRepository: _fetchFromNetwork failed', e, st);
    }
    return null;
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
