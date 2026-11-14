import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/design_system.dart';
import 'rider_active_delivery_card.dart';
import 'rider_pickup_card.dart';
import 'rider_batch_roadmap_card.dart';

/// Active Deliveries & Ready for Pickup Tab for Rider Console
class DeliveryOrdersTab extends StatefulWidget {
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

  @override
  State<DeliveryOrdersTab> createState() => _DeliveryOrdersTabState();
}

class _DeliveryOrdersTabState extends State<DeliveryOrdersTab> {
  // 0 = All, 1 = To Deliver, 2 = To Pickup
  int _filterIndex = 0;

  static const Color slateDark = AppDesignSystem.slate900;

  Widget _buildFilterPill(int index, String label, int count, Color activeColor) {
    final isSelected = _filterIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : AppDesignSystem.slate700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 9.5),
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : AppDesignSystem.slate900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final totalCount = widget.activeDeliveries.length + widget.pendingPickups.length;
    final showActive = _filterIndex == 0 || _filterIndex == 1;
    final showPickup = _filterIndex == 0 || _filterIndex == 2;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-Pill Action Filter for Rider
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterPill(0, '⚡ All', totalCount, AppDesignSystem.slate900),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildFilterPill(1, '🛵 Deliver', widget.activeDeliveries.length, AppDesignSystem.emeraldBrand),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildFilterPill(2, '📦 Pickup', widget.pendingPickups.length, AppDesignSystem.violet600),
                ),
              ],
            ),
          ),

          // Section 1: OUT FOR DELIVERY
          if (showActive) ...[
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.green100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.activeDeliveries.length}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.green700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.activeDeliveries.isEmpty
                  ? const EmptyOutForDeliveryCard(key: ValueKey('empty_out_for_delivery'))
                  : Column(
                      key: const ValueKey('active_deliveries_list'),
                      children: [
                        if (widget.activeDeliveries.length >= 2)
                          RiderBatchRoadmapCard(
                            stop1Order: widget.activeDeliveries[0],
                            stop2Order: widget.activeDeliveries[1],
                            distanceBetweenMeters: widget.activeDeliveries[0]['batch']?['distanceBetweenDropsMeters'] ??
                                widget.activeDeliveries[1]['batch']?['distanceBetweenDropsMeters'],
                            onOpenNavigation: widget.onOpenNavigation,
                          ),
                        ...widget.activeDeliveries.mapIndexed((idx, o) => RiderActiveDeliveryCard(
                              key: ValueKey('active_del_${o['id']}'),
                              order: o,
                              stopIndex: idx + 1,
                              totalStops: widget.activeDeliveries.length,
                              isUpdating: widget.updatingOrderId == o['id']?.toString(),
                              onOpenNavigation: widget.onOpenNavigation,
                              onShowDoorstepQr: widget.onShowDoorstepQr,
                              onShowConfirmation: widget.onShowConfirmation,
                            )
                                .animate()
                                .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                                .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)),
                      ],
                    ),
            ),
            if (showPickup) const SizedBox(height: 22),
          ],

          // Section 2: READY FOR PICKUP
          if (showPickup) ...[
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
                    '${widget.pendingPickups.length} Orders',
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

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.pendingPickups.isEmpty
                  ? const EmptyPendingPickupCard(key: ValueKey('empty_pending_pickup'))
                  : Column(
                      key: const ValueKey('pending_pickups_list'),
                      children: widget.pendingPickups
                          .map((o) => RiderPickupCard(
                                key: ValueKey('pickup_${o['id']}'),
                                order: o,
                                isUpdating: widget.updatingOrderId == o['id']?.toString(),
                                onOpenNavigation: widget.onOpenNavigation,
                                onUpdateStatus: widget.onUpdateStatus,
                              )
                                  .animate()
                                  .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                                  .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOutCubic))
                          .toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
