import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/logger_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_cached_image.dart';
import '../../widgets/card_media_widget.dart';

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
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/home_layout_config.dart';
import '../../providers/home_layout_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final bool forceHome;

  const SplashScreen({super.key, this.forceHome = false});

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
    if (!widget.forceHome) {
      _requestAppPermissions();
    }

    // 0. Pre-load local festive campaign instantly so Frame 1 is never empty
    initCampaignCache();

    // 1. Hydrate cached address immediately & warm up GPS location + nearest store hub concurrently
    final locationFuture = (() async {
      if (LocationService.cachedAddress == null) {
        await LocationService.loadCachedAddress();
      }
      await LocationService.bootstrapUserLocation(ref);
    })().timeout(const Duration(milliseconds: 1500), onTimeout: () {});

    // 2. Warm up active store hubs, categories, catalog, banners, and festive campaign concurrently during splash
    final prefFuture = SharedPreferences.getInstance();
    ref.read(activeStoreHubsProvider.future).catchError((_) => <StoreHub>[]);
    final categoriesFuture =
        ref.read(categoriesProvider.future).catchError((_) => <Category>[]);
    final catalogFuture =
        ref.read(homeProductCatalogProvider.future).catchError((_) => <Product>[]);
    final bannersFuture =
        ref.read(bannersProvider('grocery').future).catchError((_) => <Banner>[]);
    final campaignFuture =
        ref.read(navratriDataProvider.future).then<NavratriData?>((v) => v).catchError((_) => null);
    final homeLayoutFuture =
        ref.read(homeLayoutConfigProvider.future).catchError((_) => const HomeLayoutConfigModel());

    // 3. Texture Precaching:
    // Pre-cache top 12 category packshots, first 2 hero banners, and top 16 product images
    // with exact memory downsampling and cache managers so Home opens with images ready on Frame 0.
    final categoryPrecacheFuture = categoriesFuture.then((categories) async {
      if (!mounted || categories.isEmpty) return;
      final tasks = <Future<void>>[];
      for (final cat in categories.take(12)) {
        final imgUrl = CategoryVisualHelper.resolveRealisticImageUrl(cat);
        if (imgUrl.isNotEmpty) {
          tasks.add(
            precacheImage(
              CachedNetworkImageProvider(
                imgUrl,
                cacheManager: FastKiranaImageCacheManager.instance,
                maxWidth: 400,
                maxHeight: 400,
              ),
              context,
            ).catchError((_) {}),
          );
        }
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
    }).timeout(const Duration(milliseconds: 3000), onTimeout: () {}).catchError((_) {});

    final bannerPrecacheFuture = bannersFuture.then((banners) async {
      if (!mounted || banners.isEmpty) return;
      final tasks = <Future<void>>[];
      for (final banner in banners.take(2)) {
        final rawImg = banner.imageUrl;
        if (rawImg != null && rawImg.trim().isNotEmpty) {
          final resolvedUrl = CardMediaWidget.resolveUrl(rawImg);
          tasks.add(
            precacheImage(
              CachedNetworkImageProvider(
                resolvedUrl,
                cacheManager: FastKiranaImageCacheManager.instance,
                maxWidth: 1080,
                maxHeight: 1440,
              ),
              context,
            ).catchError((_) {}),
          );
        }
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
    }).timeout(const Duration(milliseconds: 3000), onTimeout: () {}).catchError((_) {});

    final catalogPrecacheFuture = catalogFuture.then((products) async {
      if (!mounted || products.isEmpty) return;
      final tasks = <Future<void>>[];
      for (final p in products.take(16)) {
        final rawImg = p.imageUrl;
        if (rawImg != null && rawImg.trim().isNotEmpty && !rawImg.startsWith('data:')) {
          tasks.add(
            AppCachedImage.precache(context, rawImg).catchError((_) {}),
          );
        }
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
    }).timeout(const Duration(milliseconds: 3500), onTimeout: () {}).catchError((_) {});

    campaignFuture.then((campaign) {
      if (mounted && campaign != null) {
        if (campaign.headers.isNotEmpty) {
          final firstHeader = campaign.headers.first;
          if (firstHeader.image != null && firstHeader.image!.isNotEmpty) {
            try {
              precacheImage(
                CachedNetworkImageProvider(
                  CardMediaWidget.resolveUrl(firstHeader.image!),
                  cacheManager: FastKiranaImageCacheManager.instance,
                ),
                context,
              ).catchError((_) {});
            } catch (_) {}
          }
        }
      }
    }).catchError((_) {});

    // 4. Wait for smooth splash animation AND essential metadata + decoded images
    final minDelay = Duration(milliseconds: widget.forceHome ? 400 : 700);
    Future.wait([
      Future.delayed(minDelay),
      prefFuture,
      locationFuture,
      categoryPrecacheFuture,
      bannerPrecacheFuture,
      catalogPrecacheFuture,
      campaignFuture,
      homeLayoutFuture,
    ]).then((results) {
      final prefs = results[1] as SharedPreferences;
      _safeNavigate(prefs: prefs);
    }).catchError((_) {
      _safeNavigate();
    });

    // 5. Failsafe Watchdog: App will never stay stuck on splash screen
    Future.delayed(Duration(milliseconds: widget.forceHome ? 4500 : 3500), () {
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

      if (widget.forceHome) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      }

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Center(
              child: BlinkitAnimatedBag(
                title: '100% Farm-Fresh Fruits & Vegetables',
                subtitle: 'Delivered fresh at your doorstep with superfast delivery',
                showBottomBranding: false,
              ),
            ),
            const Spacer(),

            // Dedicated Bottom Dock ("niche alag")
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE11D48),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'FASTMINUTE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.8,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trusted Quick Commerce',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
