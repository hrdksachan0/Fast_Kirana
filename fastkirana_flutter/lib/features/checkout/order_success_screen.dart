import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../orders/orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String? orderId;
  final double totalAmount;
  final String deliveryAddress;
  final String paymentMethod;

  const OrderSuccessScreen({
    super.key,
    this.orderId,
    this.totalAmount = 0.0,
    this.deliveryAddress = 'Ghatampur Home',
    this.paymentMethod = 'COD',
  });

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color successGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final displayId = orderId ?? 'FK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Success Tick Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: successGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Order Placed Successfully! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your items are being packed at Ghatampur Hub and will arrive in 10-15 minutes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Order Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Order ID', displayId, isBold: true),
                    const Divider(height: 16, color: Color(0xFFF3F4F6)),
                    _buildDetailRow('Total Paid / Due', '₹${totalAmount.toInt()}', isBold: true),
                    const Divider(height: 16, color: Color(0xFFF3F4F6)),
                    _buildDetailRow('Payment Mode', paymentMethod),
                    const Divider(height: 16, color: Color(0xFFF3F4F6)),
                    _buildDetailRow('Delivery ETA', '⚡ 10-15 Minutes', isHighlight: true),
                  ],
                ),
              ),

              const Spacer(),

              // Track Order Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryRed, Color(0xFFB30013)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Track Order Status',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Back to Home Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Continue Shopping',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? successGreen : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}