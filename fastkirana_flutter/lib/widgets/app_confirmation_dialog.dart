import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

enum ConfirmationDialogType {
  success,
  danger,
  warning,
  info,
}

class AppConfirmationDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? contentWidget;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final ConfirmationDialogType type;
  final IconData? confirmIcon;
  final bool isConfirmLoading;

  const AppConfirmationDialog({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.contentWidget,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.type = ConfirmationDialogType.info,
    this.confirmIcon,
    this.isConfirmLoading = false,
  });

  // -------------------------------------------------------------
  // Presets & Static Helpers
  // -------------------------------------------------------------

  /// Generic confirmation modal
  static Future<bool?> show({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? message,
    Widget? contentWidget,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    ConfirmationDialogType type = ConfirmationDialogType.info,
    IconData? confirmIcon,
    bool barrierDismissible = true,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AppConfirmationDialog(
        icon: icon,
        title: title,
        message: message,
        contentWidget: contentWidget,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        type: type,
        confirmIcon: confirmIcon,
        onConfirm: () {
          HapticFeedback.mediumImpact();
          Navigator.of(ctx).pop(true);
        },
        onCancel: () {
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop(false);
        },
      ),
    );
  }

  /// Modern Convert to Cash on Delivery (COD) Dialog
  static Future<bool?> showCODConversion({
    required BuildContext context,
    required String displayId,
    required num totalAmount,
    String queueMessage = 'Queued for kitchen & store packing',
  }) {
    HapticFeedback.mediumImpact();
    final cleanId = displayId.replaceAll('#', '').trim();
    final amountFormatted = totalAmount is int ? '₹$totalAmount' : '₹${totalAmount.toStringAsFixed(totalAmount.truncateToDouble() == totalAmount ? 0 : 2)}';

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AppConfirmationDialog(
        icon: Icons.payments_rounded,
        title: 'Convert to Cash on Delivery?',
        message: 'Switch this order from pending online payment to Cash on Delivery immediately.',
        type: ConfirmationDialogType.success,
        confirmLabel: 'Convert to COD',
        confirmIcon: Icons.check_circle_rounded,
        contentWidget: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Order ID & Amount Pills
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF6D28D9)),
                        const SizedBox(width: 5),
                        Text(
                          'Order #$cleanId',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      amountFormatted,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Flow path: Pending Online -> Cash On Delivery
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_alt_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: const Color(0xFF64748B)),
                          children: [
                            const TextSpan(text: 'Payment: '),
                            TextSpan(text: 'Online', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
                            const TextSpan(text: ' ➔ '),
                            TextSpan(text: 'Cash on Delivery', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Kitchen status cue
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      queueMessage,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        onConfirm: () {
          HapticFeedback.heavyImpact();
          Navigator.of(ctx).pop(true);
        },
        onCancel: () {
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop(false);
        },
      ),
    );
  }

  /// Modern Universal Logout Dialog
  static Future<bool?> showLogout({
    required BuildContext context,
    String title = 'Log Out?',
    String subtitle = 'Are you sure you want to sign out?',
    String confirmLabel = 'Log Out',
    String? accountNote,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AppConfirmationDialog(
        icon: Icons.logout_rounded,
        title: title,
        message: subtitle,
        type: ConfirmationDialogType.danger,
        confirmLabel: confirmLabel,
        confirmIcon: Icons.power_settings_new_rounded,
        contentWidget: accountNote != null
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        accountNote,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB91C1C),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
        onConfirm: () {
          HapticFeedback.heavyImpact();
          Navigator.of(ctx).pop(true);
        },
        onCancel: () {
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop(false);
        },
      ),
    );
  }

  /// Modern Destructive Action (e.g. Delete Address, Cancel Order)
  static Future<bool?> showDestructive({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    IconData icon = Icons.delete_outline_rounded,
    Widget? contentWidget,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AppConfirmationDialog(
        icon: icon,
        title: title,
        message: message,
        type: ConfirmationDialogType.danger,
        confirmLabel: confirmLabel,
        confirmIcon: icon,
        contentWidget: contentWidget,
        onConfirm: () {
          HapticFeedback.heavyImpact();
          Navigator.of(ctx).pop(true);
        },
        onCancel: () {
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop(false);
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme Helpers
  // -------------------------------------------------------------

  Color get _primaryColor {
    switch (type) {
      case ConfirmationDialogType.success:
        return const Color(0xFF10B981); // Emerald 500
      case ConfirmationDialogType.danger:
        return const Color(0xFFE20A22); // FastKirana Brand Red
      case ConfirmationDialogType.warning:
        return const Color(0xFFF59E0B); // Amber 500
      case ConfirmationDialogType.info:
        return const Color(0xFF3B82F6); // Blue 500
    }
  }

  Color get _badgeBgColor {
    switch (type) {
      case ConfirmationDialogType.success:
        return const Color(0xFFECFDF5);
      case ConfirmationDialogType.danger:
        return const Color(0xFFFFF1F2);
      case ConfirmationDialogType.warning:
        return const Color(0xFFFFFBEB);
      case ConfirmationDialogType.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color get _badgeBorderColor {
    switch (type) {
      case ConfirmationDialogType.success:
        return const Color(0xFFA7F3D0);
      case ConfirmationDialogType.danger:
        return const Color(0xFFFECDD3);
      case ConfirmationDialogType.warning:
        return const Color(0xFFFDE68A);
      case ConfirmationDialogType.info:
        return const Color(0xFFBFDBFE);
    }
  }

  // -------------------------------------------------------------
  // Widget Build
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: Colors.white,
      elevation: 20,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.25),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Concentric Glow Icon Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _badgeBgColor,
                shape: BoxShape.circle,
                border: Border.all(color: _badgeBorderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Headline
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17.5),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),

            // 3. Subtitle / Message
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.42,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 4. Custom Slot (e.g. Order Highlight Card)
            if (contentWidget != null) ...[
              const SizedBox(height: 14),
              contentWidget!,
            ],

            const SizedBox(height: 22),

            // 5. Dual Action Buttons
            Row(
              children: [
                // Cancel Button (Soft Neutral Slate)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                      onPressed: () {
                        if (onCancel != null) {
                          onCancel!();
                        } else {
                          Navigator.of(context).pop(false);
                        }
                      },
                      child: Text(
                        cancelLabel,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Confirm Button (Vibrant & Tactile with soft colored shadow)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: isConfirmLoading ? null : onConfirm,
                        child: isConfirmLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (confirmIcon != null) ...[
                                    Icon(confirmIcon, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      confirmLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }
}
