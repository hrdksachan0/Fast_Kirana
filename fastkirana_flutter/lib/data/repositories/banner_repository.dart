import 'dart:convert';
import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banner.dart';

class BannerRepository {
  final Dio dio;
  static const _diskBannersPrefix = 'cached_promo_banners_v8_';
  static final Map<String, List<Banner>> _inMemoryBanners = {};

  BannerRepository(this.dio);

  static final List<Banner> defaultGroceryBanners = [
    Banner(
      id: 'official-grocery-brand-card',
      title: 'SUPER GROCERY DAYS',
      description: 'Flat 50% Off on Fresh Fruits, Milk & California Almonds',
      code: jsonEncode({
        'cardType': 'hero',
        'eyebrowTag': '🛍️ SUPER GROCERY DAYS',
        'primaryBrand': 'FASTKIRANA',
        'secondaryBrand': 'GROCERY MART',
        'ctaText': 'SHOP GROCERIES',
        'ctaUrl': '/category/fruits-vegetables',
        'ctaBgColorHex': '#DC2626',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 50% OFF',
        'cashbackSubtitle': '+ 10-Min Doorstep Delivery',
        'disclaimerText': '*Handpicked daily from verified sources.',
      }),
      gradient: 'from-rose-600 via-rose-500 to-orange-400',
      type: 'grocery',
      imageUrl: '/banners/fastkirana-grocery-brand-card.jpg',
      linkUrl: '/category/fruits-vegetables',
      sortOrder: 0,
      isActive: true,
      extraData: const {
        'cardType': 'hero',
        'eyebrowTag': '🛍️ SUPER GROCERY DAYS',
        'primaryBrand': 'FASTKIRANA',
        'secondaryBrand': 'GROCERY MART',
        'ctaText': 'SHOP GROCERIES',
        'ctaUrl': '/category/fruits-vegetables',
        'ctaBgColorHex': '#DC2626',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 50% OFF',
        'cashbackSubtitle': '+ 10-Min Doorstep Delivery',
        'disclaimerText': '*Handpicked daily from verified sources.',
      },
    ),
    Banner(
      id: 'grocery-farm-fresh-hero',
      title: 'FARM FRESH HARVEST',
      description: 'Crisp Red Apples, Ripe Avocados & Hydroponic Veggies',
      code: jsonEncode({
        'cardType': 'hero',
        'eyebrowTag': '🌿 100% ORGANIC HARVEST',
        'primaryBrand': 'FASTKIRANA',
        'secondaryBrand': 'LOCAL FARMS',
        'ctaText': 'SHOP FRESH VEGGIES',
        'ctaUrl': '/category/fruits-vegetables',
        'ctaBgColorHex': '#10B981',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 35% OFF',
        'cashbackSubtitle': '+ 10-Min Morning Delivery in Ghatampur',
        'disclaimerText': '*Handpicked daily from verified local farms.',
      }),
      gradient: 'from-emerald-50 via-teal-50 to-emerald-100',
      type: 'grocery',
      imageUrl: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80',
      linkUrl: '/category/fruits-vegetables',
      sortOrder: 1,
      isActive: true,
      extraData: const {
        'cardType': 'hero',
        'eyebrowTag': '🌿 100% ORGANIC HARVEST',
        'primaryBrand': 'FASTKIRANA',
        'secondaryBrand': 'LOCAL FARMS',
        'ctaText': 'SHOP FRESH GREENS',
        'ctaUrl': '/category/fruits-vegetables',
        'ctaBgColorHex': '#059669',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 35% OFF',
        'cashbackSubtitle': '+ 10-Min Morning Delivery in Ghatampur',
        'disclaimerText': '*Handpicked daily from verified local farms.',
      },
    ),
    Banner(
      id: 'grocery-essentials-bento-grid',
      title: 'DAILY PANTRY STAPLES',
      description: 'Dairy Milk, Farm Eggs, Atta & Cooking Oils',
      code: jsonEncode({
        'cardType': 'bento_grid',
        'eyebrowTag': '⚡ 10-MIN EXPRESS PANTRY',
        'primaryBrand': 'DAILY ESSENTIALS',
        'ctaText': 'STOCK UP PANTRY',
        'ctaUrl': '/category/dairy-bread-eggs',
        'ctaBgColorHex': '#2563EB',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 60% OFF',
        'cashbackSubtitle': 'Zero Minimum Order Value Required',
        'disclaimerText': '*Guaranteed fresh batch or instant refund.',
        'gridImages': [
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
          'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
          'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80',
        ],
      }),
      gradient: 'from-sky-50 via-blue-50 to-indigo-50',
      type: 'grocery',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
      linkUrl: '/category/dairy-bread-eggs',
      sortOrder: 2,
      isActive: true,
      extraData: const {
        'cardType': 'bento_grid',
        'eyebrowTag': '⚡ 10-MIN EXPRESS PANTRY',
        'primaryBrand': 'DAILY ESSENTIALS',
        'ctaText': 'STOCK UP PANTRY',
        'ctaUrl': '/category/dairy-bread-eggs',
        'ctaBgColorHex': '#2563EB',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 60% OFF',
        'cashbackSubtitle': 'Zero Minimum Order Value Required',
        'disclaimerText': '*Guaranteed fresh batch or instant refund.',
        'gridImages': [
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
          'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
          'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80',
        ],
      },
    ),
    Banner(
      id: 'grocery-snacks-editorial',
      title: 'BUY 1 GET 1 FREE',
      description: 'Cadbury Silk, Lays Maxx, Ice Creams & Sodas',
      code: jsonEncode({
        'cardType': 'editorial',
        'eyebrowTag': '🎉 CRAVINGS UNLOCKED',
        'primaryBrand': 'SNACKS & MUNCHIES',
        'secondaryBrand': 'SWEET & SAVORY',
        'ctaText': 'GRAB SWEET DEALS',
        'ctaUrl': '/category/snacks-munchies',
        'ctaBgColorHex': '#7C3AED',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': '+ EXTRA 20% OFF',
        'cashbackSubtitle': 'Use code SNACK20 at checkout',
        'disclaimerText': '*Delivered cold & chilled in thermal bags.',
      }),
      gradient: 'from-purple-50 via-violet-50 to-fuchsia-50',
      type: 'grocery',
      imageUrl: 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=800&q=80',
      linkUrl: '/category/snacks-munchies',
      sortOrder: 3,
      isActive: true,
      extraData: const {
        'cardType': 'editorial',
        'eyebrowTag': '🎉 CRAVINGS UNLOCKED',
        'primaryBrand': 'SNACKS & MUNCHIES',
        'secondaryBrand': 'SWEET & SAVORY',
        'ctaText': 'GRAB SWEET DEALS',
        'ctaUrl': '/category/snacks-munchies',
        'ctaBgColorHex': '#7C3AED',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': '+ EXTRA 20% OFF',
        'cashbackSubtitle': 'Use code SNACK20 at checkout',
        'disclaimerText': '*Delivered cold & chilled in thermal bags.',
      },
    ),
  ];

