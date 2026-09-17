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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPending
              ? const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)]
              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPending ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (isPending ? const Color(0xFF64748B) : const Color(0xFFD97706)).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: isPending ? const Color(0xFFCBD5E1) : const Color(0xFFFCD34D), width: 1.5),
            ),
            child: Center(
              child: Text(isPending ? '⏳' : '👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24))),
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
                    color: isPending ? const Color(0xFF475569) : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPending ? 'AWAITING STORE CONFIRMATION' : 'STORE ACCEPTED & PREPARING',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isPending ? 'Order Sent to $shopName' : 'Packing Fresh at $shopName',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w900,
                    color: isPending ? const Color(0xFF0F172A) : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPending
                      ? 'Waiting for the store to accept your order. You can cancel now if needed.'
                      : 'Live GPS tracking map will automatically open as soon as your rider picks up the order.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: isPending ? const Color(0xFF64748B) : const Color(0xFF92400E),
                    height: 1.25,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE20A22).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: const Center(
              child: Icon(Icons.info_outline_rounded, color: primaryRed, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need to change or cancel?',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9F1239),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You can cancel now for free before the store begins preparation.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFBE123C),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isCancelling ? null : onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isCancelling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
