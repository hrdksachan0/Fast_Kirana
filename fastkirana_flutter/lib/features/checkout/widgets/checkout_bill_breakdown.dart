import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/location_service.dart';

class CheckoutBillBreakdown extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double? handlingFee;
  final String? handlingLabel;
  final double packagingFee;
  final String packagingLabel;
  final double discountAmount;
  final double walletAmountUsed;
  final double grandTotal;
  final double tipAmount;
  final DeliveryTierInfo? tier;

  const CheckoutBillBreakdown({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    this.handlingFee,
    this.handlingLabel,
    this.packagingFee = 0.0,
    this.packagingLabel = 'Handling Fee',
    required this.discountAmount,
    this.walletAmountUsed = 0.0,
    required this.grandTotal,
    this.tipAmount = 0.0,
    this.tier,
  });

  @override
  Widget build(BuildContext context) {
    const primaryRed = AppDesignSystem.primary;
    const slateDark = AppDesignSystem.slate900;
    const slateBorder = AppDesignSystem.slate200;

    final deliveryFeeLabel = (tier != null && tier!.distanceKm > 3.0)
        ? 'Delivery Fee (3-5 km Zone)'
        : (tier != null && tier!.distanceKm > 2.0)
            ? 'Delivery Fee (2-3 km Zone)'
            : 'Delivery Fee';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder, width: 1.1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🧾', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14.5))),
              const SizedBox(width: 5),
              Text(
                'Bill Summary',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _buildRow(context, 'Item Total', '₹${subtotal.toInt()}'),
          const SizedBox(height: 5.5),
          _buildRow(
            context,
            deliveryFeeLabel,
            deliveryFee == 0.0 ? 'FREE' : '₹${deliveryFee.toInt()}',
            isFree: deliveryFee == 0.0,
          ),
          if ((handlingFee ?? packagingFee) > 0) ...[
            const SizedBox(height: 5.5),
            _buildRow(
              context,
              (handlingLabel != null && handlingLabel!.trim().isNotEmpty) ? handlingLabel! : packagingLabel,
              '+₹${(handlingFee ?? packagingFee).toInt()}',
            ),
          ],
          if (tipAmount > 0) ...[
            const SizedBox(height: 5.5),
            _buildRow(context, 'Delivery Partner Tip', '₹${tipAmount.toInt()}'),
          ],
          if (discountAmount > 0) ...[
            const SizedBox(height: 5.5),
            _buildRow(context, 'Discount', '-₹${discountAmount.toInt()}', isDiscount: true),
          ],
          if (walletAmountUsed > 0) ...[
            const SizedBox(height: 5.5),
            _buildRow(context, '👛 Wallet Balance Applied', '-₹${walletAmountUsed.toInt()}', isDiscount: true),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppDesignSystem.slate200),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 20),
                  fontWeight: FontWeight.w900,
                  color: primaryRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, {bool isFree = false, bool isDiscount = false}) {
    const primaryRed = AppDesignSystem.primary;
    const slateDark = AppDesignSystem.slate900;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 13.5),
            fontWeight: FontWeight.w500,
            color: AppDesignSystem.slate600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 13.5),
            fontWeight: (isFree || isDiscount) ? FontWeight.w900 : FontWeight.w700,
            color: isFree
                ? AppDesignSystem.green600
                : (isDiscount ? primaryRed : slateDark),
          ),
        ),
      ],
    );
  }
}