  static final List<Banner> defaultFoodBanners = [
    Banner(
      id: 'official-food-brand-card',
      title: 'CRAVING SPECIALS',
      description: 'Royal Biryani, Butter Paneer, Naan & Chicken Tikka',
      code: jsonEncode({
        'cardType': 'hero',
        'eyebrowTag': '🍱 CRAVING SPECIALS',
        'primaryBrand': 'FASTKIRANA FOOD',
        'secondaryBrand': 'RESTAURANTS',
        'ctaText': 'ORDER NOW',
        'ctaUrl': '/category/food',
        'ctaBgColorHex': '#D97706',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 60% OFF',
        'cashbackSubtitle': '+ Hot & Fresh Delivery',
        'disclaimerText': '*Delivered fresh from top kitchens.',
      }),
      gradient: 'from-amber-600 via-orange-500 to-yellow-500',
      type: 'food',
      imageUrl: '/banners/fastkirana-restaurant-brand-card.jpg',
      linkUrl: '/category/food',
      sortOrder: 0,
      isActive: true,
      extraData: const {
        'cardType': 'hero',
        'eyebrowTag': '🍱 CRAVING SPECIALS',
        'primaryBrand': 'FASTKIRANA FOOD',
        'secondaryBrand': 'RESTAURANTS',
        'ctaText': 'ORDER NOW',
        'ctaUrl': '/category/food',
        'ctaBgColorHex': '#D97706',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 60% OFF',
        'cashbackSubtitle': '+ Hot & Fresh Delivery',
        'disclaimerText': '*Delivered fresh from top kitchens.',
      },
    ),
    Banner(
      id: 'food-burger-dark-hero',
      title: 'DOUBLE SMOKED BURGER',
      description: 'Crispy Patty • Melted Aged Cheddar • Truffle Aioli',
      code: jsonEncode({
        'cardType': 'hero',
        'eyebrowTag': '🔥 CHEF SPECIAL DROP',
        'primaryBrand': 'A.S. RESTAURANT',
        'secondaryBrand': 'GHATAMPUR',
        'ctaText': 'ORDER HOT BURGERS',
        'ctaUrl': '/restaurant/as-restaurant',
        'ctaBgColorHex': '#EA580C',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 40% OFF',
        'cashbackSubtitle': '+ Extra ₹50 on UPI Payment',
        'disclaimerText': '*Hot & crispy delivery in 15 mins across Ghatampur.',
      }),
      gradient: 'from-amber-50 via-orange-50 to-orange-100',
      type: 'food',
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
      linkUrl: '/restaurant/as-restaurant',
      sortOrder: 1,
      isActive: true,
      extraData: const {
        'cardType': 'hero',
        'eyebrowTag': '🔥 CHEF SPECIAL DROP',
        'primaryBrand': 'A.S. RESTAURANT',
        'secondaryBrand': 'GHATAMPUR',
        'ctaText': 'ORDER HOT BURGERS',
        'ctaUrl': '/restaurant/as-restaurant',
        'ctaBgColorHex': '#EA580C',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'FLAT 40% OFF',
        'cashbackSubtitle': '+ Extra ₹50 on UPI Payment',
        'disclaimerText': '*Hot & crispy delivery in 15 mins across Ghatampur.',
      },
    ),
    Banner(
      id: 'food-cuisines-bento-grid',
      title: 'GHATAMPUR TOP BITES',
      description: 'Wood-Fired Pizza, Dum Biryani, Frankie Rolls & Thick Shakes',
      code: jsonEncode({
        'cardType': 'bento_grid',
        'eyebrowTag': '🍽️ MOST ORDERED CUISINES',
        'ctaText': 'EXPLORE CUISINES',
        'ctaUrl': '/category/fast-food',
        'ctaBgColorHex': '#F97316',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 50% OFF',
        'cashbackSubtitle': 'FastKirana Food Pass Exclusive Deals',
        'disclaimerText': '*Delivered fresh from top verified kitchens.',
        'gridImages': [
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
          'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80',
          'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80',
        ],
      }),
      gradient: 'from-orange-50 via-amber-50 to-orange-100',
      type: 'food',
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
      linkUrl: '/category/fast-food',
      sortOrder: 2,
      isActive: true,
      extraData: const {
        'cardType': 'bento_grid',
        'eyebrowTag': '🍽️ MOST ORDERED CUISINES',
        'ctaText': 'EXPLORE CUISINES',
        'ctaUrl': '/category/fast-food',
        'ctaBgColorHex': '#F97316',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': 'UP TO 50% OFF',
        'cashbackSubtitle': 'FastKirana Food Pass Exclusive Deals',
        'disclaimerText': '*Delivered fresh from top verified kitchens.',
        'gridImages': [
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
          'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80',
          'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80',
        ],
      },
    ),
    Banner(
      id: 'food-wedson-editorial',
      title: 'ROYAL INDIAN FEAST',
      description: 'Slow-Cooked Dum Biryani, Shahi Paneer & Butter Naan Combos',
      code: jsonEncode({
        'cardType': 'editorial',
        'eyebrowTag': '✨ ROYAL MUGHALAI FEAST',
        'primaryBrand': 'WEDSON RESTAURANT',
        'secondaryBrand': 'ROYAL KITCHEN',
        'ctaText': 'VIEW ROYAL MENU',
        'ctaUrl': '/restaurant/wedson-restaurant',
        'ctaBgColorHex': '#E11D48',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': '+ EXTRA ₹100 OFF',
        'cashbackSubtitle': 'Use code WEDSON100 at checkout',
        'disclaimerText': '*Special family thalis & party packs.',
      }),
      gradient: 'from-rose-50 via-amber-50 to-orange-50',
      type: 'food',
      imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80',
      linkUrl: '/restaurant/wedson-restaurant',
      sortOrder: 3,
      isActive: true,
      extraData: const {
        'cardType': 'editorial',
        'eyebrowTag': '✨ ROYAL MUGHALAI FEAST',
        'primaryBrand': 'WEDSON RESTAURANT',
        'secondaryBrand': 'ROYAL KITCHEN',
        'ctaText': 'VIEW ROYAL MENU',
        'ctaUrl': '/restaurant/wedson-restaurant',
        'ctaBgColorHex': '#B91C1C',
        'ctaTextColorHex': '#FFFFFF',
        'cashbackTitle': '+ EXTRA ₹100 OFF',
        'cashbackSubtitle': 'Use code WEDSON100 at checkout',
        'disclaimerText': '*Special family thalis & party packs.',
      },
    ),
  ];

