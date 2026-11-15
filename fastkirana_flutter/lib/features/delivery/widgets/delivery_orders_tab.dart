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

  // 0 = All, 1 = Pickup, 2 = Item Ready
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

  void _showOutletSelectorSheet(BuildContext context, List<Map<String, dynamic>> outlets) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🏪', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'Filter by Outlet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppDesignSystem.slate500),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a store or kitchen to view only its assigned drops and pickups.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppDesignSystem.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: outlets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                    itemBuilder: (context, index) {
                      final outlet = outlets[index];
                      final outletId = outlet['id']?.toString() ?? 'ALL';
                      final outletName = outlet['name']?.toString() ?? 'All Outlets';
                      final count = outlet['count'] as int? ?? 0;
                      final iconStr = outlet['icon']?.toString() ?? '🏪';
                      final isSelected = _selectedOutlet == outletId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3B82F6) : AppDesignSystem.slate200,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(iconStr, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(
                          outletName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFDBEAFE) : AppDesignSystem.slate100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? const Color(0xFF1D4ED8) : AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: isSelected ? const Color(0xFF2563EB) : AppDesignSystem.slate300,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedOutlet = outletId);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPill(int index, String label, int count, Color activeColor) {
    final isSelected = _filterIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? Colors.white : AppDesignSystem.slate700,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 3),
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

    // Counts for Rider 3-pill filter (dynamically filtered by selected outlet)
    final totalCount = activeDeliveriesForOutlet.length + pendingPickupsForOutlet.length;
    final pickupCount = pendingPickupsForOutlet.length;
    final itemReadyCount = itemReadyOrdersForOutlet.length;

    // Filter modes:
    // 0 = All (Show Out for Delivery + Ready for Pickup)
    // 1 = Pickup (Show all Ready for Pickup orders waiting at store)
    // 2 = Ready (Show strictly PACKED/Food Ready orders waiting at counter)
    final showActiveDeliveries = _filterIndex == 0;
    final showPickupSection = _filterIndex == 0 || _filterIndex == 1 || _filterIndex == 2;
    final displayedPickups = _filterIndex == 2 ? itemReadyOrdersForOutlet : pendingPickupsForOutlet;

    final selectedOutletData = outlets.firstWhereOrNull((o) => o['id'] == _selectedOutlet);
    final isAllOutlet = _selectedOutlet == 'ALL';
    final selectedOutletName = selectedOutletData != null ? selectedOutletData['name']?.toString() ?? 'All Outlets' : 'All Outlets';
    final selectedOutletIcon = selectedOutletData != null ? selectedOutletData['icon']?.toString() ?? '🏢' : '🏢';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unified 1-Row Filter Bar for Rider Console:
          // Left: Column-wise Outlet Dropdown Anchor
          // Right: 3-Pill Action Filter (⚡ All | 📦 Pickup | 🔥 Ready)
          SizedBox(
            height: 38,
            child: Row(
              children: [
                // 1. Column-wise Outlet Dropdown Anchor
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showOutletSelectorSheet(context, outlets),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAllOutlet ? Colors.white : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAllOutlet ? AppDesignSystem.slate200 : const Color(0xFF0D9488),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selectedOutletIcon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 82),
                          child: Text(
                            selectedOutletName,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w800,
                              color: isAllOutlet ? AppDesignSystem.slate900 : const Color(0xFF0F766E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isAllOutlet ? AppDesignSystem.slate100 : const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalCount',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w800,
                              color: isAllOutlet ? AppDesignSystem.slate700 : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppDesignSystem.slate600),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // 2. 3-Pill Action Filter for Rider: All | Pickup | Ready
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                          flex: 8,
                          child: _buildFilterPill(0, '⚡ All', totalCount, AppDesignSystem.slate900),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: 11,
                          child: _buildFilterPill(1, '📦 Pickup', pickupCount, AppDesignSystem.violet600),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: 11,
                          child: _buildFilterPill(2, '🔥 Ready', itemReadyCount, const Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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

          // Section 2: READY FOR PICKUP (Shown in All, Pickup, and Ready modes)
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
                        color: _filterIndex == 2 ? const Color(0xFFD97706) : AppDesignSystem.violet600,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _filterIndex == 2 ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _filterIndex == 2 ? 'ITEMS PACKED & READY' : 'READY FOR PICKUP',
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
                    color: _filterIndex == 2 ? const Color(0xFFFEF3C7) : AppDesignSystem.violet200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${displayedPickups.length} Orders',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w800,
                      color: _filterIndex == 2 ? const Color(0xFFB45309) : AppDesignSystem.violet600,
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
                  ? (_filterIndex == 2
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
