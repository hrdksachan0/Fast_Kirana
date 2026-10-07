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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          _buildShortcutCard(
            context,
            iconWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppDesignSystem.blue50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(
                child: Icon(Icons.receipt_long_rounded, color: AppDesignSystem.blue600, size: 21),
              ),
            ),
            title: 'My Orders',
            subtitle: (isLoggedIn && ordersCount > 0) ? '$ordersCount Placed' : 'No Orders',
            hasValue: isLoggedIn && ordersCount > 0,
            onTap: onOrdersTap,
          ),
          const SizedBox(width: 10),
          _buildShortcutCard(
            context,
            iconWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppDesignSystem.rose50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(
                child: Icon(Icons.favorite_rounded, color: AppDesignSystem.rose600, size: 21),
              ),
            ),
            title: 'Wishlist',
            subtitle: wishlistCount > 0 ? '$wishlistCount Items' : '0 Saved',
            hasValue: wishlistCount > 0,
            onTap: onWishlistTap,
          ),
          const SizedBox(width: 10),
          _buildShortcutCard(
            context,
            iconWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(
                child: Icon(Icons.location_on_rounded, color: AppDesignSystem.emerald600, size: 21),
              ),
            ),
            title: 'Addresses',
            subtitle: addressesCount > 0 ? '$addressesCount Saved' : 'Add New',
            hasValue: addressesCount > 0,
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
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppDesignSystem.slate200.withValues(alpha: 0.7),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w600,
                      color: hasValue ? AppDesignSystem.slate800 : AppDesignSystem.slate400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
