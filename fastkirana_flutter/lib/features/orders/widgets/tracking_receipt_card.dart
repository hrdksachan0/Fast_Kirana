import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingReceiptCard extends StatelessWidget {
  final Order? order;

  const TrackingReceiptCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final items = order?.items ?? [];
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);
    const slateBorder = Color(0xFFE2E8F0);
    const primaryRed = Color(0xFFE11D48);
    const brandGreen = Color(0xFF00A344);

    double calculatedItemTotal = 0.0;
    for (final item in items) {
      calculatedItemTotal += item.price * item.quantity;
    }

    final subtotal = calculatedItemTotal > 0 ? calculatedItemTotal : (order?.subtotal ?? 0.0);
    final deliveryFee = order?.deliveryFee ?? 0.0;
    final miscFee = order?.miscFee ?? 0.0;
    final taxes = order?.taxes ?? 0.0;
    final discount = order?.discount ?? 0.0;
    final total = order?.total ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bill Details',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'ITEM' : 'ITEMS'}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w800,
                    color: slateMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final isItemRefunded = item.isRefunded || item.refundAmount > 0;
            final itemTotal = (item.price * item.quantity).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isItemRefunded ? const Color(0xFFFFE4E6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: isItemRefunded ? const Color(0xFFFDA4AF) : slateBorder),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w800,
                          color: isItemRefunded ? const Color(0xFFE11D48) : slateDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w700,
                            color: isItemRefunded ? slateMuted : slateDark,
                            decoration: isItemRefunded ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isItemRefunded)
                          Text(
                            'Item Unavailable - Refunded',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isItemRefunded ? '₹0' : '₹$itemTotal',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: isItemRefunded ? slateMuted : slateDark,
                      decoration: isItemRefunded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Subtotal', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
              Text('₹${subtotal.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Partner Fee', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
              Text(
                deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: deliveryFee == 0 ? brandGreen : slateDark,
                ),
              ),
            ],
          ),
          if (miscFee > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Packaging Charge', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                Text('₹${miscFee.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
              ],
            ),
          ],
          if (taxes > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Handling & Taxes', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                Text('₹${taxes.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
              ],
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount Savings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: brandGreen)),
                Text('-₹${discount.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: brandGreen)),
              ],
            ),
          ],
          if ((order?.refundAmount ?? 0) > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Refund Credited',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE11D48),
                  ),
                ),
                Text(
                  '-₹${order!.refundAmount.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (order?.refundAmount ?? 0) > 0 ? 'Net Paid Total' : 'Total Paid',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark),
                  ),
                  Text(
                    (order?.refundAmount ?? 0) > 0
                        ? 'Original: ₹${total.toInt()} • ${order?.paymentMethod.displayName ?? "COD"}'
                        : (order?.paymentMethod.displayName ?? 'COD'),
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w600, color: slateMuted),
                  ),
                ],
              ),
              Text(
                '₹${((total - (order?.refundAmount ?? 0.0)).clamp(0.0, double.infinity)).toInt()}',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: primaryRed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrackingDestinationCard extends StatelessWidget {
  final Order? order;

  const TrackingDestinationCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);
    const slateBorder = Color(0xFFE2E8F0);
    const primaryRed = Color(0xFFE11D48);

    final addr = order?.address;
    final raw = order?.addressRaw;

    String fullAddress = addr?.formattedAddress ?? '';
    if (fullAddress.isEmpty || fullAddress == 'Ghatampur Zone') {
      if (raw != null) {
        final parts = [
          raw['houseNo'],
          raw['street'],
          raw['area'],
          raw['landmark'],
          raw['city'],
          raw['pincode'],
        ]
            .where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
            .map((p) => p.toString().trim())
            .toList();
        if (parts.isNotEmpty) {
          fullAddress = parts.join(', ');
        }
      }
      if (fullAddress.isEmpty) {
        fullAddress = order?.customerAddress ?? 'Ghatampur, Kanpur Nagar - 209206';
      }
    }

    String labelText = 'Delivery Address';
    final rawLabel = addr?.label ?? '';
    if (rawLabel.isNotEmpty &&
        rawLabel != 'Delivery Location' &&
        !rawLabel.toLowerCase().contains('express delivery')) {
      labelText = rawLabel;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelText,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
                ),
                const SizedBox(height: 3),
                Text(
                  fullAddress,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrackingRefundNoticeCard extends StatelessWidget {
  final Order? order;

  const TrackingRefundNoticeCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final refundAmount = order?.refundAmount ?? 0.0;
    final notes = order?.notes ?? '';
    final hasRefundNote = notes.toLowerCase().contains('refund');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF1F2),
            Color(0xFFFFFBEB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.replay_rounded, size: 20, color: Color(0xFFE11D48)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      refundAmount > 0
                          ? '₹${refundAmount.toInt()} Refund Credited'
                          : 'Refund Processed',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9F1239),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'REFUNDED',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 8.5),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasRefundNote
                      ? notes
                      : 'Refund has been credited back to your original payment method.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFBE123C),
                    height: 1.3,
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
