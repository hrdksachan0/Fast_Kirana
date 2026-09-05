import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class DeliveryEarningsScreen extends StatelessWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Earnings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.accent]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                children: [
                  Text('Today\'s Earnings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 8),
                  Text('₹480', style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 36), fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _earnStat(context, 'Orders', '12'),
                      _earnStat(context, 'Distance', '38 km'),
                      _earnStat(context, 'Bonus', '₹80'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Weekly Breakdown', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            ...['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
                child: Row(
                  children: [
                    Text(d, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                    const Spacer(),
                    Text('8 orders', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                    const SizedBox(width: 12),
                    Text('₹320', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _earnStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: Colors.white.withValues(alpha: 0.9))),
      ],
    );
  }
}