import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class ProfileQuickStats extends StatelessWidget {
  final int ordersCount;
  final int wishlistCount;
  final int addressesCount;
  final bool isLoggedIn;
  final VoidCallback onOrdersTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddressesTap;

  const ProfileQuickStats({
    super.key,
    required this.ordersCount,
    required this.wishlistCount,
    required this.addressesCount,
    required this.isLoggedIn,
    required this.onOrdersTap,
    required this.onWishlistTap,
    required this.onAddressesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          _buildShortcutCard(
            context,
            iconWidget: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppDesignSystem.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppDesignSystem.blue600, size: 20),
            ),
            title: 'My Orders',
            subtitle: (isLoggedIn && ordersCount > 0) ? '$ordersCount Placed' : 'No Orders',
            onTap: onOrdersTap,
          ),
          const SizedBox(width: 10),
          _buildShortcutCard(
            context,
            iconWidget: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppDesignSystem.rose50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite_rounded, color: AppDesignSystem.rose600, size: 20),
            ),
            title: 'Wishlist',
            subtitle: wishlistCount > 0 ? '$wishlistCount Items' : '0 Saved',
            onTap: onWishlistTap,
          ),
          const SizedBox(width: 10),
          _buildShortcutCard(
            context,
            iconWidget: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded, color: AppDesignSystem.emerald600, size: 20),
            ),
            title: 'Addresses',
            subtitle: addressesCount > 0 ? '$addressesCount Saved' : 'Add New',
            onTap: onAddressesTap,
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              iconWidget,
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
