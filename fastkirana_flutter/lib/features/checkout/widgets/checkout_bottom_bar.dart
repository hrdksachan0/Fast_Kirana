import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class CheckoutBottomBar extends StatelessWidget {
  final double grandTotal;
  final bool isPlacingOrder;
  final bool isOffline;
  final bool isCheckingConnection;
  final VoidCallback onProceedToPay;
  final VoidCallback? onRetryConnection;

  const CheckoutBottomBar({
    super.key,
    required this.grandTotal,
    required this.isPlacingOrder,
    this.isOffline = false,
    this.isCheckingConnection = false,
    required this.onProceedToPay,
    this.onRetryConnection,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sleek inline warning banner docked directly above the checkout action bar (Zepto/Blinkit style)
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                border: Border(
                  top: BorderSide(color: Color(0xFFFECACA), width: 1),
                  bottom: BorderSide(color: Color(0xFFFEE2E2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 13,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'You are offline',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          'Connect to internet to place order',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRetryConnection != null)
                    GestureDetector(
                      onTap: (isCheckingConnection || isPlacingOrder)
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onRetryConnection!();
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFECACA), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCheckingConnection)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFFDC2626),
                                ),
                              )
                            else ...[
                              const Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Retry',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BILL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: slateMuted,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        '₹${grandTotal.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 19),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOffline
                                ? const [Color(0xFF64748B), Color(0xFF475569)]
                                : const [
                                    AppDesignSystem.green700,
                                    AppDesignSystem.accentDark
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isOffline
                                  ? Colors.black.withValues(alpha: 0.1)
                                  : AppDesignSystem.green700.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: (isPlacingOrder || isCheckingConnection)
                              ? null
                              : () {
                                  if (isOffline) {
                                    HapticFeedback.lightImpact();
                                    if (onRetryConnection != null) {
                                      onRetryConnection!();
                                    }
                                    return;
                                  }
                                  onProceedToPay();
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 48,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Center(
                                child: (isPlacingOrder || isCheckingConnection)
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              isOffline
                                                  ? 'Check Connection & Pay'
                                                  : (grandTotal == 0.0
                                                      ? '⚡ 1-Tap Place Order'
                                                      : 'Proceed to Pay'),
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(
                                                    context, isOffline ? 11.5 : 13.5),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            isOffline
                                                ? Icons.wifi_off_rounded
                                                : Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
