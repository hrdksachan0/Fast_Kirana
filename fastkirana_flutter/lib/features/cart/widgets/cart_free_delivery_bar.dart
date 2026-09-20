import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/location_service.dart';

/// Dynamic Distance-Tiered Free Delivery Milestone Progress Bar for Cart
class CartFreeDeliveryBar extends StatelessWidget {
  final double subtotal;
  final DeliveryTierInfo tier;

  const CartFreeDeliveryBar({
    super.key,
    required this.subtotal,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    if (!tier.isServiceable) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignSystem.statusPending,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.rose300, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outside Delivery Zone (${tier.distanceKm.toStringAsFixed(1)} km away)',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.red600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Delivery is currently available within 5.0 km of our active operational hub. Please select a serviceable delivery address.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      color: AppDesignSystem.statusPendingText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final freeDeliveryThreshold = tier.freeDeliveryThreshold;
    final remaining = (freeDeliveryThreshold - subtotal).clamp(0.0, freeDeliveryThreshold);
    final progress = (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
    final isUnlocked = remaining <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFEA580C)).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon Badge + Main Milestone Headline + Fraction Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge with subtle gradient & glow
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUnlocked
                        ? [const Color(0xFF22C55E), const Color(0xFF15803D)]
                        : [const Color(0xFFFB923C), const Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFEA580C)).withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isUnlocked ? '🎉' : '🛵',
                    style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title Headline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnlocked
                          ? 'FREE Delivery Unlocked!'
                          : 'Add ₹${remaining.toInt()} for FREE Delivery',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked
                          ? 'You saved ₹${tier.baseFee.toInt()} on delivery (${tier.tierName})'
                          : 'Shop for ₹${freeDeliveryThreshold.toInt()} or more to get free delivery',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: isUnlocked ? const Color(0xFF15803D) : AppDesignSystem.slate500,
                        letterSpacing: -0.1,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Fraction / Status Tag (Self-contained, no clipping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnlocked ? const Color(0xFF86EFAC) : const Color(0xFFFFEDD5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnlocked) ...[
                      const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isUnlocked
                          ? 'FREE'
                          : '₹${subtotal.toInt()} / ₹${freeDeliveryThreshold.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: isUnlocked ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Tactile Animated Progress Bar Track
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return Container(
                height: 6,
                width: barWidth,
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: (barWidth * progress).clamp(0.0, barWidth),
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUnlocked
                            ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                            : [const Color(0xFFFB923C), const Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (isUnlocked ? const Color(0xFF16A34A) : const Color(0xFFEA580C))
                              .withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
