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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOnlinePayment ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnlinePayment ? const Color(0xFFFDA4AF) : const Color(0xFFDCFCE7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnlinePayment ? const Color(0xFFE11D48) : const Color(0xFF00A344)).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (isOnlinePayment ? const Color(0xFFE11D48) : const Color(0xFF00A344)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOnlinePayment ? 'PAYMENT PENDING' : 'PAY ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w900,
                    color: isOnlinePayment ? const Color(0xFFE11D48) : const Color(0xFF00A344),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOnlinePayment ? const Color(0xFFFFE4E6) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnlinePayment ? Icons.warning_amber_rounded : Icons.shield_outlined,
                      size: 11,
                      color: isOnlinePayment ? const Color(0xFFBE123C) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isOnlinePayment ? 'Action Needed' : 'Instant & Secure',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w800,
                        color: isOnlinePayment ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isOnlinePayment ? 'Complete Payment of ₹${grandTotal.toInt()}' : 'Pay ₹${grandTotal.toInt()} Online',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 14.5),
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isOnlinePayment
                ? 'Your online payment has not been confirmed yet. You can retry paying online or switch to Cash on Delivery (COD) to proceed.'
                : 'Order is currently set to Cash on Delivery. You can pay online using Google Pay, PhonePe, Paytm, BHIM, UPI or Cards.',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              color: const Color(0xFF475569),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isProcessingPayment ? null : onPayOnline,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A344), Color(0xFF008736)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A344).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isProcessingPayment
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payment_rounded, color: Colors.white, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                isOnlinePayment ? 'Pay Online Now' : 'Pay ₹${grandTotal.toInt()} Online Now',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                  ),
                ),
              ),
              if (canSwitchToCOD) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: isProcessingPayment ? null : onSwitchToCOD,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00A344), width: 1.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_atm_rounded, color: Color(0xFF00A344), size: 15),
                          const SizedBox(width: 5),
                          Text(
                            'Switch to COD',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF00A344),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
