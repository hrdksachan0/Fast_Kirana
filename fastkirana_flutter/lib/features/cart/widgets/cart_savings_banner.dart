import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';

/// Modular Smart Savings Callout & Free Delivery Milestone Progress Bar for Cart
class CartSavingsBanner extends StatelessWidget {
  final double totalSavings;
  final double subtotal;
  final double freeDeliveryThreshold;
  final String? appliedCoupon;
  final double couponDiscount;
  final VoidCallback onApplyCouponTap;
  final VoidCallback? onRemoveCouponTap;

  const CartSavingsBanner({
    super.key,
    required this.totalSavings,
    required this.subtotal,
    this.freeDeliveryThreshold = 199.0,
    this.appliedCoupon,
    this.couponDiscount = 0.0,
    required this.onApplyCouponTap,
    this.onRemoveCouponTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFreeDelivery = subtotal >= freeDeliveryThreshold;
    final progress = (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
    final remainingForFreeDelivery = (freeDeliveryThreshold - subtotal).clamp(0.0, freeDeliveryThreshold);

    return Column(
      children: [
        // Total Savings Pill (if savings > 0)
        if (totalSavings > 0 || couponDiscount > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B140),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 You are saving ₹${(totalSavings + couponDiscount).toInt()} on this order!',
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Free Delivery Progress Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppDesignSystem.slate100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFreeDelivery ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                        color: isFreeDelivery ? const Color(0xFF00B140) : AppDesignSystem.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isFreeDelivery
                            ? 'FREE Delivery Unlocked! ⚡'
                            : 'Add ₹${remainingForFreeDelivery.toInt()} more for FREE Delivery',
                        style: TextStyle(
                          color: isFreeDelivery ? const Color(0xFF065F46) : AppDesignSystem.slate800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${subtotal.toInt()}/₹${freeDeliveryThreshold.toInt()}',
                    style: const TextStyle(
                      color: AppDesignSystem.slate500,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppDesignSystem.slate100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFreeDelivery ? const Color(0xFF00B140) : AppDesignSystem.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Coupon Code Action Strip
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppDesignSystem.slate200),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: AppDesignSystem.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: appliedCoupon != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                appliedCoupon!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00B140),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Color(0xFF00B140),
                              ),
                            ],
                          ),
                          Text(
                            'Saved ₹${couponDiscount.toInt()} with this coupon',
                            style: const TextStyle(
                              color: AppDesignSystem.slate500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Apply Coupons & Offers',
                        style: TextStyle(
                          color: AppDesignSystem.slate800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
              appliedCoupon != null
                  ? Bounceable(
                      onTap: onRemoveCouponTap,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            color: AppDesignSystem.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  : Bounceable(
                      onTap: onApplyCouponTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SELECT',
                          style: TextStyle(
                            color: AppDesignSystem.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
