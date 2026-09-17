import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';

class TrackingCancelCard extends StatelessWidget {
  const TrackingCancelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ORDER CANCELLED',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This order has been cancelled',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'If you have already paid online via UPI/Card, a full refund has been initiated to your original payment method within 2-4 business days.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB91C1C),
                    height: 1.3,
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
