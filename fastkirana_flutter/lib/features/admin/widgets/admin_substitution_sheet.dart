import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../data/models/order.dart';
import '../../../../core/services/admin_notification_service.dart';

/// Out-of-Stock Replacement Modal for Admin Orders Console
class AdminSubstitutionSheet {
  static void show(BuildContext context, Order order, OrderItem item) {
    final repController = TextEditingController();
    final custPhone = order.customerPhone ?? '';
    final custName = order.customerName ?? 'Customer';
    final orderId = order.readableId ?? order.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusCancelled,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppDesignSystem.red600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Out-of-Stock Replacement',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                      ),
                      Text(
                        'Order #$orderId • Customer: $custName',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.rose50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.rose200),
              ),
              child: Row(
                children: [
                  Text('❌', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unavailable Item: ${item.name} (${item.quantity}x)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.rose800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'SUGGESTED REPLACEMENT:',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w800, color: AppDesignSystem.slate600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: repController,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. Britannia Brown Bread 400g / Taaza 500ml',
                hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: AppDesignSystem.slate400),
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.green600, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                final replacement = repController.text.trim();
                if (replacement.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter replacement item name', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                  );
                  return;
                }
                Navigator.pop(ctx);
                AdminNotificationService.sendSubstitutionWhatsApp(
                  customerPhone: custPhone,
                  customerName: custName,
                  orderId: orderId,
                  unavailableItem: item.name,
                  suggestedReplacement: replacement,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.green600,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Send Substitution via WhatsApp ➔',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
