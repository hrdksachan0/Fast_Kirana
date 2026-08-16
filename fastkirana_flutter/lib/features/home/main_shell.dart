import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/cart_provider.dart';
import 'home_screen.dart';
import '../search/search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // 4 Standard Tabs matching Web: Home · Search · Category · Account
    final screens = const [
      HomeScreen(),
      SearchScreen(),
      CategoriesScreen(),
      ProfileScreen(),
    ];

    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
            children: screens,
          ),

          // Slim Modern Floating Sticky Cart Bar (visible on Home, Search & Category tabs when cart has items)
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 76,
            child: cartAsync.when(
              data: (cart) {
                if (cart.items.isEmpty) return const SizedBox.shrink();
                final total = cart.subtotal;
                final itemCount = cart.totalItems;

                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8153A), Color(0xFFFF2D55), Color(0xFFFF4742)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8153A).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Navigate to Cart
                      Navigator.pushNamed(context, '/cart');
                    },
                    child: Row(
                      children: [
                        // Bag Icon Pill
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} • ₹${total.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              total >= 200 ? '✨ Free delivery unlocked' : 'Add ₹${(200 - total).clamp(0, 200).toInt()} for FREE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VIEW CART',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFE8153A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFFE8153A)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
            
          // Liquid Flow Glass Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildLiquidBottomNav(context, ref, selectedIndex),
            ),
          ),
        ],
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