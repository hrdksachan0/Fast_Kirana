import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Single Bill Item Row
class CartBillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isGreen;
  final bool isBold;

  const CartBillRow(
    this.label,
    this.value, {
    super.key,
    this.isGreen = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13),
              color: isBold ? AppDesignSystem.slate900 : AppDesignSystem.slate500,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13.5),
              color: isGreen ? AppDesignSystem.green700 : AppDesignSystem.slate900,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Comprehensive Bill Summary Card with BOGO, Coupon, Tip, and Taxes
class CartBillDetailsCard extends StatelessWidget {
  final double subtotal;
  final double itemSavings;
  final double deliveryFee;
  final double packagingFee;
  final String packagingLabel;
  final double totalSavings;
  final double grandTotal;
  final double couponDiscount;
  final int selectedTip;
  final Map<String, dynamic>? freeGiftDetails;

  const CartBillDetailsCard({
    super.key,
    required this.subtotal,
    required this.itemSavings,
    required this.deliveryFee,
    required this.packagingFee,
    required this.packagingLabel,
    required this.totalSavings,
    required this.grandTotal,
    required this.couponDiscount,
    required this.selectedTip,
    this.freeGiftDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🧾', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              const SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CartBillRow('Item Total (MRP)', '₹${(subtotal + itemSavings).toInt()}'),
          if (itemSavings > 0) CartBillRow('Product Savings', '-₹${itemSavings.toInt()}', isGreen: true),
          if (freeGiftDetails != null)
            CartBillRow(
              '🎁 ${freeGiftDetails!['name']} (BOGO Gift)',
              'FREE (-₹${((freeGiftDetails!['originalPrice'] as num?)?.toDouble() ?? 0.0).toInt()})',
              isGreen: true,
            ),
          if (couponDiscount > 0) CartBillRow('Coupon Discount', '-₹${couponDiscount.toInt()}', isGreen: true),
          CartBillRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
          CartBillRow(packagingLabel, packagingFee == 0 ? 'FREE' : '₹${packagingFee.toInt()}', isGreen: packagingFee == 0),
          if (selectedTip > 0) CartBillRow('Delivery Partner Tip', '₹$selectedTip'),
          const CartBillRow('Handling & Taxes', '₹0', isGreen: true),
          const Divider(height: 16, color: AppDesignSystem.slate200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom Sheet Breakdown Modal
  static void showModal({
    required BuildContext context,
    required double subtotal,
    required double deliveryFee,
    required double savings,
    required double grandTotal,
    required int selectedTip,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bill Summary',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16.5),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 14),
            CartBillRow('Item Total', '₹${subtotal.toInt()}'),
            if (savings > 0) CartBillRow('Total Savings', '-₹${savings.toInt()}', isGreen: true),
            CartBillRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
            if (selectedTip > 0) CartBillRow('Delivery Partner Tip', '₹$selectedTip', isGreen: false),
            const CartBillRow('Handling & Taxes', '₹0', isGreen: true),
            const Divider(height: 22, color: AppDesignSystem.slate300),
            CartBillRow('To Pay', '₹${grandTotal.toInt()}', isBold: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
