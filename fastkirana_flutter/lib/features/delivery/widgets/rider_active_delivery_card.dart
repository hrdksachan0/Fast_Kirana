import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_url_launcher.dart';
import 'package:fastminute_flutter/core/theme/design_system.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/services/logger_service.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'order_recipient_helper.dart';
import 'rider_cart_modal.dart';
import '../../../core/utils/route_detector.dart';

class RiderActiveDeliveryCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isUpdating;
  final int? stopIndex;
  final int? totalStops;
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
    this.stopIndex,
    this.totalStops,
    this.onOpenNavigation,
    this.onShowDoorstepQr,
    this.onShowConfirmation,
  });

  @override
  State<RiderActiveDeliveryCard> createState() => _RiderActiveDeliveryCardState();
}

class _RiderActiveDeliveryCardState extends State<RiderActiveDeliveryCard>
    with TickerProviderStateMixin {
  bool _itemsExpanded = false;
  double _slideProgress = 0.0;
  bool _slideCompleted = false;
  bool _isDragging = false;

  late AnimationController _springController;
  late Animation<double> _springAnimation;
  late AnimationController _shimmerController;
  int _lastHapticTier = 0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _springAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    )..addListener(() {
      if (!mounted) return;
      setState(() => _slideProgress = _springAnimation.value.clamp(0.0, 1.0));
    });

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _springController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RiderActiveDeliveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['id'] != widget.order['id'] || (!widget.isUpdating && oldWidget.isUpdating)) {
      _slideProgress = 0.0;
      _slideCompleted = false;
      _lastHapticTier = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderId = order['id']?.toString() ?? '';
    final orderNum = (order['readableId'] ?? orderId.substring(0, math.min(8, orderId.length))).toString();
    final isFood = (order['orderType'] == 'RESTAURANT') || (order['restaurantId'] != null) || orderNum.contains('-R');
    final outlet = getOutletLocation(
      restaurantId: order['restaurantId']?.toString(),
      shopName: order['shopName']?.toString(),
      orderType: order['orderType']?.toString(),
      rawOrder: order,
    );
    final routeInfo = DeliveryRoutes.detect(order);
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
    final isCombined = order['companionOrder'] != null ||
        order['combinedId'] != null ||
        (order['subOrders'] is List && (order['subOrders'] as List).length > 1);

    double? parseCoord(dynamic v) => v == null ? null : double.tryParse(v.toString());
    final rawLat = parseCoord(order['deliveryLat']) ??
        parseCoord(address?['lat']) ??
        parseCoord(address?['latitude']);
    final rawLng = parseCoord(order['deliveryLng']) ??
        parseCoord(address?['lng']) ??
        parseCoord(address?['longitude']);
    bool isDarkstoreFallback(double? la, double? ln) {
      if (la == null || ln == null || (la == 0.0 && ln == 0.0)) return true;
      const r = 6371000.0;
      final dLat = (la - AppConfig.darkstoreLat) * math.pi / 180.0;
      final dLng = (ln - AppConfig.darkstoreLng) * math.pi / 180.0;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(AppConfig.darkstoreLat * math.pi / 180.0) *
              math.cos(la * math.pi / 180.0) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2);
      final distM = r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return distM <= 50.0;
    }
    final isPinApprox = isDarkstoreFallback(rawLat, rawLng);
    final lat = isPinApprox ? 0.0 : rawLat!;
    final lng = isPinApprox ? 0.0 : rawLng!;
    final batch = order['batch'] is Map ? (order['batch'] as Map<String, dynamic>) : null;
    final isBatch = batch?['isBatch'] == true;
    final effectiveStop = widget.stopIndex ?? (batch?['stopIndex'] as int?) ?? 1;
    final effectiveTotal = widget.totalStops ?? (batch?['totalStops'] as int?) ?? (isBatch ? 2 : 1);

    final recipient = OrderRecipientDetails.fromOrder(order);
    final customerName = recipient.recipientName;
    final customerPhone = (recipient.recipientPhone != null && recipient.recipientPhone!.isNotEmpty)
        ? recipient.recipientPhone!
        : ((address?['phone']?.toString().trim().isNotEmpty == true)
            ? address!['phone'].toString().trim()
            : (customer['phone']?.toString().trim() ?? ''));

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (e, _) {
        LoggerService.error('DeliveryDashboard: silent catch', e);
      }
    }
    final orderTimeStr = DateFormat('hh:mm a').format(orderDate);
    final elapsedMinutes = DateTime.now().difference(orderDate).inMinutes.clamp(0, 9999);
    final isSlaUrgent = elapsedMinutes >= 20;
    final isSlaWarning = elapsedMinutes >= 15 && elapsedMinutes < 20;

    // Extract prominent Landmark / Area headline + clean street address
    String landmarkHeadline = '';
    String deliverAddress = '';
    if (address != null) {
      final lm = address['landmark']?.toString().trim() ?? '';
      final area = address['area']?.toString().trim() ?? '';
      if (lm.isNotEmpty && lm != 'null') {
        landmarkHeadline = lm;
      } else if (area.isNotEmpty && area != 'null') {
        landmarkHeadline = area;
      }

      if (address['formattedAddress'] != null && address['formattedAddress'].toString().trim().isNotEmpty) {
        deliverAddress = address['formattedAddress'].toString().trim();
      } else {
        final rawParts = [
          address['houseNo'],
          address['street'],
          address['area'],
          address['landmark'],
          address['city'],
          address['pincode'],
        ]
            .where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null' && p.toString().trim() != '.')
            .map((p) => p.toString().trim())
            .toList();
        final seen = <String>{};
        final parts = <String>[];
        for (final p in rawParts) {
          final norm = p.toLowerCase();
          if (seen.add(norm)) parts.add(p);
        }
        deliverAddress = parts.isNotEmpty ? parts.join(', ') : '';
      }
    }
    if (deliverAddress.isEmpty) deliverAddress = 'Ghatampur, Kanpur Nagar';

    // High-contrast hero palette
    final List<Color> heroGrad = isPaid
        ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
        : (isCod
            ? [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)]
            : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]);
    final Color heroBorder = isPaid
        ? const Color(0xFF6EE7B7)
        : (isCod ? const Color(0xFFFDBA74) : const Color(0xFFFCA5A5));
    final Color heroLabelColor = isPaid
        ? const Color(0xFF047857)
        : (isCod ? const Color(0xFFC2410C) : const Color(0xFFB91C1C));
    final Color heroAmountColor = isPaid
        ? const Color(0xFF065F46)
        : (isCod ? const Color(0xFF9A3412) : const Color(0xFF991B1B));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSlaUrgent ? const Color(0xFFFCA5A5) : heroBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.slate900.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. GIANT HIGH-CONTRAST PAYMENT HERO STRIP (0.5s Sunlight Readability)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: heroGrad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22.5)),
              border: Border(bottom: BorderSide(color: heroBorder, width: 1.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid
                            ? '✅ PAID ONLINE • NO CASH'
                            : (isCod ? '⚠️ COLLECT CASH OR QR' : '⚠️ UNPAID • COLLECT QR / CASH'),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: heroLabelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPaid ? 'COLLECT ₹0' : '₹${total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 23),
                          fontWeight: FontWeight.w900,
                          color: heroAmountColor,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSlaUrgent
                            ? const Color(0xFFDC2626)
                            : (isSlaWarning ? const Color(0xFFD97706) : Colors.white),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSlaUrgent
                              ? const Color(0xFFDC2626)
                              : (isSlaWarning ? const Color(0xFFD97706) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSlaUrgent ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                            size: 12,
                            color: (isSlaUrgent || isSlaWarning) ? Colors.white : AppDesignSystem.slate800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${elapsedMinutes}m',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w900,
                              color: (isSlaUrgent || isSlaWarning) ? Colors.white : AppDesignSystem.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#$orderNum',
                      style: GoogleFonts.robotoMono(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CARD BODY
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact Stop + Outlet + Route Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: effectiveStop == 1 ? const Color(0xFF0F172A) : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        effectiveTotal > 1 ? 'STOP $effectiveStop/$effectiveTotal' : 'ACTIVE DROP',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w900,
                          color: effectiveStop == 1 ? Colors.white : const Color(0xFF1E40AF),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isFood ? AppDesignSystem.violet50 : AppDesignSystem.emerald50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFood ? AppDesignSystem.violet200 : AppDesignSystem.emerald200,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isFood ? '🍽️ ${outlet.name}' : '🛒 ${outlet.name}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: isFood ? const Color(0xFF5B21B6) : AppDesignSystem.emerald800,
                        ),
                      ),
                    ),
                    if (isCombined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                        ),
                        child: Text(
                          '📦 Combined',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    if (routeInfo.key != DeliveryRouteKey.all)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          routeInfo.shortLabel,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate700,
                          ),
                        ),
                      ),
                  ],
                ),

                // Gift / Order for Someone Else Banner
                if (recipient.isOrderForSomeone) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDBA74), width: 1.1),
                    ),
                    child: Text(
                      '🎁 Gift Order • Deliver to ${recipient.recipientName}${recipient.buyerName != null ? ' (By ${recipient.buyerName})' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 2. BIG, UNCUT CUSTOMER NAME (17.5pt Bold, 2 lines max)
                Text(
                  customerName,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 17.5),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (customerPhone.isNotEmpty)
                      Text(
                        customerPhone.startsWith('+') ? customerPhone : '+91 $customerPhone',
                        style: GoogleFonts.robotoMono(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate600,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '• $orderTimeStr',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. LANDMARK-FIRST ADDRESS BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (landmarkHeadline.isNotEmpty) ...[
                              Text(
                                landmarkHeadline,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14.5),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.slate900,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              deliverAddress,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, landmarkHeadline.isNotEmpty ? 12 : 13.5),
                                fontWeight: landmarkHeadline.isNotEmpty ? FontWeight.w600 : FontWeight.w800,
                                color: landmarkHeadline.isNotEmpty ? AppDesignSystem.slate600 : AppDesignSystem.slate900,
                                height: 1.35,
                              ),
                            ),
                            if (recipient.deliveryInstructions != null &&
                                recipient.deliveryInstructions!.trim().isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF9C3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE047)),
                                ),
                                child: Text(
                                  '📝 ${recipient.deliveryInstructions!.trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF854D0E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. COLLAPSIBLE ITEMS DRAWER (Keeps Card 1-Screen Compact!)
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _itemsExpanded = !_itemsExpanded);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('📦', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${items.length} ${items.length == 1 ? 'Item' : 'Items'} • Tap to verify',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.slate800,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _itemsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: AppDesignSystem.slate600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _itemsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: RiderCartPreviewWidget(
                              order: order,
                              onViewCart: () => showRiderCartModal(context, order),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 5. BIG 54px ONE-HANDED THUMB ACTION TILES (Call | Maps | QR Pay)
                Row(
                  children: [
                    Expanded(
                      child: _ThumbActionTile(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        bgColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFFBFDBFE),
                        fgColor: const Color(0xFF1D4ED8),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (customerPhone.isNotEmpty) {
                            final cleanPhone = customerPhone.replaceAll(' ', '').trim();
                            AppUrlLauncher.launchString('tel:$cleanPhone', context: context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer phone number not available')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ThumbActionTile(
                        icon: Icons.navigation_rounded,
                        label: 'Maps',
                        bgColor: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFECACA),
                        fgColor: const Color(0xFFB91C1C),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenNavigation?.call(lat, lng, customerName, address: deliverAddress);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: !isPaid
                          ? _ThumbActionTile(
                              icon: Icons.qr_code_2_rounded,
                              label: 'QR Pay',
                              bgColor: const Color(0xFFECFDF5),
                              borderColor: const Color(0xFF6EE7B7),
                              fgColor: const Color(0xFF047857),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onShowDoorstepQr?.call(order);
                              },
                            )
                          : _ThumbActionTile(
                              icon: Icons.receipt_long_rounded,
                              label: 'Items',
                              bgColor: AppDesignSystem.slate100,
                              borderColor: AppDesignSystem.slate200,
                              fgColor: AppDesignSystem.slate800,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                showRiderCartModal(context, order);
                              },
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 6. SWIGGY-STYLE 64px FULL-PILL SLIDE-TO-DELIVER SLIDER (Round White Thumb, Matte Green)
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double sliderHeight = 64;
                    const double pad = 5;
                    const double thumbWidth = sliderHeight - (pad * 2); // 54x54 perfect circle
                    final double maxDrag = math.max(1.0, constraints.maxWidth - thumbWidth - (pad * 2));
                    final double thumbLeft = pad + (_slideProgress * maxDrag);
                    final double textOpacity = (1.0 - _slideProgress * 1.45).clamp(0.0, 1.0);
                    final bool isNearComplete = _slideProgress >= 0.78;

                    return GestureDetector(
                      onHorizontalDragStart: widget.isUpdating || _slideCompleted
                          ? null
                          : (_) {
                              setState(() => _isDragging = true);
                              HapticFeedback.selectionClick();
                            },
                      onHorizontalDragUpdate: widget.isUpdating || _slideCompleted
                          ? null
                          : (details) {
                              final next = (_slideProgress + details.delta.dx / maxDrag).clamp(0.0, 1.0);
                              final tier = (next * 4).floor();
                              if (tier != _lastHapticTier && tier > 0) {
                                _lastHapticTier = tier;
                                HapticFeedback.selectionClick();
                              }
                              setState(() => _slideProgress = next);
                            },
                      onHorizontalDragEnd: widget.isUpdating || _slideCompleted
                          ? null
                          : (_) {
                              setState(() => _isDragging = false);
                              if (_slideProgress >= 0.78) {
                                HapticFeedback.heavyImpact();
                                setState(() {
                                  _slideProgress = 1.0;
                                  _slideCompleted = true;
                                });
                                widget.onShowConfirmation?.call(order, lat, lng);
                                Future.delayed(const Duration(milliseconds: 900), () {
                                  if (mounted && !widget.isUpdating) {
                                    setState(() {
                                      _slideProgress = 0.0;
                                      _slideCompleted = false;
                                      _lastHapticTier = 0;
                                    });
                                  }
                                });
                              } else {
                                _springAnimation = Tween<double>(begin: _slideProgress, end: 0.0).animate(
                                  CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
                                );
                                _springController.forward(from: 0.0);
                                _lastHapticTier = 0;
                              }
                            },
                      child: Container(
                        height: sliderHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF008744),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF008744).withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Matte Darker Green Fill Following Thumb
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: (thumbLeft + thumbWidth * 0.5 + pad).clamp(0.0, constraints.maxWidth),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006B35),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),

                            // 2. Clean Sentence-Case Center Label + Double Chevron
                            if (widget.isUpdating)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            else
                              Opacity(
                                opacity: textOpacity,
                                child: Transform.translate(
                                  offset: Offset(_slideProgress * 12.0, 0),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 42, right: 16),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            !isPaid
                                                ? 'Collect ₹${total.toInt()} & Deliver'
                                                : 'Slide to Deliver',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 15),
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -0.1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                        Transform.translate(
                                          offset: const Offset(-8, 0),
                                          child: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: Colors.white.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // 3. Round White 54x54 Thumb Knob
                            Positioned(
                              left: thumbLeft,
                              top: pad,
                              bottom: pad,
                              child: AnimatedScale(
                                scale: _isDragging ? 1.04 : 1.0,
                                duration: const Duration(milliseconds: 140),
                                child: Container(
                                  width: thumbWidth,
                                  height: thumbWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      child: isNearComplete
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Color(0xFF008744),
                                              size: 26,
                                              key: ValueKey('check'),
                                            )
                                          : const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Color(0xFF008744),
                                              size: 24,
                                              key: ValueKey('arrow'),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _ThumbActionTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bounceable(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w900,
                color: fgColor,
              ),
            ),
          ],
        ),
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
