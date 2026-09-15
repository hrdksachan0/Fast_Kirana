import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentFailedCodSheet extends StatefulWidget {
  final double grandTotal;
  final VoidCallback onCancelOrder;
  final VoidCallback onConfirmCod;

  const PaymentFailedCodSheet({
    super.key,
    required this.grandTotal,
    required this.onCancelOrder,
    required this.onConfirmCod,
  });

  static Future<void> show({
    required BuildContext context,
    required double grandTotal,
    required VoidCallback onCancelOrder,
    required VoidCallback onConfirmCod,
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

  @override
  Widget build(BuildContext context) {
    final progress = _secondsRemaining / _totalSeconds;
    final timeStr = '00:${_secondsRemaining < 10 ? '0' : ''}$_secondsRemaining';

    return PopScope(
      canPop: false, // Prevent dismissing without clicking an explicit action
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
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
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Warning Badge & Header
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          'Payment Not Completed',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Online Payment Cancel Ho Gaya',
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Friendly Clarification Card
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'Order COD par mangwayein:',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Aapka order automatically Cash on Delivery (Ghar par payment) mein convert ho raha hai. Agar aapko yeh order nahi chahiye, toh turant "Roko / Cancel" dabayein.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 60-Second Slider / Countdown Progress Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
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
                            'COD mein convert hone ka time:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar Slider Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFFDE68A),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⏰ 1 minute slider chal raha hai — rokein ya confirm karein',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 🛑 Cancel / Stop Button ("Roko")
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F2),
                  side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.cancel_rounded, color: Color(0xFFBE123C), size: 18),
                label: Text(
                  '🛑 Roko / Cancel Order (Nahi Chahiye)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFBE123C),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 💵 Confirm COD Immediately Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleConfirmCod,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                label: Text(
                  '💵 Abhi COD Confirm Karein (₹${widget.grandTotal.toInt()})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
