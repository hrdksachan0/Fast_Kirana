import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class GroceryFoodTabSlider extends StatefulWidget {
  final int initialIndex;
  final Function(int) onTabChanged;

  const GroceryFoodTabSlider({
    super.key,
    this.initialIndex = 0,
    required this.onTabChanged,
  });

  @override
  State<GroceryFoodTabSlider> createState() => _GroceryFoodTabSliderState();
}

class _GroceryFoodTabSliderState extends State<GroceryFoodTabSlider> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated background indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 4,
            bottom: 4,
            left: _selectedIndex == 0 ? 4 : null,
            right: _selectedIndex == 1 ? 4 : null,
            width: MediaQuery.of(context).size.width / 2 - 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: _selectedIndex == 0
                    ? AppTheme.primary.withOpacity(0.08)
                    : AppTheme.cafeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Tab buttons
          Row(
            children: [
              Expanded(
                child: _TabButton(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Grocery',
                  isSelected: _selectedIndex == 0,
                  color: AppTheme.primary,
                  onTap: () {
                    if (_selectedIndex != 0) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIndex = 0);
                      widget.onTabChanged(0);
                    }
                  },
                ),
              ),
              Expanded(
                child: _TabButton(
                  icon: Icons.restaurant_outlined,
                  label: 'Food',
                  isSelected: _selectedIndex == 1,
                  color: AppTheme.cafeAccent,
                  onTap: () {
                    if (_selectedIndex != 1) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIndex = 1);
                      widget.onTabChanged(1);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : AppTheme.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
