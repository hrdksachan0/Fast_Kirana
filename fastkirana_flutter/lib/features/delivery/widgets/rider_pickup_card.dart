import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/services/logger_service.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'order_recipient_helper.dart';
import 'rider_cart_modal.dart';

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
    final items = (order['items'] as List<dynamic>?) ?? [];
    final lat = (address?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng = (address?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
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
          // Top Colored Highlight Line
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isFood ? AppDesignSystem.rose500 : AppDesignSystem.emeraldBrand,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                        Text(
                          '#$orderNum',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
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
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), color: AppDesignSystem.slate500),
                              maxLines: 1,
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
                            launchUrl(Uri.parse('tel:$clean'));
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

                // Recipient Details Banner if ordered for someone else
                if (recipient.isOrderForSomeone) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED), // amber-50
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDBA74), width: 1.2), // amber-300
                    ),
                    child: Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER FOR SOMEONE ELSE',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFC2410C), // orange-700
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Deliver to: ${recipient.recipientName}${recipient.buyerName != null ? ' • By: ${recipient.buyerName}' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF9A3412), // orange-900
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDBA74), width: 0.8),
                          ),
                          child: Text(
                            'Gift Order',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Customer Info Box with Order Received Time
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate100),
                  ),
                  child: Row(
                    children: [
                      // Letter Avatar
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.info,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13),
                                      fontWeight: FontWeight.w800,
                                      color: slateDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (recipient.isOrderForSomeone) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFDBA74), width: 0.6),
                                    ),
                                    child: Text(
                                      'Recipient',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 8.5),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFC2410C),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.blue50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 9, color: AppDesignSystem.blue600),
                                      const SizedBox(width: 2.5),
                                      Text(
                                        orderTimeStr,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.blue700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (customerPhone.isNotEmpty)
                              Text(
                                customerPhone.startsWith('+') ? customerPhone : '+91 $customerPhone',
                                style: GoogleFonts.robotoMono(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w600,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action button: Direct Call (Google Maps is prominently available below)
                      Bounceable(
                        onTap: () {
                          if (customerPhone.isNotEmpty) {
                            final cleanPhone = customerPhone.replaceAll(' ', '').trim();
                            launchUrl(Uri.parse('tel:$cleanPhone'));
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesignSystem.blue200, width: 0.8),
                          ),
                          child: const Center(
                            child: Icon(Icons.phone_outlined, size: 18, color: AppDesignSystem.blue600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delivery Note callout if instructions are present
                if (recipient.deliveryInstructions != null && recipient.deliveryInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.amber50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Note: ${recipient.deliveryInstructions!}',
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
                  ),
                ],
                const SizedBox(height: 10),

                // Pickup & Deliver Routes Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppDesignSystem.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('PICKUP: ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              shopName,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppDesignSystem.info, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('DELIVER: ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateMuted)),
                          Expanded(
                            child: Text(
                              deliverAddress,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: slateDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 📍 1-Tap Turn-by-Turn Google Maps Navigation Banner
                Bounceable(
                  onTap: () => onOpenNavigation?.call(lat, lng, customerName, address: deliverAddress),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppDesignSystem.emerald700, AppDesignSystem.success],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Navigate in Google Maps ➔',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

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

                // Footer: Total Value | Action Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL ORDER VALUE',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 8.5), fontWeight: FontWeight.w800, color: slateMuted),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${total.toInt()}',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 17), fontWeight: FontWeight.w900, color: slateDark),
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
                                  isPaid
                                      ? '✅ PAID'
                                      : (isCod ? '💵 COD' : '⚠️ UNPAID (${rawPayMethod.isNotEmpty ? rawPayMethod : 'ONLINE'})'),
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
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(isPaid ? '💳' : (isCod ? '🔥' : '⚠️'), style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  isPaid
                                      ? 'Paid Online'
                                      : (isCod ? 'Collect ₹${total.toInt()} Cash' : 'Collect ₹${total.toInt()} (Payment Pending)'),
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: isPaid
                                        ? AppDesignSystem.emerald600
                                        : (isCod ? AppDesignSystem.amber600 : AppDesignSystem.red600),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Button
                    if (status == 'PREPARING' || status == 'CONFIRMED')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusPending,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppDesignSystem.yellow200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: AppDesignSystem.amber600),
                                const SizedBox(width: 4),
                                Text(
                                  isFood ? 'Cooking in Kitchen...' : 'Packing at Store...',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.amber600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Bounceable(
                            onTap: () => onUpdateStatus?.call(orderId, 'SHIPPED'),
                            child: Text(
                              isFood ? 'Food Ready? Pick Up' : 'Items Ready? Pick Up',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.emerald600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Bounceable(
                        onTap: isUpdating ? null : () => onUpdateStatus?.call(orderId, 'SHIPPED'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFood
                                  ? [const Color(0xFFE11D48), const Color(0xFFBE123C)]
                                  : [const Color(0xFF059669), const Color(0xFF047857)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (isFood ? AppDesignSystem.rose500 : AppDesignSystem.emerald600).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUpdating)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              else ...[
                                const Icon(Icons.delivery_dining_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  isFood ? 'Pick Up Food ➔' : 'Pick Up From Store ➔',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
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
