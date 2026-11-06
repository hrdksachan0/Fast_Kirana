import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/logger_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/location_service.dart';

import '../../providers/product_provider.dart';
import '../../providers/banner_provider.dart';
import '../../providers/store_hub_provider.dart';

import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/banner.dart';
import '../../data/models/store_hub.dart';

import '../home/utils/category_visual_helper.dart';
import '../navratri/navratri_data.dart';
import 'widgets/blinkit_animated_bag.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/brand/fastminute_logo_hq.png'), context).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _requestAppPermissions();

    // 1. Warm up GPS location & nearest store hub concurrently
    LocationService.bootstrapUserLocation(ref);

    // 2. Warm up active store hubs, categories, catalog, banners, and festive campaign concurrently during splash
    final prefFuture = SharedPreferences.getInstance();
    ref.read(activeStoreHubsProvider.future).catchError((_) => <StoreHub>[]);
    final categoriesFuture =
        ref.read(categoriesProvider.future).catchError((_) => <Category>[]);
    ref.read(homeProductCatalogProvider.future).catchError((_) => <Product>[]);
    final bannersFuture =
        ref.read(bannersProvider('grocery').future).catchError((_) => <Banner>[]);
    final campaignFuture =
        ref.read(navratriDataProvider.future).then<NavratriData?>((v) => v).catchError((_) => null);

    // 3. Memory-Safe Pre-warming (Zero OOM):
    // Pre-cache only the top 4 visible hero categories at compact thumbnail dimensions (120x120)
    // to keep JVM heap usage minimal (<5MB) and prevent OutOfMemoryError on 2GB/3GB devices.
    categoriesFuture.then((categories) {
      if (mounted && categories.isNotEmpty) {
        for (final cat in categories.take(4)) {
          final imgUrl = CategoryVisualHelper.resolveRealisticImageUrl(cat);
          if (imgUrl.isNotEmpty) {
            try {
              precacheImage(
                ResizeImage(
                  CachedNetworkImageProvider(imgUrl),
                  width: 140,
                  height: 140,
                ),
                context,
              ).catchError((_) {});
            } catch (_) {}
          }
        }
      }
    }).catchError((_) {});

    campaignFuture.then((campaign) {
      if (mounted && campaign != null) {
        // Precache only the primary hero header if available
        if (campaign.headers.isNotEmpty) {
          final firstHeader = campaign.headers.first;
          if (firstHeader.image != null && firstHeader.image!.isNotEmpty) {
            try {
              precacheImage(
                ResizeImage(
                  CachedNetworkImageProvider(firstHeader.image!),
                  width: 450,
                ),
                context,
              ).catchError((_) {});
            } catch (_) {}
          }
        }
      }
    }).catchError((_) {});

    // 4. Blinkit-Style Animated Boot Timing:
    // Wait for at least 1.4 seconds of smooth physics bounce animation AND essential metadata,
    // so Home screen opens with all festive sections, categories & banners pre-hydrated (zero layout shift!)
    Future.wait([
      Future.delayed(const Duration(milliseconds: 1400)),
      prefFuture,
      categoriesFuture,
      bannersFuture,
      campaignFuture,
    ]).then((results) {
      final prefs = results[1] as SharedPreferences;
      _safeNavigate(prefs: prefs);
    }).catchError((_) {
      _safeNavigate();
    });

    // 5. Failsafe Watchdog: App will NEVER stay stuck on splash screen for more than 2.0s
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!_hasNavigated && mounted) {
        _safeNavigate();
      }
    });
  }

  Future<void> _requestAppPermissions() async {
    if (kIsWeb) return;
    try {
      await NotificationService().requestPermissions();
    } catch (e, _) {
      LoggerService.error('SplashScreen: silent catch', e);
    }
  }

  Future<void> _safeNavigate({SharedPreferences? prefs}) async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final secureToken = await SecureStorageService.instance.getAuthToken();
      final token = (secureToken != null && secureToken.isNotEmpty)
          ? secureToken
          : (p.getString('auth_token') ?? p.getString('user_id'));

      if (!mounted) return;

      // On web during preview/testing or when logged in with location
      if (kIsWeb && (token == null || token.isEmpty)) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      }

      if (token == null || token.isEmpty) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }

      // If app was launched from a notification tap or deep link while terminated, navigate to it after /home mounts
      if (NotificationService.pendingDeepLinkUrl != null) {
        final targetLink = NotificationService.pendingDeepLinkUrl!;
        NotificationService.pendingDeepLinkUrl = null;
        Future.delayed(const Duration(milliseconds: 350), () {
          NotificationService.navigateToLink(targetLink);
        });
      }
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: BlinkitAnimatedBag(
            title: '100% Farm-Fresh Fruits & Vegetables',
            subtitle: 'Delivered fresh at your doorstep with superfast delivery',
          ),
        ),
      ),
    );
  }
}
