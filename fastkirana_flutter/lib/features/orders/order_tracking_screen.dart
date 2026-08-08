import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Track Order',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Map Placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppDesignSystem.primary.withOpacity(0.1), AppDesignSystem.accent.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded, size: 64, color: AppDesignSystem.primary),
                    const SizedBox(height: 8),
                    Text('Live Map', style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order ID
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 20, color: AppDesignSystem.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ID', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                        Text(orderId, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('IN TRANSIT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppDesignSystem.warning)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Status Timeline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  _statusRow('Order Confirmed', '12:34 PM', true, false),
                  _statusRow('Packed & Ready', '12:45 PM', true, false),
                  _statusRow('Out for Delivery', '1:15 PM', true, true),
                  _statusRow('Delivered', 'Expected 1:45 PM', false, false),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Partner
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(child: Text('RA', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ravi Kumar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                        Text('Your delivery partner', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.phone_rounded, color: AppDesignSystem.primary),
                    style: IconButton.styleFrom(backgroundColor: AppDesignSystem.primary.withOpacity(0.1)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.chat_rounded, color: AppDesignSystem.accent),
                    style: IconButton.styleFrom(backgroundColor: AppDesignSystem.accent.withOpacity(0.1)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            BrandButton(
              text: 'Contact Support',
              onPressed: () {},
              backgroundColor: AppDesignSystem.surface,
              textColor: AppDesignSystem.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String time, bool done, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done ? AppDesignSystem.success : (isCurrent ? AppDesignSystem.warning : AppDesignSystem.borderLight),
              shape: BoxShape.circle,
            ),
            child: Icon(done ? Icons.check_rounded : Icons.circle, size: done ? 16 : 8, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                Text(time, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesignSystem.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppDesignSystem.warning)),
            ),
        ],
      ),
    );
  }
}