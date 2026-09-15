import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class RestaurantOrderCardView extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isUpdating;
  final VoidCallback onReject;
  final VoidCallback onAcceptAndCook;
  final VoidCallback onMarkReady;
  final VoidCallback onEditOrder;
  final VoidCallback onPrintKot;

  const RestaurantOrderCardView({
    super.key,
    required this.order,
    required this.isUpdating,
    required this.onReject,
    required this.onAcceptAndCook,
    required this.onMarkReady,
    required this.onEditOrder,
    required this.onPrintKot,
  });

  @override
  Widget build(BuildContext context) {
    const primaryRed = AppDesignSystem.primary;
    const brandGreen = AppDesignSystem.success;
    const brandAmber = AppDesignSystem.warning;
    const slateDark = AppDesignSystem.slate900;
    const slateMuted = AppDesignSystem.slate500;
    const slateBorder = AppDesignSystem.slate200;

    final String status = (order['status'] ?? 'PENDING').toString();
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final dynamic rawItems = order['items'];
    final List items = (rawItems is List) ? rawItems : [];

    final num total = (order['total'] is num)
        ? (order['total'] as num)
        : (num.tryParse(order['total']?.toString() ?? '0') ?? 0);

    final dynamic rawUser = order['user'];
    final Map<String, dynamic> user = (rawUser is Map<String, dynamic>) ? rawUser : {};
    final String customerName = (order['userName'] ?? user['name'] ?? order['customerName'] ?? 'Customer')
        .toString().trim().isEmpty
        ? 'Customer'
        : (order['userName'] ?? user['name'] ?? order['customerName'] ?? 'Customer').toString().trim();

    final dynamic rawRider = order['assignedRider'] ?? order['assignedDelivery'] ?? order['deliveryUser'];
    final Map<String, dynamic>? assignedRider = (rawRider is Map<String, dynamic> &&
            !(rawRider['name']?.toString().toLowerCase().contains('admin') ?? false) &&
            !(rawRider['phone']?.toString().contains('7054470303') ?? false))
        ? rawRider
        : null;

    Color statusBadgeColor = primaryRed;
    String statusLabel = 'NEW ORDER';
    if (status == 'CONFIRMED' || status == 'PREPARING') {
      statusBadgeColor = brandAmber;
      statusLabel = 'IN PREP';
    } else if (status == 'PACKED' || status == 'READY') {
      statusBadgeColor = brandGreen;
      statusLabel = 'READY FOR PICKUP';
    } else if (status == 'OUT_FOR_DELIVERY') {
      statusBadgeColor = AppDesignSystem.info;
      statusLabel = 'DISPATCHED';
    }

    final isPending = status == 'PENDING';
    final isPickup = (order['deliveryMethod'] ?? '').toString().toUpperCase().contains('PICKUP') ||
        (order['deliveryMethod'] ?? '').toString().toUpperCase().contains('TAKEAWAY');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? primaryRed : slateBorder, width: isPending ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isPending ? primaryRed.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$readableId',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              Text(isPickup ? '🚶‍♂️' : '🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 9.5))),
                              const SizedBox(width: 3),
                              Text(
                                isPickup ? 'SELF PICKUP' : 'DELIVERY',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9),
                                  fontWeight: FontWeight.w900,
                                  color: isPickup ? AppDesignSystem.amber700 : AppDesignSystem.green700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBadgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusBadgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: statusBadgeColor),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${total.toInt()}',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
                    ),
                  ],
                ),
                if (isPickup) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.amber50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppDesignSystem.yellow200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📍', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                        const SizedBox(width: 3),
                        Text(
                          'Customer will collect takeaway at counter (No Rider)',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: AppDesignSystem.statusPendingText),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Customer Name & Direct Action Buttons (KOT)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: slateMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerName,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Bounceable(
                      onTap: onPrintKot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.blue50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDesignSystem.blue200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print_rounded, size: 12, color: AppDesignSystem.blue600),
                            const SizedBox(width: 4),
                            Text('KOT', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w900, color: AppDesignSystem.blue600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items List
            ...items.map((item) {
              final String name = (item['name'] ?? 'Dish').toString();
              final int qty = (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
              final String? notes = item['notes']?.toString();
              final String? variant = item['selectedVariant']?.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4)),
                      child: Text('${qty}x', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: slateDark),
                          ),
                          if (variant != null && variant.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(variant, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: brandAmber)),
                            ),
                          if (notes != null && notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('📝 $notes', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, color: brandAmber)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Assigned Rider Status
            if (assignedRider != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppDesignSystem.green200),
                ),
                child: Row(
                  children: [
                    Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rider: ${assignedRider['name'] ?? 'Assigned'}',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.green800),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: Bounceable(
                      onTap: isUpdating ? null : onReject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.rose50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.rose200),
                        ),
                        child: Center(
                          child: Text('Reject', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: primaryRed)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: onEditOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.amber50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.amber400),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 18, color: AppDesignSystem.amber700),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Bounceable(
                      onTap: isUpdating ? null : onAcceptAndCook,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: isUpdating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Accept & Cook ⏱️', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (status == 'CONFIRMED' || status == 'PREPARING')
              Row(
                children: [
                  Expanded(
                    child: Bounceable(
                      onTap: isUpdating ? null : onMarkReady,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: brandGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: isUpdating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Mark Food as Ready 🥡', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: onEditOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.amber50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.amber400),
                      ),
                      child: const Icon(Icons.edit_note_rounded, size: 18, color: AppDesignSystem.amber700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: onPrintKot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.blue200),
                      ),
                      child: const Icon(Icons.print_rounded, size: 18, color: AppDesignSystem.blue600),
                    ),
                  ),
                ],
              )
            else if (status == 'PACKED' || status == 'READY')
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.green50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.emerald200),
                      ),
                      child: Center(
                        child: Text('Waiting for Rider Pickup 🛵', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: brandGreen)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: onPrintKot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.blue200),
                      ),
                      child: const Icon(Icons.print_rounded, size: 18, color: AppDesignSystem.blue600),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
