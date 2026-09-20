import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class CheckoutBottomBar extends StatelessWidget {
  final double grandTotal;
  final bool isPlacingOrder;
  final VoidCallback onProceedToPay;

  const CheckoutBottomBar({
    super.key,
    required this.grandTotal,
    required this.isPlacingOrder,
    required this.onProceedToPay,
  });

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BILL',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w800,
                      color: slateMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '₹${grandTotal.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 19),
                      fontWeight: FontWeight.w900,
                      color: slateDark,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: isPlacingOrder ? null : onProceedToPay,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppDesignSystem.green700, AppDesignSystem.accentDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.green700.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isPlacingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Proceed to Pay',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
