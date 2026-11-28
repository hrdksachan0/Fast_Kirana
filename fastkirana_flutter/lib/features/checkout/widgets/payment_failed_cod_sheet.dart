import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blinkit-style Payment Failed / Cancelled -> 1-Tap Pay on Delivery Recovery Sheet (Option 7).
///
/// Displays when a customer's UPI/online payment fails or is cancelled during checkout.
/// Features:
/// - Floating circular close (✕) button above the sheet
/// - Calm reassurance banner ("Payment failed/cancelled · ₹0 deducted")
/// - Pre-selected "Pay on Delivery (Cash / Rider UPI QR)" radio card + "Retry Online UPI" row
/// - Full-width Blinkit Green (#0C831F) split-total CTA with subtle glossy sheen animation
class PaymentFailedCodSheet extends StatefulWidget {
  final double grandTotal;
  final VoidCallback onCancelOrder;
  final VoidCallback onConfirmCod;
  final VoidCallback? onRetryPayment;
  final bool isCancelled;

  const PaymentFailedCodSheet({
    super.key,
    required this.grandTotal,
    required this.onCancelOrder,
    required this.onConfirmCod,
    this.onRetryPayment,
    this.isCancelled = false,
  });

  static Future<void> show({
    required BuildContext context,
    required double grandTotal,
    required VoidCallback onCancelOrder,
    required VoidCallback onConfirmCod,
    VoidCallback? onRetryPayment,
    bool isCancelled = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => PaymentFailedCodSheet(
        grandTotal: grandTotal,
        onCancelOrder: onCancelOrder,
        onConfirmCod: onConfirmCod,
        onRetryPayment: onRetryPayment,
        isCancelled: isCancelled,
      ),
    );
  }

  @override
  State<PaymentFailedCodSheet> createState() => _PaymentFailedCodSheetState();
}

class _PaymentFailedCodSheetState extends State<PaymentFailedCodSheet>
    with SingleTickerProviderStateMixin {
  String _selectedOption = 'cod'; // 'cod' (default recommended) or 'upi'
  bool _isActionTaken = false;
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onCancelOrder();
  }

  void _handlePrimaryCta() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
    if (_selectedOption == 'upi' && widget.onRetryPayment != null) {
      widget.onRetryPayment!();
    } else {
      widget.onConfirmCod();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = widget.grandTotal.toStringAsFixed(
      widget.grandTotal.truncateToDouble() == widget.grandTotal ? 0 : 2,
    );
    final hasRetry = widget.onRetryPayment != null;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleDismiss();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinkit Signature Floating Circular Close Button Above Sheet
          GestureDetector(
            onTap: _handleDismiss,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xE00F172A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),

          // Main Rounded Sheet (#F4F6FB Blinkit Surface)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Calm Reassurance Alert Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isCancelled
                                  ? 'Payment cancelled · ₹0 deducted'
                                  : 'Payment failed · ₹0 deducted',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF991B1B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              'Your cart is 100% safe. Place order instantly below.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // White Radio Option Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8ECF4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Option 1: Pay on Delivery (Recommended)
                      _buildRadioRow(
                        selected: _selectedOption == 'cod',
                        title: 'Pay on Delivery',
                        badge: 'RECOMMENDED',
                        subtitle: 'Cash or scan Rider UPI QR at doorstep',
                        trailingEmoji: '🛵',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedOption = 'cod');
                        },
                      ),

                      if (hasRetry) ...[
                        const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F6)),
                        // Option 2: Retry Online UPI
                        _buildRadioRow(
                          selected: _selectedOption == 'upi',
                          title: 'Retry Online UPI',
                          subtitle: 'GPay · PhonePe · Paytm · BHIM',
                          trailingEmoji: '⚡',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedOption = 'upi');
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Blinkit Signature Green Split-Total CTA with Glossy Sheen
                SizedBox(
                  height: 54,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      color: const Color(0xFF0C831F),
                      child: InkWell(
                        onTap: _handlePrimaryCta,
                        child: Stack(
                          children: [
                            // Subtle diagonal glossy sheen sweep
                            AnimatedBuilder(
                              animation: _sheenController,
                              builder: (context, _) {
                                final progress = _sheenController.value;
                                // Sweep across during first 45% of cycle, rest quietly
                                final x = progress < 0.45
                                    ? -1.4 + (progress / 0.45) * 3.0
                                    : 2.0;
                                return Positioned.fill(
                                  child: IgnorePointer(
                                    child: FractionalTranslation(
                                      translation: Offset(x, 0),
                                      child: Container(
                                        width: 90,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0.0),
                                              Colors.white.withValues(alpha: 0.22),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹$formattedAmount',
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                      Text(
                                        'TOTAL',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: 0.85),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedOption == 'upi'
                                            ? 'Retry UPI'
                                            : 'Place Order',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_right_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _buildRadioRow({
    required bool selected,
    required String title,
    String? badge,
    required String subtitle,
    required String trailingEmoji,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: selected ? const Color(0xFFF2FBF4) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF0C831F) : Colors.transparent,
                border: Border.all(
                  color: selected ? const Color(0xFF0C831F) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF5E4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0C831F),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(trailingEmoji, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
