import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import 'donut_capacity_painter.dart';

/// Cash Wallet & Duty Status Tab for Rider Dashboard
class DeliveryWalletTab extends StatelessWidget {
  final Map<String, dynamic>? walletInfo;
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;

  const DeliveryWalletTab({
    super.key,
    required this.walletInfo,
    required this.isOnline,
    required this.onToggleOnline,
  });

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  Widget build(BuildContext context) {
    final wallet = walletInfo?['wallet'] ?? {};
    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 10000.0;
    final capacityPercent = ((cashInHand / math.max(1.0, cashLimit)) * 100).clamp(0, 100).toInt();

    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + safeBottom),
      child: Column(
        children: [
          // White Hero Card with 27% Capacity Gauge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pill Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusPending,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.yellow200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppDesignSystem.amber700),
                      const SizedBox(width: 6),
                      Text(
                        'CASH IN HAND (जेब में नकद)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.amber700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                Text(
                  '₹${cashInHand.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 38),
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 18),

                // Circular Donut Progress Arc
                CustomPaint(
                  size: const Size(130, 130),
                  painter: DonutCapacityPainter(
                    percent: capacityPercent / 100.0,
                    trackColor: AppDesignSystem.slate100,
                    progressColor: AppDesignSystem.success,
                  ),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$capacityPercent%',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 24),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'CAPACITY',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w800,
                              color: slateMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Active & Eligible Status Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.green50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.emerald200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppDesignSystem.emerald600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Active & Eligible: Full COD order capacity available.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.statusDeliveredText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🚨 On Duty / Off Duty Interactive Toggle Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isOnline ? AppDesignSystem.emerald200 : AppDesignSystem.rose200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? AppDesignSystem.success : AppDesignSystem.rose500).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
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
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isOnline ? AppDesignSystem.green100 : AppDesignSystem.statusCancelled,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                            color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'ON DUTY (ड्यूटी चालू)' : 'OFF DUTY (ड्यूटी बंद)',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                              ),
                            ),
                            Text(
                              isOnline ? 'Receiving live delivery orders' : 'Orders redirected to other riders',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: isOnline,
                        activeThumbColor: AppDesignSystem.success,
                        activeTrackColor: AppDesignSystem.green200,
                        inactiveTrackColor: AppDesignSystem.rose200,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          onToggleOnline(val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOnline ? AppDesignSystem.green50 : AppDesignSystem.rose50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOnline ? AppDesignSystem.green200 : AppDesignSystem.rose200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isOnline ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOnline
                              ? 'Aap online hain. Store se new orders aate hi aapko pickup notification milegi.'
                              : 'Off duty hone par new orders doosre active delivery partners ke paas transfer ho jayenge.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: isOnline ? AppDesignSystem.green800 : AppDesignSystem.statusCancelledText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
