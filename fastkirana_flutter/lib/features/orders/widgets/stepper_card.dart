import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';

class StepperCard extends StatelessWidget {
  final String currentStatus;
  final DateTime? createdAt;
  final DateTime? estimatedDelivery;

  const StepperCard({
    super.key,
    required this.currentStatus,
    this.createdAt,
    this.estimatedDelivery,
  });

  int _getStepIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'CONFIRMED':
        return 0;
      case 'PROCESSING':
      case 'PACKED':
      case 'READY_FOR_PICKUP':
        return 1;
      case 'OUT_FOR_DELIVERY':
        return 2;
      case 'DELIVERED':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _getStepIndex(currentStatus);
    final steps = [
      {'title': 'Order Placed', 'desc': 'Received by store'},
      {'title': 'Items Packed', 'desc': 'Freshly bagged'},
      {'title': 'On the Way', 'desc': 'Rider heading to you'},
      {'title': 'Delivered', 'desc': 'Enjoy your meal/grocery'},
    ];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER STATUS TIMELINE',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (index) {
            final isDone = index < activeIndex;
            final isCurrent = index == activeIndex;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon & Vertical Line
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone || isCurrent
                            ? AppDesignSystem.green600
                            : AppDesignSystem.slate200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isDone
                              ? Icons.check
                              : isCurrent
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                          size: isCurrent ? 10 : 14,
                          color: isDone || isCurrent ? Colors.white : AppDesignSystem.slate400,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: isDone ? AppDesignSystem.green600 : AppDesignSystem.slate200,
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Text labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[index]['title']!,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isDone || isCurrent
                              ? AppDesignSystem.slate900
                              : AppDesignSystem.slate400,
                        ),
                      ),
                      Text(
                        steps[index]['desc']!,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
