import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/order.dart';
import '../../../providers/store_settings_provider.dart';
import '../../orders/order_detail_screen.dart';

/// Reusable Admin Order Card extracted from admin_orders_list.dart
/// Handles status badges, KOT dispatch, rider assignments, super-edit, and items preview.
class AdminOrderCard extends ConsumerWidget {
  static const Color primaryRed = AppDesignSystem.primary;

  final Order order;
  final bool? isLive;
  final bool isKOTPrinted;
  final bool isKOTSending;
  final List<Map<String, String>> availableRiders;
  final VoidCallback? onTap;
  final void Function(Order order, OrderStatus newStatus)? onUpdateStatus;
  final void Function(Order parentOrder, Order subOrder, OrderStatus newStatus)? onUpdateSubOrderStatus;
  final void Function(Order order, String riderId, String riderName, String riderPhone)? onAssignRider;
  final void Function(String phone, String orderId)? onWhatsappCustomer;
  final void Function(String phone)? onCallCustomer;
  final void Function(Order order, OrderItem item)? onShowSubstitution;
  final void Function(Order order)? onVerifyRazorpay;
  final void Function(Order order)? onConvertToCOD;
  final void Function(Order order)? onSendWhatsAppPaymentReminder;
  final void Function(Order order)? onOpenSuperOrderEdit;
  final void Function(Order order)? onShowRecordRefund;
  final void Function(Order order)? onSendRemoteKOT;
  final void Function(Order order)? onSendWhatsAppKOT;

