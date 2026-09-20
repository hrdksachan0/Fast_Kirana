import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class CheckoutPaymentSelectorSheet extends StatefulWidget {
  final String initialPayment;
  final double grandTotal;
  final bool isPlacingOrder;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onConfirm;

  const CheckoutPaymentSelectorSheet({
    super.key,
    required this.initialPayment,
    required this.grandTotal,
    required this.isPlacingOrder,
    required this.onPaymentChanged,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String selectedPayment,
    required double grandTotal,
    required bool isPlacingOrder,
    required ValueChanged<String> onPaymentChanged,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return CheckoutPaymentSelectorSheet(
          initialPayment: selectedPayment,
          grandTotal: grandTotal,
          isPlacingOrder: isPlacingOrder,
          onPaymentChanged: onPaymentChanged,
          onConfirm: () {
            Navigator.pop(ctx);
            onConfirm();
          },
        );
      },
    );
  }

  @override
  State<CheckoutPaymentSelectorSheet> createState() => _CheckoutPaymentSelectorSheetState();
}

class _CheckoutPaymentSelectorSheetState extends State<CheckoutPaymentSelectorSheet> {
  late String _selectedPayment;

  @override
  void initState() {
    super.initState();
    _selectedPayment = widget.initialPayment;
  }

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pull Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Payment Method',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16.5),
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Safe & Encrypted 256-bit Checkout',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: slateMuted,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.slate200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: AppDesignSystem.slate500, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Option 1: Cash on Delivery (COD)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPayment = 'cod');
                widget.onPaymentChanged('cod');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedPayment == 'cod' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                    width: _selectedPayment == 'cod' ? 1.8 : 1.1,
                  ),
                  boxShadow: _selectedPayment == 'cod'
                      ? [
                          BoxShadow(
                            color: AppDesignSystem.green700.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.green100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('💵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w900,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.green100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Default',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.green700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pay via cash or UPI QR at your doorstep',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : Colors.white,
                        border: Border.all(
                          color: _selectedPayment == 'cod' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                          width: 2,
                        ),
                      ),
                      child: _selectedPayment == 'cod'
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Pay Online (Instant UPI, Cards & Netbanking)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPayment = 'online');
                widget.onPaymentChanged('online');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedPayment == 'online' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedPayment == 'online' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                    width: _selectedPayment == 'online' ? 1.8 : 1.1,
                  ),
                  boxShadow: _selectedPayment == 'online'
                      ? [
                          BoxShadow(
                            color: AppDesignSystem.green700.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('💳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pay Online',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w900,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.statusDelivered,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.emerald200),
                                ),
                                child: Text(
                                  '⚡ INSTANT',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.statusDeliveredText,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Google Pay, PhonePe, Paytm, Cards & UPI',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedPayment == 'online' ? AppDesignSystem.green700 : Colors.white,
                        border: Border.all(
                          color: _selectedPayment == 'online' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                          width: 2,
                        ),
                      ),
                      child: _selectedPayment == 'online'
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security Trust Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: AppDesignSystem.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '100% Safe & Encrypted • Instant Refunds',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Confirm Action Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.green700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: widget.isPlacingOrder ? null : widget.onConfirm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedPayment == 'online'
                          ? 'Pay ₹${widget.grandTotal.toInt()} Online'
                          : 'Place Order • Pay ₹${widget.grandTotal.toInt()} on Delivery',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
