import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingPaymentCard extends StatelessWidget {
  final Order? order;
  final bool isProcessingPayment;
  final int statusStep;
  final VoidCallback onPayOnline;
  final VoidCallback onSwitchToCOD;

  const TrackingPaymentCard({
    super.key,
    required this.order,
    required this.isProcessingPayment,
    required this.statusStep,
    required this.onPayOnline,
    required this.onSwitchToCOD,
  });

  @override
  Widget build(BuildContext context) {
    final grandTotal = order?.total ?? 0.0;
    final isOnlinePayment = order?.paymentMethod != PaymentMethod.cod;
    final isUnpaid = order?.paymentStatus.toUpperCase() != 'PAID';
    final canSwitchToCOD = isOnlinePayment && isUnpaid && (statusStep <= 0);

    const brandGreen = Color(0xFF00A344);
    const alertRose = Color(0xFFE11D48);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnlinePayment ? const Color(0xFFFDA4AF) : const Color(0xFF86EFAC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnlinePayment ? alertRose : brandGreen).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOnlinePayment ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnlinePayment ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                width: 1,
              ),
            ),
            child: Icon(
              isOnlinePayment ? Icons.payment_rounded : Icons.account_balance_wallet_rounded,
              color: isOnlinePayment ? alertRose : brandGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isOnlinePayment ? 'Pay Online: ' : 'Cash on Delivery: ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '₹${grandTotal.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnlinePayment
                      ? 'Payment pending • Tap to pay'
                      : 'Pay via Cash or UPI at door',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w600,
                    color: isOnlinePayment ? alertRose : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Actions
          if (isProcessingPayment)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: brandGreen, strokeWidth: 2),
            )
          else ...[
            if (canSwitchToCOD)
              TextButton(
                onPressed: onSwitchToCOD,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Switch to COD',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            GestureDetector(
              onTap: onPayOnline,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A344), Color(0xFF008736)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: brandGreen.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pay Online',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