  static List<Banner> get defaultBanners => defaultGroceryBanners;

  Future<List<Banner>> getBanners({String? type, bool forceRefresh = false}) async {
    final key = type ?? 'all';

    // 1. In-memory cache hit
    if (!forceRefresh && _inMemoryBanners[key] != null && _inMemoryBanners[key]!.isNotEmpty) {
      return _inMemoryBanners[key]!;
    }

    // 2. Disk cache hit (instant 0ms hydration + async background refresh)
    if (!forceRefresh) {
      final diskBanners = await _loadBannersFromDisk(key);
      if (diskBanners != null && diskBanners.isNotEmpty) {
        _inMemoryBanners[key] = diskBanners;
        _fetchFromNetwork(type: type);
        return diskBanners;
      }
    }

    // 3. Network fetch (first load or pull-to-refresh)
    final networkBanners = await _fetchFromNetwork(type: type);
    if (networkBanners != null && networkBanners.isNotEmpty) {
      _inMemoryBanners[key] = networkBanners;
      return networkBanners;
    }

    // 4. Fallback to bundled real banners segregated by type
    final fallbacks = (type == 'food' || type == 'cafe')
        ? defaultFoodBanners
        : defaultGroceryBanners;
    _inMemoryBanners[key] = fallbacks;
    return fallbacks;
  }

  Future<List<Banner>?> _fetchFromNetwork({String? type}) async {
    final key = type ?? 'all';
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
          _inMemoryBanners[key] = banners;
          await _saveBannersToDisk(key, banners);
          return banners;
        }
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
      if (raw == null || raw.isEmpty) return null;
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
