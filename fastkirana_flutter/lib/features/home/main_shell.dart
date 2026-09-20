import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
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
import '../../core/services/secure_storage_service.dart';
import '../../core/services/location_service.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        try {
          NotificationService().registerDeviceToken(ref.read(dioProvider));
        } catch (e, _) { LoggerService.error('MainShell: _reRegisterPendingToken', e); }

        // Automatically detect device GPS and set nearest store hub on launch
        LocationService.bootstrapUserLocation(ref);
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

      final authToken = await SecureStorage.read('auth_token');
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
    } catch (e, _) { LoggerService.error('MainShell: _reRegisterPendingToken', e); }
  }

  @override
  void dispose() {
    super.dispose();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = (user?.role ?? 'USER').toUpperCase();

    final isMasterAdmin = (user?.email == 'admin@fastkirana.com' ||
        user?.email == 'superadmin@fastkirana.com' ||
        (user?.phone ?? '').contains('7054470303') ||
        (user?.phone ?? '').contains('9170942500') ||
        role == 'ADMIN');
    final isAdmin = isMasterAdmin;
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
      return RestaurantDashboard(
        initialRestaurantId: user?.assignedRestaurantId,
      );
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

    final showCart = selectedIndex != 3 && cartCount > 0;
    const cartBottomOffset = 10.0;
    final trackingBottomOffset = showCart ? (cartBottomOffset + 76.0) : cartBottomOffset;

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

              // Slim Modern Floating Sticky Cart Bar (Docked right above Bottom Navigation, hidden on Profile tab)
              if (selectedIndex != 3)
                const FloatingCartBar(bottomOffset: cartBottomOffset),
            ],
          ),
        ),
        bottomNavigationBar: _buildLiquidBottomNav(context, ref, selectedIndex),
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
    final navWidth = screenWidth.clamp(280.0, Responsive.wideMaxContentWidth);
    final tabWidth = navWidth / 4;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Center(
            child: SizedBox(
              width: navWidth,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Active Tab Highlight Capsule
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: (selectedIndex * tabWidth) + (tabWidth - 62) / 2,
                    top: 6,
                    child: Container(
                      width: 62,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusCancelled,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Interactive Tabs Row
                  Row(
                    children: List.generate(navItems.length, (index) {
                      final isSelected = selectedIndex == index;
                      final item = navItems[index];

                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(selectedTabProvider.notifier).state = index;
                          },
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
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
            ),
          ),
        ),
      ),
    );
  }
}