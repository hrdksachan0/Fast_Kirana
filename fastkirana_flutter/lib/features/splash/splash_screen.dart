import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/brand_logo.dart';

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
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
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

    // Fast, reliable 1.1s splash exit
    Future.delayed(const Duration(milliseconds: 1100), _safeNavigate);
  }

  Future<void> _requestAppPermissions() async {
    try {
      await NotificationService().requestPermissions();
    } catch (_) {}
  }

  Future<void> _safeNavigate() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('user_id');
      final hasChosenLocation = prefs.getBool('has_chosen_location') ?? false;

      if (!mounted) return;

      if (token == null || token.isEmpty) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (!hasChosenLocation) {
        Navigator.of(context).pushNamedAndRemoveUntil('/location', (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
              Color(0xFFE20A22), // Vibrant Brand Red
              Color(0xFFB80517), // Deep Crimson
              Color(0xFF88000F), // Dark Luxury Red
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
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFFE20A22).withOpacity(0.3),
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
                        fontSize: 36,
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
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'GROCERY • FOOD • ESSENTIALS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.92),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FASTKIRANA EXPRESS STORE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.65),
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