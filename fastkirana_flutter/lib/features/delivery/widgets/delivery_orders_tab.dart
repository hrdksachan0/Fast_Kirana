import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/utils/route_detector.dart';
import '../../../core/services/order_alarm_service.dart';
import 'rider_active_delivery_card.dart';
import 'rider_pickup_card.dart';

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

  // 4-Road Arterial Route filter
  DeliveryRouteKey _selectedRoute = DeliveryRouteKey.all;

  // 0 = On The Way (Active Deliveries), 1 = Assigned Pickups
  int _deliverySubTab = 0;

  @override
  void initState() {
    super.initState();
    _smartAutoSelectTab();
  }

  @override
  void didUpdateWidget(covariant DeliveryOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeChanged = oldWidget.activeDeliveries.length != widget.activeDeliveries.length;
    final pickupsChanged = oldWidget.pendingPickups.length != widget.pendingPickups.length;
    if (activeChanged || pickupsChanged) {
      _smartAutoSelectTab();
    }
  }

  void _smartAutoSelectTab() {
    // 1. If rider has an active delivery out on the road, auto-focus "On The Way" (Tab 0)
    if (widget.activeDeliveries.isNotEmpty) {
      _deliverySubTab = 0;
    }
    // 2. If NO active delivery on the road, but rider has pending pickups waiting at the store/hub,
    // automatically open "Assigned Pickups" (Tab 1)! Never show an empty screen to the rider!
    else if (widget.pendingPickups.isNotEmpty) {
      _deliverySubTab = 1;
    }
    // 3. Fallback when both are empty
    else {
      _deliverySubTab = 0;
    }
  }

  bool _orderMatchesRoute(Map<String, dynamic> o) {
    if (_selectedRoute == DeliveryRouteKey.all) return true;
    final r = DeliveryRoutes.detect(o);
    return r.key == _selectedRoute;
  }

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

  void _showRouteSelectorSheet(BuildContext context, List<Map<String, dynamic>> allOrders) {
    HapticFeedback.lightImpact();
    final routes = [
      DeliveryRouteKey.all,
      DeliveryRouteKey.hamirpur,
      DeliveryRouteKey.moosanagar,
      DeliveryRouteKey.kanpur,
      DeliveryRouteKey.jahanabad,
      DeliveryRouteKey.townCenter,
    ];

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
                        const Text('📍', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'Filter by Route',
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
                  'Select an arterial delivery route to see orders on that path.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppDesignSystem.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                    itemBuilder: (context, index) {
                      final rKey = routes[index];
                      final rInfo = DeliveryRoutes.getByKey(rKey);
                      final count = rKey == DeliveryRouteKey.all
                          ? allOrders.length
                          : allOrders.where((o) => DeliveryRoutes.detect(o).key == rKey).length;
                      final isSelected = _selectedRoute == rKey;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: rInfo.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? rInfo.primaryColor : rInfo.primaryColor.withValues(alpha: 0.3),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(rInfo.emoji, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(
                          rInfo.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate700,
                          ),
                        ),
                        subtitle: Text(
                          rInfo.description,
                          style: GoogleFonts.inter(fontSize: 10.5, color: AppDesignSystem.slate400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: rInfo.backgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: rInfo.textColor,
                                  ),
                                ),
                              ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: isSelected ? rInfo.primaryColor : AppDesignSystem.slate300,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRoute = rKey);
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

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final allOrders = [...widget.activeDeliveries, ...widget.pendingPickups];
    final outlets = _buildOutletsList(allOrders);

    // Filter by selected outlet and route
    final activeDeliveriesForOutlet = widget.activeDeliveries
        .where((o) => _orderMatchesOutlet(o, _selectedOutlet) && _orderMatchesRoute(o))
        .toList();

    final pendingPickupsForOutlet = widget.pendingPickups
        .where((o) => _orderMatchesOutlet(o, _selectedOutlet) && _orderMatchesRoute(o))
        .toList();

    final itemReadyOrdersForOutlet = pendingPickupsForOutlet
        .where((o) => (o['status'] ?? '').toString().toUpperCase() == 'PACKED')
        .toList();

    // Counts for Rider 3-pill filter (dynamically filtered by selected outlet)
    final totalCount = activeDeliveriesForOutlet.length + pendingPickupsForOutlet.length;
    final pickupCount = pendingPickupsForOutlet.length;
    final itemReadyCount = itemReadyOrdersForOutlet.length;

    final selectedOutletData = outlets.firstWhereOrNull((o) => o['id'] == _selectedOutlet);
    final isAllOutlet = _selectedOutlet == 'ALL';
    final selectedOutletName = selectedOutletData != null ? selectedOutletData['name']?.toString() ?? 'All Outlets' : 'All Outlets';
    final selectedOutletIcon = selectedOutletData != null ? selectedOutletData['icon']?.toString() ?? '🏢' : '🏢';
    final selectedRouteInfo = DeliveryRoutes.getByKey(_selectedRoute);
    final currentRouteCount = _selectedRoute == DeliveryRouteKey.all
        ? allOrders.length
        : allOrders.where((o) => DeliveryRoutes.detect(o).key == _selectedRoute).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Single-Row Dropdown Filters Bar: Outlet Dropdown & Route Dropdown
          SizedBox(
            height: 42,
            child: Row(
              children: [
                // Outlet Dropdown Button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showOutletSelectorSheet(context, outlets),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isAllOutlet ? Colors.white : const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
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
                        children: [
                          Text(selectedOutletIcon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Expanded(
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppDesignSystem.slate600),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Route Dropdown Button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showRouteSelectorSheet(context, allOrders),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedRoute == DeliveryRouteKey.all ? Colors.white : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedRoute == DeliveryRouteKey.all ? AppDesignSystem.slate200 : const Color(0xFF3B82F6),
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
                        children: [
                          Text(selectedRouteInfo.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              selectedRouteInfo.shortLabel,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: _selectedRoute == DeliveryRouteKey.all ? AppDesignSystem.slate900 : const Color(0xFF1D4ED8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _selectedRoute == DeliveryRouteKey.all ? AppDesignSystem.slate100 : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$currentRouteCount',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: _selectedRoute == DeliveryRouteKey.all ? AppDesignSystem.slate700 : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppDesignSystem.slate600),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Page-Wise Sub-Tab Switcher: On The Way vs Assigned Orders
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // slate-100
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Sub-tab 0: On The Way
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      OrderAlarmService.instance.stopAlarm();
                      setState(() => _deliverySubTab = 0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _deliverySubTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _deliverySubTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.two_wheeler_rounded,
                            size: 15,
                            color: _deliverySubTab == 0 ? const Color(0xFF059669) : AppDesignSystem.slate500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'On The Way',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: _deliverySubTab == 0 ? FontWeight.w900 : FontWeight.w700,
                              color: _deliverySubTab == 0 ? AppDesignSystem.slate900 : AppDesignSystem.slate600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _deliverySubTab == 0 ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${activeDeliveriesForOutlet.length}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w900,
                                color: _deliverySubTab == 0 ? const Color(0xFF047857) : AppDesignSystem.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Sub-tab 1: Assigned Orders
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _deliverySubTab = 1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _deliverySubTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _deliverySubTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 14,
                            color: _deliverySubTab == 1 ? const Color(0xFF7C3AED) : AppDesignSystem.slate500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Assigned Pickups',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: _deliverySubTab == 1 ? FontWeight.w900 : FontWeight.w700,
                              color: _deliverySubTab == 1 ? AppDesignSystem.slate900 : AppDesignSystem.slate600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _deliverySubTab == 1 ? const Color(0xFFEDE9FE) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pendingPickupsForOutlet.length}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w900,
                                color: _deliverySubTab == 1 ? const Color(0xFF6D28D9) : AppDesignSystem.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3A. PAGE-WISE VIEW: ON THE WAY (Active Deliveries)
          if (_deliverySubTab == 0) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: activeDeliveriesForOutlet.isEmpty
                  ? Container(
                      key: const ValueKey('empty_out_for_delivery_tab'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 34))),
                          const SizedBox(height: 10),
                          Text(
                            'No orders out for delivery',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accept assigned pickup orders to start your delivery trip.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.slate500,
                            ),
                          ),
                          if (pendingPickupsForOutlet.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _deliverySubTab = 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF), // purple-100
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Assigned Pickups (${pendingPickupsForOutlet.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF7E22CE), // purple-700
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF7E22CE)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      key: ValueKey('active_deliveries_${_selectedOutlet}_$_selectedRoute'),
                      children: [
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
          ],

          // 3B. PAGE-WISE VIEW: ASSIGNED PICKUPS (Option 2 Kitchen Switcher)
          if (_deliverySubTab == 1) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: pendingPickupsForOutlet.isEmpty
                  ? const EmptyPendingPickupCard(key: ValueKey('empty_pending_pickup_tab'))
                  : Column(
                      key: ValueKey('pending_pickups_${_selectedOutlet}_$_selectedRoute'),
                      children: pendingPickupsForOutlet
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
