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

class RiderActiveDeliveryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isUpdating;
  final void Function(double lat, double lng, String label, {String? address})? onOpenNavigation;
  final void Function(Map<String, dynamic> order)? onShowDoorstepQr;
  final void Function(Map<String, dynamic> order, double lat, double lng)? onShowConfirmation;

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;
  static const Color emeraldGreen = AppDesignSystem.emeraldBrand;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color primaryRed = AppDesignSystem.primary;

  const RiderActiveDeliveryCard({
    super.key,
    required this.order,
    this.isUpdating = false,
    this.onOpenNavigation,
    this.onShowDoorstepQr,
    this.onShowConfirmation,
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
        border: Border.all(color: AppDesignSystem.emerald200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.success.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ambient Green Top Strip
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.emerald600]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.green100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'STOP #1 • ACTIVE DROP',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.green700,
                            ),
                          ),
                        ),
                        if (isFood) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.violet50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppDesignSystem.violet200, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 9.5))),
                                const SizedBox(width: 3),
                                Text(
                                  outlet.name,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.statusShippedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '#$orderNum',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: slateDark),
                    ),
                  ],
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

                // Customer details with Order Time & Call Action Button
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: AppDesignSystem.info, shape: BoxShape.circle),
                        child: Center(
                          child: Text(avatarLetter,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
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
                            const SizedBox(height: 2),
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
                      // Call Button
                      Bounceable(
                        onTap: () {
                          if (customerPhone.isNotEmpty) {
                            final cleanPhone = customerPhone.replaceAll(' ', '').trim();
                            launchUrl(Uri.parse('tel:$cleanPhone'));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer phone number not available')),
                            );
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
                const SizedBox(height: 8),

                // Delivery Address Row
                if (deliverAddress.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusCancelled,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.red200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppDesignSystem.red600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            deliverAddress,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.statusCancelledText,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                // Items List (Clean vertical list for delivery boy to check all products)
                if (items.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.slate100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: AppDesignSystem.emerald600),
                                const SizedBox(width: 5),
                                Text(
                                  'ITEMS IN THIS DROP (${items.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.statusDeliveredText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.green100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.fold<int>(0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1))} qty',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: AppDesignSystem.green700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...items.map((item) {
                          final title = item['title'] ?? item['name'] ?? 'Item';
                          final qty = item['quantity'] ?? 1;
                          final price = (item['price'] as num?)?.toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppDesignSystem.slate200),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                if (price != null && price > 0)
                                  Text(
                                    '₹${(price * (qty is num ? qty : 1)).toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w800,
                                      color: slateMuted,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Payment Status Highlight Strip (Crystal Clear for Rider)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppDesignSystem.green100
                        : (isCod ? AppDesignSystem.statusPending : AppDesignSystem.statusCancelled),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPaid
                          ? AppDesignSystem.emerald200
                          : (isCod ? AppDesignSystem.yellow200 : AppDesignSystem.red200),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(isPaid ? '💳' : (isCod ? '💵' : '⚠️'), style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPaid
                                    ? 'PAID ONLINE (PREPAID)'
                                    : (isCod ? 'CASH ON DELIVERY' : 'PAYMENT PENDING / UNPAID (${rawPayMethod.isNotEmpty ? rawPayMethod : 'ONLINE'})'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  color: isPaid
                                      ? AppDesignSystem.statusDeliveredText
                                      : (isCod ? const Color(0xFFD97706) : AppDesignSystem.red600),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                isPaid
                                    ? '₹0 to collect • Payment already done'
                                    : (isCod
                                        ? 'Collect ₹${total.toInt()} cash from customer'
                                        : '⚠️ Payment NOT received! Collect ₹${total.toInt()} via QR or Cash'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: isPaid
                                      ? AppDesignSystem.statusDeliveredText
                                      : (isCod ? const Color(0xFF78350F) : AppDesignSystem.red700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '₹${total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: isPaid
                              ? AppDesignSystem.statusDeliveredText
                              : (isCod ? const Color(0xFF78350F) : AppDesignSystem.red700),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons: Doorstep UPI QR + Delivered
                Row(
                  children: [
                    if (!isPaid) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onShowDoorstepQr?.call(order),
                          icon: const Icon(Icons.qr_code_rounded, size: 16, color: AppDesignSystem.blue600),
                          label: Text('Doorstep QR',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.blue600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppDesignSystem.blue300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUpdating ? null : () => onShowConfirmation?.call(order, lat, lng),
                        icon: isUpdating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: Text(
                          !isPaid ? 'Collect ₹${total.toInt()} & Deliver' : 'Mark Delivered',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
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

class EmptyOutForDeliveryCard extends StatelessWidget {
  const EmptyOutForDeliveryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
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
          Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 32))),
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
            'Accept new pickup orders from below to start delivering.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
