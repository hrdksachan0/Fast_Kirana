import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class DeliveryOrderDetailScreen extends StatelessWidget {
  final String orderId;
  const DeliveryOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Order $orderId', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignSystem.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: AppDesignSystem.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Ready for Pickup', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                      Text('Warehouse: Ghatampur Market', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Customer info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]), borderRadius: BorderRadius.circular(25)),
                  child: Center(child: Text('AK', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aman Kumar', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                      Text('+91 98xxx xxx00', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.phone_rounded, color: AppDesignSystem.primary), onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items
          Text('Items (4)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          const SizedBox(height: 8),
          ...['Tomatoes 1kg', 'Milk 1L', 'Bread', 'Eggs 6pc'].asMap().entries.map((e) {
            final qty = [2, 1, 1, 1][e.key];
            final price = [45, 28, 35, 60][e.key];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppDesignSystem.borderLight)),
              child: Row(
                children: [
                  Text(e.value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textPrimary)),
                  const Spacer(),
                  Text('x$qty', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                  const SizedBox(width: 12),
                  Text('₹${price * qty}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
          // Navigation button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.navigation_rounded, color: AppDesignSystem.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('123, Green Park, Ghatampur', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppDesignSystem.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text('NAVIGATE', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BrandButton(text: 'Mark Delivered', onPressed: () {}),
        ],
      ),
    );
  }
}