import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';

/// Receiver / Contact Info Card for Checkout
class CheckoutReceiverCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final bool isOrderingForSomeone;
  final void Function(String? name, String? phone) onReceiverDetailsSaved;

  const CheckoutReceiverCard({
    super.key,
    required this.customerName,
    required this.customerPhone,
    required this.isOrderingForSomeone,
    required this.onReceiverDetailsSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                        'Edit',
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
            'Order tracking and delivery updates will be sent here',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate400,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditReceiverModal(BuildContext context) {
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
                  'Edit Receiver Details',
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
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Receiver Name',
                hintText: 'e.g. Rahul / Mom / Friend',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Receiver Phone Number',
                hintText: '10-digit mobile number',
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
                ),
                child: Center(
                  child: Text(
                    'Save Details',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
