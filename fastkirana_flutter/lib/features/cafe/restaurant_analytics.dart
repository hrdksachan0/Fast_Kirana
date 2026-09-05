import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class RestaurantAnalyticsScreen extends StatelessWidget {
  const RestaurantAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Analytics', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('This Month', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppDesignSystem.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('₹98,450', style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 28), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: AppDesignSystem.success, size: 14),
                      const SizedBox(width: 4),
                      Text('+18.5% vs last month', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _miniCard(context, 'Orders', '1,240', AppDesignSystem.primary)),
                const SizedBox(width: 12),
                Expanded(child: _miniCard(context, 'Avg Rating', '4.5', AppDesignSystem.warning)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Popular Items', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            ...['Cappuccino (340)', 'Masala Chai (280)', 'Cold Coffee (195)', 'Veg Burger (150)'].asMap().entries.map((e) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppDesignSystem.borderLight)),
                child: Row(
                  children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: AppDesignSystem.cafeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${e.key + 1}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.cafeAccent)))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value.split(' (')[0], style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textPrimary))),
                    Text(e.value.split(' (')[1].replaceAll(')', ''), style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.cafeAccent)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.bar_chart_rounded, color: color, size: 18)),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 20), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
        ],
      ),
    );
  }
}