import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-Premium Payment Interrupted / Fallback Bottom Sheet.
///
/// Displays when a customer backs out or cancels during UPI/online checkout.
/// Provides a live 1-minute countdown timer with 3 high-converting options:
/// 1. Instant Convert to Cash / UPI on Delivery (COD)
/// 2. Retry Online Payment (PhonePe, Paytm, GPay, Cards)
/// 3. Cancel Order (safely retaining all items in cart)
class PaymentFailedCodSheet extends StatefulWidget {
  final double grandTotal;
  final VoidCallback onCancelOrder;
  final VoidCallback onConfirmCod;
  final VoidCallback? onRetryPayment;

  const PaymentFailedCodSheet({
    super.key,
    required this.grandTotal,
    required this.onCancelOrder,
    required this.onConfirmCod,
    this.onRetryPayment,
  });

  static Future<void> show({
    required BuildContext context,
    required double grandTotal,
    required VoidCallback onCancelOrder,
    required VoidCallback onConfirmCod,
    VoidCallback? onRetryPayment,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => PaymentFailedCodSheet(
        grandTotal: grandTotal,
        onCancelOrder: onCancelOrder,
        onConfirmCod: onConfirmCod,
        onRetryPayment: onRetryPayment,
      ),
    );
  }

  @override
  State<PaymentFailedCodSheet> createState() => _PaymentFailedCodSheetState();
}

class _PaymentFailedCodSheetState extends State<PaymentFailedCodSheet> with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 60;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;
  bool _isActionTaken = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (!_isActionTaken) {
          _isActionTaken = true;
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop();
          // Auto-cancel on expiration to prevent unauthorized charges while saving cart
          widget.onCancelOrder();
        }
      } else {
        setState(() {
          _secondsRemaining--;
        });
        if (_secondsRemaining == 10) {
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _timer?.cancel();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onCancelOrder();
  }

  void _handleConfirmCod() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
    widget.onConfirmCod();
  }

  void _handleRetryPayment() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    if (widget.onRetryPayment != null) {
      widget.onRetryPayment!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_secondsRemaining / _totalSeconds).clamp(0.0, 1.0);
    final isUrgent = _secondsRemaining <= 10;
    final timeStr = '00:${_secondsRemaining < 10 ? '0' : ''}$_secondsRemaining';
    final formattedAmount = widget.grandTotal.toStringAsFixed(
      widget.grandTotal.truncateToDouble() == widget.grandTotal ? 0 : 2,
    );

    final timerColor = isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final timerBgColor = isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final timerBorderColor = isUrgent ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleCancel();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 36,
              spreadRadius: 2,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Top Header: Animated Pulsing Shield & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaleTransition(
                  scale: _pulseScale,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFEA580C),
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE11D48),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'PAYMENT INTERRUPTED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: const Color(0xFFBE123C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Text(
                              '₹0 DEBITED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Online Payment Cancelled',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'No amount was deducted. Would you like to switch to COD or retry?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ⏱️ Hero Countdown Bento Timer Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: timerBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: timerBorderColor, width: 1.2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: timerColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Holding cart & slot for:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isUrgent ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: timerBorderColor),
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
                            Text(
                              timeStr,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: timerColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),

                  // Animated Progress Bar Track (Slim 4.5px, smooth corners)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4.5,
                      backgroundColor: timerBorderColor.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🚀 Option 1: Hero Primary Option — Cash on Delivery (COD) (100% Truncation-Free & Responsive)
            InkWell(
              onTap: _handleConfirmCod,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Delivery Icon Box
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 11),

                    // Title & Subtitle (100% Truncation-Free across all screen widths)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'POPULAR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pay via Cash or UPI on delivery',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Price Pill (Fixed & Safe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '₹$formattedAmount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🔄 Option 2: Retry Online Payment Card
            if (widget.onRetryPayment != null) ...[
              InkWell(
                onTap: _handleRetryPayment,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retry Online Payment',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              'UPI (PhonePe, GPay, Paytm) or Cards',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ❌ Option 3: Cancel Order (Items safe in cart)
            SizedBox(
              height: 42,
              child: TextButton.icon(
                onPressed: _handleCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF64748B)),
                label: Text(
                  'Cancel Order (Cart items will be kept safe)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
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
