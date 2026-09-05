import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/floating_order_tracking_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import 'home_screen.dart';
import '../search/search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/picker_dashboard.dart';
import '../cafe/restaurant_dashboard.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  bool _isBottomNavVisible = true;
  Timer? _autoShowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        try {
          NotificationService().registerDeviceToken(ref.read(dioProvider));
        } catch (e, _) { LoggerService.error('MainShell: silent catch', e); }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-register any pending FCM token when the app comes to foreground
      if (!kIsWeb) {
        _reRegisterPendingToken();
      }
    }
  }

  Future<void> _reRegisterPendingToken() async {
    if (kIsWeb) return;
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
    } catch (e, _) { LoggerService.error('MainShell: silent catch', e); }
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

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = (user?.role ?? 'USER').toUpperCase();

    final isAdmin = role == 'ADMIN';
    final isRiderOnly = !isAdmin && (
      role == 'RIDER' ||
      role == 'DELIVERY' ||
      role == 'DELIVERY_PARTNER'
    );
    final isChefOrOwnerOnly = !isAdmin && (
      role == 'CHEF' ||
      role == 'RESTAURANT_OWNER' ||
      role == 'RESTAURANT'
    );
    final isPickerOnly = !isAdmin && (role == 'PICKER');

    // ─── STAFF DEDICATED CONSOLES ───────────────────────────
    // Riders, Restaurant Chefs/Owners, and Pickers only see their respected console
    if (isRiderOnly) {
      return const DeliveryDashboard();
    }
    if (isChefOrOwnerOnly) {
      return const RestaurantDashboard();
    }
    if (isPickerOnly) {
      return const PickerDashboard();
    }

    final selectedIndex = ref.watch(selectedTabProvider);

    // 4 Standard Tabs matching Web: Home · Search · Category · Account
    const screens = [
      HomeScreen(),
      SearchScreen(),
      CategoriesScreen(),
      ProfileScreen(),
    ];

    final cart = ref.watch(cartProvider).valueOrNull;
    final cartCount = cart?.items.fold<int>(0, (s, item) => s + item.quantity) ?? 0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBaseBottom = bottomPadding > 0 ? bottomPadding + 6 : 10.0;
    const navHeight = 58.0;
    final navTop = navBaseBottom + navHeight;

    final cartBottomOffset = navTop + 8.0;
    final trackingBottomOffset = cartCount > 0 ? (cartBottomOffset + 54.0) : cartBottomOffset;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentTab = ref.read(selectedTabProvider);
        if (currentTab != 0) {
          // If on Search, Categories, or Account -> jump back to Home tab
          HapticFeedback.lightImpact();
          ref.read(selectedTabProvider.notifier).state = 0;
          return;
        }

        // On Home tab -> require double back press to exit app
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Press back again to exit FastKirana',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppDesignSystem.slate800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }

        // User confirmed exit
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppDesignSystem.background,
        body: ResponsiveContainer(
          maxWidth: Responsive.wideMaxContentWidth,
          fillHeight: true,
          child: Stack(
            children: [
              IndexedStack(
                index: selectedIndex,
                children: screens,
              ),

              // Floating Order Tracking Pill (Stacked cleanly above Floating Cart)
              FloatingOrderTrackingBar(bottomOffset: trackingBottomOffset),

              // Slim Modern Floating Sticky Cart Bar (Docked right above Bottom Navigation)
              FloatingCartBar(bottomOffset: cartBottomOffset),

              // Liquid Flow Glass Bottom Navigation (Always accessible, rock solid)
              Positioned(
                left: 0,
                right: 0,
                bottom: navBaseBottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildLiquidBottomNav(context, ref, selectedIndex),
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
      {
        'label': 'Home',
        'activeIcon': Icons.home_rounded,
        'inactiveIcon': Icons.home_outlined,
      },
      {
        'label': 'Search',
        'activeIcon': Icons.search_rounded,
        'inactiveIcon': Icons.search_rounded,
      },
      {
        'label': 'Category',
        'activeIcon': Icons.grid_view_rounded,
        'inactiveIcon': Icons.grid_view_outlined,
      },
      {
        'label': 'Account',
        'activeIcon': Icons.person_rounded,
        'inactiveIcon': Icons.person_outline_rounded,
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = (screenWidth * 0.92).clamp(320.0, 420.0);
    final tabWidth = (navWidth - 12) / 4;

    return Container(
      width: navWidth,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppDesignSystem.slate200),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Liquid Water Droplet Active Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: 6 + (selectedIndex * tabWidth),
                top: 8,
                child: Container(
                  width: tabWidth,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusCancelled,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppDesignSystem.rose200),
                    boxShadow: [
                      BoxShadow(
                        color: AppDesignSystem.red600.withValues(alpha: 0.06),
                        blurRadius: 8,
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
                                (isSelected ? item['activeIcon'] : item['inactiveIcon']) as IconData,
                                size: 21,
                                color: isSelected ? AppDesignSystem.red600 : AppDesignSystem.slate400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? AppDesignSystem.red600 : AppDesignSystem.slate400,
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
    );
  }
}