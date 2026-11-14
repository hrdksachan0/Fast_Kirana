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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.statusDelivered,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppDesignSystem.emerald200, width: 0.9),
      ),
      child: Row(
        children: [
          Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
          const SizedBox(width: 7),
          Text(
            '₹${totalSavings.toStringAsFixed(0)} saved! On this order',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.statusDeliveredText,
            ),
          ),
        ],
      ),
    );
  }
}
