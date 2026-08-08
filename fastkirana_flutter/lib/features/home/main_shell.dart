import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/cart_provider.dart';
import 'home_screen.dart';
import '../categories/categories_screen.dart';
import '../cart/cart_screen.dart';
import '../orders/orders_screen.dart';
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
      OrdersScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(context, ref, selectedIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, int selectedIndex) {
    const primaryRed = Color(0xFFB50017);
    const textMuted = Color(0xFF9D4852);

    final items = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded, 'label': 'HOME'},
      {'icon': Icons.search_rounded, 'activeIcon': Icons.search_rounded, 'label': 'SEARCH'},
      {'icon': Icons.grid_view_outlined, 'activeIcon': Icons.grid_view_rounded, 'label': 'CATEGORIES'},
      {'icon': Icons.account_circle_outlined, 'activeIcon': Icons.account_circle_rounded, 'label': 'ACCOUNT'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFCF8F8),
        border: Border(top: BorderSide(color: Color(0xFFF4E7E8))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedTabProvider.notifier).state = index;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? (items[index]['activeIcon'] as IconData) : (items[index]['icon'] as IconData),
                        size: 24,
                        color: isSelected ? primaryRed : textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[index]['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? primaryRed : textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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