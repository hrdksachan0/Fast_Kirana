import '../../../core/utils/restaurant_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingPreparingCard extends StatelessWidget {
  final Order? order;

  const TrackingPreparingCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final outlet = getOutletLocation(
      restaurantId: order?.restaurantId,
      shopName: order?.shopName,
      items: order?.items,
      rawOrder: order?.toJson(),
    );
    final isRest = outlet.isRestaurant;
    final shopName = isRest ? outlet.name : (order?.shopName?.replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute') ?? 'FastMinute Store');
    final isPending = order?.status == OrderStatus.adminPending || order?.status == OrderStatus.pending;

    final brandColor = isRest ? const Color(0xFF7C3AED) : const Color(0xFF00A344);
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF00B140)).withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF00B140)).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
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
              color: isPending ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPending ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0),
                width: 1,
              ),
            ),
            child: Icon(
              isPending ? Icons.fact_check_outlined : (isRest ? Icons.restaurant_rounded : Icons.storefront_rounded),
              color: isPending ? const Color(0xFFD97706) : brandColor,
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
                        color: isPending ? const Color(0xFFD97706) : brandColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPending ? (isRest ? 'KITCHEN VERIFICATION' : 'ADMIN & STORE VERIFICATION') : (isRest ? 'KITCHEN PREPARING' : 'STORE PREPARING'),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w900,
                        color: isPending ? const Color(0xFFD97706) : brandColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPending ? 'Verifying order at $shopName' : (isRest ? 'Cooking Fresh at $shopName' : 'Packing Fresh at $shopName'),
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPending
                      ? (isRest ? '${outlet.address} is confirming your dishes.' : 'Ghatampur Hub is checking stock & freshness. You can cancel if needed.')
                      : (isRest ? '${outlet.address} is preparing your hot meal fresh.' : 'Live GPS map will open as soon as your rider picks up the order.'),
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
  final DateTime? createdAt;

  const TrackingCancelBanner({
    super.key,
    required this.isCancelling,
    required this.onCancel,
    this.createdAt,
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_outlined, color: primaryRed, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Need to cancel?',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9F1239),
                  ),
                ),
                Text(
                  'Free cancellation available before store confirmation',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: primaryRed, width: 1.2),
              backgroundColor: Colors.white,
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
                    'Cancel Order',
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
