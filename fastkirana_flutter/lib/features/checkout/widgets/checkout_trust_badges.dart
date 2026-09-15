import 'package:flutter/material.dart';
import '../../../core/theme/design_system.dart';

/// Conversion & Trust Badge for FastKirana Checkout
/// Displays 100% Secure Checkout with 256-bit encryption.
class CheckoutTrustBadges extends StatelessWidget {
  const CheckoutTrustBadges({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkSurfaceMuted : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppDesignSystem.darkBorder : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Color(0xFF7C3AED),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '100% Secure Checkout',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'End-to-end encrypted 256-bit secure payments via UPI, Cards & NetBanking',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppDesignSystem.darkTextSecondary : AppDesignSystem.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