  const AdminOrderCard({
    super.key,
    required this.order,
    this.isLive,
    this.isKOTPrinted = false,
    this.isKOTSending = false,
    this.availableRiders = const [],
    this.onTap,
    this.onUpdateStatus,
    this.onUpdateSubOrderStatus,
    this.onAssignRider,
    this.onWhatsappCustomer,
    this.onCallCustomer,
    this.onShowSubstitution,
    this.onVerifyRazorpay,
    this.onConvertToCOD,
    this.onSendWhatsAppPaymentReminder,
    this.onOpenSuperOrderEdit,
    this.onShowRecordRefund,
    this.onSendRemoteKOT,
    this.onSendWhatsAppKOT,
  });

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
    return !isCOD && !isPaid;
  }

  static String formatOrderTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = getStatusColor(order.status);
    final custName = order.customerName?.isNotEmpty == true ? order.customerName! : 'Customer';
    final custPhone = (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty)
        ? order.customerPhone!.trim()
        : (order.addressRaw?['phone']?.toString().isNotEmpty == true
            ? order.addressRaw!['phone'].toString().trim()
            : (order.customerPhone?.isNotEmpty == true ? order.customerPhone! : 'Not Available'));
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
    // KOT state passed via constructor
    final isPickup = (order.deliveryMethod ?? '').toUpperCase().contains('PICKUP') ||
        (order.deliveryMethod ?? '').toUpperCase().contains('TAKEAWAY');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: live ? statusColor.withValues(alpha: 0.4) : AppDesignSystem.slate200,
          width: live ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Order ID, Total, Status Header & Details Action
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: onTap ?? () {
              Navigator.push(
                context,
                FadeSlideRoute(page: OrderDetailScreen(order: order)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_rounded, size: 18, color: statusColor),
                        ),
                        const SizedBox(width: 10),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPickup ? AppDesignSystem.statusPending : AppDesignSystem.green100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPickup ? AppDesignSystem.warning : AppDesignSystem.emerald200,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(isPickup ? '🚶‍♂️' : '🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                        const SizedBox(width: 3),
                                        Text(
                                          isPickup ? 'SELF PICKUP' : 'DELIVERY',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9.5),
                                            fontWeight: FontWeight.w900,
                                            color: isPickup ? AppDesignSystem.amber700 : AppDesignSystem.green700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (order.isCombined) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [AppDesignSystem.violet600, AppDesignSystem.fuchsia600],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                                          const SizedBox(width: 3),
                                          Text(
                                            'COMBINED',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9),
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                   Builder(
                                     builder: (context) {
                                       final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
                                       final isCod = order.paymentMethod == PaymentMethod.cod;

                                       String badgeText;
                                       Color bg;
                                       Color border;
                                       Color text;

                                       if (isPaid) {
                                         badgeText = isCod ? '💵 CASH RECEIVED' : '✅ ONLINE PAID';
                                         bg = AppDesignSystem.green100;
                                         border = AppDesignSystem.emerald200;
                                         text = AppDesignSystem.green700;
                                       } else {
                                         badgeText = isCod ? '💵 COD' : '⏳ UNPAID (ONLINE)';
                                         bg = isCod ? AppDesignSystem.statusPending : const Color(0xFFFFE4E6);
                                         border = isCod ? AppDesignSystem.yellow200 : const Color(0xFFFDA4AF);
                                         text = isCod ? AppDesignSystem.amber700 : const Color(0xFFBE123C);
                                       }

                                       return Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                                       );
                                     },
                                   ),
                                  Text(
                                    formatOrderTime(order.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w600,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                              if (!order.isCombined) ...[
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    final shop = order.shopName;
                                    final isRest = order.isRestaurantOrder;
                                    final outletName = (shop != null && shop.isNotEmpty && shop != 'null' && shop != 'FastKirana Dark Store') 
                                        ? shop 
                                        : (isRest ? (RestaurantRegistry.getName(order.restaurantId) ?? 'Restaurant') : 'FastKirana Dark Store');

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRest ? AppDesignSystem.violet50 : AppDesignSystem.green50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isRest ? AppDesignSystem.violet300 : AppDesignSystem.green200,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(isRest ? '🍽️' : '🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                                          const SizedBox(width: 4),
                                          Text(
                                            outletName,
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 10.5),
                                              fontWeight: FontWeight.w800,
                                              color: isRest ? AppDesignSystem.statusShippedText : AppDesignSystem.green800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                            color: primaryRed,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
                          ? ((sub.shopName != null && sub.shopName!.isNotEmpty && sub.shopName != 'FastKirana Dark Store')
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
                                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate500, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                      onPressed: onWhatsappCustomer != null ? () => onWhatsappCustomer!(custPhone, order.readableId ?? order.id) : null,
                      icon: const Icon(Icons.chat_rounded, color: AppDesignSystem.green600, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppDesignSystem.green100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onCallCustomer != null ? () => onCallCustomer!(custPhone) : null,
                      icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Ordered Items List
          if (itemsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ITEMS (${itemsList.length}):',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: itemsList.map((item) {
                      final isItemRefunded = item.isRefunded || item.refundAmount > 0;
                      return GestureDetector(
                        onTap: onShowSubstitution != null ? () => onShowSubstitution!(order, item) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isItemRefunded ? const Color(0xFFFFE4E6) : AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isItemRefunded ? const Color(0xFFFDA4AF) : AppDesignSystem.slate200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.quantity}x ${item.name}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: isItemRefunded ? const Color(0xFFBE123C) : AppDesignSystem.slate700,
                                  decoration: isItemRefunded ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (isItemRefunded) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '↩️ -₹${item.refundAmount > 0 ? item.refundAmount.toInt() : (item.price * item.quantity).toInt()}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE11D48),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.swap_horiz_rounded, size: 12, color: AppDesignSystem.slate400),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          if (order.notes?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Note: ${order.notes}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.orange600,
                ),
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
            // 3.4 Rider Assignment Dropdown / Selector
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              color: AppDesignSystem.background,
              child: Row(
                children: [
                  Text(
                    'RIDER:',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppDesignSystem.slate300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: (order.deliveryBoyName?.toLowerCase().contains('aryan') == true)
                              ? 'ARYAN'
                              : ((order.deliveryBoyName?.isNotEmpty == true) ? 'STORE_PARTNER' : 'UNASSIGNED'),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppDesignSystem.slate600, size: 20),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: Colors.white,
                          items: [
                            DropdownMenuItem(
                              value: 'UNASSIGNED',
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 15, color: AppDesignSystem.slate400),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Unassigned · Tap to assign',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                                  ),
                                ],
                              ),
                            ),
                            ...availableRiders.map((rider) => DropdownMenuItem(
                              value: rider['id'],
                              child: Row(
                                children: [
                                  const Icon(Icons.two_wheeler_rounded, size: 16, color: AppDesignSystem.cyan600),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${rider['name']} (${rider['phone']})',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.cyan600),
                                  ),
                                ],
                              ),
                            )),
                            DropdownMenuItem(
                              value: 'STORE_PARTNER',
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 15, color: AppDesignSystem.green600),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Store Partner (Self Delivery)',
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.green700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              if (val == 'STORE_PARTNER') {
                                final settings = ref.read(storeSettingsProvider).valueOrNull;
                                final storePhone = settings?.contactPhone.isNotEmpty == true
                                    ? settings!.contactPhone
                                    : AppConfig.supportPhone;
                                onAssignRider?.call(order, 'store_admin_self', 'Store Partner', storePhone);
                              } else {
                                final rider = availableRiders.firstWhere(
                                  (r) => r['id'] == val,
                                  orElse: () => availableRiders.first,
                                );
                                onAssignRider?.call(order, rider['id']!, rider['name']!, rider['phone']!);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                              'Online payment incomplete. Verify Razorpay, convert to COD, or send WhatsApp link.',
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
                          onPressed: onVerifyRazorpay != null ? () => onVerifyRazorpay!(order) : null,
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

          // ───── ADMIN APPROVAL GATE (only for ADMIN_PENDING orders) ─────
          if (order.status == OrderStatus.adminPending) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                border: Border(
                  top: BorderSide(color: AppDesignSystem.orange600.withValues(alpha: 0.3), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ADMIN APPROVAL REQUIRED — Call customer to verify before approving',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFC2410C),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // ✅ APPROVE → moves to PENDING (restaurant can now see it)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: onUpdateStatus != null ? () => onUpdateStatus!(order, OrderStatus.pending) : null,
                          icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'APPROVE ORDER',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesignSystem.green600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ❌ REJECT → cancel order
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onUpdateStatus != null ? () => onUpdateStatus!(order, OrderStatus.cancelled) : null,
                          icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'REJECT',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesignSystem.red600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],

          // 3.5 Order Status Dropdown Selector
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: AppDesignSystem.background,
            child: Row(
              children: [
                Text(
                  'STATUS:',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<OrderStatus>(
                        value: order.status,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: statusColor, size: 22),
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: OrderStatus.adminPending,
                            child: _StatusDropdownItem(
                              icon: Icons.admin_panel_settings_rounded,
                              label: '🔒 Needs Admin Approval',
                              color: AppDesignSystem.orange600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.pending,
                            child: _StatusDropdownItem(
                              icon: Icons.schedule_rounded,
                              label: 'Placed (Pending)',
                              color: AppDesignSystem.amber600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.confirmed,
                            child: _StatusDropdownItem(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Confirmed',
                              color: AppDesignSystem.cyan600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.packed,
                            child: _StatusDropdownItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Packed / Ready',
                              color: AppDesignSystem.violet600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.shipped,
                            child: _StatusDropdownItem(
                              icon: Icons.delivery_dining_rounded,
                              label: 'On the Way (Out for Delivery)',
                              color: AppDesignSystem.orange600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.delivered,
                            child: _StatusDropdownItem(
                              icon: Icons.task_alt_rounded,
                              label: 'Delivered',
                              color: AppDesignSystem.green600,
                            ),
                          ),
                          DropdownMenuItem(
                            value: OrderStatus.cancelled,
                            child: _StatusDropdownItem(
                              icon: Icons.cancel_outlined,
                              label: 'Cancelled',
                              color: AppDesignSystem.red600,
                            ),
                          ),
                        ],
                        onChanged: (newStatus) {
                          if (newStatus != null && newStatus != order.status) {
                            HapticFeedback.mediumImpact();
                            onUpdateStatus?.call(order, newStatus);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // 3.5 Superpower Action: Edit Order / Add & Swap Items (⚡)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpenSuperOrderEdit != null ? () => onOpenSuperOrderEdit!(order) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      'Edit Items & Swap (Superpower)',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3.6 Refund Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onShowRecordRefund != null ? () => onShowRecordRefund!(order) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.replay_rounded, size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    Text(
                      order.refundAmount > 0
                          ? '↩️ Refunded ₹${order.refundAmount.toInt()} (Record More)'
                          : '↩️ Record Refund (Deduct from Finance)',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFBE123C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. The 2 Main Order Actions: 🖨️ Send KOT (Remote) & 💬 WhatsApp KOT
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                // Option 1: 🖨️ Send KOT / ⏳ Printing... / 🖨️ KOT ✓
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: (isKOTSending || isKOTPrinted || onSendRemoteKOT == null) ? null : () => onSendRemoteKOT!(order),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isKOTSending
                            ? AppDesignSystem.statusPending // Yellow amber loading
                            : (isKOTPrinted ? AppDesignSystem.green100 : AppDesignSystem.green50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isKOTSending
                              ? AppDesignSystem.yellow200
                              : (isKOTPrinted ? AppDesignSystem.emerald200 : AppDesignSystem.green200),
                          width: 1.2,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isKOTSending) ...[
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.amber600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sending KOT...',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.amber700,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                isKOTPrinted ? Icons.check_circle_rounded : Icons.print_rounded,
                                size: 16,
                                color: AppDesignSystem.green600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isKOTPrinted ? 'KOT Sent ✓' : 'Send KOT',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.green700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Option 2: 💬 WhatsApp KOT
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSendWhatsAppKOT != null ? () => onSendWhatsAppKOT!(order) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppDesignSystem.slate900),
                            const SizedBox(width: 6),
                            Text(
                              'WhatsApp KOT',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                          ],
                        ),
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
