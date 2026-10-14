import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Modal bottom sheet presented when payment verification is pending confirmation
/// or experiencing temporary network uncertainty.
/// Protects customers from double payment or premature COD conversion.
class PaymentPendingReconciliationSheet extends StatefulWidget {
  final double grandTotal;
  final String cfOrderId;
  final Future<void> Function() onCheckStatus;
  final VoidCallback onWait;

  const PaymentPendingReconciliationSheet({
    super.key,
    required this.grandTotal,
    required this.cfOrderId,
    required this.onCheckStatus,
    required this.onWait,
  });

  static Future<void> show({
    required BuildContext context,
    required double grandTotal,
    required String cfOrderId,
    required Future<void> Function() onCheckStatus,
    required VoidCallback onWait,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => PaymentPendingReconciliationSheet(
        grandTotal: grandTotal,
        cfOrderId: cfOrderId,
        onCheckStatus: onCheckStatus,
        onWait: onWait,
      ),
    );
  }

  @override
  State<PaymentPendingReconciliationSheet> createState() =>
      _PaymentPendingReconciliationSheetState();
}

class _PaymentPendingReconciliationSheetState
    extends State<PaymentPendingReconciliationSheet> {
  bool _isChecking = false;

  Future<void> _handleCheck() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    HapticFeedback.selectionClick();
    try {
      await widget.onCheckStatus();
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header icon and title
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppDesignSystem.amber50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignSystem.amber200, width: 1.2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: AppDesignSystem.amber600,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Confirmation Pending',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Awaiting final verification from your bank',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        color: AppDesignSystem.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Safe reassurance banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppDesignSystem.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppDesignSystem.emerald600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If money was deducted from your account, please do NOT pay again. Your payment reference is safely recorded and will confirm shortly.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      color: AppDesignSystem.slate700,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary: Check status button
          ElevatedButton(
            onPressed: _isChecking ? null : _handleCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.green700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isChecking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Check Status Now',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Secondary: Wait / dismiss
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onWait();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppDesignSystem.slate600,
            ),
            child: Text(
              'I will wait & check orders',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
