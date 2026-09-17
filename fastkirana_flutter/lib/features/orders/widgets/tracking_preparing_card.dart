import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingPreparingCard extends StatelessWidget {
  final Order? order;

  const TrackingPreparingCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final shopName = order?.shopName ?? 'FastKirana Store';
    final isPending = order?.status == OrderStatus.pending || order?.status == OrderStatus.adminPending;

    const brandGreen = Color(0xFF00A344);
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPending ? const Color(0xFFF1F5F9) : const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPending ? const Color(0xFFCBD5E1) : const Color(0xFFBBF7D0),
                width: 1,
              ),
            ),
            child: Icon(
              isPending ? Icons.hourglass_top_rounded : Icons.storefront_rounded,
              color: isPending ? slateMuted : brandGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPending ? const Color(0xFFD97706) : brandGreen,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPending ? 'AWAITING STORE CONFIRMATION' : 'STORE PREPARING',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w900,
                        color: isPending ? const Color(0xFFD97706) : brandGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPending ? 'Sent to $shopName' : 'Packing Fresh at $shopName',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPending
                      ? 'Waiting for the store to accept. You can cancel if needed.'
                      : 'Live GPS map will open as soon as your rider picks up the order.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: slateMuted,
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

class TrackingCancelBanner extends StatelessWidget {
  final bool isCancelling;
  final VoidCallback onCancel;

  const TrackingCancelBanner({
    super.key,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE11D48);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: primaryRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Change of plans?',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9F1239),
                  ),
                ),
                Text(
                  'Cancel for free before store begins preparation',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFBE123C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: isCancelling ? null : onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: primaryRed, width: 1.2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isCancelling
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(color: primaryRed, strokeWidth: 2),
                  )
                : Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w800,
                      color: primaryRed,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
