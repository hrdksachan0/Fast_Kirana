import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/app_url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../core/utils/route_detector.dart';
import '../../../data/models/order.dart';
import '../../../providers/store_settings_provider.dart';
import '../../orders/order_detail_screen.dart';
import '../../delivery/widgets/rider_cart_modal.dart';
import '../../../core/services/order_alarm_service.dart';

/// Reusable Admin Order Card extracted from admin_orders_list.dart
/// Handles status badges, KOT dispatch, rider assignments, super-edit, and items preview.
class AdminOrderCard extends ConsumerWidget {
  static const Color primaryRed = AppDesignSystem.primary;

  final Order order;
  final bool? isLive;
  final bool isKOTPrinted;
  final String? kotPrintedBy;
  final bool isKOTSending;
  final List<Map<String, String>> availableRiders;
  final VoidCallback? onTap;
  final void Function(Order order, OrderStatus newStatus)? onUpdateStatus;
  final void Function(Order parentOrder, Order subOrder, OrderStatus newStatus)? onUpdateSubOrderStatus;
  final void Function(Order order, String riderId, String riderName, String riderPhone)? onAssignRider;
  final void Function(Order order, DeliveryRouteKey newRoute)? onUpdateRoute;
  final void Function(String phone, String orderId)? onWhatsappCustomer;
  final void Function(String phone)? onCallCustomer;
  final void Function(Order order, OrderItem item)? onShowSubstitution;
  final void Function(Order order)? onVerifyPayment;
  final void Function(Order order)? onConvertToCOD;
  final void Function(Order order)? onSendWhatsAppPaymentReminder;
  final void Function(Order order)? onOpenSuperOrderEdit;
  final void Function(Order order)? onShowRecordRefund;
  final void Function(Order order)? onSendRemoteKOT;
  final void Function(Order order)? onSendWhatsAppKOT;
  final bool isProcessing;

  const AdminOrderCard({
    super.key,
    required this.order,
    this.isLive,
    this.isKOTPrinted = false,
    this.kotPrintedBy,
    this.isKOTSending = false,
    this.availableRiders = const [],
    this.onTap,
    this.onUpdateStatus,
    this.onUpdateSubOrderStatus,
    this.onAssignRider,
    this.onUpdateRoute,
    this.onWhatsappCustomer,
    this.onCallCustomer,
    this.onShowSubstitution,
    this.onVerifyPayment,
    this.onConvertToCOD,
    this.onSendWhatsAppPaymentReminder,
    this.onOpenSuperOrderEdit,
    this.onShowRecordRefund,
    this.onSendRemoteKOT,
    this.onSendWhatsAppKOT,
    this.isProcessing = false,
  });

  String? _resolveAssignedRiderGpsTs() {
    for (final r in availableRiders) {
      final rid = r['id'];
      final rname = r['name']?.trim().toLowerCase();
      if ((order.deliveryUserId != null && rid == order.deliveryUserId) ||
          (order.deliveryBoyName != null &&
              order.deliveryBoyName!.trim().isNotEmpty &&
              rname == order.deliveryBoyName!.trim().toLowerCase())) {
        return r['gpsUpdatedAt'];
      }
    }
    return null;
  }

