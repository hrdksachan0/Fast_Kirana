import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../widgets/live_clock_badge.dart';

class RestaurantMetricsBar extends StatelessWidget {
  final bool isPlayingAlarm;
  final int pendingCount;
  final int activeOrders;
  final VoidCallback onMuteAlarm;

  const RestaurantMetricsBar({
    super.key,
    required this.isPlayingAlarm,
    required this.pendingCount,
    required this.activeOrders,
    required this.onMuteAlarm,
  });

  @override
  Widget build(BuildContext context) {
    const primaryRed = AppDesignSystem.primary;
    const brandAmber = AppDesignSystem.warning;
    const slateDark = AppDesignSystem.slate900;
    const slateMuted = AppDesignSystem.slate500;
    const slateBorder = AppDesignSystem.slate200;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Continuous Ringing Alert Banner when orders need confirmation
        if (isPlayingAlarm && pendingCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppDesignSystem.red600, primaryRed],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: primaryRed,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔔 $pendingCount New Order${pendingCount > 1 ? 's' : ''} Received!',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: Responsive.scaledFontSize(context, 13),
                        ),
                      ),
                      Text(
                        'Ringing continuously until accepted/confirmed',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Bounceable(
                  onTap: onMuteAlarm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_off_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Mute',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: Responsive.scaledFontSize(context, 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Sub-Header Metric Strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: Colors.white,
          child: Row(
            children: [
              _buildMetricItem(
                context,
                'New Orders',
                '$pendingCount',
                pendingCount > 0 ? primaryRed : slateDark,
                isAlert: pendingCount > 0,
              ),
              const SizedBox(width: 10),
              _buildMetricItem(
                context,
                'Cooking Now',
                '$activeOrders',
                brandAmber,
              ),
              const SizedBox(width: 10),
              _buildLiveClock(context, slateDark, slateMuted, slateBorder),
            ],
          ),
        ),
        const Divider(height: 1, color: slateBorder),
      ],
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, Color col, {bool isAlert = false}) {
    const slateBorder = AppDesignSystem.slate200;
    const slateMuted = AppDesignSystem.slate500;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isAlert ? AppDesignSystem.statusCancelled : AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? AppDesignSystem.rose200 : slateBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w900,
                color: col,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 9.5),
                fontWeight: FontWeight.w700,
                color: isAlert ? AppDesignSystem.rose600 : slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveClock(BuildContext context, Color slateDark, Color slateMuted, Color slateBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          children: [
            LiveDigitalClockBadge(
              backgroundColor: Colors.transparent,
              borderColor: Colors.transparent,
              textColor: slateDark,
              iconColor: slateMuted,
              fontSize: Responsive.scaledFontSize(context, 12),
              showSeconds: false,
            ),
            Text(
              'Live Time',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 9.5),
                fontWeight: FontWeight.w700,
                color: slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
