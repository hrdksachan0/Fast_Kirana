import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Reports & Analytics', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today • Aug 7, 2026', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                const Icon(Icons.calendar_today_rounded, color: AppDesignSystem.primary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Revenue card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.accent]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Revenue', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 4),
                    Text('₹24,580', style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 28), fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                Row(
                  children: [
                    _reportStat(context, 'Orders', '142'),
                    const SizedBox(width: 16),
                    _reportStat(context, 'Avg Value', '₹173'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Breakdown', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                const SizedBox(height: 12),
                _breakdownRow(context, 'Grocery Orders', '98', '₹18,200', 0.65),
                const SizedBox(height: 10),
                _breakdownRow(context, 'Cafe Orders', '44', '₹6,380', 0.35),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Top products
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top Products', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                const SizedBox(height: 12),
                _topRow(context, 'Amul Milk 1L', 340),
                _topRow(context, 'Fresh Tomatoes 1kg', 290),
                _topRow(context, 'Bread', 180),
                _topRow(context, 'Eggs (6pc)', 150),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: Colors.white.withValues(alpha: 0.9))),
      ],
    );
  }

  Widget _breakdownRow(BuildContext context, String label, String count, String amount, double percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textPrimary)),
            Text('$count orders • $amount', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 6, decoration: BoxDecoration(color: AppDesignSystem.borderLight, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: Container(height: 6, decoration: BoxDecoration(color: AppDesignSystem.primary, borderRadius: BorderRadius.circular(3)))),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  Widget _topRow(BuildContext context, String name, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppDesignSystem.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('$count sold', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w700, color: AppDesignSystem.primary)),
          ),
        ],
      ),
    );
  }
}