  Widget _buildRiderGpsFreshnessPill(String? gpsUpdatedAt) {
    String label = 'GPS Off';
    Color bg = const Color(0xFFFEE2E2);
    Color border = const Color(0xFFFCA5A5);
    Color fg = const Color(0xFFB91C1C);
    Color dot = const Color(0xFFEF4444);

    if (gpsUpdatedAt != null && gpsUpdatedAt.trim().isNotEmpty) {
      final raw = gpsUpdatedAt.trim();
      final normalized = (raw.endsWith('Z') || raw.contains('+') || RegExp(r'-\d{2}:\d{2}$').hasMatch(raw))
          ? raw
          : '${raw}Z';
      final parsed = DateTime.tryParse(normalized)?.toUtc();
      if (parsed != null) {
        final ageSec = DateTime.now().toUtc().difference(parsed).inSeconds;
        final safeAge = ageSec < 0 ? 0 : ageSec;
        String ageText;
        if (safeAge < 60) {
          ageText = '${safeAge}s ago';
        } else if (safeAge < 3600) {
          ageText = '${safeAge ~/ 60}m ago';
        } else if (safeAge < 86400) {
          ageText = '${safeAge ~/ 3600}h ago';
        } else {
          ageText = '${safeAge ~/ 86400}d ago';
        }
        label = 'GPS $ageText';
        if (safeAge <= 60) {
          bg = const Color(0xFFDCFCE7);
          border = const Color(0xFF86EFAC);
          fg = const Color(0xFF15803D);
          dot = const Color(0xFF22C55E);
        } else if (safeAge <= 300) {
          bg = const Color(0xFFFEF3C7);
          border = const Color(0xFFFCD34D);
          fg = const Color(0xFFB45309);
          dot = const Color(0xFFF59E0B);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static Color getStatusColor(OrderStatus? status) {
    if (status == null) return AppDesignSystem.slate500;
    switch (status) {
      case OrderStatus.adminPending:
        return AppDesignSystem.orange600;
      case OrderStatus.pending:
        return AppDesignSystem.warning;
      case OrderStatus.confirmed:
        return AppDesignSystem.cyan600;
      case OrderStatus.packed:
        return AppDesignSystem.violet600;
      case OrderStatus.shipped:
        return AppDesignSystem.orange600;
      case OrderStatus.delivered:
        return AppDesignSystem.green600;
      case OrderStatus.cancelled:
        return AppDesignSystem.red600;
    }
  }

  static bool isLiveOrder(Order order) {
    return order.status == OrderStatus.adminPending ||
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.packed ||
        order.status == OrderStatus.shipped;
  }

  static bool isUnpaidOnline(Order order) {
    final isCOD = order.paymentMethod == PaymentMethod.cod;
    final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
    final hasOnlineAttempt = (order.notes ?? '').contains('Cashfree') || 
                             (order.notes ?? '').contains('UPI') ||
                             (order.notes ?? '').contains('cf_');
    return !isPaid && (!isCOD || hasOnlineAttempt);
  }

  static String formatOrderTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  void _showRiderSelectionSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final isAssigned = (order.deliveryBoyName != null && order.deliveryBoyName!.trim().isNotEmpty);
    final currentRiderNorm = (order.deliveryBoyName ?? '').trim().toLowerCase();
    final rInfo = DeliveryRoutes.detect(order);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign Delivery Partner',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            Text(
                              'Order #${order.displayId} · ${rInfo.emoji} ${rInfo.shortLabel}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.slate500,
                              ),
                            ),
                          ],
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
                const SizedBox(height: 12),

                // Option 1: Store Partner (Self Delivery)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    final settings = ref.read(storeSettingsProvider).valueOrNull;
                    final storePhone = settings?.contactPhone.isNotEmpty == true
                        ? settings!.contactPhone
                        : AppConfig.supportPhone;
                    onAssignRider?.call(order, 'store_admin_self', 'Store Partner', storePhone);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (currentRiderNorm == 'store partner' || currentRiderNorm == 'store_admin_self')
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (currentRiderNorm == 'store partner' || currentRiderNorm == 'store_admin_self')
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF86EFAC),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBBF7D0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Store Partner (Self Delivery)',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                              Text(
                                'Store staff delivers directly without external rider',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                        if (currentRiderNorm == 'store partner' || currentRiderNorm == 'store_admin_self')
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22)
                        else
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF16A34A), size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppDesignSystem.slate200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'AVAILABLE RIDERS (${availableRiders.length})',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppDesignSystem.slate200)),
                  ],
                ),
                const SizedBox(height: 8),

                if (availableRiders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No registered delivery partners online.\nUse Store Partner (Self Delivery) or register riders in admin.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.slate500),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableRiders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final rider = availableRiders[index];
                        final riderId = rider['id'] ?? '';
                        final riderName = rider['name'] ?? 'Rider';
                        final riderPhone = rider['phone'] ?? '';
                        final isThisSelected = isAssigned &&
                            (order.deliveryUserId == riderId ||
                             order.deliveryBoyName?.trim().toLowerCase() == riderName.trim().toLowerCase() ||
                             order.deliveryBoyPhone == riderPhone);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            onAssignRider?.call(order, riderId, riderName, riderPhone);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isThisSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isThisSelected ? const Color(0xFF3B82F6) : AppDesignSystem.slate200,
                                width: isThisSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isThisSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                  child: Text(
                                    riderName.isNotEmpty ? riderName.substring(0, 1).toUpperCase() : 'R',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              riderName,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: isThisSelected ? FontWeight.w900 : FontWeight.w700,
                                                color: isThisSelected ? const Color(0xFF1D4ED8) : AppDesignSystem.slate900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          _buildRiderGpsFreshnessPill(rider['gpsUpdatedAt']?.toString()),
                                        ],
                                      ),
                                      if (riderPhone.isNotEmpty)
                                        Text(
                                          riderPhone,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppDesignSystem.slate500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isThisSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Assigned',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Option 3: Unassign (if already assigned)
                if (isAssigned) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onAssignRider?.call(order, 'UNASSIGNED', '', '');
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.person_off_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: Text(
                        'Unassign Delivery Partner',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: const Color(0xFFFEF2F2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = getStatusColor(order.status);
    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'Customer';
    final resolvedPhone = (order.customerPhone?.trim().isNotEmpty == true)
        ? order.customerPhone!.trim()
        : (order.addressRaw?['phone']?.toString().trim().isNotEmpty == true)
            ? order.addressRaw!['phone'].toString().trim()
            : (order.addressRaw?['mobile']?.toString().trim().isNotEmpty == true)
                ? order.addressRaw!['mobile'].toString().trim()
                : '';
    final custPhone = resolvedPhone.isNotEmpty ? resolvedPhone : 'Not Available';
    final custAddr = order.customerAddress?.trim().isNotEmpty == true
        ? order.customerAddress!.trim()
        : (order.addressRaw?['address']?.toString().trim().isNotEmpty == true
            ? order.addressRaw!['address'].toString().trim()
            : 'No address provided');
    final rawItems = order.items ?? [];
    final List<OrderItem> itemsList = [];
    final seenCardItemKeys = <String>{};
    for (final item in rawItems) {
      final key = item.id.isNotEmpty
          ? item.id
          : '${item.name.toLowerCase().trim()}_${item.selectedVariant?.toLowerCase().trim() ?? ""}_${item.notes?.toLowerCase().trim() ?? ""}';
      if (seenCardItemKeys.add(key)) {
        itemsList.add(item);
      }
    }
    final live = isLive ?? isLiveOrder(order);
    // Calculate elapsed waiting time for Live orders (SLA Alert System)
    final elapsedMinutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isSlaUrgent = live && elapsedMinutes >= 15 && (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed || order.status == OrderStatus.adminPending);
    final isSlaWarning = live && elapsedMinutes >= 10 && !isSlaUrgent && (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed || order.status == OrderStatus.adminPending);
    // KOT state passed via constructor
    final isPickup = (order.deliveryMethod ?? '').toUpperCase().contains('PICKUP') ||
        (order.deliveryMethod ?? '').toUpperCase().contains('TAKEAWAY');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: isSlaUrgent ? const Color(0xFFEF4444) : (live ? statusColor : AppDesignSystem.slate300),
            width: live ? 5.5 : 3.0,
          ),
          top: BorderSide(
            color: isSlaUrgent ? const Color(0xFFFCA5A5) : (live ? statusColor.withValues(alpha: 0.3) : AppDesignSystem.slate200),
            width: 1.0,
          ),
          right: BorderSide(
            color: isSlaUrgent ? const Color(0xFFFCA5A5) : (live ? statusColor.withValues(alpha: 0.3) : AppDesignSystem.slate200),
            width: 1.0,
          ),
          bottom: BorderSide(
            color: isSlaUrgent ? const Color(0xFFFCA5A5) : (live ? statusColor.withValues(alpha: 0.3) : AppDesignSystem.slate200),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isSlaUrgent
                ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSlaUrgent ? 12 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Top SLA Alert & Amount Header Bar (FastMinute Hybrid Blinkit/Zepto Style)
          if (live) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
              decoration: BoxDecoration(
                color: isSlaUrgent
                    ? const Color(0xFFFEE2E2)
                    : (isSlaWarning ? const Color(0xFFFEF3C7) : AppDesignSystem.slate100),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                  bottom: BorderSide(
                    color: isSlaUrgent
                        ? const Color(0xFFFCA5A5)
                        : (isSlaWarning ? const Color(0xFFFDE68A) : AppDesignSystem.slate200),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSlaUrgent
                              ? const Color(0xFFDC2626)
                              : (isSlaWarning ? const Color(0xFFD97706) : AppDesignSystem.slate500),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSlaUrgent
                            ? '⚠️ ${elapsedMinutes}m SLA OVERDUE'
                            : (isSlaWarning ? '⏱️ ${elapsedMinutes}m SLA Warning' : '⏱️ ${elapsedMinutes}m waiting'),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: isSlaUrgent
                              ? const Color(0xFFB91C1C)
                              : (isSlaWarning ? const Color(0xFFB45309) : AppDesignSystem.slate700),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Builder(builder: (context) {
                      final shop = order.shopName;
                      final isRest = order.isRestaurantOrder;
                      final outletName = (shop != null && shop.isNotEmpty && shop != 'null' && shop != 'FastMinute Dark Store' && shop != 'FastKirana Dark Store')
                          ? shop
                          : (isRest ? (RestaurantRegistry.getName(order.restaurantId) ?? 'Restaurant') : 'Dark Store');
                      final isCombined = order.isCombined;

                      if (isCombined) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA855F7), width: 1.3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9333EA).withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'COMBINED (${order.subOrders?.length ?? 2})',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF581C87),
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (isRest) {
                        // Ultra-highlighted, vibrant, high-contrast Restaurant Badge
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.22),
                                blurRadius: 5,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🍽️', style: TextStyle(fontSize: 12.5)),
                              const SizedBox(width: 4.5),
                              Flexible(
                                child: Text(
                                  outletName.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF9A3412),
                                    letterSpacing: 0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFF34D399), width: 1.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🛒', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 3.5),
                            Flexible(
                              child: Text(
                                'DARK STORE',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF065F46),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
          // 1. Order ID, Total, Status Header & Details Action
          InkWell(
            borderRadius: (live && (isSlaUrgent || isSlaWarning || order.status == OrderStatus.pending || order.status == OrderStatus.confirmed || order.status == OrderStatus.adminPending))
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: onTap ?? () {
              Navigator.push(
                context,
                FadeSlideRoute(page: OrderDetailScreen(order: order)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '#${order.readableId ?? order.id}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            // In History tab (live == false), render a single concise outlet badge since top SLA bar is not present
                            if (!live) ...[
                              if (order.isCombined)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA855F7), width: 1.1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('✨', style: TextStyle(fontSize: 10)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'COMBINED (${order.subOrders?.length ?? 2})',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF6B21A8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (order.isRestaurantOrder)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDD5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFB923C), width: 1.1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🍽️', style: TextStyle(fontSize: 10)),
                                      const SizedBox(width: 3),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        child: Text(
                                          (RestaurantRegistry.getName(order.restaurantId) ?? order.shopName ?? 'Restaurant').toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFC2410C),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                                  Builder(builder: (context) {
                                    final rInfo = DeliveryRoutes.detect(order);
                                    return PopupMenuButton<DeliveryRouteKey>(
                                      tooltip: 'Change Delivery Route',
                                      initialValue: rInfo.key,
                                      onSelected: (key) => onUpdateRoute?.call(order, key),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: DeliveryRouteKey.hamirpur,
                                          child: Text('🔴 Hamirpur Road (South)'),
                                        ),
                                        const PopupMenuItem(
                                          value: DeliveryRouteKey.moosanagar,
                                          child: Text('🟣 Moosanagar Road (West)'),
                                        ),
                                        const PopupMenuItem(
                                          value: DeliveryRouteKey.kanpur,
                                          child: Text('🔵 Kanpur Road (North)'),
                                        ),
                                        const PopupMenuItem(
                                          value: DeliveryRouteKey.jahanabad,
                                          child: Text('🟢 Jahanabad Road (East)'),
                                        ),
                                        const PopupMenuItem(
                                          value: DeliveryRouteKey.townCenter,
                                          child: Text('🟡 Town Center'),
                                        ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: rInfo.backgroundColor,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: rInfo.primaryColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${rInfo.emoji} ${rInfo.shortLabel}',
                                              style: GoogleFonts.inter(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: rInfo.textColor,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(Icons.arrow_drop_down_rounded, size: 14, color: rInfo.textColor),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  if (isPickup)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppDesignSystem.statusPending,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppDesignSystem.warning,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('🚶‍♂️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                          const SizedBox(width: 3),
                                          Text(
                                            'SELF PICKUP',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9.5),
                                              fontWeight: FontWeight.w900,
                                              color: AppDesignSystem.amber700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Order Status Badge + KOT Status Badge directly below #4097 & Route Pill
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      order.status.displayName.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 9.5),
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  if (live && (order.isRestaurantOrder || order.isCombined))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isKOTPrinted ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isKOTPrinted ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isKOTPrinted
                                            ? ((kotPrintedBy != null && kotPrintedBy!.trim().isNotEmpty)
                                                ? 'KOT ✓ · ${kotPrintedBy!.trim().split(' ').first}'
                                                : 'KOT ✓')
                                            : 'KOT Pending',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 9.5),
                                          fontWeight: FontWeight.w800,
                                          color: isKOTPrinted ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Payment Badge + Order Time directly ABOVE the Price (Space Optimized)
                      Builder(
                        builder: (context) {
                          final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
                          final isCod = order.paymentMethod == PaymentMethod.cod;
                          final timeStr = formatOrderTime(order.createdAt);

                          String badgeText;
                          Color bg;
                          Color border;
                          Color text;

                          if (isPaid) {
                            badgeText = isCod ? '💵 PAID' : '💳 PAID';
                            bg = AppDesignSystem.green100;
                            border = AppDesignSystem.emerald200;
                            text = AppDesignSystem.green700;
                          } else {
                            badgeText = isCod ? '💵 COD' : '⏳ UNPAID';
                            bg = isCod ? AppDesignSystem.statusPending : const Color(0xFFFFE4E6);
                            border = isCod ? AppDesignSystem.yellow200 : const Color(0xFFFDA4AF);
                            text = isCod ? AppDesignSystem.amber700 : const Color(0xFFBE123C);
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: border,
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  timeStr,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (order.refundAmount > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${(order.total - order.refundAmount).clamp(0.0, double.infinity).toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 16.5),
                                fontWeight: FontWeight.w900,
                                color: primaryRed,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '₹${order.total.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.slate400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '↩️ -₹${order.refundAmount.toInt()} REFUND',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 8.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '₹${order.total.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Sub-outlets Breakdown Strip for Combined Orders
          if (order.isCombined && order.subOrders != null && order.subOrders!.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppDesignSystem.violet50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📦 OUTLET STATUSES (Tap to toggle):',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w900, color: AppDesignSystem.statusShippedText, letterSpacing: 0.3),
                      ),
                      if (order.status != OrderStatus.packed)
                        GestureDetector(
                          onTap: onUpdateStatus != null ? () => onUpdateStatus!(order, OrderStatus.packed) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.violet600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⚡ Pack All',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: order.subOrders!.map((sub) {
                      final isRest = sub.isRestaurantOrder;
                      final outletIcon = isRest ? '🍽️' : '🛒';
                      final outletTitle = isRest
                          ? ((sub.shopName != null && sub.shopName!.isNotEmpty && sub.shopName != 'FastMinute Dark Store' && sub.shopName != 'FastKirana Dark Store')
                              ? sub.shopName!
                              : (RestaurantRegistry.getName(sub.restaurantId) ?? 'Restaurant'))
                          : 'Dark Store (Grocery)';
                      final isPacked = sub.status == OrderStatus.packed || sub.status == OrderStatus.shipped || sub.status == OrderStatus.delivered;

                      return GestureDetector(
                        onTap: () {
                          final nextStatus = isPacked ? OrderStatus.confirmed : OrderStatus.packed;
                          onUpdateSubOrderStatus?.call(order, sub, nextStatus);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPacked ? AppDesignSystem.green100 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isPacked ? AppDesignSystem.emerald200 : AppDesignSystem.violet300, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(outletIcon, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                              const SizedBox(width: 5),
                              Text(
                                '$outletTitle: ',
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w800, color: AppDesignSystem.indigo950),
                              ),
                              Text(
                                sub.status.displayName.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: isPacked ? AppDesignSystem.green600 : AppDesignSystem.fuchsia600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isPacked ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                size: 12,
                                color: isPacked ? AppDesignSystem.green600 : AppDesignSystem.fuchsia600,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // 2. Customer Contact Details Box
          Container(
            color: AppDesignSystem.slate50,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: AppDesignSystem.slate600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              custName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppDesignSystem.slate500),
                          const SizedBox(width: 6),
                          Text(
                            custPhone,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.slate600,
                            ),
                          ),
                        ],
                      ),
                      if (isPickup) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.statusPending,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.yellow200),
                          ),
                          child: Row(
                            children: [
                              Text('🚶‍♂️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'STORE PICKUP — Customer will collect at counter',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.amber700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1.0),
                              child: Icon(Icons.location_on_outlined, size: 13, color: AppDesignSystem.slate500),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                custAddr,
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate600, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Action Buttons: Call & WhatsApp
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final phoneToMsg = resolvedPhone.isNotEmpty ? resolvedPhone : custPhone;
                        if (phoneToMsg.isEmpty || phoneToMsg == 'Not Available') {
                          AppToast.showWarning(context, 'No phone number found for this customer');
                          return;
                        }
                        if (onWhatsappCustomer != null) {
                          onWhatsappCustomer!(phoneToMsg, order.readableId ?? order.id);
                        } else {
                          var clean = phoneToMsg.replaceAll(RegExp(r'[^0-9]'), '');
                          if (!clean.startsWith('91') && clean.length == 10) clean = '91$clean';
                          if (clean.isNotEmpty) {
                            AppUrlLauncher.launchString('https://wa.me/$clean', context: context);
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_rounded, color: AppDesignSystem.green600, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppDesignSystem.green100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'WhatsApp Customer',
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final phoneToCall = resolvedPhone.isNotEmpty ? resolvedPhone : custPhone;
                        final clean = phoneToCall.replaceAll(RegExp(r'[^0-9+]'), '');
                        if (clean.isEmpty) {
                          AppToast.showWarning(context, 'No phone number found for this customer');
                          return;
                        }
                        if (onCallCustomer != null) {
                          onCallCustomer!(clean);
                        } else {
                          AppUrlLauncher.launchString('tel:$clean', context: context);
                        }
                      },
                      icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Call Customer',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Ordered Items List with Photo Preview Strip & View Cart Modal (Like Rider)
          if (itemsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: RiderCartPreviewWidget(
                order: order.toJson(),
                onViewCart: () => showRiderCartModal(context, order.toJson()),
              ),
            ),

          if (order.notes?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (order.notes ?? '').split('\n').where((s) => s.trim().isNotEmpty).map((line) {
                  final trimmed = line.trim();
                  final isRefund = trimmed.contains('Refund');
                  final isCashfree = trimmed.contains('Cashfree');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isRefund
                              ? Icons.replay_rounded
                              : (isCashfree ? Icons.payment_rounded : Icons.sticky_note_2_outlined),
                          size: 13,
                          color: isRefund
                              ? const Color(0xFFE11D48)
                              : (isCashfree ? const Color(0xFF0284C7) : AppDesignSystem.orange600),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            trimmed,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: isRefund
                                  ? const Color(0xFFE11D48)
                                  : (isCashfree ? const Color(0xFF0369A1) : AppDesignSystem.orange600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          if (isPickup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: AppDesignSystem.amber50,
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 16, color: AppDesignSystem.amber700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store Self-Pickup Order — No Delivery Partner Required',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.amber700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // 3.4 Modern Tactile Rider Assignment Section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: () {
                final isAssigned = (order.deliveryBoyName != null && order.deliveryBoyName!.trim().isNotEmpty);
                final norm = (order.deliveryBoyName ?? '').trim().toLowerCase();
                final isStorePartner = norm == 'store partner' || norm == 'store_admin_self' || norm.contains('store partner');

                if (!isAssigned) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showRiderSelectionSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assign Delivery Partner',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  'Tap to choose rider or self-delivery',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5.5),
                        decoration: BoxDecoration(
                          color: isStorePartner ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isStorePartner ? Icons.storefront_rounded : Icons.two_wheeler_rounded,
                          size: 15,
                          color: isStorePartner ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 5,
                              runSpacing: 2,
                              children: [
                                Text(
                                  order.deliveryBoyName!,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isStorePartner ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isStorePartner ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    isStorePartner ? 'SELF' : 'RIDER',
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: isStorePartner ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                if (!isStorePartner &&
                                    order.status != OrderStatus.delivered &&
                                    order.status != OrderStatus.cancelled)
                                  _buildRiderGpsFreshnessPill(_resolveAssignedRiderGpsTs()),
                              ],
                            ),
                            if (order.deliveryBoyPhone != null && order.deliveryBoyPhone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  order.deliveryBoyPhone!,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignSystem.slate500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (order.deliveryBoyPhone != null && order.deliveryBoyPhone!.isNotEmpty) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onCallCustomer?.call(order.deliveryBoyPhone!),
                          child: Container(
                            padding: const EdgeInsets.all(5.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                            ),
                            child: const Icon(Icons.call_rounded, size: 15, color: Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onWhatsappCustomer?.call(order.deliveryBoyPhone!, order.readableId ?? order.id),
                          child: Container(
                            padding: const EdgeInsets.all(5.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                            ),
                            child: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF15803D)),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showRiderSelectionSheet(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate100,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppDesignSystem.slate300, width: 0.9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.slate700,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, size: 14, color: AppDesignSystem.slate600),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ),

          // ───── UNPAID ONLINE PAYMENT ACTIONS (Payment Pending Queue) ─────
          if (isUnpaidOnline(order)) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE11D48)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Pending (₹${order.total.toInt()})',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF9F1239),
                              ),
                            ),
                            Text(
                              'Online payment incomplete. Verify Cashfree, convert to COD, or send WhatsApp link.',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                color: const Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // 1. Verify Online
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onVerifyPayment != null ? () => onVerifyPayment!(order) : null,
                          icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                          label: Text(
                            'Verify',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 2. Convert to COD
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onConvertToCOD != null ? () => onConvertToCOD!(order) : null,
                          icon: const Icon(Icons.local_atm_rounded, size: 14, color: Colors.white),
                          label: Text(
                            'To COD',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 3. WhatsApp Reminder
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onSendWhatsAppPaymentReminder != null ? () => onSendWhatsAppPaymentReminder!(order) : null,
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF15803D)),
                          label: Text(
                            'Remind',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDCFCE7),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

          // ───── 3.5 UNIFIED DYNAMIC STAGE PROGRESSION ACTION BAR ─────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            color: AppDesignSystem.background,
            child: Row(
              children: [
                // Dynamic Primary Stage Action Button
                Expanded(
                  child: () {
                    // 1. ADMIN PENDING / PENDING → Confirm Order ✓ + Reject
                    if (order.status == OrderStatus.adminPending || order.status == OrderStatus.pending) {
                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: (onUpdateStatus != null && !isProcessing)
                                  ? () {
                                      HapticFeedback.heavyImpact();
                                      OrderAlarmService.instance.stopAlarm();
                                      onUpdateStatus!(order, OrderStatus.confirmed);
                                    }
                                  : null,
                              icon: isProcessing
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                              label: Text(
                                isProcessing ? 'CONFIRMING...' : 'Confirm Order ✓',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isProcessing
                                    ? AppDesignSystem.green600.withValues(alpha: 0.6)
                                    : AppDesignSystem.green600,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: (onUpdateStatus != null && !isProcessing)
                                  ? () {
                                      HapticFeedback.mediumImpact();
                                      OrderAlarmService.instance.stopAlarm();
                                      onUpdateStatus!(order, OrderStatus.cancelled);
                                    }
                                  : null,
                              icon: const Icon(Icons.cancel_rounded, size: 15, color: AppDesignSystem.red600),
                              label: Text(
                                'Reject',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.red600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.1),
                                backgroundColor: const Color(0xFFFEF2F2),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // 2. CONFIRMED → Mark Packed 📦
                    if (order.status == OrderStatus.confirmed) {
                      return ElevatedButton.icon(
                        onPressed: (onUpdateStatus != null && !isProcessing)
                            ? () {
                                HapticFeedback.heavyImpact();
                                onUpdateStatus!(order, OrderStatus.packed);
                              }
                            : null,
                        icon: isProcessing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isProcessing ? 'PACKING...' : 'Mark Packed 📦',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5), // Indigo
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      );
                    }

                    // 3. PACKED → On the Way 🚀 (or Assign Rider 🛵)
                    if (order.status == OrderStatus.packed) {
                      final hasRider = (order.deliveryBoyName != null && order.deliveryBoyName!.trim().isNotEmpty);
                      if (!hasRider && !isPickup) {
                        return ElevatedButton.icon(
                          onPressed: () => _showRiderSelectionSheet(context, ref),
                          icon: const Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Assign Rider 🛵',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7), // Sky/Cyan
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        );
                      }

                      return ElevatedButton.icon(
                        onPressed: (onUpdateStatus != null && !isProcessing)
                            ? () {
                                HapticFeedback.heavyImpact();
                                onUpdateStatus!(order, OrderStatus.shipped);
                              }
                            : null,
                        icon: isProcessing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.delivery_dining_rounded, size: 18, color: Colors.white),
                        label: Text(
                          isProcessing ? 'DISPATCHING...' : 'On the Way 🚀',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C), // Sunset Orange
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      );
                    }

                    // 4. SHIPPED → Delivered ✓
                    if (order.status == OrderStatus.shipped) {
                      return ElevatedButton.icon(
                        onPressed: (onUpdateStatus != null && !isProcessing)
                            ? () {
                                HapticFeedback.heavyImpact();
                                onUpdateStatus!(order, OrderStatus.delivered);
                              }
                            : null,
                        icon: isProcessing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.task_alt_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isProcessing ? 'DELIVERING...' : 'Delivered ✓',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.green600,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      );
                    }

                    // 5. DELIVERED → Complete banner
                    if (order.status == OrderStatus.delivered) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Text(
                              'Delivered ✓',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 6. CANCELLED
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA), width: 1.1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Text(
                            'Order Cancelled',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
                ),

                const SizedBox(width: 6),

                // Manual Status Override / Reversal Menu
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Change / Override Status',
                  initialValue: order.status,
                  onSelected: (newStatus) {
                    if (newStatus != order.status) {
                      HapticFeedback.mediumImpact();
                      onUpdateStatus?.call(order, newStatus);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: OrderStatus.adminPending,
                      child: _StatusDropdownItem(
                        icon: Icons.admin_panel_settings_rounded,
                        label: '🔒 Needs Approval',
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.pending,
                      child: _StatusDropdownItem(
                        icon: Icons.schedule_rounded,
                        label: 'Placed (Pending)',
                        color: AppDesignSystem.amber600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.confirmed,
                      child: _StatusDropdownItem(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Confirmed',
                        color: AppDesignSystem.cyan600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.packed,
                      child: _StatusDropdownItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Packed / Ready',
                        color: AppDesignSystem.violet600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.shipped,
                      child: _StatusDropdownItem(
                        icon: Icons.delivery_dining_rounded,
                        label: 'On the Way (Out for Delivery)',
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.delivered,
                      child: _StatusDropdownItem(
                        icon: Icons.task_alt_rounded,
                        label: 'Delivered',
                        color: AppDesignSystem.green600,
                      ),
                    ),
                    PopupMenuItem(
                      value: OrderStatus.cancelled,
                      child: _StatusDropdownItem(
                        icon: Icons.cancel_outlined,
                        label: 'Cancelled',
                        color: AppDesignSystem.red600,
                      ),
                    ),
                  ],
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 15, color: statusColor),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_drop_down_rounded, size: 16, color: statusColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // ───── 4-BUTTON COMPACT UTILITY STRIP (Zoomed Out, Height ~32px) ─────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                // 1. Edit Items & Swap
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onOpenSuperOrderEdit != null ? () => onOpenSuperOrderEdit!(order) : null,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 3),
                          Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // 2. Record Refund
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onShowRecordRefund != null ? () => onShowRecordRefund!(order) : null,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDA4AF), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.replay_rounded, size: 13, color: Color(0xFFE11D48)),
                          const SizedBox(width: 3),
                          Text(
                            order.refundAmount > 0 ? '₹${order.refundAmount.toInt()}' : 'Refund',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFBE123C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // 3. Send KOT (with Reprint guard & Printed-By indicator)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: (isKOTSending || onSendRemoteKOT == null) ? null : () => onSendRemoteKOT!(order),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isKOTSending
                            ? AppDesignSystem.statusPending
                            : (isKOTPrinted
                                ? AppDesignSystem.green100
                                : ((order.isRestaurantOrder || order.isCombined) && live
                                    ? const Color(0xFFFFF7ED)
                                    : const Color(0xFFEFF6FF))),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isKOTSending
                              ? AppDesignSystem.yellow200
                              : (isKOTPrinted
                                  ? AppDesignSystem.emerald200
                                  : ((order.isRestaurantOrder || order.isCombined) && live
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFBFDBFE))),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isKOTSending) ...[
                            const SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(AppDesignSystem.amber600)),
                            ),
                          ] else ...[
                            Icon(
                              isKOTPrinted ? Icons.check_circle_rounded : Icons.print_rounded,
                              size: 13,
                              color: isKOTPrinted
                                  ? AppDesignSystem.green600
                                  : ((order.isRestaurantOrder || order.isCombined) && live
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                isKOTPrinted
                                    ? ((kotPrintedBy != null && kotPrintedBy!.trim().isNotEmpty)
                                        ? '✓ ${kotPrintedBy!.trim().split(' ').first}'
                                        : 'KOT ✓')
                                    : ((order.isRestaurantOrder || order.isCombined) && live ? 'KOT !' : 'KOT'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w800,
                                  color: isKOTPrinted
                                      ? AppDesignSystem.green700
                                      : ((order.isRestaurantOrder || order.isCombined) && live
                                          ? const Color(0xFFC2410C)
                                          : const Color(0xFF1D4ED8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // 4. WhatsApp KOT / Slip
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onSendWhatsAppKOT != null ? () => onSendWhatsAppKOT!(order) : null,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            order.isCombined ? 'Slips' : (order.isRestaurantOrder ? 'WA KOT' : 'WA Slip'),
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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

class _StatusDropdownItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusDropdownItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 12.5),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
