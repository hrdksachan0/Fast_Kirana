import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';

class EtaWidget extends StatelessWidget {
  final String etaText;
  final String distanceText;
  final String orderStatus;
  final bool isRealtimeConnected;

  const EtaWidget({
    super.key,
    required this.etaText,
    required this.distanceText,
    required this.orderStatus,
    this.isRealtimeConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDelivered = orderStatus.toUpperCase() == 'DELIVERED';
    final bool isOutForDelivery = orderStatus.toUpperCase() == 'OUT_FOR_DELIVERY';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dynamic Status Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDelivered
                  ? AppDesignSystem.green100
                  : isOutForDelivery
                      ? AppDesignSystem.blue50
                      : AppDesignSystem.statusPending,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                isDelivered
                    ? Icons.task_alt_rounded
                    : isOutForDelivery
                        ? Icons.delivery_dining_rounded
                        : Icons.timer_outlined,
                color: isDelivered
                    ? AppDesignSystem.green600
                    : isOutForDelivery
                        ? AppDesignSystem.blue600
                        : AppDesignSystem.amber600,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ETA text and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isDelivered ? 'Order Delivered' : etaText,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                    if (isRealtimeConnected && !isDelivered) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.green600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isDelivered
                      ? 'Package has reached your doorstep'
                      : distanceText.isNotEmpty
                          ? 'Rider is  away'
                          : 'Live order status is being synchronized',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.slate500,
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
