import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/cart_provider.dart';
import 'home_screen.dart';
import '../categories/categories_screen.dart';
import '../cart/cart_screen.dart';
import '../profile/profile_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    final screens = const [
      HomeScreen(),
      CategoriesScreen(),
      CartScreen(),
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

          // Floating Cart Bar overlay (visible on Home & Categories tab when cart has items)
          if (selectedIndex != 2) // Hide on Cart tab itself
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 84,
              child: cartAsync.when(
                data: (cart) {
                  if (cart.items.isEmpty) return const SizedBox.shrink();
                  final total = cart.subtotal;
                  final itemCount = cart.totalItems;

                  return Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE20A22), // FastKirana Primary Brand Red
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE20A22).withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTabProvider.notifier).state = 2; // Switch to Cart tab
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '₹${total.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                'View Cart',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                            ],
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
            
          // Floating Pill Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomNav(context, ref, selectedIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, int selectedIndex) {
    const textMuted = Color(0xFF9CA3AF);

    final items = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded},
      {'icon': Icons.grid_view_outlined, 'activeIcon': Icons.grid_view_rounded},
      {'icon': Icons.shopping_cart_outlined, 'activeIcon': Icons.shopping_cart_rounded},
      {'icon': Icons.person_outline, 'activeIcon': Icons.person_rounded},
    ];

    final cartState = ref.watch(cartProvider);
    final cartCount = cartState.value?.totalItems ?? 0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      constraints: const BoxConstraints(maxWidth: 420),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = selectedIndex == index;
              final isCartTab = index == 2;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedTabProvider.notifier).state = index;
                  },
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE20A22) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? (items[index]['activeIcon'] as IconData) : (items[index]['icon'] as IconData),
                            size: 24,
                            color: isSelected ? Colors.white : textMuted,
                          ),
                          if (isCartTab && cartCount > 0)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : const Color(0xFFE20A22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$cartCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? const Color(0xFFE20A22) : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}