import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
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
  // Outlet filter: 'ALL', 'DARKSTORE', or restaurantId ('REST-104', etc.)
  String _selectedOutlet = 'ALL';

  // 0 = All Live (Out for Delivery + Pickup)
  // 1 = On Way (Out for Delivery only)
  // 2 = Pickup (Ready for Pickup)
  // 3 = Ready (Items Packed & Ready)
  int _filterIndex = 0;

  static const Color slateDark = AppDesignSystem.slate900;

  bool _orderMatchesOutlet(Map<String, dynamic> o, String outletId) {
    if (outletId == 'ALL') return true;
    final orderType = (o['orderType'] ?? '').toString().toUpperCase();
    final rId = (o['restaurantId'] ?? '').toString().trim();
    final readableId = (o['readableId'] ?? '').toString();
    final isFood = orderType == 'RESTAURANT' || rId.isNotEmpty || readableId.contains('-R');

    if (outletId == 'DARKSTORE') {
      return !isFood;
    }

    final target = outletId.toLowerCase().trim();
    final sName = (o['shopName'] ?? '').toString().toLowerCase().trim();
    if (rId.toLowerCase() == target || sName.contains(target) || target.contains(sName)) {
      return true;
    }

    final subOrders = o['subOrders'];
    if (subOrders is List) {
      return subOrders.any((sub) {
        if (sub is Map) {
          final subRId = (sub['restaurantId'] ?? '').toString().toLowerCase().trim();
          final subSName = (sub['shopName'] ?? '').toString().toLowerCase().trim();
          return subRId == target || subSName.contains(target) || target.contains(subSName);
        }
        return false;
      });
    }

    return false;
  }

  List<Map<String, dynamic>> _buildOutletsList(List<Map<String, dynamic>> allOrders) {
    final List<Map<String, dynamic>> result = [];

    // 1. All Outlets
    result.add({
      'id': 'ALL',
      'name': 'All Outlets',
      'icon': '🏢',
      'count': allOrders.length,
    });

    // 2. Darkstore (Grocery)
    final darkstoreCount = allOrders.where((o) => _orderMatchesOutlet(o, 'DARKSTORE')).length;
    result.add({
      'id': 'DARKSTORE',
      'name': 'Darkstore',
      'icon': '🛒',
      'count': darkstoreCount,
    });

    // 3. Dynamic restaurants from orders + registered restaurants
    final Map<String, String> uniqueRestaurants = {};
    for (final r in RestaurantRegistry.all) {
      uniqueRestaurants[r.id] = r.name;
    }
    for (final o in allOrders) {
      final rId = o['restaurantId']?.toString();
      if (rId != null && rId.isNotEmpty) {
        uniqueRestaurants[rId] = o['shopName']?.toString() ?? RestaurantRegistry.getName(rId) ?? 'Restaurant';
      }
      final subOrders = o['subOrders'];
      if (subOrders is List) {
        for (final sub in subOrders) {
          if (sub is Map) {
            final sRId = sub['restaurantId']?.toString();
            if (sRId != null && sRId.isNotEmpty) {
              uniqueRestaurants[sRId] = sub['shopName']?.toString() ?? RestaurantRegistry.getName(sRId) ?? 'Restaurant';
            }
          }
        }
      }
    }

    uniqueRestaurants.forEach((restId, restName) {
      final count = allOrders.where((o) => _orderMatchesOutlet(o, restId)).length;
      if (count > 0 || restId == 'REST-101' || restId == 'REST-104') {
        String icon = '🍽️';
        final lowerName = restName.toLowerCase();
        if (lowerName.contains('cafe') || lowerName.contains('burger') || lowerName.contains('pizza')) {
          icon = '🍕';
        } else if (lowerName.contains('bal udyan') || lowerName.contains('garden')) {
          icon = '🌲';
        }
        String shortName = restName
            .replaceAll(RegExp(r'\s+restaurant', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+cafe', caseSensitive: false), ' Cafe')
            .trim();
        result.add({
          'id': restId,
          'name': shortName,
          'icon': icon,
          'count': count,
        });
      }
    });

    return result;
  }

  Widget _buildOutletChip({
    required String id,
    required String name,
    required String icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignSystem.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.12 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppDesignSystem.slate800,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.22) : AppDesignSystem.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppDesignSystem.slate700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(int index, String label, int count, Color activeColor) {
    final isSelected = _filterIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filterIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : const Color(0xFFF8FAFC),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : AppDesignSystem.slate700,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : AppDesignSystem.slate900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final allOrders = [...widget.activeDeliveries, ...widget.pendingPickups];
    final outlets = _buildOutletsList(allOrders);

    // Filter by selected outlet
    final activeDeliveriesForOutlet = widget.activeDeliveries
        .where((o) => _orderMatchesOutlet(o, _selectedOutlet))
        .toList();

    final pendingPickupsForOutlet = widget.pendingPickups
        .where((o) => _orderMatchesOutlet(o, _selectedOutlet))
        .toList();

    final itemReadyOrdersForOutlet = pendingPickupsForOutlet
        .where((o) => (o['status'] ?? '').toString().toUpperCase() == 'PACKED')
        .toList();

    // Counts for Live Status pills
    final totalLiveCount = activeDeliveriesForOutlet.length + pendingPickupsForOutlet.length;
    final onWayCount = activeDeliveriesForOutlet.length;
    final pickupCount = pendingPickupsForOutlet.length;
    final itemReadyCount = itemReadyOrdersForOutlet.length;

    // Filter modes:
    // 0 = All Live (Show Out for Delivery + Ready for Pickup)
    // 1 = On Way (Show only Out for Delivery)
    // 2 = Pickup (Show all Ready for Pickup orders waiting at store)
    // 3 = Ready (Show strictly PACKED/Food Ready orders waiting at counter)
    final showActiveDeliveries = _filterIndex == 0 || _filterIndex == 1;
    final showPickupSection = _filterIndex == 0 || _filterIndex == 2 || _filterIndex == 3;
    final displayedPickups = _filterIndex == 3 ? itemReadyOrdersForOutlet : pendingPickupsForOutlet;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Outlet Filter Chips (All Outlets | Darkstore | Hot Pizza | A.S. Cafe ...)
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: outlets.length,
              itemBuilder: (context, i) {
                final out = outlets[i];
                final isSelected = _selectedOutlet == out['id'];
                return _buildOutletChip(
                  id: out['id'] as String,
                  name: out['name'] as String,
                  icon: out['icon'] as String,
                  count: out['count'] as int,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedOutlet = out['id'] as String),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Live Status Pills: All Live | On Way | Pickup | Ready (Like Admin)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFilterPill(0, '⚡ All Live', totalLiveCount, AppDesignSystem.slate900),
                _buildFilterPill(1, '🛵 On Way', onWayCount, AppDesignSystem.emeraldBrand),
                _buildFilterPill(2, '📦 Pickup', pickupCount, AppDesignSystem.violet600),
                _buildFilterPill(3, '🔥 Ready', itemReadyCount, const Color(0xFFD97706)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section 1: OUT FOR DELIVERY (Shown in "All Live" and "On Way" modes)
          if (showActiveDeliveries) ...[
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
                    '${activeDeliveriesForOutlet.length}',
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
              child: activeDeliveriesForOutlet.isEmpty
                  ? const EmptyOutForDeliveryCard(key: ValueKey('empty_out_for_delivery'))
                  : Column(
                      key: ValueKey('active_deliveries_${_selectedOutlet}_$_filterIndex'),
                      children: [
                        if (activeDeliveriesForOutlet.length >= 2)
                          RiderBatchRoadmapCard(
                            stop1Order: activeDeliveriesForOutlet[0],
                            stop2Order: activeDeliveriesForOutlet[1],
                            distanceBetweenMeters: activeDeliveriesForOutlet[0]['batch']?['distanceBetweenDropsMeters'] ??
                                activeDeliveriesForOutlet[1]['batch']?['distanceBetweenDropsMeters'],
                            onOpenNavigation: widget.onOpenNavigation,
                          ),
                        ...activeDeliveriesForOutlet.mapIndexed((idx, o) => RiderActiveDeliveryCard(
                              key: ValueKey('active_del_${o['id']}'),
                              order: o,
                              stopIndex: idx + 1,
                              totalStops: activeDeliveriesForOutlet.length,
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
            if (showPickupSection) const SizedBox(height: 22),
          ],

          // Section 2: READY FOR PICKUP (Shown in All Live, Pickup, and Ready modes)
          if (showPickupSection) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _filterIndex == 3 ? const Color(0xFFD97706) : AppDesignSystem.violet600,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _filterIndex == 3 ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _filterIndex == 3 ? 'ITEMS PACKED & READY' : 'READY FOR PICKUP',
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
                    color: _filterIndex == 3 ? const Color(0xFFFEF3C7) : AppDesignSystem.violet200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${displayedPickups.length} Orders',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w800,
                      color: _filterIndex == 3 ? const Color(0xFFB45309) : AppDesignSystem.violet600,
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
              child: displayedPickups.isEmpty
                  ? (_filterIndex == 3
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Text('🍳', style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                Text(
                                  'No Packed Items Waiting',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedOutlet == 'ALL'
                                      ? 'Items will appear here as soon as the kitchen or darkstore packs them.'
                                      : 'No packed items waiting for $_selectedOutlet.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    color: AppDesignSystem.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const EmptyPendingPickupCard(key: ValueKey('empty_pending_pickup')))
                  : Column(
                      key: ValueKey('pending_pickups_${_selectedOutlet}_$_filterIndex'),
                      children: displayedPickups
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
