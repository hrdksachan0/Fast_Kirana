import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/kot_print_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/utils/app_toast.dart';

/// Modal bottom sheet for viewing, printing, broadcasting, and sharing Kitchen Order Tickets (KOT)
class RestaurantKotModal {
  static String formatKitchenWhatsAppMessage(Map<String, dynamic> order, String defaultOutletName) {
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final List items = KotPrintService.extractRestaurantItems(order);

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        orderDate = DateTime.parse(order['createdAt'].toString()).toLocal();
      } catch (e, _) {
        LoggerService.error('RestaurantKotModal: date parse error', e);
      }
    }
    final timeStr = DateFormat('hh:mm a').format(orderDate);

    final String deliveryMethod = (order['deliveryMethod'] ?? 'DELIVERY').toString().toUpperCase();
    final String typeStr = (deliveryMethod == 'PICKUP' || deliveryMethod == 'SELF_PICKUP')
        ? '🚶 Self Pickup (Customer Takeaway)'
        : '🛵 Doorstep Delivery (Rider Pickup)';

    final outletName = (order['shopName'] != null && order['shopName'].toString().isNotEmpty)
        ? order['shopName'].toString()
        : defaultOutletName;

    final buffer = StringBuffer();
    buffer.writeln('🍽️ *FASTKIRANA KITCHEN ORDER*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🆔 *Order Token:* #$readableId');
    buffer.writeln('⏰ *Order Time:* $timeStr');
    buffer.writeln('📦 *Type:* $typeStr');
    buffer.writeln('🏪 *Outlet:* $outletName');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *ITEMS TO PREPARE:*\n');

    int totalQty = 0;
    for (int idx = 0; idx < items.length; idx++) {
      final i = items[idx];
      final name = (i['name'] ?? 'Food Item').toString();
      final qty = (i['quantity'] is num) ? (i['quantity'] as num).toInt() : (int.tryParse(i['quantity']?.toString() ?? '1') ?? 1);
      totalQty += qty;
      final variant = (i['selectedVariant'] != null && i['selectedVariant'].toString().isNotEmpty)
          ? ' (${i['selectedVariant']})'
          : '';
      final itemNote = (i['notes'] != null && i['notes'].toString().isNotEmpty)
          ? ' [Note: ${i['notes']}]'
          : '';
      buffer.writeln('${idx + 1}. $name$variant$itemNote  ➜  *Qty: $qty*');
    }

    if (items.isEmpty) {
      buffer.writeln('1. Food Items  ➜  *Qty: 1*');
      totalQty = 1;
    }

    buffer.writeln('\n🔢 *Total Items to Pack:* $totalQty items');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    final customerNote = (order['notes'] ?? order['customerNote'] ?? '').toString().trim();
    if (customerNote.isNotEmpty && customerNote != 'null') {
      buffer.writeln('📝 *Customer Note:* $customerNote');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('👨‍🍳 *Chef Note:* Kripya fresh prepare karein aur safely pack karein');

    return buffer.toString();
  }

  static String generateKOTText(Map<String, dynamic> order) {
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    final List items = KotPrintService.extractRestaurantItems(order);

    final formattedItems = items.isNotEmpty
        ? items.map((i) {
            final name = (i['name'] ?? 'Food Item').toString();
            final qty = (i['quantity'] is num) ? (i['quantity'] as num).toInt() : (int.tryParse(i['quantity']?.toString() ?? '1') ?? 1);
            final variant = (i['selectedVariant'] != null && i['selectedVariant'].toString().isNotEmpty)
                ? ' (${i['selectedVariant']})'
                : '';
            final note = (i['notes'] != null && i['notes'].toString().isNotEmpty)
                ? '\n      * Note: ${i['notes']}'
                : '';
            final qtyStr = '$qty'.padRight(2);
            return '$qtyStr x  $name$variant$note';
          }).join('\n')
        : '1  x  Kitchen Food';

    DateTime orderDate = DateTime.now();
    if (order['createdAt'] != null) {
      try {
        String s = order['createdAt'].toString().trim();
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        orderDate = DateTime.parse(s).toLocal();
      } catch (e, _) {
        LoggerService.error('RestaurantKotModal: date parse error', e);
      }
    }
    final rawCustName = (order['userName'] ?? (order['user'] is Map ? order['user']['name'] : null) ?? order['customerName'])?.toString().trim();
    final custName = rawCustName != null && rawCustName.isNotEmpty ? ' | $rawCustName' : '';
    final printTimeStr = DateFormat('dd MMM  hh:mm a').format(DateTime.now());
    final typeStr = (order['deliveryMethod'] ?? 'DELIVERY').toString();

    return '''======================================
            FASTKIRANA KOT
======================================
TOKEN : #$readableId$custName
TYPE  : $typeStr
ORDER : ${DateFormat('dd MMM  hh:mm a').format(orderDate)}
PRINT : $printTimeStr
--------------------------------------
QTY   ITEM
--------------------------------------
$formattedItems
--------------------------------------
      *** FASTKIRANA KITCHEN ***
======================================''';
  }

  static void show({
    required BuildContext context,
    required Map<String, dynamic> order,
    required bool isAdmin,
    required String defaultOutletName,
  }) {
    HapticFeedback.mediumImpact();
    final kotText = generateKOTText(order);
    final String orderId = (order['id'] ?? '').toString();
    final dynamic rawReadable = order['readableId'];
    final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
        ? rawReadable.toString()
        : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppDesignSystem.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.blue50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.print_rounded, color: AppDesignSystem.blue600, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kitchen Order Ticket (KOT)',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15.5),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          Text(
                            'Order #$readableId-R · Bluetooth / POS Print',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              color: AppDesignSystem.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // KOT Ticket Receipt View
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Text(
                  kotText,
                  style: GoogleFonts.robotoMono(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.slate800,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  // 1. Primary Print Thermal POS (For Restaurant Console)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(ctx);
                        KotPrintService.printKOTReceipt(context, order);
                      },
                      icon: const Icon(Icons.print_rounded, size: 17, color: Colors.white),
                      label: Text(
                        'Print KOT (Thermal POS)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.blue600,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  // 2. Admin Only: Send Remote Broadcast to Web Kitchen Console
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Bounceable(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(ctx);

                        final extractedItems = KotPrintService.extractRestaurantItems(order);
                        final custName = (order['userName'] ?? (order['user'] is Map ? order['user']['name'] : null) ?? order['customerName'])?.toString();

                        KotPrintService.sendRemoteKOTToKitchen(
                          orderId: orderId,
                          readableId: readableId,
                          items: extractedItems,
                          customerName: custName,
                        );

                        if (context.mounted) {
                          AppToast.showSuccess(
                            context,
                            'KOT Sent to Web Console! 🚀',
                            subtitle: 'Kitchen ticket popped on Dark Store Display',
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.emeraldBrand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_to_mobile_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Web KOT',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // 3. Quick Share WhatsApp / Clipboard
                  const SizedBox(width: 8),
                  Bounceable(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                      final waText = formatKitchenWhatsAppMessage(order, defaultOutletName);
                      await Clipboard.setData(ClipboardData(text: waText));
                      if (context.mounted) {
                        AppToast.showInfo(
                          context,
                          'Kitchen Order Copied! 📋',
                          subtitle: 'Ready to share on WhatsApp',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.slate300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('💬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
