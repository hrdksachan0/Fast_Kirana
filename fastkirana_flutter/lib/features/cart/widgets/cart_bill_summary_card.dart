import 'package:flutter/material.dart';
import '../../../core/theme/design_system.dart';

/// Modular Bill Breakdown Card for Cart
class CartBillSummaryCard extends StatelessWidget {
  final double itemTotal;
  final double deliveryFee;
  final double handlingFee;
  final double couponDiscount;
  final double tipAmount;
  final double grandTotal;
  final double totalSaved;

  const CartBillSummaryCard({
    super.key,
    required this.itemTotal,
    required this.deliveryFee,
    this.handlingFee = 5.0,
    this.couponDiscount = 0.0,
    this.tipAmount = 0.0,
    required this.grandTotal,
    this.totalSaved = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate100,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: AppDesignSystem.h3.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
            ),
          ),
          const SizedBox(height: 12),

          _buildRow('Item Total', '₹${itemTotal.toInt()}'),
          const SizedBox(height: 8),

          _buildRow(
            'Delivery Fee',
            deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}',
            valueColor: deliveryFee == 0 ? const Color(0xFF00B140) : null,
          ),
          const SizedBox(height: 8),

          if (handlingFee > 0) ...[
            _buildRow('Handling & Packaging', '₹${handlingFee.toInt()}'),
            const SizedBox(height: 8),
          ],

          if (tipAmount > 0) ...[
            _buildRow('Delivery Partner Tip', '₹${tipAmount.toInt()}'),
            const SizedBox(height: 8),
          ],

          if (couponDiscount > 0) ...[
            _buildRow(
              'Coupon Discount',
              '- ₹${couponDiscount.toInt()}',
              valueColor: const Color(0xFF00B140),
            ),
            const SizedBox(height: 8),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Divider(color: AppDesignSystem.slate100, height: 1),
          ),
          const SizedBox(height: 6),

          // Grand Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: AppDesignSystem.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                ),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppDesignSystem.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          if (totalSaved > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✨ Total Savings of ₹${totalSaved.toInt()} on this order',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppDesignSystem.slate600,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppDesignSystem.slate900,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
