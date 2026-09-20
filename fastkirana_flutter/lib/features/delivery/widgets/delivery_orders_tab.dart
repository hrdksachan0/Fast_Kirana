import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import 'rider_active_delivery_card.dart';
import 'rider_pickup_card.dart';

/// Active Deliveries & Ready for Pickup Tab for Rider Console
class DeliveryOrdersTab extends StatelessWidget {
  final List<Map<String, dynamic>> activeDeliveries;
  final List<Map<String, dynamic>> pendingPickups;
  final String? updatingOrderId;
  final void Function(double lat, double lng, String label, {String? address}) onOpenNavigation;
  final void Function(Map<String, dynamic> order) onShowDoorstepQr;
  final void Function(Map<String, dynamic> order, double lat, double lng) onShowConfirmation;
  final Future<void> Function(String orderId, String newStatus, {Map<String, dynamic>? extra}) onUpdateStatus;

  const DeliveryOrdersTab({
    super.key,
    required this.activeDeliveries,
    required this.pendingPickups,
    this.updatingOrderId,
    required this.onOpenNavigation,
    required this.onShowDoorstepQr,
    required this.onShowConfirmation,
    required this.onUpdateStatus,
  });

  static const Color slateDark = AppDesignSystem.slate900;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: OUT FOR DELIVERY
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppDesignSystem.emeraldBrand,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.two_wheeler_rounded, size: 14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'OUT FOR DELIVERY',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeDeliveries.isEmpty)
            const EmptyOutForDeliveryCard()
          else
            ...activeDeliveries.map((o) => RiderActiveDeliveryCard(
                  key: ValueKey(o['id']),
                  order: o,
                  isUpdating: updatingOrderId == o['id']?.toString(),
                  onOpenNavigation: onOpenNavigation,
                  onShowDoorstepQr: onShowDoorstepQr,
                  onShowConfirmation: onShowConfirmation,
                )),

          const SizedBox(height: 22),

          // Section 2: READY FOR PICKUP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.violet600,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.inventory_2_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'READY FOR PICKUP',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignSystem.violet200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pendingPickups.length} Orders',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.violet600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (pendingPickups.isEmpty)
            const EmptyPendingPickupCard()
          else
            ...pendingPickups.map((o) => RiderPickupCard(
                  key: ValueKey(o['id']),
                  order: o,
                  isUpdating: updatingOrderId == o['id']?.toString(),
                  onOpenNavigation: onOpenNavigation,
                  onUpdateStatus: onUpdateStatus,
                )),
        ],
      ),
    );
  }
}
