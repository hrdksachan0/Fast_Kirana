import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _PaymentFailedCodSheetState extends State<PaymentFailedCodSheet> {
  static const int _totalSeconds = 60;
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (!_isActionTaken) {
          _isActionTaken = true;
          Navigator.of(context).pop();
          widget.onConfirmCod();
        }
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onCancelOrder();
  }

  void _handleConfirmCod() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
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
    final progress = _secondsRemaining / _totalSeconds;
    final timeStr = '00:${_secondsRemaining < 10 ? '0' : ''}$_secondsRemaining';
    final formattedAmount = widget.grandTotal.toStringAsFixed(widget.grandTotal.truncateToDouble() == widget.grandTotal ? 0 : 2);

    return PopScope(
      canPop: false, // Prevent dismissing without clicking an explicit action
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Handle Bar
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Row: Status Icon & Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE11D48),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          'PAYMENT INCOMPLETE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Online Payment Not Completed',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No money was debited from your account.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Option 1: Cash on Delivery Benefit Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay on Delivery Available',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pay via Cash or UPI at your doorstep.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Countdown Timer Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-switching to COD in:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          timeStr,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFFDE68A),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. Primary Button: Confirm COD
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleConfirmCod,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Confirm Pay on Delivery (₹$formattedAmount)',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Secondary Button: Retry Online Payment
            if (widget.onRetryPayment != null) ...[
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _handleRetryPayment,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 18),
                  label: Text(
                    'Retry Online Payment (UPI / Cards)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 3. Cancel / Discard Action
            SizedBox(
              height: 40,
              child: TextButton.icon(
                onPressed: _handleCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  'Cancel Order',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
