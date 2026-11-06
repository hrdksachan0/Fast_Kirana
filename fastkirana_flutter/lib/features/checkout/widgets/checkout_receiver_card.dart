import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';

/// Receiver / Contact Info Card for Checkout
/// Features Zepto Dual-Action Guard when customer live GPS is > 200m away from destination
class CheckoutReceiverCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final bool isOrderingForSomeone;
  final void Function(String? name, String? phone) onReceiverDetailsSaved;
  final double? distanceMeters;
  final VoidCallback? onAddressChangeRequested;
  final VoidCallback? onProximitySheetRequested;

  const CheckoutReceiverCard({
    super.key,
    required this.customerName,
    required this.customerPhone,
    required this.isOrderingForSomeone,
    required this.onReceiverDetailsSaved,
    this.distanceMeters,
    this.onAddressChangeRequested,
    this.onProximitySheetRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppDesignSystem.slate200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Avatar + Tag + Edit Button)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isOrderingForSomeone
                      ? AppDesignSystem.statusPending
                      : AppDesignSystem.blue50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOrderingForSomeone ? '🎁' : '👤',
                  style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOrderingForSomeone ? 'Ordering for someone else' : 'Contact Details for Order',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.slate500,
                ),
              ),
              const Spacer(),
              Bounceable(
                onTap: () => _showEditReceiverModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.orange50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDesignSystem.orange300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 12, color: AppDesignSystem.orange600),
                      const SizedBox(width: 3),
                      Text(
                        isOrderingForSomeone ? 'Edit' : '+ Change',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.orange600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Customer Name & Phone Number
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                customerName,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),
              if (customerPhone.isNotEmpty)
                Text(
                  '•   $customerPhone',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isOrderingForSomeone
                ? 'Delivery rider will call this receiver number at doorstep'
                : 'Order tracking and delivery updates will be sent here',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w500,
              color: isOrderingForSomeone ? AppDesignSystem.orange600 : AppDesignSystem.slate400,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditReceiverModal(BuildContext context) {
    showEditReceiverModal(
      context: context,
      isOrderingForSomeone: isOrderingForSomeone,
      customerName: customerName,
      customerPhone: customerPhone,
      onReceiverDetailsSaved: onReceiverDetailsSaved,
    );
  }

  static void showEditReceiverModal({
    required BuildContext context,
    required bool isOrderingForSomeone,
    required String customerName,
    required String customerPhone,
    required void Function(String? name, String? phone) onReceiverDetailsSaved,
  }) {
    final nameCtrl = TextEditingController(text: isOrderingForSomeone ? customerName : '');
    final phoneCtrl = TextEditingController(text: isOrderingForSomeone ? customerPhone : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Receiver Details',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rider will contact this person when delivering at the doorstep',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                color: AppDesignSystem.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Receiver Name',
                hintText: 'e.g. Papa / Mummy / Friend',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Receiver Phone Number',
                hintText: '10-digit mobile number',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12, top: 14, right: 8),
                  child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            Bounceable(
              onTap: () {
                final n = nameCtrl.text.trim();
                final p = phoneCtrl.text.trim();
                onReceiverDetailsSaved(
                  n.isNotEmpty ? n : null,
                  p.isNotEmpty ? p : null,
                );
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppDesignSystem.orange600,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignSystem.orange600.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Save Receiver Details',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (isOrderingForSomeone) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    onReceiverDetailsSaved(null, null);
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Reset to my own contact details',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
