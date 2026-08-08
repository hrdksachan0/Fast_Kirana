import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.accent]),
                  shape: BoxShape.circle,
                  boxShadow: AppDesignSystem.shadowGlow,
                ),
                child: Icon(Icons.check_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Order Placed! 🎉',
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order has been confirmed',
                style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppDesignSystem.borderLight),
                  boxShadow: AppDesignSystem.shadowSm,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order ID', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                        Text(orderId, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                        Text('20-25 mins', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.success)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                        Text('Cash on Delivery', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              BrandButton(
                text: 'Track Order',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId)),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text('Back to Home', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}