import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/order_item_helper.dart';
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
              color: AppDesignSystem.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, color: AppDesignSystem.warning, size: 20),
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
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]), borderRadius: BorderRadius.circular(25)),
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
                IconButton(icon: const Icon(Icons.phone_rounded, color: AppDesignSystem.primary), onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items Header with Units Summary
          Row(
            children: [
              Text('Order Items (4)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignSystem.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '5 UNITS TOTAL',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: AppDesignSystem.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...([
            {'name': 'Tomatoes 1kg', 'qty': 2, 'price': 45},
            {'name': 'Milk 1L', 'qty': 1, 'price': 28},
            {'name': 'Bread', 'qty': 1, 'price': 35},
            {'name': 'Eggs 6pc', 'qty': 1, 'price': 60},
          ]..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int))).map((item) {
            final name = item['name'] as String;
            final qty = item['qty'] as int;
            final price = item['price'] as int;
            final isMulti = qty > 1;
            final weightVariant = OrderItemHelper.resolveWeightOrVariant(item, name);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMulti ? const Color(0xFFFFF7ED) : AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMulti ? const Color(0xFFF97316) : AppDesignSystem.borderLight,
                  width: isMulti ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: isMulti ? FontWeight.w700 : FontWeight.w500, color: AppDesignSystem.textPrimary)),
                        if (weightVariant.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          OrderItemHelper.buildWeightBadge(context, weightVariant),
                        ],
                        if (isMulti)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEA580C)),
                                const SizedBox(width: 4),
                                Text(
                                  'DELIVER $qty PIECES (CHECK QTY)',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: const Color(0xFFEA580C)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMulti ? const Color(0xFFEA580C) : AppDesignSystem.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${qty}x QTY',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: isMulti ? Colors.white : AppDesignSystem.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('₹${price * qty}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          // Navigation button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded, color: AppDesignSystem.primary, size: 20),
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