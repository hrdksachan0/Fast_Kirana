import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Top Mint Green Savings Banner for Checkout
class CheckoutSavingsBanner extends StatelessWidget {
  final double totalSavings;

  const CheckoutSavingsBanner({
    super.key,
    required this.totalSavings,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSavings <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.statusDelivered,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignSystem.emerald200),
      ),
      child: Row(
        children: [
          Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
          const SizedBox(width: 8),
          Text(
            '₹${totalSavings.toStringAsFixed(0)} saved! On this order',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.statusDeliveredText,
            ),
          ),
        ],
      ),
    );
  }
}
