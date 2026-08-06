import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/order.dart';
import '../../widgets/brand_button.dart';
import '../orders/orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Order order;

  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppDesignSystem.success, AppDesignSystem.accent],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: AppDesignSystem.shadowXl,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your order has been confirmed and will be delivered soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppDesignSystem.shadowMd,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order ID', style: GoogleFonts.poppins(fontSize: 13, color: AppDesignSystem.textSecondary)),
                        Text(
                          order.readableId ?? order.id.substring(0, 8).toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: GoogleFonts.poppins(fontSize: 13, color: AppDesignSystem.textSecondary)),
                        Text(
                          Helpers.formatPrice(order.total),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment', style: GoogleFonts.poppins(fontSize: 13, color: AppDesignSystem.textSecondary)),
                        Text(
                          order.paymentMethod.displayName,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              BrandButton(
                text: 'Track Order',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const OrdersScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text(
                  'Continue Shopping',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}