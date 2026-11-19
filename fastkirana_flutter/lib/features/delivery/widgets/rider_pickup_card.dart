import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fastminute_flutter/core/theme/design_system.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/services/logger_service.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/utils/app_url_launcher.dart';
import 'order_recipient_helper.dart';
import 'rider_cart_modal.dart';
import '../../../core/utils/route_detector.dart';

class RiderPickupCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isUpdating;
  final void Function(double lat, double lng, String label, {String? address})? onOpenNavigation;
  final void Function(String orderId, String newStatus, {Map<String, dynamic>? extra})? onUpdateStatus;

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;
  static const Color emeraldGreen = AppDesignSystem.emeraldBrand;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color primaryRed = AppDesignSystem.primary;

  const RiderPickupCard({
    super.key,
    required this.order,
    this.isUpdating = false,
    this.onOpenNavigation,
    this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length));
    final isFood = (order['orderType'] == 'RESTAURANT') || (order['restaurantId'] != null) || orderNum.contains('-R');
    final outlet = getOutletLocation(
      restaurantId: order['restaurantId']?.toString(),
      shopName: order['shopName']?.toString(),
      orderType: order['orderType']?.toString(),
      rawOrder: order,
    );
    final shopName = outlet.name;
    final status = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final customer = order['user'] is Map ? order['user'] : {'name': 'Customer', 'phone': null};
    final address = order['address'] is Map ? order['address'] : null;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final rawPayMethod = (order['paymentMethod'] ?? '').toString().toUpperCase().trim();
    final rawPayStatus = (order['paymentStatus'] ?? '').toString().toUpperCase().trim();
    final isPaid = rawPayStatus == 'PAID';
    final isCod = rawPayMethod == 'COD' || rawPayMethod.isEmpty;
    final rawItems = (order['items'] as List<dynamic>?) ?? [];
    final companionItems = (order['companionOrder'] is Map ? (order['companionOrder']['items'] as List<dynamic>?) : null) ?? [];
    final subOrdersItems = (order['subOrders'] is List)
        ? (order['subOrders'] as List).expand((sub) => (sub is Map && sub['items'] is List) ? (sub['items'] as List) : []).toList()
        : [];
    final items = [
      ...rawItems,
      ...companionItems,
      if (rawItems.isEmpty) ...subOrdersItems,
    ];
    final lat = (address?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng = (address?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
    final batch = order['batch'] is Map ? (order['batch'] as Map<String, dynamic>) : null;
    final isBatch = batch?['isBatch'] == true;
    final partnerOrderId = batch?['partnerOrderId']?.toString();
    final partnerOrderReadableId = batch?['partnerOrderReadableId']?.toString();
    final bonusEarning = (batch?['bonusEarning'] as num?)?.toDouble() ?? 12.0;
    final distanceMeters = batch?['distanceBetweenDropsMeters'] as num?;
    final stopIndex = batch?['stopIndex'] ?? 1;
    // isUpdating is passed via constructor

    final recipient = OrderRecipientDetails.fromOrder(order);
    final customerName = recipient.recipientName;
    final customerPhone = (recipient.recipientPhone != null && recipient.recipientPhone!.isNotEmpty)
        ? recipient.recipientPhone!
        : ((address?['phone']?.toString().trim().isNotEmpty == true)
            ? address!['phone'].toString().trim()
            : (customer['phone']?.toString().trim() ?? ''));
    final avatarLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C';

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
    }
    final orderTimeStr = DateFormat('hh:mm a').format(orderDate);
    final elapsedMinutes = DateTime.now().difference(orderDate).inMinutes.clamp(0, 9999);
    final isSlaUrgent = elapsedMinutes >= 20;
    final isSlaWarning = elapsedMinutes >= 15 && elapsedMinutes < 20;

    String deliverAddress = '';
    if (address != null) {
      if (address['formattedAddress'] != null && address['formattedAddress'].toString().trim().isNotEmpty) {
        deliverAddress = address['formattedAddress'].toString().trim();
      } else {
        final parts = [
          address['houseNo'],
          address['street'],
          address['area'],
          address['landmark'],
          address['city'],
          address['pincode'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
         .map((p) => p.toString().trim())
         .toList();
        deliverAddress = parts.isNotEmpty ? parts.join(', ') : '';
      }
    }
    if (deliverAddress.isEmpty) deliverAddress = 'Ghatampur, Kanpur Nagar';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFood ? AppDesignSystem.rose100 : AppDesignSystem.teal100,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top SLA Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isSlaUrgent
                  ? const Color(0xFFFEE2E2)
                  : (isSlaWarning ? const Color(0xFFFEF3C7) : (isFood ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                bottom: BorderSide(
                  color: isSlaUrgent
                      ? const Color(0xFFFCA5A5)
                      : (isSlaWarning ? const Color(0xFFFDE68A) : (isFood ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0))),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isSlaUrgent
                            ? const Color(0xFFDC2626)
                            : (isSlaWarning ? const Color(0xFFD97706) : (isFood ? AppDesignSystem.rose500 : AppDesignSystem.emeraldBrand)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSlaUrgent
                          ? '⚠️ ${elapsedMinutes}m SLA OVERDUE'
                          : (isSlaWarning ? '⏱️ ${elapsedMinutes}m SLA Warning' : '⏱️ ${elapsedMinutes}m elapsed • On Track'),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w900,
                        color: isSlaUrgent
                            ? const Color(0xFFB91C1C)
                            : (isSlaWarning ? const Color(0xFFB45309) : (isFood ? AppDesignSystem.red700 : const Color(0xFF047857))),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                Text(
                  orderTimeStr,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w700,
                    color: isSlaUrgent
                        ? const Color(0xFFB91C1C)
                        : (isSlaWarning ? const Color(0xFFB45309) : AppDesignSystem.slate500),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order ID + FOOD pill | Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '#$orderNum',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Builder(builder: (context) {
                          final rInfo = DeliveryRoutes.detect(order);
                          return Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: rInfo.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: rInfo.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${rInfo.emoji} ${rInfo.shortLabel}',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: rInfo.textColor,
                              ),
                            ),
                          );
                        }),
                        if (isFood) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusCancelled,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                const SizedBox(width: 3),
                                Text(
                                  'FOOD',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.red600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: status == 'PACKED'
                            ? AppDesignSystem.green100
                            : (status == 'PREPARING' ? AppDesignSystem.statusPending : AppDesignSystem.blue50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'PACKED'
                              ? AppDesignSystem.emerald200
                              : (status == 'PREPARING' ? AppDesignSystem.yellow200 : AppDesignSystem.blue200),
                        ),
                      ),
                      child: Text(
                        status == 'PACKED' ? 'PACKED • READY' : status,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: status == 'PACKED'
                              ? AppDesignSystem.green700
                              : (status == 'PREPARING' ? AppDesignSystem.amber700 : AppDesignSystem.blue700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: outlet.isRestaurant ? AppDesignSystem.violet50 : AppDesignSystem.green50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: outlet.isRestaurant ? AppDesignSystem.violet200 : AppDesignSystem.green200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(outlet.isRestaurant ? '🍽️' : '🏪', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outlet.name,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w800,
                                color: outlet.isRestaurant ? AppDesignSystem.statusShippedText : AppDesignSystem.green800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              outlet.address,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), color: AppDesignSystem.slate500, height: 1.25),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (outlet.phone != null && outlet.phone!.isNotEmpty) ...[
                        Bounceable(
                          onTap: () {
                            final clean = outlet.phone!.replaceAll(' ', '').trim();
                            AppUrlLauncher.launchString('tel:$clean', context: context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppDesignSystem.violet200),
                            ),
                            child: const Icon(Icons.phone_rounded, size: 14, color: AppDesignSystem.violet600),
                          ),
                        ),
                      ],
                      Bounceable(
                        onTap: () => onOpenNavigation?.call(outlet.lat, outlet.lng, outlet.name, address: outlet.address),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: outlet.isRestaurant ? AppDesignSystem.violet300 : AppDesignSystem.emerald200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_rounded, size: 12, color: outlet.isRestaurant ? AppDesignSystem.violet600 : AppDesignSystem.green700),
                              const SizedBox(width: 3),
                              Text(
                                outlet.isRestaurant ? 'Go Outlet' : 'Go Store',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: outlet.isRestaurant ? AppDesignSystem.violet600 : AppDesignSystem.green700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Clean Customer Note if present (e.g. Ring bell on arrival)
                if (recipient.deliveryInstructions != null && recipient.deliveryInstructions!.trim().isNotEmpty) ...[
                  Builder(builder: (context) {
                    final cleanNote = recipient.deliveryInstructions!
                        .replaceAll('[STOCK_DEDUCTED]', '')
                        .trim();
                    if (cleanNote.isEmpty) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.amber50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔔', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Note: "$cleanNote"',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.amber800,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Full Complete Delivery Address (Pura Address Without Truncation)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Text('📍', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customerName.isNotEmpty) ...[
                              Text(
                                'Deliver To: $customerName',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              deliverAddress,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Items Preview Strip + View Cart Button (Photo View Type)
                if (items.isNotEmpty) ...[
                  RiderCartPreviewWidget(
                    order: order,
                    onViewCart: () => showRiderCartModal(context, order),
                  ),
                  const SizedBox(height: 10),
                ],

                const Divider(height: 1, color: AppDesignSystem.slate100),
                const SizedBox(height: 10),

                // Footer: Total Value + Status on top, Full-width Action Button below (Aapki Image 2 Jaisa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '₹${total.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 17),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppDesignSystem.green100
                                : (isCod ? AppDesignSystem.statusPending : AppDesignSystem.statusCancelled),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPaid
                                  ? AppDesignSystem.emerald200
                                  : (isCod ? AppDesignSystem.yellow200 : AppDesignSystem.red200),
                            ),
                          ),
                          child: Text(
                            isPaid ? '✅ PAID' : (isCod ? '💵 COD' : '⚠️ UNPAID'),
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w900,
                              color: isPaid
                                  ? AppDesignSystem.green700
                                  : (isCod ? AppDesignSystem.amber700 : AppDesignSystem.red600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status == 'PREPARING' || status == 'CONFIRMED')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFood ? 'Kitchen Preparing' : 'Store Packing',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // FULL-WIDTH SOLID ACTION BUTTON
                Bounceable(
                  onTap: isUpdating
                      ? null
                      : () => onUpdateStatus?.call(
                            orderId,
                            'SHIPPED',
                          ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBatch
                            ? [const Color(0xFF7C3AED), const Color(0xFF6D28D9)]
                            : (status == 'PACKED'
                                ? [const Color(0xFF059669), const Color(0xFF047857)]
                                : [const Color(0xFF9333EA), const Color(0xFF7E22CE)]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (status == 'PACKED' ? const Color(0xFF059669) : const Color(0xFF9333EA))
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('📦', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 6),
                                Text(
                                  isFood
                                      ? 'CONFIRM PICKUP FROM RESTAURANT'
                                      : 'CONFIRM PICKUP & START TRIP ➔',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
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
        ],
      ),
    );
  }
}


class EmptyPendingPickupCard extends StatelessWidget {
  const EmptyPendingPickupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
      ),
      child: Center(
        child: Text(
          'No pickup orders waiting at store right now.',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 12),
            color: AppDesignSystem.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
