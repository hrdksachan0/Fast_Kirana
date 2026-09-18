import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' hide Banner;
import '../../core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/brand_logo.dart';
import '../../providers/product_provider.dart';
import '../../providers/banner_provider.dart';

import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/models/banner.dart';
import '../../data/models/store_hub.dart';
import '../../core/services/location_service.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../providers/store_hub_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoScale;
  late Animation<double> _contentFade;
  late Animation<double> _slideUp;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    _contentFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );

    _slideUp = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();
    _requestAppPermissions();

    // 1. Warm up GPS location & resolve nearest store hub concurrently
    final locationFuture = LocationService.getCurrentPosition().then((pos) async {
      if (pos != null) {
        final details = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        final addr = Address(
          id: 'gps_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'current',
          label: 'Current Location',
          houseNo: details.houseNo,
          street: details.street,
          area: details.area,
          city: details.city,
          pincode: details.pincode,
          latitude: details.latitude,
          longitude: details.longitude,
          isDefault: true,
        );
        ref.read(selectedAddressProvider.notifier).state = addr;
      }
    }).catchError((_) {});

    // 2. Warm up active store hubs, categories, catalog, and banners concurrently during splash
    final prefFuture = SharedPreferences.getInstance();
    final hubsFuture = ref.read(activeStoreHubsProvider.future).catchError((_) => <StoreHub>[]);
    final categoriesFuture = ref.read(categoriesProvider.future).catchError((_) => <Category>[]);
    final catalogFuture = ref.read(homeProductCatalogProvider.future).catchError((_) => <Product>[]);
    final bannersFuture = ref.read(bannersProvider('grocery').future).catchError((_) => <Banner>[]);

    // Keep splash active until essential catalog and auth are loaded (minimum 1200ms)
    Future.wait([
      Future.delayed(const Duration(milliseconds: 1200)),
      prefFuture,
      locationFuture,
      hubsFuture,
      categoriesFuture,
      catalogFuture,
      bannersFuture,
    ]).then((results) {
      final prefs = results[1] as SharedPreferences;
      _safeNavigate(prefs: prefs);
    }).catchError((_) {
      _safeNavigate();
    });

    // Guaranteed watchdog timeout: App will NEVER stay stuck on splash screen for more than 4.0s
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (!_hasNavigated && mounted) {
        _safeNavigate();
      }
    });
  }

  Future<void> _requestAppPermissions() async {
    if (kIsWeb) return;
    try {
      await NotificationService().requestPermissions();
    } catch (e, _) { LoggerService.error('SplashScreen: silent catch', e); }
  }

  Future<void> _safeNavigate({SharedPreferences? prefs}) async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final token = p.getString('auth_token') ?? p.getString('user_id');
      final hasChosenLocation = p.getBool('has_chosen_location') ?? false;

      if (!mounted) return;

      // On web during preview/testing or when logged in with location
      if (kIsWeb && (token == null || token.isEmpty)) {
        // Automatically allow web testing direct access to /home with fallback
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      }

      if (token == null || token.isEmpty) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (!hasChosenLocation) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/location',
          (route) => false,
          arguments: true,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppDesignSystem.primary, // Vibrant Brand Red
              AppDesignSystem.primaryDark, // Deep Crimson
              AppDesignSystem.primaryDark, // Dark Luxury Red
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // 1. High-Contrast Premium White Logo Card
              ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: AppDesignSystem.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: FastKiranaLogoWidget(size: 68),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 2. Brand Name & Premium Tagline
              AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _contentFade,
                    child: Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      'FastKirana',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 36),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Sleek Frosted Glass Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'GROCERY • FOOD • ESSENTIALS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Delivering Freshness to Your Doorstep',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // 3. Subtle Loading Ring & City Footer
              FadeTransition(
                opacity: _contentFade,
                child: Column(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FASTKIRANA EXPRESS STORE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}