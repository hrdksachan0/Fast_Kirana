import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/floating_cart_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/battery_optimization_service.dart';
import 'home_screen.dart';
import '../search/search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  bool _isBottomNavVisible = true;
  Timer? _autoShowTimer;
  bool _batteryCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        NotificationService().registerDeviceToken(ref.read(dioProvider));
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-register any pending FCM token when the app comes to foreground
      _reRegisterPendingToken();

      // Prompt battery optimization exemption once (Android only)
      if (!_batteryCheckDone) {
        _batteryCheckDone = true;
        BatteryOptimizationService.ensureExempt();
      }
    }
  }

  Future<void> _reRegisterPendingToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString('pending_fcm_token');
      if (pending == null || pending.isEmpty) return;

      final authToken = prefs.getString('auth_token');
      if (authToken == null) return;

      final dio = ref.read(dioProvider);
      final deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      final response = await dio.post(
        '/api/fcm/register',
        data: {'token': pending, 'deviceType': deviceType},
      );
      if (response.statusCode == 200) {
        await prefs.remove('pending_fcm_token');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoShowTimer?.cancel();
    super.dispose();
  }

  void _onUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      // User scrolling DOWN -> Hide bottom nav bar
      _autoShowTimer?.cancel();
      if (_isBottomNavVisible) {
        setState(() => _isBottomNavVisible = false);
      }
      // Re-appear automatically after 1 second of pausing/stopping
      _autoShowTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && !_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = true);
        }
      });
    } else if (notification.direction == ScrollDirection.forward) {
      // User scrolling UP -> Show bottom nav bar immediately
      _autoShowTimer?.cancel();
      if (!_isBottomNavVisible) {
        setState(() => _isBottomNavVisible = true);
      }
    } else if (notification.direction == ScrollDirection.idle) {
      // Idle -> Bring it back after 1 second
      _autoShowTimer?.cancel();
      _autoShowTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && !_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // 4 Standard Tabs matching Web: Home · Search · Category · Account
    final screens = const [
      HomeScreen(),
      SearchScreen(),
      CategoriesScreen(),
      ProfileScreen(),
    ];

    final cartAsync = ref.watch(cartProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            _onUserScroll(notification);
            return false;
          },
          child: Stack(
            children: [
              IndexedStack(
                index: selectedIndex,
                children: screens,
              ),

              // Slim Modern Floating Sticky Cart Bar (Shared across all pages)
              FloatingCartBar(bottomOffset: _isBottomNavVisible ? (bottomPadding + 76) : (bottomPadding + 16)),

              // Liquid Flow Glass Bottom Navigation (Auto Hide & Auto Reveal in 1s)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: _isBottomNavVisible ? (bottomPadding + 12) : -(bottomPadding + 90),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  opacity: _isBottomNavVisible ? 1.0 : 0.0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildLiquidBottomNav(context, ref, selectedIndex),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidBottomNav(BuildContext context, WidgetRef ref, int selectedIndex) {
    final navItems = [
      {'label': 'Home', 'icon': Icons.home_outlined},
      {'label': 'Search', 'icon': Icons.search_rounded},
      {'label': 'Category', 'icon': Icons.grid_view_rounded},
      {'label': 'Account', 'icon': Icons.person_outline_rounded},
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = (screenWidth * 0.92).clamp(320.0, 420.0);
    final tabWidth = (navWidth - 12) / 4;

    return Container(
      width: navWidth,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Liquid Water Droplet Active Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: 6 + (selectedIndex * tabWidth),
                top: 8,
                child: Container(
                  width: tabWidth,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        const Color(0xFFF3F4F6).withOpacity(0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive Tabs Row
              Row(
                children: List.generate(navItems.length, (index) {
                  final isSelected = selectedIndex == index;
                  final item = navItems[index];

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(selectedTabProvider.notifier).state = index;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                item['icon'] as IconData,
                                size: 21,
                                color: isSelected ? const Color(0xFFF33B30) : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFFF33B30) : const Color(0xFF9CA3AF),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}